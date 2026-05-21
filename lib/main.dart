import 'dart:math';
import 'dart:ui' as ui;

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fullscreen_stub.dart'
    if (dart.library.html) 'fullscreen_web.dart' as platform_fs;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations(
      [DeviceOrientation.landscapeLeft, DeviceOrientation.landscapeRight]);
  await MetaStore.load();
  await GameStats.load();
  await NpcStore.load();
  await Settings.load();
  await Sfx.init();
  runApp(const BuffBattleApp());
}

/// Tiny SFX layer: one pre-loaded AudioPlayer per sound, played by
/// seek-to-zero + resume so we can spam shots/hits without churn.
class Sfx {
  static final Map<String, AudioPlayer> _p = {};
  static const _names = ['hit', 'kill', 'dash', 'pickup', 'door'];
  static final Random _rng = Random();

  static Future<void> init() async {
    for (final n in _names) {
      try {
        final ap = AudioPlayer()..setReleaseMode(ReleaseMode.stop);
        await ap.setPlayerMode(PlayerMode.lowLatency);
        await ap.setSource(AssetSource('sfx/$n.wav'));
        _p[n] = ap;
      } catch (_) {/* tests / unsupported platforms: stay silent */}
    }
  }

  // `pitch` overrides the playback rate directly; `jitter` adds a small
  // random ± to the default rate so repeated kills don't feel monotone.
  static void play(String name,
      {double vol = 0.6, double pitch = 1.0, double jitter = 0.0}) {
    final ap = _p[name];
    if (ap == null) return;
    final v = (vol * Settings.sfxVol).clamp(0.0, 1.0).toDouble();
    if (v <= 0.0) return;
    final rate =
        (pitch + (jitter > 0 ? (_rng.nextDouble() * 2 - 1) * jitter : 0.0))
            .clamp(0.5, 2.0)
            .toDouble();
    () async {
      try {
        await ap.setVolume(v);
        try {
          await ap.setPlaybackRate(rate);
        } catch (_) {/* not all platforms expose pitch */}
        await ap.seek(Duration.zero);
        await ap.resume();
      } catch (_) {}
    }();
  }
}

class BuffBattleApp extends StatelessWidget {
  const BuffBattleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Buff Battle',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF14131F),
        fontFamily: 'RobotoMono',
        fontFamilyFallback: const ['NotoEmoji'],
      ),
      builder: (context, child) => _LandscapeGate(child: child!),
      home: const TitleScreen(),
    );
  }
}

/// Browsers can't force device rotation, so on a portrait phone we cover
/// the app with a "rotate" prompt. Wide screens (desktop) are unaffected.
class _LandscapeGate extends StatelessWidget {
  const _LandscapeGate({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final portrait = mq.size.height > mq.size.width;
    final phone = mq.size.shortestSide < 900;
    if (!(portrait && phone)) return child;
    return ColoredBox(
      color: const Color(0xFF14131F),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: const [
          Icon(Icons.screen_rotation,
              size: 64, color: Color(0xFFFFD45E)),
          SizedBox(height: 18),
          Text('ROTATE YOUR DEVICE',
              style: TextStyle(
                  color: Color(0xFFFFD45E),
                  fontWeight: FontWeight.w900,
                  fontSize: 18)),
          SizedBox(height: 6),
          Text('Buff Battle plays in landscape',
              style: TextStyle(color: Colors.white60, fontSize: 13)),
        ],
      ),
    );
  }
}

/// ---------------------------------------------------------------------------
/// Meta progression (Home / Mirror) - persisted with SharedPreferences
/// ---------------------------------------------------------------------------
class MetaUpgrade {
  const MetaUpgrade(this.id, this.title, this.desc, this.maxLvl);
  final String id;
  final String title;
  final String desc;
  final int maxLvl;
}

const List<MetaUpgrade> kMeta = [
  MetaUpgrade('hp', 'IRON HIDE', '+2 max HP per level', 6),
  MetaUpgrade('dmg', 'SHARP CLAWS', '+0.3 damage per level', 6),
  MetaUpgrade('spd', 'SWIFT PAWS', '+8 move speed per level', 6),
  MetaUpgrade('gold', 'TRUST FUND', '+15 starting obols per level', 5),
  MetaUpgrade('vis', 'FAR SIGHT', '+0.10 base view per level', 5),
  MetaUpgrade('rev', 'NINE LIVES', '+1 Death Defiance per level', 3),
  MetaUpgrade('crit', 'SHARP EYE', '+3% crit chance per level', 5),
  MetaUpgrade('dash', 'FLEET FOOT', '−0.1s dash cooldown per level', 4),
  MetaUpgrade('life', 'VAMPIRIC', '+0.1 lifesteal per level', 4),
  MetaUpgrade('mp', 'FOCUSED MIND', '+0.4 MP regen per level', 4),
  MetaUpgrade('splash', 'BLAST CASTER', '+6 splash radius per level', 4),
];

class MetaStore {
  static int shards = 0;
  static final Map<String, int> lvl = {for (final m in kMeta) m.id: 0};

  static int lvlOf(String id) => lvl[id] ?? 0;
  static int costFor(String id) => 6 + lvlOf(id) * 7;

  static Future<void> load() async {
    try {
      final p = await SharedPreferences.getInstance();
      shards = p.getInt('bb_shards') ?? 0;
      for (final m in kMeta) {
        lvl[m.id] = p.getInt('bb_lvl_${m.id}') ?? 0;
      }
    } catch (_) {}
  }

  static Future<void> save() async {
    try {
      final p = await SharedPreferences.getInstance();
      await p.setInt('bb_shards', shards);
      for (final m in kMeta) {
        await p.setInt('bb_lvl_${m.id}', lvl[m.id] ?? 0);
      }
    } catch (_) {}
  }

  static bool buy(MetaUpgrade m) {
    final c = costFor(m.id);
    if (lvlOf(m.id) >= m.maxLvl || shards < c) return false;
    shards -= c;
    lvl[m.id] = lvlOf(m.id) + 1;
    save();
    return true;
  }
}

/// ---------------------------------------------------------------------------
/// Keepsakes + Heat (run loadout)
/// ---------------------------------------------------------------------------
class Keepsake {
  const Keepsake(this.name, this.desc, this.apply);
  final String name;
  final String desc;
  final void Function(Player p) apply;
}

final List<Keepsake> kKeepsakes = [
  Keepsake('OLD COLLAR', '+5 max HP', (p) {
    p.maxHp += 5;
    p.hp += 5;
  }),
  Keepsake('LUCKY TOOTH', '+1 Death Defiance', (p) => p.revives += 1),
  Keepsake('SHADOW SANDALS', '-0.4s dash cooldown',
      (p) => p.dashCd = (p.dashCd - 0.4).clamp(0.4, 5).toDouble()),
  Keepsake('THUNDER SIGNET', 'start with Zeus chain',
      (p) => p.zeus += 1),
  Keepsake('PIERCED HEART', '+8% crit chance',
      (p) => p.critChance += 0.08),
  Keepsake('LAMBENT PLUME', '+22 move speed', (p) => p.speed += 22),
  Keepsake('FROST WARD', "you can't be chilled", (p) {
    p.frostImmune = true;
    p.maxHp += 2;
    p.hp += 2;
  }),
  Keepsake('FERAL FANG', '+10% lifesteal',
      (p) => p.lifesteal = (p.lifesteal + 0.1)),
];

/// Unique keepsakes gifted by each NPC at ★★★ friendship. They append to
/// kKeepsakes in `availableKeepsakes()` whenever the NPC's friendship is
/// max so the Keepsake Stand only lists what the player has actually earned.
class NpcKeepsake {
  const NpcKeepsake(this.npcId, this.keepsake);
  final String npcId;
  final Keepsake keepsake;
}

final List<NpcKeepsake> kNpcKeepsakes = [
  NpcKeepsake('hypnos', Keepsake('PILLOW OF NIGHT',
      '+5 HP & +0.4 HP/sec, but -0.5 damage', (p) {
    p.maxHp += 5;
    p.hp += 5;
    p.regen += 0.4;
    p.damage = (p.damage - 0.5).clamp(0.1, 999).toDouble();
  })),
  NpcKeepsake('achilles', Keepsake('BRONZE GUARD',
      '+2 Death Defiance, but -8 max HP', (p) {
    p.revives += 2;
    p.maxHp = (p.maxHp - 8).clamp(1, 999).toDouble();
    p.hp = p.hp.clamp(1, p.maxHp).toDouble();
  })),
  NpcKeepsake('dusa', Keepsake('MIRROR SHARD',
      '+0.25 vision & +0.6 MP/sec', (p) {
    p.vision = (p.vision + 0.25).clamp(1.0, 2.8).toDouble();
    p.mpRegen += 0.6;
  })),
  NpcKeepsake('smith', Keepsake('FORGE STAMP',
      '+1.5 damage but +15% fire interval', (p) {
    p.damage += 1.5;
    p.fireInterval *= 1.15;
  })),
  NpcKeepsake('chef', Keepsake('WARM LOAF',
      '+25% nectar drops & +6 max HP', (p) {
    Loadout.blessingNectarBonus += 0.25;
    p.maxHp += 6;
    p.hp += 6;
  })),
  NpcKeepsake('scribe', Keepsake('INKWELL',
      '+8% crit & +1 projectile', (p) {
    p.critChance += 0.08;
    p.projectiles = (p.projectiles + 1).clamp(1, 8).toInt();
  })),
  NpcKeepsake('apothecary', Keepsake('HERB POUCH',
      '+0.8 HP/sec & +0.4 MP/sec', (p) {
    p.regen += 0.8;
    p.mpRegen += 0.4;
  })),
];

// Base keepsakes + every NPC-keepsake whose donor is at ★★★ friendship.
List<Keepsake> availableKeepsakes() {
  final list = List<Keepsake>.from(kKeepsakes);
  for (final nk in kNpcKeepsakes) {
    if (NpcStore.tierOf(nk.npcId) >= 3) list.add(nk.keepsake);
  }
  return list;
}

class Loadout {
  static Keepsake? keepsake;
  static int heat = 0; // Pact of Punishment-style difficulty
  static double get enemyMul => 1 + heat * 0.12;
  static double get rewardMul => 1 + heat * 0.25;
  // If set, the next run uses this RNG seed and records its score under
  // `dailyKey()` so each day's seed has a personal best.
  static int? dailySeed;
  // Pre-run picks set at the home stands. Null = use the hero default.
  static WeaponDef? startingWeapon;
  // Bonus obols the player walks in with, set at the Trade Post.
  static int startingObols = 0;
  // NPC blessings — set in the home, applied + consumed at run start.
  static int blessingDmg = 0; // Smith: +damage
  static int blessingHp = 0; // Hypnos: +max HP
  static int blessingRevives = 0; // Achilles: +revives
  static double blessingMpRegen = 0; // Dusa: +MP/sec
  static double blessingNectarBonus = 0; // Chef: extra nectar drop chance
  static double blessingCritChance = 0; // Scribe: +crit chance
  static double blessingRegen = 0; // Apothecary: +HP/sec
  static String? dailyKey; // YYYYMMDD format

  static String todayKey() {
    final d = DateTime.now();
    return '${d.year.toString().padLeft(4, '0')}'
        '${d.month.toString().padLeft(2, '0')}'
        '${d.day.toString().padLeft(2, '0')}';
  }

  // Seed derived from the YYYYMMDD key so everyone on the same day plays
  // the same generated run (without depending on a server clock).
  static int todaySeed() {
    final key = todayKey();
    return int.tryParse(key) ?? 1;
  }
}

/// ---------------------------------------------------------------------------
/// Classes
/// ---------------------------------------------------------------------------
enum HeroClass { tank, archer, mage, warlock, assassin, gunner }

class HeroDef {
  const HeroDef({
    required this.cls,
    required this.name,
    required this.role,
    required this.tagline,
    required this.body,
    required this.accent,
    required this.maxHp,
    required this.speed,
    required this.damage,
    required this.fireInterval,
    required this.projSpeed,
    required this.range,
    required this.abilityName,
    required this.abilityDesc,
    required this.abilityCost,
    required this.abilityCd,
    this.maxMp = 12,
    this.critChance = 0.05,
    this.projectiles = 1,
    this.lifesteal = 0,
    this.splash = 0,
    this.pierce = 0,
    this.dot = 0,
    this.thorns = 0,
  });

  final HeroClass cls;
  final String name;
  final String role;
  final String tagline;
  final Color body;
  final Color accent;
  final double maxHp;
  final double maxMp;
  final double speed;
  final double damage;
  final double fireInterval;
  final double projSpeed;
  final double range;
  final double critChance;
  final int projectiles;
  final double lifesteal;
  final double splash;
  final int pierce;
  final double dot;
  final double thorns;
  final String abilityName;
  final String abilityDesc;
  final double abilityCost;
  final double abilityCd;
}

const List<HeroDef> kHeroes = [
  HeroDef(
    cls: HeroClass.tank,
    name: 'CHONK KNIGHT',
    role: 'TANK',
    tagline: 'Unkillable lump of beef. Touch = ouch.',
    body: Color(0xFF8C93A3),
    accent: Color(0xFF4A4F5E),
    maxHp: 18,
    maxMp: 10,
    speed: 140,
    damage: 1.5,
    fireInterval: 0.70,
    projSpeed: 300,
    range: 240,
    critChance: 0.03,
    thorns: 1.5,
    abilityName: 'GROUND SLAM',
    abilityDesc: 'Shockwave: huge AoE + knockback',
    abilityCost: 6,
    abilityCd: 6,
  ),
  HeroDef(
    cls: HeroClass.archer,
    name: 'BOW DOGE',
    role: 'ARCHER',
    tagline: 'Arrows go fast. Arrows go through.',
    body: Color(0xFF6FCF7B),
    accent: Color(0xFF2E6B36),
    maxHp: 6,
    speed: 186,
    damage: 1.2,
    fireInterval: 0.38,
    projSpeed: 470,
    range: 360,
    critChance: 0.10,
    pierce: 1,
    abilityName: 'ARROW NOVA',
    abilityDesc: 'Fire arrows in every direction',
    abilityCost: 6,
    abilityCd: 7,
  ),
  HeroDef(
    cls: HeroClass.mage,
    name: 'WIZARD CAT',
    role: 'MAGE',
    tagline: 'Big slow bonk. Big boom.',
    body: Color(0xFF8C6CFF),
    accent: Color(0xFF3E2E80),
    maxHp: 6,
    maxMp: 16,
    speed: 160,
    damage: 2.4,
    fireInterval: 0.88,
    projSpeed: 300,
    range: 320,
    splash: 48,
    abilityName: 'METEOR',
    abilityDesc: 'Massive explosion on the pack',
    abilityCost: 7,
    abilityCd: 8,
  ),
  HeroDef(
    cls: HeroClass.warlock,
    name: 'DOOM PUG',
    role: 'WARLOCK',
    tagline: 'They rot. You heal. Wow.',
    body: Color(0xFFB05CCB),
    accent: Color(0xFF4F2358),
    maxHp: 7,
    maxMp: 14,
    speed: 168,
    damage: 0.9,
    fireInterval: 0.50,
    projSpeed: 340,
    range: 300,
    dot: 2.5,
    lifesteal: 0.3,
    abilityName: 'PLAGUE WIND',
    abilityDesc: 'Poison every enemy on screen',
    abilityCost: 6,
    abilityCd: 7,
  ),
  HeroDef(
    cls: HeroClass.assassin,
    name: 'NINJA SHIBA',
    role: 'ASSASSIN',
    tagline: 'Blink and you are dead. So fast.',
    body: Color(0xFF44485A),
    accent: Color(0xFFE0436B),
    maxHp: 5,
    maxMp: 10,
    speed: 226,
    damage: 1.6,
    fireInterval: 0.30,
    projSpeed: 480,
    range: 220,
    critChance: 0.25,
    abilityName: 'SHADOW DASH',
    abilityDesc: 'Blink to target, burst dmg, i-frames',
    abilityCost: 5,
    abilityCd: 5,
  ),
  HeroDef(
    cls: HeroClass.gunner,
    name: 'GANGSTA RAT',
    role: 'GUNNER',
    tagline: 'Brrrrt. Many small bonk.',
    body: Color(0xFFD9A24A),
    accent: Color(0xFF7A521C),
    maxHp: 7,
    maxMp: 12,
    speed: 172,
    damage: 0.8,
    fireInterval: 0.16,
    projSpeed: 520,
    range: 300,
    abilityName: 'OVERDRIVE',
    abilityDesc: '4s of insane fire rate',
    abilityCost: 7,
    abilityCd: 9,
  ),
];

/// ---------------------------------------------------------------------------
/// Floors
/// ---------------------------------------------------------------------------
class FloorDef {
  const FloorDef({
    required this.name,
    required this.bg,
    required this.voidc,
    required this.grid,
    required this.mob,
    required this.prop,
    required this.pool,
    required this.hpMul,
    required this.spdMul,
    required this.dmgMul,
  });

  final String name;
  final Color bg;
  final Color voidc;
  final Color grid;
  final Color mob;
  final Color prop;
  final Color pool;
  final double hpMul;
  final double spdMul;
  final double dmgMul;
}

const List<FloorDef> kFloors = [
  FloorDef(
    name: 'THE BACKYARD',
    bg: Color(0xFF1C3325),
    voidc: Color(0xFF0C1710),
    grid: Color(0xFF2C4A36),
    mob: Color(0xFF7BC96F),
    prop: Color(0xFF2F5A3C),
    pool: Color(0xFF2E6FB0),
    hpMul: 1.0,
    spdMul: 1.0,
    dmgMul: 1.0,
  ),
  FloorDef(
    name: 'SEWER OF SHAME',
    bg: Color(0xFF173230),
    voidc: Color(0xFF081413),
    grid: Color(0xFF255250),
    mob: Color(0xFF49C3B0),
    prop: Color(0xFF1F4A47),
    pool: Color(0xFF3FA38C),
    hpMul: 1.5,
    spdMul: 1.08,
    dmgMul: 1.2,
  ),
  FloorDef(
    name: 'DANK CAVES',
    bg: Color(0xFF2A2036),
    voidc: Color(0xFF120D18),
    grid: Color(0xFF402F50),
    mob: Color(0xFFB05CCB),
    prop: Color(0xFF3C2C4C),
    pool: Color(0xFF6E3FA0),
    hpMul: 2.2,
    spdMul: 1.16,
    dmgMul: 1.45,
  ),
  FloorDef(
    name: 'MEME FACTORY',
    bg: Color(0xFF332A1E),
    voidc: Color(0xFF17120A),
    grid: Color(0xFF50432C),
    mob: Color(0xFFE0A046),
    prop: Color(0xFF4A3A22),
    pool: Color(0xFFC8662A),
    hpMul: 3.1,
    spdMul: 1.24,
    dmgMul: 1.7,
  ),
  FloorDef(
    name: 'THE VOID',
    bg: Color(0xFF18182A),
    voidc: Color(0xFF08080F),
    grid: Color(0xFF2E2E48),
    mob: Color(0xFFFF5C8A),
    prop: Color(0xFF262640),
    pool: Color(0xFF7A3FC0),
    hpMul: 4.2,
    spdMul: 1.34,
    dmgMul: 2.0,
  ),
];

// The HomeRoom uses a non-combat palette: warm stone + amber so the player
// can read at a glance that they're safely back at base between runs.
const FloorDef kHomeFloor = FloorDef(
  name: 'HOME',
  bg: Color(0xFF3A2D1F),
  voidc: Color(0xFF14100A),
  grid: Color(0xFF5C4830),
  mob: Color(0xFFFFD45E),
  prop: Color(0xFF6C4F2E),
  pool: Color(0xFF8C6633),
  hpMul: 1.0,
  spdMul: 1.0,
  dmgMul: 1.0,
);

const int kWavesPerFloor = 5;
final int kMaxWaves = kFloors.length * kWavesPerFloor;

const List<String> kBossNames = [
  'CHOMPER, THE BACKYARD KING',
  'GLOOP, SEWER TYRANT',
  'CRYSTALMAW OF THE CAVES',
  'OVERSEER UNIT 9000',
  'NULL, THE VOID DEVOURER',
];

/// ---------------------------------------------------------------------------
/// Procedural map: rooms joined by corridors on a tile grid
/// ---------------------------------------------------------------------------
// tile codes: 0 = wall/void (blocks move + shots), 1 = floor,
// 2 = pool (blocks move, shots pass over)
class GameMap {
  GameMap(this.cols, this.rows, this.cell)
      : tiles = List<int>.filled(cols * rows, 0),
        rooms = [];

  final int cols;
  final int rows;
  final double cell;
  final List<int> tiles;
  final List<Rect> rooms; // tile coordinates

  double get worldW => cols * cell;
  double get worldH => rows * cell;
  Size get size => Size(worldW, worldH);

  bool _in(int c, int r) => c >= 0 && r >= 0 && c < cols && r < rows;
  int tt(int c, int r) => _in(c, r) ? tiles[r * cols + c] : 0;
  bool tile(int c, int r) => tt(c, r) == 1; // is floor
  void set(int c, int r, int v) {
    if (_in(c, r)) tiles[r * cols + c] = v;
  }

  // Force a walkable floor disk (overwrites walls/pools) so the player can
  // always stand on and reach this world point — used for spawn and doors.
  void clearDisk(double wx, double wy, double radiusCells) {
    final cc = (wx / cell).floor();
    final cr = (wy / cell).floor();
    final rad = radiusCells.ceil();
    for (var dr = -rad; dr <= rad; dr++) {
      for (var dc = -rad; dc <= rad; dc++) {
        if (dc * dc + dr * dr <= radiusCells * radiusCells) {
          set(cc + dc, cr + dr, 1);
        }
      }
    }
  }

  int _ttAt(double x, double y) => tt((x / cell).floor(), (y / cell).floor());
  bool walkable(double x, double y) => _ttAt(x, y) == 1;
  bool blocksShot(double x, double y) => _ttAt(x, y) == 0;

  Offset roomCenter(int idx) {
    final rr = rooms[idx.clamp(0, rooms.length - 1).toInt()];
    return Offset((rr.left + rr.width / 2) * cell,
        (rr.top + rr.height / 2) * cell);
  }

  Offset randomFloor(Random rng) {
    for (var i = 0; i < 260; i++) {
      final c = rng.nextInt(cols);
      final r = rng.nextInt(rows);
      if (tiles[r * cols + c] == 1) {
        return Offset((c + 0.5) * cell, (r + 0.5) * cell);
      }
    }
    return roomCenter(0);
  }

  static GameMap generate(Random rng, double sw, double sh, int wave) {
    const cell = 60.0;
    final cols = ((sw * 2.4) / cell).round().clamp(18, 42).toInt();
    final rows = ((sh * 2.4) / cell).round().clamp(18, 64).toInt();
    final m = GameMap(cols, rows, cell);
    final roomCount = 6 + rng.nextInt(4) + wave ~/ 4;
    final centers = <Point<int>>[];
    for (var i = 0; i < roomCount; i++) {
      // varied shapes: occasional big hall, occasional tight room
      final big = rng.nextDouble() < 0.22;
      final rw = (big ? 9 : 5) + rng.nextInt(big ? 7 : 6);
      final rh = (big ? 9 : 5) + rng.nextInt(big ? 7 : 6);
      final rx = 2 + rng.nextInt(max(1, cols - rw - 4));
      final ry = 2 + rng.nextInt(max(1, rows - rh - 4));
      for (var c = rx; c < rx + rw; c++) {
        for (var r = ry; r < ry + rh; r++) {
          m.set(c, r, 1);
        }
      }
      m.rooms.add(Rect.fromLTWH(
          rx.toDouble(), ry.toDouble(), rw.toDouble(), rh.toDouble()));
      centers.add(Point<int>(rx + rw ~/ 2, ry + rh ~/ 2));
    }
    void corridor(Point<int> a, Point<int> b) {
      for (var x = min(a.x, b.x); x <= max(a.x, b.x); x++) {
        m.set(x, a.y, 1);
        m.set(x, a.y + 1, 1);
      }
      for (var y = min(a.y, b.y); y <= max(a.y, b.y); y++) {
        m.set(b.x, y, 1);
        m.set(b.x + 1, y, 1);
      }
    }

    for (var i = 1; i < centers.length; i++) {
      corridor(centers[i - 1], centers[i]);
    }
    // a few extra loops so the layout is less linear
    final loops = 1 + rng.nextInt(3);
    for (var i = 0; i < loops && centers.length > 2; i++) {
      corridor(centers[rng.nextInt(centers.length)],
          centers[rng.nextInt(centers.length)]);
    }
    // interior obstacles: wall pillars + pools (keep room centers clear,
    // skip the start room so the player never spawns boxed in)
    for (var ri = 1; ri < m.rooms.length; ri++) {
      final rr = m.rooms[ri];
      if (rr.width < 7 || rr.height < 7) continue;
      final l = rr.left.toInt(), t = rr.top.toInt();
      final w = rr.width.toInt(), h = rr.height.toInt();
      final cc = l + w ~/ 2, cr = t + h ~/ 2;
      final poolBlobs = rng.nextDouble() < 0.85 ? (1 + rng.nextInt(2)) : 0;
      for (var pb = 0; pb < poolBlobs; pb++) {
        final pw = 2 + rng.nextInt(3);
        final ph = 2 + rng.nextInt(3);
        final px = l + 1 + rng.nextInt(max(1, w - pw - 2));
        final py = t + 1 + rng.nextInt(max(1, h - ph - 2));
        for (var c = px; c < px + pw; c++) {
          for (var r = py; r < py + ph; r++) {
            if (!(c == cc && r == cr)) m.set(c, r, 2);
          }
        }
      }
      if (rng.nextDouble() < 0.7) {
        final horiz = rng.nextBool();
        final len = 2 + rng.nextInt(3);
        final wx = l + 1 + rng.nextInt(max(1, w - 3));
        final wy = t + 1 + rng.nextInt(max(1, h - 3));
        for (var k = 0; k < len; k++) {
          final c = horiz ? wx + k : wx;
          final r = horiz ? wy : wy + k;
          if (!(c == cc && r == cr) && c < l + w - 1 && r < t + h - 1) {
            m.set(c, r, 0);
          }
        }
      }
    }
    return m;
  }
}

/// ---------------------------------------------------------------------------
/// Title
/// ---------------------------------------------------------------------------
class TitleScreen extends StatefulWidget {
  const TitleScreen({super.key});
  @override
  State<TitleScreen> createState() => _TitleScreenState();
}

class _TitleScreenState extends State<TitleScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          platform_fs.enterFullscreen();
          Navigator.of(context).pushReplacement(
              MaterialPageRoute<void>(builder: (_) => const HomeRoomScreen()));
        },
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('BUFF BATTLE',
                  style: TextStyle(
                      fontSize: 56,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 3,
                      color: Color(0xFFFFD45E))),
              const SizedBox(height: 8),
              const Text('pick a class · clear the rooms · get swole',
                  style: TextStyle(color: Colors.white54, fontSize: 13)),
              const SizedBox(height: 36),
              const Text('TAP TO ENTER',
                  style: TextStyle(
                      color: Color(0xFF8CC8FF),
                      fontWeight: FontWeight.w900,
                      fontSize: 16,
                      letterSpacing: 3)),
              const SizedBox(height: 40),
              if (GameStats.totalRuns > 0)
                Text(
                    'best: floor ${GameStats.bestFloor} · room ${GameStats.bestWave}',
                    style: const TextStyle(color: Colors.white38, fontSize: 11)),
            ],
          ),
        ),
      ),
    );
  }
}

/// ---------------------------------------------------------------------------
/// Home Room — the walkable hub that replaces the menu screen. Each altar
/// is a Door instance; stepping into one navigates to its sub-screen.
/// ---------------------------------------------------------------------------
class HomeRoomScreen extends StatefulWidget {
  const HomeRoomScreen({super.key});
  @override
  State<HomeRoomScreen> createState() => _HomeRoomScreenState();
}

class _HomeRoomScreenState extends State<HomeRoomScreen>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  Duration _last = Duration.zero;
  GameMap? _map;
  Player? _p;
  final List<Door> _altars = [];
  final Map<Door, double> _cool = {};
  final List<HomeNpc> _npcs = [];
  HomeNpc? _talking; // NPC the player is currently standing next to
  Offset _moveDir = Offset.zero;
  Offset _facing = const Offset(1, 0);
  double _elapsed = 0;
  Size _size = Size.zero;
  bool _ready = false;
  Door? _near;

  static const double _stickR = 60;
  bool _stickOn = false;
  Offset _stickOrigin = Offset.zero;
  Offset _stickKnob = Offset.zero;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_onTick)..start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    WorldPainter.resetCaches();
    super.dispose();
  }

  void _build() {
    WorldPainter.resetCaches();
    const cell = 60.0;
    const cols = 30, rows = 18;
    final m = GameMap(cols, rows, cell);

    // Carve three connected chambers separated by interior walls:
    //   LEFT (the Mirror) ── CORRIDOR ── CENTER (entrance + portal)
    //                                       ── CORRIDOR ── RIGHT (vault)
    void carve(int c0, int c1, int r0, int r1) {
      for (int c = c0; c <= c1; c++) {
        for (int r = r0; r <= r1; r++) {
          m.set(c, r, 1);
        }
      }
    }

    carve(2, 9, 3, 14); // LEFT chamber
    carve(12, 18, 3, 14); // CENTER hall
    carve(21, 27, 3, 14); // RIGHT vault
    carve(9, 12, 7, 10); // left ↔ center corridor (4 tiles wide, 4 tall)
    carve(18, 21, 7, 10); // center ↔ right corridor

    m.rooms
      ..add(const Rect.fromLTWH(2, 3, 8, 12))
      ..add(const Rect.fromLTWH(12, 3, 7, 12))
      ..add(const Rect.fromLTWH(21, 3, 7, 12));
    _map = m;

    final player = Player(kHeroes.first);
    // Spawn in the doorway of the center hall so the first thing the
    // player sees is the BEGIN RUN portal at the bottom of the room.
    player.pos = Offset(15.5 * cell, 11.5 * cell);
    player.speed = 300;
    _p = player;

    // Altars spread across the three chambers + corridor approaches.
    const lcx = 5.5; // left chamber center column
    const ccx = 15.5; // center hall center column
    const rcx = 24.0; // right vault center column

    _altars
      ..clear()
      ..addAll([
        // LEFT chamber — Mirror of Gains (back wall), Bestiary (front).
        Door(
          Offset(lcx * cell, 4.5 * cell),
          DoorDef('🪞', 'MIRROR OF GAINS', 'permanent stat upgrades',
              DoorKind.shop, (_) {}),
        ),
        Door(
          Offset(lcx * cell, 13.2 * cell),
          DoorDef(
              '📖', 'BESTIARY', "foes you've faced", DoorKind.shrine, (_) {}),
        ),
        // CENTER hall — Settings (top) and BEGIN RUN (the way out), plus
        // the two pre-run stands (Arsenal + Keepsake) on either side of
        // the portal so the player can tinker without leaving the room.
        Door(
          Offset(ccx * cell, 4.5 * cell),
          DoorDef('⚙', 'SETTINGS', 'audio · shake · haptics',
              DoorKind.shrine, (_) {}),
        ),
        Door(
          Offset((ccx - 2.0) * cell, 11.4 * cell),
          DoorDef('🗡', 'ARSENAL', 'pick your starting weapon',
              DoorKind.shrine, (_) {}),
        ),
        Door(
          Offset((ccx + 2.0) * cell, 11.4 * cell),
          DoorDef('🎁', 'KEEPSAKE STAND', 'equip a trinket',
              DoorKind.shrine, (_) {}),
        ),
        Door(
          Offset((ccx - 2.0) * cell, 7.5 * cell),
          DoorDef('🎯', 'TRAINING DUMMY',
              'preview damage + DPS', DoorKind.shrine, (_) {}),
        ),
        Door(
          Offset((ccx + 2.0) * cell, 7.5 * cell),
          DoorDef('💱', 'TRADE POST',
              'spend shards on run blessings', DoorKind.shrine, (_) {}),
        ),
        Door(
          Offset(ccx * cell, 13.2 * cell),
          DoorDef('⚔', 'BEGIN RUN', 'fight through the dungeon',
              DoorKind.reward, (_) {}),
        ),
        // RIGHT vault — Achievements (back) + Daily Challenge (front).
        Door(
          Offset(rcx * cell, 4.5 * cell),
          DoorDef(
              '🏆',
              'ACHIEVEMENTS',
              '${GameStats.achievements.length}/${kAchievements.length}',
              DoorKind.shrine, (_) {}),
        ),
        Door(
          Offset(rcx * cell, 13.2 * cell),
          DoorDef('🌞', 'DAILY CHALLENGE',
              "today's seeded dungeon", DoorKind.shrine, (_) {}),
        ),
      ]);
    for (final a in _altars) {
      _cool[a] = 0;
    }

    // NPCs that walk you through the home: a greeter who comments on each
    // return, a polishing trader by the daily altar, and a mentor by the
    // mirror who riffs on training. Names are Hades-flavored.
    _npcs
      ..clear()
      ..addAll([
        HomeNpc(
          id: 'hypnos',
          pos: Offset(ccx * cell - 80, 7.5 * cell),
          name: 'HYPNOS',
          icon: '😴',
          color: const Color(0xFFFFD45E),
          lines: _hypnosLines(),
        ),
        HomeNpc(
          id: 'dusa',
          pos: Offset((rcx - 1.4) * cell, 9 * cell),
          name: 'DUSA',
          icon: '👁',
          color: const Color(0xFF9B5CFF),
          lines: const [
            "oh! you startled me. don't, um — look too directly.",
            "i keep the floors clean. it's the least i can do.",
            "the lord says you're back. that's a 'good thing', isn't it?",
            "today's challenge is laid out. don't trip on the rug.",
            "be careful out there, my, um — yes. you.",
          ],
        ),
        HomeNpc(
          id: 'achilles',
          pos: Offset((lcx + 1.4) * cell, 9 * cell),
          name: 'ACHILLES',
          icon: '🛡',
          color: const Color(0xFF8CC8FF),
          lines: const [
            "strength is not luck. it is a habit.",
            "the mirror rewards the disciplined. spend wisely.",
            "i have seen many fall to the same trap twice.",
            "next time, dash THROUGH the attack. not away from it.",
            "keep your guard up, lad. the dungeon teaches the unprepared.",
          ],
        ),
        // Rescued NPCs: only appear at home after the player has freed them
        // from a captive event during a run.
        if (NpcStore.rescued.contains('smith'))
          HomeNpc(
            id: 'smith',
            pos: Offset(rcx * cell + 70, 7.5 * cell),
            name: 'THE SMITH',
            icon: '🔨',
            color: const Color(0xFFFFB347),
            lines: const [
              "set me free, you did. won't forget it.",
              "got nectar? i'll bless your edge for the next run.",
              "the hammer never lies. your blade is sharper than last week.",
              "ask, and i'll work the steel. that's the deal.",
            ],
          ),
        if (NpcStore.rescued.contains('chef'))
          HomeNpc(
            id: 'chef',
            pos: Offset((lcx + 1.4) * cell, 5.4 * cell),
            name: 'THE CHEF',
            icon: '🍞',
            color: const Color(0xFFB6FFC0),
            lines: const [
              "you saved me from that cell. i bake for free now.",
              "a small loaf, before you go? it's still warm.",
              "i pickle nectar bottles too. you'll find more on your travels.",
              "everything tastes better with a sharp edge — go see the smith.",
            ],
          ),
        if (NpcStore.rescued.contains('scribe'))
          HomeNpc(
            id: 'scribe',
            pos: Offset((rcx - 0.8) * cell, 5.4 * cell),
            name: 'THE SCRIBE',
            icon: '📜',
            color: const Color(0xFF8CC8FF),
            lines: const [
              "ink and quill — i record your every choice.",
              "twenty-three boons last week. your aim improves.",
              "a sharper eye is just a small etching away.",
              "the codex remembers what you forget.",
            ],
          ),
        if (NpcStore.rescued.contains('apothecary'))
          HomeNpc(
            id: 'apothecary',
            pos: Offset((ccx + 0.5) * cell, 5.4 * cell),
            name: 'THE APOTHECARY',
            icon: '🧪',
            color: const Color(0xFF8CFF98),
            lines: const [
              "salts, poultices, and a dash of nectar — that's the recipe.",
              "a slow heal beats a sudden hit. drink up.",
              "i've got herbs that knit you while you walk.",
              "next run — try not to bleed everywhere this time.",
            ],
          ),
      ]);
    for (final n in _npcs) {
      n.lineIdx = _rng.nextInt(n.lines.length);
    }

    _ready = true;
  }

  // Bottom-center stack of NPC actions: appears while the player is standing
  // next to an NPC. Each NPC has a gift button and (at ★+ affinity) their
  // own per-run blessing service.
  Widget _npcActionPanel() {
    final npc = _talking!;
    final tier = NpcStore.tierOf(npc.id);
    final hasNectar = NpcStore.nectar > 0;

    Widget button(String label, Color color, VoidCallback? onTap) {
      final enabled = onTap != null;
      return InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: enabled
                ? color.withValues(alpha: 0.18)
                : Colors.white12,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
                color: enabled ? color : Colors.white24, width: 1.4),
          ),
          child: Text(label,
              style: TextStyle(
                  color: enabled ? color : Colors.white38,
                  fontWeight: FontWeight.w900,
                  fontSize: 12,
                  letterSpacing: 1)),
        ),
      );
    }

    // Each NPC's blessing service: label, color, predicate, side-effect.
    final blessing = _blessingFor(npc.id, tier, hasNectar);
    final pendingNote = _pendingBlessingNote();

    return Positioned(
      bottom: 64,
      left: 0,
      right: 0,
      child: Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(
              '${npc.name} · friendship ${'★' * tier}${'☆' * (3 - tier)} (${NpcStore.affOf(npc.id)})',
              style: TextStyle(
                  color: npc.color,
                  fontWeight: FontWeight.w900,
                  fontSize: 11,
                  letterSpacing: 1.6)),
          const SizedBox(height: 6),
          Row(mainAxisSize: MainAxisSize.min, children: [
            button(
              hasNectar
                  ? '🍯 GIFT NECTAR'
                  : '🍯 NO NECTAR — DROPS FROM ELITES',
              const Color(0xFFFFD45E),
              hasNectar
                  ? () {
                      NpcStore.gift(npc.id);
                      npc.lineIdx = (npc.lineIdx + 1) % npc.lines.length;
                      setState(() {});
                    }
                  : null,
            ),
            if (blessing != null) ...[
              const SizedBox(width: 10),
              button(blessing.label, blessing.color, blessing.onTap),
            ],
          ]),
          if (_questRow(npc.id, tier) != null) _questRow(npc.id, tier)!,
          if (pendingNote != null)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(pendingNote,
                  style: const TextStyle(
                      color: Color(0xFFFFD45E), fontSize: 10)),
            ),
        ]),
      ),
    );
  }

  _NpcBlessing? _blessingFor(String id, int tier, bool hasNectar) {
    switch (id) {
      case 'smith':
        return _NpcBlessing(
          label: tier >= 1
              ? (hasNectar
                  ? '🔨 BLESS WEAPON +1 DMG (1🍯)'
                  : '🔨 NEED NECTAR')
              : '🔨 LOCKED — GIFT TO REACH ★',
          color: const Color(0xFFFFB347),
          onTap: tier >= 1 && hasNectar
              ? () {
                  NpcStore.nectar -= 1;
                  NpcStore.save();
                  Loadout.blessingDmg += 1;
                  setState(() {});
                }
              : null,
        );
      case 'hypnos':
        return _NpcBlessing(
          label: tier >= 1
              ? (hasNectar
                  ? '💤 SLEEP CHARM +5 MAX HP (1🍯)'
                  : '💤 NEED NECTAR')
              : '💤 LOCKED — GIFT TO REACH ★',
          color: const Color(0xFFFFD45E),
          onTap: tier >= 1 && hasNectar
              ? () {
                  NpcStore.nectar -= 1;
                  NpcStore.save();
                  Loadout.blessingHp += 5;
                  setState(() {});
                }
              : null,
        );
      case 'achilles':
        return _NpcBlessing(
          label: tier >= 1
              ? (hasNectar
                  ? '🛡 DRILL +1 REVIVE (1🍯)'
                  : '🛡 NEED NECTAR')
              : '🛡 LOCKED — GIFT TO REACH ★',
          color: const Color(0xFF8CC8FF),
          onTap: tier >= 1 && hasNectar
              ? () {
                  NpcStore.nectar -= 1;
                  NpcStore.save();
                  Loadout.blessingRevives += 1;
                  setState(() {});
                }
              : null,
        );
      case 'dusa':
        return _NpcBlessing(
          label: tier >= 1
              ? (hasNectar
                  ? '✨ POLISH +1 MP/SEC (1🍯)'
                  : '✨ NEED NECTAR')
              : '✨ LOCKED — GIFT TO REACH ★',
          color: const Color(0xFF9B5CFF),
          onTap: tier >= 1 && hasNectar
              ? () {
                  NpcStore.nectar -= 1;
                  NpcStore.save();
                  Loadout.blessingMpRegen += 1.0;
                  setState(() {});
                }
              : null,
        );
      case 'chef':
        return _NpcBlessing(
          label: tier >= 1
              ? (hasNectar
                  ? '🍞 MEAL +25% NECTAR DROPS (1🍯)'
                  : '🍞 NEED NECTAR')
              : '🍞 LOCKED — GIFT TO REACH ★',
          color: const Color(0xFFB6FFC0),
          onTap: tier >= 1 && hasNectar
              ? () {
                  NpcStore.nectar -= 1;
                  NpcStore.save();
                  Loadout.blessingNectarBonus += 0.25;
                  setState(() {});
                }
              : null,
        );
      case 'scribe':
        return _NpcBlessing(
          label: tier >= 1
              ? (hasNectar
                  ? '📜 ETCHING +5% CRIT (1🍯)'
                  : '📜 NEED NECTAR')
              : '📜 LOCKED — GIFT TO REACH ★',
          color: const Color(0xFF8CC8FF),
          onTap: tier >= 1 && hasNectar
              ? () {
                  NpcStore.nectar -= 1;
                  NpcStore.save();
                  Loadout.blessingCritChance += 0.05;
                  setState(() {});
                }
              : null,
        );
      case 'apothecary':
        return _NpcBlessing(
          label: tier >= 1
              ? (hasNectar
                  ? '🧪 POULTICE +1 HP/SEC (1🍯)'
                  : '🧪 NEED NECTAR')
              : '🧪 LOCKED — GIFT TO REACH ★',
          color: const Color(0xFF8CFF98),
          onTap: tier >= 1 && hasNectar
              ? () {
                  NpcStore.nectar -= 1;
                  NpcStore.save();
                  Loadout.blessingRegen += 1.0;
                  setState(() {});
                }
              : null,
        );
      default:
        return null;
    }
  }

  // Each NPC's ★★ quest: tracker label, target, and the permanent
  // reward applied once `questDone` includes their id. Reward effects
  // are wired in Player ctor / kill loop, so claim here is just bookkeeping.
  static const Map<String, ({String label, int target, String reward})>
      _quests = {
    'smith': (
      label: 'land lifetime crits',
      target: 200,
      reward: '+1 starting damage',
    ),
    'hypnos': (
      label: 'finish runs (win or lose)',
      target: 8,
      reward: '+5 starting max HP',
    ),
    'achilles': (
      label: 'defeat bosses',
      target: 10,
      reward: '+1 starting Death Defiance',
    ),
    'dusa': (
      label: 'collect nectar bottles',
      target: 30,
      reward: '+0.5 starting MP/sec',
    ),
    'chef': (
      label: 'kill grenadiers',
      target: 40,
      reward: '5% chance any kill drops nectar',
    ),
    'scribe': (
      label: 'pick boons in runs',
      target: 25,
      reward: '+0.05 starting crit chance',
    ),
    'apothecary': (
      label: 'pick up healing hearts',
      target: 25,
      reward: '+0.5 starting HP/sec regen',
    ),
  };

  Widget? _questRow(String id, int tier) {
    if (tier < 2) return null;
    final q = _quests[id];
    if (q == null) return null;
    final done = NpcStore.questDone.contains(id);
    final progress = NpcStore.qp(id);
    if (done) {
      return Padding(
        padding: const EdgeInsets.only(top: 6),
        child: Text('✓ QUEST CLAIMED · ${q.reward}',
            style: const TextStyle(
                color: Color(0xFF8CFF98),
                fontWeight: FontWeight.w900,
                fontSize: 10)),
      );
    }
    final ready = progress >= q.target;
    final clamped = progress.clamp(0, q.target);
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Column(children: [
        Text('QUEST · ${q.label} · $clamped/${q.target}',
            style: TextStyle(
                color: ready
                    ? const Color(0xFF8CFF98)
                    : Colors.white70,
                fontWeight: FontWeight.w900,
                fontSize: 10)),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(2),
          child: Container(
            width: 220,
            height: 5,
            color: const Color(0xFF1F1D2E),
            alignment: Alignment.centerLeft,
            child: FractionallySizedBox(
              widthFactor: clamped / q.target,
              child: Container(
                color:
                    ready ? const Color(0xFF8CFF98) : const Color(0xFFFFD45E),
              ),
            ),
          ),
        ),
        if (ready)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: () {
                NpcStore.questDone.add(id);
                NpcStore.save();
                setState(() {});
              },
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFF8CFF98).withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFF8CFF98)),
                ),
                child: Text('🎁 CLAIM · ${q.reward}',
                    style: const TextStyle(
                        color: Color(0xFF8CFF98),
                        fontWeight: FontWeight.w900,
                        fontSize: 11)),
              ),
            ),
          ),
      ]),
    );
  }

  // Summary line so the player sees what's stacked on the next run.
  String? _pendingBlessingNote() {
    final parts = <String>[];
    if (Loadout.blessingDmg > 0) parts.add('+${Loadout.blessingDmg} dmg');
    if (Loadout.blessingHp > 0) parts.add('+${Loadout.blessingHp} max HP');
    if (Loadout.blessingRevives > 0) {
      parts.add('+${Loadout.blessingRevives} revive');
    }
    if (Loadout.blessingMpRegen > 0) {
      parts.add('+${Loadout.blessingMpRegen.toStringAsFixed(1)} MP/s');
    }
    if (Loadout.blessingNectarBonus > 0) {
      parts.add('+${(Loadout.blessingNectarBonus * 100).round()}% nectar');
    }
    return parts.isEmpty ? null : 'next run blessings: ${parts.join(' · ')}';
  }

  // The greeter's lines fold in the player's lifetime run count so each
  // return feels like Hypnos is actually keeping score.
  List<String> _hypnosLines() {
    final n = GameStats.totalRuns;
    return [
      n == 0
          ? "first time in the house? mind the rug."
          : "back again? that makes $n attempt${n == 1 ? '' : 's'}.",
      "you smell like ash. and floor 1, mostly.",
      "the portal at the bottom of the hall — that's the one.",
      "don't forget the mirror. permanent gains compound, you know.",
      "i keep tallies. you're welcome.",
      if (GameStats.bestFloor >= 3)
        "your best is floor ${GameStats.bestFloor}. impressive. for now.",
      if (GameStats.totalBossKills > 0)
        "${GameStats.totalBossKills} boss kill${GameStats.totalBossKills == 1 ? '' : 's'}. not bad. not great.",
    ];
  }

  static final Random _rng = Random();

  void _onTick(Duration elapsed) {
    if (!_ready || _map == null || _p == null) {
      _last = elapsed;
      return;
    }
    var dt = (elapsed - _last).inMicroseconds / 1e6;
    _last = elapsed;
    if (dt > 1 / 30) dt = 1 / 30;
    _elapsed += dt;
    for (final a in _altars) {
      final c = _cool[a];
      if (c != null && c > 0) _cool[a] = c - dt;
    }
    final p = _p!;
    if (_moveDir != Offset.zero) {
      p.pos = _slide(p.pos, _moveDir * p.speed * dt, p.radius * 0.7);
      _facing = _moveDir;
    }
    Door? closest;
    var closestD = 1e9;
    for (final a in _altars) {
      final d = (a.pos - p.pos).distance;
      if (d < closestD) {
        closestD = d;
        closest = a;
      }
    }
    _near = (closest != null && closestD < 80) ? closest : null;
    if (closest != null &&
        closestD < p.radius + closest.r * 0.7 &&
        (_cool[closest] ?? 0) <= 0) {
      _cool[closest] = 1.6;
      _activate(closest);
    }

    // NPC dialog: pick a fresh line whenever the player enters a chat range
    // they weren't in last frame, so they can step away and back to cycle.
    HomeNpc? talking;
    for (final n in _npcs) {
      n.bob += dt;
      final inRange = (n.pos - p.pos).distance < 90;
      if (inRange && !n.wasNear) {
        n.lineIdx = (n.lineIdx + 1) % n.lines.length;
      }
      n.wasNear = inRange;
      if (inRange) talking = n;
    }
    _talking = talking;

    setState(() {});
  }

  Future<void> _activate(Door a) async {
    final label = a.def.title;
    Widget? route;
    bool resetOnReturn = true;
    if (label == 'BEGIN RUN') {
      Loadout.dailySeed = null;
      Loadout.dailyKey = null;
      platform_fs.enterFullscreen();
      route = const CharacterSelectScreen();
    } else if (label == 'DAILY CHALLENGE') {
      Loadout.dailyKey = Loadout.todayKey();
      Loadout.dailySeed = Loadout.todaySeed();
      platform_fs.enterFullscreen();
      route = const CharacterSelectScreen();
    } else if (label == 'MIRROR OF GAINS') {
      route = const HomeScreen();
    } else if (label == 'BESTIARY') {
      route = const BestiaryScreen();
      resetOnReturn = false;
    } else if (label == 'ACHIEVEMENTS') {
      route = const AchievementsScreen();
    } else if (label == 'SETTINGS') {
      route = const SettingsScreen();
      resetOnReturn = false;
    } else if (label == 'KEEPSAKE STAND') {
      route = const KeepsakeStandScreen();
      resetOnReturn = false;
    } else if (label == 'ARSENAL') {
      route = const ArsenalScreen();
      resetOnReturn = false;
    } else if (label == 'TRADE POST') {
      route = const TradePostScreen();
      resetOnReturn = false;
    } else if (label == 'TRAINING DUMMY') {
      route = const TrainingDummyScreen();
      resetOnReturn = false;
    }
    if (route == null) return;
    final w = route;
    await Navigator.of(context)
        .push(MaterialPageRoute<void>(builder: (_) => w));
    if (!mounted) return;
    if (resetOnReturn) {
      setState(_build);
    } else {
      setState(() {});
    }
  }

  bool _free(Offset p, double rad) {
    final m = _map;
    if (m == null) return false;
    return m.walkable(p.dx, p.dy) &&
        m.walkable(p.dx - rad, p.dy) &&
        m.walkable(p.dx + rad, p.dy) &&
        m.walkable(p.dx, p.dy - rad) &&
        m.walkable(p.dx, p.dy + rad);
  }

  Offset _slide(Offset pos, Offset delta, double rad) {
    var nx = pos.dx;
    var ny = pos.dy;
    if (_free(Offset(pos.dx + delta.dx, pos.dy), rad)) nx = pos.dx + delta.dx;
    if (_free(Offset(nx, pos.dy + delta.dy), rad)) ny = pos.dy + delta.dy;
    return Offset(nx, ny);
  }

  void _panStart(DragStartDetails d) {
    _stickOn = true;
    _stickOrigin = d.localPosition;
    _stickKnob = d.localPosition;
  }

  void _panUpdate(DragUpdateDetails d) {
    if (!_stickOn) return;
    var delta = d.localPosition - _stickOrigin;
    if (delta.distance > _stickR) {
      delta = delta / delta.distance * _stickR;
    }
    _stickKnob = _stickOrigin + delta;
    final screen = delta / _stickR;
    final world = isoUnproject(screen);
    _moveDir = world == Offset.zero
        ? Offset.zero
        : world / world.distance * screen.distance;
  }

  void _panEnd(_) {
    _stickOn = false;
    _moveDir = Offset.zero;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: LayoutBuilder(builder: (context, c) {
        final s = Size(c.maxWidth, c.maxHeight);
        if (s != _size) {
          _size = s;
          if (!_ready) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) setState(_build);
            });
          }
        }
        return GestureDetector(
          onPanStart: _panStart,
          onPanUpdate: _panUpdate,
          onPanEnd: _panEnd,
          child: Stack(
            fit: StackFit.expand,
            children: [
              Positioned.fill(
                child: RepaintBoundary(
                  child: CustomPaint(
                    isComplex: true,
                    willChange: true,
                    painter: WorldPainter(
                      player: _p ?? Player(kHeroes.first),
                      enemies: const <Enemy>[],
                      bolts: const <Bolt>[],
                      ebolts: const <EBolt>[],
                      grenades: const <Grenade>[],
                      homeNpcs: _npcs,
                      talkingNpc: _talking,
                      orbs: const <Orb>[],
                      hearts: const <Heart>[],
                      bursts: const <Burst>[],
                      texts: const <FloatText>[],
                      doors: _altars,
                      swings: const <Swing>[],
                      ghosts: const <Ghost>[],
                      traps: const <Trap>[],
                      ballistas: const <Ballista>[],
                      map: _ready ? _map : null,
                      floor: kHomeFloor,
                      time: _elapsed,
                      facing: _facing,
                      moving: _moveDir != Offset.zero,
                      shake: 0,
                      lowHp: false,
                      stickOn: _stickOn,
                      stickOrigin: _stickOrigin,
                      stickKnob: _stickKnob,
                      ready: _ready,
                    ),
                  ),
                ),
              ),
              Positioned(
                top: 14,
                left: 0,
                right: 0,
                child: Column(children: [
                  const Text('HOUSE OF GAINS',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          color: Color(0xFFFFD45E),
                          fontWeight: FontWeight.w900,
                          fontSize: 18,
                          letterSpacing: 3)),
                  const SizedBox(height: 2),
                  Text(
                      _near != null
                          ? '${_near!.def.title} — step in to use'
                          : 'drag to walk · step into an altar',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          color: _near != null
                              ? const Color(0xFFFFD45E)
                              : Colors.white54,
                          fontSize: 11)),
                ]),
              ),
              Positioned(
                top: 14,
                right: 16,
                child: Row(children: [
                  InkWell(
                    borderRadius: BorderRadius.circular(8),
                    onTap: () async {
                      await Navigator.of(context).push(
                          MaterialPageRoute<void>(
                              builder: (_) =>
                                  const RelationshipsScreen()));
                      if (mounted) setState(_build);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xCC1F1D2E),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFFF8AB4)),
                      ),
                      child: const Text('💞 BONDS',
                          style: TextStyle(
                              color: Color(0xFFFF8AB4),
                              fontWeight: FontWeight.w900,
                              fontSize: 11,
                              letterSpacing: 1)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text('🍯 ${NpcStore.nectar}',
                      style: const TextStyle(
                          color: Color(0xFFFFD45E),
                          fontWeight: FontWeight.w900,
                          fontSize: 14)),
                  const SizedBox(width: 12),
                  Text('🔷 ${MetaStore.shards}',
                      style: const TextStyle(
                          color: Color(0xFF8CC8FF),
                          fontWeight: FontWeight.w900,
                          fontSize: 14)),
                ]),
              ),
              if (_talking != null) _npcActionPanel(),
              Positioned(
                bottom: 16,
                right: 16,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xCC14131F),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFFF8A4C)),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    InkWell(
                      onTap: () => setState(() => Loadout.heat =
                          (Loadout.heat - 1).clamp(0, 10).toInt()),
                      child: const Icon(Icons.remove,
                          size: 18, color: Colors.white70),
                    ),
                    const SizedBox(width: 8),
                    Text('🔥 HEAT ${Loadout.heat}',
                        style: const TextStyle(
                            color: Color(0xFFFF8A4C),
                            fontWeight: FontWeight.w900,
                            fontSize: 12)),
                    const SizedBox(width: 8),
                    InkWell(
                      onTap: () => setState(() => Loadout.heat =
                          (Loadout.heat + 1).clamp(0, 10).toInt()),
                      child: const Icon(Icons.add,
                          size: 18, color: Colors.white70),
                    ),
                  ]),
                ),
              ),
              if (Loadout.dailyKey != null &&
                  GameStats.dailyBest[Loadout.todayKey()] != null)
                Positioned(
                  bottom: 16,
                  left: 16,
                  child: Text(
                      "today's best · ${GameStats.dailyBest[Loadout.todayKey()]}",
                      style: const TextStyle(
                          color: Color(0xFFFF8A4C), fontSize: 11)),
                ),
            ],
          ),
        );
      }),
    );
  }
}

/// ---------------------------------------------------------------------------
/// Home / Mirror
/// ---------------------------------------------------------------------------
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('HOME · MIRROR OF GAINS')),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            color: const Color(0xFF1F1D2E),
            child: Text('🔷 ${MetaStore.shards} shards',
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF8CC8FF))),
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Text(
                'Earn shards every run. Spend them for permanent boosts.',
                style: TextStyle(color: Colors.white54, fontSize: 12)),
          ),
          Expanded(child: _buildTree()),
        ],
      ),
    );
  }

  // Mirror-of-Gains is split into three thematic branches so the meta
  // upgrade list reads like a small tree rather than a flat shopping list.
  static const Map<String, List<String>> _branches = {
    'COMBAT': ['dmg', 'crit', 'splash'],
    'SURVIVAL': ['hp', 'rev', 'life'],
    'UTILITY': ['spd', 'dash', 'vis', 'mp', 'gold'],
  };

  Widget _buildTree() {
    final children = <Widget>[];
    _branches.forEach((branch, ids) {
      children.add(Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 6),
        child: Text(branch,
            style: const TextStyle(
                color: Color(0xFFFFD45E),
                fontWeight: FontWeight.w900,
                letterSpacing: 1.6)),
      ));
      for (final id in ids) {
        final m = kMeta.firstWhere((x) => x.id == id);
        children.add(Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
          child: _metaRow(m),
        ));
      }
    });
    return ListView(children: children);
  }

  Widget _metaRow(MetaUpgrade m) {
    final lv = MetaStore.lvlOf(m.id);
    final maxed = lv >= m.maxLvl;
    final cost = MetaStore.costFor(m.id);
    final afford = MetaStore.shards >= cost;
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: maxed
          ? null
          : () {
              if (MetaStore.buy(m)) setState(() {});
            },
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFF1F1D2E),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
              color: maxed
                  ? const Color(0xFF8CFF98)
                  : (afford
                      ? const Color(0xFF8CC8FF)
                      : Colors.white24)),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(m.title,
                      style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                          color: Colors.white)),
                  Text(m.desc,
                      style: const TextStyle(
                          color: Colors.white54, fontSize: 12)),
                  const SizedBox(height: 6),
                  _metaPips(lv, m.maxLvl),
                ],
              ),
            ),
            Text(maxed ? 'MAX' : '🔷$cost',
                style: TextStyle(
                    fontWeight: FontWeight.w900,
                    color: maxed
                        ? const Color(0xFF8CFF98)
                        : const Color(0xFF8CC8FF))),
          ],
        ),
      ),
    );
  }

  Widget _metaPips(int lv, int max) {
    return Row(children: [
      for (int i = 0; i < max; i++)
        Container(
          width: 12,
          height: 6,
          margin: const EdgeInsets.only(right: 3),
          decoration: BoxDecoration(
            color: i < lv
                ? const Color(0xFF8CC8FF)
                : Colors.white12,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
    ]);
  }
}

/// ---------------------------------------------------------------------------
/// Character select
/// ---------------------------------------------------------------------------
/// One row in the rotating Trade Post inventory. Effects either bump a
/// blessing field (consumed at run start) or top up the persistent stash.
class _TradeOffer {
  const _TradeOffer(this.label, this.desc, this.cost, this.apply);
  final String label;
  final String desc;
  final int cost; // in 🔷 shards
  final void Function() apply;
}

class TradePostScreen extends StatefulWidget {
  const TradePostScreen({super.key});
  @override
  State<TradePostScreen> createState() => _TradePostScreenState();
}

class _TradePostScreenState extends State<TradePostScreen> {
  static final Random _rng = Random();
  late List<_TradeOffer> _stock;

  // Pool of possible wares. The shop rolls a fresh subset every visit /
  // reroll; each consumes shards on purchase and applies its effect.
  static final List<_TradeOffer> _pool = [
    _TradeOffer('🍯 BOTTLE OF NECTAR', '+2 nectar in your stash', 6, () {
      NpcStore.nectar += 2;
      NpcStore.lifetimeNectar += 2;
      NpcStore.save();
    }),
    _TradeOffer('🗡 IRON SCRAP', '+1 starting damage next run', 10,
        () => Loadout.blessingDmg += 1),
    _TradeOffer('❤ HEALTH POTION', '+5 starting max HP next run', 8,
        () => Loadout.blessingHp += 5),
    _TradeOffer('🛡 HOLY TALISMAN', '+1 starting Death Defiance', 16,
        () => Loadout.blessingRevives += 1),
    _TradeOffer('🔮 ETHER VIAL', '+1 starting MP/sec next run', 10,
        () => Loadout.blessingMpRegen += 1.0),
    _TradeOffer('🌟 SHARPENING OIL', '+5% crit next run', 12,
        () => Loadout.blessingCritChance += 0.05),
    _TradeOffer('🧪 STEADY TONIC', '+1 HP/sec regen next run', 10,
        () => Loadout.blessingRegen += 1.0),
    _TradeOffer('💰 LUCKY COIN', '+50 starting obols next run', 6,
        () => Loadout.startingObols += 50),
  ];

  static const int _slots = 4;
  static const int _rerollCost = 2;

  @override
  void initState() {
    super.initState();
    _stock = _rollStock();
  }

  List<_TradeOffer> _rollStock() {
    final copy = List<_TradeOffer>.from(_pool)..shuffle(_rng);
    return copy.take(_slots).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('TRADE POST')),
      body: Column(children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          color: const Color(0xFF1F1D2E),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('🔷 ${MetaStore.shards} shards',
                  style: const TextStyle(
                      color: Color(0xFF8CC8FF),
                      fontWeight: FontWeight.w900)),
              Text('🍯 ${NpcStore.nectar}',
                  style: const TextStyle(
                      color: Color(0xFFFFD45E),
                      fontWeight: FontWeight.w900)),
            ],
          ),
        ),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.all(14),
            itemCount: _stock.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (_, i) {
              final o = _stock[i];
              final afford = MetaStore.shards >= o.cost;
              return InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: afford
                    ? () {
                        MetaStore.shards -= o.cost;
                        MetaStore.save();
                        o.apply();
                        setState(() {
                          _stock = _stock
                              .where((x) => x != o)
                              .toList(growable: false);
                        });
                      }
                    : null,
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1F1D2E),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                        color: afford
                            ? const Color(0xFFFFD45E)
                            : Colors.white24),
                  ),
                  child: Row(children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(o.label,
                              style: const TextStyle(
                                  color: Color(0xFFFFD45E),
                                  fontWeight: FontWeight.w900,
                                  fontSize: 15)),
                          Text(o.desc,
                              style: const TextStyle(
                                  color: Colors.white70, fontSize: 12)),
                        ],
                      ),
                    ),
                    Text('🔷${o.cost}',
                        style: TextStyle(
                            color: afford
                                ? const Color(0xFF8CC8FF)
                                : Colors.white38,
                            fontWeight: FontWeight.w900)),
                  ]),
                ),
              );
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(14),
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: MetaStore.shards >= _rerollCost
                ? () {
                    MetaStore.shards -= _rerollCost;
                    MetaStore.save();
                    setState(() => _stock = _rollStock());
                  }
                : null,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0x118CC8FF),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFF8CC8FF)),
              ),
              child: Center(
                child: Text('REROLL STOCK · 🔷$_rerollCost',
                    style: TextStyle(
                        color: MetaStore.shards >= _rerollCost
                            ? const Color(0xFF8CC8FF)
                            : Colors.white38,
                        fontWeight: FontWeight.w900,
                        fontSize: 13,
                        letterSpacing: 2)),
              ),
            ),
          ),
        ),
      ]),
    );
  }
}

/// Training Dummy: shows the player's projected DPS for the active
/// loadout and lets them tap a dummy to see crits / hits land live.
class TrainingDummyScreen extends StatefulWidget {
  const TrainingDummyScreen({super.key});
  @override
  State<TrainingDummyScreen> createState() => _TrainingDummyScreenState();
}

class _TrainingDummyScreenState extends State<TrainingDummyScreen>
    with SingleTickerProviderStateMixin {
  static final Random _rng = Random();
  late Player _p;
  final List<FloatText> _hits = [];
  double _dummyHp = 200;
  double _dummyMax = 200;
  late final Ticker _ticker;
  Duration _last = Duration.zero;
  // Window timer for DPS estimate.
  double _windowDamage = 0;
  double _windowT = 0;
  double _displayedDps = 0;

  @override
  void initState() {
    super.initState();
    _p = Player(kHeroes.first);
    Loadout.keepsake?.apply(_p);
    // Apply pending blessings READ-ONLY for the preview, so the player
    // sees what their next-run damage will look like.
    _p.damage += Loadout.blessingDmg;
    _p.maxHp += Loadout.blessingHp;
    _p.mpRegen += Loadout.blessingMpRegen;
    _p.critChance += Loadout.blessingCritChance;
    if (Loadout.startingWeapon != null) _p.weapon = Loadout.startingWeapon!;
    _ticker = createTicker((elapsed) {
      var dt = (elapsed - _last).inMicroseconds / 1e6;
      _last = elapsed;
      if (dt > 1 / 30) dt = 1 / 30;
      _windowT += dt;
      for (final h in _hits) {
        h.pos = h.pos.translate(0, -45 * dt);
        h.life -= dt;
      }
      _hits.removeWhere((h) => h.life <= 0);
      if (_windowT > 1.0) {
        _displayedDps = _windowDamage / _windowT;
        _windowDamage = 0;
        _windowT = 0;
      }
      setState(() {});
    })
      ..start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  void _strike() {
    final crit = _rng.nextDouble() < _p.critChance;
    final dmg = _p.damage * (crit ? 1.8 : 1.0) * _p.weapon.dmgMul;
    _dummyHp -= dmg;
    _windowDamage += dmg;
    _hits.add(FloatText(
      const Offset(0, 0),
      '${dmg.toStringAsFixed(1)}${crit ? '!' : ''}',
      crit ? const Color(0xFFFF9A3C) : Colors.white,
      size: crit ? 22 : 14,
    ));
    if (_dummyHp <= 0) {
      _dummyHp = _dummyMax;
    }
  }

  @override
  Widget build(BuildContext context) {
    final dpsEstimate =
        _p.damage * _p.weapon.dmgMul / (_p.fireInterval * _p.weapon.rofMul);
    return Scaffold(
      appBar: AppBar(title: const Text('TRAINING DUMMY')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(children: [
          // Loadout summary tile.
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFF1F1D2E),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFFFD45E)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('WEAPON · ${_p.weapon.name}',
                    style: const TextStyle(
                        color: Color(0xFFFFD45E),
                        fontWeight: FontWeight.w900,
                        fontSize: 13)),
                const SizedBox(height: 4),
                Text(
                    'dmg/hit ${(_p.damage * _p.weapon.dmgMul).toStringAsFixed(1)}  ·  fire ${(_p.fireInterval * _p.weapon.rofMul).toStringAsFixed(2)}s  ·  crit ${(_p.critChance * 100).round()}%',
                    style: const TextStyle(
                        color: Colors.white70, fontSize: 11)),
                const SizedBox(height: 2),
                Text(
                    'theoretical DPS ${dpsEstimate.toStringAsFixed(1)}  ·  live DPS ${_displayedDps.toStringAsFixed(1)}',
                    style: const TextStyle(
                        color: Color(0xFF8CFF98), fontSize: 11)),
              ],
            ),
          ),
          const SizedBox(height: 28),
          Expanded(
            child: Center(
              child: Stack(
                clipBehavior: Clip.none,
                alignment: Alignment.center,
                children: [
                  GestureDetector(
                    onTap: _strike,
                    child: Container(
                      width: 180,
                      height: 180,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: const RadialGradient(
                          center: Alignment(-0.3, -0.4),
                          colors: [
                            Color(0xFFB87333),
                            Color(0xFF4F2F18),
                          ],
                        ),
                        border: Border.all(
                            color: const Color(0xFFFFD45E), width: 3),
                      ),
                      child: const Center(
                          child: Text('🎯',
                              style: TextStyle(fontSize: 64))),
                    ),
                  ),
                  for (final h in _hits)
                    Transform.translate(
                      offset: h.pos,
                      child: Opacity(
                        opacity: h.life.clamp(0.0, 1.0).toDouble(),
                        child: Text(h.text,
                            style: TextStyle(
                                color: h.color,
                                fontWeight: FontWeight.w900,
                                fontSize: h.size + 4,
                                fontFamily: 'RobotoMono')),
                      ),
                    ),
                ],
              ),
            ),
          ),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: Container(
              width: double.infinity,
              height: 10,
              color: const Color(0xFF1F1D2E),
              alignment: Alignment.centerLeft,
              child: FractionallySizedBox(
                widthFactor: (_dummyHp / _dummyMax).clamp(0.0, 1.0),
                child: Container(color: const Color(0xFFFF5C6C)),
              ),
            ),
          ),
          const SizedBox(height: 8),
          const Text('tap the dummy to swing',
              style: TextStyle(color: Colors.white54, fontSize: 11)),
          const SizedBox(height: 16),
        ]),
      ),
    );
  }
}

/// Pre-run keepsake picker — same look as the post-character-select one
/// but it just pops back to the home so the player can keep tinkering.
class KeepsakeStandScreen extends StatelessWidget {
  const KeepsakeStandScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final list = availableKeepsakes();
    Widget tile({required String name, required String desc,
        required Color color, required VoidCallback onTap}) {
      return InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(14),
          margin: const EdgeInsets.only(bottom: 10),
          decoration: BoxDecoration(
            color: const Color(0xFF1F1D2E),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: color),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(name,
                  style: TextStyle(
                      color: color,
                      fontWeight: FontWeight.w900,
                      fontSize: 15)),
              const SizedBox(height: 2),
              Text(desc,
                  style: const TextStyle(
                      color: Colors.white70, fontSize: 12)),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('KEEPSAKE STAND')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          tile(
              name: 'NO KEEPSAKE',
              desc: Loadout.keepsake == null
                  ? 'currently selected'
                  : 'unequip your current keepsake',
              color: Loadout.keepsake == null
                  ? const Color(0xFFFFD45E)
                  : Colors.white24,
              onTap: () {
                Loadout.keepsake = null;
                Navigator.of(context).pop();
              }),
          for (final k in list)
            tile(
                name:
                    '${k.name}${Loadout.keepsake == k ? '  ★' : ''}',
                desc: k.desc,
                color: Loadout.keepsake == k
                    ? const Color(0xFFFFD45E)
                    : const Color(0xFF8CC8FF),
                onTap: () {
                  Loadout.keepsake = k;
                  Navigator.of(context).pop();
                }),
        ],
      ),
    );
  }
}

/// Arsenal: pick which weapon you start the next run with. Null falls back
/// to the hero's default SIDEARM at run init.
class ArsenalScreen extends StatelessWidget {
  const ArsenalScreen({super.key});
  @override
  Widget build(BuildContext context) {
    Widget tile(WeaponDef? w) {
      final selected = identical(Loadout.startingWeapon, w);
      final name = w == null ? kDefaultWeapon.name : w.name;
      final desc = w == null ? 'hero default — ${kDefaultWeapon.desc}' : w.desc;
      return InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () {
          Loadout.startingWeapon = w;
          Navigator.of(context).pop();
        },
        child: Container(
          padding: const EdgeInsets.all(14),
          margin: const EdgeInsets.only(bottom: 10),
          decoration: BoxDecoration(
            color: const Color(0xFF1F1D2E),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
                color: selected
                    ? const Color(0xFFFFD45E)
                    : const Color(0xFFFFB347),
                width: selected ? 2 : 1),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Text(name,
                    style: const TextStyle(
                        color: Color(0xFFFFD45E),
                        fontWeight: FontWeight.w900,
                        fontSize: 15)),
                if (selected) ...[
                  const SizedBox(width: 6),
                  const Text('★',
                      style: TextStyle(color: Color(0xFFFFD45E))),
                ],
              ]),
              const SizedBox(height: 2),
              Text(desc,
                  style: const TextStyle(
                      color: Colors.white70, fontSize: 12)),
              if (w != null) ...[
                const SizedBox(height: 4),
                Text(
                    'dmg ×${w.dmgMul.toStringAsFixed(2)}  rof ×${w.rofMul.toStringAsFixed(2)}  spd ×${w.speedMul.toStringAsFixed(2)}',
                    style: const TextStyle(
                        color: Colors.white38, fontSize: 11)),
              ],
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('ARSENAL')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          tile(null),
          for (final w in kWeapons) tile(w),
        ],
      ),
    );
  }
}

class RelationshipsScreen extends StatelessWidget {
  const RelationshipsScreen({super.key});

  // Catalog every NPC in the house plus the rescuables. Locked-out
  // rescuables show as silhouettes so the player has something to chase.
  static const _entries = [
    (
      id: 'hypnos',
      name: 'HYPNOS',
      icon: '😴',
      role: 'GREETER',
      color: Color(0xFFFFD45E),
      rescuable: false,
    ),
    (
      id: 'achilles',
      name: 'ACHILLES',
      icon: '🛡',
      role: 'MENTOR',
      color: Color(0xFF8CC8FF),
      rescuable: false,
    ),
    (
      id: 'dusa',
      name: 'DUSA',
      icon: '👁',
      role: 'ATTENDANT',
      color: Color(0xFF9B5CFF),
      rescuable: false,
    ),
    (
      id: 'smith',
      name: 'THE SMITH',
      icon: '🔨',
      role: 'BLACKSMITH',
      color: Color(0xFFFFB347),
      rescuable: true,
    ),
    (
      id: 'chef',
      name: 'THE CHEF',
      icon: '🍞',
      role: 'COOK',
      color: Color(0xFFB6FFC0),
      rescuable: true,
    ),
    (
      id: 'scribe',
      name: 'THE SCRIBE',
      icon: '📜',
      role: 'CODEX-KEEPER',
      color: Color(0xFF8CC8FF),
      rescuable: true,
    ),
    (
      id: 'apothecary',
      name: 'THE APOTHECARY',
      icon: '🧪',
      role: 'HEALER',
      color: Color(0xFF8CFF98),
      rescuable: true,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('BONDS · RELATIONSHIPS')),
      body: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: _entries.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (_, i) {
          final e = _entries[i];
          final rescued =
              !e.rescuable || NpcStore.rescued.contains(e.id);
          final tier = NpcStore.tierOf(e.id);
          final aff = NpcStore.affOf(e.id);
          final qDone = NpcStore.questDone.contains(e.id);
          return Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFF1F1D2E),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                  color: rescued ? e.color : Colors.white12,
                  width: rescued ? 1.4 : 1),
            ),
            child: Row(children: [
              Container(
                width: 44,
                height: 44,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: rescued
                      ? e.color.withValues(alpha: 0.2)
                      : Colors.white12,
                  shape: BoxShape.circle,
                  border: Border.all(
                      color: rescued ? e.color : Colors.white24),
                ),
                child: Text(rescued ? e.icon : '?',
                    style: const TextStyle(
                        fontSize: 22, fontFamily: 'NotoEmoji')),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(rescued ? e.name : '???',
                        style: TextStyle(
                            color: rescued
                                ? Colors.white
                                : Colors.white38,
                            fontWeight: FontWeight.w900,
                            fontSize: 15)),
                    Text(rescued ? e.role : 'captive — find them in a run',
                        style: TextStyle(
                            color: rescued
                                ? e.color
                                : Colors.white38,
                            fontSize: 11,
                            letterSpacing: 1)),
                    if (rescued) ...[
                      const SizedBox(height: 4),
                      Text(
                          'friendship ${'★' * tier}${'☆' * (3 - tier)} ($aff)',
                          style: const TextStyle(
                              color: Colors.white70, fontSize: 11)),
                      if (qDone)
                        const Padding(
                          padding: EdgeInsets.only(top: 2),
                          child: Text('✓ quest claimed',
                              style: TextStyle(
                                  color: Color(0xFF8CFF98), fontSize: 10)),
                        ),
                    ],
                  ],
                ),
              ),
            ]),
          );
        },
      ),
    );
  }
}

class BestiaryScreen extends StatelessWidget {
  const BestiaryScreen({super.key});

  static const _entries = [
    (0, 'GRUNT', Color(0xFFB6FFC0),
        'baseline cube. low HP, modest damage, wanders straight at you.'),
    (1, 'SWIFT', Color(0xFFFF8A4C),
        'fast and fragile. closes range in a hurry — dash or kite.'),
    (2, 'BRUTE', Color(0xFF9B5CFF),
        'slow, beefy. hits hard up close, but easy to outpace.'),
    (3, 'BOSS', Color(0xFFFF3B5C),
        'floor warden. winds up a telegraphed nova every few seconds.'),
    (4, 'SHOOTER', Color(0xFF4CD2C0),
        'kites and lobs bolts. may shoot frost or fire from deeper floors.'),
    (5, 'SHIELDED', Color(0xFF9CA8B5),
        'steel brute. takes half damage above 50% HP — break the armor.'),
    (6, 'FROST', Color(0xFFA9E8FF),
        'chills you on contact, halving your move speed for a moment.'),
    (7, 'VAMPIRE', Color(0xFF8E1A2B),
        'heals from any damage it lands on you. do not let it touch.'),
    (8, 'KAMIKAZE', Color(0xFFFF6432),
        'fast, fragile, explodes in a wide AoE the instant it reaches you.'),
    (9, 'GRENADIER', Color(0xFF5C8A3C),
        'keeps distance and lobs arcing grenades. dodge the orange ring.'),
    (10, 'BULL', Color(0xFF5C3A22),
        'paws the ground, then charges in a straight line. sidestep the beam.'),
    (11, 'SLAMMER', Color(0xFFB94CFF),
        'leaps into the air and slams your last known spot — keep moving.'),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('BESTIARY')),
      body: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: _entries.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (_, i) {
          final (kind, name, color, desc) = _entries[i];
          final kills = GameStats.killsByKind[kind] ?? 0;
          final seen = kills > 0;
          return Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFF1F1D2E),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: seen ? color : Colors.white12),
            ),
            child: Row(children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: seen ? color : Colors.white12,
                  shape: BoxShape.circle,
                  boxShadow: seen
                      ? [BoxShadow(color: color.withValues(alpha: 0.5), blurRadius: 12)]
                      : null,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(seen ? name : '???',
                        style: TextStyle(
                            color: seen ? Colors.white : Colors.white38,
                            fontWeight: FontWeight.w900,
                            fontSize: 15)),
                    Text(seen ? desc : 'undiscovered — defeat one to reveal',
                        style: const TextStyle(
                            color: Colors.white54, fontSize: 12)),
                  ],
                ),
              ),
              Text(seen ? '$kills' : '—',
                  style: TextStyle(
                      color: seen ? color : Colors.white38,
                      fontWeight: FontWeight.w900)),
            ]),
          );
        },
      ),
    );
  }
}

class AchievementsScreen extends StatelessWidget {
  const AchievementsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final unlocked = GameStats.achievements;
    return Scaffold(
      appBar: AppBar(
          title: Text(
              'ACHIEVEMENTS · ${unlocked.length}/${kAchievements.length}')),
      body: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: kAchievements.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (_, i) {
          final a = kAchievements[i];
          final got = unlocked.contains(a.id);
          return Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFF1F1D2E),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                  color: got ? const Color(0xFFFFD45E) : Colors.white12),
            ),
            child: Row(children: [
              Icon(got ? Icons.star : Icons.star_border,
                  color: got
                      ? const Color(0xFFFFD45E)
                      : Colors.white24,
                  size: 28),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(a.title,
                        style: TextStyle(
                            color: got ? Colors.white : Colors.white38,
                            fontWeight: FontWeight.w900,
                            fontSize: 15)),
                    Text(a.desc,
                        style: const TextStyle(
                            color: Colors.white54, fontSize: 12)),
                  ],
                ),
              ),
            ]),
          );
        },
      ),
    );
  }
}

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});
  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  @override
  void dispose() {
    Settings.save();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('SETTINGS')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text('SFX volume  ${(Settings.sfxVol * 100).round()}%',
              style: const TextStyle(
                  color: Color(0xFFFFD45E),
                  fontWeight: FontWeight.w900,
                  fontSize: 14)),
          Slider(
            min: 0,
            max: 1,
            value: Settings.sfxVol,
            onChanged: (v) => setState(() => Settings.sfxVol = v),
            onChangeEnd: (_) => Sfx.play('pickup', vol: 0.6),
          ),
          const SizedBox(height: 8),
          SwitchListTile(
            title: const Text('Screen shake',
                style: TextStyle(color: Colors.white)),
            subtitle: const Text(
                'camera kick on hits, dashes, and explosions',
                style: TextStyle(color: Colors.white54, fontSize: 12)),
            value: Settings.shake,
            onChanged: (v) => setState(() => Settings.shake = v),
            activeThumbColor: const Color(0xFFFFD45E),
          ),
          SwitchListTile(
            title: const Text('Vibration (mobile)',
                style: TextStyle(color: Colors.white)),
            subtitle: const Text(
                'haptic pulses on dash, hits, and damage',
                style: TextStyle(color: Colors.white54, fontSize: 12)),
            value: Settings.haptics,
            onChanged: (v) => setState(() => Settings.haptics = v),
            activeThumbColor: const Color(0xFFFFD45E),
          ),
          const SizedBox(height: 14),
          TextButton(
            onPressed: () {
              setState(() {
                Settings.tutorialDone = false;
              });
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                  content: Text('tutorial will show again next run')));
            },
            child: const Text('Reset tutorial',
                style: TextStyle(color: Color(0xFF8CC8FF))),
          ),
        ],
      ),
    );
  }
}

class CharacterSelectScreen extends StatelessWidget {
  const CharacterSelectScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('CHOOSE YOUR CLASS')),
      body: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: kHeroes.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, i) => _HeroCard(def: kHeroes[i]),
      ),
    );
  }
}

class _HeroCard extends StatelessWidget {
  const _HeroCard({required this.def});
  final HeroDef def;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => KeepsakeScreen(def: def))),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              const Color(0xFF1F1D2E),
              const Color(0xFF14131F),
            ],
          ),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFB58435), width: 1.4),
          boxShadow: [
            BoxShadow(
              color: def.accent.withValues(alpha: 0.18),
              blurRadius: 14,
            ),
          ],
        ),
        padding: const EdgeInsets.fromLTRB(14, 14, 18, 14),
        child: Row(
          children: [
            SizedBox(
              width: 140,
              height: 170,
              child: CustomPaint(
                painter: HeroMedallionPainter(def: def, label: def.role),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(def.name.toUpperCase(),
                      style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFFFFD45E),
                          letterSpacing: 1.5)),
                  const SizedBox(height: 4),
                  Text(def.tagline,
                      style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                          fontStyle: FontStyle.italic)),
                  const SizedBox(height: 10),
                  _statRow('HP', def.maxHp.toInt().toString(),
                      const Color(0xFFFF5C6C)),
                  _statRow('MP', def.maxMp.toInt().toString(),
                      const Color(0xFF3F8BFF)),
                  _statRow('DMG', def.damage.toString(),
                      const Color(0xFFFFB347)),
                  _statRow('SPD', def.speed.toInt().toString(),
                      const Color(0xFF8CFF98)),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 5),
                    decoration: BoxDecoration(
                      color: def.accent.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(6),
                      border:
                          Border.all(color: def.accent.withValues(alpha: 0.6)),
                    ),
                    child: Row(children: [
                      Text('✦ ${def.abilityName}',
                          style: TextStyle(
                              color: def.accent,
                              fontWeight: FontWeight.w900,
                              fontSize: 11)),
                    ]),
                  ),
                  const SizedBox(height: 3),
                  Text(def.abilityDesc,
                      style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 10,
                          height: 1.4)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _statRow(String name, String value, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Row(children: [
        SizedBox(
            width: 28,
            child: Text(name,
                style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.w900,
                    fontSize: 10))),
        Text(value,
            style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                fontSize: 11)),
      ]),
    );
  }
}

/// ---------------------------------------------------------------------------
/// Keepsake select
/// ---------------------------------------------------------------------------
class KeepsakeScreen extends StatelessWidget {
  const KeepsakeScreen({super.key, required this.def});
  final HeroDef def;

  @override
  Widget build(BuildContext context) {
    void go() => Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(builder: (_) => GameScreen(def: def)));
    return Scaffold(
      appBar: AppBar(title: const Text('EQUIP A KEEPSAKE')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: () {
              Loadout.keepsake = null;
              go();
            },
            child: Container(
              padding: const EdgeInsets.all(16),
              margin: const EdgeInsets.only(bottom: 10),
              decoration: BoxDecoration(
                color: const Color(0xFF1F1D2E),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.white24),
              ),
              child: const Text('NO KEEPSAKE',
                  style: TextStyle(
                      fontWeight: FontWeight.w900, color: Colors.white)),
            ),
          ),
          for (final k in availableKeepsakes())
            InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: () {
                Loadout.keepsake = k;
                go();
              },
              child: Container(
                padding: const EdgeInsets.all(16),
                margin: const EdgeInsets.only(bottom: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFF1F1D2E),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFF8CC8FF)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(k.name,
                        style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF8CC8FF))),
                    Text(k.desc,
                        style: const TextStyle(
                            color: Colors.white60, fontSize: 12)),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// ---------------------------------------------------------------------------
/// Weapons
/// ---------------------------------------------------------------------------
enum WeaponKind { ranged, melee, thrust }

class WeaponDef {
  const WeaponDef(this.name, this.desc,
      {this.kind = WeaponKind.ranged,
      this.pellets = 1,
      this.spread = 0,
      this.dmgMul = 1,
      this.rofMul = 1,
      this.speedMul = 1,
      this.pierceAdd = 0,
      this.splashAdd = 0,
      this.reach = 78,
      this.arc = 1.5});
  final String name;
  final String desc;
  final WeaponKind kind;
  final int pellets;
  final double spread;
  final double dmgMul;
  final double rofMul;
  final double speedMul;
  final int pierceAdd;
  final double splashAdd;
  final double reach; // melee/thrust range
  final double arc; // melee swing angle (radians)
}

const WeaponDef kDefaultWeapon =
    WeaponDef('SIDEARM', 'trusty starter bonk');

const List<WeaponDef> kWeapons = [
  // melee / thrust
  WeaponDef('STYGIUS SWORD', 'wide melee arc, strong',
      kind: WeaponKind.melee,
      dmgMul: 1.7,
      rofMul: 0.52,
      reach: 84,
      arc: 1.7),
  WeaponDef('VARATHA SPEAR', 'long narrow thrust',
      kind: WeaponKind.thrust,
      dmgMul: 1.9,
      rofMul: 0.62,
      reach: 138,
      arc: 0.5),
  WeaponDef('TWIN FANGS', 'fast short melee',
      kind: WeaponKind.melee,
      dmgMul: 0.8,
      rofMul: 0.26,
      reach: 56,
      arc: 1.3),
  WeaponDef('AEGIS BASH', 'short heavy melee',
      kind: WeaponKind.melee,
      dmgMul: 2.4,
      rofMul: 0.8,
      reach: 64,
      arc: 2.4),
  // ranged
  WeaponDef('CORONACHT BOW', 'piercing power shots',
      dmgMul: 1.7, rofMul: 1.05, speedMul: 1.6, pierceAdd: 2),
  WeaponDef('SMG', 'fast, weak, slight spray',
      pellets: 1, spread: 0.06, dmgMul: 0.62, rofMul: 0.45, speedMul: 1.1),
  WeaponDef('SHOTGUN', '6 pellets, close range',
      pellets: 6, spread: 0.55, dmgMul: 0.5, rofMul: 1.5, speedMul: 0.92),
  WeaponDef('SNIPER', 'huge dmg, pierces, slow',
      dmgMul: 3.4, rofMul: 2.0, speedMul: 1.9, pierceAdd: 4),
  WeaponDef('CANNON', 'explosive lobs',
      dmgMul: 2.2, rofMul: 1.7, speedMul: 0.8, splashAdd: 42),
  WeaponDef('MINIGUN', 'brrrt of tiny bonks',
      pellets: 1, spread: 0.10, dmgMul: 0.5, rofMul: 0.28, speedMul: 1.15),
  WeaponDef('REVOLVER', 'slow but heavy hitters',
      pellets: 1, spread: 0.02, dmgMul: 2.6, rofMul: 1.55, speedMul: 1.45),
  WeaponDef('AUTO BOW', 'rapid piercing shots',
      pellets: 1, spread: 0.04, dmgMul: 0.95, rofMul: 0.36, speedMul: 1.35,
      pierceAdd: 1),
  WeaponDef('GRENADE LAUNCHER', 'big splash, slow lob',
      pellets: 1, spread: 0.03, dmgMul: 1.6, rofMul: 1.4, speedMul: 0.65,
      splashAdd: 60),
];

/// ---------------------------------------------------------------------------
/// Entities
/// ---------------------------------------------------------------------------
class Player {
  Player(this.def)
      : pos = Offset.zero,
        hp = def.maxHp +
            MetaStore.lvlOf('hp') * 2 +
            (NpcStore.questDone.contains('hypnos') ? 5 : 0),
        maxHp = def.maxHp +
            MetaStore.lvlOf('hp') * 2 +
            (NpcStore.questDone.contains('hypnos') ? 5 : 0),
        mp = def.maxMp,
        maxMp = def.maxMp,
        speed = def.speed + MetaStore.lvlOf('spd') * 8,
        damage = def.damage +
            MetaStore.lvlOf('dmg') * 0.3 +
            (NpcStore.questDone.contains('smith') ? 1 : 0),
        fireInterval = def.fireInterval,
        projSpeed = def.projSpeed,
        range = def.range,
        critChance = def.critChance +
            MetaStore.lvlOf('crit') * 0.03 +
            (NpcStore.questDone.contains('scribe') ? 0.05 : 0),
        projectiles = def.projectiles,
        lifesteal = def.lifesteal + MetaStore.lvlOf('life') * 0.1,
        splash = def.splash + MetaStore.lvlOf('splash') * 6,
        pierce = def.pierce,
        dot = def.dot,
        thorns = def.thorns,
        obols = MetaStore.lvlOf('gold') * 15,
        vision = 1.0 + MetaStore.lvlOf('vis') * 0.10;

  final HeroDef def;
  Offset pos;
  double hp;
  double maxHp;
  double mp;
  double maxMp;
  double mpRegen = 1.0 +
      MetaStore.lvlOf('mp') * 0.4 +
      (NpcStore.questDone.contains('dusa') ? 0.5 : 0);
  double speed;
  double damage;
  double fireInterval;
  double projSpeed;
  double range;
  double critChance;
  int projectiles;
  double lifesteal;
  double splash;
  int pierce;
  double dot;
  double thorns;
  double vision;
  int volleys = 1;
  WeaponDef weapon = kDefaultWeapon;

  // Hades-style kit
  int revives = 1 +
      MetaStore.lvlOf('rev') +
      (NpcStore.questDone.contains('achilles') ? 1 : 0);
  double dashTimer = 0;
  double dashCd = (1.5 - MetaStore.lvlOf('dash') * 0.1).clamp(0.4, 5);
  int zeus = 0; // chain-lightning jumps
  double knockback = 0; // Poseidon
  double doomAmt = 0; // Ares delayed burst

  double fireTimer = 0;
  double regen = NpcStore.questDone.contains('apothecary') ? 0.5 : 0;
  double hurtFlash = 0;
  double frostT = 0; // movement-slow timer applied by FROST enemies
  bool frostImmune = false;
  double fireT = 0; // burning damage-over-time from fire bolts
  double fireDps = 0;
  double abilityTimer = 0;
  double invuln = 0;
  double frenzy = 0;
  int volleyLeft = 0;
  double volleyTimer = 0;

  int level = 1;
  int xp = 0;
  int xpToNext = 5;
  int kills = 0;
  int obols;

  int get buffStage => (level - 1) ~/ 3 < 3 ? (level - 1) ~/ 3 : 3;
  double get radius => 16 + buffStage * 3.0;
  double get effFire => frenzy > 0 ? fireInterval * 0.32 : fireInterval;
}

class Enemy {
  Enemy({
    required this.pos,
    required this.hp,
    required this.speed,
    required this.damage,
    required this.radius,
    required this.kind,
    required this.bounty,
    required this.xp,
  }) : maxHp = hp;

  Offset pos;
  double hp;
  final double maxHp;
  double speed;
  double damage;
  double radius;
  int kind;
  int bounty;
  int xp;
  double touchTimer = 0;
  double shootTimer = 1.4;
  double dotTimer = 0;
  double dotDps = 0;
  double flash = 0;
  double doomT = 0;
  double doomAmt = 0;
  bool elite = false;
  // Bolt flavor this ranged enemy fires (0=normal, 1=frost, 2=fire).
  int boltKind = 0;
  // Boss nova attack telegraphs (boss-only state machine).
  double novaT = 5.0; // time until next nova starts winding up
  double novaTele = 0; // current telegraph timer (0 = idle, >0 = winding up)
  double novaRadius = 0;
  // Bull (kind 10) charge state machine.
  double chargeCd = 3.0; // time until next wind-up
  double chargeWind = 0; // >0 = winding up (telegraphed)
  double chargeRem = 0; // >0 = currently dashing
  Offset chargeDir = Offset.zero;
  double stunT = 0; // brief stun after wall-collision
  // Slammer (kind 11) jump-and-slam state machine.
  double slamCd = 3.5;
  double slamT = 0; // >0 while airborne, lands at 0
  Offset slamTarget = Offset.zero;
  // Grenadier (kind 9) throw cooldown.
  double grenadeT = 1.6;
}

// Lobbed grenade with a 1.1s flight arc and an AoE explosion on landing.
class Grenade {
  Grenade(this.origin, this.target, this.damage);
  final Offset origin;
  final Offset target;
  final double damage;
  double t = 0;
  static const double total = 1.1;
  Offset get pos => Offset.lerp(origin, target, progress)!;
  double get lift => sin(progress * pi) * 56; // peak ~56 mid-flight
  double get progress => (t / total).clamp(0.0, 1.0).toDouble();
  bool get landed => t >= total;
}

class Bolt {
  Bolt(this.pos, this.vel, this.damage, this.crit, this.pierce, this.splash,
      this.dot);
  Offset pos;
  Offset vel;
  double damage;
  bool crit;
  int pierce;
  double splash;
  double dot;
  double life = 1.7;
  final Set<Enemy> hit = {};
}

class EBolt {
  EBolt(this.pos, this.vel, this.damage, {this.kind = 0});
  Offset pos;
  Offset vel;
  double damage;
  double life = 4;
  // 0=normal violet bolt, 1=frost (chills on hit), 2=fire (lingering DoT)
  final int kind;
}

class Heart {
  Heart(this.pos);
  Offset pos;
  double life = 12.0; // hearts disappear if uncollected after ~12s
  double bob = 0;
}

class NectarDrop {
  NectarDrop(this.pos);
  Offset pos;
  double life = 16.0;
  double bob = 0;
}

class Captive {
  Captive(this.pos, this.npcId);
  Offset pos;
  String npcId;
  double bob = 0;
  bool freed = false;
}

class Toast {
  Toast(this.title, this.subtitle, [this.color = const Color(0xFFFFD45E)]);
  final String title;
  final String subtitle;
  final Color color;
  double t = 3.6; // total seconds visible (fades during final 1s)
}

class Orb {
  Orb(this.pos, this.xp);
  Offset pos;
  int xp;
}

class Burst {
  Burst(this.pos, this.maxR);
  Offset pos;
  double maxR;
  double t = 0;
}

class FloatText {
  FloatText(this.pos, this.text, this.color, {this.size = 14});
  Offset pos;
  String text;
  Color color;
  double size;
  double life = 0.8;
}

class Swing {
  Swing(this.pos, this.ang, this.reach, this.arc, this.thrust);
  Offset pos;
  double ang;
  double reach;
  double arc;
  bool thrust;
  double life = 0.18;
}

class Ghost {
  Ghost(this.pos);
  final Offset pos;
  double life = 0.3;
}

class Trap {
  Trap(this.pos);
  final Offset pos;
  double r = 30;
  // 0 idle, 1 armed (counting down), 2 spent (cooldown)
  int state = 0;
  double timer = 0;
}

class Ballista {
  Ballista(this.pos, this.vel, this.interval);
  final Offset pos;
  final Offset vel; // unit dir * speed
  final double interval;
  double timer = 0;
}

enum DoorKind { reward, boon, shop, treasure, challenge, shrine, respite }

enum RoomKind { normal, treasure, challenge, shrine, respite }

class DoorDef {
  DoorDef(this.icon, this.title, this.desc, this.kind, this.apply);
  final String icon;
  final String title;
  final String desc;
  final DoorKind kind;
  final void Function(Player p) apply;
}

class Door {
  Door(this.pos, this.def);
  final Offset pos;
  final DoorDef def;
  double r = 30;
}

/// Per-device toggles (volume, screen shake, haptics, tutorial flag),
/// persisted via SharedPreferences. Safe defaults if loading fails.
class Settings {
  static double sfxVol = 0.7;
  static bool shake = true;
  static bool haptics = true;
  static bool tutorialDone = false;

  static Future<void> load() async {
    try {
      final p = await SharedPreferences.getInstance();
      sfxVol = (p.getDouble('bb_sfxVol') ?? 0.7).clamp(0.0, 1.0);
      shake = p.getBool('bb_shake') ?? true;
      haptics = p.getBool('bb_haptics') ?? true;
      tutorialDone = p.getBool('bb_tut') ?? false;
    } catch (_) {}
  }

  static Future<void> save() async {
    try {
      final p = await SharedPreferences.getInstance();
      await p.setDouble('bb_sfxVol', sfxVol);
      await p.setBool('bb_shake', shake);
      await p.setBool('bb_haptics', haptics);
      await p.setBool('bb_tut', tutorialDone);
    } catch (_) {}
  }
}

class Achievement {
  const Achievement(this.id, this.title, this.desc);
  final String id;
  final String title;
  final String desc;
}

const List<Achievement> kAchievements = [
  Achievement('first_blood', 'FIRST BLOOD', 'land your first kill'),
  Achievement('kills_100', 'CENTURION', 'rack up 100 lifetime kills'),
  Achievement('kills_1000', 'EXTERMINATOR', 'rack up 1 000 lifetime kills'),
  Achievement('combo_20', 'STREAKER', 'reach a combo of 20'),
  Achievement('combo_50', 'INFERNO', 'reach a combo of 50'),
  Achievement('boss_1', 'GIANT SLAYER', 'defeat your first boss'),
  Achievement('boss_5', 'TYRANT', 'defeat 5 bosses lifetime'),
  Achievement('floor_3', 'DEEP DIVE', 'reach floor 3'),
  Achievement('floor_5', 'BEDROCK', 'reach floor 5'),
  Achievement('vampire_50', 'STAKE MASTER', 'kill 50 vampires'),
  Achievement('kamikaze_50', 'BOMB SQUAD', 'kill 50 kamikazes'),
  Achievement('shielded_50', 'CAN OPENER', 'kill 50 shielded brutes'),
];

/// Per-NPC persistent state: affinity earned through gifts, who's been
/// rescued from the dungeon, and the player's stash of NECTAR (the gift
/// currency). Loaded once at boot, written through after every mutation.
class NpcStore {
  static const _npcIds = [
    'hypnos',
    'achilles',
    'dusa',
    'smith',
    'chef',
    'scribe',
    'apothecary',
  ];

  // ids that the player has freed during runs; they appear in home after.
  static Set<String> rescued = {};
  // affinity[id] starts at 0; each gift adds 1.
  static Map<String, int> affinity = {};
  // gift currency that drops from elites, bosses, and rare rooms.
  static int nectar = 0;
  // Whether the smith's per-run service has been used. Cleared at _initRun.
  static bool smithUsedThisRun = false;
  // Quest tracking (★★ unlocks each NPC's one-time quest).
  static Map<String, int> questProgress = {};
  static Set<String> questDone = {};
  // Lifetime nectar collected — feeds Dusa's quest target.
  static int lifetimeNectar = 0;

  static int affOf(String id) => affinity[id] ?? 0;
  static int tierOf(String id) {
    final a = affOf(id);
    if (a >= 6) return 3;
    if (a >= 3) return 2;
    if (a >= 1) return 1;
    return 0;
  }

  static Future<void> load() async {
    try {
      final p = await SharedPreferences.getInstance();
      nectar = p.getInt('bb_nectar') ?? 0;
      lifetimeNectar = p.getInt('bb_nectarTotal') ?? 0;
      rescued = (p.getStringList('bb_rescued') ?? const <String>[]).toSet();
      affinity = {};
      questProgress = {};
      for (final id in _npcIds) {
        affinity[id] = p.getInt('bb_aff_$id') ?? 0;
        questProgress[id] = p.getInt('bb_qp_$id') ?? 0;
      }
      questDone = (p.getStringList('bb_qdone') ?? const <String>[]).toSet();
    } catch (_) {}
  }

  static Future<void> save() async {
    try {
      final p = await SharedPreferences.getInstance();
      await p.setInt('bb_nectar', nectar);
      await p.setInt('bb_nectarTotal', lifetimeNectar);
      await p.setStringList('bb_rescued', rescued.toList());
      for (final id in _npcIds) {
        await p.setInt('bb_aff_$id', affinity[id] ?? 0);
        await p.setInt('bb_qp_$id', questProgress[id] ?? 0);
      }
      await p.setStringList('bb_qdone', questDone.toList());
    } catch (_) {}
  }

  static int qp(String id) => questProgress[id] ?? 0;
  static void bumpQuest(String id, int by) {
    if (questDone.contains(id)) return;
    questProgress[id] = qp(id) + by;
    save();
  }

  static void gift(String id) {
    if (nectar <= 0) return;
    nectar -= 1;
    affinity[id] = affOf(id) + 1;
    save();
  }

  static void rescue(String id) {
    if (rescued.add(id)) save();
  }
}

class GameStats {
  static int bestWave = 0;
  static int bestFloor = 0;
  static int totalKills = 0;
  static int totalObols = 0;
  static int totalRuns = 0;
  static int bestCombo = 0;
  static int totalBossKills = 0;
  static int totalCrits = 0;
  static final Map<int, int> killsByKind = {};
  static final Set<String> achievements = {};
  // dailyBest keyed by YYYYMMDD → best score for that day's seeded run.
  static final Map<String, int> dailyBest = {};

  static Future<void> load() async {
    try {
      final p = await SharedPreferences.getInstance();
      bestWave = p.getInt('bb_bestWave') ?? 0;
      bestFloor = p.getInt('bb_bestFloor') ?? 0;
      totalKills = p.getInt('bb_totalKills') ?? 0;
      totalObols = p.getInt('bb_totalObols') ?? 0;
      totalRuns = p.getInt('bb_totalRuns') ?? 0;
      bestCombo = p.getInt('bb_bestCombo') ?? 0;
      totalBossKills = p.getInt('bb_totalBossKills') ?? 0;
      totalCrits = p.getInt('bb_totalCrits') ?? 0;
      killsByKind.clear();
      for (int k = 0; k < 12; k++) {
        final n = p.getInt('bb_killsK$k') ?? 0;
        if (n > 0) killsByKind[k] = n;
      }
      achievements
        ..clear()
        ..addAll(p.getStringList('bb_ach') ?? const <String>[]);
      dailyBest.clear();
      for (final key in (p.getStringList('bb_dailyKeys') ?? const <String>[])) {
        dailyBest[key] = p.getInt('bb_daily_$key') ?? 0;
      }
    } catch (_) {}
  }

  static Future<void> save() async {
    try {
      final p = await SharedPreferences.getInstance();
      await p.setInt('bb_bestWave', bestWave);
      await p.setInt('bb_bestFloor', bestFloor);
      await p.setInt('bb_totalKills', totalKills);
      await p.setInt('bb_totalObols', totalObols);
      await p.setInt('bb_totalRuns', totalRuns);
      await p.setInt('bb_bestCombo', bestCombo);
      await p.setInt('bb_totalBossKills', totalBossKills);
      await p.setInt('bb_totalCrits', totalCrits);
      for (final e in killsByKind.entries) {
        await p.setInt('bb_killsK${e.key}', e.value);
      }
      await p.setStringList('bb_ach', achievements.toList());
      await p.setStringList('bb_dailyKeys', dailyBest.keys.toList());
      for (final e in dailyBest.entries) {
        await p.setInt('bb_daily_${e.key}', e.value);
      }
    } catch (_) {}
  }

  static void recordRunEnd(int reachedWave, int reachedFloor, int kills,
      int obols) {
    totalRuns += 1;
    totalKills += kills;
    totalObols += obols;
    if (reachedWave > bestWave) bestWave = reachedWave;
    if (reachedFloor > bestFloor) bestFloor = reachedFloor;
    save();
  }
}

enum Phase {
  playing,
  roomCleared,
  paused,
  levelUp,
  shop,
  shrine,
  gameOver,
  victory
}

/// ---------------------------------------------------------------------------
/// Game
/// ---------------------------------------------------------------------------
class GameScreen extends StatefulWidget {
  const GameScreen({super.key, required this.def});
  final HeroDef def;

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  Duration _last = Duration.zero;
  Random _rng = Random();

  Size _size = Size.zero;
  late GameMap _map;
  bool _ready = false;
  bool _showTutorial = false;
  // BFS distance field from the player's tile so enemies can route around
  // walls and pools instead of walking straight into them.
  List<int>? _flow;
  int _flowFromCell = -1;

  late Player _p;
  final List<Enemy> _enemies = [];
  final List<Bolt> _bolts = [];
  final List<EBolt> _ebolts = [];
  final List<Grenade> _grenades = [];
  final List<Orb> _orbs = [];
  final List<Heart> _hearts = [];
  final List<NectarDrop> _nectar = [];
  final List<Captive> _captives = [];
  final List<Toast> _toasts = [];
  final List<Burst> _bursts = [];
  final List<FloatText> _texts = [];
  final List<Door> _doors = [];
  final List<Swing> _swings = [];
  final List<Ghost> _ghosts = [];
  final List<Trap> _traps = [];
  final List<Ballista> _ballistas = [];

  Phase _phase = Phase.playing;
  int _wave = 1;
  int _combo = 0;
  double _comboT = 0;
  RoomKind _roomKind = RoomKind.normal;
  // Microsecond hit-stop: when > 0, the simulation freezes for that many
  // seconds so a crit or boss hit lands with weight. Rendering continues.
  double _freezeT = 0;
  String? _bossIntro;
  double _bossIntroT = 0;
  String? _floorIntro;
  double _floorIntroT = 0;
  int _lastIntroFloor = -1;
  // Run-scoped trackers, reset at _initRun and read on the end overlay.
  final List<String> _runBoons = [];
  double _runTime = 0;
  int _runMaxCombo = 0;
  int _runStartNectar = 0;
  // Whichever enemy the auto-aim is locked onto this frame — drawn with a
  // subtle ring so the player can read where their next shot is going.
  Enemy? _aimAt;
  // Hades-style room flow. Player spawns at one of the two LOWER corners
  // (2 = lower-left, 3 = lower-right) and the exit portals appear at the
  // diagonally opposite UPPER corner (0 = upper-left, 1 = upper-right).
  int _entryCorner = 2;
  int get _exitCorner => (_entryCorner + 2) % 4;
  double get _comboFireMul =>
      _combo >= 25 ? 0.7 : (_combo >= 10 ? 0.85 : 1.0);
  double get _comboDmgMul =>
      _combo >= 25 ? 1.20 : (_combo >= 10 ? 1.10 : 1.0);
  int _toSpawn = 0;
  bool _bossSpawned = false;
  double _spawnTimer = 0;
  bool _boonThenNext = false;

  bool _stickOn = false;
  Offset _stickOrigin = Offset.zero;
  Offset _stickKnob = Offset.zero;
  Offset _moveDir = Offset.zero;
  Offset _facing = const Offset(1, 0);
  double _elapsed = 0;
  double _shake = 0;
  static const double _stickR = 60;

  List<Upgrade> _choices = [];
  List<ShopItem> _shop = [];

  int get _floorIdx =>
      ((_wave - 1) ~/ kWavesPerFloor).clamp(0, kFloors.length - 1).toInt();
  FloorDef get _floor => kFloors[_floorIdx];
  bool get _bossWave => _wave % kWavesPerFloor == 0;
  int get _enemiesLeft => _enemies.length + _toSpawn;

  Rect get _abilityRect =>
      Rect.fromLTWH(_size.width - 98, _size.height - 108, 78, 78);
  Rect get _dashRect =>
      Rect.fromLTWH(_size.width - 95, _size.height - 196, 72, 72);
  // Pause sits just below the top-right minimap.
  Rect get _pauseRect => Rect.fromLTWH(_size.width - 50, 116, 36, 36);

  @override
  void initState() {
    super.initState();
    _p = Player(widget.def);
    _ticker = createTicker(_onTick)..start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  void _genRoom() {
    WorldPainter.resetCaches(); // drop stale floor/wall caches from previous map
    _flow = null;
    _flowFromCell = -1;
    _map = GameMap.generate(_rng, _size.width, _size.height, _wave);
    final entryPos = _cornerSpawn(_entryCorner);
    _p.pos = entryPos;
    _map.clearDisk(_p.pos.dx, _p.pos.dy, 3.2); // wide gateway in the entry wall
    _enemies.clear();
    _bolts.clear();
    _ebolts.clear();
    _grenades.clear();
    _orbs.clear();
    _hearts.clear();
    _nectar.clear();
    _captives.clear();
    _toasts.clear();
    _bursts.clear();
    _texts.clear();
    _doors.clear();
    _swings.clear();
    _ghosts.clear();
    _traps.clear();
    _ballistas.clear();
    _bossSpawned = false;
    _spawnTimer = 0.6;
    // Banner: when the player walks into the first room of a new floor.
    if (_floorIdx != _lastIntroFloor) {
      _lastIntroFloor = _floorIdx;
      _floorIntro = 'F${_floorIdx + 1} · ${_floor.name}';
      _floorIntroT = 2.4;
    }
    var spawn = _bossWave ? 7 : (6 + _wave * 2).clamp(6, 26).toInt();
    if (_roomKind == RoomKind.treasure) spawn = 0;
    if (_roomKind == RoomKind.challenge) spawn = (spawn * 1.6).round();
    if (_roomKind == RoomKind.shrine) spawn = 0;
    if (_roomKind == RoomKind.respite) spawn = 0;
    _toSpawn = spawn;

    // Treasure rooms: drop a pile of obol orbs by the entry.
    if (_roomKind == RoomKind.treasure) {
      final c = _map.roomCenter(0);
      for (var i = 0; i < 6; i++) {
        final a = _rng.nextDouble() * 2 * pi;
        final off = Offset(cos(a), sin(a)) * (40.0 + _rng.nextDouble() * 60);
        _orbs.add(Orb(c + off, 4 + _floorIdx));
      }
      _p.obols += 8 + _floorIdx * 6;
      _texts.add(FloatText(c.translate(0, -28), 'TREASURE ROOM',
          const Color(0xFFFFD45E)));
    }
    if (_roomKind == RoomKind.challenge) {
      _texts.add(FloatText(_p.pos.translate(0, -32), 'CHALLENGE!',
          const Color(0xFFFF9A3C)));
    }
    if (_roomKind == RoomKind.respite) {
      // Wayhouse: drop a single visitor at the map center. Walking up to
      // them grants a small free buff and a nectar bottle.
      final centerRoom = _map.rooms[_map.rooms.length ~/ 2];
      final vp = Offset(
          (centerRoom.left + centerRoom.width / 2) * _map.cell,
          (centerRoom.top + centerRoom.height / 2) * _map.cell);
      _map.clearDisk(vp.dx, vp.dy, 2.0);
      final pick =
          ['eurydice', 'patroclus', 'sisyphus'][_rng.nextInt(3)];
      final id = 'respite_$pick';
      _captives.add(Captive(vp, id));
      _texts.add(FloatText(vp.translate(0, -32),
          'A QUIET VISITOR', const Color(0xFFB6FFC0)));
    }

    // traps: visible, sparse, away from the entry
    final entry = _map.roomCenter(0);
    final trapCount = _bossWave ? 0 : (2 + _rng.nextInt(3));
    for (var i = 0; i < trapCount; i++) {
      for (var tries = 0; tries < 30; tries++) {
        final p = _map.randomFloor(_rng);
        if ((p - entry).distance > 200) {
          _traps.add(Trap(p));
          break;
        }
      }
    }
    // ballistas: fire across rooms horizontally / vertically
    final balCount = _bossWave ? 1 : (1 + _rng.nextInt(2)) + _floorIdx ~/ 2;
    for (var i = 0; i < balCount; i++) {
      final room = _map.rooms[1 + _rng.nextInt(max(1, _map.rooms.length - 1))];
      final horiz = _rng.nextBool();
      final cell = _map.cell;
      if (horiz) {
        final y = (room.top + room.height / 2) * cell;
        final fromLeft = _rng.nextBool();
        final x = fromLeft
            ? (room.left + 0.3) * cell
            : (room.left + room.width - 0.3) * cell;
        _ballistas.add(Ballista(Offset(x, y),
            Offset(fromLeft ? 300 : -300, 0), 2.4 + _rng.nextDouble()));
      } else {
        final x = (room.left + room.width / 2) * cell;
        final fromTop = _rng.nextBool();
        final y = fromTop
            ? (room.top + 0.3) * cell
            : (room.top + room.height - 0.3) * cell;
        _ballistas.add(Ballista(Offset(x, y),
            Offset(0, fromTop ? 300 : -300), 2.4 + _rng.nextDouble()));
      }
    }

    // Rare rescue event: tucked-away captive in a far room. We pick from
    // the unrescued candidates so each run can save at most one new NPC.
    if (!_bossWave && _floorIdx >= 1) {
      const rescuables = ['smith', 'chef', 'scribe', 'apothecary'];
      final candidates = rescuables
          .where((id) => !NpcStore.rescued.contains(id))
          .toList();
      if (candidates.isNotEmpty &&
          _rng.nextDouble() < 0.06 + _floorIdx * 0.025) {
        final id = candidates[_rng.nextInt(candidates.length)];
        final back = _cornerCell(_exitCorner, _floorBounds()!);
        final cell = _map.cell;
        final pos = Offset((back.$1 + 0.5) * cell, (back.$2 + 0.5) * cell);
        _map.clearDisk(pos.dx, pos.dy, 2.0);
        _captives.add(Captive(pos, id));
        _texts.add(FloatText(pos.translate(0, -32),
            'CAPTIVE — clear the room', const Color(0xFFFFD45E)));
      }
    }
  }

  void _initRun() {
    if (Loadout.dailySeed != null) {
      _rng = Random(Loadout.dailySeed!);
    } else {
      _rng = Random();
    }
    _p = Player(widget.def);
    Loadout.keepsake?.apply(_p);
    if (Loadout.startingWeapon != null) {
      _p.weapon = Loadout.startingWeapon!;
    }
    if (Loadout.startingObols > 0) {
      _p.obols += Loadout.startingObols;
      Loadout.startingObols = 0;
    }
    if (Loadout.blessingDmg > 0) {
      _p.damage += Loadout.blessingDmg;
      Loadout.blessingDmg = 0;
    }
    if (Loadout.blessingHp > 0) {
      _p.maxHp += Loadout.blessingHp.toDouble();
      _p.hp += Loadout.blessingHp.toDouble();
      Loadout.blessingHp = 0;
    }
    if (Loadout.blessingRevives > 0) {
      _p.revives += Loadout.blessingRevives;
      Loadout.blessingRevives = 0;
    }
    if (Loadout.blessingMpRegen > 0) {
      _p.mpRegen += Loadout.blessingMpRegen;
      Loadout.blessingMpRegen = 0;
    }
    if (Loadout.blessingCritChance > 0) {
      _p.critChance += Loadout.blessingCritChance;
      Loadout.blessingCritChance = 0;
    }
    if (Loadout.blessingRegen > 0) {
      _p.regen += Loadout.blessingRegen;
      Loadout.blessingRegen = 0;
    }
    // Chef's bonus is read live during the run (nectar drop chance) and
    // zeroed at game-over so it only buffs the run it was set for.
    _wave = 1;
    _entryCorner = 2 + _rng.nextInt(2); // either lower-left or lower-right
    _lastIntroFloor = -1; // force the F1 banner on the first room of a run
    _runBoons.clear();
    _runTime = 0;
    _runMaxCombo = 0;
    _runStartNectar = NpcStore.nectar;
    NpcStore.smithUsedThisRun = false;
    _shake = 0;
    _combo = 0;
    _comboT = 0;
    _roomKind = RoomKind.normal;
    _boonThenNext = false;
    _genRoom();
    _phase = Phase.playing;
    _ready = true;
    _showTutorial = !Settings.tutorialDone;
  }

  void _onTick(Duration elapsed) {
    if (!_ready) {
      _last = elapsed;
      return;
    }
    var dt = (elapsed - _last).inMicroseconds / 1e6;
    _last = elapsed;
    if (dt > 1 / 30) dt = 1 / 30;
    _elapsed += dt;
    if (_shake > 0) {
      _shake -= dt * 26;
      if (_shake < 0) _shake = 0;
    }
    if (_bossIntroT > 0) _bossIntroT -= dt;
    if (_floorIntroT > 0) _floorIntroT -= dt;
    // Hit-stop: drain the freeze timer with real time, but pass dt=0 to
    // the simulation while it's active. Rendering keeps animating.
    if (_freezeT > 0) {
      _freezeT -= dt;
      dt = 0;
    }
    if (_phase == Phase.playing) _runTime += dt;
    if (_phase == Phase.playing || _phase == Phase.roomCleared) _update(dt);
    setState(() {});
  }

  bool _free(Offset p, double rad) =>
      _map.walkable(p.dx, p.dy) &&
      _map.walkable(p.dx - rad, p.dy) &&
      _map.walkable(p.dx + rad, p.dy) &&
      _map.walkable(p.dx, p.dy - rad) &&
      _map.walkable(p.dx, p.dy + rad);

  Offset _slide(Offset pos, Offset delta, double rad) {
    var nx = pos.dx;
    var ny = pos.dy;
    if (_free(Offset(pos.dx + delta.dx, pos.dy), rad)) nx = pos.dx + delta.dx;
    if (_free(Offset(nx, pos.dy + delta.dy), rad)) ny = pos.dy + delta.dy;
    return Offset(nx, ny);
  }

  // Rebuilds the player-anchored BFS distance field. Cells that aren't pure
  // floor (walls + pools) are blocked so AI can't path through them. Cheap
  // enough to run on every player-cell change — re-uses the buffer otherwise.
  void _ensureFlow() {
    final m = _map;
    final cell = m.cell;
    final pc = (_p.pos.dx / cell).floor();
    final pr = (_p.pos.dy / cell).floor();
    if (pc < 0 || pr < 0 || pc >= m.cols || pr >= m.rows) return;
    final key = pr * m.cols + pc;
    if (_flowFromCell == key && _flow != null) return;
    _flowFromCell = key;
    final flow = List<int>.filled(m.cols * m.rows, 0x7FFFFFFF);
    if (m.tt(pc, pr) != 1) {
      _flow = flow;
      return;
    }
    flow[key] = 0;
    final q = <int>[key];
    var head = 0;
    while (head < q.length) {
      final i = q[head++];
      final c = i % m.cols, r = i ~/ m.cols;
      final d = flow[i] + 1;
      for (final dir in const [(1, 0), (-1, 0), (0, 1), (0, -1)]) {
        final nc = c + dir.$1, nr = r + dir.$2;
        if (nc < 0 || nr < 0 || nc >= m.cols || nr >= m.rows) continue;
        if (m.tt(nc, nr) != 1) continue;
        final ni = nr * m.cols + nc;
        if (flow[ni] > d) {
          flow[ni] = d;
          q.add(ni);
        }
      }
    }
    _flow = flow;
  }

  // True iff the segment from `a` to `b` is fully over floor tiles (no
  // walls and no pools in between). Sampled at sub-cell resolution.
  bool _pathClear(Offset a, Offset b) {
    final dx = b.dx - a.dx, dy = b.dy - a.dy;
    final dist = sqrt(dx * dx + dy * dy);
    if (dist < 1) return true;
    final steps = (dist / (_map.cell * 0.4)).ceil().clamp(1, 80);
    final inv = 1.0 / steps;
    for (var i = 1; i < steps; i++) {
      final t = i * inv;
      final x = a.dx + dx * t;
      final y = a.dy + dy * t;
      final c = (x / _map.cell).floor();
      final r = (y / _map.cell).floor();
      if (_map.tt(c, r) != 1) return false;
    }
    return true;
  }

  // Returns a unit vector toward the lowest-cost neighbor cell of `from`
  // in the flow field, i.e. one step down the gradient toward the player.
  Offset _flowStep(Offset from) {
    _ensureFlow();
    final flow = _flow;
    if (flow == null) return Offset.zero;
    final cell = _map.cell;
    final c = (from.dx / cell).floor();
    final r = (from.dy / cell).floor();
    if (c < 0 || r < 0 || c >= _map.cols || r >= _map.rows) {
      return Offset.zero;
    }
    final myDist = flow[r * _map.cols + c];
    if (myDist >= 0x7FFFFFFF) return Offset.zero;
    var bestC = c, bestR = r;
    var bestDist = myDist;
    for (final dir in const [(1, 0), (-1, 0), (0, 1), (0, -1)]) {
      final nc = c + dir.$1, nr = r + dir.$2;
      if (nc < 0 || nr < 0 || nc >= _map.cols || nr >= _map.rows) continue;
      final d = flow[nr * _map.cols + nc];
      if (d < bestDist) {
        bestDist = d;
        bestC = nc;
        bestR = nr;
      }
    }
    if (bestC == c && bestR == r) return Offset.zero;
    final target = Offset((bestC + 0.5) * cell, (bestR + 0.5) * cell);
    final v = target - from;
    final mag = v.distance;
    if (mag < 0.01) return Offset.zero;
    return v / mag;
  }

  void _update(double dt) {
    if (_showTutorial) return; // freeze gameplay until the player dismisses
    if (_moveDir != Offset.zero) {
      final spdMul = _p.frostT > 0 ? 0.55 : 1.0;
      _p.pos =
          _slide(_p.pos, _moveDir * _p.speed * spdMul * dt, _p.radius * 0.7);
      _facing = _moveDir;
    }
    if (_p.frostT > 0) _p.frostT -= dt;
    if (_p.fireT > 0) {
      _p.fireT -= dt;
      _p.hp -= _p.fireDps * dt; // burn ticks bypass i-frames + screen shake
    }
    if (_p.hurtFlash > 0) _p.hurtFlash -= dt;
    if (_p.invuln > 0) _p.invuln -= dt;
    if (_p.frenzy > 0) _p.frenzy -= dt;
    if (_p.abilityTimer > 0) _p.abilityTimer -= dt;
    if (_combo > 0) {
      _comboT -= dt;
      if (_comboT <= 0) _combo = 0;
    }
    if (_p.dashTimer > 0) _p.dashTimer -= dt;
    for (final g in _ghosts) {
      g.life -= dt;
    }
    _ghosts.removeWhere((g) => g.life <= 0);
    if (_p.regen > 0) {
      _p.hp = (_p.hp + _p.regen * dt).clamp(0, _p.maxHp).toDouble();
    }
    _p.mp = (_p.mp + _p.mpRegen * dt).clamp(0, _p.maxMp).toDouble();

    for (final b in _bursts) {
      b.t += dt;
    }
    _bursts.removeWhere((b) => b.t > 0.35);
    // Cap visible bursts/texts so dense fights don't pile up draw calls.
    if (_bursts.length > 32) _bursts.removeRange(0, _bursts.length - 32);
    for (final t in _texts) {
      t.pos = t.pos.translate(0, -34 * dt);
      t.life -= dt;
    }
    _texts.removeWhere((t) => t.life <= 0);
    if (_texts.length > 24) _texts.removeRange(0, _texts.length - 24);

    // orbs always collectible (including while roaming a cleared room)
    for (final o in _orbs) {
      final dir = _p.pos - o.pos;
      final d = dir.distance;
      if (d < 140 && d > 0.01) o.pos += dir / d * 280 * dt;
    }
    _orbs.removeWhere((o) {
      if ((o.pos - _p.pos).distance < _p.radius + 9) {
        _gainXp(o.xp);
        Sfx.play('pickup', vol: 0.5);
        return true;
      }
      return false;
    });

    for (final h in _hearts) {
      h.life -= dt;
      h.bob += dt;
      final dir = _p.pos - h.pos;
      final d = dir.distance;
      if (d < 160 && d > 0.01) h.pos += dir / d * 240 * dt;
    }
    _hearts.removeWhere((h) {
      if (h.life <= 0) return true;
      if ((h.pos - _p.pos).distance < _p.radius + 11) {
        _p.hp = (_p.hp + 6).clamp(0, _p.maxHp).toDouble();
        NpcStore.bumpQuest('apothecary', 1);
        _texts.add(FloatText(
            _p.pos.translate(0, -22), '+6', const Color(0xFFFF6B79)));
        Sfx.play('pickup', vol: 0.7, pitch: 1.2);
        return true;
      }
      return false;
    });

    // Nectar bottles: magnet pull + pickup adds to the persistent gift stash.
    for (final n in _nectar) {
      n.life -= dt;
      n.bob += dt;
      final dir = _p.pos - n.pos;
      final d = dir.distance;
      if (d < 170 && d > 0.01) n.pos += dir / d * 220 * dt;
    }
    _nectar.removeWhere((n) {
      if (n.life <= 0) return true;
      if ((n.pos - _p.pos).distance < _p.radius + 11) {
        NpcStore.nectar += 1;
        NpcStore.lifetimeNectar += 1;
        NpcStore.bumpQuest('dusa', 1);
        NpcStore.save();
        _texts.add(FloatText(_p.pos.translate(0, -22), '🍯 NECTAR',
            const Color(0xFFFFD45E)));
        Sfx.play('pickup', vol: 0.7, pitch: 1.35);
        return true;
      }
      return false;
    });

    // Captives + respite visitors share the same entity. The npcId prefix
    // decides: 'respite_*' grants a one-shot heal + nectar; anything else
    // is a permanent NPC rescue that persists to the home.
    for (final c in _captives) {
      c.bob += dt;
      if (c.freed) continue;
      if ((c.pos - _p.pos).distance < _p.radius + 22 &&
          _enemies.isEmpty) {
        c.freed = true;
        Sfx.play('pickup', vol: 0.95, pitch: 1.0);
        _shake = max(_shake, 4.0);
        if (c.npcId.startsWith('respite_')) {
          final visitor = c.npcId.substring('respite_'.length).toUpperCase();
          _p.hp = (_p.hp + _p.maxHp * 0.35).clamp(0, _p.maxHp).toDouble();
          NpcStore.nectar += 1;
          NpcStore.save();
          _toasts.add(Toast(
              '🍞 $visitor SHARED A MEAL',
              'heal · +1 nectar',
              const Color(0xFFB6FFC0)));
        } else {
          NpcStore.rescue(c.npcId);
          _toasts.add(Toast(
              '★ FREED THE ${c.npcId.toUpperCase()}',
              'they are heading to your home',
              const Color(0xFFFFD45E)));
        }
      }
    }

    if (_toasts.isNotEmpty) {
      for (final t in _toasts) {
        t.t -= dt;
      }
      _toasts.removeWhere((t) => t.t <= 0);
    }

    if (_phase == Phase.roomCleared) {
      for (final d in _doors) {
        if ((d.pos - _p.pos).distance < _p.radius + d.r) {
          _enterDoor(d);
          break;
        }
      }
      return;
    }

    // spawn until quota met, capped concurrent
    _spawnTimer -= dt;
    if (_toSpawn > 0 && _spawnTimer <= 0 && _enemies.length < 20) {
      _spawnEnemy();
      _toSpawn--;
      _spawnTimer = (0.85 - _wave * 0.012).clamp(0.28, 0.85).toDouble();
    }

    final atkRange = _p.weapon.kind == WeaponKind.ranged
        ? _p.range
        : _p.weapon.reach + 40;
    // Update the aim-target highlight every tick — used by the painter to
    // draw a yellow ring on whoever the auto-aim is currently shooting at.
    _aimAt = _nearestEnemy(atkRange);
    _p.fireTimer -= dt;
    if (_p.fireTimer <= 0) {
      final t = _aimAt;
      if (t != null) {
        _attack(t.pos - _p.pos);
        _p.fireTimer = _p.effFire * _p.weapon.rofMul * _comboFireMul;
        if (_p.volleys > 1) {
          _p.volleyLeft = _p.volleys - 1;
          _p.volleyTimer = 0.10;
        }
      }
    }
    if (_p.volleyLeft > 0) {
      _p.volleyTimer -= dt;
      if (_p.volleyTimer <= 0) {
        final t = _nearestEnemy(atkRange);
        if (t != null) _attack(t.pos - _p.pos);
        _p.volleyLeft--;
        _p.volleyTimer = 0.10;
      }
    }

    for (final s in _swings) {
      s.life -= dt;
    }
    _swings.removeWhere((s) => s.life <= 0);

    // ballistas fire periodically along their axis
    for (final ba in _ballistas) {
      ba.timer -= dt;
      if (ba.timer <= 0) {
        ba.timer = ba.interval;
        _ebolts.add(EBolt(ba.pos, ba.vel, 1.5 * _floor.dmgMul));
      }
    }

    // traps: step on -> arms -> detonates (AoE on enemies, spawns more,
    // hurts you if you're still on it)
    for (final tr in _traps) {
      if (tr.state == 2) {
        tr.timer -= dt;
        if (tr.timer <= 0) tr.state = 0;
        continue;
      }
      final on = (tr.pos - _p.pos).distance < tr.r;
      if (tr.state == 0 && on) {
        tr.state = 1;
        tr.timer = 0.75;
      } else if (tr.state == 1) {
        tr.timer -= dt;
        if (tr.timer <= 0) {
          _bursts.add(Burst(tr.pos, tr.r + 18));
          _shake = max(_shake, 7.0);
          for (final e in _enemies) {
            if ((e.pos - tr.pos).distance < tr.r + 18) {
              _damageEnemy(e, 6.0 + _wave.toDouble(), true);
            }
          }
          if ((tr.pos - _p.pos).distance < tr.r + 14) {
            _hurtPlayer(3);
          }
          _toSpawn += 2; // the catch: triggering riles up more enemies
          tr.state = 2;
          tr.timer = 6;
          if (_phase != Phase.playing) return;
        }
      }
    }

    for (final b in _bolts) {
      b.pos += b.vel * dt;
      b.life -= dt;
    }
    _bolts.removeWhere(
        (b) => b.life <= 0 || _map.blocksShot(b.pos.dx, b.pos.dy));
    // Hard caps so volleys + auto-fire can't snowball draw cost.
    if (_bolts.length > 80) _bolts.removeRange(0, _bolts.length - 80);
    if (_ebolts.length > 40) _ebolts.removeRange(0, _ebolts.length - 40);

    for (final e in _ebolts) {
      e.pos += e.vel * dt;
      e.life -= dt;
      if ((e.pos - _p.pos).distance < _p.radius + 5) {
        _hurtPlayer(e.damage);
        if (e.kind == 1 && !_p.frostImmune) {
          _p.frostT = max(_p.frostT, 1.4); // frost bolt chills
        } else if (e.kind == 2) {
          _p.fireT = max(_p.fireT, 2.2); // fire bolt burns over time
          _p.fireDps = max(_p.fireDps, e.damage * 0.6);
        }
        e.life = 0;
        if (_phase != Phase.playing) return;
      }
    }
    _ebolts.removeWhere(
        (e) => e.life <= 0 || _map.blocksShot(e.pos.dx, e.pos.dy));

    for (final g in _grenades) {
      g.t += dt;
      if (g.landed) {
        _bursts.add(Burst(g.target, 70));
        _shake = max(_shake, 4.0);
        Sfx.play('kill', vol: 0.6, pitch: 0.95);
        if ((_p.pos - g.target).distance < 60 && _p.invuln <= 0) {
          _hurtPlayer(g.damage * 1.4);
          if (_phase != Phase.playing) return;
        }
      }
    }
    _grenades.removeWhere((g) => g.landed);

    for (final e in _enemies) {
      final dir = _p.pos - e.pos;
      final d = dir.distance;
      final rad = e.radius * 0.7;
      // Boss telegraphed nova: per-floor flavor, charges up then explodes.
      if (e.kind == 3) {
        if (e.novaTele > 0) {
          // Winding up: grow the telegraph ring, then trigger the explosion.
          e.novaTele -= dt;
          e.novaRadius = (160 + 60 * _floorIdx).toDouble();
          if (e.novaTele <= 0) {
            _bursts.add(Burst(e.pos, e.novaRadius));
            _shake = max(_shake, 10.0);
            Sfx.play('kill', vol: 0.8);
            // AoE explosion damages the player if inside the ring.
            if ((_p.pos - e.pos).distance < e.novaRadius) {
              _hurtPlayer(e.damage * 1.4);
              if (_phase != Phase.playing) return;
            }
            // Per-floor signature attack on detonation.
            switch (_floorIdx) {
              case 0: // Floor 1 — splash nova only.
                break;
              case 1: // Floor 2 — 8-bolt radial fan of standard bolts.
                for (int i = 0; i < 8; i++) {
                  final a = i * (2 * pi / 8);
                  _ebolts.add(EBolt(e.pos,
                      Offset(cos(a), sin(a)) * 180, e.damage));
                }
                break;
              case 2: // Floor 3 — 6 frost bolts (a colder, slower fan).
                for (int i = 0; i < 6; i++) {
                  final a = i * (2 * pi / 6);
                  _ebolts.add(EBolt(e.pos,
                      Offset(cos(a), sin(a)) * 160, e.damage,
                      kind: 1));
                }
                break;
              case 3: // Floor 4 — summon a kamikaze wingman beside the boss.
                _enemies.add(Enemy(
                  pos: e.pos + Offset(40, 0),
                  hp: (2 + _wave * 0.4) * _floor.hpMul,
                  speed: (130 + _wave) * _floor.spdMul,
                  damage: 2.0 * _floor.dmgMul,
                  radius: 12,
                  kind: 8,
                  bounty: 1,
                  xp: 1,
                ));
                break;
              default: // Floor 5+ — fiery 8-bolt fan that burns.
                for (int i = 0; i < 8; i++) {
                  final a = i * (2 * pi / 8) + 0.2;
                  _ebolts.add(EBolt(e.pos,
                      Offset(cos(a), sin(a)) * 200, e.damage,
                      kind: 2));
                }
            }
            e.novaTele = 0;
            e.novaRadius = 0;
            e.novaT = 4.5; // cooldown until next nova
          }
        } else {
          e.novaT -= dt;
          if (e.novaT <= 0) {
            e.novaTele = 1.1; // 1.1s telegraph window
          }
        }
      }
      if (e.kind == 4) {
        if (d < 220 && d > 0.01) {
          // Retreating stays direct — kiter is right next to the player.
          e.pos = _slide(e.pos, -dir / d * e.speed * dt, rad);
        } else if (d > 300 && d > 0.01) {
          final chase = _pathClear(e.pos, _p.pos)
              ? dir / d
              : _flowStep(e.pos);
          if (chase != Offset.zero) {
            e.pos = _slide(e.pos, chase * e.speed * dt, rad);
          }
        }
        e.shootTimer -= dt;
        if (e.shootTimer <= 0 && d < 460 && d > 0.01 &&
            _pathClear(e.pos, _p.pos)) {
          e.shootTimer = 1.7;
          _ebolts.add(EBolt(e.pos, dir / d * 220, e.damage, kind: e.boltKind));
        }
      } else if (e.kind == 9) {
        // GRENADIER: keep medium distance + lob arcing grenades.
        if (d < 240 && d > 0.01) {
          e.pos = _slide(e.pos, -dir / d * e.speed * dt, rad);
        } else if (d > 360 && d > 0.01) {
          final chase = _pathClear(e.pos, _p.pos)
              ? dir / d
              : _flowStep(e.pos);
          if (chase != Offset.zero) {
            e.pos = _slide(e.pos, chase * e.speed * dt, rad);
          }
        }
        e.grenadeT -= dt;
        if (e.grenadeT <= 0 && d < 520 && d > 0.01) {
          e.grenadeT = 2.4;
          _grenades.add(Grenade(e.pos, _p.pos, e.damage));
        }
      } else if (e.kind == 10) {
        // BULL: walk → wind up (telegraph) → charge → optional wall-stun.
        if (e.stunT > 0) {
          e.stunT -= dt;
        } else if (e.chargeRem > 0) {
          // Currently dashing in the locked direction.
          e.chargeRem -= dt;
          final before = e.pos;
          e.pos = _slide(e.pos, e.chargeDir * 360 * dt, rad);
          // If a wall blocked the slide (no progress), stun briefly.
          if ((e.pos - before).distance < 1 && e.chargeRem > 0.05) {
            e.stunT = 0.7;
            e.chargeRem = 0;
            _bursts.add(Burst(e.pos, 28));
            _shake = max(_shake, 4.0);
          }
        } else if (e.chargeWind > 0) {
          e.chargeWind -= dt;
          if (e.chargeWind <= 0) {
            // Lock direction toward the player at this instant.
            if (d > 0.01) {
              e.chargeDir = dir / d;
            } else {
              e.chargeDir = const Offset(1, 0);
            }
            e.chargeRem = 0.75;
            Sfx.play('kill', vol: 0.5, pitch: 0.8);
          }
        } else {
          // Walk normally; queue a charge every ~3-4s when in sight.
          if (d > 0.01) {
            final step = _pathClear(e.pos, _p.pos) ? dir / d : _flowStep(e.pos);
            if (step != Offset.zero) {
              e.pos = _slide(e.pos, step * e.speed * dt, rad);
            }
          }
          e.chargeCd -= dt;
          if (e.chargeCd <= 0 && d < 340 && _pathClear(e.pos, _p.pos)) {
            e.chargeWind = 1.0;
            e.chargeCd = 3.6 + _rng.nextDouble() * 1.2;
          }
        }
      } else if (e.kind == 11) {
        // SLAMMER: walks, jumps periodically. While airborne it locks a
        // landing reticle and drops there for AoE damage.
        if (e.slamT > 0) {
          e.slamT -= dt;
          if (e.slamT <= 0) {
            // Land + slam.
            e.pos = e.slamTarget;
            _bursts.add(Burst(e.slamTarget, 72));
            _shake = max(_shake, 6.0);
            Sfx.play('kill', vol: 0.6, pitch: 0.85);
            if ((_p.pos - e.slamTarget).distance < 60 && _p.invuln <= 0) {
              _hurtPlayer(e.damage * 1.4);
              if (_phase != Phase.playing) return;
            }
            e.slamCd = 3.0 + _rng.nextDouble();
          }
        } else {
          if (d > 0.01) {
            final step = _pathClear(e.pos, _p.pos) ? dir / d : _flowStep(e.pos);
            if (step != Offset.zero) {
              e.pos = _slide(e.pos, step * e.speed * dt, rad);
            }
          }
          e.slamCd -= dt;
          if (e.slamCd <= 0 && d < 420) {
            e.slamT = 1.2;
            e.slamTarget = _p.pos;
            Sfx.play('dash', vol: 0.5, pitch: 1.1);
          }
        }
      } else if (d > 0.01) {
        // Walk straight when there's line of sight; otherwise follow the
        // flow field around walls + pools.
        final step = _pathClear(e.pos, _p.pos) ? dir / d : _flowStep(e.pos);
        if (step != Offset.zero) {
          e.pos = _slide(e.pos, step * e.speed * dt, rad);
        }
      }

      if (e.dotTimer > 0) {
        e.dotTimer -= dt;
        e.hp -= e.dotDps * dt;
      }
      if (e.doomT > 0) {
        e.doomT -= dt;
        if (e.doomT <= 0 && e.doomAmt > 0) {
          _bursts.add(Burst(e.pos, 36));
          e.hp -= e.doomAmt;
          _texts.add(FloatText(e.pos.translate(0, -e.radius), 'DOOM',
              const Color(0xFFFF6BE0)));
          e.doomAmt = 0;
        }
      }
      if (e.touchTimer > 0) e.touchTimer -= dt;
      if (e.flash > 0) e.flash -= dt;
      if (d < e.radius + _p.radius && e.touchTimer <= 0) {
        e.touchTimer = 0.7;
        if (_p.thorns > 0) {
          e.hp -= _p.thorns;
          _texts.add(FloatText(e.pos.translate(0, -e.radius),
              '${_p.thorns.toInt()}', const Color(0xFFFFB347)));
        }
        if (e.kind == 8) {
          // KAMIKAZE: bursts on contact, hits hard, dies.
          _bursts.add(Burst(e.pos, 96));
          _shake = max(_shake, 7.0);
          Sfx.play('kill', vol: 0.75);
          _hurtPlayer(e.damage * 1.6);
          e.hp = 0;
        } else {
          if (e.kind == 6 && !_p.frostImmune) {
            _p.frostT = 1.5; // FROST chills the player on touch
          }
          _hurtPlayer(e.damage);
          if (e.kind == 7) {
            // VAMPIRE feeds: heal from the damage it dealt.
            e.hp = (e.hp + e.damage * 0.8).clamp(0, e.maxHp).toDouble();
          }
        }
        if (_phase != Phase.playing) return;
      }
    }

    for (final b in _bolts) {
      if (b.life <= 0) continue;
      for (final e in _enemies) {
        if (b.hit.contains(e)) continue;
        if ((b.pos - e.pos).distance < e.radius + 5) {
          _damageEnemy(e, b.damage, b.crit, b.pos);
          _zeusChain(e, b.damage * 0.6);
          if (b.dot > 0) {
            e.dotDps = b.dot;
            e.dotTimer = 2.0;
          }
          if (b.splash > 0) {
            _bursts.add(Burst(b.pos, b.splash));
            for (final o in _enemies) {
              if (o == e) continue;
              if ((o.pos - b.pos).distance < b.splash) {
                _damageEnemy(o, b.damage * 0.6, false);
              }
            }
            b.life = 0;
            break;
          }
          b.hit.add(e);
          if (b.pierce > 0) {
            b.pierce--;
          } else {
            b.life = 0;
            break;
          }
        }
      }
    }
    _enemies.removeWhere((e) {
      if (e.hp <= 0) {
        if (e.kind == 3) _shake = max(_shake, 11.0);
        _bursts.add(Burst(e.pos, e.kind == 3 ? 80 : 32));
        Sfx.play('kill',
            vol: e.kind == 3 ? 0.85 : 0.55,
            pitch: e.kind == 3 ? 0.7 : (1.0 + min(_combo, 12) * 0.02),
            jitter: e.kind == 3 ? 0.0 : 0.08);
        _shake = max(_shake, e.kind == 3 ? 11.0 : 2.0);
        _orbs.add(Orb(e.pos, e.xp));
        _p.obols += e.bounty;
        _p.mp = (_p.mp + 0.8).clamp(0, _p.maxMp).toDouble();
        if (_p.lifesteal > 0) {
          _p.hp = (_p.hp + _p.lifesteal).clamp(0, _p.maxHp).toDouble();
        }
        _p.kills++;
        _combo++;
        _comboT = 3.5;
        // Stats + achievement bookkeeping.
        GameStats.killsByKind.update(e.kind, (n) => n + 1,
            ifAbsent: () => 1);
        if (e.kind == 3) {
          GameStats.totalBossKills++;
          NpcStore.bumpQuest('achilles', 1);
        }
        if (e.kind == 9) NpcStore.bumpQuest('chef', 1);
        if (_combo > GameStats.bestCombo) GameStats.bestCombo = _combo;
        if (_combo > _runMaxCombo) _runMaxCombo = _combo;
        // Boss kills can drop a healing heart for the player.
        if (e.kind == 3) {
          _hearts.add(Heart(e.pos));
          // Bosses always drop a nectar bottle so each clear is a small
          // gift-shop run for the home NPCs.
          _nectar.add(NectarDrop(e.pos.translate(20, 0)));
        } else if (e.elite && _rng.nextDouble() < 0.18) {
          _hearts.add(Heart(e.pos));
        }
        if (e.elite &&
            _rng.nextDouble() < 0.45 + Loadout.blessingNectarBonus) {
          _nectar.add(NectarDrop(e.pos));
        } else if (NpcStore.questDone.contains('chef') &&
            _rng.nextDouble() < 0.05) {
          // Chef's quest reward: small chance per normal kill, always on.
          _nectar.add(NectarDrop(e.pos));
        }
        _checkAchievements();
        return true;
      }
      return false;
    });

    final treasureWait =
        _roomKind == RoomKind.treasure && _orbs.isNotEmpty;
    // Only fire room-end once. Without the phase gate, picking up the last
    // XP orb (or any tick after clear) re-runs _roomEnd and re-rolls the
    // exit doors — which is what was making the portals change on the
    // player after they appeared.
    if (_phase == Phase.playing &&
        _toSpawn <= 0 &&
        _enemies.isEmpty &&
        !treasureWait) {
      _roomEnd();
    }
  }

  void _hurtPlayer(double dmg) {
    if (_p.invuln > 0) return;
    _p.hp -= dmg;
    _p.hurtFlash = 0.25;
    _shake = max(_shake, 7.0);
    _haptic(HapticFeedback.mediumImpact);
    _combo = 0;
    _comboT = 0;
    if (_p.hp <= 0) {
      if (_p.revives > 0) {
        _p.revives--;
        _p.hp = _p.maxHp * 0.5;
        _p.invuln = 1.6;
        _shake = max(_shake, 12.0);
        _bursts.add(Burst(_p.pos, 140));
        _texts.add(FloatText(_p.pos.translate(0, -_p.radius - 16),
            'DEATH DEFIED', const Color(0xFFFFD45E)));
        return;
      }
      _p.hp = 0;
      _gameOver();
    }
  }

  void _damageEnemy(Enemy e, double dmg, bool crit, [Offset? from]) {
    dmg *= _comboDmgMul;
    // SHIELDED enemies absorb half the hit until their armor breaks at 50% HP.
    if (e.kind == 5 && e.hp / e.maxHp > 0.5) dmg *= 0.5;
    e.hp -= dmg;
    e.flash = 0.1;
    _bursts.add(Burst(e.pos, crit ? 22 : 14));
    if (crit) {
      // Crits get a wider ring + count toward smith's quest tracker.
      _bursts.add(Burst(e.pos, 44));
      GameStats.totalCrits++;
      NpcStore.bumpQuest('smith', 1);
    }
    Sfx.play('hit',
        vol: crit ? 0.7 : 0.45,
        pitch: crit ? 1.25 : 1.0,
        jitter: 0.06);
    if (crit) _shake = max(_shake, 4.0);
    _texts.add(FloatText(
      e.pos.translate(0, -e.radius),
      crit ? '${dmg.toInt()}!' : '${dmg.toInt()}',
      crit ? const Color(0xFFFF9A3C) : Colors.white,
      size: crit ? 22 : 14,
    ));
    // Tiny hit-stop on crits + boss damage so impactful hits register.
    if (crit || e.kind == 3) {
      _freezeT = max(_freezeT, e.kind == 3 ? 0.07 : 0.05);
    }
    if (from != null && _p.knockback > 0) {
      final v = e.pos - from;
      final n = v.distance;
      if (n > 0.01) {
        e.pos = _slide(e.pos, v / n * _p.knockback, e.radius * 0.6);
      }
    }
    if (_p.doomAmt > 0 && e.doomT <= 0) {
      e.doomT = 1.0;
      e.doomAmt = _p.doomAmt;
    }
  }

  void _zeusChain(Enemy src, double dmg) {
    if (_p.zeus <= 0) return;
    final hit = <Enemy>{src};
    var from = src;
    for (var j = 0; j < _p.zeus; j++) {
      Enemy? next;
      var bd = 180.0 * 180.0;
      for (final e in _enemies) {
        if (hit.contains(e)) continue;
        final d2 = (e.pos - from.pos).distanceSquared;
        if (d2 < bd) {
          bd = d2;
          next = e;
        }
      }
      if (next == null) break;
      _texts.add(FloatText(next.pos, '⚡', const Color(0xFF8CD8FF)));
      _damageEnemy(next, dmg, true);
      hit.add(next);
      from = next;
    }
  }

  Enemy? _nearestEnemy(double maxRange) {
    Enemy? best;
    double bd = maxRange * maxRange;
    for (final e in _enemies) {
      final dx = e.pos.dx - _p.pos.dx;
      final dy = e.pos.dy - _p.pos.dy;
      final d2 = dx * dx + dy * dy;
      if (d2 < bd) {
        bd = d2;
        best = e;
      }
    }
    return best;
  }

  void _attack(Offset aim) {
    final w = _p.weapon;
    if (w.kind == WeaponKind.ranged) {
      _fireAt(aim);
      return;
    }
    final ang = atan2(aim.dy, aim.dx);
    final reach = w.reach;
    final arc = w.arc;
    _swings.add(Swing(_p.pos, ang, reach, arc, w.kind == WeaponKind.thrust));
    for (final e in _enemies) {
      final v = e.pos - _p.pos;
      final d = v.distance;
      if (d > reach + e.radius || d < 0.01) continue;
      var da = (atan2(v.dy, v.dx) - ang) % (2 * pi);
      if (da > pi) da -= 2 * pi;
      if (da < -pi) da += 2 * pi;
      if (da.abs() <= arc / 2) {
        final crit = _rng.nextDouble() < _p.critChance + 0.05;
        _damageEnemy(
            e, _p.damage * w.dmgMul * (crit ? 2 : 1), crit, _p.pos);
        _zeusChain(e, _p.damage * w.dmgMul * 0.5);
        if (_p.dot > 0) {
          e.dotDps = _p.dot;
          e.dotTimer = 2.0;
        }
      }
    }
  }

  void _fireAt(Offset aim) {
    final w = _p.weapon;
    final baseAng = atan2(aim.dy, aim.dx);
    final n = w.pellets + (_p.projectiles - 1);
    final spread = w.spread > 0
        ? w.spread
        : (n > 1 ? 0.16 : 0.0);
    final speed = _p.projSpeed * w.speedMul;
    final pierce = _p.pierce + w.pierceAdd;
    final splash = _p.splash + w.splashAdd;
    for (var i = 0; i < n; i++) {
      final off = n > 1 ? (i / (n - 1) - 0.5) * spread : 0.0;
      final ang = baseAng + off;
      final crit = _rng.nextDouble() < _p.critChance;
      final dmg = _p.damage * w.dmgMul * (crit ? 2 : 1);
      _bolts.add(Bolt(
        _p.pos,
        Offset(cos(ang), sin(ang)) * speed,
        dmg,
        crit,
        pierce,
        splash,
        _p.dot,
      ));
    }
  }

  bool get _canCast =>
      _phase == Phase.playing &&
      _p.abilityTimer <= 0 &&
      _p.mp >= widget.def.abilityCost;

  bool get _canDash =>
      (_phase == Phase.playing || _phase == Phase.roomCleared) &&
      _p.dashTimer <= 0;

  // Trigger a haptic pulse on supported platforms; silently no-op on web.
  void _haptic(Future<void> Function() impact) {
    if (!Settings.haptics) return;
    try {
      impact();
    } catch (_) {}
  }

  void _dash() {
    if (!_canDash) return;
    final dir = _moveDir != Offset.zero ? _moveDir : _facing;
    final n = dir.distance;
    if (n < 0.01) return;
    final unit = dir / n;
    _p.dashTimer = _p.dashCd;
    _p.invuln = max(_p.invuln, 0.32); // i-frames
    Sfx.play('dash', vol: 0.55);
    _haptic(HapticFeedback.lightImpact);
    _shake = max(_shake, 3.0);
    const dist = 150.0;
    for (var i = 0; i < 6; i++) {
      _ghosts.add(Ghost(_p.pos));
      _p.pos = _slide(_p.pos, unit * (dist / 6), _p.radius * 0.7);
    }
    _facing = unit;
    _texts.add(FloatText(_p.pos.translate(0, -_p.radius - 14), 'DASH',
        const Color(0xFF8CC8FF)));
  }

  void _castAbility() {
    if (!_canCast) return;
    _p.mp -= widget.def.abilityCost;
    _p.abilityTimer = widget.def.abilityCd;
    final d = _p.damage;
    switch (widget.def.cls) {
      case HeroClass.tank:
        {
          _bursts.add(Burst(_p.pos, 150));
          _shake = max(_shake, 9.0);
          for (final e in _enemies) {
            final v = e.pos - _p.pos;
            if (v.distance < 150) {
              _damageEnemy(e, d * 4, true);
              if (v.distance > 0.01) {
                e.pos = _slide(e.pos, v / v.distance * 70, e.radius * 0.7);
              }
            }
          }
          break;
        }
      case HeroClass.archer:
        {
          for (var i = 0; i < 16; i++) {
            final ang = i * pi / 8;
            _bolts.add(Bolt(
              _p.pos,
              Offset(cos(ang), sin(ang)) * _p.projSpeed,
              d,
              false,
              _p.pierce + 1,
              _p.splash,
              _p.dot,
            ));
          }
          break;
        }
      case HeroClass.mage:
        {
          final tgt = _nearestEnemy(4000);
          final at = tgt?.pos ?? _p.pos;
          _bursts.add(Burst(at, 130));
          _shake = max(_shake, 10.0);
          for (final e in _enemies) {
            if ((e.pos - at).distance < 130) _damageEnemy(e, d * 5, true);
          }
          break;
        }
      case HeroClass.warlock:
        {
          for (final e in _enemies) {
            _damageEnemy(e, d * 2, false);
            e.dotDps = (_p.dot < 3 ? 3.0 : _p.dot);
            e.dotTimer = 4;
          }
          break;
        }
      case HeroClass.assassin:
        {
          final tgt = _nearestEnemy(4000);
          if (tgt != null) _p.pos = tgt.pos;
          _p.invuln = 1.0;
          _bursts.add(Burst(_p.pos, 70));
          _shake = max(_shake, 8.0);
          for (final e in _enemies) {
            if ((e.pos - _p.pos).distance < 70) _damageEnemy(e, d * 6, true);
          }
          break;
        }
      case HeroClass.gunner:
        {
          _p.frenzy = 4;
          break;
        }
    }
    _texts.add(FloatText(_p.pos.translate(0, -_p.radius - 16),
        widget.def.abilityName, const Color(0xFF8CC8FF)));
  }

  Offset _spawnPoint() {
    for (var i = 0; i < 60; i++) {
      final p = _map.randomFloor(_rng);
      final d = (p - _p.pos).distance;
      if (d > 220 && d < 760) return p;
    }
    return _map.randomFloor(_rng);
  }

  int _xpFor(int kind) {
    final base = switch (kind) {
      1 => 1,
      2 => 4,
      3 => 14,
      4 => 3,
      _ => 1,
    };
    return base + _floorIdx;
  }

  void _spawnEnemy() {
    final p = _spawnPoint();
    final f = _floor;
    final ws = 1 + _wave * 0.05;

    if (_bossWave && !_bossSpawned) {
      _bossSpawned = true;
      _enemies.add(Enemy(
        pos: p,
        hp: (26 + _wave * 5) * f.hpMul * Loadout.enemyMul,
        speed: (70 + _wave * 1.4) * f.spdMul,
        damage: 2.5 * f.dmgMul * Loadout.enemyMul,
        radius: 36,
        kind: 3,
        bounty: 25,
        xp: _xpFor(3),
      ));
      // Drop a boss-intro banner so the wave reads as an event.
      _bossIntro = kBossNames[_floorIdx.clamp(0, kBossNames.length - 1)];
      _bossIntroT = 2.4;
      _shake = max(_shake, 6.0);
      Sfx.play('kill', vol: 0.85, pitch: 0.7);
      return;
    }

    final roll = _rng.nextDouble();
    if (_floorIdx >= 2 && roll < 0.05) {
      // GRENADIER: slow tosser. Lobs an AoE grenade every couple of seconds.
      _enemies.add(Enemy(
        pos: p,
        hp: (7 + _wave * 0.9) * f.hpMul,
        speed: (62 + _wave * 0.5) * f.spdMul,
        damage: 1.8 * f.dmgMul,
        radius: 15,
        kind: 9,
        bounty: 3,
        xp: _xpFor(2),
      ));
    } else if (_floorIdx >= 1 && roll < 0.11) {
      // BULL: walks slowly, winds up, then charges in a straight line.
      _enemies.add(Enemy(
        pos: p,
        hp: (16 + _wave * 1.7) * f.hpMul * ws,
        speed: (80 + _wave * 0.7) * f.spdMul,
        damage: 2.4 * f.dmgMul,
        radius: 22,
        kind: 10,
        bounty: 4,
        xp: _xpFor(2),
      ));
    } else if (_floorIdx >= 2 && roll < 0.16) {
      // SLAMMER: walker that jumps + slams the player's last position.
      _enemies.add(Enemy(
        pos: p,
        hp: (8 + _wave * 1.0) * f.hpMul,
        speed: (88 + _wave * 0.9) * f.spdMul,
        damage: 2.0 * f.dmgMul,
        radius: 18,
        kind: 11,
        bounty: 3,
        xp: _xpFor(2),
      ));
    } else if (_floorIdx >= 1 && roll < 0.22) {
      // KAMIKAZE: fast and fragile, but explodes on touch.
      _enemies.add(Enemy(
        pos: p,
        hp: (2 + _wave * 0.4) * f.hpMul,
        speed: (150 + _wave * 1.6) * f.spdMul,
        damage: 2.5 * f.dmgMul,
        radius: 12,
        kind: 8,
        bounty: 2,
        xp: _xpFor(1),
      ));
    } else if (_floorIdx >= 1 && roll < 0.28) {
      // SHIELDED: tanky brute that halves damage above 50% HP.
      _enemies.add(Enemy(
        pos: p,
        hp: (14 + _wave * 1.6) * f.hpMul * ws,
        speed: (66 + _wave * 0.6) * f.spdMul,
        damage: 2.5 * f.dmgMul,
        radius: 25,
        kind: 5,
        bounty: 4,
        xp: _xpFor(2),
      ));
    } else if (_floorIdx >= 2 && roll < 0.34) {
      // FROST: chills the player's movement on contact.
      _enemies.add(Enemy(
        pos: p,
        hp: (5 + _wave * 0.7) * f.hpMul,
        speed: (95 + _wave * 1.0) * f.spdMul,
        damage: 1.5 * f.dmgMul,
        radius: 14,
        kind: 6,
        bounty: 2,
        xp: _xpFor(1),
      ));
    } else if (_floorIdx >= 3 && roll < 0.40) {
      // VAMPIRE: heals from contact damage dealt.
      _enemies.add(Enemy(
        pos: p,
        hp: (7 + _wave * 1.0) * f.hpMul,
        speed: (95 + _wave * 1.1) * f.spdMul,
        damage: 1.6 * f.dmgMul,
        radius: 16,
        kind: 7,
        bounty: 3,
        xp: _xpFor(2),
      ));
    } else if (_floorIdx >= 2 && roll < 0.50) {
      // Ranged shooter / kiter.
      _enemies.add(Enemy(
        pos: p,
        hp: (6 + _wave * 0.7) * f.hpMul,
        speed: (105 + _wave * 0.8) * f.spdMul,
        damage: 1.0 * f.dmgMul,
        radius: 14,
        kind: 4,
        bounty: 2,
        xp: _xpFor(4),
      ));
    } else if (roll < 0.65 + _floorIdx * 0.02) {
      _enemies.add(Enemy(
        pos: p,
        hp: (2 + _wave * 0.35) * f.hpMul * ws,
        speed: (160 + _wave * 1.8) * f.spdMul,
        damage: 1.0 * f.dmgMul,
        radius: 11,
        kind: 1,
        bounty: 1,
        xp: _xpFor(1),
      ));
    } else if (roll < 0.82) {
      _enemies.add(Enemy(
        pos: p,
        hp: (9 + _wave * 1.4) * f.hpMul * ws,
        speed: (78 + _wave * 0.9) * f.spdMul,
        damage: 2.0 * f.dmgMul,
        radius: 23,
        kind: 2,
        bounty: 3,
        xp: _xpFor(2),
      ));
    } else {
      _enemies.add(Enemy(
        pos: p,
        hp: (3 + _wave * 0.8) * f.hpMul * ws,
        speed: (102 + _wave * 1.3) * f.spdMul,
        damage: 1.0 * f.dmgMul,
        radius: 15,
        kind: 0,
        bounty: 1,
        xp: _xpFor(0),
      ));
    }
    // elite: rare, beefier, glowing, worth much more
    final e = _enemies.isNotEmpty ? _enemies.last : null;
    if (e != null) {
      if (e.kind != 3 && _rng.nextDouble() < 0.08 + _floorIdx * 0.015) {
        e.elite = true;
        e.hp *= 2.4;
        e.damage *= 1.5;
        e.radius *= 1.3;
        e.bounty *= 4;
        e.xp *= 3;
      }
      if (Loadout.heat > 0) {
        e.hp *= Loadout.enemyMul;
        e.damage *= Loadout.enemyMul;
        e.speed *= 1 + Loadout.heat * 0.03;
      }
      // Pick bolt flavor for ranged shooters based on floor depth.
      if (e.kind == 4) {
        final r = _rng.nextDouble();
        if (_floorIdx >= 3 && r < 0.30) {
          e.boltKind = 2; // fire bolt
        } else if (_floorIdx >= 2 && r < 0.55) {
          e.boltKind = 1; // frost bolt
        } else {
          e.boltKind = 0;
        }
      }
    }
  }

  // Run all achievement predicates after a relevant event and emit a toast
  // for each newly-unlocked achievement.
  void _checkAchievements() {
    bool got(String id) => GameStats.achievements.contains(id);
    void unlock(String id) {
      if (got(id)) return;
      final ach = kAchievements.firstWhere((a) => a.id == id);
      GameStats.achievements.add(id);
      GameStats.save();
      _toasts.add(Toast('★ ${ach.title}', ach.desc));
      Sfx.play('pickup', vol: 0.9, pitch: 1.35);
    }

    if (GameStats.totalKills + _p.kills >= 1) unlock('first_blood');
    if (GameStats.totalKills + _p.kills >= 100) unlock('kills_100');
    if (GameStats.totalKills + _p.kills >= 1000) unlock('kills_1000');
    if (_combo >= 20) unlock('combo_20');
    if (_combo >= 50) unlock('combo_50');
    if (GameStats.totalBossKills >= 1) unlock('boss_1');
    if (GameStats.totalBossKills >= 5) unlock('boss_5');
    if (_floorIdx + 1 >= 3) unlock('floor_3');
    if (_floorIdx + 1 >= 5) unlock('floor_5');
    if ((GameStats.killsByKind[7] ?? 0) >= 50) unlock('vampire_50');
    if ((GameStats.killsByKind[8] ?? 0) >= 50) unlock('kamikaze_50');
    if ((GameStats.killsByKind[5] ?? 0) >= 50) unlock('shielded_50');
  }

  void _gainXp(int amount) {
    _p.xp += amount;
    while (_p.xp >= _p.xpToNext) {
      _p.xp -= _p.xpToNext;
      _p.level++;
      _p.xpToNext = 5 + _p.level * 3;
      _openBoon();
      return; // resolve one boon at a time; rest applied after pick
    }
  }

  void _openBoon() {
    _choices = _rollUpgrades();
    _phase = Phase.levelUp;
  }

  List<Upgrade> _rollUpgrades() {
    final bag = <Upgrade>[];
    for (final u in kUpgrades) {
      final n = u.tier == 0 ? 4 : (u.tier == 1 ? 2 : 1);
      for (var i = 0; i < n; i++) {
        bag.add(u);
      }
    }
    bag.shuffle(_rng);
    final out = <Upgrade>[];
    for (final u in bag) {
      if (!out.contains(u)) out.add(u);
      if (out.length == 3) break;
    }
    return out;
  }

  void _pickUpgrade(Upgrade u) {
    u.apply(_p);
    _runBoons.add(u.title);
    NpcStore.bumpQuest('scribe', 1);
    _texts.add(FloatText(_p.pos.translate(0, -_p.radius - 14), u.title,
        const Color(0xFF8CFF98)));
    if (_p.xp >= _p.xpToNext) {
      _p.xp -= _p.xpToNext;
      _p.level++;
      _p.xpToNext = 5 + _p.level * 3;
      setState(_openBoon);
    } else if (_boonThenNext) {
      _boonThenNext = false;
      _nextRoom();
    } else {
      setState(() => _phase = Phase.playing);
    }
  }

  void _roomEnd() {
    if (_roomKind == RoomKind.challenge) {
      _p.obols += 50 + _floorIdx * 12;
      _p.hp =
          (_p.hp + _p.maxHp * 0.30).clamp(0, _p.maxHp).toDouble();
      _texts.add(FloatText(_p.pos.translate(0, -28),
          'CHALLENGE CLEAR!', const Color(0xFFFF9A3C)));
    }
    _p.obols += 4 + _wave * 2;
    if (_wave >= kMaxWaves) {
      _victory();
      return;
    }
    if (_wave - 1 > GameStats.bestWave) GameStats.bestWave = _wave - 1;
    _doors.clear();
    if (_bossWave) {
      final slots = _cornerDoorSlots(_exitCorner, 1);
      _doors.add(Door(
        slots.isNotEmpty ? slots.first : _map.roomCenter(_map.rooms.length - 1),
        DoorDef('🛒', "CHARON'S SHOP", 'spend your obols', DoorKind.shop,
            (_) {}),
      ));
    } else {
      final n = 2 + _rng.nextInt(2); // 2 or 3 portals at the opposite corner
      final picks = _rollDoorDefs(n);
      final slots = _cornerDoorSlots(_exitCorner, n);
      for (var i = 0; i < n && i < slots.length; i++) {
        _doors.add(Door(slots[i], picks[i]));
      }
    }
    // Doors must always be reachable — clear pools/walls around them. The
    // disk also carves the archway into the wall the door sits in.
    for (final d in _doors) {
      _map.clearDisk(d.pos.dx, d.pos.dy, 2.6);
    }
    _phase = Phase.roomCleared;
  }

  List<DoorDef> _rollDoorDefs([int n = 2]) {
    final fi = _floorIdx;
    final gun = kWeapons[_rng.nextInt(kWeapons.length)];
    final pool = <DoorDef>[
      DoorDef('🔫', 'ARMORY: ${gun.name}', gun.desc, DoorKind.reward,
          (p) => p.weapon = gun),
      DoorDef('💰', 'TREASURE', '+${12 + fi * 8} obols', DoorKind.reward,
          (p) => p.obols += 12 + fi * 8),
      DoorDef('❤', 'FOUNTAIN', 'heal 45% + 50% MP', DoorKind.reward, (p) {
        p.hp = (p.hp + p.maxHp * 0.45).clamp(0, p.maxHp).toDouble();
        p.mp = (p.mp + p.maxMp * 0.5).clamp(0, p.maxMp).toDouble();
      }),
      DoorDef('✦', 'BOON', 'pick a power-up', DoorKind.boon, (_) {}),
      DoorDef('🗡', 'ARSENAL', '+1 projectile', DoorKind.reward,
          (p) => p.projectiles = (p.projectiles + 1).clamp(1, 8).toInt()),
      DoorDef('👁', 'WATCHTOWER', '+0.2 view', DoorKind.reward,
          (p) => p.vision = (p.vision + 0.2).clamp(1.0, 2.6).toDouble()),
      _chaosDoor(),
      // Special rooms — the door label hints, the room itself is the prize.
      DoorDef('💎', 'TREASURE ROOM', 'empty room full of obols',
          DoorKind.treasure, (_) {}),
      DoorDef('⚔', 'CHALLENGE ROOM', 'more foes, bigger reward',
          DoorKind.challenge, (_) {}),
      DoorDef('⛩', 'SHRINE', 'a blessing — at a price',
          DoorKind.shrine, (_) {}),
      // Hidden NPC encounter — a calm room with a wandering visitor.
      DoorDef('🏠', 'WAYHOUSE', 'a quiet visitor + small gift',
          DoorKind.respite, (_) {}),
    ]..shuffle(_rng);
    return pool.take(n.clamp(2, pool.length).toInt()).toList();
  }

  DoorDef _chaosDoor() {
    // Chaos: a real cost, then a strong permanent gift
    final pairs = <List<dynamic>>[
      ['-15% max HP, but +2 damage', (Player p) {
        p.maxHp = (p.maxHp * 0.85);
        p.hp = p.hp.clamp(1, p.maxHp).toDouble();
        p.damage += 2;
      }],
      ['-20 speed, but +3 pierce', (Player p) {
        p.speed = (p.speed - 20).clamp(60, 999).toDouble();
        p.pierce += 3;
      }],
      ['lose all obols, but +1 Death Defiance', (Player p) {
        p.obols = 0;
        p.revives += 1;
      }],
      ['-25% fire rate, but +1 projectile', (Player p) {
        p.fireInterval *= 1.25;
        p.projectiles = (p.projectiles + 1).clamp(1, 8).toInt();
      }],
    ];
    final c = pairs[_rng.nextInt(pairs.length)];
    return DoorDef('🌀', 'CHAOS', c[0] as String, DoorKind.reward,
        c[1] as void Function(Player));
  }

  void _enterDoor(Door d) {
    Sfx.play('door', vol: 0.6);
    if (d.def.kind == DoorKind.shop) {
      _shop = _rollShop();
      _doors.clear();
      setState(() => _phase = Phase.shop);
      return;
    }
    if (d.def.kind == DoorKind.boon) {
      _doors.clear();
      _boonThenNext = true;
      setState(_openBoon);
      return;
    }
    switch (d.def.kind) {
      case DoorKind.treasure:
        _roomKind = RoomKind.treasure;
        break;
      case DoorKind.challenge:
        _roomKind = RoomKind.challenge;
        break;
      case DoorKind.shrine:
        _roomKind = RoomKind.shrine;
        break;
      case DoorKind.respite:
        _roomKind = RoomKind.respite;
        break;
      default:
        _roomKind = RoomKind.normal;
    }
    d.def.apply(_p);
    _nextRoom();
  }

  void _nextRoom() {
    _wave++;
    _p.hp = (_p.hp + _p.maxHp * 0.12).clamp(0, _p.maxHp).toDouble();
    // Re-randomize the lower-corner entry each room so left/right alternates
    // unpredictably; portals always land at the opposite upper corner.
    _entryCorner = 2 + _rng.nextInt(2);
    _genRoom();
    if (_roomKind == RoomKind.shrine) {
      _openShrine();
    } else {
      setState(() => _phase = Phase.playing);
    }
  }

  // Returns the (col, row) of the chosen corner of the floor bounding box.
  // Corner ids: 0=upper-left, 1=upper-right, 2=lower-left, 3=lower-right.
  (int, int) _cornerCell(int corner, Rect b) {
    final tc = (corner == 0 || corner == 2) ? b.left.toInt() : b.right.toInt();
    final tr = (corner == 0 || corner == 1) ? b.top.toInt() : b.bottom.toInt();
    return (tc, tr);
  }

  // Picks the floor tile closest to the requested corner (Manhattan), so
  // the player spawns tucked into that corner of the playable area.
  Offset _cornerSpawn(int corner) {
    final b = _floorBounds();
    if (b == null) return _map.roomCenter(0);
    final cell = _map.cell;
    final (tc, tr) = _cornerCell(corner, b);
    Point<int>? best;
    int bestDist = 1 << 30;
    for (int r = b.top.toInt(); r <= b.bottom.toInt(); r++) {
      for (int c = b.left.toInt(); c <= b.right.toInt(); c++) {
        if (_map.tt(c, r) != 1) continue;
        final d = (c - tc).abs() + (r - tr).abs();
        if (d < bestDist) {
          bestDist = d;
          best = Point(c, r);
        }
      }
    }
    if (best == null) return _map.roomCenter(0);
    return Offset((best.x + 0.5) * cell, (best.y + 0.5) * cell);
  }

  // Picks up to `n` floor tiles near the corner, ranked by Manhattan
  // distance to it and spaced out by ~2.5 cells so the portals don't all
  // pile on top of each other.
  List<Offset> _cornerDoorSlots(int corner, int n) {
    final b = _floorBounds();
    if (b == null) return const [];
    final cell = _map.cell;
    final (tc, tr) = _cornerCell(corner, b);
    final candidates = <(int, int, int)>[]; // (distance, c, r)
    for (int r = b.top.toInt(); r <= b.bottom.toInt(); r++) {
      for (int c = b.left.toInt(); c <= b.right.toInt(); c++) {
        if (_map.tt(c, r) != 1) continue;
        final d = (c - tc).abs() + (r - tr).abs();
        candidates.add((d, c, r));
      }
    }
    candidates.sort((a, b) => a.$1.compareTo(b.$1));
    final picks = <Offset>[];
    final minSep = cell * 2.5;
    for (final (_, c, r) in candidates) {
      final pos = Offset((c + 0.5) * cell, (r + 0.5) * cell);
      var ok = true;
      for (final p in picks) {
        if ((p - pos).distance < minSep) {
          ok = false;
          break;
        }
      }
      if (ok) {
        picks.add(pos);
        if (picks.length >= n) break;
      }
    }
    return picks;
  }

  Rect? _floorBounds() {
    int minC = _map.cols, maxC = -1, minR = _map.rows, maxR = -1;
    for (int r = 0; r < _map.rows; r++) {
      for (int c = 0; c < _map.cols; c++) {
        if (_map.tt(c, r) == 1) {
          if (c < minC) minC = c;
          if (c > maxC) maxC = c;
          if (r < minR) minR = r;
          if (r > maxR) maxR = r;
        }
      }
    }
    if (maxC < 0) return null;
    return Rect.fromLTRB(
        minC.toDouble(), minR.toDouble(), maxC.toDouble(), maxR.toDouble());
  }

  List<List<dynamic>> _shrineOffers = const [];
  void _openShrine() {
    final all = <List<dynamic>>[
      ['+30% damage', '−20% max HP', (Player p) {
        p.damage *= 1.30;
        p.maxHp = (p.maxHp * 0.8).clamp(1, 9999).toDouble();
        p.hp = p.hp.clamp(1, p.maxHp).toDouble();
      }],
      ['+30% fire rate', '−25 move speed', (Player p) {
        p.fireInterval *= 0.77;
        p.speed = (p.speed - 25).clamp(60, 9999).toDouble();
      }],
      ['+1 projectile', '+0.3s dash CD', (Player p) {
        p.projectiles = (p.projectiles + 1).clamp(1, 8).toInt();
        p.dashCd = (p.dashCd + 0.3).clamp(0.4, 5).toDouble();
      }],
      ['+15% crit chance', 'lose all obols', (Player p) {
        p.critChance = (p.critChance + 0.15).clamp(0.0, 1.0).toDouble();
        p.obols = 0;
      }],
      ['+1 Death Defiance', '−25% max MP', (Player p) {
        p.revives += 1;
        p.maxMp = (p.maxMp * 0.75).clamp(1, 9999).toDouble();
        p.mp = p.mp.clamp(0, p.maxMp).toDouble();
      }],
    ]..shuffle(_rng);
    _shrineOffers = all.take(2).toList();
    setState(() => _phase = Phase.shrine);
  }

  void _pickShrine(int i) {
    final offer = _shrineOffers[i];
    (offer[2] as void Function(Player))(_p);
    _texts.add(FloatText(_p.pos.translate(0, -32),
        'SHRINE: ${offer[0]}', const Color(0xFFE0A0FF)));
    _roomKind = RoomKind.normal;
    setState(() => _phase = Phase.playing);
  }

  void _gameOver() {
    _recordDailyScore();
    GameStats.recordRunEnd(_wave, _floorIdx + 1, _p.kills, _p.obols);
    _awardShards();
    Loadout.blessingNectarBonus = 0; // chef's buff is per-run
    NpcStore.bumpQuest('hypnos', 1);
    _phase = Phase.gameOver;
  }

  void _victory() {
    _recordDailyScore();
    GameStats.recordRunEnd(_wave, _floorIdx + 1, _p.kills, _p.obols);
    _awardShards();
    Loadout.blessingNectarBonus = 0;
    NpcStore.bumpQuest('hypnos', 1);
    _phase = Phase.victory;
  }

  // Score formula for daily challenges: rewards both depth and clearing.
  void _recordDailyScore() {
    final key = Loadout.dailyKey;
    if (key == null) return;
    final score = _p.kills + _wave * 25 + _floorIdx * 100;
    final prev = GameStats.dailyBest[key] ?? 0;
    if (score > prev) GameStats.dailyBest[key] = score;
    GameStats.save();
  }

  int _lastGain = 0;
  void _awardShards() {
    _lastGain =
        ((_wave * 2 + _p.kills ~/ 8 + _floorIdx * 4) * Loadout.rewardMul)
            .round();
    MetaStore.shards += _lastGain;
    MetaStore.save();
  }

  List<ShopItem> _rollShop() {
    final mul = 1 + _floorIdx * 0.6;
    int price(num b) => (b * mul).round();
    final all = <ShopItem>[
      ShopItem('HEALTH POTION', 'heal 50% max HP', price(8), (p) {
        p.hp = (p.hp + p.maxHp * 0.5).clamp(0, p.maxHp).toDouble();
      }),
      ShopItem('FULL HEAL', 'restore all HP', price(16),
          (p) => p.hp = p.maxHp),
      ShopItem('MANA POTION', 'restore all MP', price(7),
          (p) => p.mp = p.maxMp),
      ShopItem('+2 MAX HP', 'and heal that much', price(12), (p) {
        p.maxHp += 2;
        p.hp += 2;
      }),
      ShopItem('+3 MAX MP', 'bigger mana pool', price(12), (p) {
        p.maxMp += 3;
        p.mp += 3;
      }),
      ShopItem('+1 DAMAGE', 'hit harder', price(15), (p) => p.damage += 1),
      ShopItem('+15 SPEED', 'move faster', price(12), (p) => p.speed += 15),
      ShopItem('+15% ATK SPEED', 'shoot faster', price(16),
          (p) => p.fireInterval = p.fireInterval * 0.85),
      ShopItem('+6% CRIT', 'more big hits', price(14),
          (p) => p.critChance += 0.06),
      ShopItem('+0.6 MP REGEN', 'cast more often', price(17),
          (p) => p.mpRegen += 0.6),
      ShopItem('+0.3 LIFESTEAL', 'heal on kill', price(18),
          (p) => p.lifesteal += 0.3),
    ]..shuffle(_rng);
    final gun = kWeapons[_rng.nextInt(kWeapons.length)];
    return [
      ShopItem('WEAPON: ${gun.name}', gun.desc, price(22),
          (p) => p.weapon = gun),
      ...all.take(5),
    ];
  }

  void _buy(ShopItem it) {
    if (it.sold || _p.obols < it.price) return;
    _p.obols -= it.price;
    it.apply(_p);
    setState(() => it.sold = true);
  }

  void _pause() {
    if (_phase == Phase.playing || _phase == Phase.roomCleared) {
      setState(() => _phase = Phase.paused);
    }
  }

  void _resume() => setState(() => _phase = Phase.playing);

  void _panStart(DragStartDetails d) {
    if (_phase != Phase.playing && _phase != Phase.roomCleared) return;
    if (_abilityRect.contains(d.localPosition)) return;
    if (_dashRect.contains(d.localPosition)) return;
    if (_pauseRect.contains(d.localPosition)) return;
    _stickOn = true;
    _stickOrigin = d.localPosition;
    _stickKnob = d.localPosition;
  }

  void _panUpdate(DragUpdateDetails d) {
    if (!_stickOn) return;
    var delta = d.localPosition - _stickOrigin;
    if (delta.distance > _stickR) {
      delta = delta / delta.distance * _stickR;
    }
    _stickKnob = _stickOrigin + delta;
    final screen = delta / _stickR; // intended on-screen direction
    final world = isoUnproject(screen);
    _moveDir = world == Offset.zero
        ? Offset.zero
        : world / world.distance * screen.distance;
  }

  void _panEnd(_) {
    _stickOn = false;
    _moveDir = Offset.zero;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: LayoutBuilder(
        builder: (context, c) {
          final s = Size(c.maxWidth, c.maxHeight);
          if (s != _size) {
            _size = s;
            if (!_ready) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) setState(_initRun);
              });
            }
          }
          final play =
              _phase == Phase.playing || _phase == Phase.roomCleared;
          return GestureDetector(
            onPanStart: _panStart,
            onPanUpdate: _panUpdate,
            onPanEnd: _panEnd,
            child: Stack(
              fit: StackFit.expand,
              children: [
                Positioned.fill(
                  child: RepaintBoundary(
                      child: CustomPaint(
                    isComplex: true,
                    willChange: true,
                    painter: WorldPainter(
                      player: _p,
                      enemies: _enemies,
                      bolts: _bolts,
                      ebolts: _ebolts,
                      grenades: _grenades,
                      nectar: _nectar,
                      captives: _captives,
                      orbs: _orbs,
                      hearts: _hearts,
                      bursts: _bursts,
                      texts: _texts,
                      doors: _doors,
                      swings: _swings,
                      ghosts: _ghosts,
                      traps: _traps,
                      ballistas: _ballistas,
                      map: _ready ? _map : null,
                      floor: _floor,
                      time: _elapsed,
                      facing: _facing,
                      moving: _moveDir != Offset.zero,
                      shake: Settings.shake ? _shake : 0.0,
                      lowHp: _ready && _p.hp / _p.maxHp < 0.3,
                      stickOn: _stickOn,
                      stickOrigin: _stickOrigin,
                      stickKnob: _stickKnob,
                      ready: _ready,
                      aimAt: _aimAt,
                    ),
                  )),
                ),
                if (_ready) _hud(),
                if (_ready && _combo > 1) _comboBadge(),
                if (_ready && _runBoons.isNotEmpty) _runBoonsStrip(),
                if (_ready) _bossBar(),
                if (_ready && _bossIntroT > 0 && _bossIntro != null)
                  _bossIntroOverlay(),
                if (_ready &&
                    _floorIntroT > 0 &&
                    _floorIntro != null &&
                    _bossIntroT <= 0)
                  _floorIntroOverlay(),
                if (_ready && _phase == Phase.playing) _abilityButton(),
                if (_ready && play) _dashButton(),
                if (_ready && play) _pauseButton(),
                if (_phase == Phase.paused) _pauseOverlay(),
                if (_phase == Phase.levelUp) _levelUpOverlay(),
                if (_toasts.isNotEmpty) _toastStack(),
                if (_phase == Phase.shop) _shopOverlay(),
                if (_phase == Phase.shrine) _shrineOverlay(),
                if (_ready && _showTutorial) _tutorialOverlay(),
                if (_phase == Phase.gameOver) _endOverlay(false),
                if (_phase == Phase.victory) _endOverlay(true),
              ],
            ),
          );
        },
      ),
    );
  }


  Widget _dashButton() {
    final ready = _p.dashTimer <= 0;
    return Positioned(
      left: _dashRect.left,
      top: _dashRect.top,
      width: _dashRect.width,
      height: _dashRect.height,
      child: GestureDetector(
        onTap: _dash,
        child: Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color:
                ready ? const Color(0xFF2E7D5B) : const Color(0xFF24242F),
            border: Border.all(
                color: ready ? const Color(0xFF8CFFC0) : Colors.white24,
                width: 2),
          ),
          alignment: Alignment.center,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.bolt, color: Colors.white, size: 22),
              Text(
                ready ? 'DASH' : '${_p.dashTimer.toStringAsFixed(1)}s',
                style: const TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                    color: Colors.white70),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _abilityButton() {
    final ready = _canCast;
    final cd = _p.abilityTimer;
    return Positioned(
      left: _abilityRect.left,
      top: _abilityRect.top,
      width: _abilityRect.width,
      height: _abilityRect.height,
      child: GestureDetector(
        onTap: _castAbility,
        child: Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color:
                ready ? const Color(0xFF2A5BD7) : const Color(0xFF24242F),
            border: Border.all(
                color: ready ? const Color(0xFF8CC8FF) : Colors.white24,
                width: 2),
          ),
          alignment: Alignment.center,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('✦',
                  style: TextStyle(fontSize: 22, color: Colors.white)),
              Text(
                cd > 0
                    ? '${cd.toStringAsFixed(1)}s'
                    : '${widget.def.abilityCost.toInt()} MP',
                style: const TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                    color: Colors.white70),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _pauseButton() {
    return Positioned(
      left: _pauseRect.left,
      top: _pauseRect.top,
      width: _pauseRect.width,
      height: _pauseRect.height,
      child: GestureDetector(
        onTap: _pause,
        child: Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: const Color(0xCC24242F),
            border: Border.all(color: Colors.white24, width: 2),
          ),
          alignment: Alignment.center,
          child: const Icon(Icons.pause, color: Colors.white, size: 22),
        ),
      ),
    );
  }

  Widget _pauseOverlay() {
    return _scrim(Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text('PAUSED',
            style: TextStyle(
                fontSize: 34,
                fontWeight: FontWeight.w900,
                color: Color(0xFFFFD45E))),
        const SizedBox(height: 6),
        Text('F${_floorIdx + 1} ${_floor.name} · room $_wave · lv ${_p.level}',
            style: const TextStyle(color: Colors.white60)),
        const SizedBox(height: 24),
        _BigButton(
            label: 'RESUME', color: const Color(0xFFFFD45E), onTap: _resume),
        const SizedBox(height: 12),
        _BigButton(
            label: 'SETTINGS',
            color: const Color(0xFF8CC8FF),
            onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(
                builder: (_) => const SettingsScreen()))),
        const SizedBox(height: 12),
        _BigButton(
            label: 'RESTART',
            color: const Color(0xFF8CC8FF),
            onTap: () => setState(_initRun)),
        const SizedBox(height: 12),
        _BigButton(
          label: 'BACK HOME',
          color: const Color(0xFF8CC8FF),
          onTap: () => Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute<void>(builder: (_) => const HomeRoomScreen()),
            (r) => false,
          ),
        ),
      ],
    ));
  }

  // Slides in for ~2.4s when the player enters a new floor's first room.
  Widget _floorIntroOverlay() {
    final t = _floorIntroT;
    final entry = (2.4 - t).clamp(0.0, 0.45) / 0.45;
    final fade = t < 0.8 ? (t / 0.8).clamp(0.0, 1.0) : 1.0;
    final xOffset = (1 - entry) * -36.0;
    return Positioned(
      top: 110,
      left: 0,
      right: 0,
      child: IgnorePointer(
        ignoring: true,
        child: Transform.translate(
          offset: Offset(xOffset, 0),
          child: Opacity(
            opacity: fade,
            child: Column(children: [
              const Text('— ENTERING FLOOR —',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      color: Color(0xFF8CC8FF),
                      fontWeight: FontWeight.w900,
                      fontSize: 12,
                      letterSpacing: 5)),
              const SizedBox(height: 4),
              Text(_floorIntro!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      color: Color(0xFFFFD45E),
                      fontWeight: FontWeight.w900,
                      fontSize: 22,
                      letterSpacing: 1.5)),
            ]),
          ),
        ),
      ),
    );
  }

  // Slides in for ~2.4s when a boss spawns, fading the last second.
  Widget _bossIntroOverlay() {
    final t = _bossIntroT;
    final entry = (2.4 - t).clamp(0.0, 0.4) / 0.4; // ease-in over first 0.4s
    final fade = t < 0.8 ? (t / 0.8).clamp(0.0, 1.0) : 1.0;
    final yOffset = (1 - entry) * -40.0;
    return Positioned(
      top: 110,
      left: 0,
      right: 0,
      child: IgnorePointer(
        ignoring: true,
        child: Transform.translate(
          offset: Offset(0, yOffset),
          child: Opacity(
            opacity: fade,
            child: Column(children: [
              const Text('— BOSS —',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      color: Color(0xFFFF3B5C),
                      fontWeight: FontWeight.w900,
                      fontSize: 13,
                      letterSpacing: 6)),
              const SizedBox(height: 4),
              Text(_bossIntro!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      color: Color(0xFFFFD45E),
                      fontWeight: FontWeight.w900,
                      fontSize: 22,
                      letterSpacing: 1)),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _bossBar() {
    Enemy? boss;
    for (final e in _enemies) {
      if (e.kind == 3) {
        boss = e;
        break;
      }
    }
    if (boss == null) return const SizedBox.shrink();
    final frac = (boss.hp / boss.maxHp).clamp(0.0, 1.0).toDouble();
    return Positioned(
      top: 160,
      left: 30,
      right: 30,
      child: Column(
        children: [
          Text('☠ ${kBossNames[_floorIdx]} ☠',
              textAlign: TextAlign.center,
              style: const TextStyle(
                  color: Color(0xFFFF3B5C),
                  fontWeight: FontWeight.w900,
                  fontSize: 13)),
          const SizedBox(height: 3),
          Container(
            height: 12,
            decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFFF3B5C))),
            child: FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: frac,
              child: Container(
                decoration: BoxDecoration(
                    color: const Color(0xFFFF3B5C),
                    borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _hud() {
    const lblColor = Color(0xFFFFD45E);
    return Positioned(
      top: 0,
      left: 0,
      // Leave the top-right corner for the minimap.
      right: 116,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(10, 6, 10, 0),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Flexible(
                    child: Text('F${_floorIdx + 1} ${_floor.name}',
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 10,
                            color: lblColor)),
                  ),
                  Text('R$_wave/$kMaxWaves',
                      style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 10,
                          color: Colors.white70)),
                  Text(
                      _phase == Phase.roomCleared
                          ? 'CLEAR'
                          : '👾$_enemiesLeft',
                      style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 10,
                          color: Colors.white)),
                  Text('💰${_p.obols}',
                      style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 10,
                          color: lblColor)),
                  Text('LV${_p.level}',
                      style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 10,
                          color: Color(0xFF8CC8FF))),
                ],
              ),
              const SizedBox(height: 3),
              _bar(_p.hp / _p.maxHp, const Color(0xFFFF5C6C),
                  'HP ${_p.hp.ceil()}/${_p.maxHp.toInt()}', h: 11),
              const SizedBox(height: 2),
              _bar(_p.mp / _p.maxMp, const Color(0xFF3F8BFF),
                  'MP ${_p.mp.floor()}/${_p.maxMp.toInt()}', h: 7),
              const SizedBox(height: 2),
              _bar(_p.xp / _p.xpToNext, const Color(0xFF8CFF98), null, h: 4),
              const SizedBox(height: 2),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                    '🔫 ${_p.weapon.name}    '
                    '${'💀' * _p.revives.clamp(0, 6).toInt()}',
                    style: const TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w900,
                        color: lblColor)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Small chip strip on the bottom-left: shows acquired-boon count plus
  // the short codes of the latest picks so the player can see their build
  // shaping up without opening a menu.
  Widget _runBoonsStrip() {
    final tail = _runBoons.length <= 4
        ? _runBoons
        : _runBoons.sublist(_runBoons.length - 4);
    return Positioned(
      left: 10,
      bottom: 16,
      child: IgnorePointer(
        ignoring: true,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          decoration: BoxDecoration(
            color: const Color(0xCC14131F),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
                color: const Color(0xFF8CFF98).withValues(alpha: 0.5),
                width: 1),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Text('✦ ${_runBoons.length}',
                style: const TextStyle(
                    color: Color(0xFF8CFF98),
                    fontWeight: FontWeight.w900,
                    fontSize: 11)),
            const SizedBox(width: 6),
            for (final b in tail)
              Padding(
                padding: const EdgeInsets.only(left: 3),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 5, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1F1D2E),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                      // Show only the first word so the strip stays tight.
                      b.split(' ').first,
                      style: const TextStyle(
                          color: Colors.white70,
                          fontWeight: FontWeight.w900,
                          fontSize: 9,
                          letterSpacing: 0.5)),
                ),
              ),
          ]),
        ),
      ),
    );
  }

  Widget _comboBadge() {
    final tier = _combo >= 25 ? 2 : (_combo >= 10 ? 1 : 0);
    final color = tier == 2
        ? const Color(0xFFFF9A3C)
        : (tier == 1 ? const Color(0xFFFFD45E) : Colors.white70);
    return Positioned(
      left: 12,
      top: 78,
      child: Row(children: [
        Text('x$_combo',
            style: TextStyle(
                color: color,
                fontWeight: FontWeight.w900,
                fontSize: tier == 2 ? 22 : (tier == 1 ? 18 : 14))),
        const SizedBox(width: 6),
        if (tier > 0)
          Text(tier == 2 ? 'INFERNO' : 'STREAK',
              style: TextStyle(
                  color: color.withValues(alpha: 0.85),
                  fontWeight: FontWeight.w900,
                  fontSize: 10)),
      ]),
    );
  }

  Widget _bar(double v, Color color, String? label, {double h = 11}) {
    return Stack(
      alignment: Alignment.center,
      children: [
        Container(
          height: h,
          decoration: BoxDecoration(
              color: Colors.black38,
              borderRadius: BorderRadius.circular(6)),
          child: FractionallySizedBox(
            alignment: Alignment.centerLeft,
            widthFactor: v.clamp(0.0, 1.0).toDouble(),
            child: Container(
              decoration: BoxDecoration(
                  color: color, borderRadius: BorderRadius.circular(6)),
            ),
          ),
        ),
        if (label != null)
          Text(label,
              style: const TextStyle(
                  fontSize: 8,
                  fontWeight: FontWeight.bold,
                  color: Colors.white)),
      ],
    );
  }

  Widget _scrim(Widget child) {
    return Positioned.fill(
      child: Container(
        color: Colors.black.withValues(alpha: 0.78),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: child,
          ),
        ),
      ),
    );
  }

  // Right-side stack of achievement / event toasts that fade out near 0s.
  Widget _toastStack() {
    return Positioned(
      right: 16,
      top: 64,
      child: IgnorePointer(
        ignoring: true,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            for (final t in _toasts)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Opacity(
                  opacity: t.t < 1.0 ? t.t.clamp(0.0, 1.0).toDouble() : 1.0,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xCC1F1D2E),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: t.color, width: 1.5),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(t.title,
                            style: TextStyle(
                                color: t.color,
                                fontWeight: FontWeight.w900,
                                fontSize: 13)),
                        Text(t.subtitle,
                            style: const TextStyle(
                                color: Colors.white70, fontSize: 11)),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _tutorialOverlay() {
    return _scrim(Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text('HOW TO PLAY',
            style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w900,
                color: Color(0xFFFFD45E))),
        const SizedBox(height: 14),
        const Text('• drag anywhere to move (virtual stick)',
            style: TextStyle(color: Colors.white, fontSize: 14)),
        const SizedBox(height: 6),
        const Text('• you auto-aim at the nearest enemy',
            style: TextStyle(color: Colors.white, fontSize: 14)),
        const SizedBox(height: 6),
        const Text('• tap ⚡ to dash through danger (i-frames)',
            style: TextStyle(color: Colors.white, fontSize: 14)),
        const SizedBox(height: 6),
        const Text('• tap ✦ for your hero ability',
            style: TextStyle(color: Colors.white, fontSize: 14)),
        const SizedBox(height: 6),
        const Text('• clear the room, then walk into a door',
            style: TextStyle(color: Colors.white, fontSize: 14)),
        const SizedBox(height: 6),
        const Text('• chain kills for STREAK and INFERNO buffs',
            style: TextStyle(color: Color(0xFFFFD45E), fontSize: 14)),
        const SizedBox(height: 22),
        _BigButton(
          label: "LET'S GO",
          color: const Color(0xFFFFD45E),
          onTap: () {
            Settings.tutorialDone = true;
            Settings.save();
            setState(() => _showTutorial = false);
          },
        ),
      ],
    ));
  }

  Widget _shrineOverlay() {
    return _scrim(Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text('⛩ SHRINE',
            style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w900,
                color: Color(0xFFE0A0FF))),
        const SizedBox(height: 4),
        const Text('each blessing has a price',
            style: TextStyle(color: Colors.white60)),
        const SizedBox(height: 18),
        for (var i = 0; i < _shrineOffers.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => _pickShrine(i),
              child: Container(
                width: 320,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xCC1F1D2E),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: const Color(0xFFE0A0FF), width: 1.5),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('+ ${_shrineOffers[i][0]}',
                        style: const TextStyle(
                            color: Color(0xFF8CFF98),
                            fontWeight: FontWeight.w900,
                            fontSize: 14)),
                    const SizedBox(height: 2),
                    Text('− ${_shrineOffers[i][1]}',
                        style: const TextStyle(
                            color: Color(0xFFFF5C6C), fontSize: 12)),
                  ],
                ),
              ),
            ),
          ),
      ],
    ));
  }

  Widget _levelUpOverlay() {
    return _scrim(Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text('LEVEL UP!',
            style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.w900,
                color: Color(0xFF8CFF98))),
        const SizedBox(height: 4),
        const Text('pick a boon', style: TextStyle(color: Colors.white60)),
        const SizedBox(height: 18),
        for (final u in _choices)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _UpgradeCard(u: u, onTap: () => _pickUpgrade(u)),
          ),
      ],
    ));
  }

  Widget _shopOverlay() {
    return _scrim(Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text("CHARON'S SHOP",
            style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w900,
                color: Color(0xFFFFD45E))),
        const SizedBox(height: 2),
        Text('💰 ${_p.obols}',
            style: const TextStyle(color: Colors.white60)),
        const SizedBox(height: 16),
        for (final it in _shop)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Opacity(
              opacity: it.sold ? 0.35 : 1,
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () => _buy(it),
                child: Container(
                  width: 330,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1F1D2E),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: _p.obols >= it.price && !it.sold
                            ? const Color(0xFFFFD45E)
                            : Colors.white24),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(it.sold ? '${it.title} (SOLD)' : it.title,
                                style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w900,
                                    color: Colors.white)),
                            Text(it.desc,
                                style: const TextStyle(
                                    color: Colors.white54, fontSize: 11)),
                          ],
                        ),
                      ),
                      Text('💰${it.price}',
                          style: const TextStyle(
                              fontWeight: FontWeight.w900,
                              color: Color(0xFFFFD45E))),
                    ],
                  ),
                ),
              ),
            ),
          ),
        const SizedBox(height: 6),
        _BigButton(
            label: 'LEAVE SHOP',
            color: const Color(0xFF8CC8FF),
            onTap: _nextRoom),
      ],
    ));
  }

  Widget _endOverlay(bool win) {
    final mins = (_runTime / 60).floor();
    final secs = (_runTime % 60).floor();
    final nectarGained = NpcStore.nectar - _runStartNectar;
    final beatBest = _wave > GameStats.bestWave ||
        (_floorIdx + 1) > GameStats.bestFloor;
    final boonsByTitle = <String, int>{};
    for (final t in _runBoons) {
      boonsByTitle[t] = (boonsByTitle[t] ?? 0) + 1;
    }
    return _scrim(Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(win ? 'YOU CLEARED THE VOID!' : 'GET REKT',
            textAlign: TextAlign.center,
            style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.w900,
                color: win
                    ? const Color(0xFF8CFF98)
                    : const Color(0xFFFF5C6C))),
        if (beatBest)
          const Padding(
            padding: EdgeInsets.only(top: 4),
            child: Text('NEW BEST!',
                style: TextStyle(
                    color: Color(0xFFFFD45E),
                    fontWeight: FontWeight.w900,
                    letterSpacing: 3,
                    fontSize: 12)),
          ),
        const SizedBox(height: 14),
        Container(
          width: 320,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xCC1F1D2E),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFFFD45E)),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _recapRow('FLOOR', '${_floorIdx + 1} · ${_floor.name}',
                const Color(0xFFFFD45E)),
            _recapRow('ROOM', '$_wave / $kMaxWaves', Colors.white),
            _recapRow('LEVEL', '${_p.level}', Colors.white),
            _recapRow('KILLS', '${_p.kills}', Colors.white),
            _recapRow('MAX COMBO', 'x$_runMaxCombo',
                const Color(0xFFFF9A3C)),
            _recapRow('TIME ALIVE',
                '${mins}m ${secs.toString().padLeft(2, '0')}s',
                Colors.white70),
            _recapRow('WEAPON', _p.weapon.name, const Color(0xFFFFB347)),
            const Divider(color: Colors.white24, height: 18),
            _recapRow('🔷 SHARDS', '+$_lastGain',
                const Color(0xFF8CC8FF)),
            if (nectarGained > 0)
              _recapRow('🍯 NECTAR', '+$nectarGained',
                  const Color(0xFFFFD45E)),
            _recapRow('💰 OBOLS', '${_p.obols}',
                const Color(0xFFFFD45E)),
            if (boonsByTitle.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text('BOONS PICKED (${_runBoons.length})',
                  style: const TextStyle(
                      color: Color(0xFF8CFF98),
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.5,
                      fontSize: 10)),
              const SizedBox(height: 4),
              Wrap(
                spacing: 4,
                runSpacing: 4,
                children: [
                  for (final entry in boonsByTitle.entries)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 7, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFF14131F),
                        borderRadius: BorderRadius.circular(5),
                        border: Border.all(
                            color: const Color(0xFF8CFF98), width: 0.8),
                      ),
                      child: Text(
                          entry.value > 1
                              ? '${entry.key} x${entry.value}'
                              : entry.key,
                          style: const TextStyle(
                              color: Color(0xFF8CFF98), fontSize: 10)),
                    ),
                ],
              ),
            ],
          ]),
        ),
        const SizedBox(height: 14),
        Text(
            'lifetime: ${GameStats.totalRuns} runs · ${GameStats.totalKills} kills',
            style: const TextStyle(color: Colors.white38, fontSize: 11)),
        const SizedBox(height: 14),
        _BigButton(
            label: 'PLAY AGAIN',
            color: const Color(0xFFFFD45E),
            onTap: () => setState(_initRun)),
        const SizedBox(height: 10),
        _BigButton(
          label: 'BACK HOME',
          color: const Color(0xFF8CC8FF),
          onTap: () => Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute<void>(builder: (_) => const HomeRoomScreen()),
            (r) => false,
          ),
        ),
      ],
    ));
  }

  Widget _recapRow(String label, String value, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: const TextStyle(
                  color: Colors.white54,
                  fontSize: 10,
                  letterSpacing: 1.6)),
          Text(value,
              style: TextStyle(
                  color: color, fontWeight: FontWeight.w900, fontSize: 13)),
        ],
      ),
    );
  }
}

/// ---------------------------------------------------------------------------
/// Upgrades / shop
/// ---------------------------------------------------------------------------
class Upgrade {
  const Upgrade(this.title, this.desc, this.tier, this.apply);
  final String title;
  final String desc;
  final int tier;
  final void Function(Player p) apply;
}

const Color _cCommon = Color(0xFF8CFF98);
const Color _cRare = Color(0xFF8CC8FF);
const Color _cEpic = Color(0xFFE0A0FF);
Color _tierColor(int t) => t == 0 ? _cCommon : (t == 1 ? _cRare : _cEpic);

final List<Upgrade> kUpgrades = [
  Upgrade('MUCH DAMAGE', '+1 damage', 0, (p) => p.damage += 1),
  Upgrade('VERY SPEED', '+18 move speed', 0, (p) => p.speed += 18),
  Upgrade('SO TANKY', '+3 max HP & heal', 0, (p) {
    p.maxHp += 3;
    p.hp = (p.hp + 3).clamp(0, p.maxHp).toDouble();
  }),
  Upgrade('REGEN', '+0.6 HP / sec', 0, (p) => p.regen += 0.6),
  Upgrade('LONG REACH', '+70 range', 0, (p) => p.range += 70),
  Upgrade('FAST BONK', '+90 projectile speed', 0, (p) => p.projSpeed += 90),
  Upgrade('BIG BRAIN', '+2 max MP', 0, (p) {
    p.maxMp += 2;
    p.mp += 2;
  }),
  Upgrade('WOW CRIT', '+9% crit chance', 1, (p) => p.critChance += 0.09),
  Upgrade('RAPID BONK', '+24% attack speed', 1,
      (p) => p.fireInterval = (p.fireInterval * 0.76).clamp(0.05, 5).toDouble()),
  Upgrade('VAMPIRE', '+0.4 HP per kill', 1, (p) => p.lifesteal += 0.4),
  Upgrade('PLAGUE', '+1.5 poison dps', 1, (p) => p.dot += 1.5),
  Upgrade('SPIKES', '+1 thorns damage', 1, (p) => p.thorns += 1),
  Upgrade('FOCUS', '+0.7 MP regen', 1, (p) => p.mpRegen += 0.7),
  Upgrade('DOUBLE SHOT', 'fire a 2nd volley', 1,
      (p) => p.volleys = (p.volleys + 1).clamp(1, 4).toInt()),
  Upgrade('MULTI BONK', '+1 projectile', 2,
      (p) => p.projectiles = (p.projectiles + 1).clamp(1, 8).toInt()),
  Upgrade('BIG BOOM', '+24 splash radius', 2, (p) => p.splash += 24),
  Upgrade('PIERCING', '+2 pierce', 2,
      (p) => p.pierce = (p.pierce + 2).clamp(0, 12).toInt()),
  Upgrade('EAGLE EYE', 'see way more of the room', 2,
      (p) => p.vision = (p.vision + 0.35).clamp(1.0, 2.8).toDouble()),
  // god boons
  Upgrade('POSEIDON: WAVE', 'hits knock enemies back', 1,
      (p) => p.knockback += 26),
  Upgrade('ATHENA: SWIFT', '-0.35s dash cooldown', 1,
      (p) => p.dashCd = (p.dashCd - 0.35).clamp(0.4, 5).toDouble()),
  Upgrade('ARES: DOOM', 'hits plant a delayed burst', 2,
      (p) => p.doomAmt += 7),
  Upgrade('ZEUS: CHAIN', 'attacks chain to +1 enemy', 2,
      (p) => p.zeus += 1),
  // New boons
  Upgrade('IRON GUT', '+5 max HP & full heal', 0, (p) {
    p.maxHp += 5;
    p.hp = p.maxHp;
  }),
  Upgrade('MANA TIDE', '+1.0 MP regen', 1, (p) => p.mpRegen += 1.0),
  Upgrade('GLASS CANNON', '+50% damage, −25% max HP', 2, (p) {
    p.damage *= 1.5;
    p.maxHp = (p.maxHp * 0.75).clamp(1, 9999).toDouble();
    p.hp = p.hp.clamp(1, p.maxHp).toDouble();
  }),
  Upgrade('SECOND WIND', '+1 Death Defiance', 2, (p) => p.revives += 1),
  Upgrade('FROST WALKER', 'immune to chill', 1,
      (p) => p.frostImmune = true),
  Upgrade('HERMES: HASTE', '+30 move speed & −0.2s dash CD', 2, (p) {
    p.speed += 30;
    p.dashCd = (p.dashCd - 0.2).clamp(0.4, 5).toDouble();
  }),
];

class ShopItem {
  ShopItem(this.title, this.desc, this.price, this.apply);
  final String title;
  final String desc;
  final int price;
  final void Function(Player p) apply;
  bool sold = false;
}

class _UpgradeCard extends StatelessWidget {
  const _UpgradeCard({required this.u, required this.onTap});
  final Upgrade u;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = _tierColor(u.tier);
    final tn = u.tier == 0 ? 'COMMON' : (u.tier == 1 ? 'RARE' : 'EPIC');
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Container(
        width: 320,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        decoration: BoxDecoration(
          color: const Color(0xFF1F1D2E),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: c, width: 1.8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(u.title,
                    style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: c)),
                const Spacer(),
                Text(tn,
                    style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        color: c)),
              ],
            ),
            const SizedBox(height: 2),
            Text(u.desc,
                style: const TextStyle(color: Colors.white60, fontSize: 13)),
          ],
        ),
      ),
    );
  }
}

class _BigButton extends StatelessWidget {
  const _BigButton(
      {required this.label, required this.color, required this.onTap});
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
        decoration: BoxDecoration(
            color: color, borderRadius: BorderRadius.circular(14)),
        child: Text(label,
            style: const TextStyle(
                color: Color(0xFF14131F),
                fontWeight: FontWeight.w900,
                fontSize: 17,
                letterSpacing: 1)),
      ),
    );
  }
}

/// ---------------------------------------------------------------------------
/// Rendering
/// ---------------------------------------------------------------------------
Color _lit(Color c, double a) => Color.lerp(c, Colors.white, a)!;
Color _shd(Color c, double a) => Color.lerp(c, Colors.black, a)!;

// Isometric (Hades-style 3/4) projection. Gameplay stays in world space;
// only rendering and the joystick input are projected through this basis.
const double kIsoSX = 0.70;
const double kIsoSY = 0.35;
const double kWallH = 30.0; // extruded wall height in screen units
Offset isoProject(Offset w) =>
    Offset((w.dx - w.dy) * kIsoSX, (w.dx + w.dy) * kIsoSY);
Offset isoUnproject(Offset s) => Offset(
    (s.dx / kIsoSX + s.dy / kIsoSY) / 2,
    (s.dy / kIsoSY - s.dx / kIsoSX) / 2);

void _drawHero(Canvas canvas, Offset base, double r, HeroDef def, int stage,
    {double t = 0, bool moving = false, Offset look = Offset.zero}) {
  canvas.drawOval(
    Rect.fromCenter(
        center: base.translate(0, r * 1.0),
        width: r * 1.9,
        height: r * 0.55),
    Paint()..color = const Color(0x44000000),
  );

  final fp = Paint()..color = _shd(def.body, 0.5);
  final s1 = moving ? sin(t * 13) : 0.0;
  final lift1 = (s1 > 0 ? s1 : 0.0) * r * 0.22;
  final lift2 = (s1 < 0 ? -s1 : 0.0) * r * 0.22;
  canvas.drawOval(
      Rect.fromCenter(
          center: base.translate(-r * 0.42, r * 0.86 - lift1),
          width: r * 0.6,
          height: r * 0.36),
      fp);
  canvas.drawOval(
      Rect.fromCenter(
          center: base.translate(r * 0.42, r * 0.86 - lift2),
          width: r * 0.6,
          height: r * 0.36),
      fp);

  final bob = sin(t * (moving ? 9 : 2.4)) * r * (moving ? 0.10 : 0.05);
  final c = base.translate(0, -bob.abs() * 0.6);

  final accent = Paint()..color = def.accent;
  final outline = Paint()
    ..color = _shd(def.body, 0.5)
    ..style = PaintingStyle.stroke
    ..strokeWidth = (r * 0.10).clamp(1.4, 4.0).toDouble();

  Paint bodyShader(Offset center, double rad) => Paint()
    ..shader = RadialGradient(
      center: const Alignment(-0.4, -0.5),
      radius: 1.05,
      colors: [_lit(def.body, 0.4), def.body, _shd(def.body, 0.32)],
      stops: const [0.0, 0.55, 1.0],
    ).createShader(Rect.fromCircle(center: center, radius: rad));

  if (stage > 0) {
    final mr = r * (0.55 + stage * 0.12);
    for (final s in [-1.0, 1.0]) {
      final mc = c.translate(s * r * 0.95, r * 0.18);
      canvas.drawCircle(mc, mr, bodyShader(mc, mr));
      canvas.drawCircle(mc, mr, outline);
    }
  }

  canvas.drawCircle(c, r, bodyShader(c, r));
  canvas.drawCircle(c, r, outline);

  switch (def.cls) {
    case HeroClass.tank:
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
              center: c.translate(0, -r * 1.05),
              width: r * 1.7,
              height: r * 0.5),
          Radius.circular(r * 0.2),
        ),
        accent,
      );
      canvas.drawCircle(c.translate(r * 1.05, 0), r * 0.55, accent);
      break;
    case HeroClass.archer:
      final bow = Path()
        ..moveTo(c.dx + r * 1.0, c.dy - r * 0.9)
        ..quadraticBezierTo(
            c.dx + r * 1.7, c.dy, c.dx + r * 1.0, c.dy + r * 0.9);
      canvas.drawPath(
          bow,
          Paint()
            ..color = def.accent
            ..style = PaintingStyle.stroke
            ..strokeWidth = r * 0.18
            ..strokeCap = StrokeCap.round);
      _ears(canvas, c, r, accent);
      break;
    case HeroClass.mage:
      final hat = Path()
        ..moveTo(c.dx - r * 0.85, c.dy - r * 0.7)
        ..lineTo(c.dx + r * 0.12, c.dy - r * 2.05)
        ..lineTo(c.dx + r * 0.85, c.dy - r * 0.7)
        ..close();
      canvas.drawPath(hat, accent);
      final glow = 0.5 + 0.5 * sin(t * 4);
      canvas.drawCircle(c.translate(r * 0.12, -r * 2.05), r * 0.16,
          Paint()..color = const Color(0xFFFFE066));
      canvas.drawCircle(
          c.translate(r * 0.12, -r * 2.05),
          r * 0.28,
          Paint()
            ..color =
                const Color(0xFFFFE066).withValues(alpha: 0.35 * glow));
      break;
    case HeroClass.warlock:
      for (final s in [-1.0, 1.0]) {
        final horn = Path()
          ..moveTo(c.dx + s * r * 0.6, c.dy - r * 0.8)
          ..lineTo(c.dx + s * r * 1.0, c.dy - r * 1.85)
          ..lineTo(c.dx + s * r * 0.2, c.dy - r * 1.0)
          ..close();
        canvas.drawPath(horn, accent);
      }
      break;
    case HeroClass.assassin:
      canvas.drawRect(
        Rect.fromCenter(
            center: c.translate(0, -r * 0.18),
            width: r * 2.0,
            height: r * 0.42),
        accent,
      );
      _ears(canvas, c, r, Paint()..color = def.body);
      break;
    case HeroClass.gunner:
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
              center: c.translate(0, -r * 0.95),
              width: r * 1.8,
              height: r * 0.55),
          Radius.circular(r * 0.15),
        ),
        accent,
      );
      _ears(canvas, c, r, accent);
      break;
  }

  final lx = look.dx.clamp(-1.0, 1.0).toDouble() * r * 0.09;
  final ly = look.dy.clamp(-1.0, 1.0).toDouble() * r * 0.07;
  if (def.cls != HeroClass.assassin) {
    for (final s in [-1.0, 1.0]) {
      final ec = c.translate(s * r * 0.32, -r * 0.14);
      canvas.drawCircle(ec, r * 0.2, Paint()..color = Colors.white);
      canvas.drawCircle(ec.translate(lx, ly), r * 0.1,
          Paint()..color = Colors.black);
      canvas.drawCircle(ec.translate(-r * 0.05, -r * 0.05), r * 0.04,
          Paint()..color = Colors.white);
    }
  } else {
    final ep = Paint()..color = const Color(0xFFE0436B);
    for (final s in [-1.0, 1.0]) {
      canvas.drawCircle(c.translate(s * r * 0.32, -r * 0.16), r * 0.1, ep);
    }
  }
}

void _ears(Canvas canvas, Offset c, double r, Paint p) {
  canvas.drawCircle(c.translate(-r * 0.78, -r * 0.78), r * 0.34, p);
  canvas.drawCircle(c.translate(r * 0.78, -r * 0.78), r * 0.34, p);
}

void _drawProp(Canvas canvas, Offset c, double s, int kind, FloorDef f) {
  final dark = Paint()..color = _shd(f.prop, 0.45);
  switch (kind) {
    case 0: // tree
      canvas.drawRect(
          Rect.fromCenter(
              center: c.translate(0, s * 0.34),
              width: s * 0.16,
              height: s * 0.5),
          Paint()..color = _shd(f.prop, 0.3));
      canvas.drawCircle(c.translate(0, -s * 0.08), s * 0.34,
          Paint()..color = f.prop);
      canvas.drawCircle(c.translate(-s * 0.12, -s * 0.2), s * 0.2,
          Paint()..color = _lit(f.prop, 0.15));
      break;
    case 1: // rock
      canvas.drawCircle(c, s * 0.34, dark);
      canvas.drawCircle(c.translate(-s * 0.1, -s * 0.1), s * 0.16,
          Paint()..color = _lit(f.prop, 0.12));
      break;
    case 2: // pillar
      canvas.drawRRect(
          RRect.fromRectAndRadius(
              Rect.fromCenter(
                  center: c, width: s * 0.34, height: s * 0.78),
              const Radius.circular(4)),
          Paint()..color = f.prop);
      canvas.drawRect(
          Rect.fromCenter(
              center: c.translate(0, -s * 0.36),
              width: s * 0.46,
              height: s * 0.12),
          Paint()..color = _lit(f.prop, 0.1));
      break;
    case 3: // crystal
      final pth = Path()
        ..moveTo(c.dx, c.dy - s * 0.4)
        ..lineTo(c.dx + s * 0.22, c.dy)
        ..lineTo(c.dx, c.dy + s * 0.34)
        ..lineTo(c.dx - s * 0.22, c.dy)
        ..close();
      canvas.drawPath(pth, Paint()..color = _lit(f.mob, 0.1));
      break;
    default: // bush / debris
      canvas.drawCircle(c.translate(-s * 0.12, 0), s * 0.18,
          Paint()..color = f.prop);
      canvas.drawCircle(c.translate(s * 0.12, s * 0.04), s * 0.2,
          Paint()..color = _shd(f.prop, 0.18));
  }
}

class _NpcBlessing {
  const _NpcBlessing(
      {required this.label, required this.color, required this.onTap});
  final String label;
  final Color color;
  final VoidCallback? onTap;
}

class HomeNpc {
  HomeNpc({
    required this.id,
    required this.pos,
    required this.name,
    required this.icon,
    required this.color,
    required this.lines,
  });
  final String id;
  final Offset pos;
  final String name;
  final String icon;
  final Color color;
  final List<String> lines;
  int lineIdx = 0;
  bool wasNear = false; // tracks proximity edge so we rotate lines on re-entry
  double bob = 0; // idle animation phase
}

class HeroPreviewPainter extends CustomPainter {
  HeroPreviewPainter({required this.def});
  final HeroDef def;

  @override
  void paint(Canvas canvas, Size size) {
    _drawHero(
        canvas,
        size.center(Offset.zero).translate(0, size.height * 0.12),
        size.width * 0.26,
        def,
        2);
  }

  @override
  bool shouldRepaint(covariant HeroPreviewPainter old) => false;
}

/// Big Hades-style medallion: ornate gold rings, four diamond ornaments at
/// the cardinals, dramatic vignette behind the hero, and a red name banner
/// across the bottom. Used for character-select / keepsake screens.
class HeroMedallionPainter extends CustomPainter {
  HeroMedallionPainter({required this.def, this.label});
  final HeroDef def;
  final String? label;

  static const _gold = Color(0xFFFFD45E);
  static const _goldDark = Color(0xFFB58435);
  static const _ink = Color(0xFF0E0C16);
  static const _crimson = Color(0xFF7A1F2B);
  static const _crimsonDark = Color(0xFF3D1218);

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height * 0.45;
    final r = min(size.width, size.height * 0.7) * 0.36;

    // Vignette backdrop behind the medallion.
    canvas.drawCircle(
        Offset(cx, cy),
        r * 1.9,
        Paint()
          ..shader = RadialGradient(
            colors: [
              _ink,
              _ink.withValues(alpha: 0.0),
            ],
            stops: const [0.45, 1.0],
          ).createShader(
              Rect.fromCircle(center: Offset(cx, cy), radius: r * 1.9)));

    // Outer gold ring.
    canvas.drawCircle(
        Offset(cx, cy),
        r + 14,
        Paint()
          ..shader = RadialGradient(
            center: const Alignment(-0.4, -0.6),
            colors: [_gold, _goldDark],
          ).createShader(
              Rect.fromCircle(center: Offset(cx, cy), radius: r + 14)));
    // Inner dark ring + thin gold liner produce a triple-band Hades feel.
    canvas.drawCircle(Offset(cx, cy), r + 7, Paint()..color = _ink);
    canvas.drawCircle(
        Offset(cx, cy),
        r + 3,
        Paint()
          ..color = _gold
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.6);

    // Interior: subtle radial wash in the hero's body color so each class
    // reads with its own mood inside the same frame.
    canvas.drawCircle(
        Offset(cx, cy),
        r,
        Paint()
          ..shader = RadialGradient(
            center: const Alignment(-0.3, -0.4),
            colors: [
              _lit(def.body, 0.25).withValues(alpha: 0.55),
              const Color(0xFF14131F),
            ],
          ).createShader(
              Rect.fromCircle(center: Offset(cx, cy), radius: r)));

    // Four golden diamond ornaments at the cardinals.
    for (final a in const [0.0, pi / 2, pi, -pi / 2]) {
      final ox = cx + cos(a) * (r + 9);
      final oy = cy + sin(a) * (r + 9);
      final path = Path()
        ..moveTo(ox, oy - 7)
        ..lineTo(ox + 5, oy)
        ..lineTo(ox, oy + 7)
        ..lineTo(ox - 5, oy)
        ..close();
      canvas.drawPath(path, Paint()..color = _gold);
      canvas.drawPath(
          path,
          Paint()
            ..color = _ink
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.2);
    }

    // Hero portrait inside the medallion. Use stage 2 for the "buffed"
    // silhouette so the class accessories (helm/bow/hat) read clearly.
    canvas.save();
    canvas.clipPath(Path()..addOval(Rect.fromCircle(
        center: Offset(cx, cy), radius: r - 2)));
    _drawHero(canvas, Offset(cx, cy + r * 0.2), r * 0.65, def, 2);
    canvas.restore();

    if (label != null) _drawBanner(canvas, size, cy + r + 18, label!);
  }

  void _drawBanner(Canvas canvas, Size size, double y, String text) {
    final tp = TextPainter(
      text: TextSpan(
          text: text,
          style: const TextStyle(
              color: _gold,
              fontWeight: FontWeight.w900,
              fontSize: 14,
              letterSpacing: 2.2,
              fontFamily: 'RobotoMono')),
      textDirection: TextDirection.ltr,
    )..layout();
    final w = (tp.width + 38).clamp(80.0, size.width - 16);
    final h = tp.height + 14;
    final left = (size.width - w) / 2;
    final rect = Rect.fromLTWH(left, y, w, h);

    // Ribbon body: deep crimson with a darker fold underneath.
    canvas.drawRRect(
        RRect.fromRectAndRadius(
            rect.translate(0, 2), const Radius.circular(3)),
        Paint()..color = _crimsonDark);
    canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(3)),
        Paint()..color = _crimson);

    // Gold thin border + a small notch on each end.
    canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(3)),
        Paint()
          ..color = _gold
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.4);
    final notch = Path()
      ..moveTo(rect.left - 8, rect.top + h / 2)
      ..lineTo(rect.left, rect.top)
      ..lineTo(rect.left, rect.bottom)
      ..close();
    final notch2 = Path()
      ..moveTo(rect.right + 8, rect.top + h / 2)
      ..lineTo(rect.right, rect.top)
      ..lineTo(rect.right, rect.bottom)
      ..close();
    canvas.drawPath(notch, Paint()..color = _crimsonDark);
    canvas.drawPath(notch2, Paint()..color = _crimsonDark);

    tp.paint(canvas,
        Offset(rect.center.dx - tp.width / 2, rect.center.dy - tp.height / 2));
  }

  @override
  bool shouldRepaint(covariant HeroMedallionPainter old) =>
      old.def != def || old.label != label;
}

class WorldPainter extends CustomPainter {
  WorldPainter({
    required this.player,
    required this.enemies,
    required this.bolts,
    required this.ebolts,
    required this.grenades,
    this.homeNpcs = const <HomeNpc>[],
    this.talkingNpc,
    this.nectar = const <NectarDrop>[],
    this.captives = const <Captive>[],
    required this.orbs,
    required this.hearts,
    required this.bursts,
    required this.texts,
    required this.doors,
    required this.swings,
    required this.ghosts,
    required this.traps,
    required this.ballistas,
    required this.map,
    required this.floor,
    required this.time,
    required this.facing,
    required this.moving,
    required this.shake,
    required this.lowHp,
    required this.stickOn,
    required this.stickOrigin,
    required this.stickKnob,
    required this.ready,
    this.aimAt,
  });

  final Player player;
  final List<Enemy> enemies;
  final List<Bolt> bolts;
  final List<EBolt> ebolts;
  final List<Grenade> grenades;
  final List<HomeNpc> homeNpcs;
  final HomeNpc? talkingNpc;
  final List<NectarDrop> nectar;
  final List<Captive> captives;
  final List<Orb> orbs;
  final List<Heart> hearts;
  final List<Burst> bursts;
  final List<FloatText> texts;
  final List<Door> doors;
  final List<Swing> swings;
  final List<Ghost> ghosts;
  final List<Trap> traps;
  final List<Ballista> ballistas;
  final GameMap? map;
  final FloorDef floor;
  final double time;
  final Offset facing;
  final bool moving;
  final double shake;
  final bool lowHp;
  final bool stickOn;
  final Offset stickOrigin;
  final Offset stickKnob;
  final bool ready;
  final Enemy? aimAt;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
        Offset.zero & size, Paint()..color = const Color(0xFF06060B));
    final m = map;
    if (!ready || m == null) return;

    final z = (1.0 / (player.vision <= 0 ? 1.0 : player.vision))
        .clamp(0.6, 1.2)
        .toDouble();
    final cam = isoProject(player.pos); // follow-cam on the projected player

    canvas.save();
    canvas.translate(size.width / 2, size.height / 2);
    canvas.scale(z);
    if (shake > 0) {
      canvas.translate(sin(time * 97) * shake, cos(time * 89) * shake);
    }
    canvas.translate(-cam.dx, -cam.dy);

    _paintMap(canvas, m);
    final queue = <(double, void Function())>[];
    void enqueue(double d, void Function() fn) => queue.add((d, fn));
    _enqueueWalls(canvas, m, enqueue);
    _paintWorld(canvas, enqueue);
    queue.sort((a, b) => a.$1.compareTo(b.$1));
    for (final item in queue) {
      item.$2();
    }
    // Aim indicator: a soft pulsing ring around whichever enemy the
    // auto-aim is currently locked onto. Drawn above entities so it
    // reads even against busy backgrounds.
    _paintTelegraphs(canvas);
    _paintAim(canvas);
    // Small fast projectiles are drawn flat on top of the depth-sorted
    // pass instead of going through it — saves a closure + tuple per bolt
    // per frame, which adds up fast during volley-heavy combat.
    _paintProjectiles(canvas);
    // Doors render last (in world space) so they always sit above tiles,
    // walls, entities, and bursts — and their label is never occluded.
    _paintDoorsOverlay(canvas);
    _paintNpcBubble(canvas);

    canvas.restore();

    if (lowHp) {
      final a = 0.22 + 0.16 * (0.5 + 0.5 * sin(time * 7));
      canvas.drawRect(
        Offset.zero & size,
        Paint()
          ..shader = RadialGradient(
            radius: 0.95,
            colors: [
              const Color(0x00000000),
              const Color(0xFFFF2D40).withValues(alpha: a),
            ],
            stops: const [0.55, 1.0],
          ).createShader(Offset.zero & size),
      );
    }

    _paintMinimap(canvas, size, m);

    if (stickOn) {
      canvas.drawCircle(stickOrigin, 60,
          Paint()..color = Colors.white.withValues(alpha: 0.07));
      canvas.drawCircle(
          stickOrigin,
          60,
          Paint()
            ..color = Colors.white24
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2);
      canvas.drawCircle(stickKnob, 26,
          Paint()..color = Colors.white.withValues(alpha: 0.3));
    }
  }

  // 4 projected corners of tile (c,r), optionally lifted up-screen.
  Path _tilePath(double cell, int c, int r, [double lift = 0]) {
    final x0 = c * cell, y0 = r * cell, x1 = x0 + cell, y1 = y0 + cell;
    Offset p(double x, double y) {
      final s = isoProject(Offset(x, y));
      return Offset(s.dx, s.dy - lift);
    }

    final a = p(x0, y0), b = p(x1, y0), d = p(x1, y1), e = p(x0, y1);
    return Path()
      ..moveTo(a.dx, a.dy)
      ..lineTo(b.dx, b.dy)
      ..lineTo(d.dx, d.dy)
      ..lineTo(e.dx, e.dy)
      ..close();
  }

  // Cached static layer per GameMap. We rebuild the void + floor + pool-base
  // tiles into a Picture exactly once per generated map and stamp it each
  // frame; only the pool shimmer needs per-frame work.
  static final Map<int, ui.Picture> _mapBgCache = {};
  static final Map<int, List<int>> _poolTiles = {};

  // Called by the game when a fresh GameMap is generated so the per-map
  // static caches don't leak memory across rooms.
  static void resetCaches() {
    for (final p in _mapBgCache.values) {
      p.dispose();
    }
    _mapBgCache.clear();
    _poolTiles.clear();
    _wallEntries.clear();
  }

  // Telegraph + projectile pass for the three "elite" elites:
  //   - Bull (kind 10): yellow charge-up beam and dust streak.
  //   - Slammer (kind 11): growing yellow landing reticle.
  //   - Grenadier (kind 9): arcing grenade with shadow + landing zone.
  // All drawn above the depth queue so telegraphs read against busy combat.
  void _paintTelegraphs(Canvas canvas) {
    // Per-enemy telegraphs.
    for (final e in enemies) {
      if (e.kind == 10) {
        if (e.chargeWind > 0) {
          // Wind-up: short orange line in the direction of the player.
          _projAt(canvas, e.pos, 0, () {
            final dir = player.pos - e.pos;
            final d = dir.distance;
            if (d < 0.01) return;
            final unit = dir / d;
            final t = 1 - (e.chargeWind / 1.0).clamp(0.0, 1.0);
            const length = 220.0;
            final end = e.pos + unit * length;
            canvas.drawLine(
                e.pos,
                end,
                Paint()
                  ..color = const Color(0xFFFFD45E)
                      .withValues(alpha: 0.20 + 0.45 * t)
                  ..strokeWidth = 6 + 8 * t
                  ..strokeCap = StrokeCap.round);
            canvas.drawLine(
                e.pos,
                end,
                Paint()
                  ..color = const Color(0xFFFF6B3C)
                      .withValues(alpha: 0.6 * t)
                  ..strokeWidth = 2);
          });
        } else if (e.chargeRem > 0) {
          // Active dash: short orange streak behind in the locked direction.
          _projAt(canvas, e.pos, 0, () {
            final back = e.pos - e.chargeDir * 36;
            canvas.drawLine(
                back,
                e.pos,
                Paint()
                  ..color = const Color(0xFFFF6B3C).withValues(alpha: 0.5)
                  ..strokeWidth = 8
                  ..strokeCap = StrokeCap.round);
          });
        }
      } else if (e.kind == 11 && e.slamT > 0) {
        // Growing yellow landing reticle at the locked target.
        _projAt(canvas, e.slamTarget, 0, () {
          final p = (1.2 - e.slamT).clamp(0.0, 1.2) / 1.2;
          final radius = 22 + 38 * p;
          final col = Color.lerp(
              const Color(0xFFFFD45E), const Color(0xFFFF3B5C), p * p)!;
          canvas.drawCircle(
              e.slamTarget,
              radius,
              Paint()..color = col.withValues(alpha: 0.18 + 0.18 * p));
          canvas.drawCircle(
              e.slamTarget,
              radius,
              Paint()
                ..color = col.withValues(alpha: 0.6 + 0.3 * p)
                ..style = PaintingStyle.stroke
                ..strokeWidth = 2 + 2 * p);
          // Crosshair brackets.
          final cross = Paint()
            ..color = col.withValues(alpha: 0.8)
            ..strokeWidth = 2;
          canvas.drawLine(e.slamTarget.translate(-radius - 6, 0),
              e.slamTarget.translate(-radius + 6, 0), cross);
          canvas.drawLine(e.slamTarget.translate(radius - 6, 0),
              e.slamTarget.translate(radius + 6, 0), cross);
        });
      }
    }
    // Grenades: ground shadow + airborne body + landing reticle.
    for (final g in grenades) {
      final landP = g.progress;
      // Ground shadow follows the projected (x,y) on the floor.
      _projAt(canvas, g.pos, 0, () {
        canvas.drawOval(
            Rect.fromCenter(
                center: g.pos, width: 18 - landP * 4, height: 8 - landP * 2),
            Paint()..color = const Color(0x66000000));
      });
      // Landing-zone reticle at the impact site grows as it approaches land.
      _projAt(canvas, g.target, 0, () {
        canvas.drawCircle(
            g.target,
            12 + landP * 38,
            Paint()
              ..color = const Color(0xFFFFA84C)
                  .withValues(alpha: 0.20 + 0.20 * landP));
        canvas.drawCircle(
            g.target,
            12 + landP * 38,
            Paint()
              ..color = const Color(0xFFFFA84C)
                  .withValues(alpha: 0.6 + 0.3 * landP)
              ..style = PaintingStyle.stroke
              ..strokeWidth = 2);
      });
      // Body lifted off the ground along a sine arc.
      _projAt(canvas, g.pos, g.lift, () {
        canvas.drawCircle(g.pos, 8,
            Paint()..color = const Color(0xFFFFE2B0).withValues(alpha: 0.4));
        canvas.drawCircle(
            g.pos, 5, Paint()..color = const Color(0xFFFF8A4C));
      });
    }
  }

  // Pulsing reticle around the locked-on enemy so the player can see where
  // their auto-aim is pointing without disrupting the combat flow.
  void _paintAim(Canvas canvas) {
    final a = aimAt;
    if (a == null) return;
    _projAt(canvas, a.pos, 0, () {
      final pulse = 0.5 + 0.5 * sin(time * 12);
      final r = a.radius + 8 + pulse * 3;
      canvas.drawCircle(
          a.pos,
          r,
          Paint()
            ..color = const Color(0xFFFFD45E)
                .withValues(alpha: 0.25 + 0.25 * pulse)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2);
      // Two short brackets at the top/bottom of the ring for a "targeted" look.
      final tick = Paint()
        ..color = const Color(0xFFFFD45E).withValues(alpha: 0.7)
        ..strokeWidth = 2;
      canvas.drawLine(a.pos.translate(-r, -r - 2),
          a.pos.translate(-r + 6, -r - 2), tick);
      canvas.drawLine(a.pos.translate(r - 6, -r - 2),
          a.pos.translate(r, -r - 2), tick);
    });
  }

  // Cheap projectile pass: draws every bolt + enemy bolt directly with two
  // reused Paint objects. No depth-sort, no per-bolt closures.
  void _paintProjectiles(Canvas canvas) {
    final glow = Paint();
    final core = Paint();
    for (final b in bolts) {
      final s = isoProject(b.pos);
      final dx = s.dx - b.pos.dx, dy = s.dy - b.pos.dy;
      canvas.save();
      canvas.translate(dx, dy);
      final col = b.crit
          ? const Color(0xFFFFE066)
          : (b.splash > 0 ? const Color(0xFFFF9A3C) : Colors.white);
      final cr = b.splash > 0 ? 7.0 : (b.crit ? 6.0 : 4.0);
      glow.color = col.withValues(alpha: 0.3);
      core.color = col;
      canvas.drawCircle(b.pos, cr + 4, glow);
      canvas.drawCircle(b.pos, cr, core);
      canvas.restore();
    }
    for (final e in ebolts) {
      final s = isoProject(e.pos);
      final dx = s.dx - e.pos.dx, dy = s.dy - e.pos.dy;
      canvas.save();
      canvas.translate(dx, dy);
      final (g, c) = switch (e.kind) {
        1 => (const Color(0xFFA9E8FF), const Color(0xFFE6F8FF)), // frost
        2 => (const Color(0xFFFFA84C), const Color(0xFFFFE2B0)), // fire
        _ => (const Color(0xFFFF4D5E), const Color(0xFFFF6B79)),
      };
      glow.color = g.withValues(alpha: 0.3);
      core.color = c;
      canvas.drawCircle(e.pos, 9, glow);
      canvas.drawCircle(e.pos, 4.5, core);
      canvas.restore();
    }
  }

  // Speech bubble over the talking NPC. Drawn in world space so the camera
  // shake / iso projection moves it with the head, but on top of the
  // doors-overlay layer so it's never occluded.
  void _paintNpcBubble(Canvas canvas) {
    final n = talkingNpc;
    if (n == null) return;
    final line = n.lines[n.lineIdx.clamp(0, n.lines.length - 1)];
    final tp = TextPainter(
      text: TextSpan(
          text: line,
          style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              height: 1.35,
              fontFamily: 'RobotoMono',
              fontFamilyFallback: ['NotoEmoji'])),
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
    )..layout(maxWidth: 220);
    final nm = TextPainter(
      text: TextSpan(
          text: n.name,
          style: TextStyle(
              color: n.color,
              fontWeight: FontWeight.w900,
              fontSize: 10,
              letterSpacing: 2,
              fontFamily: 'RobotoMono')),
      textDirection: TextDirection.ltr,
    )..layout();
    final w = max(tp.width, nm.width) + 24;
    final h = tp.height + nm.height + 16;
    _projAt(canvas, n.pos, 0, () {
      final anchor = n.pos.translate(0, -52);
      final rect = Rect.fromCenter(center: anchor, width: w, height: h);
      final rrect =
          RRect.fromRectAndRadius(rect, const Radius.circular(8));
      // Drop shadow plate.
      canvas.drawRRect(rrect.shift(const Offset(0, 3)),
          Paint()..color = const Color(0xAA000000));
      canvas.drawRRect(
          rrect, Paint()..color = const Color(0xEE12101C));
      canvas.drawRRect(
          rrect,
          Paint()
            ..color = n.color
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.6);
      // Tail pointing down to the NPC's head.
      final tail = Path()
        ..moveTo(anchor.dx - 8, rect.bottom)
        ..lineTo(anchor.dx, rect.bottom + 10)
        ..lineTo(anchor.dx + 8, rect.bottom)
        ..close();
      canvas.drawPath(tail, Paint()..color = const Color(0xEE12101C));
      canvas.drawPath(
          tail,
          Paint()
            ..color = n.color
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.6);
      nm.paint(canvas, Offset(rect.left + 12, rect.top + 6));
      tp.paint(canvas, Offset(rect.center.dx - tp.width / 2,
          rect.top + 6 + nm.height + 4));
    });
  }

  void _paintDoorsOverlay(Canvas canvas) {
    if (doors.isEmpty) return;
    for (final d in doors) {
      _projAt(canvas, d.pos, 0, () {
        final pulse = 0.5 + 0.5 * sin(time * 4 + d.pos.dx);
        canvas.drawCircle(d.pos, d.r + 12,
            Paint()..color = const Color(0xFFFFD45E).withValues(alpha: 0.2));
        final arch = RRect.fromRectAndRadius(
          Rect.fromCenter(center: d.pos, width: d.r * 2, height: d.r * 2.4),
          Radius.circular(d.r),
        );
        canvas.drawRRect(arch, Paint()..color = _shd(floor.bg, 0.5));
        canvas.drawRRect(
            arch,
            Paint()
              ..color = Color.lerp(
                  const Color(0xFFFFD45E), Colors.white, pulse * 0.4)!
              ..style = PaintingStyle.stroke
              ..strokeWidth = 4);
        final tp = TextPainter(
          text: TextSpan(
              text: d.def.icon,
              style: const TextStyle(fontSize: 26, fontFamily: 'NotoEmoji')),
          textDirection: TextDirection.ltr,
        )..layout();
        tp.paint(canvas, d.pos - Offset(tp.width / 2, tp.height / 2));
        // Label is drawn over a dark plate so the title + desc are legible
        // no matter what tile / wall is behind the door.
        final lp = TextPainter(
          text: TextSpan(
              style: const TextStyle(
                  fontFamily: 'RobotoMono',
                  fontFamilyFallback: ['NotoEmoji']),
              children: [
                TextSpan(
                    text: '${d.def.title}\n',
                    style: const TextStyle(
                        color: Color(0xFFFFD45E),
                        fontWeight: FontWeight.w900,
                        fontSize: 13,
                        height: 1.3)),
                TextSpan(
                    text: d.def.desc,
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 11)),
              ]),
          textAlign: TextAlign.center,
          textDirection: TextDirection.ltr,
        )..layout(maxWidth: 200);
        final labelTop = d.pos.dy + d.r * 1.2 + 6;
        final plate = RRect.fromRectAndRadius(
            Rect.fromLTWH(d.pos.dx - lp.width / 2 - 8, labelTop - 4,
                lp.width + 16, lp.height + 8),
            const Radius.circular(8));
        canvas.drawRRect(
            plate, Paint()..color = const Color(0xCC0E0C16));
        canvas.drawRRect(
            plate,
            Paint()
              ..color = const Color(0x33FFD45E)
              ..style = PaintingStyle.stroke
              ..strokeWidth = 1);
        lp.paint(canvas, Offset(d.pos.dx - lp.width / 2, labelTop));
      });
    }
  }

  void _paintMap(Canvas canvas, GameMap m) {
    final id = identityHashCode(m);
    final pic = _mapBgCache.putIfAbsent(id, () => _buildStaticMapPicture(m));
    canvas.drawPicture(pic);

    // Pools animate (shimmer), so they get a small per-frame pass — but only
    // over the precomputed pool-tile list rather than scanning all cells.
    final pools = _poolTiles[id];
    if (pools == null || pools.isEmpty) return;
    final cell = m.cell;
    final cols = m.cols;
    final shimmer = Paint();
    for (final idx in pools) {
      final c = idx % cols, r = idx ~/ cols;
      final sh = 0.5 + 0.5 * sin(time * 2 + c * 0.7 + r * 0.5);
      shimmer.color =
          _lit(floor.pool, 0.22 * sh).withValues(alpha: 0.5);
      canvas.drawPath(_tilePath(cell, c, r), shimmer);
    }
  }

  ui.Picture _buildStaticMapPicture(GameMap m) {
    final cell = m.cell;
    final w = m.worldW, h = m.worldH;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);

    final back = Path()
      ..addPolygon([
        isoProject(const Offset(0, 0)),
        isoProject(Offset(w, 0)),
        isoProject(Offset(w, h)),
        isoProject(Offset(0, h)),
      ], true);
    canvas.drawPath(back, Paint()..color = floor.voidc);

    final floorPaint = Paint()..color = floor.bg;
    final edge = Paint()
      ..color = floor.grid.withValues(alpha: 0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    final poolFill = Paint()..color = floor.pool;
    final poolEdge = Paint()
      ..color = _shd(floor.pool, 0.35)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    final pools = <int>[];
    for (var r = 0; r < m.rows; r++) {
      for (var c = 0; c < m.cols; c++) {
        final t = m.tt(c, r);
        if (t == 1) {
          final pth = _tilePath(cell, c, r);
          canvas.drawPath(pth, floorPaint);
          canvas.drawPath(pth, edge);
        } else if (t == 2) {
          final pth = _tilePath(cell, c, r);
          canvas.drawPath(pth, poolFill);
          canvas.drawPath(pth, poolEdge);
          pools.add(r * m.cols + c);
        }
      }
    }

    _poolTiles[identityHashCode(m)] = pools;
    return recorder.endRecording();
  }

  // Visible-wall cells precomputed once per map so the per-frame draw skips
  // the 2700-cell scan and only walks the small set of cells that matter.
  // Each entry packs (c, r, hsh, isWall) into a flat int list: 4 ints per cell.
  static final Map<int, List<int>> _wallEntries = {};

  List<int> _wallEntriesFor(GameMap m) {
    final id = identityHashCode(m);
    final cached = _wallEntries[id];
    if (cached != null) return cached;
    final out = <int>[];
    for (var r = 0; r < m.rows; r++) {
      for (var c = 0; c < m.cols; c++) {
        if (m.tt(c, r) != 0) continue;
        final play = m.tt(c - 1, r) > 0 ||
            m.tt(c + 1, r) > 0 ||
            m.tt(c, r - 1) > 0 ||
            m.tt(c, r + 1) > 0;
        final hsh = (c * 73 + r * 131) % 100;
        if (play) {
          out.add(c);
          out.add(r);
          out.add(hsh);
          out.add(1);
        } else if (hsh < 8) {
          out.add(c);
          out.add(r);
          out.add(hsh);
          out.add(0);
        }
      }
    }
    _wallEntries[id] = out;
    return out;
  }

  // Walls are tall, so they participate in the depth-sorted pass with
  // dynamic entities so a character standing in front of a wall draws on
  // top of it and a character behind it is occluded.
  void _enqueueWalls(Canvas canvas, GameMap m,
      void Function(double depth, void Function() draw) add) {
    final cell = m.cell;
    final sideR = Paint()..color = _shd(floor.prop, 0.32);
    final sideF = Paint()..color = _shd(floor.prop, 0.5);
    final topP = Paint()..color = floor.prop;
    final topEdge = Paint()
      ..color = _shd(floor.prop, 0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    Offset pj(double x, double y, double lift) {
      final s = isoProject(Offset(x, y));
      return Offset(s.dx, s.dy - lift);
    }

    final entries = _wallEntriesFor(m);
    for (var i = 0; i < entries.length; i += 4) {
      final c = entries[i];
      final r = entries[i + 1];
      final hsh = entries[i + 2];
      final isWall = entries[i + 3] == 1;
      final depth = c + r + 0.5;
      if (isWall) {
        add(depth, () {
          final x0 = c * cell, y0 = r * cell, x1 = x0 + cell, y1 = y0 + cell;
          canvas.drawPath(
              Path()
                ..moveTo(pj(x1, y0, 0).dx, pj(x1, y0, 0).dy)
                ..lineTo(pj(x1, y1, 0).dx, pj(x1, y1, 0).dy)
                ..lineTo(pj(x1, y1, kWallH).dx, pj(x1, y1, kWallH).dy)
                ..lineTo(pj(x1, y0, kWallH).dx, pj(x1, y0, kWallH).dy)
                ..close(),
              sideR);
          canvas.drawPath(
              Path()
                ..moveTo(pj(x0, y1, 0).dx, pj(x0, y1, 0).dy)
                ..lineTo(pj(x1, y1, 0).dx, pj(x1, y1, 0).dy)
                ..lineTo(pj(x1, y1, kWallH).dx, pj(x1, y1, kWallH).dy)
                ..lineTo(pj(x0, y1, kWallH).dx, pj(x0, y1, kWallH).dy)
                ..close(),
              sideF);
          final top = _tilePath(cell, c, r, kWallH);
          canvas.drawPath(top, topP);
          canvas.drawPath(top, topEdge);
          if (hsh < 40) {
            _projAt(canvas, Offset((c + 0.5) * cell, (r + 0.4) * cell),
                kWallH,
                () => _drawProp(canvas,
                    Offset((c + 0.5) * cell, (r + 0.4) * cell),
                    cell, hsh % 5, floor));
          }
        });
      } else {
        add(depth, () {
          _projAt(canvas, Offset((c + 0.5) * cell, (r + 0.5) * cell), 0,
              () => _drawProp(canvas,
                  Offset((c + 0.5) * cell, (r + 0.5) * cell),
                  cell, hsh % 5, floor));
        });
      }
    }
  }

  // Run [draw] (which paints around [anchor] in world coords) so that it lands
  // at the projected, optionally lifted, screen position — body stays upright.
  void _projAt(Canvas canvas, Offset anchor, double lift, void Function() draw) {
    final s = isoProject(anchor);
    canvas.save();
    canvas.translate(s.dx - anchor.dx, s.dy - anchor.dy - lift);
    draw();
    canvas.restore();
  }

  void _paintWorld(
      Canvas canvas, void Function(double, void Function()) add) {
    final cellSize = map!.cell;
    double dep(Offset p) => (p.dx + p.dy) / cellSize;
    // traps — drawn as a diamond filling the floor tile so the marker
    // visually matches the iso grid instead of floating as a flat circle.
    final cell = map!.cell;
    for (final tr in traps) {
      add(dep(tr.pos), () => _projAt(canvas, tr.pos, 0, () {
            final col = tr.state == 1
                ? const Color(0xFFFF5C5C)
                : (tr.state == 2
                    ? const Color(0x55FFFFFF)
                    : const Color(0xFFFFB347));
            final pulse =
                tr.state == 1 ? 0.5 + 0.5 * sin(time * 24) : 0.4;
            final tc = (tr.pos.dx / cell).floor();
            final trow = (tr.pos.dy / cell).floor();
            final tile = _tilePath(cell, tc, trow);
            canvas.drawPath(tile,
                Paint()..color = col.withValues(alpha: 0.20 + 0.22 * pulse));
            canvas.drawPath(
                tile,
                Paint()
                  ..color = col
                  ..style = PaintingStyle.stroke
                  ..strokeWidth = 2);
            final mp = Paint()
              ..color = col
              ..strokeWidth = 3;
            canvas.drawLine(tr.pos.translate(-tr.r * 0.35, -tr.r * 0.35),
                tr.pos.translate(tr.r * 0.35, tr.r * 0.35), mp);
            canvas.drawLine(tr.pos.translate(tr.r * 0.35, -tr.r * 0.35),
                tr.pos.translate(-tr.r * 0.35, tr.r * 0.35), mp);
          }));
    }

    // Ballista heads only — the warning laser line was distracting in tight
    // rooms and made every room look like a kill grid, so it's gone now.
    for (final ba in ballistas) {
      add(dep(ba.pos), () => _projAt(canvas, ba.pos, 0, () {
            canvas.drawRect(
                Rect.fromCenter(center: ba.pos, width: 22, height: 22),
                Paint()..color = _shd(floor.prop, 0.1));
            canvas.drawCircle(
                ba.pos, 7, Paint()..color = const Color(0xFFBB4444));
          }));
    }

    // Doors are intentionally NOT added to the depth-sorted queue — they
    // are drawn on top of every map / entity in `_paintDoorsOverlay` after
    // the queue is flushed, so the arched portal and its label are never
    // hidden behind walls or props.

    for (final b in bursts) {
      add(dep(b.pos), () => _projAt(canvas, b.pos, 0, () {
      final double f = (b.t / 0.35).clamp(0.0, 1.0).toDouble();
      canvas.drawCircle(b.pos, b.maxR * f,
          Paint()..color = const Color(0xFFFF9A3C).withValues(alpha: (1 - f) * 0.22));
      canvas.drawCircle(
          b.pos,
          b.maxR * f,
          Paint()
            ..color = const Color(0xFFFFD45E).withValues(alpha: (1 - f) * 0.7)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 4);
      }));
    }

    for (final o in orbs) {
      add(dep(o.pos), () => _projAt(canvas, o.pos, 0, () {
      final pul = 0.5 + 0.5 * sin(time * 6 + o.pos.dx);
      canvas.drawCircle(o.pos, 11,
          Paint()..color = const Color(0xFF8CFF98).withValues(alpha: 0.22));
      canvas.drawCircle(
          o.pos, 4 + pul * 1.6, Paint()..color = const Color(0xFFB6FFC0));
      }));
    }
    for (final h in hearts) {
      final pos = h.pos.translate(0, -2 + sin(h.bob * 4) * 2);
      // Fade out during the last second before despawning.
      final fade = h.life < 1.0 ? h.life.clamp(0.0, 1.0).toDouble() : 1.0;
      add(dep(pos), () => _projAt(canvas, pos, 0, () {
            canvas.drawCircle(
                pos,
                14,
                Paint()
                  ..color =
                      const Color(0xFFFF6B79).withValues(alpha: 0.20 * fade));
            // Two overlapping circles + a triangle approximate a heart icon.
            canvas.drawCircle(pos.translate(-3.4, -1),
                4.4, Paint()..color = const Color(0xFFFF6B79).withValues(alpha: fade));
            canvas.drawCircle(pos.translate(3.4, -1),
                4.4, Paint()..color = const Color(0xFFFF6B79).withValues(alpha: fade));
            final path = Path()
              ..moveTo(pos.dx - 6.5, pos.dy + 1)
              ..lineTo(pos.dx + 6.5, pos.dy + 1)
              ..lineTo(pos.dx, pos.dy + 8)
              ..close();
            canvas.drawPath(
                path,
                Paint()
                  ..color = const Color(0xFFFF6B79).withValues(alpha: fade));
          }));
    }
    // Nectar bottles: amber droplet with a pulsing aura.
    for (final n in nectar) {
      final pos = n.pos.translate(0, -3 + sin(n.bob * 4.6) * 2);
      final fade = n.life < 1.0 ? n.life.clamp(0.0, 1.0).toDouble() : 1.0;
      add(dep(pos), () => _projAt(canvas, pos, 0, () {
            canvas.drawCircle(
                pos,
                12,
                Paint()
                  ..color =
                      const Color(0xFFFFD45E).withValues(alpha: 0.22 * fade));
            // Bottle: rounded body + gold cap.
            canvas.drawRRect(
                RRect.fromRectAndRadius(
                    Rect.fromCenter(
                        center: pos.translate(0, 1),
                        width: 8.5,
                        height: 12),
                    const Radius.circular(3)),
                Paint()
                  ..color =
                      const Color(0xFFFFB347).withValues(alpha: fade));
            canvas.drawRect(
                Rect.fromCenter(
                    center: pos.translate(0, -5), width: 5.5, height: 4),
                Paint()
                  ..color =
                      const Color(0xFFFFD45E).withValues(alpha: fade));
          }));
    }
    // Captives: faded ghostly NPC body with shimmering chains until freed.
    for (final c in captives) {
      if (c.freed) continue;
      final pos = c.pos.translate(0, sin(c.bob * 2.2) * 1.2);
      add(dep(pos), () => _projAt(canvas, pos, 0, () {
            // Dim halo so the player sees them from across the room.
            final pulse = 0.5 + 0.5 * sin(c.bob * 4);
            canvas.drawCircle(
                pos,
                36,
                Paint()
                  ..color = const Color(0xFFFFD45E)
                      .withValues(alpha: 0.10 + 0.10 * pulse));
            canvas.drawCircle(
                pos,
                20,
                Paint()
                  ..shader = RadialGradient(
                    colors: [
                      const Color(0xFF8CC8FF).withValues(alpha: 0.55),
                      const Color(0xFF4A4F6B).withValues(alpha: 0.85),
                    ],
                  ).createShader(Rect.fromCircle(center: pos, radius: 20)));
            canvas.drawCircle(
                pos,
                20,
                Paint()
                  ..color = const Color(0xFFFFD45E)
                  ..style = PaintingStyle.stroke
                  ..strokeWidth = 2);
            // "?" mark and a chain bracket below to read as "captive".
            final tp = TextPainter(
              text: const TextSpan(
                  text: '?',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      fontFamily: 'RobotoMono')),
              textDirection: TextDirection.ltr,
            )..layout();
            tp.paint(canvas, pos - Offset(tp.width / 2, tp.height / 2));
            final chain = Paint()
              ..color = const Color(0xFF7E8AAB)
              ..strokeWidth = 2;
            canvas.drawLine(pos.translate(-14, 22), pos.translate(14, 22),
                chain);
            canvas.drawLine(pos.translate(-8, 18), pos.translate(-8, 26),
                chain);
            canvas.drawLine(
                pos.translate(8, 18), pos.translate(8, 26), chain);
          }));
    }

    for (final e in enemies) {
      // Slammers go offscreen while airborne — the floor reticle is the only
      // tell the player needs while they decide where to dodge.
      if (e.kind == 11 && e.slamT > 0) continue;
      add(dep(e.pos), () => _projAt(canvas, e.pos, 0, () {
      final base = switch (e.kind) {
        1 => const Color(0xFFFF8A4C),
        2 => const Color(0xFF9B5CFF),
        3 => const Color(0xFFFF3B5C),
        4 => const Color(0xFF4CD2C0),
        5 => const Color(0xFF9CA8B5), // SHIELDED — steel grey
        6 => const Color(0xFFA9E8FF), // FROST — ice cyan
        7 => const Color(0xFF8E1A2B), // VAMPIRE — blood red
        8 => const Color(0xFFFF6432), // KAMIKAZE — fuse orange
        9 => const Color(0xFF5C8A3C), // GRENADIER — moss green
        10 => const Color(0xFF5C3A22), // BULL — leather brown
        11 => const Color(0xFFB94CFF), // SLAMMER — bright magenta
        _ => floor.mob,
      };
      canvas.drawOval(
        Rect.fromCenter(
            center: e.pos.translate(0, e.radius * 0.9),
            width: e.radius * 1.9,
            height: e.radius * 0.6),
        Paint()..color = const Color(0x3C000000),
      );
      if (e.elite) {
        final g = 0.5 + 0.5 * sin(time * 6 + e.pos.dx);
        canvas.drawCircle(
            e.pos,
            e.radius + 7 + g * 4,
            Paint()
              ..color = const Color(0xFFFFE066).withValues(alpha: 0.35)
              ..style = PaintingStyle.stroke
              ..strokeWidth = 3);
      }
      if (e.kind == 3) {
        final aura = 0.5 + 0.5 * sin(time * 5);
        canvas.drawCircle(
            e.pos,
            e.radius + 6 + aura * 4,
            Paint()
              ..color = base.withValues(alpha: 0.25)
              ..style = PaintingStyle.stroke
              ..strokeWidth = 3);
        // Boss nova telegraph: a fattening yellow ring that flashes red on impact.
        if (e.novaTele > 0 && e.novaRadius > 0) {
          final t = (1.1 - e.novaTele).clamp(0.0, 1.1) / 1.1; // 0 → 1
          final col = Color.lerp(const Color(0xFFFFD45E),
                  const Color(0xFFFF3B5C), t * t) ??
              const Color(0xFFFFD45E);
          canvas.drawCircle(
              e.pos,
              e.novaRadius * t,
              Paint()
                ..color = col.withValues(alpha: 0.18 + 0.35 * t)
                ..style = PaintingStyle.stroke
                ..strokeWidth = 3 + 3 * t);
        }
      }
      canvas.drawCircle(
        e.pos,
        e.radius,
        Paint()
          ..shader = RadialGradient(
            center: const Alignment(-0.4, -0.5),
            colors: [_lit(base, 0.4), base, _shd(base, 0.4)],
            stops: const [0.0, 0.55, 1.0],
          ).createShader(Rect.fromCircle(center: e.pos, radius: e.radius)),
      );
      canvas.drawCircle(
          e.pos,
          e.radius,
          Paint()
            ..color = _shd(base, 0.5)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.6);
      if (e.kind == 3) {
        final crown = Path()
          ..moveTo(e.pos.dx - e.radius * 0.7, e.pos.dy - e.radius * 0.85)
          ..lineTo(e.pos.dx - e.radius * 0.5, e.pos.dy - e.radius * 1.35)
          ..lineTo(e.pos.dx - e.radius * 0.25, e.pos.dy - e.radius * 0.95)
          ..lineTo(e.pos.dx, e.pos.dy - e.radius * 1.45)
          ..lineTo(e.pos.dx + e.radius * 0.25, e.pos.dy - e.radius * 0.95)
          ..lineTo(e.pos.dx + e.radius * 0.5, e.pos.dy - e.radius * 1.35)
          ..lineTo(e.pos.dx + e.radius * 0.7, e.pos.dy - e.radius * 0.85)
          ..close();
        canvas.drawPath(crown, Paint()..color = const Color(0xFFFFD45E));
      }
      final brow = Paint()
        ..color = Colors.black
        ..strokeWidth = e.radius * 0.12
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(e.pos.translate(-e.radius * 0.5, -e.radius * 0.32),
          e.pos.translate(-e.radius * 0.15, -e.radius * 0.16), brow);
      canvas.drawLine(e.pos.translate(e.radius * 0.5, -e.radius * 0.32),
          e.pos.translate(e.radius * 0.15, -e.radius * 0.16), brow);
      final wp = Paint()..color = Colors.white;
      canvas.drawCircle(e.pos.translate(-e.radius * 0.3, -e.radius * 0.02),
          e.radius * 0.2, wp);
      canvas.drawCircle(e.pos.translate(e.radius * 0.3, -e.radius * 0.02),
          e.radius * 0.2, wp);
      final pup = Paint()..color = Colors.black;
      canvas.drawCircle(e.pos.translate(-e.radius * 0.26, e.radius * 0.02),
          e.radius * 0.1, pup);
      canvas.drawCircle(e.pos.translate(e.radius * 0.26, e.radius * 0.02),
          e.radius * 0.1, pup);
      if (e.flash > 0) {
        canvas.drawCircle(
            e.pos,
            e.radius,
            Paint()
              ..color = Colors.white.withValues(
                  alpha: (e.flash / 0.1).clamp(0.0, 1.0).toDouble() * 0.7));
      }
      final bw = e.radius * 2;
      final by = e.pos.dy - e.radius - 9;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromLTWH(e.pos.dx - e.radius, by, bw, 4),
            const Radius.circular(2)),
        Paint()..color = Colors.black54,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromLTWH(e.pos.dx - e.radius, by,
                bw * (e.hp / e.maxHp).clamp(0, 1).toDouble(), 4),
            const Radius.circular(2)),
        Paint()..color = const Color(0xFF8CFF98),
      );
      }));
    }

    // (bolts + ebolts moved to _paintProjectiles to skip the depth queue)

    add(dep(player.pos), () => _projAt(canvas, player.pos, 0, () {
    if (player.invuln > 0) {
      canvas.drawCircle(
          player.pos,
          player.radius + 9,
          Paint()
            ..color = const Color(0x668CC8FF)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 3);
    }
    if (player.frenzy > 0) {
      canvas.drawCircle(
          player.pos,
          player.radius + 6 + sin(time * 16).abs() * 3,
          Paint()
            ..color = const Color(0x66FFD45E)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 3);
    }
    if (player.hurtFlash > 0) {
      canvas.drawCircle(player.pos, player.radius + 6,
          Paint()..color = const Color(0x55FF5C6C));
    }
    }));
    for (final s in swings) {
      add(dep(s.pos), () => _projAt(canvas, s.pos, 0, () {
      final k = (s.life / 0.18).clamp(0.0, 1.0).toDouble();
      final paint = Paint()
        ..color = Colors.white.withValues(alpha: 0.5 * k)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 6;
      if (s.thrust) {
        final tip = s.pos +
            Offset(cos(s.ang), sin(s.ang)) * s.reach * (1.0 - k * 0.3);
        canvas.drawLine(s.pos, tip, paint..strokeWidth = 10);
      } else {
        final rect = Rect.fromCircle(center: s.pos, radius: s.reach);
        canvas.drawArc(rect, s.ang - s.arc / 2, s.arc, false, paint);
      }
      }));
    }
    for (final g in ghosts) {
      add(dep(g.pos), () => _projAt(canvas, g.pos, 0, () {
        final k = (g.life / 0.3).clamp(0.0, 1.0).toDouble();
        // Tinted ghost body plus a brighter highlight ring for a stronger
        // streak read during the 6-step dash burst.
        canvas.drawCircle(
            g.pos,
            player.radius,
            Paint()
              ..color =
                  const Color(0xFF8CC8FF).withValues(alpha: 0.30 * k));
        canvas.drawCircle(
            g.pos,
            player.radius + 2,
            Paint()
              ..color =
                  const Color(0xFFE0F2FF).withValues(alpha: 0.55 * k)
              ..style = PaintingStyle.stroke
              ..strokeWidth = 1.4);
      }));
    }
    add(dep(player.pos), () {
      _projAt(canvas, player.pos, 0, () {
        _drawHero(canvas, player.pos, player.radius, player.def,
            player.buffStage,
            t: time, moving: moving, look: facing);
      });
    });
    // Home-room NPCs: drawn as colored disc + emoji face, depth-sorted so
    // they stand behind / in front of the player consistently.
    for (final n in homeNpcs) {
      add(dep(n.pos), () => _projAt(canvas, n.pos, 0, () {
            const r = 22.0;
            final bob = sin(n.bob * 2.6) * 1.5;
            final c = n.pos.translate(0, bob);
            // shadow
            canvas.drawOval(
                Rect.fromCenter(
                    center: c.translate(0, r * 0.95),
                    width: r * 1.7,
                    height: r * 0.5),
                Paint()..color = const Color(0x44000000));
            canvas.drawCircle(
                c,
                r,
                Paint()
                  ..shader = RadialGradient(
                    center: const Alignment(-0.4, -0.5),
                    colors: [_lit(n.color, 0.4), n.color, _shd(n.color, 0.4)],
                    stops: const [0.0, 0.55, 1.0],
                  ).createShader(Rect.fromCircle(center: c, radius: r)));
            canvas.drawCircle(
                c,
                r,
                Paint()
                  ..color = _shd(n.color, 0.5)
                  ..style = PaintingStyle.stroke
                  ..strokeWidth = 2);
            // Emoji face centered on the body.
            final tp = TextPainter(
              text: TextSpan(
                  text: n.icon,
                  style:
                      const TextStyle(fontSize: 22, fontFamily: 'NotoEmoji')),
              textDirection: TextDirection.ltr,
            )..layout();
            tp.paint(canvas, c - Offset(tp.width / 2, tp.height / 2));
            // Name tag below the body.
            final nt = TextPainter(
              text: TextSpan(
                  text: n.name,
                  style: TextStyle(
                      color: n.color,
                      fontWeight: FontWeight.w900,
                      fontSize: 10,
                      letterSpacing: 1.6,
                      fontFamily: 'RobotoMono')),
              textDirection: TextDirection.ltr,
            )..layout();
            nt.paint(
                canvas,
                Offset(c.dx - nt.width / 2,
                    c.dy + r + 4));
          }));
    }

    for (final tx in texts) {
      add(1e18, () => _projAt(canvas, tx.pos, 0, () {
      final a = tx.life.clamp(0.0, 1.0).toDouble();
      void dr(Color col, Offset at) {
        final tp = TextPainter(
          text: TextSpan(
            text: tx.text,
            style: TextStyle(
                color: col.withValues(alpha: a),
                fontSize: tx.size,
                fontWeight: FontWeight.w900,
                fontFamily: 'RobotoMono',
                fontFamilyFallback: const ['NotoEmoji']),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        tp.paint(canvas, at - Offset(tp.width / 2, tp.height / 2));
      }

      dr(Colors.black, tx.pos.translate(1.4, 1.4));
      dr(tx.color, tx.pos);
      }));
    }
  }

  void _paintMinimap(Canvas canvas, Size size, GameMap m) {
    const mw = 92.0;
    final mh = mw * (m.worldH / m.worldW);
    final ox = size.width - mw - 14;
    final oy = 14.0;
    final rect = Rect.fromLTWH(ox, oy, mw, mh);
    canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(6)),
        Paint()..color = Colors.black.withValues(alpha: 0.5));
    final fp = Paint()..color = floor.bg.withValues(alpha: 0.9);
    final sx = mw / m.cols;
    final sy = mh / m.rows;
    for (var r = 0; r < m.rows; r++) {
      for (var c = 0; c < m.cols; c++) {
        if (m.tile(c, r)) {
          canvas.drawRect(
              Rect.fromLTWH(ox + c * sx, oy + r * sy, sx + 0.6, sy + 0.6),
              fp);
        }
      }
    }
    canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(6)),
        Paint()
          ..color = Colors.white24
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1);
    Offset mp(Offset w) =>
        Offset(ox + w.dx / m.worldW * mw, oy + w.dy / m.worldH * mh);
    final ep = Paint()..color = const Color(0xFFFF5C6C);
    for (final e in enemies) {
      canvas.drawCircle(mp(e.pos), 1.6, ep);
    }
    final dp = Paint()..color = const Color(0xFFFFD45E);
    for (final dr in doors) {
      canvas.drawCircle(mp(dr.pos), 3, dp);
    }
    canvas.drawCircle(
        mp(player.pos), 3, Paint()..color = const Color(0xFF8CFF98));
  }

  @override
  bool shouldRepaint(covariant WorldPainter old) => true;
}

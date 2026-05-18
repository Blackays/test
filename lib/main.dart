import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

void main() => runApp(const BuffBattleApp());

/// ---------------------------------------------------------------------------
/// App shell
/// ---------------------------------------------------------------------------
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
        fontFamily: 'monospace',
      ),
      home: const TitleScreen(),
    );
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
    speed: 118,
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
    speed: 166,
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
    speed: 138,
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
    speed: 146,
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
    speed: 204,
    damage: 1.6,
    fireInterval: 0.30,
    projSpeed: 480,
    range: 220,
    critChance: 0.25,
    abilityName: 'SHADOW DASH',
    abilityDesc: 'Blink to target, burst dmg, brief i-frames',
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
    speed: 150,
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
    required this.grid,
    required this.mob,
    required this.hpMul,
    required this.spdMul,
    required this.dmgMul,
  });

  final String name;
  final Color bg;
  final Color grid;
  final Color mob;
  final double hpMul;
  final double spdMul;
  final double dmgMul;
}

const List<FloorDef> kFloors = [
  FloorDef(
    name: 'THE BACKYARD',
    bg: Color(0xFF15231A),
    grid: Color(0xFF254033),
    mob: Color(0xFF7BC96F),
    hpMul: 1.0,
    spdMul: 1.0,
    dmgMul: 1.0,
  ),
  FloorDef(
    name: 'SEWER OF SHAME',
    bg: Color(0xFF11201F),
    grid: Color(0xFF1E3A38),
    mob: Color(0xFF49C3B0),
    hpMul: 1.5,
    spdMul: 1.08,
    dmgMul: 1.2,
  ),
  FloorDef(
    name: 'DANK CAVES',
    bg: Color(0xFF1F1726),
    grid: Color(0xFF3A2A47),
    mob: Color(0xFFB05CCB),
    hpMul: 2.2,
    spdMul: 1.16,
    dmgMul: 1.45,
  ),
  FloorDef(
    name: 'MEME FACTORY',
    bg: Color(0xFF26201A),
    grid: Color(0xFF453826),
    mob: Color(0xFFE0A046),
    hpMul: 3.1,
    spdMul: 1.24,
    dmgMul: 1.7,
  ),
  FloorDef(
    name: 'THE VOID',
    bg: Color(0xFF0E0E16),
    grid: Color(0xFF26263A),
    mob: Color(0xFFFF5C8A),
    hpMul: 4.2,
    spdMul: 1.34,
    dmgMul: 2.0,
  ),
];

const int kWavesPerFloor = 5;
final int kMaxWaves = kFloors.length * kWavesPerFloor;
const double kWaveTime = 22;

/// ---------------------------------------------------------------------------
/// Title screen
/// ---------------------------------------------------------------------------
class TitleScreen extends StatelessWidget {
  const TitleScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'BUFF BATTLE',
              style: TextStyle(
                fontSize: 44,
                fontWeight: FontWeight.w900,
                letterSpacing: 2,
                color: Color(0xFFFFD45E),
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'pick a class · cast · loot · clear the floors',
              style: TextStyle(color: Colors.white54, fontSize: 13),
            ),
            const SizedBox(height: 40),
            _BigButton(
              label: 'PLAY',
              color: const Color(0xFFFFD45E),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const CharacterSelectScreen(),
                ),
              ),
            ),
            const SizedBox(height: 18),
            if (GameStats.bestWave > 0)
              Text(
                'best: floor ${((GameStats.bestWave - 1) ~/ kWavesPerFloor) + 1}'
                ' · wave ${GameStats.bestWave}',
                style: const TextStyle(color: Colors.white38),
              ),
          ],
        ),
      ),
    );
  }
}

/// ---------------------------------------------------------------------------
/// Character select
/// ---------------------------------------------------------------------------
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
      onTap: () => Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(builder: (_) => GameScreen(def: def)),
      ),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF1F1D2E),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: def.accent, width: 2),
        ),
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            SizedBox(
              width: 80,
              height: 80,
              child: CustomPaint(painter: HeroPreviewPainter(def: def)),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          def.name,
                          style: TextStyle(
                            fontSize: 19,
                            fontWeight: FontWeight.w900,
                            color: def.body,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: def.accent,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          def.role,
                          style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                              color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(def.tagline,
                      style: const TextStyle(
                          color: Colors.white54, fontSize: 11)),
                  const SizedBox(height: 6),
                  Text(
                    'HP ${def.maxHp.toInt()}  MP ${def.maxMp.toInt()}  '
                    'DMG ${def.damage}  SPD ${def.speed.toInt()}',
                    style:
                        const TextStyle(color: Colors.white38, fontSize: 10),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '✦ ${def.abilityName}: ${def.abilityDesc}',
                    style: TextStyle(
                        color: def.body, fontSize: 10, height: 1.3),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// ---------------------------------------------------------------------------
/// Entities
/// ---------------------------------------------------------------------------
class Player {
  Player(this.def)
      : pos = Offset.zero,
        hp = def.maxHp,
        maxHp = def.maxHp,
        mp = def.maxMp,
        maxMp = def.maxMp,
        speed = def.speed,
        damage = def.damage,
        fireInterval = def.fireInterval,
        projSpeed = def.projSpeed,
        range = def.range,
        critChance = def.critChance,
        projectiles = def.projectiles,
        lifesteal = def.lifesteal,
        splash = def.splash,
        pierce = def.pierce,
        dot = def.dot,
        thorns = def.thorns;

  final HeroDef def;
  Offset pos;
  double hp;
  double maxHp;
  double mp;
  double maxMp;
  double mpRegen = 1.0;
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

  double fireTimer = 0;
  double regen = 0;
  double hurtFlash = 0;
  double abilityTimer = 0;
  double invuln = 0;
  double frenzy = 0;

  int level = 1;
  int xp = 0;
  int xpToNext = 5;
  int kills = 0;
  int obols = 0;

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
  }) : maxHp = hp;

  Offset pos;
  double hp;
  final double maxHp;
  double speed;
  double damage;
  double radius;
  int kind; // 0 hater 1 zoomer 2 chonk 3 boss 4 spitter
  int bounty;
  double touchTimer = 0;
  double shootTimer = 1.4;
  double dotTimer = 0;
  double dotDps = 0;
  double flash = 0;
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
  EBolt(this.pos, this.vel, this.damage);
  Offset pos;
  Offset vel;
  double damage;
  double life = 4;
}

class Orb {
  Orb(this.pos);
  Offset pos;
}

class Burst {
  Burst(this.pos, this.maxR);
  Offset pos;
  double maxR;
  double t = 0;
}

class FloatText {
  FloatText(this.pos, this.text, this.color);
  Offset pos;
  String text;
  Color color;
  double life = 0.8;
}

class GameStats {
  static int bestWave = 0;
}

enum Phase { playing, levelUp, doors, shop, waveCleared, gameOver, victory }

/// ---------------------------------------------------------------------------
/// Game screen
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
  final Random _rng = Random();

  Size _size = Size.zero;
  bool _ready = false;

  late Player _p;
  final List<Enemy> _enemies = [];
  final List<Bolt> _bolts = [];
  final List<EBolt> _ebolts = [];
  final List<Orb> _orbs = [];
  final List<Burst> _bursts = [];
  final List<FloatText> _texts = [];

  Phase _phase = Phase.playing;
  int _wave = 1;
  double _waveTime = kWaveTime;
  double _spawnTimer = 0;

  bool _stickOn = false;
  Offset _stickOrigin = Offset.zero;
  Offset _stickKnob = Offset.zero;
  Offset _moveDir = Offset.zero;
  Offset _facing = const Offset(1, 0);
  double _elapsed = 0;
  static const double _stickR = 60;

  List<Upgrade> _choices = [];
  bool _boonThenNext = false;
  List<ShopItem> _shop = [];
  List<DoorDef> _doors = [];

  int get _floorIdx =>
      ((_wave - 1) ~/ kWavesPerFloor).clamp(0, kFloors.length - 1).toInt();
  FloorDef get _floor => kFloors[_floorIdx];
  bool get _bossWave => _wave % kWavesPerFloor == 0;

  Rect get _abilityRect {
    return Rect.fromLTWH(
        _size.width - 98, _size.height - 108, 78, 78);
  }

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

  void _initRun() {
    _p = Player(widget.def);
    _p.pos = Offset(_size.width / 2, _size.height / 2);
    _enemies.clear();
    _bolts.clear();
    _ebolts.clear();
    _orbs.clear();
    _bursts.clear();
    _texts.clear();
    _wave = 1;
    _waveTime = kWaveTime;
    _spawnTimer = 0;
    _boonThenNext = false;
    _phase = Phase.playing;
    _ready = true;
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
    if (_phase == Phase.playing) _update(dt);
    setState(() {});
  }

  void _update(double dt) {
    final w = _size.width;
    final h = _size.height;

    if (_moveDir != Offset.zero) {
      final next = _p.pos + _moveDir * _p.speed * dt;
      _p.pos = Offset(
        next.dx.clamp(_p.radius, w - _p.radius).toDouble(),
        next.dy.clamp(_p.radius + 70, h - _p.radius - 12).toDouble(),
      );
      _facing = _moveDir;
    }
    if (_p.hurtFlash > 0) _p.hurtFlash -= dt;
    if (_p.invuln > 0) _p.invuln -= dt;
    if (_p.frenzy > 0) _p.frenzy -= dt;
    if (_p.abilityTimer > 0) _p.abilityTimer -= dt;
    if (_p.regen > 0) {
      _p.hp = (_p.hp + _p.regen * dt).clamp(0, _p.maxHp).toDouble();
    }
    _p.mp = (_p.mp + _p.mpRegen * dt).clamp(0, _p.maxMp).toDouble();

    for (final b in _bursts) {
      b.t += dt;
    }
    _bursts.removeWhere((b) => b.t > 0.35);

    _waveTime -= dt;
    if (_waveTime <= 0) {
      _enemies.clear();
      _ebolts.clear();
      _onWaveCleared();
      return;
    }

    _spawnTimer -= dt;
    if (_spawnTimer <= 0) {
      _spawnEnemy();
      final base = 1.45 - _wave * 0.035;
      _spawnTimer = base.clamp(0.30, 1.45).toDouble();
    }

    _p.fireTimer -= dt;
    if (_p.fireTimer <= 0) {
      final target = _nearestEnemy(_p.range);
      if (target != null) {
        _fireAt((target.pos - _p.pos));
        _p.fireTimer = _p.effFire;
      }
    }

    for (final b in _bolts) {
      b.pos += b.vel * dt;
      b.life -= dt;
    }
    _bolts.removeWhere((b) =>
        b.life <= 0 ||
        b.pos.dx < -30 ||
        b.pos.dx > w + 30 ||
        b.pos.dy < -30 ||
        b.pos.dy > h + 30);

    for (final e in _ebolts) {
      e.pos += e.vel * dt;
      e.life -= dt;
      if ((e.pos - _p.pos).distance < _p.radius + 5) {
        _hurtPlayer(e.damage);
        e.life = 0;
        if (_phase != Phase.playing) return;
      }
    }
    _ebolts.removeWhere((e) =>
        e.life <= 0 ||
        e.pos.dx < -30 ||
        e.pos.dx > w + 30 ||
        e.pos.dy < -30 ||
        e.pos.dy > h + 30);

    for (final e in _enemies) {
      final dir = _p.pos - e.pos;
      final d = dir.distance;

      if (e.kind == 4) {
        if (d < 220 && d > 0.01) {
          e.pos -= dir / d * e.speed * dt;
        } else if (d > 300) {
          e.pos += dir / d * e.speed * dt;
        }
        e.shootTimer -= dt;
        if (e.shootTimer <= 0 && d < 420 && d > 0.01) {
          e.shootTimer = 1.7;
          _ebolts.add(EBolt(e.pos, dir / d * 220, e.damage));
        }
      } else if (d > 0.01) {
        e.pos += dir / d * e.speed * dt;
      }

      if (e.dotTimer > 0) {
        e.dotTimer -= dt;
        e.hp -= e.dotDps * dt;
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
        _hurtPlayer(e.damage);
        if (_phase != Phase.playing) return;
      }
    }

    for (final b in _bolts) {
      if (b.life <= 0) continue;
      for (final e in _enemies) {
        if (b.hit.contains(e)) continue;
        if ((b.pos - e.pos).distance < e.radius + 5) {
          _damageEnemy(e, b.damage, b.crit);
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
        _orbs.add(Orb(e.pos));
        _p.obols += e.bounty;
        _p.mp = (_p.mp + 0.8).clamp(0, _p.maxMp).toDouble();
        if (_p.lifesteal > 0) {
          _p.hp = (_p.hp + _p.lifesteal).clamp(0, _p.maxHp).toDouble();
        }
        _p.kills++;
        return true;
      }
      return false;
    });

    for (final o in _orbs) {
      final dir = _p.pos - o.pos;
      final d = dir.distance;
      if (d < 120 && d > 0.01) o.pos += dir / d * 250 * dt;
    }
    _orbs.removeWhere((o) {
      if ((o.pos - _p.pos).distance < _p.radius + 8) {
        _gainXp();
        return true;
      }
      return false;
    });

    for (final t in _texts) {
      t.pos = t.pos.translate(0, -34 * dt);
      t.life -= dt;
    }
    _texts.removeWhere((t) => t.life <= 0);
  }

  void _hurtPlayer(double dmg) {
    if (_p.invuln > 0) return;
    _p.hp -= dmg;
    _p.hurtFlash = 0.25;
    if (_p.hp <= 0) {
      _p.hp = 0;
      _gameOver();
    }
  }

  void _damageEnemy(Enemy e, double dmg, bool crit) {
    e.hp -= dmg;
    e.flash = 0.1;
    _texts.add(FloatText(
      e.pos.translate(0, -e.radius),
      crit ? '${dmg.toInt()}!' : '${dmg.toInt()}',
      crit ? const Color(0xFFFFE066) : Colors.white,
    ));
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

  void _fireAt(Offset aim) {
    final baseAng = atan2(aim.dy, aim.dx);
    final n = _p.projectiles;
    final spread = n > 1 ? 0.16 : 0.0;
    for (var i = 0; i < n; i++) {
      final off = (i - (n - 1) / 2) * spread;
      final ang = baseAng + off;
      final crit = _rng.nextDouble() < _p.critChance;
      final dmg = _p.damage * (crit ? 2 : 1);
      _bolts.add(Bolt(
        _p.pos,
        Offset(cos(ang), sin(ang)) * _p.projSpeed,
        dmg,
        crit,
        _p.pierce,
        _p.splash,
        _p.dot,
      ));
    }
  }

  bool get _canCast =>
      _phase == Phase.playing &&
      _p.abilityTimer <= 0 &&
      _p.mp >= widget.def.abilityCost;

  void _castAbility() {
    if (!_canCast) return;
    _p.mp -= widget.def.abilityCost;
    _p.abilityTimer = widget.def.abilityCd;
    final d = _p.damage;
    switch (widget.def.cls) {
      case HeroClass.tank:
        {
          _bursts.add(Burst(_p.pos, 150));
          for (final e in _enemies) {
            final v = e.pos - _p.pos;
            if (v.distance < 150) {
              _damageEnemy(e, d * 4, true);
              if (v.distance > 0.01) e.pos += v / v.distance * 70;
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
          final tgt = _nearestEnemy(900);
          final at = tgt?.pos ?? _p.pos;
          _bursts.add(Burst(at, 130));
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
          final tgt = _nearestEnemy(900);
          if (tgt != null) _p.pos = tgt.pos;
          _p.invuln = 1.0;
          _bursts.add(Burst(_p.pos, 70));
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

  void _spawnEnemy() {
    final w = _size.width;
    final h = _size.height;
    Offset p;
    switch (_rng.nextInt(4)) {
      case 0:
        p = Offset(_rng.nextDouble() * w, -24);
        break;
      case 1:
        p = Offset(_rng.nextDouble() * w, h + 24);
        break;
      case 2:
        p = Offset(-24, _rng.nextDouble() * h);
        break;
      default:
        p = Offset(w + 24, _rng.nextDouble() * h);
    }

    final f = _floor;
    final ws = 1 + _wave * 0.05;

    if (_bossWave && _enemies.where((e) => e.kind == 3).isEmpty) {
      _enemies.add(Enemy(
        pos: p,
        hp: (26 + _wave * 5) * f.hpMul,
        speed: (44 + _wave * 1.2) * f.spdMul,
        damage: 2.5 * f.dmgMul,
        radius: 36,
        kind: 3,
        bounty: 25,
      ));
      return;
    }

    final roll = _rng.nextDouble();
    if (_floorIdx >= 2 && roll < 0.16) {
      _enemies.add(Enemy(
        pos: p,
        hp: (6 + _wave * 0.7) * f.hpMul,
        speed: (70 + _wave * 0.6) * f.spdMul,
        damage: 1.0 * f.dmgMul,
        radius: 14,
        kind: 4,
        bounty: 2,
      ));
    } else if (roll < 0.30 + _floorIdx * 0.02) {
      _enemies.add(Enemy(
        pos: p,
        hp: (2 + _wave * 0.35) * f.hpMul * ws,
        speed: (120 + _wave * 1.6) * f.spdMul,
        damage: 1.0 * f.dmgMul,
        radius: 11,
        kind: 1,
        bounty: 1,
      ));
    } else if (roll < 0.44) {
      _enemies.add(Enemy(
        pos: p,
        hp: (9 + _wave * 1.4) * f.hpMul * ws,
        speed: (46 + _wave * 0.7) * f.spdMul,
        damage: 2.0 * f.dmgMul,
        radius: 23,
        kind: 2,
        bounty: 3,
      ));
    } else {
      _enemies.add(Enemy(
        pos: p,
        hp: (3 + _wave * 0.8) * f.hpMul * ws,
        speed: (66 + _wave * 1.1) * f.spdMul,
        damage: 1.0 * f.dmgMul,
        radius: 15,
        kind: 0,
        bounty: 1,
      ));
    }
  }

  void _gainXp() {
    _p.xp++;
    if (_p.xp >= _p.xpToNext) {
      _p.xp -= _p.xpToNext;
      _p.level++;
      _p.xpToNext = 5 + _p.level * 3;
      _openBoon();
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
    _texts.add(FloatText(_p.pos.translate(0, -_p.radius - 14), u.title,
        const Color(0xFF8CFF98)));
    if (_p.xp >= _p.xpToNext) {
      _p.xp -= _p.xpToNext;
      _p.level++;
      _p.xpToNext = 5 + _p.level * 3;
      setState(_openBoon);
    } else if (_boonThenNext) {
      _boonThenNext = false;
      _nextWave();
    } else {
      setState(() => _phase = Phase.playing);
    }
  }

  void _onWaveCleared() {
    _p.obols += 3 + _wave * 2;
    if (_wave >= kMaxWaves) {
      if (_wave > GameStats.bestWave) GameStats.bestWave = _wave;
      _phase = Phase.victory;
      return;
    }
    if (_wave - 1 > GameStats.bestWave) GameStats.bestWave = _wave - 1;
    if (_bossWave) {
      _shop = _rollShop();
      _phase = Phase.shop;
    } else {
      _doors = _rollDoors();
      _phase = Phase.doors;
    }
  }

  void _nextWave() {
    _wave++;
    _waveTime = kWaveTime;
    _spawnTimer = 0;
    _p.hp = (_p.hp + _p.maxHp * 0.15).clamp(0, _p.maxHp).toDouble();
    setState(() => _phase = Phase.playing);
  }

  // ---- shop ----
  List<ShopItem> _rollShop() {
    final mul = 1 + _floorIdx * 0.6;
    int price(num base) => (base * mul).round();
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
          (p) => p.fireInterval = (p.fireInterval * 0.85).toDouble()),
      ShopItem('+6% CRIT', 'more big hits', price(14),
          (p) => p.critChance += 0.06),
      ShopItem('+0.6 MP REGEN', 'cast more often', price(17),
          (p) => p.mpRegen += 0.6),
      ShopItem('+0.3 LIFESTEAL', 'heal on kill', price(18),
          (p) => p.lifesteal += 0.3),
    ]..shuffle(_rng);
    return all.take(6).toList();
  }

  void _buy(ShopItem item) {
    if (item.sold || _p.obols < item.price) return;
    _p.obols -= item.price;
    item.apply(_p);
    setState(() => item.sold = true);
  }

  // ---- doors (Hades-style reward choice) ----
  List<DoorDef> _rollDoors() {
    final pool = <DoorDef>[
      DoorDef('💰', 'TREASURE', '+${10 + _floorIdx * 8} obols',
          (p) => p.obols += 10 + _floorIdx * 8),
      DoorDef('❤', 'FOUNTAIN', 'heal 40% HP + 50% MP', (p) {
        p.hp = (p.hp + p.maxHp * 0.4).clamp(0, p.maxHp).toDouble();
        p.mp = (p.mp + p.maxMp * 0.5).clamp(0, p.maxMp).toDouble();
      }),
      DoorDef('✦', 'BOON', 'pick a power-up', (_) {}),
      DoorDef('🗡', 'ARSENAL', '+1 projectile',
          (p) => p.projectiles = (p.projectiles + 1).clamp(1, 8).toInt()),
      DoorDef('⚡', 'OVERCHARGE', '+0.5 MP regen',
          (p) => p.mpRegen += 0.5),
    ]..shuffle(_rng);
    return pool.take(2).toList();
  }

  void _pickDoor(DoorDef door) {
    if (door.title == 'BOON') {
      _boonThenNext = true;
      setState(_openBoon);
      return;
    }
    door.apply(_p);
    _nextWave();
  }

  // ---- input ----
  void _panStart(DragStartDetails d) {
    if (_phase != Phase.playing) return;
    if (_abilityRect.contains(d.localPosition)) return;
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
    _moveDir = delta / _stickR;
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
          return GestureDetector(
            onPanStart: _panStart,
            onPanUpdate: _panUpdate,
            onPanEnd: _panEnd,
            child: Stack(
              children: [
                Positioned.fill(
                  child: CustomPaint(
                    painter: WorldPainter(
                      player: _p,
                      enemies: _enemies,
                      bolts: _bolts,
                      ebolts: _ebolts,
                      orbs: _orbs,
                      bursts: _bursts,
                      texts: _texts,
                      floor: _floor,
                      time: _elapsed,
                      facing: _facing,
                      moving: _moveDir != Offset.zero,
                      stickOn: _stickOn,
                      stickOrigin: _stickOrigin,
                      stickKnob: _stickKnob,
                      ready: _ready,
                    ),
                  ),
                ),
                if (_ready) _hud(),
                if (_ready && _phase == Phase.playing) _abilityButton(),
                if (_phase == Phase.levelUp) _levelUpOverlay(),
                if (_phase == Phase.doors) _doorsOverlay(),
                if (_phase == Phase.shop) _shopOverlay(),
                if (_phase == Phase.gameOver) _endOverlay(false),
                if (_phase == Phase.victory) _endOverlay(true),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _abilityButton() {
    final ready = _canCast;
    final cdFrac = (_p.abilityTimer / widget.def.abilityCd).clamp(0.0, 1.0);
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
            color: ready
                ? const Color(0xFF2A5BD7)
                : const Color(0xFF24242F),
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
                cdFrac > 0
                    ? '${(_p.abilityTimer).toStringAsFixed(1)}s'
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

  Widget _hud() {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Flexible(
                    child: Text(
                      'F${_floorIdx + 1} ${_floor.name}',
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 12,
                          color: Color(0xFFFFD45E)),
                    ),
                  ),
                  Text('W$_wave/$kMaxWaves',
                      style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 12,
                          color: Colors.white70)),
                  Text('⏱${_waveTime.ceil()}',
                      style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 12,
                          color: Colors.white)),
                  Text('💰${_p.obols}',
                      style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 12,
                          color: Color(0xFFFFD45E))),
                  Text('LV${_p.level}',
                      style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 12,
                          color: Color(0xFF8CC8FF))),
                ],
              ),
              const SizedBox(height: 5),
              _bar(_p.hp / _p.maxHp, const Color(0xFFFF5C6C),
                  'HP ${_p.hp.ceil()}/${_p.maxHp.toInt()}'),
              const SizedBox(height: 3),
              _bar(_p.mp / _p.maxMp, const Color(0xFF3F8BFF),
                  'MP ${_p.mp.floor()}/${_p.maxMp.toInt()}', h: 12),
              const SizedBox(height: 3),
              _bar(_p.xp / _p.xpToNext, const Color(0xFF8CFF98), null,
                  h: 6),
            ],
          ),
        ),
      ),
    );
  }

  Widget _bar(double v, Color color, String? label, {double h = 18}) {
    return Stack(
      alignment: Alignment.center,
      children: [
        Container(
          height: h,
          decoration: BoxDecoration(
            color: Colors.black38,
            borderRadius: BorderRadius.circular(10),
          ),
          child: FractionallySizedBox(
            alignment: Alignment.centerLeft,
            widthFactor: v.clamp(0.0, 1.0).toDouble(),
            child: Container(
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
        ),
        if (label != null)
          Text(label,
              style: const TextStyle(
                  fontSize: 10,
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

  Widget _doorsOverlay() {
    return _scrim(Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('WAVE $_wave CLEARED',
            style: const TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w900,
                color: Color(0xFFFFD45E))),
        const SizedBox(height: 4),
        const Text('choose your door', style: TextStyle(color: Colors.white60)),
        const SizedBox(height: 20),
        for (final dr in _doors)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: () => _pickDoor(dr),
              child: Container(
                width: 320,
                padding: const EdgeInsets.symmetric(
                    horizontal: 18, vertical: 16),
                decoration: BoxDecoration(
                  color: const Color(0xFF1F1D2E),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                      color: const Color(0xFFFFD45E), width: 1.5),
                ),
                child: Row(
                  children: [
                    Text(dr.icon, style: const TextStyle(fontSize: 30)),
                    const SizedBox(width: 16),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(dr.title,
                            style: const TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w900,
                                color: Color(0xFFFFD45E))),
                        Text(dr.desc,
                            style: const TextStyle(
                                color: Colors.white60, fontSize: 12)),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    ));
  }

  Widget _shopOverlay() {
    return _scrim(Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text('CHARON\'S SHOP',
            style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w900,
                color: Color(0xFFFFD45E))),
        const SizedBox(height: 2),
        Text('floor cleared · 💰 ${_p.obols}',
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
          label: _wave >= kMaxWaves ? 'FINISH' : 'LEAVE SHOP',
          color: const Color(0xFF8CC8FF),
          onTap: _nextWave,
        ),
      ],
    ));
  }

  Widget _endOverlay(bool win) {
    return _scrim(Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(win ? 'YOU CLEARED THE VOID!' : 'GET REKT',
            textAlign: TextAlign.center,
            style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.w900,
                color:
                    win ? const Color(0xFF8CFF98) : const Color(0xFFFF5C6C))),
        const SizedBox(height: 10),
        Text(
          'floor ${_floorIdx + 1} · wave $_wave · '
          'lv ${_p.level} · ${_p.kills} kills',
          style: const TextStyle(color: Colors.white70),
        ),
        const SizedBox(height: 4),
        Text('best: wave ${GameStats.bestWave}',
            style: const TextStyle(color: Colors.white38)),
        const SizedBox(height: 22),
        _BigButton(
          label: 'PLAY AGAIN',
          color: const Color(0xFFFFD45E),
          onTap: () => setState(_initRun),
        ),
        const SizedBox(height: 12),
        _BigButton(
          label: 'CHANGE CLASS',
          color: const Color(0xFF8CC8FF),
          onTap: () => Navigator.of(context).pushReplacement(
            MaterialPageRoute<void>(
                builder: (_) => const CharacterSelectScreen()),
          ),
        ),
      ],
    ));
  }
}

/// ---------------------------------------------------------------------------
/// Upgrades / Shop / Doors
/// ---------------------------------------------------------------------------
class Upgrade {
  const Upgrade(this.title, this.desc, this.tier, this.apply);
  final String title;
  final String desc;
  final int tier; // 0 common 1 rare 2 epic
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
  Upgrade('MULTI BONK', '+1 projectile', 2,
      (p) => p.projectiles = (p.projectiles + 1).clamp(1, 8).toInt()),
  Upgrade('BIG BOOM', '+24 splash radius', 2, (p) => p.splash += 24),
  Upgrade('PIERCING', '+2 pierce', 2,
      (p) => p.pierce = (p.pierce + 2).clamp(0, 12).toInt()),
];

class ShopItem {
  ShopItem(this.title, this.desc, this.price, this.apply);
  final String title;
  final String desc;
  final int price;
  final void Function(Player p) apply;
  bool sold = false;
}

class DoorDef {
  DoorDef(this.icon, this.title, this.desc, this.apply);
  final String icon;
  final String title;
  final String desc;
  final void Function(Player p) apply;
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
        padding: const EdgeInsets.symmetric(horizontal: 44, vertical: 16),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Text(
          label,
          style: const TextStyle(
            color: Color(0xFF14131F),
            fontWeight: FontWeight.w900,
            fontSize: 18,
            letterSpacing: 1,
          ),
        ),
      ),
    );
  }
}

/// ---------------------------------------------------------------------------
/// Rendering
/// ---------------------------------------------------------------------------
Color _lit(Color c, double a) => Color.lerp(c, Colors.white, a)!;
Color _shd(Color c, double a) => Color.lerp(c, Colors.black, a)!;

void _drawHero(Canvas canvas, Offset base, double r, HeroDef def, int stage,
    {double t = 0, bool moving = false, Offset look = Offset.zero}) {
  // ground shadow
  canvas.drawOval(
    Rect.fromCenter(
        center: base.translate(0, r * 1.0),
        width: r * 1.9,
        height: r * 0.55),
    Paint()..color = const Color(0x44000000),
  );

  // feet (alternate while moving)
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

  // body bob
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
      canvas.drawCircle(
          c.translate(r * 0.95, -r * 0.15), r * 0.16, Paint()..color = _lit(def.accent, 0.5));
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
      canvas.drawPath(
          hat,
          Paint()
            ..color = _shd(def.accent, 0.4)
            ..style = PaintingStyle.stroke
            ..strokeWidth = r * 0.06);
      final glow = 0.5 + 0.5 * sin(t * 4);
      canvas.drawCircle(c.translate(r * 0.12, -r * 2.05), r * 0.16,
          Paint()..color = const Color(0xFFFFE066));
      canvas.drawCircle(
          c.translate(r * 0.12, -r * 2.05),
          r * 0.28,
          Paint()
            ..color = const Color(0xFFFFE066)
                .withValues(alpha: 0.35 * glow));
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
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
              center: c.translate(0, -r * 1.18),
              width: r * 1.0,
              height: r * 0.4),
          Radius.circular(r * 0.1),
        ),
        Paint()..color = _lit(def.accent, 0.3),
      );
      _ears(canvas, c, r, accent);
      break;
  }

  // eyes
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

class WorldPainter extends CustomPainter {
  WorldPainter({
    required this.player,
    required this.enemies,
    required this.bolts,
    required this.ebolts,
    required this.orbs,
    required this.bursts,
    required this.texts,
    required this.floor,
    required this.time,
    required this.facing,
    required this.moving,
    required this.stickOn,
    required this.stickOrigin,
    required this.stickKnob,
    required this.ready,
  });

  final Player player;
  final List<Enemy> enemies;
  final List<Bolt> bolts;
  final List<EBolt> ebolts;
  final List<Orb> orbs;
  final List<Burst> bursts;
  final List<FloatText> texts;
  final FloorDef floor;
  final double time;
  final Offset facing;
  final bool moving;
  final bool stickOn;
  final Offset stickOrigin;
  final Offset stickKnob;
  final bool ready;

  @override
  void paint(Canvas canvas, Size size) {
    final full = Offset.zero & size;
    canvas.drawRect(
      full,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [_lit(floor.bg, 0.05), floor.bg, _shd(floor.bg, 0.28)],
          stops: const [0.0, 0.5, 1.0],
        ).createShader(full),
    );

    final grid = Paint()
      ..color = floor.grid.withValues(alpha: 0.5)
      ..strokeWidth = 1;
    for (double x = 0; x < size.width; x += 46) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), grid);
    }
    for (double y = 0; y < size.height; y += 46) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
    }
    if (!ready) return;

    // ambient drifting particles
    final w = size.width, h = size.height;
    final pp = Paint()..color = _lit(floor.grid, 0.3).withValues(alpha: 0.3);
    for (var i = 0; i < 26; i++) {
      final px = (i * 6311 % w.toInt()).toDouble();
      final drift = time * (12 + (i % 5) * 5);
      var py = (h - (i * 4127 % h.toInt()).toDouble() - drift) % h;
      if (py < 0) py += h;
      canvas.drawCircle(Offset(px, py), 1.4 + (i % 3), pp);
    }

    // vignette
    canvas.drawRect(
      full,
      Paint()
        ..shader = RadialGradient(
          radius: 0.95,
          colors: const [Color(0x00000000), Color(0x80000000)],
          stops: const [0.62, 1.0],
        ).createShader(full),
    );

    // bursts (filled fade + expanding ring)
    for (final b in bursts) {
      final double f = (b.t / 0.35).clamp(0.0, 1.0).toDouble();
      canvas.drawCircle(b.pos, b.maxR * f,
          Paint()..color = const Color(0xFFFF9A3C).withValues(alpha: (1 - f) * 0.22));
      canvas.drawCircle(
        b.pos,
        b.maxR * f,
        Paint()
          ..color = const Color(0xFFFFD45E).withValues(alpha: (1 - f) * 0.7)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 4,
      );
    }

    // xp orbs (glow + pulsing core)
    for (final o in orbs) {
      final pul = 0.5 + 0.5 * sin(time * 6 + o.pos.dx);
      canvas.drawCircle(o.pos, 10,
          Paint()..color = const Color(0xFF8CFF98).withValues(alpha: 0.22));
      canvas.drawCircle(o.pos, 4 + pul * 1.6,
          Paint()..color = const Color(0xFFB6FFC0));
    }

    for (final e in enemies) {
      final base = switch (e.kind) {
        1 => const Color(0xFFFF8A4C),
        2 => const Color(0xFF9B5CFF),
        3 => const Color(0xFFFF3B5C),
        4 => const Color(0xFF4CD2C0),
        _ => floor.mob,
      };
      // shadow
      canvas.drawOval(
        Rect.fromCenter(
            center: e.pos.translate(0, e.radius * 0.9),
            width: e.radius * 1.9,
            height: e.radius * 0.6),
        Paint()..color = const Color(0x3C000000),
      );

      if (e.kind == 3) {
        final aura = 0.5 + 0.5 * sin(time * 5);
        canvas.drawCircle(
            e.pos,
            e.radius + 6 + aura * 4,
            Paint()
              ..color = base.withValues(alpha: 0.25)
              ..style = PaintingStyle.stroke
              ..strokeWidth = 3);
      }
      if (e.kind == 4) {
        canvas.drawCircle(e.pos, e.radius + 5,
            Paint()..color = base.withValues(alpha: 0.2));
      }

      final wob = e.kind == 1 ? sin(time * 18 + e.pos.dx) * e.radius * 0.12 : 0.0;
      canvas.drawCircle(
        e.pos,
        e.radius,
        Paint()
          ..shader = RadialGradient(
            center: const Alignment(-0.4, -0.5),
            colors: [_lit(base, 0.4), base, _shd(base, 0.4)],
            stops: const [0.0, 0.55, 1.0],
          ).createShader(
              Rect.fromCircle(center: e.pos, radius: e.radius + wob)),
      );
      canvas.drawCircle(
          e.pos,
          e.radius,
          Paint()
            ..color = _shd(base, 0.5)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.6);

      if (e.kind == 2) {
        canvas.drawCircle(e.pos.translate(-e.radius * 0.35, e.radius * 0.2),
            e.radius * 0.22, Paint()..color = _shd(base, 0.35));
        canvas.drawCircle(e.pos.translate(e.radius * 0.4, e.radius * 0.05),
            e.radius * 0.18, Paint()..color = _shd(base, 0.35));
      }
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
      if (e.kind == 4) {
        final dir = (player.pos - e.pos);
        final dl = dir.distance;
        if (dl > 0.01) {
          final n = dir / dl;
          canvas.drawCircle(e.pos + n * e.radius * 0.9, e.radius * 0.32,
              Paint()..color = _shd(base, 0.45));
        }
      }

      // angry brows + eyes
      final brow = Paint()
        ..color = Colors.black
        ..strokeWidth = e.radius * 0.12
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(
          e.pos.translate(-e.radius * 0.5, -e.radius * 0.32),
          e.pos.translate(-e.radius * 0.15, -e.radius * 0.16),
          brow);
      canvas.drawLine(
          e.pos.translate(e.radius * 0.5, -e.radius * 0.32),
          e.pos.translate(e.radius * 0.15, -e.radius * 0.16),
          brow);
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

      if (e.kind == 2 || e.kind == 3 || e.kind == 4) {
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
      }
    }

    for (final b in bolts) {
      final col = b.crit
          ? const Color(0xFFFFE066)
          : (b.splash > 0 ? const Color(0xFFFF9A3C) : Colors.white);
      final cr = b.splash > 0 ? 7.0 : (b.crit ? 6.0 : 4.0);
      canvas.drawCircle(
          b.pos, cr + 4, Paint()..color = col.withValues(alpha: 0.3));
      canvas.drawCircle(b.pos, cr, Paint()..color = col);
    }
    for (final e in ebolts) {
      canvas.drawCircle(e.pos, 9,
          Paint()..color = const Color(0xFFFF4D5E).withValues(alpha: 0.3));
      canvas.drawCircle(e.pos, 4.5, Paint()..color = const Color(0xFFFF6B79));
    }

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
    _drawHero(canvas, player.pos, player.radius, player.def, player.buffStage,
        t: time, moving: moving, look: facing);

    for (final t in texts) {
      final a = t.life.clamp(0.0, 1.0).toDouble();
      void draw(Color col, Offset at) {
        final tp = TextPainter(
          text: TextSpan(
            text: t.text,
            style: TextStyle(
              color: col.withValues(alpha: a),
              fontSize: 14,
              fontWeight: FontWeight.w900,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        tp.paint(canvas, at - Offset(tp.width / 2, tp.height / 2));
      }

      draw(Colors.black, t.pos.translate(1.4, 1.4));
      draw(t.color, t.pos);
    }

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
      canvas.drawCircle(
          stickKnob,
          26,
          Paint()
            ..color = Colors.white54
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2);
    }
  }

  @override
  bool shouldRepaint(covariant WorldPainter old) => true;
}

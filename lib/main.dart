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
    speed: 118,
    damage: 1.5,
    fireInterval: 0.70,
    projSpeed: 300,
    range: 240,
    critChance: 0.03,
    thorns: 1.5,
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
  ),
  HeroDef(
    cls: HeroClass.mage,
    name: 'WIZARD CAT',
    role: 'MAGE',
    tagline: 'Big slow bonk. Big boom.',
    body: Color(0xFF8C6CFF),
    accent: Color(0xFF3E2E80),
    maxHp: 6,
    speed: 138,
    damage: 2.4,
    fireInterval: 0.88,
    projSpeed: 300,
    range: 320,
    splash: 48,
  ),
  HeroDef(
    cls: HeroClass.warlock,
    name: 'DOOM PUG',
    role: 'WARLOCK',
    tagline: 'They rot. You heal. Wow.',
    body: Color(0xFFB05CCB),
    accent: Color(0xFF4F2358),
    maxHp: 7,
    speed: 146,
    damage: 0.9,
    fireInterval: 0.50,
    projSpeed: 340,
    range: 300,
    dot: 2.5,
    lifesteal: 0.3,
  ),
  HeroDef(
    cls: HeroClass.assassin,
    name: 'NINJA SHIBA',
    role: 'ASSASSIN',
    tagline: 'Blink and you are dead. So fast.',
    body: Color(0xFF44485A),
    accent: Color(0xFFE0436B),
    maxHp: 5,
    speed: 204,
    damage: 1.6,
    fireInterval: 0.30,
    projSpeed: 480,
    range: 220,
    critChance: 0.25,
  ),
  HeroDef(
    cls: HeroClass.gunner,
    name: 'GANGSTA RAT',
    role: 'GUNNER',
    tagline: 'Brrrrt. Many small bonk.',
    body: Color(0xFFD9A24A),
    accent: Color(0xFF7A521C),
    maxHp: 7,
    speed: 150,
    damage: 0.8,
    fireInterval: 0.16,
    projSpeed: 520,
    range: 300,
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
              'pick a class · clear the floors · get swole',
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
              width: 84,
              height: 84,
              child: CustomPaint(painter: HeroPreviewPainter(def: def)),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Text(
                        def.name,
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                          color: def.body,
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
                  Text(
                    def.tagline,
                    style:
                        const TextStyle(color: Colors.white54, fontSize: 11),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'HP ${def.maxHp.toInt()}  SPD ${def.speed.toInt()}  '
                    'DMG ${def.damage}  ROF '
                    '${(1 / def.fireInterval).toStringAsFixed(1)}/s',
                    style:
                        const TextStyle(color: Colors.white38, fontSize: 10),
                  ),
                  Text(
                    _perk(def),
                    style: TextStyle(
                        color: def.body, fontSize: 10, height: 1.4),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _perk(HeroDef d) {
    final p = <String>[];
    if (d.thorns > 0) p.add('THORNS ${d.thorns}');
    if (d.pierce > 0) p.add('PIERCE ${d.pierce}');
    if (d.splash > 0) p.add('SPLASH');
    if (d.dot > 0) p.add('POISON');
    if (d.lifesteal > 0) p.add('LIFESTEAL');
    if (d.critChance >= 0.2) p.add('HIGH CRIT');
    if (d.projectiles > 1) p.add('${d.projectiles}x SHOT');
    return p.isEmpty ? 'BALANCED' : p.join(' · ');
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

  int level = 1;
  int xp = 0;
  int xpToNext = 5;
  int kills = 0;

  int get buffStage => (level - 1) ~/ 3 < 3 ? (level - 1) ~/ 3 : 3;
  double get radius => 16 + buffStage * 3.0;
}

class Enemy {
  Enemy({
    required this.pos,
    required this.hp,
    required this.speed,
    required this.damage,
    required this.radius,
    required this.kind,
  }) : maxHp = hp;

  Offset pos;
  double hp;
  final double maxHp;
  double speed;
  double damage;
  double radius;
  int kind; // 0 hater 1 zoomer 2 chonk 3 boss 4 spitter
  double touchTimer = 0;
  double shootTimer = 1.4;
  double dotTimer = 0;
  double dotDps = 0;
}

class Bolt {
  Bolt(this.pos, this.vel, this.damage, this.crit,
      this.pierce, this.splash, this.dot);
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

enum Phase { playing, levelUp, waveCleared, gameOver, victory }

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
  final List<FloatText> _texts = [];

  Phase _phase = Phase.playing;
  int _wave = 1;
  double _waveTime = kWaveTime;
  double _spawnTimer = 0;

  bool _stickOn = false;
  Offset _stickOrigin = Offset.zero;
  Offset _stickKnob = Offset.zero;
  Offset _moveDir = Offset.zero;
  static const double _stickR = 60;

  List<Upgrade> _choices = [];

  int get _floorIdx =>
      ((_wave - 1) ~/ kWavesPerFloor).clamp(0, kFloors.length - 1).toInt();
  FloorDef get _floor => kFloors[_floorIdx];

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
    _texts.clear();
    _wave = 1;
    _waveTime = kWaveTime;
    _spawnTimer = 0;
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
    }
    if (_p.hurtFlash > 0) _p.hurtFlash -= dt;
    if (_p.regen > 0) {
      _p.hp = (_p.hp + _p.regen * dt).clamp(0, _p.maxHp).toDouble();
    }

    _waveTime -= dt;
    if (_waveTime <= 0) {
      _enemies.clear();
      _ebolts.clear();
      _phase = Phase.waveCleared;
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
      final target = _nearestEnemy();
      if (target != null) {
        _fire(target);
        _p.fireTimer = _p.fireInterval;
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
        // spitter keeps distance and shoots
        if (d < 220) {
          e.pos -= dir / d * e.speed * dt;
        } else if (d > 300) {
          e.pos += dir / d * e.speed * dt;
        }
        e.shootTimer -= dt;
        if (e.shootTimer <= 0 && d < 420) {
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
            for (final o in _enemies) {
              if (o == e) continue;
              if ((o.pos - b.pos).distance < b.splash) {
                _damageEnemy(o, b.damage * 0.6, false);
              }
            }
            _texts.add(FloatText(
                b.pos, 'BOOM', const Color(0xFFFF9A3C)));
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
      if (d < 120) o.pos += dir / d * 250 * dt;
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
    _p.hp -= dmg;
    _p.hurtFlash = 0.25;
    if (_p.hp <= 0) {
      _p.hp = 0;
      _gameOver();
    }
  }

  void _damageEnemy(Enemy e, double dmg, bool crit) {
    e.hp -= dmg;
    _texts.add(FloatText(
      e.pos.translate(0, -e.radius),
      crit ? '${dmg.toInt()}!' : '${dmg.toInt()}',
      crit ? const Color(0xFFFFE066) : Colors.white,
    ));
  }

  Enemy? _nearestEnemy() {
    Enemy? best;
    double bd = _p.range * _p.range;
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

  void _fire(Enemy target) {
    final base = target.pos - _p.pos;
    final baseAng = atan2(base.dy, base.dx);
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

    if (_wave % kWavesPerFloor == 0 &&
        _enemies.where((e) => e.kind == 3).isEmpty) {
      _enemies.add(Enemy(
        pos: p,
        hp: (26 + _wave * 5) * f.hpMul,
        speed: (44 + _wave * 1.2) * f.spdMul,
        damage: 2.5 * f.dmgMul,
        radius: 36,
        kind: 3,
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
      ));
    } else if (roll < 0.30 + _floorIdx * 0.02) {
      _enemies.add(Enemy(
        pos: p,
        hp: (2 + _wave * 0.35) * f.hpMul * ws,
        speed: (120 + _wave * 1.6) * f.spdMul,
        damage: 1.0 * f.dmgMul,
        radius: 11,
        kind: 1,
      ));
    } else if (roll < 0.44) {
      _enemies.add(Enemy(
        pos: p,
        hp: (9 + _wave * 1.4) * f.hpMul * ws,
        speed: (46 + _wave * 0.7) * f.spdMul,
        damage: 2.0 * f.dmgMul,
        radius: 23,
        kind: 2,
      ));
    } else {
      _enemies.add(Enemy(
        pos: p,
        hp: (3 + _wave * 0.8) * f.hpMul * ws,
        speed: (66 + _wave * 1.1) * f.spdMul,
        damage: 1.0 * f.dmgMul,
        radius: 15,
        kind: 0,
      ));
    }
  }

  void _gainXp() {
    _p.xp++;
    if (_p.xp >= _p.xpToNext) {
      _p.xp -= _p.xpToNext;
      _p.level++;
      _p.xpToNext = 5 + _p.level * 3;
      _choices = (List<Upgrade>.from(kUpgrades)..shuffle(_rng)).take(3).toList();
      _phase = Phase.levelUp;
    }
  }

  void _pickUpgrade(Upgrade u) {
    u.apply(_p);
    _texts.add(FloatText(_p.pos.translate(0, -_p.radius - 14), u.title,
        const Color(0xFF8CFF98)));
    if (_p.xp >= _p.xpToNext) {
      _p.xp -= _p.xpToNext;
      _p.level++;
      _p.xpToNext = 5 + _p.level * 3;
      _choices =
          (List<Upgrade>.from(kUpgrades)..shuffle(_rng)).take(3).toList();
      setState(() => _phase = Phase.levelUp);
    } else {
      setState(() => _phase = Phase.playing);
    }
  }

  void _nextWave() {
    if (_wave >= kMaxWaves) {
      if (_wave > GameStats.bestWave) GameStats.bestWave = _wave;
      setState(() => _phase = Phase.victory);
      return;
    }
    _wave++;
    if (_wave - 1 > GameStats.bestWave) GameStats.bestWave = _wave - 1;
    _waveTime = kWaveTime;
    _spawnTimer = 0;
    _p.hp = (_p.hp + _p.maxHp * 0.25).clamp(0, _p.maxHp).toDouble();
    setState(() => _phase = Phase.playing);
  }

  void _gameOver() {
    if (_wave > GameStats.bestWave) GameStats.bestWave = _wave;
    _phase = Phase.gameOver;
  }

  void _panStart(DragStartDetails d) {
    if (_phase != Phase.playing) return;
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
                      texts: _texts,
                      floor: _floor,
                      stickOn: _stickOn,
                      stickOrigin: _stickOrigin,
                      stickKnob: _stickKnob,
                      ready: _ready,
                    ),
                  ),
                ),
                if (_ready) _hud(),
                if (_phase == Phase.levelUp) _levelUpOverlay(),
                if (_phase == Phase.waveCleared) _waveClearedOverlay(),
                if (_phase == Phase.gameOver) _endOverlay(false),
                if (_phase == Phase.victory) _endOverlay(true),
              ],
            ),
          );
        },
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
          padding: const EdgeInsets.fromLTRB(14, 8, 14, 0),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'F${_floorIdx + 1} · ${_floor.name}',
                    style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 13,
                        color: Color(0xFFFFD45E)),
                  ),
                  Text(
                    'W$_wave/$kMaxWaves',
                    style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 13,
                        color: Colors.white70),
                  ),
                  Text(
                    '⏱ ${_waveTime.ceil()}s',
                    style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 13,
                        color: Colors.white),
                  ),
                  Text(
                    'LV ${_p.level}',
                    style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 13,
                        color: Color(0xFF8CC8FF)),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              _bar(_p.hp / _p.maxHp, const Color(0xFFFF5C6C),
                  'HP ${_p.hp.ceil()}/${_p.maxHp.toInt()}'),
              const SizedBox(height: 4),
              _bar(_p.xp / _p.xpToNext, const Color(0xFF8CC8FF), null,
                  thin: true),
            ],
          ),
        ),
      ),
    );
  }

  Widget _bar(double v, Color color, String? label, {bool thin = false}) {
    return Stack(
      alignment: Alignment.center,
      children: [
        Container(
          height: thin ? 8 : 18,
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
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: Colors.white)),
      ],
    );
  }

  Widget _scrim(Widget child) {
    return Positioned.fill(
      child: Container(
        color: Colors.black.withValues(alpha: 0.74),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
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
                fontSize: 34,
                fontWeight: FontWeight.w900,
                color: Color(0xFF8CFF98))),
        const SizedBox(height: 4),
        const Text('get swole — pick one',
            style: TextStyle(color: Colors.white60)),
        const SizedBox(height: 20),
        for (final u in _choices)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _UpgradeCard(u: u, onTap: () => _pickUpgrade(u)),
          ),
      ],
    ));
  }

  Widget _waveClearedOverlay() {
    final bossCleared = _wave % kWavesPerFloor == 0;
    return _scrim(Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(bossCleared ? 'FLOOR CLEARED' : 'WAVE $_wave CLEARED',
            style: const TextStyle(
                fontSize: 30,
                fontWeight: FontWeight.w900,
                color: Color(0xFFFFD45E))),
        const SizedBox(height: 8),
        Text('kills: ${_p.kills}   ·   +25% HP restored',
            style: const TextStyle(color: Colors.white60)),
        if (bossCleared && _wave < kMaxWaves) ...[
          const SizedBox(height: 8),
          Text(
            'next: ${kFloors[(_floorIdx + 1).clamp(0, kFloors.length - 1).toInt()].name}',
            style: const TextStyle(
                color: Color(0xFFFF8A4C), fontWeight: FontWeight.bold),
          ),
        ],
        const SizedBox(height: 24),
        _BigButton(
          label: _wave >= kMaxWaves ? 'FINISH' : 'CONTINUE',
          color: const Color(0xFFFFD45E),
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
                fontSize: 34,
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
        const SizedBox(height: 24),
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
/// Upgrades
/// ---------------------------------------------------------------------------
class Upgrade {
  const Upgrade(this.title, this.desc, this.apply);
  final String title;
  final String desc;
  final void Function(Player p) apply;
}

final List<Upgrade> kUpgrades = [
  Upgrade('MUCH DAMAGE', '+1 damage', (p) => p.damage += 1),
  Upgrade('VERY SPEED', '+18 move speed', (p) => p.speed += 18),
  Upgrade('SO TANKY', '+3 max HP & heal', (p) {
    p.maxHp += 3;
    p.hp = (p.hp + 3).clamp(0, p.maxHp).toDouble();
  }),
  Upgrade('WOW CRIT', '+8% crit chance', (p) => p.critChance += 0.08),
  Upgrade('RAPID BONK', '+22% attack speed',
      (p) => p.fireInterval = (p.fireInterval * 0.78).clamp(0.06, 5).toDouble()),
  Upgrade('LONG REACH', '+70 range', (p) => p.range += 70),
  Upgrade('FAST BONK', '+90 projectile speed', (p) => p.projSpeed += 90),
  Upgrade('MULTI BONK', '+1 projectile',
      (p) => p.projectiles = (p.projectiles + 1).clamp(1, 8).toInt()),
  Upgrade('VAMPIRE', '+0.4 HP per kill', (p) => p.lifesteal += 0.4),
  Upgrade('REGEN', '+0.6 HP / sec', (p) => p.regen += 0.6),
  Upgrade('PIERCING', '+1 pierce',
      (p) => p.pierce = (p.pierce + 1).clamp(0, 8).toInt()),
  Upgrade('BIG BOOM', '+22 splash radius', (p) => p.splash += 22),
  Upgrade('PLAGUE', '+1.5 poison dps', (p) => p.dot += 1.5),
  Upgrade('SPIKES', '+1 thorns damage', (p) => p.thorns += 1),
];

class _UpgradeCard extends StatelessWidget {
  const _UpgradeCard({required this.u, required this.onTap});
  final Upgrade u;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Container(
        width: 320,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        decoration: BoxDecoration(
          color: const Color(0xFF1F1D2E),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFF8CFF98), width: 1.5),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(u.title,
                style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF8CFF98))),
            const SizedBox(height: 2),
            Text(u.desc,
                style: const TextStyle(color: Colors.white60, fontSize: 13)),
          ],
        ),
      ),
    );
  }
}

/// ---------------------------------------------------------------------------
/// Shared widgets
/// ---------------------------------------------------------------------------
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
void _drawHero(Canvas canvas, Offset c, double r, HeroDef def, int stage) {
  final body = Paint()..color = def.body;
  final accent = Paint()..color = def.accent;
  final dark = Paint()..color = Colors.black;

  if (stage > 0) {
    final mr = r * (0.55 + stage * 0.12);
    canvas.drawCircle(c.translate(-r * 0.95, r * 0.18), mr, body);
    canvas.drawCircle(c.translate(r * 0.95, r * 0.18), mr, body);
  }

  canvas.drawCircle(c, r, body);

  switch (def.cls) {
    case HeroClass.tank:
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
              center: c.translate(0, -r * 1.05), width: r * 1.7, height: r * 0.5),
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
            ..strokeWidth = r * 0.18);
      _ears(canvas, c, r, accent);
      break;
    case HeroClass.mage:
      final hat = Path()
        ..moveTo(c.dx - r * 0.85, c.dy - r * 0.7)
        ..lineTo(c.dx, c.dy - r * 2.0)
        ..lineTo(c.dx + r * 0.85, c.dy - r * 0.7)
        ..close();
      canvas.drawPath(hat, accent);
      canvas.drawCircle(c.translate(0, -r * 2.0), r * 0.15,
          Paint()..color = const Color(0xFFFFE066));
      break;
    case HeroClass.warlock:
      final hornL = Path()
        ..moveTo(c.dx - r * 0.6, c.dy - r * 0.8)
        ..lineTo(c.dx - r * 1.0, c.dy - r * 1.8)
        ..lineTo(c.dx - r * 0.2, c.dy - r * 1.0)
        ..close();
      final hornR = Path()
        ..moveTo(c.dx + r * 0.6, c.dy - r * 0.8)
        ..lineTo(c.dx + r * 1.0, c.dy - r * 1.8)
        ..lineTo(c.dx + r * 0.2, c.dy - r * 1.0)
        ..close();
      canvas.drawPath(hornL, accent);
      canvas.drawPath(hornR, accent);
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

  if (def.cls != HeroClass.assassin) {
    canvas.drawCircle(c.translate(-r * 0.32, -r * 0.16), r * 0.13, dark);
    canvas.drawCircle(c.translate(r * 0.32, -r * 0.16), r * 0.13, dark);
  } else {
    final ep = Paint()..color = def.accent;
    canvas.drawCircle(c.translate(-r * 0.32, -r * 0.16), r * 0.1, ep);
    canvas.drawCircle(c.translate(r * 0.32, -r * 0.16), r * 0.1, ep);
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
    _drawHero(canvas, size.center(Offset.zero).translate(0, size.height * 0.12),
        size.width * 0.26, def, 2);
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
    required this.texts,
    required this.floor,
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
  final List<FloatText> texts;
  final FloorDef floor;
  final bool stickOn;
  final Offset stickOrigin;
  final Offset stickKnob;
  final bool ready;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = floor.bg);
    final grid = Paint()
      ..color = floor.grid
      ..strokeWidth = 1;
    for (double x = 0; x < size.width; x += 44) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), grid);
    }
    for (double y = 0; y < size.height; y += 44) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
    }
    if (!ready) return;

    final orbP = Paint()..color = const Color(0xFF8CC8FF);
    for (final o in orbs) {
      canvas.drawCircle(o.pos, 5, orbP);
    }

    for (final e in enemies) {
      final col = switch (e.kind) {
        1 => const Color(0xFFFF8A4C),
        2 => const Color(0xFF9B5CFF),
        3 => const Color(0xFFFF3B5C),
        4 => const Color(0xFF4CD2C0),
        _ => floor.mob,
      };
      canvas.drawCircle(e.pos, e.radius, Paint()..color = col);
      final wp = Paint()..color = Colors.white;
      canvas.drawCircle(e.pos.translate(-e.radius * 0.3, -e.radius * 0.1),
          e.radius * 0.22, wp);
      canvas.drawCircle(e.pos.translate(e.radius * 0.3, -e.radius * 0.1),
          e.radius * 0.22, wp);
      final pp = Paint()..color = Colors.black;
      canvas.drawCircle(e.pos.translate(-e.radius * 0.26, -e.radius * 0.05),
          e.radius * 0.1, pp);
      canvas.drawCircle(e.pos.translate(e.radius * 0.26, -e.radius * 0.05),
          e.radius * 0.1, pp);
      if (e.kind == 2 || e.kind == 3 || e.kind == 4) {
        final bw = e.radius * 2;
        canvas.drawRect(
          Rect.fromLTWH(e.pos.dx - e.radius, e.pos.dy - e.radius - 8, bw, 4),
          Paint()..color = Colors.black54,
        );
        canvas.drawRect(
          Rect.fromLTWH(e.pos.dx - e.radius, e.pos.dy - e.radius - 8,
              bw * (e.hp / e.maxHp).clamp(0, 1), 4),
          Paint()..color = const Color(0xFF8CFF98),
        );
      }
    }

    for (final b in bolts) {
      canvas.drawCircle(
        b.pos,
        b.splash > 0 ? 7 : (b.crit ? 6 : 4),
        Paint()..color = b.crit ? const Color(0xFFFFE066) : Colors.white,
      );
    }
    for (final e in ebolts) {
      canvas.drawCircle(e.pos, 5, Paint()..color = const Color(0xFFFF4D5E));
    }

    if (player.hurtFlash > 0) {
      canvas.drawCircle(player.pos, player.radius + 6,
          Paint()..color = const Color(0x55FF5C6C));
    }
    _drawHero(canvas, player.pos, player.radius, player.def,
        player.buffStage);

    for (final t in texts) {
      final tp = TextPainter(
        text: TextSpan(
          text: t.text,
          style: TextStyle(
            color: t.color.withValues(alpha: t.life.clamp(0.0, 1.0).toDouble()),
            fontSize: 14,
            fontWeight: FontWeight.w900,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, t.pos - Offset(tp.width / 2, tp.height / 2));
    }

    if (stickOn) {
      canvas.drawCircle(stickOrigin, 60,
          Paint()..color = Colors.white.withValues(alpha: 0.08));
      canvas.drawCircle(
          stickOrigin,
          60,
          Paint()
            ..color = Colors.white24
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2);
      canvas.drawCircle(stickKnob, 26,
          Paint()..color = Colors.white.withValues(alpha: 0.35));
    }
  }

  @override
  bool shouldRepaint(covariant WorldPainter old) => true;
}

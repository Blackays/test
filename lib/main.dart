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
/// Characters
/// ---------------------------------------------------------------------------
enum Hero { dog, cat }

class HeroDef {
  const HeroDef({
    required this.hero,
    required this.name,
    required this.tagline,
    required this.body,
    required this.accent,
    required this.maxHp,
    required this.speed,
    required this.damage,
    required this.fireInterval,
  });

  final Hero hero;
  final String name;
  final String tagline;
  final Color body;
  final Color accent;
  final double maxHp;
  final double speed;
  final double damage;
  final double fireInterval;
}

const HeroDef kDog = HeroDef(
  hero: Hero.dog,
  name: 'CHEEMS',
  tagline: 'Much fast. Very bonk. Wow.',
  body: Color(0xFFE8C39E),
  accent: Color(0xFF7A4B25),
  maxHp: 6,
  speed: 168,
  damage: 1.0,
  fireInterval: 0.46,
);

const HeroDef kCat = HeroDef(
  hero: Hero.cat,
  name: 'BUFF CAT',
  tagline: 'Tanky. Grumpy. Unbothered.',
  body: Color(0xFF9AA0AD),
  accent: Color(0xFF3C4250),
  maxHp: 10,
  speed: 138,
  damage: 1.5,
  fireInterval: 0.62,
);

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
              'survive the haters · get swole',
              style: TextStyle(color: Colors.white54, fontSize: 14),
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
                'best: wave ${GameStats.bestWave}',
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
      appBar: AppBar(title: const Text('CHOOSE YOUR FIGHTER')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const SizedBox(height: 8),
            const Text(
              'Dog or cat? Pick your champion.',
              style: TextStyle(color: Colors.white60),
            ),
            const SizedBox(height: 24),
            Expanded(child: _HeroCard(def: kDog)),
            const SizedBox(height: 16),
            Expanded(child: _HeroCard(def: kCat)),
          ],
        ),
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
      borderRadius: BorderRadius.circular(20),
      onTap: () => Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(builder: (_) => GameScreen(def: def)),
      ),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF1F1D2E),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: def.accent, width: 2),
        ),
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            SizedBox(
              width: 96,
              height: 96,
              child: CustomPaint(
                painter: HeroPreviewPainter(def: def),
              ),
            ),
            const SizedBox(width: 18),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    def.name,
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w900,
                      color: def.body,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    def.tagline,
                    style: const TextStyle(color: Colors.white54, fontSize: 12),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'HP ${def.maxHp.toInt()}   SPD ${def.speed.toInt()}   '
                    'DMG ${def.damage}   ROF ${(1 / def.fireInterval).toStringAsFixed(1)}/s',
                    style: const TextStyle(color: Colors.white38, fontSize: 11),
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
/// Game entities
/// ---------------------------------------------------------------------------
class Player {
  Player(this.def)
      : pos = Offset.zero,
        hp = def.maxHp,
        maxHp = def.maxHp,
        speed = def.speed,
        damage = def.damage,
        fireInterval = def.fireInterval;

  final HeroDef def;
  Offset pos;
  double hp;
  double maxHp;
  double speed;
  double damage;
  double fireInterval;
  double fireTimer = 0;
  double projSpeed = 360;
  double range = 320;
  double critChance = 0.05;
  int projectiles = 1;
  double regen = 0;
  double lifesteal = 0;
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
  int kind; // 0 hater, 1 zoomer, 2 chonk, 3 boss
  double touchTimer = 0;
}

class Bolt {
  Bolt(this.pos, this.vel, this.damage, this.crit);
  Offset pos;
  Offset vel;
  double damage;
  bool crit;
  double life = 1.6;
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
const int kMaxWaves = 12;
const double kWaveTime = 20;

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
  final List<Orb> _orbs = [];
  final List<FloatText> _texts = [];

  Phase _phase = Phase.playing;
  int _wave = 1;
  double _waveTime = kWaveTime;
  double _spawnTimer = 0;

  // joystick
  bool _stickOn = false;
  Offset _stickOrigin = Offset.zero;
  Offset _stickKnob = Offset.zero;
  Offset _moveDir = Offset.zero;
  static const double _stickR = 60;

  List<Upgrade> _choices = [];

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

    // movement
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

    // wave timer
    _waveTime -= dt;
    if (_waveTime <= 0) {
      _enemies.clear();
      _phase = Phase.waveCleared;
      return;
    }

    // spawning
    _spawnTimer -= dt;
    if (_spawnTimer <= 0) {
      _spawnEnemy();
      final base = 1.45 - _wave * 0.07;
      _spawnTimer = base.clamp(0.32, 1.45).toDouble();
    }

    // auto fire
    _p.fireTimer -= dt;
    if (_p.fireTimer <= 0) {
      final target = _nearestEnemy();
      if (target != null) {
        _fire(target);
        _p.fireTimer = _p.fireInterval;
      }
    }

    // bolts
    for (final b in _bolts) {
      b.pos += b.vel * dt;
      b.life -= dt;
    }
    _bolts.removeWhere((b) =>
        b.life <= 0 ||
        b.pos.dx < -20 ||
        b.pos.dx > w + 20 ||
        b.pos.dy < -20 ||
        b.pos.dy > h + 20);

    // enemies
    for (final e in _enemies) {
      final dir = _p.pos - e.pos;
      final d = dir.distance;
      if (d > 0.01) e.pos += dir / d * e.speed * dt;
      if (e.touchTimer > 0) e.touchTimer -= dt;
      if (d < e.radius + _p.radius && e.touchTimer <= 0) {
        e.touchTimer = 0.7;
        _p.hp -= e.damage;
        _p.hurtFlash = 0.25;
        if (_p.hp <= 0) {
          _p.hp = 0;
          _gameOver();
          return;
        }
      }
    }

    // bolt vs enemy
    for (final b in _bolts) {
      for (final e in _enemies) {
        if ((b.pos - e.pos).distance < e.radius + 5) {
          e.hp -= b.damage;
          _texts.add(FloatText(
            e.pos.translate(0, -e.radius),
            b.crit ? '${b.damage.toInt()}!' : '${b.damage.toInt()}',
            b.crit ? const Color(0xFFFFE066) : Colors.white,
          ));
          b.life = 0;
          if (e.hp <= 0) {
            _orbs.add(Orb(e.pos));
            if (_p.lifesteal > 0) {
              _p.hp = (_p.hp + _p.lifesteal).clamp(0, _p.maxHp).toDouble();
            }
            _p.kills++;
          }
          break;
        }
      }
    }
    _enemies.removeWhere((e) => e.hp <= 0);

    // orbs (magnet + collect)
    for (final o in _orbs) {
      final dir = _p.pos - o.pos;
      final d = dir.distance;
      if (d < 110) o.pos += dir / d * 240 * dt;
    }
    _orbs.removeWhere((o) {
      if ((o.pos - _p.pos).distance < _p.radius + 8) {
        _gainXp();
        return true;
      }
      return false;
    });

    // floating text
    for (final t in _texts) {
      t.pos = t.pos.translate(0, -34 * dt);
      t.life -= dt;
    }
    _texts.removeWhere((t) => t.life <= 0);
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
    final base = (target.pos - _p.pos);
    final baseAng = atan2(base.dy, base.dx);
    final n = _p.projectiles;
    const spread = 0.18;
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
      ));
    }
  }

  void _spawnEnemy() {
    final w = _size.width;
    final h = _size.height;
    // spawn just off a random edge
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

    if (_wave % 5 == 0 && _enemies.where((e) => e.kind == 3).isEmpty) {
      _enemies.add(Enemy(
        pos: p,
        hp: 24.0 + _wave * 6,
        speed: 46 + _wave * 1.5,
        damage: 2,
        radius: 34,
        kind: 3,
      ));
      return;
    }

    final roll = _rng.nextDouble();
    if (roll < 0.18 + _wave * 0.01) {
      _enemies.add(Enemy(
        pos: p,
        hp: 2.0 + _wave * 0.4,
        speed: 122 + _wave * 2.0,
        damage: 1,
        radius: 11,
        kind: 1,
      ));
    } else if (roll < 0.32) {
      _enemies.add(Enemy(
        pos: p,
        hp: 9.0 + _wave * 1.6,
        speed: 48 + _wave * 0.8,
        damage: 2,
        radius: 22,
        kind: 2,
      ));
    } else {
      _enemies.add(Enemy(
        pos: p,
        hp: 3.0 + _wave * 0.9,
        speed: 70 + _wave * 1.3,
        damage: 1,
        radius: 15,
        kind: 0,
      ));
    }
  }

  void _gainXp() {
    _p.xp++;
    if (_p.xp >= _p.xpToNext) {
      _p.xp = 0;
      _p.level++;
      _p.xpToNext = 5 + _p.level * 3;
      _choices = _rollUpgrades();
      _phase = Phase.levelUp;
    }
  }

  List<Upgrade> _rollUpgrades() {
    final pool = List<Upgrade>.from(kUpgrades)..shuffle(_rng);
    return pool.take(3).toList();
  }

  void _pickUpgrade(Upgrade u) {
    u.apply(_p);
    _texts.add(FloatText(
      _p.pos.translate(0, -_p.radius - 14),
      u.title,
      const Color(0xFF8CFF98),
    ));
    if (_p.xp >= _p.xpToNext) {
      _p.xp -= _p.xpToNext;
      _p.level++;
      _p.xpToNext = 5 + _p.level * 3;
      _choices = _rollUpgrades();
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

  // input -----------------------------------------------------------------
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
                      orbs: _orbs,
                      texts: _texts,
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
                    'WAVE $_wave/$kMaxWaves',
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 16,
                      color: Color(0xFFFFD45E),
                    ),
                  ),
                  Text(
                    '⏱ ${_waveTime.ceil()}s',
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 16,
                      color: Colors.white,
                    ),
                  ),
                  Text(
                    'LV ${_p.level}',
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 16,
                      color: Color(0xFF8CC8FF),
                    ),
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
                color: Colors.white,
              )),
      ],
    );
  }

  Widget _scrim(Widget child) {
    return Positioned.fill(
      child: Container(
        color: Colors.black.withValues(alpha: 0.72),
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
    return _scrim(Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('WAVE $_wave CLEARED',
            style: const TextStyle(
                fontSize: 30,
                fontWeight: FontWeight.w900,
                color: Color(0xFFFFD45E))),
        const SizedBox(height: 8),
        Text('kills: ${_p.kills}   ·   +25% HP restored',
            style: const TextStyle(color: Colors.white60)),
        const SizedBox(height: 24),
        _BigButton(
          label: _wave >= kMaxWaves ? 'FINISH' : 'NEXT WAVE',
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
        Text(win ? 'YOU SURVIVED!' : 'GET REKT',
            style: TextStyle(
                fontSize: 38,
                fontWeight: FontWeight.w900,
                color: win ? const Color(0xFF8CFF98) : const Color(0xFFFF5C6C))),
        const SizedBox(height: 10),
        Text(
          'reached wave $_wave   ·   level ${_p.level}   ·   ${_p.kills} kills',
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
          label: 'CHANGE FIGHTER',
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
      (p) => p.fireInterval = (p.fireInterval * 0.78).clamp(0.08, 5).toDouble()),
  Upgrade('LONG REACH', '+70 range', (p) => p.range += 70),
  Upgrade('FAST BONK', '+90 projectile speed', (p) => p.projSpeed += 90),
  Upgrade('MULTI BONK', '+1 projectile',
      (p) => p.projectiles = (p.projectiles + 1).clamp(1, 7).toInt()),
  Upgrade('VAMPIRE', '+0.4 HP per kill', (p) => p.lifesteal += 0.4),
  Upgrade('REGEN', '+0.6 HP / sec', (p) => p.regen += 0.6),
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
/// Painters
/// ---------------------------------------------------------------------------
void _drawHero(Canvas canvas, Offset c, double r, HeroDef def, int stage) {
  final body = Paint()..color = def.body;
  final accent = Paint()..color = def.accent;
  final dark = Paint()..color = Colors.black;
  final white = Paint()..color = Colors.white;

  // muscles grow with stage
  if (stage > 0) {
    final mr = r * (0.55 + stage * 0.12);
    canvas.drawCircle(c.translate(-r * 0.95, r * 0.15), mr, body);
    canvas.drawCircle(c.translate(r * 0.95, r * 0.15), mr, body);
  }

  // body
  canvas.drawCircle(c, r, body);

  if (def.hero == Hero.dog) {
    // ears
    canvas.drawCircle(c.translate(-r * 0.8, -r * 0.75), r * 0.42, accent);
    canvas.drawCircle(c.translate(r * 0.8, -r * 0.75), r * 0.42, accent);
    // snout
    canvas.drawCircle(c.translate(0, r * 0.25), r * 0.42, white);
    canvas.drawCircle(c.translate(0, r * 0.1), r * 0.16, dark);
  } else {
    // pointy ears
    final earL = Path()
      ..moveTo(c.dx - r * 0.95, c.dy - r * 0.55)
      ..lineTo(c.dx - r * 0.45, c.dy - r * 1.25)
      ..lineTo(c.dx - r * 0.15, c.dy - r * 0.7)
      ..close();
    final earR = Path()
      ..moveTo(c.dx + r * 0.95, c.dy - r * 0.55)
      ..lineTo(c.dx + r * 0.45, c.dy - r * 1.25)
      ..lineTo(c.dx + r * 0.15, c.dy - r * 0.7)
      ..close();
    canvas.drawPath(earL, accent);
    canvas.drawPath(earR, accent);
    canvas.drawCircle(c.translate(0, r * 0.18), r * 0.1, dark);
    // whiskers
    final wp = Paint()
      ..color = Colors.white70
      ..strokeWidth = 1.4;
    canvas.drawLine(c.translate(-r * 0.2, r * 0.2),
        c.translate(-r * 1.1, r * 0.05), wp);
    canvas.drawLine(c.translate(-r * 0.2, r * 0.3),
        c.translate(-r * 1.1, r * 0.4), wp);
    canvas.drawLine(
        c.translate(r * 0.2, r * 0.2), c.translate(r * 1.1, r * 0.05), wp);
    canvas.drawLine(
        c.translate(r * 0.2, r * 0.3), c.translate(r * 1.1, r * 0.4), wp);
  }

  // eyes
  canvas.drawCircle(c.translate(-r * 0.32, -r * 0.18), r * 0.13, dark);
  canvas.drawCircle(c.translate(r * 0.32, -r * 0.18), r * 0.13, dark);
}

class HeroPreviewPainter extends CustomPainter {
  HeroPreviewPainter({required this.def});
  final HeroDef def;

  @override
  void paint(Canvas canvas, Size size) {
    _drawHero(canvas, size.center(Offset.zero), size.width * 0.32, def, 2);
  }

  @override
  bool shouldRepaint(covariant HeroPreviewPainter old) => false;
}

class WorldPainter extends CustomPainter {
  WorldPainter({
    required this.player,
    required this.enemies,
    required this.bolts,
    required this.orbs,
    required this.texts,
    required this.stickOn,
    required this.stickOrigin,
    required this.stickKnob,
    required this.ready,
  });

  final Player player;
  final List<Enemy> enemies;
  final List<Bolt> bolts;
  final List<Orb> orbs;
  final List<FloatText> texts;
  final bool stickOn;
  final Offset stickOrigin;
  final Offset stickKnob;
  final bool ready;

  @override
  void paint(Canvas canvas, Size size) {
    // background
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = const Color(0xFF14131F),
    );
    final grid = Paint()
      ..color = Colors.white.withValues(alpha: 0.04)
      ..strokeWidth = 1;
    for (double x = 0; x < size.width; x += 44) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), grid);
    }
    for (double y = 0; y < size.height; y += 44) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
    }
    if (!ready) return;

    // orbs
    final orbP = Paint()..color = const Color(0xFF8CC8FF);
    for (final o in orbs) {
      canvas.drawCircle(o.pos, 5, orbP);
    }

    // enemies
    for (final e in enemies) {
      final col = switch (e.kind) {
        1 => const Color(0xFFFF8A4C),
        2 => const Color(0xFF9B5CFF),
        3 => const Color(0xFFFF3B5C),
        _ => const Color(0xFFFF5C6C),
      };
      canvas.drawCircle(e.pos, e.radius, Paint()..color = col);
      // angry eyes
      final ep = Paint()..color = Colors.white;
      canvas.drawCircle(
          e.pos.translate(-e.radius * 0.3, -e.radius * 0.1), e.radius * 0.22, ep);
      canvas.drawCircle(
          e.pos.translate(e.radius * 0.3, -e.radius * 0.1), e.radius * 0.22, ep);
      final pp = Paint()..color = Colors.black;
      canvas.drawCircle(e.pos.translate(-e.radius * 0.26, -e.radius * 0.05),
          e.radius * 0.1, pp);
      canvas.drawCircle(e.pos.translate(e.radius * 0.26, -e.radius * 0.05),
          e.radius * 0.1, pp);
      // hp bar for tough ones
      if (e.kind == 2 || e.kind == 3) {
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

    // bolts
    for (final b in bolts) {
      canvas.drawCircle(
        b.pos,
        b.crit ? 6 : 4,
        Paint()..color = b.crit ? const Color(0xFFFFE066) : Colors.white,
      );
    }

    // player
    if (player.hurtFlash > 0) {
      canvas.drawCircle(player.pos, player.radius + 6,
          Paint()..color = const Color(0x55FF5C6C));
    }
    _drawHero(canvas, player.pos, player.radius, player.def,
        player.buffStage);

    // floating text
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

    // joystick
    if (stickOn) {
      canvas.drawCircle(stickOrigin, 60,
          Paint()..color = Colors.white.withValues(alpha: 0.08));
      canvas.drawCircle(stickOrigin, 60,
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

import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:reflex_mobile_game/main.dart';

// Walks the same fixups _genRoom / _roomEnd apply: carve a clear disk
// at the spawn and at every other room's center (where doors sit).
void _applyGameFixups(GameMap m) {
  final spawn = m.roomCenter(0);
  m.clearDisk(spawn.dx, spawn.dy, 2.4);
  for (var i = 1; i < m.rooms.length; i++) {
    final c = m.roomCenter(i);
    m.clearDisk(c.dx, c.dy, 2.4);
  }
}

bool _reachable(GameMap m, Offset from, Offset to) {
  final sc = (from.dx / m.cell).floor();
  final sr = (from.dy / m.cell).floor();
  final tc = (to.dx / m.cell).floor();
  final tr = (to.dy / m.cell).floor();
  if (!m.tile(sc, sr) || !m.tile(tc, tr)) return false;
  final seen = List<bool>.filled(m.cols * m.rows, false);
  final q = <int>[sr * m.cols + sc];
  seen[sr * m.cols + sc] = true;
  while (q.isNotEmpty) {
    final i = q.removeLast();
    final c = i % m.cols, r = i ~/ m.cols;
    if (c == tc && r == tr) return true;
    for (final d in const [[1, 0], [-1, 0], [0, 1], [0, -1]]) {
      final nc = c + d[0], nr = r + d[1];
      if (nc < 0 || nr < 0 || nc >= m.cols || nr >= m.rows) continue;
      final ni = nr * m.cols + nc;
      if (seen[ni] || !m.tile(nc, nr)) continue;
      seen[ni] = true;
      q.add(ni);
    }
  }
  return false;
}

void main() {
  test('every room center is reachable from spawn across many seeds', () {
    var checked = 0;
    for (var seed = 0; seed < 40; seed++) {
      final rng = Random(seed);
      for (final wave in const [1, 4, 5, 9, 14]) {
        final m = GameMap.generate(rng, 1280, 800, wave);
        _applyGameFixups(m);
        final spawn = m.roomCenter(0);
        for (var i = 1; i < m.rooms.length; i++) {
          final c = m.roomCenter(i);
          expect(_reachable(m, spawn, c), isTrue,
              reason: 'seed=$seed wave=$wave room=$i unreachable from spawn');
          checked++;
        }
      }
    }
    expect(checked, greaterThan(0));
  });
}

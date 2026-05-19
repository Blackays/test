import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reflex_mobile_game/main.dart';

void main() {
  testWidgets('GameScreen boots, runs frames, and paints without throwing',
      (tester) async {
    await tester.pumpWidget(MaterialApp(home: GameScreen(def: kHeroes.first)));
    // first frame schedules the post-frame _initRun
    await tester.pump();
    // a few simulated ticks to exercise the game loop + painter
    await tester.pump(const Duration(milliseconds: 16));
    await tester.pump(const Duration(milliseconds: 16));
    await tester.pump(const Duration(milliseconds: 16));
    expect(tester.takeException(), isNull);
    expect(find.byType(CustomPaint), findsWidgets);
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:reflex_mobile_game/main.dart';

void main() {
  testWidgets('boots to the title screen', (tester) async {
    await tester.pumpWidget(const BuffBattleApp());
    expect(find.text('BUFF BATTLE'), findsOneWidget);
    expect(find.text('PLAY'), findsOneWidget);
  });
}

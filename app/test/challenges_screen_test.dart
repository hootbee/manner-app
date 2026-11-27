import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mannerfit/screens/challenges_screen.dart';

void main() {
  testWidgets('tabs show pending data without granting rewards', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 780);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(const MaterialApp(home: ChallengesScreen()));
    expect(find.text('오늘의 첫걸음'), findsOneWidget);
    await tester.tap(find.text('주간'));
    await tester.pumpAndSettle();
    expect(find.text('꾸준한 매너 습관'), findsOneWidget);
    expect(find.text('보상 받기'), findsNothing);
    await tester.tap(find.text('업적'));
    await tester.pumpAndSettle();
    expect(find.text('첫걸음'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

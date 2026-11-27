import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mannerfit/screens/activity_preview.dart';
import 'package:mannerfit/screens/activity_screen.dart';
import 'package:mannerfit/screens/partner_selection_screen.dart';

void main() {
  test('preview automatic popup can be claimed only once per date', () {
    final preview = ActivityPreview();
    expect(preview.claimAutomaticPopup(), isTrue);
    expect(preview.claimAutomaticPopup(), isFalse);
  });
  testWidgets('weekly is default, month navigation handles year boundary', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 780);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final preview = ActivityPreview(now: DateTime(2026, 1, 7));
    await tester.pumpWidget(
      MaterialApp(
        home: ActivityBinding(
          days: preview.days,
          today: preview.today,
          attendanceStreak: 4,
          learningStreak: 7,
          totalLearningDays: 12,
          totalProblems: 48,
          rewardDay: 4,
          rewardCoins: 30,
          claimAutomaticPopup: preview.claimAutomaticPopup,
          child: const ActivityScreen(partner: MannerPartner.dog),
        ),
      ),
    );
    expect(find.text('1월 1주차'), findsOneWidget);
    await tester.tap(find.text('월간'));
    await tester.pump();
    expect(find.text('2026년 1월'), findsOneWidget);
    await tester.tap(find.byTooltip('이전 기간'));
    await tester.pump();
    expect(find.text('2025년 12월'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

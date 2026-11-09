import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mannerfit/screens/settings_screen.dart';

void main() {
  testWidgets(
    'notification switch and time picker are local; deletion is preview only',
    (tester) async {
      tester.view.physicalSize = const Size(360, 780);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(const MaterialApp(home: SettingsScreen()));
      expect(tester.widget<Switch>(find.byType(Switch)).value, isTrue);
      await tester.tap(find.byType(Switch));
      await tester.pumpAndSettle();
      expect(tester.widget<Switch>(find.byType(Switch)).value, isFalse);
      expect(
        tester
            .widget<ListTile>(find.byKey(const Key('notification-time')))
            .onTap,
        isNull,
      );
      await tester.tap(find.byType(Switch));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('notification-time')));
      await tester.pumpAndSettle();
      expect(find.byType(TimePickerDialog), findsOneWidget);
      await tester.tap(find.text('취소'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('회원 탈퇴'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('회원 탈퇴'));
      await tester.pumpAndSettle();
      expect(find.text('정말로 탈퇴하시겠습니까?'), findsOneWidget);
      await tester.tap(find.text('취소'));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
      await tester.tap(find.text('회원 탈퇴'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('탈퇴하기'));
      await tester.pumpAndSettle();
      expect(find.text('회원 탈퇴는 계정 연결 후 사용할 수 있어요.'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('small screen can reach app information', (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(const MaterialApp(home: SettingsScreen()));
    await tester.ensureVisible(find.text('개인정보 처리방침'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('개인정보 처리방침'));
    await tester.pumpAndSettle();
    expect(find.text('정식 개인정보 처리방침은 추후 연결할 예정이에요.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

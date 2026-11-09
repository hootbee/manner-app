import 'package:mannerfit/screens/settings_screen.dart';
import 'package:mannerfit/backend.dart';
import 'package:mannerfit/fake/fake_backend.dart';
import 'package:mannerfit/screens/stat_share_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mannerfit/screens/my_page_screen.dart';
import 'package:mannerfit/screens/home_screen.dart';
import 'package:mannerfit/screens/partner_selection_screen.dart';

void main() {
  setUp(() => backend = FakeBackend());
  testWidgets(
    'selected partner reacts to tap and drag; menu remains reachable',
    (tester) async {
      tester.view.physicalSize = const Size(360, 780);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        const MaterialApp(home: MyPageScreen(partner: MannerPartner.cat)),
      );
      expect(find.text('냥냥이'), findsOneWidget);
      await tester.tap(find.byKey(const Key('profile-character')));
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('꺄르르! 함께하니 즐거워요!'), findsOneWidget);
      await tester.drag(
        find.byKey(const Key('profile-character')),
        const Offset(100, 0),
      );
      await tester.pump(const Duration(milliseconds: 100));
      final transform = tester.widget<Transform>(
        find.byKey(const Key('character-turn')),
      );
      expect(transform.transform.entry(0, 0), isNot(1));
      await tester.ensureVisible(find.text('스탯 공유'));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(find.text('스탯 공유'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byType(StatShareScreen), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('home opens profile with the selected partner', (tester) async {
    tester.view.physicalSize = const Size(360, 780);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      const MaterialApp(home: HomeScreen(partner: MannerPartner.monkey)),
    );
    await tester.tap(find.text('마이페이지'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byType(MyPageScreen), findsOneWidget);
    expect(find.text('몽몽이'), findsOneWidget);
    await tester.tap(find.text('홈').last);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byType(MyPageScreen), findsNothing);
    expect(tester.takeException(), isNull);
  });
  testWidgets('profile settings icon opens frontend settings', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: MyPageScreen(partner: MannerPartner.dog)),
    );
    await tester.tap(find.byTooltip('설정'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byType(SettingsScreen), findsOneWidget);
    expect(find.text('알림 설정'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

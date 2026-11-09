import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mannerfit/screens/home_screen.dart';
import 'package:mannerfit/screens/transport_lesson_screen.dart';
import 'package:mannerfit/screens/partner_selection_screen.dart';
import 'package:mannerfit/screens/partner_growth_screen.dart';
import 'package:mannerfit/screens/daily_mission_progress.dart';

void main() {
  const output = String.fromEnvironment('CAPTURE_DIR');
  final capture = GlobalKey();
  Future<void> mount(
    WidgetTester tester,
    Widget screen, {
    Size size = const Size(360, 780),
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    if (output.isNotEmpty) {
      await tester.runAsync(() async {
        for (final (family, path) in [
          ('PreviewKorean', const String.fromEnvironment('PREVIEW_FONT')),
          ('MaterialIcons', const String.fromEnvironment('PREVIEW_ICONS_FONT')),
        ]) {
          if (path.isEmpty) continue;
          await (FontLoader(family)
                ..addFont(File(path).readAsBytes().then(ByteData.sublistView)))
              .load();
        }
      });
    }
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(fontFamily: 'PreviewKorean'),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(disableAnimations: true),
          child: child!,
        ),
        home: RepaintBoundary(key: capture, child: screen),
      ),
    );
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 400)),
    );
    await tester.pumpAndSettle();
  }

  Future<void> shot(WidgetTester tester, String name) async {
    if (output.isEmpty) return;
    await tester.runAsync(() async {
      final boundary =
          capture.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 2);
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      await File('$output/$name.png').writeAsBytes(data!.buffer.asUint8List());
      image.dispose();
    });
  }

  test('mission states and remaining counts', () {
    expect(const DailyMissionProgress().action, '시작하기');
    expect(
      const DailyMissionProgress(completed: 4).encouragement,
      contains('6문제'),
    );
    expect(const DailyMissionProgress(completed: 10).isComplete, isTrue);
    expect(const DailyMissionProgress(completed: 10).timeAt(9), '오전 09:09');
  });
  for (final count in [0, 4, 10]) {
    testWidgets('main $count/10 defaults folded, expands records and folds', (
      tester,
    ) async {
      final p = DailyMissionProgress(completed: count);
      await mount(tester, HomeScreen(partner: MannerPartner.dog, progress: p));
      expect(find.text('학습 기록 펼치기'), findsOneWidget);
      expect(find.text(p.action), findsOneWidget);
      expect(find.text(p.encouragement), findsOneWidget);
      expect(find.text('$count / 10'), findsOneWidget);
      await shot(tester, 'home_${count}_collapsed');
      await tester.ensureVisible(find.text('학습 기록 펼치기'));
      await tester.tap(find.text('학습 기록 펼치기'));
      await tester.pumpAndSettle();
      if (count == 0) {
        expect(find.textContaining('아직 학습 기록이 없어요.'), findsOneWidget);
      } else {
        expect(find.text(p.titleAt(0)), findsOneWidget);
        await tester.ensureVisible(find.text(p.titleAt(0)));
        await tester.tap(find.text(p.titleAt(0)));
        await tester.pumpAndSettle();
        expect(find.text('1번 문제 완료 · 오전 08:24'), findsOneWidget);
      }
      await shot(tester, 'home_${count}_expanded');
      await tester.ensureVisible(find.text('학습 기록 접기'));
      await tester.tap(find.text('학습 기록 접기'));
      await tester.pumpAndSettle();
      expect(find.text('학습 기록 펼치기'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  }
  for (final partner in MannerPartner.values) {
    testWidgets('${partner.name} growth and selection lead home', (
      tester,
    ) async {
      await mount(tester, PartnerGrowthScreen(partner: partner));
      for (final name in ['아기', '유년기', '청소년기', '성체']) {
        expect(find.text(name), findsOneWidget);
      }
      await shot(tester, 'growth_${partner.index}');
      await tester.ensureVisible(find.text('이 파트너 선택하기'));
      await tester.tap(find.text('이 파트너 선택하기'));
      await tester.pumpAndSettle();
      final home = tester.widget<HomeScreen>(find.byType(HomeScreen));
      expect(home.partner, partner);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  }
  testWidgets('each visible carousel character opens its own growth', (
    tester,
  ) async {
    await mount(tester, const PartnerSelectionScreen());
    for (final (dx, partner) in [
      (60.0, MannerPartner.cat),
      (180.0, MannerPartner.dog),
      (300.0, MannerPartner.monkey),
    ]) {
      final origin = tester.getTopLeft(find.byType(GestureDetector).first);
      // Find the dedicated 212px character stage instead of button gestures.
      final stage = find.byKey(const ValueKey('partner-carousel'));
      final top = tester.getTopLeft(stage);
      await tester.tapAt(top + Offset(dx, 140));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<PartnerGrowthScreen>(find.byType(PartnerGrowthScreen))
            .partner,
        partner,
      );
      await tester.tap(find.byTooltip('뒤로 가기').last);
      await tester.pumpAndSettle();
      expect(origin.dx, isNonNegative);
    }
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('small phone keeps main action reachable', (tester) async {
    await mount(
      tester,
      const HomeScreen(partner: MannerPartner.cat),
      size: const Size(320, 568),
    );
    await tester.ensureVisible(find.text('시작하기'));
    await tester.tap(find.text('시작하기'));
    await tester.pumpAndSettle();
    expect(find.byType(TransportLessonScreen), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
}

import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mannerfit/screens/home_screen.dart';
import 'package:mannerfit/screens/partner_selection_screen.dart';
import 'package:mannerfit/screens/learning_catalog.dart';
import 'package:mannerfit/screens/learning_screens.dart';

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
          ('PreviewKorean', 'C:/Windows/Fonts/malgun.ttf'),
          (
            'MaterialIcons',
            'C:/Users/gjo49/flutter/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
          ),
        ]) {
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
      () => Future<void>.delayed(const Duration(milliseconds: 300)),
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

  test(
    'six consistent categories, sixty unique topics and matching search',
    () {
      expect(learningCategories.length, 6);
      final all = learningCategories.expand((c) => c.lessons).toList();
      expect(all.length, 60);
      expect(all.map((l) => l.id).toSet().length, 60);
      expect(all.where((l) => l.status == LessonStatus.completed).length, 0);
      for (final c in learningCategories) {
        expect(c.lessons.length, 10);
        expect(c.search('').length, 10);
      }
      final transport = learningCategories.first;
      expect(transport.search('분실물').single.id, 'transport-10');
      expect(transport.search('소음').single.title, '큰 소리로 통화하지 않기');
      expect(transport.search('  자리  ').isNotEmpty, isTrue);
      expect(transport.search('없는검색어'), isEmpty);
    },
  );
  testWidgets(
    'home learning tab opens categories, home returns to existing home',
    (tester) async {
      await mount(tester, const HomeScreen(partner: MannerPartner.cat));
      await tester.tap(find.text('학습하기'));
      await tester.pumpAndSettle();
      expect(find.text('매너 학습하기'), findsOneWidget);
      await tester.tap(find.text('홈'));
      await tester.pumpAndSettle();
      expect(find.byType(HomeScreen), findsOneWidget);
      expect(find.byType(LearningCategoryScreen), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets('global topic search opens only matching topics and clears', (
    tester,
  ) async {
    await mount(tester, const LearningCategoryScreen());
    await shot(tester, 'learning_categories');
    await tester.enterText(find.byType(TextField), '분실물');
    await tester.pumpAndSettle();
    expect(find.text('대중교통 매너'), findsOneWidget);
    expect(find.text('식사 매너'), findsNothing);
    expect(find.text('0 / 60'), findsOneWidget);
    await tester.tap(find.text('대중교통 매너'));
    await tester.pumpAndSettle();
    expect(find.text('분실물 발견 시 대처 방법'), findsOneWidget);
    expect(find.text('10'), findsOneWidget);
    expect(find.text('자리 양보하기'), findsNothing);
    await tester.tap(find.byTooltip('검색어 지우기'));
    await tester.pumpAndSettle();
    expect(find.text('자리 양보하기'), findsOneWidget);
    await tester.tap(find.byTooltip('카테고리로 돌아가기'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '없는검색어');
    await tester.pumpAndSettle();
    expect(find.text('일치하는 학습 목록이 없어요.'), findsOneWidget);
    await tester.tap(find.byTooltip('검색어 지우기'));
    await tester.pumpAndSettle();
    expect(find.text('대중교통 매너'), findsOneWidget);
    expect(find.text('식사 매너'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets(
    'detail searches keywords, preserves original numbering and restores',
    (tester) async {
      await mount(
        tester,
        LearningLessonScreen(category: learningCategories.first),
      );
      await tester.enterText(find.byType(TextField), '소음');
      await tester.pumpAndSettle();
      expect(find.text('큰 소리로 통화하지 않기'), findsOneWidget);
      expect(find.text('03'), findsOneWidget);
      expect(find.text('자리 양보하기'), findsNothing);
      await shot(tester, 'learning_search');
      await tester.enterText(find.byType(TextField), '결과없음');
      await tester.pumpAndSettle();
      expect(find.text('일치하는 학습 목록이 없어요.'), findsOneWidget);
      await tester.tap(find.byTooltip('검색어 지우기'));
      await tester.pumpAndSettle();
      expect(find.text('자리 양보하기'), findsOneWidget);
      expect(find.text('미학습'), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
  for (final category in learningCategories) {
    testWidgets(
      '${category.id}: any topic can start; completed topics replay',
      (tester) async {
        final calls = <LearningLesson>[];
        await mount(
          tester,
          LearningLessonScreen(category: category, onLessonSelected: calls.add),
        );
        await shot(tester, 'learning_${category.id}');
        final last = category.lessons.last;
        final lastRow = find.byKey(ValueKey('lesson-${last.id}'));
        await tester.scrollUntilVisible(
          lastRow,
          180,
          scrollable: find.byType(Scrollable).last,
        );
        await tester.pumpAndSettle();
        await tester.tap(
          find.descendant(of: lastRow, matching: find.text('시작')),
        );
        await tester.pumpAndSettle();
        expect(calls, [last]);
        expect(last.status, LessonStatus.notStarted);
        final first = category.lessons.first;
        final firstRow = find.byKey(ValueKey('lesson-${first.id}'));
        await tester.scrollUntilVisible(
          firstRow,
          -180,
          scrollable: find.byType(Scrollable).last,
        );
        await tester.pumpAndSettle();
        await tester.tap(firstRow);
        await tester.pumpAndSettle();
        expect(calls, [last, first]);
        expect(first.status, LessonStatus.notStarted);
        expect(find.byIcon(Icons.lock), findsNothing);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      },
    );
  }
  testWidgets('small phone can search and reach last topic', (tester) async {
    await mount(
      tester,
      LearningLessonScreen(category: learningCategories[4]),
      size: const Size(320, 568),
    );
    final last = find.byKey(const ValueKey('lesson-school-work-10'));
    await tester.scrollUntilVisible(
      last,
      180,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.tap(last);
    await tester.pumpAndSettle();
    expect(find.text('정답 확인하기'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
}

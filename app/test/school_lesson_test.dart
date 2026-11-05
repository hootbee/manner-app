import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mannerfit/screens/school_questions.dart';
import 'package:mannerfit/screens/school_action_scene.dart';
import 'package:mannerfit/screens/transport_questions.dart';
import 'package:mannerfit/screens/transport_progress.dart';
import 'package:mannerfit/screens/transport_lesson_screen.dart';

void main() {
  const output = String.fromEnvironment('CAPTURE_DIR');
  final boundary = GlobalKey();
  Future<void> mount(WidgetTester t, int i, TransportProgress store) async {
    t.view.physicalSize = const Size(360, 780);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    if (output.isNotEmpty) {
      await t.runAsync(() async {
        for (final entry in [
          ('Korean', 'C:/Windows/Fonts/malgun.ttf'),
          (
            'MaterialIcons',
            'C:/Users/gjo49/flutter/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
          ),
        ]) {
          await (FontLoader(entry.$1)..addFont(
                File(entry.$2).readAsBytes().then(ByteData.sublistView),
              ))
              .load();
        }
      });
    }
    await t.pumpWidget(
      MaterialApp(
        theme: ThemeData(fontFamily: 'Korean'),
        builder: (c, child) => MediaQuery(
          data: MediaQuery.of(c).copyWith(disableAnimations: true),
          child: child!,
        ),
        home: RepaintBoundary(
          key: boundary,
          child: TransportLessonScreen(
            key: ValueKey(i),
            index: i,
            categoryId: 'school-work',
            store: store,
          ),
        ),
      ),
    );
    await t.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 250)),
    );
    await t.pumpAndSettle();
  }

  Future<void> shot(WidgetTester t, String name) async {
    if (output.isEmpty) return;
    await t.runAsync(() async {
      final img =
          await (boundary.currentContext!.findRenderObject()!
                  as RenderRepaintBoundary)
              .toImage(pixelRatio: 2);
      final b = await img.toByteData(format: ui.ImageByteFormat.png);
      await File('$output/$name.png').writeAsBytes(b!.buffer.asUint8List());
      img.dispose();
    });
  }

  test(
    'ten distinct school topics, valid sequences and separate reward records',
    () {
      expect(schoolQuestions.length, 10);
      expect(schoolQuestions.map((q) => q.id).toSet().length, 10);
      final store = TransportProgress(persist: false);
      for (final q in [...transportQuestions, ...schoolQuestions]) {
        if (q.kind == QuestionKind.sequence) {
          expect(
            q.order.toSet(),
            Set.of(List.generate(q.options.length, (i) => i)),
          );
        }
        store.submit(q, true);
        expect(store.complete(q.id), 10);
      }
      expect(store.completed, 20);
      expect(store.xp, 520);
      store.restart('school-work-1');
      store.submit(schoolQuestions.first, true);
      expect(store.complete('school-work-1'), 0);
    },
  );

  testWidgets(
    'wrong sorting returns object; third error requires retry and clears placements',
    (t) async {
      final store = TransportProgress(persist: false);
      await mount(t, 4, store);
      Future<void> drag(String id, Offset delta) async {
        final f = find.byKey(ValueKey('school-object-$id'));
        await t.ensureVisible(f);
        await t.pumpAndSettle();
        final g = await t.startGesture(t.getCenter(f));
        await t.pump(const Duration(milliseconds: 600));
        await g.moveBy(delta);
        await t.pump();
        await g.up();
        await t.pumpAndSettle();
      }

      await drag('laptop', const Offset(0, 100));
      for (var i = 0; i < 3; i++) {
        await drag('cup', const Offset(-200, 100));
      }
      expect(store.session('school-work-5').phase, 'review');
      expect(store.session('school-work-5').hasFailed, isTrue);
      expect(store.xp, 320);
      expect(find.text('학습 완료'), findsNothing);
      await t.ensureVisible(find.text('다시 풀기'));
      await t.tap(find.text('다시 풀기'));
      await t.pumpAndSettle();
      expect(store.session('school-work-5').placements, isEmpty);
      expect(
        find.byKey(const ValueKey('school-object-laptop')),
        findsOneWidget,
      );
      expect(t.takeException(), isNull);
    },
  );
  testWidgets('another person printout cannot be stored as own', (t) async {
    final store = TransportProgress(persist: false);
    await mount(t, 8, store);
    final f = find.byKey(const ValueKey('school-object-other-paper'));
    await t.ensureVisible(f);
    await t.pumpAndSettle();
    final g = await t.startGesture(t.getCenter(f));
    await t.pump(const Duration(milliseconds: 600));
    await g.moveBy(const Offset(100, 100));
    await t.pump();
    await g.up();
    await t.pumpAndSettle();
    expect(store.session('school-work-9').attempts, 1);
    expect(store.session('school-work-9').placements, isEmpty);
    expect(store.session('school-work-9').phase, 'question');
    expect(
      find.byKey(const ValueKey('school-object-other-paper')),
      findsOneWidget,
    );
    expect(t.takeException(), isNull);
  });
  for (var i = 0; i < 10; i++) {
    testWidgets('school topic ${i + 1} opens, input and explanation', (
      t,
    ) async {
      final store = TransportProgress(persist: false);
      await mount(t, i, store);
      expect(find.text('학교·직장 매너'), findsOneWidget);
      await shot(t, 'school_${i + 1}');
      final q = schoolQuestions[i];
      if (q.kind == QuestionKind.choice) {
        await t.ensureVisible(find.text('B'));
        await t.tap(find.text('B'));
      }
      if (q.kind == QuestionKind.sequence) {
        store.session(q.id).order = List.of(q.order);
        await t.pumpWidget(const SizedBox());
        await mount(t, i, store);
        await t.ensureVisible(find.text('정답 확인하기'));
        await t.tap(find.text('정답 확인하기'));
      }
      if (q.kind == QuestionKind.touch) {
        final button = find.byKey(const ValueKey('meeting-action-0'));
        await t.ensureVisible(button);
        await t.tap(button);
      }
      if (q.kind == QuestionKind.drag) {
        Future<void> drag(String id, Offset delta) async {
          final object = find.byKey(ValueKey('school-object-$id'));
          await t.ensureVisible(object);
          await t.pumpAndSettle();
          final g = await t.startGesture(t.getCenter(object));
          await t.pump(const Duration(milliseconds: 600));
          await g.moveBy(delta);
          await t.pump();
          await g.up();
          await t.pumpAndSettle();
        }

        if (q.number == 5) {
          await drag('laptop', const Offset(0, 100));
          expect(store.session(q.id).placements, {'laptop': 'bag'});
          expect(store.session(q.id).attempts, 0);
          final saved = QuestionSession.fromJson(store.session(q.id).toJson());
          store.sessions[q.id] = saved;
          await t.pumpWidget(const SizedBox());
          await mount(t, i, store);
          expect(
            find.byKey(const ValueKey('school-object-laptop')),
            findsNothing,
          );
          await drag('book', const Offset(-100, 100));
          await drag('cup', const Offset(0, 100));
        } else {
          await drag('own-paper', const Offset(190, 100));
        }
      }
      await t.pumpAndSettle();
      expect(store.session(q.id).phase, 'explanation');
      expect(find.text(q.explanation), findsOneWidget);
      expect(store.completed, 0);
      if (q.kind == QuestionKind.touch || q.kind == QuestionKind.drag) {
        expect(find.byType(SchoolSceneArtwork), findsOneWidget);
        await shot(t, 'school_${i + 1}_after');
      }
      await t.ensureVisible(find.text('학습 완료'));
      await t.tap(find.text('학습 완료'));
      await t.pumpAndSettle();
      expect(store.xp, 330);
      expect(t.takeException(), isNull);
    });
  }
}

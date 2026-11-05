import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mannerfit/screens/dining_questions.dart';
import 'package:mannerfit/screens/dining_action_scene.dart';
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
            categoryId: 'dining',
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
    'ten distinct dining topics, valid sequences and separate reward records',
    () {
      expect(diningQuestions.length, 10);
      expect(diningQuestions.map((q) => q.id).toSet().length, 10);
      final store = TransportProgress(persist: false);
      for (final q in [...transportQuestions, ...diningQuestions]) {
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
      store.restart('dining-1');
      store.submit(diningQuestions.first, true);
      expect(store.complete('dining-1'), 0);
    },
  );
  for (var i = 0; i < 10; i++) {
    testWidgets('dining topic ${i + 1} opens, input and explanation', (
      t,
    ) async {
      final store = TransportProgress(persist: false);
      await mount(t, i, store);
      expect(find.text('식사 매너'), findsOneWidget);
      await shot(t, 'dining_${i + 1}');
      final q = diningQuestions[i];
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
      if (q.kind == QuestionKind.touch && q.number == 7) {
        final scene = find.byKey(const ValueKey('dining-action'));
        await t.ensureVisible(scene);
        await t.pumpAndSettle();
        final r = t.getRect(scene);
        await t.tapAt(Offset(r.left + r.width * .8, r.top + r.height * .75));
      }
      if (q.kind == QuestionKind.drag) {
        final bag = find.byKey(const ValueKey('dining-drag-object'));
        await t.ensureVisible(bag);
        await t.pumpAndSettle();
        final g = await t.startGesture(t.getCenter(bag));
        await t.pump(const Duration(milliseconds: 600));
        await g.moveBy(const Offset(130, -40));
        await t.pump();
        await g.up();
      }
      await t.pumpAndSettle();
      expect(store.session(q.id).phase, 'explanation');
      expect(find.text(q.explanation), findsOneWidget);
      expect(store.completed, 0);
      if (q.kind == QuestionKind.touch || q.kind == QuestionKind.drag) {
        expect(find.byType(DiningSceneArtwork), findsOneWidget);
        await shot(t, 'dining_${i + 1}_after');
      }
      await t.ensureVisible(find.text('학습 완료'));
      await t.tap(find.text('학습 완료'));
      await t.pumpAndSettle();
      expect(store.xp, 330);
      expect(t.takeException(), isNull);
    });
  }
}

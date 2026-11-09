import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mannerfit/screens/digital_questions.dart';
import 'package:mannerfit/screens/digital_action_scene.dart';
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
          ('Korean', const String.fromEnvironment('PREVIEW_FONT')),
          ('MaterialIcons', const String.fromEnvironment('PREVIEW_ICONS_FONT')),
        ]) {
          if (entry.$2.isEmpty) continue;
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
            categoryId: 'digital',
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
    'ten distinct digital topics, valid sequences and separate reward records',
    () {
      expect(digitalQuestions.length, 10);
      expect(digitalQuestions.map((q) => q.id).toSet().length, 10);
      final store = TransportProgress(persist: false);
      for (final q in [...transportQuestions, ...digitalQuestions]) {
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
      store.restart('digital-1');
      store.submit(digitalQuestions.first, true);
      expect(store.complete('digital-1'), 0);
    },
  );

  testWidgets(
    'wrong order is red with X, keeps arrangement and hides solution',
    (t) async {
      final store = TransportProgress(persist: false);
      await mount(t, 2, store);
      final q = digitalQuestions[2];
      final order = List.of(store.session(q.id).order);
      await t.ensureVisible(find.text('정답 확인하기'));
      await t.tap(find.text('정답 확인하기'));
      await t.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('action-wrong-feedback')),
        findsOneWidget,
      );
      expect(find.byIcon(Icons.cancel), findsOneWidget);
      expect(store.session(q.id).order, order);
      expect(find.text(q.explanation), findsNothing);
      expect(store.session(q.id).attempts, 1);
      await t.ensureVisible(
        find.byKey(const ValueKey('action-wrong-feedback')),
      );
      await shot(t, 'digital_sequence_wrong');
    },
  );
  testWidgets('wrong window drop returns and shows red X, project stays open', (
    t,
  ) async {
    final store = TransportProgress(persist: false);
    await mount(t, 6, store);
    final f = find.byKey(const ValueKey('digital-window-messenger'));
    await t.ensureVisible(f);
    await t.pumpAndSettle();
    final scene = find.byKey(const ValueKey('digital-action'));
    final before = t.getTopLeft(f) - t.getTopLeft(scene);
    final g = await t.startGesture(t.getCenter(f));
    await t.pump(const Duration(milliseconds: 600));
    await g.moveBy(const Offset(0, -20));
    await t.pump();
    await g.up();
    await t.pumpAndSettle();
    expect(store.session('digital-7').attempts, 1);
    expect(store.session('digital-7').placements, isEmpty);
    expect(t.getTopLeft(f) - t.getTopLeft(scene), before);
    expect(find.byKey(const ValueKey('digital-project')), findsOneWidget);
    expect(find.byKey(const ValueKey('action-wrong-feedback')), findsOneWidget);
    final frame = t.widget<Container>(
      find.byKey(const ValueKey('drag-feedback-frame')),
    );
    expect(
      ((frame.decoration as BoxDecoration).border as Border).top.color,
      const Color(0xFFD84C50),
    );
    await t.ensureVisible(find.byKey(const ValueKey('action-wrong-feedback')));
    await shot(t, 'digital_drag_wrong');
    expect(t.takeException(), isNull);
  });
  for (var i = 0; i < 10; i++) {
    testWidgets('digital topic ${i + 1} opens, input and explanation', (
      t,
    ) async {
      final store = TransportProgress(persist: false);
      await mount(t, i, store);
      expect(find.text('디지털 매너'), findsOneWidget);
      await shot(t, 'digital_${i + 1}');
      final q = digitalQuestions[i];
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
        if (q.number == 2) {
          final f = find.byKey(const ValueKey('digital-label'));
          await t.ensureVisible(f);
          await t.pumpAndSettle();
          await t.tap(f);
        } else {
          final f = find.byKey(const ValueKey('digital-lock-0'));
          await t.ensureVisible(f);
          await t.tap(f);
        }
      }
      if (q.kind == QuestionKind.drag) {
        Future<void> drag(String id, Offset delta) async {
          final f = find.byKey(ValueKey('digital-window-$id'));
          await t.ensureVisible(f);
          await t.pumpAndSettle();
          final g = await t.startGesture(t.getCenter(f));
          await t.pump(const Duration(milliseconds: 600));
          await g.moveBy(delta);
          await t.pump();
          await g.up();
          await t.pumpAndSettle();
        }

        await drag('messenger', const Offset(160, -170));
        expect(store.session(q.id).placements, {'messenger': 'closed'});
        expect(store.session(q.id).attempts, 0);
        final saved = QuestionSession.fromJson(store.session(q.id).toJson());
        store.sessions[q.id] = saved;
        await t.pumpWidget(const SizedBox());
        await mount(t, i, store);
        expect(
          find.byKey(const ValueKey('digital-window-messenger')),
          findsNothing,
        );
        await drag('contacts', const Offset(20, -170));
      }
      await t.pumpAndSettle();
      expect(store.session(q.id).phase, 'explanation');
      expect(find.text(q.explanation), findsOneWidget);
      expect(store.completed, 0);
      if (q.kind == QuestionKind.touch || q.kind == QuestionKind.drag) {
        expect(find.byType(DigitalActionScene), findsOneWidget);
        await shot(t, 'digital_${i + 1}_after');
      }
      await t.ensureVisible(find.text('학습 완료'));
      await t.tap(find.text('학습 완료'));
      await t.pumpAndSettle();
      expect(store.xp, 330);
      expect(t.takeException(), isNull);
    });
  }
}

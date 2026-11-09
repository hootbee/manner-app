import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mannerfit/screens/conversation_questions.dart';
import 'package:mannerfit/screens/conversation_action_scene.dart';
import 'package:mannerfit/screens/transport_questions.dart';
import 'package:mannerfit/screens/transport_progress.dart';
import 'package:mannerfit/screens/transport_lesson_screen.dart';

void main() {
  testWidgets(
    'speaking turn rejects early touch and accepts after friend finishes',
    (t) async {
      final answers = <bool>[];
      await t.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 320,
              height: 320,
              child: ConversationActionScene(
                number: 2,
                answered: false,
                success: false,
                onAnswer: answers.add,
              ),
            ),
          ),
        ),
      );
      final bubble = find.byKey(const ValueKey('my-speech-bubble'));
      await t.tapAt(t.getCenter(bubble));
      await t.pump();
      expect(answers, [false]);
      await t.pump(const Duration(seconds: 3));
      await t.tapAt(t.getCenter(bubble));
      await t.pump();
      expect(answers, [false, true]);
      expect(t.takeException(), isNull);
    },
  );
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
            categoryId: 'conversation',
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
    'ten distinct conversation topics, valid sequences and separate reward records',
    () {
      expect(conversationQuestions.length, 10);
      expect(conversationQuestions.map((q) => q.id).toSet().length, 10);
      final store = TransportProgress(persist: false);
      for (final q in [...transportQuestions, ...conversationQuestions]) {
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
      store.restart('conversation-1');
      store.submit(conversationQuestions.first, true);
      expect(store.complete('conversation-1'), 0);
    },
  );
  for (var i = 0; i < 10; i++) {
    testWidgets('conversation topic ${i + 1} opens, input and explanation', (
      t,
    ) async {
      final store = TransportProgress(persist: false);
      await mount(t, i, store);
      expect(find.text('대화 매너'), findsOneWidget);
      await shot(t, 'conversation_${i + 1}');
      final q = conversationQuestions[i];
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
        final scene = find.byKey(const ValueKey('conversation-action'));
        await t.ensureVisible(scene);
        await t.pumpAndSettle();
        if (q.number == 2) {
          await t.pump(const Duration(seconds: 3));
          await t.pumpAndSettle();
        }
        final r = t.getRect(scene);
        await t.tapAt(
          Offset(
            r.left + r.width * (q.number == 2 ? .75 : .3),
            r.top + r.height * .8,
          ),
        );
      }
      if (q.kind == QuestionKind.drag) {
        final bag = find.byKey(const ValueKey('conversation-phone'));
        await t.ensureVisible(bag);
        await t.pumpAndSettle();
        final g = await t.startGesture(t.getCenter(bag));
        await t.pump(const Duration(milliseconds: 600));
        await g.moveBy(const Offset(180, 0));
        await t.pump();
        await g.up();
      }
      await t.pumpAndSettle();
      expect(store.session(q.id).phase, 'explanation');
      expect(find.text(q.explanation), findsOneWidget);
      expect(store.completed, 0);
      if (q.kind == QuestionKind.touch || q.kind == QuestionKind.drag) {
        expect(find.byType(ConversationSceneArtwork), findsOneWidget);
        await shot(t, 'conversation_${i + 1}_after');
      }
      await t.ensureVisible(find.text('학습 완료'));
      await t.tap(find.text('학습 완료'));
      await t.pumpAndSettle();
      expect(store.xp, 330);
      expect(t.takeException(), isNull);
    });
  }
}

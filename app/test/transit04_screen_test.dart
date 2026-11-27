import 'result_popup_test_helpers.dart';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mannerfit/screens/choice_lesson_state.dart';
import 'package:mannerfit/screens/lesson_explanation_content.dart';
import 'package:mannerfit/screens/lesson_explanation_screen.dart';
import 'package:mannerfit/screens/lesson_feedback_sound.dart';
import 'package:mannerfit/screens/manners_hint_bubble.dart';
import 'package:mannerfit/screens/manners_lesson_progress.dart';
import 'package:mannerfit/screens/partner_selection_screen.dart';
import 'package:mannerfit/screens/sequence_lesson_state.dart';
import 'package:mannerfit/screens/transit04_screen.dart';
import 'package:mannerfit/screens/transport_lesson_screen.dart';
import 'package:mannerfit/screens/transport_progress.dart';
import 'package:mannerfit/screens/transport_questions.dart';

final boundary = GlobalKey();
const captureDir = String.fromEnvironment('TRANSIT04_CAPTURE_DIR');
int frame = 0;

Future<void> capture(WidgetTester t, String name, {int copies = 8}) async {
  if (captureDir.isEmpty) return;
  await t.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 80)),
  );
  // Repaint cached descendant layers for a complete offscreen test capture.
  void repaint(RenderObject object) {
    object.markNeedsPaint();
    object.visitChildren(repaint);
  }

  repaint(boundary.currentContext!.findRenderObject()!);
  await t.pump();
  await t.runAsync(() async {
    final b =
        boundary.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final image = await b.toImage();
    final bytes = (await image.toByteData(format: ui.ImageByteFormat.png))!;
    final dir = Directory(captureDir)..createSync(recursive: true);
    await File(
      '${dir.path}/$name.png',
    ).writeAsBytes(bytes.buffer.asUint8List());
    for (var i = 0; i < copies; i++) {
      await File(
        '${dir.path}/video-${(frame++).toString().padLeft(4, '0')}.png',
      ).writeAsBytes(bytes.buffer.asUint8List());
    }
    image.dispose();
  });
}

void evict() {
  rootBundle.evict('assets/transit04/problem_sequence_transit04.json');
  rootBundle.evict('assets/transit04/explanation.json');
}

Future<void> ready(WidgetTester t, [String key = 'sequence-ready']) async {
  for (var i = 0; i < 400 && find.byKey(Key(key)).evaluate().isEmpty; i++) {
    await t.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 25)),
    );
    await t.pump(const Duration(milliseconds: 10));
  }
  expect(find.byKey(Key(key)), findsOneWidget);
}

SequenceLessonState state(WidgetTester t) =>
    t
            .widget<ListenableBuilder>(find.byKey(const Key('sequence-ready')))
            .listenable
        as SequenceLessonState;

Future<void> tap(WidgetTester t, Finder finder) async {
  await dismissResultPopup(t);
  if (finder.evaluate().isEmpty) {
    await dismissResultPopup(t);
    await t.scrollUntilVisible(
      finder,
      160,
      scrollable: find.byType(Scrollable).first,
    );
  }
  await dismissResultPopup(t);
  await t.ensureVisible(finder);
  await t.pumpAndSettle();
  await tapAfterResult(t, finder);
  await t.pump();
}

void orderAs(SequenceLessonState s, List<String> wanted) {
  for (var target = 0; target < wanted.length; target++) {
    final old = s.order.indexOf(wanted[target]);
    if (old != target) s.reorder(old, target > old ? target + 1 : target);
  }
}

Future<void> mount(
  WidgetTester t, {
  Size size = const Size(393, 900),
  double scale = 1,
  bool reduced = false,
  MannerPartner partner = MannerPartner.cat,
  List<LessonFeedbackSound>? sounds,
}) async {
  t.view.physicalSize = size;
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.resetPhysicalSize);
  addTearDown(t.view.resetDevicePixelRatio);
  evict();
  await t.pumpWidget(
    RepaintBoundary(
      key: boundary,
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          fontFamily: 'Pretendard',
          colorSchemeSeed: const Color(0xFF191D1A),
        ),
        builder: (c, child) => MediaQuery(
          data: MediaQuery.of(c).copyWith(
            textScaler: TextScaler.linear(scale),
            disableAnimations: reduced,
          ),
          child: child!,
        ),
        home: Transit04Screen(
          partner: partner,
          random: Random(7),
          soundMuted: reduced,
          playSound: (sound) async {
            sounds?.add(sound);
          },
        ),
      ),
    ),
  );
  await ready(t);
  await t.pumpAndSettle();
}

void main() {
  final q = SequenceQuestion.fromJson(
    jsonDecode(
      File(
        'assets/transit04/problem_sequence_transit04.json',
      ).readAsStringSync(),
    ),
  );
  final education = LessonExplanationContent.fromJson(
    jsonDecode(File('assets/transit04/explanation.json').readAsStringSync()),
  );

  test('approved data and every educational paragraph are preserved', () {
    expect(transportQuestions[3].title, q.title);
    expect(transportQuestions[3].hints, q.hints);
    expect(q.correctOrder, ['hold', 'observe', 'wait', 'exit']);
    final md = File(
      '../docs/design/education_content_transit04.md',
    ).readAsStringSync().replaceAll('\r\n', '\n');
    expect(education.reasons.length, 3);
    expect(education.faqs.length, 3);
    expect(education.sources.length, 2);
    for (final r in education.reasons) {
      expect(md, contains(r.title));
      expect(md, contains(r.body));
    }
    for (final f in education.faqs) {
      expect(md, contains(f.question));
      expect(md, contains(f.answer));
    }
    expect(md, contains(education.extraSections.single.body));
    expect(education.allText, contains('권장 흐름의 의미'));
    expect(education.allText, contains('법정 하차 순서를 뜻하지 않습니다.'));
    for (final source in education.sources) {
      expect(md, contains(source.url.toString()));
    }
    for (final c in q.cards) {
      expect(File('assets/transit04/${c.thumbnail}').existsSync(), isTrue);
    }
  });

  testWidgets(
    'native drag, hints, 4 failures, explicit reveal, explanation and replay',
    (t) async {
      await t.runAsync(() async {
        await (FontLoader('Pretendard')
              ..addFont(
                rootBundle.load(
                  'assets/fonts/pretendard/Pretendard-Regular.otf',
                ),
              )
              ..addFont(
                rootBundle.load(
                  'assets/fonts/pretendard/Pretendard-SemiBold.otf',
                ),
              )
              ..addFont(
                rootBundle.load('assets/fonts/pretendard/Pretendard-Bold.otf'),
              ))
            .load();
        const icons = String.fromEnvironment('PREVIEW_ICONS_FONT');
        if (icons.isNotEmpty) {
          await (FontLoader('MaterialIcons')
                ..addFont(File(icons).readAsBytes().then(ByteData.sublistView)))
              .load();
        }
      });
      frame = 0;
      final sounds = <LessonFeedbackSound>[];
      await mount(t, sounds: sounds);
      final s = state(t), initial = List<String>.of(state(t).order);
      final primary = find.byKey(const Key('sequence-primary'));
      expect(t.widget<FilledButton>(primary).onPressed, isNull);
      expect(s.order, isNot(q.correctOrder));
      await capture(t, '01-initial');
      final scroll = t
          .state<ScrollableState>(find.byType(Scrollable).first)
          .position;
      scroll.jumpTo(390);
      await t.pumpAndSettle();
      final first = find.byKey(ValueKey('sequence-handle-${s.order.first}'));
      final second = find.byKey(ValueKey('sequence-handle-${s.order[1]}'));
      final start = t.getCenter(first),
          end = t.getCenter(second) + const Offset(0, 22);
      final noop = await t.startGesture(start);
      await t.pump(const Duration(milliseconds: 150));
      await noop.up();
      await t.pumpAndSettle();
      expect(s.hasReordered, isFalse);
      final gesture = await t.startGesture(start);
      await t.pump(const Duration(milliseconds: 150));
      for (var i = 1; i <= 10; i++) {
        await gesture.moveTo(Offset.lerp(start, end, i / 10)!);
        await t.pump(const Duration(milliseconds: 50));
        expect(s.validSubmissions, 0);
        expect(t.widget<FilledButton>(primary).onPressed, isNull);
        await capture(t, 'drag-$i', copies: 1);
      }
      await gesture.up();
      await t.pumpAndSettle();
      expect(s.order, [initial[1], initial[0], ...initial.skip(2)]);
      expect(s.validSubmissions, 0);
      expect(t.widget<FilledButton>(primary).onPressed, isNotNull);
      for (final id in s.order) {
        final card = find.byKey(ValueKey(id));
        expect(
          find.descendant(of: card, matching: find.text(q.card(id).label)),
          findsOneWidget,
        );
        expect(
          t.getSize(find.byKey(ValueKey('sequence-handle-$id'))),
          const Size(44, 44),
        );
      }
      await capture(t, '02-reordered');
      final current = List<String>.of(s.order);
      await tap(t, find.byKey(const Key('sequence-hint')));
      expect(s.order, current);
      expect(s.hintStep, 1);
      final hint = find.byType(MannersHintBubble);
      expect(t.widget<MannersHintBubble>(hint).partner, MannerPartner.cat);
      final h = t.getSize(hint);
      await capture(t, '03-hint-one');
      await tap(t, find.byKey(const Key('sequence-hint')));
      expect(t.getSize(hint), h);
      expect(s.order, current);
      expect(s.validSubmissions, 0);
      expect(s.hintStep, 2);
      await capture(t, '04-hint-two');
      orderAs(s, q.correctOrder.reversed.toList());
      final wrong = List<String>.of(s.order);
      await t.pump();
      for (var attempt = 1; attempt <= 4; attempt++) {
        await tapAfterResult(t, primary);
        await t.pump(const Duration(milliseconds: 75));
        expect(s.phase, SequencePhase.wrongJustJudged);
        expect(s.validSubmissions, attempt);
        expect(s.order, wrong);
        expect(t.widget<FilledButton>(primary).onPressed, isNull);
        s.submit();
        expect(s.validSubmissions, attempt);
        if (attempt == 1) await capture(t, '05-wrong-effect', copies: 2);
        await t.pump(const Duration(milliseconds: 1700));
        if (attempt < 4) {
          expect(s.phase, SequencePhase.wrongComplete);
          await tapAfterResult(t, primary);
          await t.pumpAndSettle();
          expect(s.order, wrong);
          expect(s.hintStep, 2);
        }
      }
      expect(s.phase, SequencePhase.finalFailure);
      expect(s.order, wrong);
      expect(s.success, isFalse);
      expect(find.text('정답 확인'), findsOneWidget);
      await capture(t, '06-final-failure');
      await tapAfterResult(t, primary);
      await t.pumpAndSettle();
      expect(s.order, q.correctOrder);
      expect(s.success, isFalse);
      expect(s.solutionRevealed, isTrue);
      await capture(t, '07-answer-revealed');
      await tapAfterResult(t, primary);
      await t.pumpAndSettle();
      expect(find.text(education.reasons.first.title), findsNothing);
      expect(
        t
            .widget<FilledButton>(find.byKey(const Key('explanation-next')))
            .onPressed,
        isNotNull,
      );
      // Exercise both directions before recording the collapsed summary; this
      // also flushes the route's cached offscreen layers in widget screenshots.
      await tap(t, find.byKey(const Key('explanation-toggle')));
      await t.pumpAndSettle();
      await tap(t, find.byKey(const Key('explanation-toggle')));
      await t.pumpAndSettle();
      await capture(t, '08-summary');
      await tap(t, find.byKey(const Key('explanation-toggle')));
      await t.pumpAndSettle();
      await capture(t, '09-details');
      for (var i = 0; i < 3; i++) {
        await dismissResultPopup(t);
        await t.ensureVisible(find.text(education.reasons[i].title));
        await t.pumpAndSettle();
        expect(t.takeException(), isNull);
      }
      await dismissResultPopup(t);
      await t.ensureVisible(find.byKey(const Key('explanation-extra-0')));
      await t.pumpAndSettle();
      await capture(t, '10-recommended-flow');
      await dismissResultPopup(t);
      await t.ensureVisible(find.byKey(const Key('explanation-source-1')));
      await t.pumpAndSettle();
      await capture(t, '11-sources');
      await tapAfterResult(t, find.byKey(const Key('explanation-replay')));
      await t.pumpAndSettle();
      expect(s.validSubmissions, 0);
      expect(s.hintStep, 0);
      expect(s.hasReordered, isFalse);
      expect(s.order, isNot(q.correctOrder));
      expect(sounds, List.filled(4, LessonFeedbackSound.wrong));
      await capture(t, '12-replay');
      scroll.jumpTo(390);
      await t.pumpAndSettle();
      final beforeUp = List<String>.of(s.order);
      final lastHandle = find.byKey(
        ValueKey('sequence-handle-${s.order.last}'),
      );
      final firstHandle = find.byKey(
        ValueKey('sequence-handle-${s.order.first}'),
      );
      await t.timedDragFrom(
        t.getCenter(lastHandle),
        t.getCenter(firstHandle) -
            t.getCenter(lastHandle) -
            const Offset(0, 22),
        const Duration(milliseconds: 600),
      );
      await t.pumpAndSettle();
      expect(s.order, [beforeUp.last, ...beforeUp.take(3)]);
      expect(s.validSubmissions, 0);
      orderAs(s, q.correctOrder);
      await t.pump();
      await capture(t, '13-ready-to-submit');
      expect(s.success, isFalse);
      await tapAfterResult(t, primary);
      await t.pump(const Duration(milliseconds: 100));
      await capture(t, '14-correct-effect', copies: 2);
      await t.pump(const Duration(milliseconds: 1700));
      await t.pumpAndSettle();
      expect(s.phase, SequencePhase.correctComplete);
      await capture(t, '15-correct-complete');
      expect(sounds.last, LessonFeedbackSound.correct);
      expect(t.takeException(), isNull);
    },
  );

  for (final size in [const Size(320, 640), const Size(852, 393)]) {
    testWidgets(
      'large type, reduced motion, mute and successful submit $size',
      (t) async {
        final sounds = <LessonFeedbackSound>[];
        await mount(t, size: size, scale: 2, reduced: true, sounds: sounds);
        final s = state(t);
        orderAs(s, q.correctOrder);
        await t.pump();
        expect(s.validSubmissions, 0);
        expect(s.success, isFalse);
        final primary = find.byKey(const Key('sequence-primary'));
        expect(t.getRect(primary).bottom, lessThanOrEqualTo(size.height));
        await tapAfterResult(t, primary);
        await t.pump(const Duration(milliseconds: 1800));
        expect(s.phase, SequencePhase.correctComplete);
        expect(sounds, isEmpty);
        await tapAfterResult(t, primary);
        await t.pumpAndSettle();
        await tap(t, find.byKey(const Key('explanation-toggle')));
        await t.pumpAndSettle();
        await dismissResultPopup(t);
        await t.ensureVisible(find.byKey(const Key('explanation-source-1')));
        await t.pumpAndSettle();
        expect(t.takeException(), isNull);
      },
    );
  }

  testWidgets(
    '03 application then 04 preserves selected partner and stored rewards',
    (t) async {
      t.view.physicalSize = const Size(393, 900);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.resetPhysicalSize);
      addTearDown(t.view.resetDevicePixelRatio);
      for (final file in [
        'problem_choice_subway03.json',
        'explanation.json',
        'scene_layout.json',
      ]) {
        rootBundle.evict('assets/subway03/$file');
      }
      for (final name in [
        'asset_rules',
        'problem_choice_transit03',
        'state_asset_mapping',
      ]) {
        rootBundle.evict('assets/application03/spec/$name.json');
      }
      rootBundle.evict(
        'assets/application03/content/education_content_transit03.md',
      );
      evict();
      final store = TransportProgress(persist: false);
      addTearDown(store.dispose);
      store.sessions['transport-4'] = QuestionSession(
        phase: 'complete',
        attempts: 2,
        firstCompletedAt: DateTime(2026, 1, 1),
      );
      final before = jsonEncode(store.session('transport-4').toJson()),
          xp = store.xp;
      await t.pumpWidget(
        MaterialApp(
          home: TransportLessonScreen(
            index: 2,
            partner: MannerPartner.monkey,
            store: store,
          ),
        ),
      );
      await ready(t, 'subway03-ready');
      final choice =
          t
                  .widget<ListenableBuilder>(
                    find.byKey(const Key('subway03-ready')),
                  )
                  .listenable
              as ChoiceLessonState;
      choice.select('B');
      choice.submit();
      choice.settle();
      await t.pump();
      await tap(t, find.byKey(const Key('subway03-primary')));
      await t.pumpAndSettle();
      await tapAfterResult(t, find.byKey(const Key('explanation-next')));
      await t.pump(const Duration(milliseconds: 400));
      await ready(t, 'application03-ready');
      await t.pumpAndSettle();
      final application =
          t
                  .widget<ListenableBuilder>(
                    find.byKey(const Key('application03-ready')),
                  )
                  .listenable
              as ChoiceLessonState;
      await tap(t, find.byKey(const ValueKey('choice-B')));
      expect(application.validSubmissions, 0);
      await tap(t, find.byKey(const Key('application03-primary')));
      await t.pump(const Duration(milliseconds: 300));
      await dismissResultPopup(t);
      await t.pumpAndSettle();
      expect(application.success, isTrue);
      await tap(t, find.byKey(const Key('application03-primary')));
      await t.pumpAndSettle();
      expect(find.text('응용 03/20 · 2/2'), findsOneWidget);
      await tapAfterResult(t, find.byKey(const Key('explanation-next')));
      await t.pump(const Duration(milliseconds: 400));
      await ready(t);
      expect(
        t.widget<Transit04Screen>(find.byType(Transit04Screen)).partner,
        MannerPartner.monkey,
      );
      final s = state(t);
      orderAs(s, q.correctOrder);
      s.submit();
      s.settle();
      await t.pump();
      await tapAfterResult(t, find.byKey(const Key('sequence-primary')));
      await t.pumpAndSettle();
      await tapAfterResult(t, find.byKey(const Key('explanation-replay')));
      await t.pumpAndSettle();
      expect(store.xp, xp);
      expect(jsonEncode(store.session('transport-4').toJson()), before);
      expect(t.takeException(), isNull);
    },
  );

  if (captureDir.isNotEmpty) {
    testWidgets('capture summary without retained route layers', (t) async {
      t.view.physicalSize = const Size(393, 900);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.resetPhysicalSize);
      addTearDown(t.view.resetDevicePixelRatio);
      await t.pumpWidget(
        RepaintBoundary(
          key: boundary,
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: ThemeData(fontFamily: 'Pretendard'),
            home: LessonExplanationScreen(
              content: education,
              partner: MannerPartner.cat,
              progressHeader: const MannersLessonProgress(number: 4),
              answerRevealed: true,
            ),
          ),
        ),
      );
      await t.pumpAndSettle();
      await capture(t, '08-summary');
    });
  }
}

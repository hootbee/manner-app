import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mannerfit/screens/common_result_popup.dart';
import 'package:mannerfit/screens/lesson_feedback_sound.dart';
import 'package:mannerfit/screens/action_drag_state.dart';
import 'package:mannerfit/screens/choice_lesson_state.dart';
import 'package:mannerfit/screens/sequence_lesson_state.dart';
import 'package:mannerfit/screens/recline_lesson_state.dart';
import 'package:mannerfit/screens/partner_selection_screen.dart';
import 'package:mannerfit/screens/subway01_screen.dart';
import 'package:mannerfit/screens/subway02_screen.dart';
import 'package:mannerfit/screens/subway03_screen.dart';
import 'package:mannerfit/screens/transit04_screen.dart';
import 'package:mannerfit/screens/transit05_screen.dart';
import 'package:mannerfit/screens/transit06_screen.dart';
import 'transit04_screen_test.dart' as fixture;
import 'transit06_screen_test.dart' as recline;
import 'sequence_feedback_revision_test.dart' as fonts;

final popup = find.byKey(const Key('common-result-popup'));
Future<void> dismissResultPopup(WidgetTester t) async {
  if (popup.evaluate().isNotEmpty) {
    await t.tapAt(const Offset(5, 5));
    await t.pumpAndSettle();
  }
}

String readyKey(int n) => switch (n) {
  1 => 'subway01-ready',
  2 => 'subway02-ready',
  3 => 'subway03-ready',
  4 => 'sequence-ready',
  5 => 'transit05-ready',
  _ => 'transit06-ready',
};
dynamic lessonState(WidgetTester t, int n) =>
    t.widget<ListenableBuilder>(find.byKey(Key(readyKey(n)))).listenable;
String fingerprint(dynamic s) => switch (s) {
  ActionDragState() =>
    '${s.phase}/${s.wrongAttempts}/${s.delta}/${s.hint}/${s.revealed}',
  ChoiceLessonState() =>
    '${s.phase}/${s.validSubmissions}/${s.selectedId}/${s.hintStep}',
  SequenceLessonState() =>
    '${s.phase}/${s.validSubmissions}/${s.order}/${s.hintStep}',
  ReclineLessonState() =>
    '${s.phase}/${s.attempts}/${s.progress}/${s.consent}/${s.hint}',
  _ => throw StateError('Unexpected state'),
};
Future<void> mountLesson(
  WidgetTester t,
  int n,
  MannerPartner partner,
  List<LessonFeedbackSound> sounds,
) async {
  t.view.physicalSize = const Size(390, 844);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.resetPhysicalSize);
  addTearDown(t.view.resetDevicePixelRatio);
  for (final path in [
    'subway01/asset_rules.json',
    'subway01/state_asset_mapping.json',
    'subway02/asset_rules.json',
    'subway02/state_asset_mapping.json',
    'subway03/problem_choice_subway03.json',
    'subway03/explanation.json',
    'subway03/scene_layout.json',
    'transit04/problem_sequence_transit04.json',
    'transit04/explanation.json',
    'transit05/problem_choice_transit05.json',
    'transit05/explanation.json',
    'transit05/scene_layout.json',
    'transit06/runtime_manifest.json',
    'transit06/state_asset_mapping.json',
    'transit06/problem_transit06.json',
    'transit06/explanation.json',
  ]) {
    rootBundle.evict('assets/$path');
  }
  final Widget lesson = switch (n) {
    1 => Subway01Screen(partner: partner),
    2 => Subway02Screen(partner: partner),
    3 => Subway03Screen(partner: partner),
    4 => Transit04Screen(partner: partner),
    5 => Transit05Screen(partner: partner),
    _ => Transit06Screen(partner: partner),
  };
  await t.pumpWidget(
    ResultPopupAudioScope(
      play: (s) async {
        sounds.add(s);
      },
      child: RepaintBoundary(
        key: fixture.boundary,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: ThemeData(fontFamily: 'Pretendard'),
          home: lesson,
        ),
      ),
    ),
  );
  await fixture.ready(t, readyKey(n));
  await fonts.captureFonts(t);
  await t.pumpAndSettle();
}

Future<void> judge(
  WidgetTester t,
  int n,
  bool correct,
  MannerPartner partner,
) async {
  final dynamic s = lessonState(t, n);
  if (n <= 2) {
    final scene = find.byKey(Key(n == 1 ? 'subway01-scene' : 'subway02-scene'));
    await t.ensureVisible(scene);
    await t.pumpAndSettle();
    final rect = t.getRect(scene);
    Offset toScreen(Offset p) =>
        rect.topLeft +
        Offset(p.dx * rect.width / 1536, p.dy * rect.height / 1024);
    final start = n == 1 ? const Offset(965, 720) : const Offset(820, 720);
    final end = n == 1
        ? start +
              (correct ? const Offset(774, 727) : const Offset(300, 920)) -
              const Offset(901, 697)
        : start + Offset(correct ? 380 : 80, 0);
    final g = await t.startGesture(toScreen(start));
    await g.moveTo(toScreen(end));
    await t.pump();
    expect(popup, findsNothing);
    await g.up();
    await t.pump();
  } else if (n == 3 || n == 5) {
    await fixture.tap(
      t,
      find.byKey(ValueKey(correct ? 'choice-B' : 'choice-A')),
    );
    expect(popup, findsNothing);
    await fixture.tap(
      t,
      find.byKey(Key(n == 3 ? 'subway03-primary' : 'transit05-primary')),
    );
  } else if (n == 4) {
    final seq = s as SequenceLessonState;
    final order = [...seq.question.correctOrder];
    if (!correct) {
      final first = order.removeAt(0);
      order.add(first);
    }
    // Exercise the existing reorder API followed by the real Submit handler.
    seq.reorder(0, 2);
    seq.reorder(1, 0);
    fixture.orderAs(seq, order);
    await t.pump();
    expect(popup, findsNothing);
    await fixture.tap(t, find.byKey(const Key('sequence-primary')));
  } else {
    if (correct && !(s as ReclineLessonState).consent) {
      await t.tapAt(recline.screen(t, const Offset(240, 300)));
      await t.pump();
      expect(popup, findsNothing);
      await t.pump(const Duration(milliseconds: 700));
    }
    final who = switch (partner) {
      MannerPartner.cat => 'nyangnyang',
      MannerPartner.dog => 'dangdang',
      MannerPartner.monkey => 'mongmong',
    };
    await recline.drag(t, who, .32);
  }
  expect(
    popup,
    findsNothing,
    reason: 'Existing feedback must precede the common popup',
  );
  await t.pump(const Duration(milliseconds: 2000));
  await t.pump();
  await t.pump(const Duration(milliseconds: 300));
  expect(popup, findsOneWidget);
}

Future<void> retry(WidgetTester t, int n) async {
  final finder = n <= 2
      ? find.text('다시 시도하기')
      : find.byKey(
          Key(
            n == 3
                ? 'subway03-primary'
                : n == 4
                ? 'sequence-primary'
                : n == 5
                ? 'transit05-primary'
                : 'transit06-primary',
          ),
        );
  await fixture.tap(t, finder);
  await t.pumpAndSettle();
}

void main() {
  test('supplied audio metadata points to the two original MP3 assets', () {
    final m = jsonDecode(
      File('assets/result_popup/audio_manifest.json').readAsStringSync(),
    );
    for (final name in ['correct', 'wrong']) {
      expect(
        File('assets/result_popup/audio/popup_$name.mp3').existsSync(),
        isTrue,
      );
      expect(m['mapping'][name]['file'], 'audio/popup_$name.mp3');
    }
  });
  test(
    'legacy and popup audio serialize, failures recover and mute adds no playback',
    () async {
      final done = Completer<void>(), events = <String>[];
      final legacy = playLessonFeedbackSound(
        (s) async {
          events.add('legacy');
          await done.future;
          events.add('legacy-done');
        },
        LessonFeedbackSound.wrong,
        muted: false,
      );
      final common = playLessonFeedbackSound(
        (s) async {
          events.add('popup');
        },
        LessonFeedbackSound.wrong,
        muted: false,
      );
      await Future<void>.delayed(Duration.zero);
      expect(events, ['legacy']);
      done.complete();
      await legacy;
      await common;
      expect(events, ['legacy', 'legacy-done', 'popup']);
      await playLessonFeedbackSound(
        (s) async {
          throw StateError('audio');
        },
        LessonFeedbackSound.correct,
        muted: false,
      );
      await playLessonFeedbackSound(
        (s) async {
          events.add('recovered');
        },
        LessonFeedbackSound.correct,
        muted: false,
      );
      await playLessonFeedbackSound(
        (s) async {
          events.add('muted');
        },
        LessonFeedbackSound.correct,
        muted: true,
      );
      expect(events.last, 'recovered');
    },
  );
  for (var n = 1; n <= 6; n++) {
    for (final correct in [false, true]) {
      testWidgets(
        '0$n ${correct ? 'correct' : 'wrong and fourth failure'} popup preserves lesson state',
        (t) async {
          final partner = MannerPartner.values[(n - 1) % 3];
          final sounds = <LessonFeedbackSound>[];
          await mountLesson(t, n, partner, sounds);
          for (var attempt = 1; attempt <= (correct ? 1 : 4); attempt++) {
            await judge(t, n, correct, partner);
            expect(
              t
                  .widget<CommonResultPopup>(find.byType(CommonResultPopup))
                  .partner,
              partner,
            );
            final before = fingerprint(lessonState(t, n));
            expect(find.text(correct ? '정답입니다!' : '오답입니다!'), findsOneWidget);
            if (!correct && attempt == 4) {
              expect(find.text('정답을 함께 확인해 볼까요?'), findsOneWidget);
            }
            expect(
              find.byKey(const Key('popup-confetti')),
              correct ? findsOneWidget : findsNothing,
            );
            await fixture.capture(
              t,
              '0$n-${correct
                  ? 'correct'
                  : attempt == 4
                  ? 'final-failure'
                  : 'wrong-$attempt'}',
            );
            await t.pump(const Duration(milliseconds: 1200));
            expect(popup, findsOneWidget);
            expect(find.byKey(const Key('popup-confetti')), findsNothing);
            expect(fingerprint(lessonState(t, n)), before);
            expect(sounds.length, attempt);
            // Both the card and dim area dismiss only the popup; no retry tap-through.
            if (attempt.isOdd) {
              await t.tap(popup);
            } else {
              await t.tapAt(const Offset(5, 5));
            }
            await t.pumpAndSettle();
            expect(popup, findsNothing);
            expect(fingerprint(lessonState(t, n)), before);
            if (!correct && attempt < 4) await retry(t, n);
          }
          expect(t.takeException(), isNull);
          await t.pumpWidget(const SizedBox());
        },
      );
    }
  }
  for (final size in [const Size(320, 640), const Size(844, 320)]) {
    testWidgets(
      'popup readable at $size and large text; no automatic dismissal',
      (t) async {
        t.view.physicalSize = size;
        t.view.devicePixelRatio = 1;
        addTearDown(t.view.resetPhysicalSize);
        addTearDown(t.view.resetDevicePixelRatio);
        final presenter = LessonResultPresenter();
        await t.pumpWidget(
          MaterialApp(
            builder: (c, child) => MediaQuery(
              data: MediaQuery.of(c).copyWith(
                textScaler: const TextScaler.linear(2),
                disableAnimations: true,
              ),
              child: child!,
            ),
            home: Builder(
              builder: (c) => TextButton(
                onPressed: () => presenter.show(
                  c,
                  partner: MannerPartner.dog,
                  correct: true,
                  finalFailure: false,
                  muted: true,
                ),
                child: const Text('show'),
              ),
            ),
          ),
        );
        await t.tap(find.text('show'));
        await t.pumpAndSettle();
        expect(popup, findsOneWidget);
        expect(find.byKey(const Key('popup-confetti')), findsNothing);
        await t.pump(const Duration(seconds: 10));
        expect(popup, findsOneWidget);
        expect(t.takeException(), isNull);
        await dismissResultPopup(t);
        presenter.dispose();
      },
    );
  }
}

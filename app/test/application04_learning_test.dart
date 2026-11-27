import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mannerfit/screens/application04_screen.dart';
import 'package:mannerfit/screens/lesson_explanation_screen.dart';
import 'package:mannerfit/screens/lesson_feedback_sound.dart';
import 'package:mannerfit/screens/manners_hint_bubble.dart';
import 'package:mannerfit/screens/partner_selection_screen.dart';
import 'package:mannerfit/screens/sequence_lesson_state.dart';
import 'package:mannerfit/screens/topic_completion.dart';
import 'package:mannerfit/screens/topic_completion_screen.dart';
import 'package:mannerfit/screens/transit04_screen.dart';
import 'application01_test.dart' as reward;
import 'sequence_feedback_revision_test.dart' as fonts;
import 'transit04_screen_test.dart' as fixture;
import 'result_popup_test_helpers.dart';

Iterable<List<String>> permutations(List<String> ids) sync* {
  if (ids.isEmpty) {
    yield [];
    return;
  }
  for (final id in ids) {
    for (final tail in permutations(ids.where((v) => v != id).toList())) {
      yield [id, ...tail];
    }
  }
}

Future<void> mount(
  WidgetTester t,
  MannerPartner p,
  reward.MemoryRewards memory, {
  int width = 390,
  double scale = 1,
  LearningEnd basic = LearningEnd.directCorrect,
  bool basicScreen = false,
  VoidCallback? onNext,
  List<LessonFeedbackSound>? sounds,
}) async {
  t.view.physicalSize = Size(width.toDouble(), 844);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.resetPhysicalSize);
  addTearDown(t.view.resetDevicePixelRatio);
  for (final f in [
    'spec/problem_sequence_transit04.json',
    'spec/state_asset_mapping.json',
    'spec/asset_rules.json',
    'content/explanation.json',
    'content/reward_policy.json',
  ]) {
    rootBundle.evict('assets/application04/$f');
  }
  rootBundle.evict('assets/application01/completion_screen_spec.json');
  await t.pumpWidget(
    TopicCompletionBinding(
      gateway: memory.gateway(),
      child: RepaintBoundary(
        key: fixture.boundary,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: ThemeData(fontFamily: 'Pretendard'),
          builder: (c, child) => MediaQuery(
            data: MediaQuery.of(
              c,
            ).copyWith(textScaler: TextScaler.linear(scale)),
            child: child!,
          ),
          home: basicScreen
              ? Transit04Screen(
                  partner: p,
                  soundMuted: true,
                  onNextProblem: onNext,
                )
              : Application04Screen(
                  partner: p,
                  basicOutcome: basic,
                  hasNextProblem: true,
                  playSound: sounds == null
                      ? null
                      : (v) async {
                          sounds.add(v);
                        },
                ),
        ),
      ),
    ),
  );
  await fixture.ready(t);
  await fonts.captureFonts(t);
  await t.pumpAndSettle();
}

final primary = find.byKey(const Key('sequence-primary'));
Future<void> judge(WidgetTester t) async {
  await fixture.tap(t, primary);
  await t.pump(const Duration(milliseconds: 1750));
  await dismissResultPopup(t);
  await t.pumpAndSettle();
}

Future<void> explanation(WidgetTester t) async {
  await fixture.tap(t, primary);
  await t.pumpAndSettle();
  final screen = t.widget<LessonExplanationScreen>(
    find.byType(LessonExplanationScreen),
  );
  expect(screen.inlineDetails, isTrue);
  expect(screen.shortDetails!.length, 2);
  expect(find.byKey(const Key('explanation-toggle')), findsNothing);
  for (final title in ['핵심 매너', '왜 중요한가요?', '실전 팁', '학습 핵심']) {
    expect(find.text(title), findsOneWidget);
  }
  expect(screen.content.practice, '정류장 하나 놓치는 것보다 안전이 훨씬 중요해!');
  expect(screen.content.faqs, isEmpty);
}

Future<void> complete(WidgetTester t) async {
  await fixture.tap(t, find.byKey(const Key('explanation-next')));
  for (
    var i = 0;
    i < 150 && find.byKey(const Key('completion-xp')).evaluate().isEmpty;
    i++
  ) {
    await t.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 10)),
    );
    await t.pump(const Duration(milliseconds: 20));
  }
  await t.pumpAndSettle();
  expect(find.byKey(const Key('completion-xp')), findsOneWidget);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  for (final order in permutations(['A', 'B', 'C', 'D'])) {
    test('permutation ${order.join()}: accepted iff C last', () async {
      final d = await loadApplication04(MannerPartner.dog),
          s = SequenceLessonState(
            (await loadApplication04(MannerPartner.dog)).question,
          );
      s.reorder(0, 4);
      fixture.orderAs(s, order);
      s.startDrag();
      expect(s.submit(), isFalse);
      expect(s.validSubmissions, 0);
      s.endDrag();
      expect(s.submit(), isTrue);
      expect(s.success, order.last == 'C');
      expect(d.question.acceptedOrders.length, 6);
      s.dispose();
    });
  }
  test(
    'invalid/missing/duplicate card IDs rejected; unique topic04 rewards and zero reveal',
    () async {
      final d = await loadApplication04(MannerPartner.dog);
      final base = <String, dynamic>{
        'problemId': 'test',
        'title': 'test',
        'scenario': 'test',
        'instruction': 'test',
        'cards': [
          for (final c in d.question.cards)
            {'id': c.id, 'label': c.label, 'thumbnail': c.thumbnail},
        ],
        'correctOrder': ['B', 'D', 'A', 'C'],
        'hints': [],
        'feedback': {'correct': '', 'wrong': ''},
        'maxValidSubmissions': 4,
      };
      for (final invalid in [
        ['A', 'A', 'D', 'C'],
        ['A', 'B', 'C'],
        ['A', 'B', 'D', 'Z'],
      ]) {
        expect(
          () => SequenceQuestion.fromJson({
            ...base,
            'acceptedOrders': [invalid],
          }),
          throwsFormatException,
        );
      }
      final memory = reward.MemoryRewards(base: 95);
      const direct = TopicSetOutcome(
        topicId: 'transit_04',
        basic: LearningEnd.directCorrect,
        application: LearningEnd.directCorrect,
      );
      final receipts = await Future.wait([
        memory.gateway().complete(direct, d.rewards),
        memory.gateway().complete(direct, d.rewards),
      ]);
      expect(receipts.map((r) => r.awarded), [20, 0]);
      expect(receipts.first.after.level, 2);
      expect((await memory.gateway().complete(direct, d.rewards)).awarded, 0);
      expect(
        jsonDecode(memory.raw!).keys.single,
        contains('topic:transit_04:'),
      );
      final zero = reward.MemoryRewards();
      const revealed = TopicSetOutcome(
        topicId: 'transit_04',
        basic: LearningEnd.directCorrect,
        application: LearningEnd.answerRevealed,
      );
      expect((await zero.gateway().complete(revealed, d.rewards)).awarded, 0);
      expect((await zero.gateway().complete(direct, d.rewards)).awarded, 0);
      expect(zero.total, 0);
      final basicRevealed = reward.MemoryRewards();
      expect(
        (await basicRevealed.gateway().complete(
          const TopicSetOutcome(
            topicId: 'transit_04',
            basic: LearningEnd.answerRevealed,
            application: LearningEnd.directCorrect,
          ),
          d.rewards,
        )).awarded,
        0,
      );
      await expectLater(
        basicRevealed.gateway().complete(
          const TopicSetOutcome(
            topicId: 'transit_04',
            basic: null,
            application: LearningEnd.directCorrect,
          ),
          d.rewards,
        ),
        throwsStateError,
      );
    },
  );

  for (final p in MannerPartner.values) {
    testWidgets(
      '${p.name}: stable hints, wrong retry, correct, inline explanation, real completion',
      (t) async {
        final memory = reward.MemoryRewards(), sounds = <LessonFeedbackSound>[];
        await mount(t, p, memory, sounds: sounds);
        final s = fixture.state(t), original = List.of(fixture.state(t).order);
        await fixture.tap(t, find.byKey(const Key('sequence-hint')));
        await t.pumpAndSettle();
        final height = t.getSize(find.byKey(const Key('hint-bubble')));
        expect(
          t.widget<MannersHintBubble>(find.byType(MannersHintBubble)).partner,
          p,
        );
        await fixture.capture(t, 'learning04-${p.name}-hint1', copies: 0);
        await fixture.tap(t, find.byKey(const Key('sequence-hint')));
        await t.pumpAndSettle();
        expect(t.getSize(find.byKey(const Key('hint-bubble'))), height);
        expect(find.text('다음 힌트 보기'), findsNothing);
        expect(s.order, original);
        expect(s.validSubmissions, 0);
        s.reorder(0, 3);
        await t.pumpAndSettle();
        await judge(t);
        expect(s.phase, SequencePhase.wrongComplete);
        expect(find.text('남은 시도 횟수: 3/4'), findsOneWidget);
        await fixture.tap(t, primary);
        await t.pumpAndSettle();
        fixture.orderAs(s, ['A', 'D', 'B', 'C']);
        await t.pumpAndSettle();
        expect(s.validSubmissions, 1);
        expect(s.phase, SequencePhase.editing);
        await judge(t);
        expect(sounds, [
          LessonFeedbackSound.wrong,
          LessonFeedbackSound.correct,
        ]);
        expect(s.success, isTrue);
        await explanation(t);
        await fixture.capture(t, 'learning04-${p.name}-explanation', copies: 0);
        await complete(t);
        expect(memory.total, 20);
        expect(
          t
              .widget<TopicCompletionScreen>(find.byType(TopicCompletionScreen))
              .partner,
          p,
        );
        await fixture.capture(t, 'learning04-${p.name}-completion', copies: 0);
        expect(t.takeException(), isNull);
      },
    );
  }
  testWidgets(
    'four wrong submissions -> canonical answer + explanation -> zero XP',
    (t) async {
      final memory = reward.MemoryRewards();
      await mount(t, MannerPartner.monkey, memory);
      final s = fixture.state(t);
      s.reorder(0, 3);
      final wrong = List.of(s.order);
      for (var i = 1; i <= 4; i++) {
        await judge(t);
        expect(s.validSubmissions, i);
        expect(s.order, wrong);
        if (i < 4) {
          await fixture.tap(t, primary);
          await t.pumpAndSettle();
        }
      }
      expect(s.phase, SequencePhase.finalFailure);
      expect(s.submit(), isFalse);
      s.retry();
      expect(s.phase, SequencePhase.finalFailure);
      await fixture.tap(t, primary);
      await t.pumpAndSettle();
      expect(s.order, ['B', 'D', 'A', 'C']);
      expect(s.success, isFalse);
      await t.scrollUntilVisible(
        find.textContaining('A·B·D 사이의 순서는 달라도'),
        160,
        scrollable: find.byType(Scrollable).first,
      );
      await t.pumpAndSettle();
      expect(find.textContaining('A·B·D 사이의 순서는 달라도'), findsOneWidget);
      await fixture.capture(t, 'learning04-revealed', copies: 0);
      await explanation(t);
      await complete(t);
      expect(memory.total, 0);
      expect(find.text('+0 XP'), findsOneWidget);
      await fixture.capture(t, 'learning04-zero-completion', copies: 0);
    },
  );
  testWidgets('320dp large text: full education and replay reset', (t) async {
    final memory = reward.MemoryRewards();
    await mount(t, MannerPartner.cat, memory, width: 320, scale: 2);
    final s = fixture.state(t);
    await fixture.tap(t, find.byKey(const Key('sequence-hint')));
    await t.pumpAndSettle();
    final hintSize = t.getSize(find.byKey(const Key('hint-bubble')));
    await fixture.tap(t, find.byKey(const Key('sequence-hint')));
    await t.pumpAndSettle();
    expect(t.getSize(find.byKey(const Key('hint-bubble'))), hintSize);
    fixture.orderAs(s, s.question.correctOrder);
    await t.pumpAndSettle();
    await judge(t);
    await explanation(t);
    for (final k in [
      'explanation-core',
      'explanation-learning',
      'explanation-practice',
    ]) {
      await t.ensureVisible(find.byKey(Key(k)));
      await t.pumpAndSettle();
      expect(t.takeException(), isNull);
    }
    await fixture.tap(t, find.byKey(const Key('explanation-replay')));
    await t.pumpAndSettle();
    expect(s.order, ['A', 'B', 'C', 'D']);
    expect(s.validSubmissions, 0);
    expect(s.hintStep, 0);
    expect(memory.raw, isNull);
  });
  testWidgets('basic result -> application -> completion -> next callback', (
    t,
  ) async {
    var next = false;
    final memory = reward.MemoryRewards();
    await mount(
      t,
      MannerPartner.cat,
      memory,
      basicScreen: true,
      onNext: () => next = true,
    );
    final b = fixture.state(t);
    fixture.orderAs(b, b.question.correctOrder);
    expect(b.submit(), isTrue);
    b.settle();
    await t.pumpAndSettle();
    await fixture.tap(t, primary);
    await t.pumpAndSettle();
    await fixture.tap(t, find.byKey(const Key('explanation-next')));
    for (
      var i = 0;
      i < 400 && find.text('응용 04/20 · 2/2').evaluate().isEmpty;
      i++
    ) {
      await t.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 25)),
      );
      await t.pump(const Duration(milliseconds: 10));
    }
    await t.pumpAndSettle();
    final s = fixture.state(t);
    expect(
      t
          .widget<Application04Screen>(find.byType(Application04Screen))
          .basicOutcome,
      LearningEnd.directCorrect,
    );
    fixture.orderAs(s, s.question.correctOrder);
    await t.pumpAndSettle();
    await judge(t);
    await explanation(t);
    await complete(t);
    await fixture.tap(t, find.byKey(const Key('topic-completion-next')));
    await t.pumpAndSettle();
    expect(next, isTrue);
    expect(memory.total, 20);
  });
}

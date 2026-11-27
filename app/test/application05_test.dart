import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mannerfit/screens/application05_screen.dart';
import 'package:mannerfit/screens/choice_lesson_state.dart';
import 'package:mannerfit/screens/common_result_popup.dart';
import 'package:mannerfit/screens/lesson_explanation_screen.dart';
import 'package:mannerfit/screens/lesson_feedback_sound.dart';
import 'package:mannerfit/screens/manners_hint_bubble.dart';
import 'package:mannerfit/screens/partner_selection_screen.dart';
import 'package:mannerfit/screens/topic_completion.dart';
import 'package:mannerfit/screens/topic_completion_screen.dart';
import 'application01_test.dart' as reward;
import 'transit04_screen_test.dart' as fixture;
import 'sequence_feedback_revision_test.dart' as fonts;
import 'result_popup_test_helpers.dart';

ChoiceLessonState state(WidgetTester t) =>
    t
            .widget<ListenableBuilder>(
              find.byKey(const Key('application05-ready')),
            )
            .listenable
        as ChoiceLessonState;
final primary = find.byKey(const Key('application05-primary'));
Future<void> mount(
  WidgetTester t,
  MannerPartner p, {
  int width = 390,
  double scale = 1,
  reward.MemoryRewards? memory,
  LearningEnd basic = LearningEnd.directCorrect,
  List<LessonFeedbackSound>? sounds,
  Future<bool> Function(Uri)? openSource,
}) async {
  t.view.physicalSize = Size(width.toDouble(), 844);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.resetPhysicalSize);
  addTearDown(t.view.resetDevicePixelRatio);
  for (final f in [
    'spec/problem_choice_transit05.json',
    'spec/state_asset_mapping.json',
    'spec/asset_rules.json',
    'content/explanation.json',
    'content/reward_policy.json',
  ]) {
    rootBundle.evict('assets/application05/$f');
  }
  rootBundle.evict('assets/application01/completion_screen_spec.json');
  await t.pumpWidget(
    TopicCompletionBinding(
      gateway: (memory ?? reward.MemoryRewards()).gateway(),
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
          home: Application05Screen(
            partner: p,
            basicOutcome: basic,
            hasNextProblem: true,
            openSource: openSource,
            playSound: sounds == null
                ? null
                : (sound) async {
                    sounds.add(sound);
                  },
          ),
        ),
      ),
    ),
  );
  await fixture.ready(t, 'application05-ready');
  await fonts.captureFonts(t);
  await t.pumpAndSettle();
}

Future<void> choose(WidgetTester t, String id) =>
    fixture.tap(t, find.byKey(ValueKey('choice-$id')));
Future<void> submit(WidgetTester t) async {
  await fixture.tap(t, primary);
  await t.pump(const Duration(milliseconds: 1750));
  await dismissResultPopup(t);
  await t.pumpAndSettle();
}

Future<void> explanation(WidgetTester t) async {
  await fixture.tap(t, primary);
  await t.pumpAndSettle();
  final page = t.widget<LessonExplanationScreen>(
    find.byType(LessonExplanationScreen),
  );
  expect(page.inlineDetails, isTrue);
  expect(page.shortDetails!.length, 2);
  expect(
    page.content.sources.single.url.toString(),
    'https://news.seoul.go.kr/traffic/archives/36023',
  );
  expect(find.byKey(const Key('explanation-toggle')), findsNothing);
  expect(find.text('근거 및 출처'), findsOneWidget);
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
  test(
    'approved source content and submit-only B grading; retry limit and no reward state side effects',
    () async {
      final data = await loadApplication05();
      final q = ChoiceProblem.fromJson(data.lesson.problem);
      expect(q.correctId, 'B');
      expect(q.maxSubmissions, 4);
      expect(q.hints.length, 2);
      expect(q.situations.keys.toSet(), {'댕댕이', '냥냥이', '몽몽이'});
      for (final id in ['A', 'B', 'C']) {
        final s = ChoiceLessonState(q);
        expect(s.canSubmit, isFalse);
        s.select(id);
        expect(s.validSubmissions, 0);
        expect(s.phase, ChoicePhase.choosing);
        expect(s.submit(), isTrue);
        expect(s.submit(), isFalse);
        expect(s.validSubmissions, 1);
        expect(s.success, id == 'B');
        expect(s.feedback, q.feedback[id]);
        s.dispose();
      }
      final s = ChoiceLessonState(q);
      for (var i = 1; i <= 4; i++) {
        s.select(i.isEven ? 'C' : 'A');
        s.showHint();
        s.submit();
        s.settle();
        expect(s.validSubmissions, i);
        if (i < 4) s.retry();
      }
      expect(s.phase, ChoicePhase.finalFailure);
      s.retry();
      expect(s.phase, ChoicePhase.finalFailure);
      s.reveal();
      expect(s.success, isFalse);
      expect(s.submit(), isFalse);
      s.dispose();
      final md = File(
        'assets/application05/content/education_content_transit05.md',
      ).readAsStringSync();
      expect(md, contains('APPROVED'));
      expect(md, contains('포장된 음식물도'));
      expect(md, contains(data.lesson.education['practice']));
      for (final section in data.details) {
        for (final paragraph in section.body.split('\n\n')) {
          expect(
            md.replaceAll(RegExp(r'\s+'), ' '),
            contains(paragraph.replaceAll(RegExp(r'\s+'), ' ')),
          );
        }
      }
      expect(data.lesson.education['content_status'], 'APPROVED');
      expect(Directory('assets/application05/qa').existsSync(), isFalse);
    },
  );
  test(
    'user/topic reward isolation, concurrent duplicate prevention, reveal/review zero and missing basic rejection',
    () async {
      final data = await loadApplication05();
      final memory = reward.MemoryRewards(base: 95);
      const direct = TopicSetOutcome(
        topicId: 'transit_05',
        basic: LearningEnd.directCorrect,
        application: LearningEnd.directCorrect,
      );
      final r = await Future.wait([
        memory.gateway().complete(direct, data.rewards),
        memory.gateway().complete(direct, data.rewards),
      ]);
      expect(r.map((v) => v.awarded), [20, 0]);
      expect(r.first.after.level, 2);
      expect(
        (await memory.gateway().complete(direct, data.rewards)).awarded,
        0,
      );
      expect(
        jsonDecode(memory.raw!).keys.single,
        contains('topic:transit_05:'),
      );
      for (final basicRevealed in [false, true]) {
        final zero = reward.MemoryRewards();
        final outcome = TopicSetOutcome(
          topicId: 'transit_05',
          basic: basicRevealed
              ? LearningEnd.answerRevealed
              : LearningEnd.directCorrect,
          application: basicRevealed
              ? LearningEnd.directCorrect
              : LearningEnd.answerRevealed,
        );
        expect(
          (await zero.gateway().complete(outcome, data.rewards)).awarded,
          0,
        );
        expect(
          (await zero.gateway().complete(direct, data.rewards)).awarded,
          0,
        );
        expect(zero.total, 0);
      }
      await expectLater(
        memory.gateway().complete(
          const TopicSetOutcome(
            topicId: 'transit_05',
            basic: null,
            application: LearningEnd.directCorrect,
          ),
          data.rewards,
        ),
        throwsStateError,
      );
    },
  );
  for (final width in [320, 360, 390]) {
    for (final p in MannerPartner.values) {
      testWidgets(
        '${p.name} $width: completed scene, hints preserve selection, A/C wrong, B correct and completion',
        (t) async {
          final memory = reward.MemoryRewards(),
              sounds = <LessonFeedbackSound>[],
              opened = <Uri>[];
          await mount(
            t,
            p,
            width: width,
            memory: memory,
            sounds: sounds,
            openSource: (uri) async {
              opened.add(uri);
              return true;
            },
          );
          final s = state(t);
          expect(s.problem.situations[p.name], startsWith('${p.name}는'));
          final scene = find.byKey(const Key('application05-scene'));
          expect(t.widget<Image>(scene).fit, BoxFit.contain);
          expect(t.getSize(scene).aspectRatio, closeTo(9 / 4, .00001));
          expect(
            find.ancestor(of: scene, matching: find.byType(ClipRRect)),
            findsNothing,
          );
          expect(t.widget<FilledButton>(primary).onPressed, isNull);
          if (width == 390) {
            await fixture.capture(
              t,
              'application05-${p.name}-initial',
              copies: 0,
            );
          }
          await choose(t, 'A');
          await fixture.tap(t, find.byKey(const Key('application05-hint')));
          await t.pumpAndSettle();
          final hintSize = t.getSize(find.byKey(const Key('hint-bubble')));
          expect(
            t.widget<MannersHintBubble>(find.byType(MannersHintBubble)).partner,
            p,
          );
          if (width == 390) {
            await fixture.capture(t, 'application05-${p.name}-hint', copies: 0);
          }
          await fixture.tap(t, find.byKey(const Key('application05-hint')));
          await t.pumpAndSettle();
          expect(t.getSize(find.byKey(const Key('hint-bubble'))), hintSize);
          expect(find.text('다음 힌트 보기'), findsNothing);
          expect(s.selectedId, 'A');
          expect(s.validSubmissions, 0);
          expect(find.byType(CommonResultPopup), findsNothing);
          for (final wrong in ['A', 'C']) {
            await choose(t, wrong);
            await submit(t);
            expect(s.phase, ChoicePhase.wrongComplete);
            expect(s.feedback, s.problem.feedback[wrong]);
            await fixture.tap(t, primary);
            await t.pumpAndSettle();
            expect(s.selectedId, isNull);
          }
          await choose(t, 'B');
          expect(s.validSubmissions, 2);
          await submit(t);
          expect(s.success, isTrue);
          expect(s.validSubmissions, 3);
          expect(sounds, [
            LessonFeedbackSound.wrong,
            LessonFeedbackSound.wrong,
            LessonFeedbackSound.correct,
          ]);
          await explanation(t);
          expect(
            t
                .widget<LessonExplanationScreen>(
                  find.byType(LessonExplanationScreen),
                )
                .partner,
            p,
          );
          await t.ensureVisible(find.byKey(const Key('explanation-source-0')));
          await t.pumpAndSettle();
          await t.tap(find.byKey(const Key('explanation-source-0')));
          await t.pumpAndSettle();
          expect(
            opened.single.toString(),
            'https://news.seoul.go.kr/traffic/archives/36023',
          );
          if (width == 390) {
            await fixture.capture(
              t,
              'application05-${p.name}-sources',
              copies: 0,
            );
          }
          await t.ensureVisible(find.byKey(const Key('explanation-practice')));
          await t.pumpAndSettle();
          if (width == 390) {
            await fixture.capture(
              t,
              'application05-${p.name}-learning',
              copies: 0,
            );
          }
          await complete(t);
          expect(memory.total, 20);
          expect(
            t
                .widget<TopicCompletionScreen>(
                  find.byType(TopicCompletionScreen),
                )
                .partner,
            p,
          );
          if (width == 390) {
            await fixture.capture(
              t,
              'application05-${p.name}-completion',
              copies: 0,
            );
          }
          expect(t.takeException(), isNull);
        },
      );
    }
  }
  testWidgets(
    'four failures reveal B without correct sound or success, explanation -> zero XP',
    (t) async {
      final memory = reward.MemoryRewards(), sounds = <LessonFeedbackSound>[];
      await mount(t, MannerPartner.dog, memory: memory, sounds: sounds);
      final s = state(t);
      for (var i = 1; i <= 4; i++) {
        await choose(t, i.isEven ? 'C' : 'A');
        await submit(t);
        expect(s.validSubmissions, i);
        if (i < 4) {
          await fixture.tap(t, primary);
          await t.pumpAndSettle();
        }
      }
      expect(s.phase, ChoicePhase.finalFailure);
      expect(s.submit(), isFalse);
      await fixture.tap(t, primary);
      await t.pumpAndSettle();
      expect(s.success, isFalse);
      expect(s.solutionRevealed, isTrue);
      await t.ensureVisible(find.byKey(const Key('choice-feedback')));
      await t.pumpAndSettle();
      expect(find.textContaining('가장 권장되는 행동은 B예요.'), findsOneWidget);
      expect(sounds.every((s) => s == LessonFeedbackSound.wrong), isTrue);
      await fixture.capture(t, 'application05-revealed', copies: 0);
      await explanation(t);
      await complete(t);
      expect(memory.total, 0);
      expect(find.text('+0 XP'), findsOneWidget);
      await fixture.capture(t, 'application05-zero-completion', copies: 0);
    },
  );
  testWidgets(
    '320dp 2x type full hints/education, replay and rewarded review zero',
    (t) async {
      final memory = reward.MemoryRewards();
      final config = TopicRewardConfig.fromJson(
        jsonDecode(
          File(
            'assets/application05/content/reward_policy.json',
          ).readAsStringSync(),
        ),
      );
      await t.runAsync(
        () => memory.gateway().complete(
          const TopicSetOutcome(
            topicId: 'transit_05',
            basic: LearningEnd.directCorrect,
            application: LearningEnd.directCorrect,
          ),
          config,
        ),
      );
      await mount(t, MannerPartner.cat, width: 320, scale: 2, memory: memory);
      final s = state(t);
      await choose(t, 'B');
      await fixture.tap(t, find.byKey(const Key('application05-hint')));
      await t.pumpAndSettle();
      final size = t.getSize(find.byKey(const Key('hint-bubble')));
      await fixture.tap(t, find.byKey(const Key('application05-hint')));
      await t.pumpAndSettle();
      expect(t.getSize(find.byKey(const Key('hint-bubble'))), size);
      await submit(t);
      await explanation(t);
      for (final k in [
        'explanation-core',
        'explanation-source-0',
        'explanation-practice',
      ]) {
        await t.ensureVisible(find.byKey(Key(k)));
        await t.pumpAndSettle();
        expect(t.takeException(), isNull);
      }
      await fixture.tap(t, find.byKey(const Key('explanation-replay')));
      await t.pumpAndSettle();
      expect(s.selectedId, isNull);
      expect(s.validSubmissions, 0);
      expect(s.hintStep, 0);
      expect(memory.total, 20);
      await choose(t, 'B');
      await submit(t);
      await explanation(t);
      await complete(t);
      expect(find.text('+0 XP'), findsOneWidget);
      expect(memory.total, 20);
    },
  );
}

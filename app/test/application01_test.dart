import 'dart:convert';
import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mannerfit/screens/application01_screen.dart';
import 'package:mannerfit/screens/lesson_explanation_screen.dart';
import 'package:mannerfit/screens/application01_state.dart';
import 'package:mannerfit/screens/topic_completion.dart';
import 'package:mannerfit/fake/preview_topic_completion.dart';
import 'package:mannerfit/screens/topic_completion_screen.dart';
import 'package:mannerfit/screens/partner_selection_screen.dart';
import 'package:mannerfit/screens/subway02_screen.dart';
import 'package:mannerfit/screens/transport_lesson_screen.dart';
import 'package:mannerfit/screens/transport_progress.dart';
import 'package:mannerfit/screens/action_drag_state.dart';
import 'package:mannerfit/screens/lesson_feedback_sound.dart';
import 'transit04_screen_test.dart' as fixture;
import 'sequence_feedback_revision_test.dart' as fonts;
import 'result_popup_test_helpers.dart';

Map<String, dynamic> jsonFile(String name) =>
    jsonDecode(File('assets/application01/$name').readAsStringSync())
        as Map<String, dynamic>;
Application01State state(WidgetTester t) =>
    t
            .widget<ListenableBuilder>(
              find.byKey(const Key('application01-ready')),
            )
            .listenable
        as Application01State;

class MemoryRewards {
  String? raw;
  int total = 0, contribution = 0, base;
  bool fail = false;
  MemoryRewards({this.base = 0});
  PreviewTopicCompletion gateway() => PreviewTopicCompletion(
    userId: 'test-user',
    read: () async => raw,
    write: (value) async {
      if (fail) throw StateError('disk full');
      raw = value;
    },
    applyTotal: (v) {
      contribution = v;
      total = base + v;
    },
    profile: () => CompletionProfile(
      totalXp: total,
      level: total ~/ 100 + 1,
      levelXp: total % 100,
      levelMax: 100,
    ),
  );
}

TopicSetOutcome outcome({bool reveal = false}) => TopicSetOutcome(
  topicId: 'transit_01',
  basic: LearningEnd.directCorrect,
  application: reveal ? LearningEnd.answerRevealed : LearningEnd.directCorrect,
);
Future<void> mount(
  WidgetTester t,
  MannerPartner partner, {
  MemoryRewards? memory,
  LearningEnd basic = LearningEnd.directCorrect,
  Size size = const Size(390, 844),
  double scale = 1,
  bool basicScreen = false,
}) async {
  t.view.physicalSize = size;
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.resetPhysicalSize);
  addTearDown(t.view.resetDevicePixelRatio);
  for (final f in [
    'geometry.json',
    'application_explanation_01.json',
    'completion_screen_spec.json',
    'reward_config.json',
  ]) {
    rootBundle.evict('assets/application01/$f');
  }
  if (basicScreen) {
    for (final f in ['asset_rules.json', 'state_asset_mapping.json']) {
      rootBundle.evict('assets/subway01/$f');
    }
  }
  final rewards = memory ?? MemoryRewards();
  await t.pumpWidget(
    TopicCompletionBinding(
      gateway: rewards.gateway(),
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
              ? TransportLessonScreen(
                  index: 0,
                  partner: partner,
                  store: TransportProgress(persist: false),
                )
              : Builder(
                  builder: (c) => TextButton(
                    onPressed: () => Navigator.push(
                      c,
                      MaterialPageRoute(
                        builder: (_) => Application01Screen(
                          partner: partner,
                          basicOutcome: basic,
                        ),
                      ),
                    ),
                    child: const Text('launch'),
                  ),
                ),
        ),
      ),
    ),
  );
  if (!basicScreen) {
    await t.tap(find.text('launch'));
    await t.pump(const Duration(milliseconds: 400));
  }
  await fixture.ready(
    t,
    basicScreen ? 'subway01-ready' : 'application01-ready',
  );
  await fonts.captureFonts(t);
  await t.pumpAndSettle();
}

Future<void> drop(WidgetTester t, Offset target) async {
  final suitcase = find.byKey(const Key('application-suitcase'));
  final scene = find
      .ancestor(of: suitcase, matching: find.byType(AspectRatio))
      .first;
  await t.ensureVisible(scene);
  await t.pumpAndSettle();
  final rect = t.getRect(scene);
  Offset screen(Offset p) => rect.topLeft + p * (rect.width / 1536);
  final s = state(t), before = s.attempts;
  const start = Offset(690, 850);
  final gesture = await t.startGesture(screen(start));
  expect(s.phase, ApplicationPhase.dragging);
  await gesture.moveTo(screen(start + target - const Offset(690, 795)));
  await t.pump();
  expect(s.attempts, before);
  expect(
    t.getRect(scene),
    rect,
    reason: 'Dragging must not move the scene or collapse the footer',
  );
  await gesture.up();
  await t.pump();
}

Future<void> settle(WidgetTester t) async {
  await t.pump(const Duration(milliseconds: 1800));
  await t.pump();
  await dismissResultPopup(t);
}

Future<void> openExplanation(WidgetTester t) async {
  await fixture.tap(t, find.byKey(const Key('application-primary')));
  await t.pumpAndSettle();
  final screen = t.widget<LessonExplanationScreen>(
    find.byType(LessonExplanationScreen),
  );
  expect(screen.content.core, '캐리어는 다른 승객의 이동을 방해하지 않는 위치에 두고 안전하게 관리해요.');
  expect(screen.content.learningCore, '내 짐은 내 공간 안에 두고, 다른 승객이 다니는 통로는 비워요.');
  expect(screen.content.practice, '내 짐은 가까이, 다른 사람의 길은 넓게!');
  expect(find.byKey(const Key('explanation-details')), findsNothing);
  expect(find.byKey(const Key('explanation-core')), findsOneWidget);
  expect(find.byKey(const Key('explanation-learning')), findsOneWidget);
  expect(find.text('문제 다시 풀기'), findsOneWidget);
  expect(find.text('학습 완료'), findsOneWidget);
  expect(find.text('응용 01/20 · 2/2'), findsOneWidget);
  final profile = t.widget<Image>(find.byKey(const Key('explanation-profile')));
  final partnerKey = switch (screen.partner) {
    MannerPartner.dog => 'dog',
    MannerPartner.cat => 'cat',
    MannerPartner.monkey => 'monkey',
  };
  expect(
    ((profile.image as ResizeImage).imageProvider as AssetImage).assetName,
    'assets/subway01/${partnerKey}_thinking.png',
  );
  expect(profile.width, 48);
  await fixture.capture(
    t,
    '${screen.partner.name}-application-explanation-collapsed-${t.view.physicalSize.width.toInt()}',
    copies: 0,
  );
}

Future<void> complete(WidgetTester t) async {
  await openExplanation(t);
  await fixture.tap(t, find.byKey(const Key('explanation-toggle')));
  await t.pumpAndSettle();
  expect(find.text('왜 중요할까요?'), findsOneWidget);
  expect(find.text('실전 팁'), findsOneWidget);
  expect(find.text('근거 및 출처'), findsNothing);
  expect(find.text('상황별 응용 및 주의사항'), findsNothing);
  final screen = t.widget<LessonExplanationScreen>(
    find.byType(LessonExplanationScreen),
  );
  expect(screen.shortDetails!.map((s) => s.body), [
    '캐리어가 통로를 막거나 열차가 흔들릴 때 움직이면 다른 승객에게 불편과 위험을 줄 수 있기 때문이에요.',
    '캐리어는 내 발 앞의 안전한 공간에 두고, 손잡이를 잡아 움직이지 않게 관리해요.',
  ]);
  await fixture.tap(t, find.byKey(const Key('explanation-toggle')));
  await t.pumpAndSettle();
  expect(find.byKey(const Key('explanation-details')), findsNothing);
  await fixture.tap(t, find.byKey(const Key('explanation-next')));
  for (
    var i = 0;
    i < 100 && find.byKey(const Key('completion-xp')).evaluate().isEmpty;
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
  final geometry = ApplicationGeometry(jsonFile('geometry.json'));
  final config = TopicRewardConfig.fromJson(jsonFile('reward_config.json'));
  testWidgets(
    'completion waits for result audio; background pauses and resume finishes once',
    (t) async {
      final audioDone = Completer<void>();
      var calls = 0;
      final audio = playLessonFeedbackSound(
        (_) async {
          await audioDone.future;
        },
        LessonFeedbackSound.correct,
        muted: false,
      );
      const receipt = TopicCompletionReceipt(
        kind: TopicCompletionKind.firstDirect,
        awarded: 20,
        before: CompletionProfile(
          totalXp: 30,
          level: 1,
          levelXp: 30,
          levelMax: 100,
        ),
        after: CompletionProfile(
          totalXp: 50,
          level: 1,
          levelXp: 50,
          levelMax: 100,
        ),
      );
      await t.pumpWidget(
        MaterialApp(
          home: TopicCompletionScreen(
            complete: () async {
              calls++;
              return receipt;
            },
            partner: MannerPartner.dog,
            topicTitle: 'test',
            spec: jsonFile('completion_screen_spec.json'),
            onNext: () {},
          ),
        ),
      );
      await t.pump();
      expect(find.byKey(const Key('completion-xp')), findsNothing);
      audioDone.complete();
      await audio;
      await t.pump();
      await t.pump(const Duration(milliseconds: 300));
      expect(find.byKey(const Key('completion-xp')), findsOneWidget);
      final before = t
          .widget<LinearProgressIndicator>(
            find.byKey(const Key('completion-gauge')),
          )
          .value;
      t.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      t.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await t.pump(const Duration(seconds: 2));
      expect(
        t
            .widget<LinearProgressIndicator>(
              find.byKey(const Key('completion-gauge')),
            )
            .value,
        before,
      );
      t.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await t.pumpAndSettle();
      expect(calls, 1);
      expect(
        t
            .widget<LinearProgressIndicator>(
              find.byKey(const Key('completion-gauge')),
            )
            .value,
        .5,
      );
      await t.pumpWidget(const SizedBox());
    },
  );
  test(
    'persisted prototype grants restore profile XP before opening a completed topic',
    () async {
      final memory = MemoryRewards(base: 30);
      await memory.gateway().complete(outcome(), config);
      memory.total = 30;
      await memory.gateway().restore();
      expect(memory.total, 50);
      await memory.gateway().restore();
      expect(memory.total, 50);
    },
  );
  testWidgets(
    'completion uses authoritative non-100 thresholds and level-up wrap',
    (t) async {
      t.view.physicalSize = const Size(390, 844);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.resetPhysicalSize);
      addTearDown(t.view.resetDevicePixelRatio);
      const receipt = TopicCompletionReceipt(
        kind: TopicCompletionKind.firstDirect,
        awarded: 37,
        before: CompletionProfile(
          totalXp: 2100,
          level: 7,
          levelXp: 210,
          levelMax: 230,
        ),
        after: CompletionProfile(
          totalXp: 2137,
          level: 8,
          levelXp: 17,
          levelMax: 310,
        ),
      );
      await t.pumpWidget(
        MaterialApp(
          home: TopicCompletionScreen(
            complete: () async => receipt,
            partner: MannerPartner.cat,
            topicTitle: 'test',
            spec: jsonFile('completion_screen_spec.json'),
            onNext: () {},
          ),
        ),
      );
      for (
        var i = 0;
        i < 10 && find.byKey(const Key('completion-xp')).evaluate().isEmpty;
        i++
      ) {
        await t.pump();
      }
      await t.pump(const Duration(milliseconds: 1200));
      expect(find.text('Lv. 7'), findsOneWidget);
      expect(
        t
            .widget<LinearProgressIndicator>(
              find.byKey(const Key('completion-gauge')),
            )
            .value,
        greaterThan(.9),
      );
      await t.pumpAndSettle();
      expect(find.text('Lv. 8'), findsOneWidget);
      expect(find.text('17 / 310 XP'), findsOneWidget);
      expect(find.text('현재 경험치 2137 XP'), findsOneWidget);
      expect(find.text('+37 XP'), findsOneWidget);
      await t.pumpWidget(const SizedBox());
    },
  );
  test(
    'approved anchors, actual sprite scale and whole footprint/body grading',
    () {
      expect(geometry.center('initial'), const Offset(690, 795));
      expect(geometry.center('correct'), const Offset(471, 795));
      expect(geometry.classify(const Offset(471, 795)), LuggageDrop.correct);
      expect(geometry.classify(const Offset(350, 795)), LuggageDrop.correct);
      expect(
        geometry.classify(const Offset(515, 795)),
        LuggageDrop.neighbor,
        reason: 'feet fit own space but body intrudes neighbor',
      );
      expect(geometry.classify(const Offset(1015, 807)), LuggageDrop.aisle);
      expect(geometry.classify(const Offset(471, 500)), LuggageDrop.invalid);
      expect(geometry.classify(const Offset(1420, 800)), LuggageDrop.invalid);
    },
  );
  test(
    'invalid/cancel do not count; duplicate pointers/4 attempts/hints/reveal',
    () {
      final s = Application01State(geometry);
      const start = Offset(690, 850);
      expect(s.begin(1, start, false), isFalse);
      s.begin(1, start, true);
      expect(s.begin(2, start, true), isFalse);
      s.move(2, const Offset(1, 1));
      expect(s.delta, Offset.zero);
      s.cancel(1);
      expect(s.attempts, 0);
      s.begin(1, start, true);
      expect(s.release(1, const Offset(471, 500)), isFalse);
      expect(s.attempts, 0);
      s.hintTap();
      s.hintTap();
      expect(s.hint, 2);
      for (var i = 1; i <= 4; i++) {
        s.begin(i, start, true);
        s.release(
          i,
          start + geometry.center('wrong') - geometry.center('initial'),
        );
        s.settle();
        expect(s.attempts, i);
        if (i < 4) s.retry();
      }
      expect(s.phase, ApplicationPhase.failure);
      expect(s.begin(8, start, true), isFalse);
      s.reveal();
      expect(s.showingCorrect, isTrue);
      expect(s.success, isFalse);
      expect(s.attempts, 4);
    },
  );
  test(
    'one unique grant under concurrency/re-entry/restart, live profile and configuration',
    () async {
      final memory = MemoryRewards(base: 95);
      // Separate gateway instances still share a serialized prototype commit.
      final a = memory.gateway(), b = memory.gateway();
      final receipts = await Future.wait([
        a.complete(outcome(), config),
        b.complete(outcome(), config),
      ]);
      expect(receipts.map((r) => r.awarded).toList(), [20, 0]);
      expect(memory.total, 115);
      expect(receipts.first.before.level, 1);
      expect(receipts.first.after.level, 2);
      expect(receipts.first.after.levelXp, 15);
      expect(
        (await memory.gateway().complete(outcome(reveal: true), config)).kind,
        TopicCompletionKind.review,
      );
      expect(memory.total, 115);
    },
  );
  test(
    'incomplete set blocked, reveal reward and failed commit recover without double XP',
    () async {
      final memory = MemoryRewards(), g = memory.gateway();
      await expectLater(
        g.complete(
          const TopicSetOutcome(
            topicId: 'transit_01',
            basic: null,
            application: LearningEnd.directCorrect,
          ),
          config,
        ),
        throwsStateError,
      );
      expect(memory.raw, isNull);
      memory.fail = true;
      await expectLater(
        g.complete(outcome(reveal: true), config),
        throwsStateError,
      );
      expect(memory.total, 0);
      memory.fail = false;
      final custom = TopicRewardConfig.fromJson({
        'rewards': {'FIRST_DIRECT': 37, 'FIRST_ANSWER_REVEAL': 13},
      });
      expect((await g.complete(outcome(reveal: true), custom)).awarded, 13);
      expect(memory.total, 13);
      expect((await g.complete(outcome(), custom)).awarded, 0);
    },
  );
  for (final p in MannerPartner.values) {
    testWidgets(
      '${p.name}: initial/wrong/correct/grasp/explanation/direct completion',
      (t) async {
        final memory = MemoryRewards(base: 95);
        await mount(t, p, memory: memory);
        await fixture.capture(t, '${p.name}-application-initial');
        await drop(t, const Offset(471, 500));
        expect(state(t).attempts, 0);
        await drop(t, const Offset(1015, 807));
        await settle(t);
        expect(state(t).attempts, 1);
        await fixture.capture(t, '${p.name}-application-wrong');
        await fixture.tap(t, find.byKey(const Key('application-primary')));
        await drop(t, const Offset(471, 795));
        await settle(t);
        expect(state(t).success, isTrue);
        expect(find.byKey(const Key('application-grasp-hand')), findsOneWidget);
        expect(state(t).renderCenter, const Offset(471, 795));
        await fixture.capture(t, '${p.name}-application-correct');
        await complete(t);
        expect(memory.total, 115);
        expect(find.text('+20 XP'), findsOneWidget);
        expect(find.text('Lv. 2'), findsOneWidget);
        await fixture.capture(t, '${p.name}-completion-direct');
        expect(t.takeException(), isNull);
        await t.pumpWidget(const SizedBox());
      },
    );
  }
  testWidgets(
    'four failures then reveal gives first reveal state; review gives zero',
    (t) async {
      final memory = MemoryRewards();
      await mount(t, MannerPartner.dog, memory: memory);
      for (var i = 0; i < 4; i++) {
        await drop(t, const Offset(1015, 807));
        await settle(t);
        await fixture.tap(t, find.byKey(const Key('application-primary')));
      }
      expect(state(t).phase, ApplicationPhase.revealed);
      await complete(t);
      expect(find.text('+10 XP'), findsOneWidget);
      await fixture.capture(t, 'completion-reveal');
      await t.pumpWidget(const SizedBox());
      await mount(t, MannerPartner.cat, memory: memory);
      await drop(t, const Offset(471, 795));
      await settle(t);
      await complete(t);
      expect(find.text('복습 완료!'), findsOneWidget);
      expect(find.text('+0 XP'), findsOneWidget);
      expect(memory.total, 10);
      await fixture.capture(t, 'completion-review');
      await t.pumpWidget(const SizedBox());
    },
  );
  testWidgets(
    'basic explanation -> application -> completion -> actual 02, same partner',
    (t) async {
      await mount(t, MannerPartner.cat, basicScreen: true);
      final s =
          t
                  .widget<ListenableBuilder>(
                    find.byKey(const Key('subway01-ready')),
                  )
                  .listenable
              as ActionDragState;
      s.begin(1, s.initial.center, true);
      s.release(1, const Offset(774, 727));
      s.settle();
      await t.pump();
      await fixture.tap(t, find.text('해설 보기'));
      await t.pumpAndSettle();
      expect(find.text('응용 문제로 이동'), findsOneWidget);
      await fixture.capture(t, 'basic01-explanation-collapsed-390', copies: 0);
      await fixture.tap(t, find.byKey(const Key('explanation-next')));
      await t.pump(const Duration(milliseconds: 400));
      await fixture.ready(t, 'application01-ready');
      await drop(t, const Offset(471, 795));
      await settle(t);
      await complete(t);
      for (final f in ['asset_rules.json', 'state_asset_mapping.json']) {
        rootBundle.evict('assets/subway02/$f');
      }
      await fixture.tap(t, find.byKey(const Key('topic-completion-next')));
      await t.pump(const Duration(milliseconds: 400));
      await fixture.ready(t, 'subway02-ready');
      expect(
        t.widget<Subway02Screen>(find.byType(Subway02Screen)).partner,
        MannerPartner.cat,
      );
      await t.pumpWidget(const SizedBox());
    },
  );
  testWidgets(
    'explanation replay resets only the current application attempt and keeps rewards',
    (t) async {
      final memory = MemoryRewards();
      await memory.gateway().complete(
        outcome(),
        TopicRewardConfig.fromJson(jsonFile('reward_config.json')),
      );
      await mount(t, MannerPartner.dog, memory: memory);
      state(t).hintTap();
      await drop(t, const Offset(1015, 807));
      await settle(t);
      await fixture.tap(t, find.byKey(const Key('application-primary')));
      await drop(t, const Offset(471, 795));
      await settle(t);
      await openExplanation(t);
      await fixture.tap(t, find.byKey(const Key('explanation-toggle')));
      await t.pumpAndSettle();
      await fixture.capture(t, 'application01-explanation-expanded', copies: 0);
      await fixture.tap(t, find.byKey(const Key('explanation-replay')));
      await t.pumpAndSettle();
      expect(state(t).phase, ApplicationPhase.editing);
      expect(state(t).attempts, 0);
      expect(state(t).hint, 0);
      expect(state(t).hintOpen, isFalse);
      expect(state(t).pointer, isNull);
      expect(state(t).renderCenter, const Offset(690, 795));
      expect(memory.total, 20);
      await drop(t, const Offset(471, 795));
      await settle(t);
      await complete(t);
      expect(find.text('+0 XP'), findsOneWidget);
      expect(memory.total, 20);
      expect(t.takeException(), isNull);
      await t.pumpWidget(const SizedBox());
    },
  );
  testWidgets('small screen, 2x text and all approved explanation paragraphs', (
    t,
  ) async {
    await mount(t, MannerPartner.monkey, size: const Size(320, 640), scale: 2);
    await drop(t, const Offset(471, 795));
    await settle(t);
    await complete(t);
    expect(t.takeException(), isNull);
    await t.pumpWidget(const SizedBox());
  });
}

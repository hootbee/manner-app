import 'result_popup_test_helpers.dart';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mannerfit/screens/transit05_screen.dart';
import 'package:mannerfit/screens/choice_lesson_state.dart';
import 'package:mannerfit/screens/subway03_scene.dart';
import 'package:mannerfit/screens/partner_selection_screen.dart';
import 'package:mannerfit/screens/manners_hint_bubble.dart';
import 'package:mannerfit/screens/lesson_explanation_content.dart';
import 'package:mannerfit/screens/transport_progress.dart';
import 'package:mannerfit/screens/transport_lesson_screen.dart';
import 'transit04_screen_test.dart' as fixture;
import 'sequence_feedback_revision_test.dart' as fonts;
import 'application01_test.dart' as reward;
import 'application04_learning_test.dart' as app4;
import 'package:mannerfit/screens/topic_completion.dart';

void main() {
  final source =
      jsonDecode(
            File(
              'assets/transit05/problem_choice_transit05.json',
            ).readAsStringSync(),
          )
          as Map<String, dynamic>;
  final q = ChoiceProblem.fromJson(source);
  test('05 source schema, correct ID and complete education retained', () {
    expect(q.correctId, 'B');
    expect(q.maxSubmissions, 4);
    expect(q.hints.length, 2);
    final e = LessonExplanationContent.fromJson(
      jsonDecode(File('assets/transit05/explanation.json').readAsStringSync()),
    );
    final md = File(
      '../docs/design/education_content_transit05.md',
    ).readAsStringSync().replaceAll('\r\n', '\n');
    for (final r in e.reasons) {
      expect(md, contains(r.body));
    }
    for (final f in e.faqs) {
      expect(md, contains(f.answer));
    }
    expect(e.reasons.length, 3);
    expect(e.faqs.length, 3);
    expect(e.sources.length, 2);
    expect(md, contains(e.extraSections.single.body));
    expect(e.disclaimer, contains('전국 공통 벌금'));
  });
  for (final p in MannerPartner.values) {
    testWidgets(
      '${p.name}: scene, submit only, hints, four failures, reveal, replay and education',
      (t) async {
        t.view.physicalSize = const Size(393, 900);
        t.view.devicePixelRatio = 1;
        addTearDown(t.view.resetPhysicalSize);
        addTearDown(t.view.resetDevicePixelRatio);
        for (final f in [
          'problem_choice_transit05.json',
          'explanation.json',
          'scene_layout.json',
        ]) {
          rootBundle.evict('assets/transit05/$f');
        }
        await t.pumpWidget(
          RepaintBoundary(
            key: fixture.boundary,
            child: MaterialApp(
              debugShowCheckedModeBanner: false,
              theme: ThemeData(fontFamily: 'Pretendard'),
              home: Transit05Screen(partner: p),
            ),
          ),
        );
        await fixture.ready(t, 'transit05-ready');
        await fonts.captureFonts(t);
        await t.pumpAndSettle();
        final s =
            t
                    .widget<ListenableBuilder>(
                      find.byKey(const Key('transit05-ready')),
                    )
                    .listenable
                as ChoiceLessonState;
        expect(find.text(q.situations[p.name]!), findsOneWidget);
        final scene = t.widget<Subway03SceneRenderer>(
          find.byType(Subway03SceneRenderer),
        );
        final r = scene.config.rect(p, Subway03Pose.tired);
        expect(r, const Rect.fromLTWH(0, 0, 1536, 1024));
        expect(
          scene.config.asset(p, Subway03Pose.tired),
          contains(switch (p) {
            MannerPartner.cat => 'nyangnyang',
            MannerPartner.dog => 'dangdang',
            MannerPartner.monkey => 'mongmong',
          }),
        );
        final primary = find.byKey(const Key('transit05-primary'));
        expect(t.widget<FilledButton>(primary).onPressed, isNull);
        await fixture.capture(t, '${p.name}-initial');
        await fixture.tap(t, find.byKey(const ValueKey('choice-B')));
        expect(s.validSubmissions, 0);
        await fixture.capture(t, '${p.name}-selected');
        for (var i = 0; i < 2; i++) {
          await fixture.tap(t, find.byKey(const Key('transit05-hint')));
          expect(
            t.widget<MannersHintBubble>(find.byType(MannersHintBubble)).partner,
            p,
          );
          expect(s.validSubmissions, 0);
          await fixture.capture(t, '${p.name}-hint-${i + 1}');
        }
        final store = TransportProgress.instance;
        final xp = store.xp;
        final saved = jsonEncode(store.session('transport-5').toJson());
        for (var i = 0; i < 4; i++) {
          await fixture.tap(
            t,
            find.byKey(ValueKey(i.isEven ? 'choice-A' : 'choice-C')),
          );
          await tapAfterResult(t, primary);
          await t.pump();
          await t.pump(const Duration(milliseconds: 300));
          expect(s.busy, true);
          expect(
            find.byKey(const Key('sequence-result-effect')),
            findsOneWidget,
          );
          s.submit();
          expect(s.validSubmissions, i + 1);
          if (i == 0) await fixture.capture(t, '${p.name}-wrong');
          await t.pump(const Duration(milliseconds: 1500));
          if (i < 3) {
            await tapAfterResult(t, primary);
            await t.pumpAndSettle();
            expect(s.selectedId, isNull);
            expect(s.hintStep, 2);
          }
        }
        expect(s.phase, ChoicePhase.finalFailure);
        expect(s.solutionRevealed, false);
        await fixture.capture(t, '${p.name}-failure');
        await tapAfterResult(t, primary);
        await t.pumpAndSettle();
        expect(s.solutionRevealed, true);
        expect(s.success, false);
        await fixture.capture(t, '${p.name}-revealed');
        await tapAfterResult(t, primary);
        await t.pumpAndSettle();
        expect(
          t
              .widget<FilledButton>(find.byKey(const Key('explanation-next')))
              .onPressed,
          isNotNull,
        );
        await fixture.capture(t, '${p.name}-summary');
        await fixture.tap(t, find.byKey(const Key('explanation-toggle')));
        await t.pumpAndSettle();
        await fixture.capture(t, '${p.name}-details');
        await dismissResultPopup(t);
        await t.ensureVisible(find.byKey(const Key('explanation-source-1')));
        await t.pumpAndSettle();
        await fixture.capture(t, '${p.name}-sources');
        await tapAfterResult(t, find.byKey(const Key('explanation-replay')));
        await t.pumpAndSettle();
        expect(s.validSubmissions, 0);
        expect(s.hintStep, 0);
        expect(s.selectedId, isNull);
        await fixture.tap(t, find.byKey(const ValueKey('choice-B')));
        await tapAfterResult(t, primary);
        await t.pump();
        await t.pump(const Duration(milliseconds: 300));
        await fixture.capture(t, '${p.name}-correct');
        await t.pump(const Duration(milliseconds: 1500));
        expect(s.phase, ChoicePhase.correctComplete);
        expect(store.xp, xp);
        expect(jsonEncode(store.session('transport-5').toJson()), saved);
        expect(t.takeException(), isNull);
      },
    );
  }
  testWidgets(
    '04 basic/application/completion opens 05 with the same partner',
    (t) async {
      for (final f in ['problem_sequence_transit04.json', 'explanation.json']) {
        rootBundle.evict('assets/transit04/$f');
      }
      for (final f in [
        'problem_choice_transit05.json',
        'explanation.json',
        'scene_layout.json',
      ]) {
        rootBundle.evict('assets/transit05/$f');
      }
      final store = TransportProgress(persist: false);
      final memory = reward.MemoryRewards();
      addTearDown(store.dispose);
      await t.pumpWidget(
        TopicCompletionBinding(
          gateway: memory.gateway(),
          child: MaterialApp(
            home: TransportLessonScreen(
              index: 3,
              partner: MannerPartner.cat,
              store: store,
            ),
          ),
        ),
      );
      await fixture.ready(t);
      final s = fixture.state(t);
      fixture.orderAs(s, s.question.correctOrder);
      s.submit();
      s.settle();
      await t.pump();
      await tapAfterResult(t, find.byKey(const Key('sequence-primary')));
      await t.pumpAndSettle();
      await tapAfterResult(t, find.byKey(const Key('explanation-next')));
      await t.pump(const Duration(milliseconds: 400));
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
      final application = fixture.state(t);
      fixture.orderAs(application, application.question.correctOrder);
      application.submit();
      application.settle();
      await t.pumpAndSettle();
      await app4.explanation(t);
      await app4.complete(t);
      await fixture.tap(t, find.byKey(const Key('topic-completion-next')));
      await t.pump(const Duration(milliseconds: 400));
      await fixture.ready(t, 'transit05-ready');
      expect(
        t.widget<Transit05Screen>(find.byType(Transit05Screen)).partner,
        MannerPartner.cat,
      );
      expect(store.completed, 0);
      expect(memory.total, 20);
    },
  );
  for (final size in [const Size(320, 640), const Size(852, 393)]) {
    testWidgets('05 large text, reduced motion, safe footer $size', (t) async {
      t.view.physicalSize = size;
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.resetPhysicalSize);
      addTearDown(t.view.resetDevicePixelRatio);
      for (final f in [
        'problem_choice_transit05.json',
        'explanation.json',
        'scene_layout.json',
      ]) {
        rootBundle.evict('assets/transit05/$f');
      }
      await t.pumpWidget(
        MaterialApp(
          builder: (c, child) => MediaQuery(
            data: MediaQuery.of(c).copyWith(
              textScaler: TextScaler.linear(2),
              disableAnimations: true,
            ),
            child: child!,
          ),
          home: const Transit05Screen(),
        ),
      );
      await fixture.ready(t, 'transit05-ready');
      await fixture.tap(t, find.byKey(const ValueKey('choice-B')));
      final primary = find.byKey(const Key('transit05-primary'));
      expect(t.getRect(primary).bottom, lessThanOrEqualTo(size.height));
      await tapAfterResult(t, primary);
      await t.pump(const Duration(milliseconds: 1800));
      await tapAfterResult(t, primary);
      await t.pumpAndSettle();
      await fixture.tap(t, find.byKey(const Key('explanation-toggle')));
      await t.pumpAndSettle();
      await dismissResultPopup(t);
      await t.ensureVisible(find.byKey(const Key('explanation-source-1')));
      await t.pumpAndSettle();
      expect(t.takeException(), isNull);
    });
  }
}

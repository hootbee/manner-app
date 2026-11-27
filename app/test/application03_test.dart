import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mannerfit/screens/application03_screen.dart';
import 'package:mannerfit/screens/choice_lesson_state.dart';
import 'package:mannerfit/screens/common_result_popup.dart';
import 'package:mannerfit/screens/lesson_explanation_content.dart';
import 'package:mannerfit/screens/lesson_explanation_screen.dart';
import 'package:mannerfit/screens/manners_hint_bubble.dart';
import 'package:mannerfit/screens/partner_selection_screen.dart';
import 'package:mannerfit/screens/subway03_scene.dart';
import 'sequence_feedback_revision_test.dart' as fonts;
import 'transit04_screen_test.dart' as fixture;
import 'result_popup_test_helpers.dart';

void evictApplication03() {
  for (final n in [
    'asset_rules',
    'problem_choice_transit03',
    'state_asset_mapping',
  ]) {
    rootBundle.evict('assets/application03/spec/$n.json');
  }
  rootBundle.evict(
    'assets/application03/content/education_content_transit03.md',
  );
}

ChoiceLessonState application03State(WidgetTester t) =>
    t
            .widget<ListenableBuilder>(
              find.byKey(const Key('application03-ready')),
            )
            .listenable
        as ChoiceLessonState;
Future<void> choose(WidgetTester t, String id) =>
    fixture.tap(t, find.byKey(ValueKey('choice-$id')));
Future<void> primary(WidgetTester t) =>
    fixture.tap(t, find.byKey(const Key('application03-primary')));
Future<void> settle(WidgetTester t) async {
  await t.pump(const Duration(milliseconds: 300));
  await dismissResultPopup(t);
  await t.pumpAndSettle();
}

Future<void> mount(
  WidgetTester t,
  MannerPartner p,
  Size size, {
  double textScale = 1,
  bool reduced = false,
}) async {
  t.view.physicalSize = size;
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.resetPhysicalSize);
  addTearDown(t.view.resetDevicePixelRatio);
  evictApplication03();
  await t.pumpWidget(
    RepaintBoundary(
      key: fixture.boundary,
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: ThemeData(fontFamily: 'Pretendard'),
        builder: (c, child) => MediaQuery(
          data: MediaQuery.of(c).copyWith(
            textScaler: TextScaler.linear(textScale),
            disableAnimations: reduced,
            padding: const EdgeInsets.only(top: 24, bottom: 20),
          ),
          child: child!,
        ),
        home: Builder(
          builder: (c) => TextButton(
            onPressed: () => Navigator.push(
              c,
              MaterialPageRoute(
                builder: (_) => Application03Screen(
                  partner: p,
                  hasNextProblem: true,
                  soundMuted: reduced,
                ),
              ),
            ),
            child: const Text('launch'),
          ),
        ),
      ),
    ),
  );
  await t.tap(find.text('launch'));
  await t.pump(const Duration(milliseconds: 400));
  await fixture.ready(t, 'application03-ready');
  await fonts.captureFonts(t);
  await t.pumpAndSettle();
}

Future<void> capture(WidgetTester t, String name) async {
  if (fixture.captureDir.isEmpty) return;
  final scroll = find.byType(Scrollable);
  if (scroll.evaluate().isNotEmpty) {
    t.state<ScrollableState>(scroll.first).position.jumpTo(0);
    await t.pump();
  }
  await fixture.capture(t, name, copies: 0);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'v8 adapter uses original rules, exactly eight runtime PNGs, and complete educational draft',
    () async {
      evictApplication03();
      final data = await loadApplication03();
      final p = ChoiceProblem.fromJson(data.problem),
          art = Subway03SceneConfig(data.scene, root: 'assets/application03/');
      expect(p.correctId, 'B');
      expect(p.maxSubmissions, 4);
      expect(p.hints.length, 2);
      expect(art.canvas, const Size(1620, 938));
      expect(art.allAssets.toSet().length, 8);
      for (final asset in art.allAssets.toSet()) {
        expect(asset, startsWith('assets/application03/assets/'));
        expect(asset, isNot(contains('/qa/')));
        final bytes = ByteData.sublistView(File(asset).readAsBytesSync());
        expect(bytes.getUint32(16), 1620);
        expect(bytes.getUint32(20), 938);
      }
      for (final partner in MannerPartner.values) {
        for (final pose in Subway03Pose.values) {
          expect(art.rect(partner, pose), const Rect.fromLTWH(0, 0, 1620, 938));
        }
      }
      final education = LessonExplanationContent.fromJson(data.education);
      expect(education.reasons.length, 3);
      expect(education.faqs.length, 3);
      expect(education.sources.length, 3);
      final md = File(
        'assets/application03/content/education_content_transit03.md',
      ).readAsStringSync();
      for (final reason in education.reasons) {
        expect(md, contains('**${reason.title}** ${reason.body}'));
      }
      for (final faq in education.faqs) {
        expect(md, contains(faq.question));
        expect(md, contains(faq.answer));
      }
      expect(
        education.allText,
        contains('앉아 있는 승객이 실제 임산부인지 여부는 끝까지 공개하지 않습니다.'),
      );
      expect(education.allText, contains('정답 B의 표현은 MANNERS 교육 콘텐츠의 편집적 판단'));
      expect(
        jsonDecode(
          File(
            'assets/application03/spec/problem_choice_transit03.json',
          ).readAsStringSync(),
        )['content_is_draft'],
        isTrue,
      );
    },
  );
  test(
    'selection and hints do not grade; four submits and revealed answer never count as success',
    () async {
      evictApplication03();
      final data = await loadApplication03();
      final s = ChoiceLessonState(ChoiceProblem.fromJson(data.problem));
      expect(s.submit(), isFalse);
      s.showHint();
      s.showHint();
      s.showHint();
      expect(s.hintStep, 2);
      expect(s.validSubmissions, 0);
      for (var i = 0; i < 4; i++) {
        s.select(i.isEven ? 'A' : 'C');
        expect(s.validSubmissions, i);
        expect(s.phase, ChoicePhase.choosing);
        expect(s.submit(), isTrue);
        expect(s.submit(), isFalse);
        s.settle();
        if (i < 3) s.retry();
      }
      expect(s.phase, ChoicePhase.finalFailure);
      s.reveal();
      expect(s.solutionRevealed, isTrue);
      expect(s.success, isFalse);
      s.resetAttempt();
      expect(s.validSubmissions, 0);
      expect(s.selectedId, isNull);
      expect(s.hintStep, 0);
    },
  );
  for (final width in [320.0, 360.0, 390.0]) {
    for (final partner in MannerPartner.values) {
      testWidgets(
        '${partner.name} at $width: original layers, native bubble, hints, wrong/retry/correct and explanation',
        (t) async {
          await mount(t, partner, Size(width, 900));
          final s = application03State(t);
          final scene = find.byKey(const Key('application03-scene'));
          await t.ensureVisible(scene);
          await t.pumpAndSettle();
          final rect = t.getRect(scene),
              bubble = t.widget<MannersSceneSpeechBubble>(
                find.byType(MannersSceneSpeechBubble),
              );
          final actual = t.getRect(
                find.byKey(const Key('scene-speech-bubble')),
              ),
              scale = rect.width / 1620;
          expect(
            (actual.topLeft - (rect.topLeft + const Offset(938, 105) * scale))
                .distance,
            lessThan(.01),
          );
          expect(actual.width, closeTo(423 * scale, .01));
          expect(bubble.body, const Rect.fromLTWH(0, 0, 423, 243));
          expect(bubble.tailTip, const Offset(248, 280));
          expect(bubble.strokeWidth, 5);
          expect(bubble.text, '저 자리,\n괜찮은 걸까?');
          final images = t
              .widgetList<Image>(
                find.descendant(of: scene, matching: find.byType(Image)),
              )
              .toList();
          expect(images.length, 6);
          final paths = images
              .map((i) => (i.image as AssetImage).assetName)
              .toList();
          final who = switch (partner) {
            MannerPartner.dog => 'dangdang',
            MannerPartner.cat => 'nyangnyang',
            MannerPartner.monkey => 'mongmong',
          };
          expect(paths, [
            'assets/application03/assets/background/scene_background.png',
            'assets/application03/assets/passengers/passenger_seated.png',
            'assets/application03/assets/passengers/passenger_bystander.png',
            'assets/application03/assets/characters/character_$who.png',
            'assets/application03/assets/effects/emotion_bystander.png',
            'assets/application03/assets/effects/emotion_hero.png',
          ]);
          expect(
            t
                .widget<FilledButton>(
                  find.byKey(const Key('application03-primary')),
                )
                .onPressed,
            isNull,
          );
          await capture(t, '${partner.name}-${width.toInt()}-initial');
          await fixture.tap(t, find.text('힌트 보기'));
          expect(s.hintStep, 1);
          expect(s.validSubmissions, 0);
          await fixture.tap(t, find.text('다음 힌트 보기'));
          expect(s.hintStep, 2);
          expect(find.text('다음 힌트 보기'), findsNothing);
          await choose(t, 'A');
          expect(s.validSubmissions, 0);
          expect(s.phase, ChoicePhase.choosing);
          expect(find.byType(CommonResultPopup), findsNothing);
          await primary(t);
          expect(s.validSubmissions, 1);
          await settle(t);
          expect(s.phase, ChoicePhase.wrongComplete);
          await capture(t, '${partner.name}-${width.toInt()}-wrong');
          await primary(t);
          expect(s.selectedId, isNull);
          expect(s.hintStep, 2);
          await choose(t, 'B');
          expect(s.phase, ChoicePhase.choosing);
          expect(s.validSubmissions, 1);
          await primary(t);
          await settle(t);
          expect(s.success, isTrue);
          await capture(t, '${partner.name}-${width.toInt()}-correct');
          await primary(t);
          await t.pumpAndSettle();
          expect(find.byType(LessonExplanationScreen), findsOneWidget);
          final education = t.widget<LessonExplanationScreen>(
            find.byType(LessonExplanationScreen),
          );
          expect(education.partner, partner);
          expect(education.content.reasons.length, 3);
          expect(find.text('응용 03/20 · 2/2'), findsOneWidget);
          await capture(t, '${partner.name}-${width.toInt()}-explanation');
          await fixture.tap(t, find.byKey(const Key('explanation-toggle')));
          await t.pumpAndSettle();
          expect(find.byKey(const Key('explanation-details')), findsOneWidget);
          await fixture.tap(t, find.byKey(const Key('explanation-replay')));
          await t.pumpAndSettle();
          expect(s.validSubmissions, 0);
          expect(s.hintStep, 0);
          expect(t.takeException(), isNull);
          await t.pumpWidget(const SizedBox());
        },
      );
    }
  }
  testWidgets(
    'four failures keep the scene and disclose B without success, then allow explanation',
    (t) async {
      await mount(t, MannerPartner.dog, const Size(360, 844));
      final s = application03State(t);
      for (var i = 0; i < 4; i++) {
        await choose(t, i.isEven ? 'A' : 'C');
        await primary(t);
        await settle(t);
        if (i < 3) await primary(t);
      }
      expect(s.phase, ChoicePhase.finalFailure);
      expect(s.success, isFalse);
      await primary(t);
      await t.pumpAndSettle();
      expect(s.solutionRevealed, isTrue);
      expect(s.success, isFalse);
      expect(find.byType(CommonResultPopup), findsNothing);
      await primary(t);
      await t.pumpAndSettle();
      expect(
        t
            .widget<LessonExplanationScreen>(
              find.byType(LessonExplanationScreen),
            )
            .answerRevealed,
        isTrue,
      );
      expect(t.takeException(), isNull);
      await t.pumpWidget(const SizedBox());
    },
  );
  for (final size in [const Size(320, 640), const Size(852, 393)]) {
    testWidgets('large text, reduced motion and SafeArea $size', (t) async {
      await mount(t, MannerPartner.cat, size, textScale: 2, reduced: true);
      await choose(t, 'B');
      await primary(t);
      await settle(t);
      expect(application03State(t).success, isTrue);
      await primary(t);
      await t.pumpAndSettle();
      await fixture.tap(t, find.byKey(const Key('explanation-toggle')));
      await t.pumpAndSettle();
      expect(t.takeException(), isNull);
      await t.pumpWidget(const SizedBox());
    });
  }
  testWidgets(
    'native canvas comparison capture uses the actual Flutter bubble',
    (t) async {
      t.view.physicalSize = const Size(1620, 938);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.resetPhysicalSize);
      addTearDown(t.view.resetDevicePixelRatio);
      evictApplication03();
      final data = await t.runAsync(loadApplication03);
      final art = Subway03SceneConfig(
        data!.scene,
        root: 'assets/application03/',
      );
      for (final p in MannerPartner.values) {
        await t.pumpWidget(
          RepaintBoundary(
            key: fixture.boundary,
            child: MaterialApp(
              debugShowCheckedModeBanner: false,
              theme: ThemeData(fontFamily: 'Pretendard'),
              home: Scaffold(
                body: Subway03SceneRenderer(
                  config: art,
                  partner: p,
                  pose: Subway03Pose.thinking,
                ),
              ),
            ),
          ),
        );
        await fonts.captureFonts(t);
        await t.pumpAndSettle();
        await fixture.capture(t, '${p.name}-native-scene', copies: 0);
        expect(t.takeException(), isNull);
      }
      await t.pumpWidget(const SizedBox());
    },
  );
}

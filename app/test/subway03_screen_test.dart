import 'application02_test.dart' as application02;
import 'result_popup_test_helpers.dart';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mannerfit/screens/choice_lesson_state.dart';
import 'package:mannerfit/screens/action_drag_state.dart';
import 'package:mannerfit/screens/lesson_explanation_content.dart';
import 'package:mannerfit/screens/lesson_explanation_screen.dart';
import 'package:mannerfit/screens/lesson_feedback_sound.dart';
import 'package:mannerfit/screens/partner_selection_screen.dart';
import 'package:mannerfit/screens/subway03_scene.dart';
import 'package:mannerfit/screens/subway03_screen.dart';
import 'package:mannerfit/screens/transport_lesson_screen.dart';
import 'package:mannerfit/screens/transport_progress.dart';
import 'package:mannerfit/screens/transport_questions.dart';

Future<void> fonts(WidgetTester t) async {
  await t.runAsync(() async {
    await (FontLoader('Pretendard')
          ..addFont(
            rootBundle.load('assets/fonts/pretendard/Pretendard-Regular.otf'),
          )
          ..addFont(
            rootBundle.load('assets/fonts/pretendard/Pretendard-SemiBold.otf'),
          )
          ..addFont(
            rootBundle.load('assets/fonts/pretendard/Pretendard-Bold.otf'),
          ))
        .load();
    const icons = String.fromEnvironment('PREVIEW_ICONS_FONT');
    if (icons.isNotEmpty) {
      await (FontLoader(
        'MaterialIcons',
      )..addFont(File(icons).readAsBytes().then(ByteData.sublistView))).load();
    }
  });
}

Future<void> ready(WidgetTester t) async {
  for (
    var i = 0;
    i < 400 && find.byKey(const Key('subway03-ready')).evaluate().isEmpty;
    i++
  ) {
    await t.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    await t.pump(const Duration(milliseconds: 10));
  }
  expect(find.byKey(const Key('subway03-ready')), findsOneWidget);
}

void evict() {
  for (final n in [
    'problem_choice_subway03.json',
    'explanation.json',
    'scene_layout.json',
  ]) {
    rootBundle.evict('assets/subway03/$n');
  }
}

Future<void> tap(WidgetTester t, Finder f) async {
  if (f.evaluate().isEmpty) {
    await dismissResultPopup(t);
    await t.scrollUntilVisible(
      f,
      150,
      scrollable: find.byType(Scrollable).first,
    );
  }
  await dismissResultPopup(t);
  await t.ensureVisible(f);
  await t.pump();
  await tapAfterResult(t, f);
  await t.pump();
}

void main() {
  final problem = ChoiceProblem.fromJson(
    jsonDecode(
      File('assets/subway03/problem_choice_subway03.json').readAsStringSync(),
    ),
  );
  final education = LessonExplanationContent.fromJson(
    jsonDecode(File('assets/subway03/explanation.json').readAsStringSync()),
  );
  final art = Subway03SceneConfig(
    jsonDecode(File('assets/subway03/scene_layout.json').readAsStringSync()),
  );
  test('source copy, native catalog and full educational text agree', () {
    expect(transportQuestions[2].title, problem.title);
    expect(
      transportQuestions[2].options,
      problem.choices.map((c) => c.text).toList(),
    );
    expect(transportQuestions[2].hints, problem.hints);
    final md = File(
      '../docs/design/education_content_subway_03_basic.md',
    ).readAsStringSync().replaceAll('\r\n', '\n');
    for (final name in ['핵심 매너', '학습 핵심', '선택 캐릭터의 한마디']) {
      final m = RegExp('\\*\\*$name:\\*\\* (.+)').firstMatch(md)!;
      expect(education.allText, contains(m[1]));
    }
    expect(education.reasons.length, 3);
    expect(education.faqs.length, 3);
    expect(education.sources.length, 3);
    for (final r in education.reasons) {
      expect(md, contains('**${r.title}** ${r.body}'));
    }
    for (final q in education.faqs) {
      expect(md, contains('**Q. ${q.question}**\n${q.answer}'));
    }
    for (final s in education.sources) {
      expect(
        md,
        contains('${s.agency} — **${s.title}** (${s.date}): ${s.url}'),
      );
    }
    expect(education.allText, contains('착석 자체를 법적으로 처벌하는 좌석은 아닙니다.'));
  });
  test(
    'all 9 poses align to one foot line and keep visible pixels in the scene',
    () {
      final backgrounds = <String>{};
      for (final partner in MannerPartner.values) {
        backgrounds.add(art.background);
        for (final pose in Subway03Pose.values) {
          final path = art.asset(partner, pose);
          expect(path, isNot(contains('REVIEW_REQUIRED')));
          final png = ByteData.sublistView(File(path).readAsBytesSync());
          expect(png.getUint32(16), 1254);
          expect(png.getUint32(20), 1254);
          expect(png.getUint8(25), 6);
          final m = art.sprite(partner, pose),
              r = art.rect(partner, pose),
              k = art.scale(partner, pose);
          expect(
            r.left + (m['sourceFoot'][0] as num) * k,
            closeTo(art.foot.dx, 1e-7),
          );
          expect(
            r.top + (m['sourceFoot'][1] as num) * k,
            closeTo(art.foot.dy, 1e-7),
          );
          final b = art.visibleBounds(partner, pose);
          expect(b.left, greaterThanOrEqualTo(0));
          expect(b.right, lessThanOrEqualTo(1536));
          expect(b.top, greaterThanOrEqualTo(0));
          expect(b.bottom, lessThanOrEqualTo(1024));
        }
      }
      expect(backgrounds, {'assets/subway03/background.png'});
    },
  );

  for (final partner in MannerPartner.values) {
    testWidgets(
      '${partner.name} choice, expressions, hints, failures, replay and screenshots',
      (t) async {
        t.view.physicalSize = const Size(393, 900);
        t.view.devicePixelRatio = 1;
        addTearDown(t.view.resetPhysicalSize);
        addTearDown(t.view.resetDevicePixelRatio);
        await fonts(t);
        evict();
        final capture = GlobalKey();
        final sounds = <LessonFeedbackSound>[];
        await t.pumpWidget(
          RepaintBoundary(
            key: capture,
            child: MaterialApp(
              debugShowCheckedModeBanner: false,
              theme: ThemeData(fontFamily: 'Pretendard'),
              home: Subway03Screen(
                partner: partner,
                playSound: (s) async {
                  sounds.add(s);
                },
              ),
            ),
          ),
        );
        await ready(t);
        final s =
            t
                    .widget<ListenableBuilder>(
                      find.byKey(const Key('subway03-ready')),
                    )
                    .listenable
                as ChoiceLessonState;
        Subway03Pose pose() => t
            .widget<Subway03SceneRenderer>(find.byType(Subway03SceneRenderer))
            .pose;
        Future<void> shot(String name) async {
          const output = String.fromEnvironment('CAPTURE_DIR');
          if (output.isEmpty) return;
          await t.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 100)),
          );
          await t.pump();
          final img = await t.runAsync(
            () =>
                (capture.currentContext!.findRenderObject()
                        as RenderRepaintBoundary)
                    .toImage(),
          );
          final bytes = await t.runAsync(
            () => img!.toByteData(format: ui.ImageByteFormat.png),
          );
          await t.runAsync(
            () => File(
              '$output/subway03-${art.species(partner)}-$name.png',
            ).writeAsBytes(bytes!.buffer.asUint8List()),
          );
          img!.dispose();
        }

        Future<void> choose(String id) async {
          await tap(t, find.byKey(ValueKey('choice-$id')));
        }

        Future<void> primary() async {
          await tapAfterResult(t, find.byKey(const Key('subway03-primary')));
          await t.pump();
        }

        expect(pose(), Subway03Pose.tired);
        expect(s.validSubmissions, 0);
        expect(
          t
              .widget<FilledButton>(find.byKey(const Key('subway03-primary')))
              .onPressed,
          isNull,
        );
        await shot('initial');
        for (final id in ['A', 'C', 'B']) {
          await choose(id);
          expect(s.validSubmissions, 0);
          expect(find.byKey(const Key('choice-result-effect')), findsNothing);
        }
        expect(pose(), Subway03Pose.tired);
        await shot('selection-changed');
        await tap(t, find.byKey(const Key('subway03-hint')));
        await t.pump(const Duration(milliseconds: 250));
        expect(pose(), Subway03Pose.thinking);
        expect(find.text(problem.hints[0]), findsOneWidget);
        final bubble = t.getSize(find.byKey(const Key('hint-bubble')));
        final provider =
            t.widget<Image>(find.byKey(const Key('hint-profile'))).image
                as ResizeImage;
        expect(
          (provider.imageProvider as AssetImage).assetName,
          art.profile(partner),
        );
        await shot('hint1');
        await tap(t, find.byKey(const Key('subway03-hint')));
        await t.pump(const Duration(milliseconds: 250));
        expect(t.getSize(find.byKey(const Key('hint-bubble'))), bubble);
        expect(s.validSubmissions, 0);
        expect(find.byKey(const Key('subway03-hint')), findsNothing);
        await shot('hint2');
        await choose('A');
        await primary();
        expect(s.validSubmissions, 1);
        expect(s.busy, isTrue);
        expect(find.byKey(const Key('choice-result-effect')), findsOneWidget);
        await primary();
        expect(s.validSubmissions, 1);
        expect(sounds, [LessonFeedbackSound.wrong]);
        await shot('wrong-A');
        await t.pump(const Duration(milliseconds: 300));
        expect(s.feedback, problem.feedback['A']);
        expect(find.byKey(const Key('choice-result-effect')), findsNothing);
        await primary();
        expect(s.validSubmissions, 1);
        expect(s.selectedId, isNull);
        expect(s.hintStep, 2);
        await choose('C');
        await primary();
        await t.pump(const Duration(milliseconds: 300));
        expect(s.feedback, problem.feedback['C']);
        await shot('wrong-C');
        await primary();
        await choose('B');
        await primary();
        expect(s.success, isTrue);
        expect(pose(), Subway03Pose.positive);
        await t.pump(const Duration(milliseconds: 230));
        await shot('correct');
        await t.pump(const Duration(milliseconds: 100));
        await primary();
        await t.pumpAndSettle();
        expect(find.byType(LessonExplanationScreen), findsOneWidget);
        expect(find.byKey(const Key('explanation-details')), findsNothing);
        await shot('explanation');
        expect(
          t
              .widget<FilledButton>(find.byKey(const Key('explanation-next')))
              .onPressed,
          isNotNull,
        );
        await tap(t, find.byKey(const Key('explanation-toggle')));
        await t.pumpAndSettle();
        expect(find.byKey(const Key('explanation-details')), findsOneWidget);
        await shot('explanation-expanded');
        await tapAfterResult(t, find.byKey(const Key('explanation-replay')));
        await t.pumpAndSettle();
        expect(s.validSubmissions, 0);
        expect(s.hintStep, 0);
        expect(s.selectedId, isNull);
        for (var i = 0; i < 4; i++) {
          await choose(i.isEven ? 'A' : 'C');
          await primary();
          await t.pump(const Duration(milliseconds: 300));
          if (i < 3) await primary();
        }
        expect(s.phase, ChoicePhase.finalFailure);
        expect(s.selectedId, 'C');
        expect(s.success, isFalse);
        expect(pose(), Subway03Pose.thinking);
        await shot('failure-before-reveal');
        await primary();
        await t.pump(const Duration(milliseconds: 250));
        expect(s.solutionRevealed, isTrue);
        expect(s.success, isFalse);
        expect(pose(), Subway03Pose.positive);
        await shot('solution-revealed');
        await primary();
        await t.pumpAndSettle();
        expect(find.text('정답 확인 · 성공으로 기록되지 않아요.'), findsOneWidget);
        expect(t.takeException(), isNull);
      },
    );
  }

  testWidgets('existing stored completion and XP survive repeated 03 replay', (
    t,
  ) async {
    t.view.physicalSize = const Size(393, 900);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    final store = TransportProgress(persist: false);
    addTearDown(store.dispose);
    store.sessions['transport-3'] = QuestionSession(
      phase: 'complete',
      lastCorrect: true,
      firstCompletedAt: DateTime.utc(2026, 11, 1),
    );
    final before = jsonEncode(store.session('transport-3').toJson()),
        xp = store.xp;
    evict();
    await t.pumpWidget(
      MaterialApp(
        home: TransportLessonScreen(
          index: 2,
          partner: MannerPartner.cat,
          store: store,
        ),
      ),
    );
    await ready(t);
    final s =
        t
                .widget<ListenableBuilder>(
                  find.byKey(const Key('subway03-ready')),
                )
                .listenable
            as ChoiceLessonState;
    for (var i = 0; i < 2; i++) {
      s.select('B');
      s.submit();
      s.settle();
      await t.pump();
      await tapAfterResult(t, find.byKey(const Key('subway03-primary')));
      await t.pumpAndSettle();
      await tapAfterResult(t, find.byKey(const Key('explanation-replay')));
      await t.pumpAndSettle();
      expect(store.xp, xp);
      expect(jsonEncode(store.session('transport-3').toJson()), before);
    }
  });
  testWidgets('02 application then 03 preserves the selected partner', (
    t,
  ) async {
    t.view.physicalSize = const Size(393, 900);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    for (final name in [
      'asset_rules',
      'drag_zones',
      'state_asset_mapping',
      'passenger_animation',
    ]) {
      rootBundle.evict('assets/application02/spec/$name.json');
    }
    rootBundle.evict('assets/subway02/asset_rules.json');
    rootBundle.evict('assets/subway02/state_asset_mapping.json');
    evict();
    final store = TransportProgress(persist: false);
    addTearDown(store.dispose);
    await t.pumpWidget(
      MaterialApp(
        home: TransportLessonScreen(
          index: 1,
          store: store,
          partner: MannerPartner.monkey,
        ),
      ),
    );
    for (
      var i = 0;
      i < 400 && find.byKey(const Key('subway02-ready')).evaluate().isEmpty;
      i++
    ) {
      await t.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      await t.pump(const Duration(milliseconds: 10));
    }
    final s =
        t
                .widget<ListenableBuilder>(
                  find.byKey(const Key('subway02-ready')),
                )
                .listenable
            as ActionDragState;
    s.begin(1, const Offset(820, 720), true);
    s.release(1, const Offset(1200, 720));
    s.settle();
    await t.pump();
    await tap(t, find.text('해설 보기'));
    await t.pumpAndSettle();
    expect(
      t
          .widget<FilledButton>(find.byKey(const Key('explanation-next')))
          .onPressed,
      isNotNull,
    );
    await tapAfterResult(t, find.byKey(const Key('explanation-next')));
    await t.pump(const Duration(milliseconds: 400));
    for (
      var i = 0;
      i < 400 &&
          find.byKey(const Key('application02-ready')).evaluate().isEmpty;
      i++
    ) {
      await t.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 25)),
      );
      await t.pump(const Duration(milliseconds: 10));
    }
    expect(find.byKey(const Key('application02-ready')), findsOneWidget);
    await application02.drag(t, const Offset(1414, 715));
    await t.pumpAndSettle();
    expect(application02.state(t).stage, 2);
    await application02.drag(t, const Offset(475, 835));
    await application02.settleFeedback(t);
    await tap(t, find.byKey(const Key('application02-primary')));
    await t.pumpAndSettle();
    await tapAfterResult(t, find.byKey(const Key('explanation-next')));
    await t.pump(const Duration(milliseconds: 400));
    await ready(t);
    expect(
      t.widget<Subway03Screen>(find.byType(Subway03Screen)).partner,
      MannerPartner.monkey,
    );
    expect(store.completed, 0);
  });
  for (final size in [const Size(320, 640), const Size(852, 393)]) {
    testWidgets('03 large text, landscape, reduced motion and mute $size', (
      t,
    ) async {
      t.view.physicalSize = size;
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.resetPhysicalSize);
      addTearDown(t.view.resetDevicePixelRatio);
      evict();
      final sounds = <LessonFeedbackSound>[];
      await t.pumpWidget(
        MaterialApp(
          builder: (c, child) => MediaQuery(
            data: MediaQuery.of(c).copyWith(
              textScaler: TextScaler.linear(2),
              disableAnimations: true,
            ),
            child: child!,
          ),
          home: Subway03Screen(
            soundMuted: true,
            playSound: (s) async {
              sounds.add(s);
            },
          ),
        ),
      );
      await ready(t);
      await tap(t, find.byKey(const Key('choice-B')));
      final primary = find.byKey(const Key('subway03-primary'));
      expect(t.getRect(primary).bottom, lessThanOrEqualTo(size.height));
      await tapAfterResult(t, primary);
      await t.pump(const Duration(milliseconds: 300));
      await tapAfterResult(t, primary);
      await t.pumpAndSettle();
      await tap(t, find.byKey(const Key('explanation-toggle')));
      await t.pumpAndSettle();
      await dismissResultPopup(t);
      await t.ensureVisible(find.byKey(const Key('explanation-source-2')));
      await t.pumpAndSettle();
      expect(sounds, isEmpty);
      expect(t.takeException(), isNull);
    });
  }
}

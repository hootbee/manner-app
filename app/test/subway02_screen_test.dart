import 'package:mannerfit/screens/application01_screen.dart';
import 'result_popup_test_helpers.dart';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mannerfit/screens/action_drag_state.dart';
import 'package:mannerfit/screens/lesson_explanation_content.dart';
import 'package:mannerfit/screens/lesson_explanation_screen.dart';
import 'package:mannerfit/screens/lesson_feedback_sound.dart';
import 'package:mannerfit/screens/partner_selection_screen.dart';
import 'package:mannerfit/screens/subway01_screen.dart';
import 'package:mannerfit/screens/subway02_content.dart';
import 'package:mannerfit/screens/subway02_screen.dart';
import 'package:mannerfit/screens/transport_lesson_screen.dart';
import 'package:mannerfit/screens/transport_progress.dart';

Future<void> fonts(WidgetTester t) async {
  const font = String.fromEnvironment('PREVIEW_FONT');
  const icons = String.fromEnvironment('PREVIEW_ICONS_FONT');
  if (font.isEmpty) return;
  await t.runAsync(() async {
    await (FontLoader(
      'PreviewKorean',
    )..addFont(File(font).readAsBytes().then(ByteData.sublistView))).load();
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
    i < 400 && find.byKey(const Key('subway02-ready')).evaluate().isEmpty;
    i++
  ) {
    await t.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    await t.pump(const Duration(milliseconds: 10));
  }
  if (find.byKey(const Key('subway02-scene')).evaluate().isEmpty) {
    await dismissResultPopup(t);
    await t.scrollUntilVisible(
      find.byKey(const Key('subway02-scene')),
      150,
      scrollable: find.byType(Scrollable).first,
    );
  }
  expect(find.byKey(const Key('subway02-scene')), findsOneWidget);
}

void evict() {
  rootBundle.evict('assets/subway02/asset_rules.json');
  rootBundle.evict('assets/subway02/state_asset_mapping.json');
}

void main() {
  testWidgets(
    '01 explanation enters application before 02, with selected partner',
    (t) async {
      t.view.physicalSize = const Size(393, 900);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.resetPhysicalSize);
      addTearDown(t.view.resetDevicePixelRatio);
      rootBundle.evict('assets/subway01/asset_rules.json');
      rootBundle.evict('assets/subway01/state_asset_mapping.json');
      evict();
      final store = TransportProgress(persist: false);
      addTearDown(store.dispose);
      await t.pumpWidget(
        MaterialApp(
          home: TransportLessonScreen(
            index: 0,
            store: store,
            partner: MannerPartner.cat,
          ),
        ),
      );
      for (
        var i = 0;
        i < 400 && find.byKey(const Key('subway01-scene')).evaluate().isEmpty;
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
                    find.byKey(const Key('subway01-ready')),
                  )
                  .listenable
              as ActionDragState;
      s.begin(1, s.initial.center, true);
      s.release(1, const Offset(774, 727));
      s.settle();
      await t.pump();
      await dismissResultPopup(t);
      await t.ensureVisible(find.text('해설 보기'));
      await tapAfterResult(t, find.text('해설 보기'));
      await t.pumpAndSettle();
      expect(
        t
            .widget<FilledButton>(find.byKey(const Key('explanation-next')))
            .onPressed,
        isNotNull,
      );
      for (final f in [
        'geometry.json',
        'application_explanation_01.json',
        'completion_screen_spec.json',
        'reward_config.json',
      ]) {
        rootBundle.evict('assets/application01/$f');
      }
      await tapAfterResult(t, find.byKey(const Key('explanation-next')));
      await t.pump(const Duration(milliseconds: 400));
      for (
        var i = 0;
        i < 400 &&
            find.byKey(const Key('application01-ready')).evaluate().isEmpty;
        i++
      ) {
        await t.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 25)),
        );
        await t.pump();
      }
      expect(find.byKey(const Key('application01-ready')), findsOneWidget);
      expect(
        t.widget<Application01Screen>(find.byType(Application01Screen)).partner,
        MannerPartner.cat,
      );
      expect(store.completed, 0);
      expect(t.takeException(), isNull);
    },
  );

  test(
    '02 copy and full educational paragraphs preserve supplied Markdown',
    () {
      final raw = File(
        '../docs/design/education_content_subway_02.md',
      ).readAsStringSync().replaceAll('\r\n', '\n');
      final data = lessonExplanations['subway_02_basic']!;
      final all = data.allText.replaceAll('**', '');
      for (final m in RegExp(
        r'^\*\*(.+?):\*\* (.+)$',
        multiLine: true,
      ).allMatches(raw)) {
        expect(subway02Copy[m[1]], m[2]);
      }
      final detail = raw.split('### 왜 중요할까요?')[1].split('## 학습 핵심 중복 방지')[0];
      for (final p in detail.split(RegExp(r'\n\s*\n'))) {
        final text = p.trim();
        if (text.isEmpty || text.startsWith('#')) continue;
        if (RegExp(r'^\d\. ').hasMatch(text)) {
          continue; // Source fields checked below.
        }
        expect(
          all,
          contains(
            text
                .replaceAll('**', '')
                .replaceFirst(RegExp(r'^(\d\.|Q\d\.) '), ''),
          ),
        );
      }
      expect(data.reasons.length, 3);
      expect(data.faqs.length, 3);
      expect(data.sources.length, 3);
      for (final source in data.sources) {
        expect(
          raw,
          contains('**${source.title}**, ${source.body} 원문: ${source.url}'),
        );
      }
    },
  );

  for (final width in [320.0, 393.0, 430.0]) {
    testWidgets('02 real pointers, mask, feedback timing and replay at $width', (
      t,
    ) async {
      t.view.physicalSize = Size(width, 900);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.resetPhysicalSize);
      addTearDown(t.view.resetDevicePixelRatio);
      await fonts(t);
      evict();
      final key = GlobalKey();
      final sounds = <LessonFeedbackSound>[];
      await t.pumpWidget(
        RepaintBoundary(
          key: key,
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: ThemeData(fontFamily: 'PreviewKorean'),
            home: Subway02Screen(
              partner: MannerPartner.cat,
              playSound: (sound) async {
                sounds.add(sound);
              },
            ),
          ),
        ),
      );
      await ready(t);
      final s =
          t
                  .widget<ListenableBuilder>(
                    find.descendant(
                      of: find.byType(Subway01Screen),
                      matching: find.byType(ListenableBuilder),
                    ),
                  )
                  .listenable
              as ActionDragState;
      final scene = find.byKey(const Key('subway02-scene'));
      Offset screen(Offset point) {
        final rect = t.getRect(scene);
        return rect.topLeft + point * (rect.width / 1536);
      }

      Future<void> shot(String name) async {
        const output = String.fromEnvironment('CAPTURE_DIR');
        if (output.isEmpty) return;
        await t.pump();
        final image = await t.runAsync(
          () =>
              (key.currentContext!.findRenderObject() as RenderRepaintBoundary)
                  .toImage(),
        );
        final png = await t.runAsync(
          () => image!.toByteData(format: ui.ImageByteFormat.png),
        );
        await t.runAsync(
          () => File(
            '$output/subway02-$width-$name.png',
          ).writeAsBytes(png!.buffer.asUint8List()),
        );
        image!.dispose();
      }

      Future<void> drop(Offset delta) async {
        final g = await t.startGesture(screen(const Offset(820, 720)));
        expect(s.phase, ActionPhase.dragging);
        await g.moveTo(screen(const Offset(820, 720) + delta));
        await t.pump();
        await g.up();
        await t.pump();
      }

      Future<void> tap(String label) async {
        await dismissResultPopup(t);
        await t.ensureVisible(find.text(label));
        await t.pump();
        await tapAfterResult(t, find.text(label));
        await t.pump();
      }

      await shot('initial');
      for (final point in [
        const Offset(200, 700),
        const Offset(1400, 700),
        const Offset(700, 570),
      ]) {
        final g = await t.startGesture(screen(point));
        await g.moveBy(const Offset(40, 0));
        await g.up();
        await t.pump();
        expect(s.phase, ActionPhase.initial);
      }
      await drop(const Offset(25, 0));
      expect(s.wrongAttempts, 0);
      expect(sounds, isEmpty);
      final cancel = await t.startGesture(screen(const Offset(820, 720)));
      await cancel.moveBy(const Offset(30, 0));
      await cancel.cancel();
      await t.pump();
      expect(s.phase, ActionPhase.initial);
      expect(sounds, isEmpty);
      await tap('힌트 보기');
      await t.pump(const Duration(milliseconds: 250));
      expect(find.text(subway02Copy['힌트 1']!), findsOneWidget);
      final bubble = t.getRect(find.byKey(const Key('hint-bubble')));
      await shot('hint1');
      await tap('다음 힌트 보기');
      await t.pump(const Duration(milliseconds: 250));
      expect(t.getRect(find.byKey(const Key('hint-bubble'))), bubble);
      expect(find.text('다음 힌트 보기'), findsNothing);
      await shot('hint2');
      final dragging = await t.startGesture(screen(const Offset(820, 720)));
      await dragging.moveTo(screen(const Offset(900, 720)));
      await t.pump();
      expect(
        t
            .widget<Transform>(find.byKey(const Key('subway02-monkey-offset')))
            .transform
            .storage[12],
        80,
      );
      await shot('dragging');
      await dragging.up();
      await t.pump();
      expect(s.wrongAttempts, 1);
      expect(s.delta, const Offset(80, 0));
      expect(sounds, [LessonFeedbackSound.wrong]);
      final effect = t.widget<Transform>(
        find.byKey(const Key('subway02-result-effect')),
      );
      expect(
        effect.transform.storage[12],
        40,
      ); // Source X shifted by delta -40.
      await shot('wrong');
      await t.pump(const Duration(milliseconds: 260));
      expect(find.byKey(const Key('subway02-result-effect')), findsNothing);
      await t.pump(const Duration(milliseconds: 700));
      expect(s.phase, ActionPhase.wrongComplete);
      await tap('다시 시도하기');
      expect(s.delta, Offset.zero);
      expect(s.hint, 2);
      expect(s.wrongAttempts, 1);
      await drop(const Offset(380, 0));
      expect(s.success, isTrue);
      expect(sounds.last, LessonFeedbackSound.correct);
      expect(find.byKey(const Key('subway02-monkey-offset')), findsNothing);
      await shot('correct');
      await t.pump(const Duration(milliseconds: 260));
      expect(find.byKey(const Key('subway02-result-effect')), findsNothing);
      expect(find.text(subway02Copy['정답']!), findsOneWidget);
      await t.pump(const Duration(milliseconds: 700));
      await tap('해설 보기');
      await t.pumpAndSettle();
      expect(find.byType(LessonExplanationScreen), findsOneWidget);
      expect(find.byKey(const Key('explanation-details')), findsNothing);
      expect(
        t
            .widget<FilledButton>(find.byKey(const Key('explanation-next')))
            .onPressed,
        isNotNull,
      );
      expect(find.text('응용 문제로 이동'), findsOneWidget);
      await shot('explanation');
      await dismissResultPopup(t);
      await t.ensureVisible(find.byKey(const Key('explanation-toggle')));
      await t.pumpAndSettle();
      await tapAfterResult(t, find.byKey(const Key('explanation-toggle')));
      await t.pumpAndSettle();
      expect(find.byKey(const Key('explanation-details')), findsOneWidget);
      await shot('explanation-expanded');
      await tapAfterResult(t, find.byKey(const Key('explanation-replay')));
      await t.pumpAndSettle();
      expect(s.phase, ActionPhase.initial);
      expect(s.hint, 0);
      expect(s.wrongAttempts, 0);
      // Four failures must not show a correct monkey until the explicit button.
      for (var i = 0; i < 4; i++) {
        await drop(const Offset(60, 0));
        await t.pump(const Duration(milliseconds: 1000));
        if (i < 3) await tap('다시 시도하기');
      }
      expect(s.revealed, isFalse);
      expect(s.success, isFalse);
      expect(find.byKey(const Key('subway02-monkey-offset')), findsOneWidget);
      await shot('failure');
      await tap('정답 확인');
      expect(s.revealed, isTrue);
      expect(s.success, isFalse);
      expect(find.byKey(const Key('subway02-monkey-offset')), findsNothing);
      await shot('reveal');
      await tap('해설 보기');
      await t.pumpAndSettle();
      expect(find.text('정답 확인 · 성공으로 기록되지 않아요.'), findsOneWidget);
      expect(t.takeException(), isNull);
    });
  }

  testWidgets('catalog route preserves stored 02 completion and XP on replay', (
    t,
  ) async {
    t.view.physicalSize = const Size(393, 900);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    final store = TransportProgress(persist: false);
    addTearDown(store.dispose);
    store.sessions['transport-2'] = QuestionSession(
      firstCompletedAt: DateTime.utc(2026, 11, 1),
      phase: 'complete',
      lastCorrect: true,
    );
    final before = jsonEncode(store.session('transport-2').toJson());
    final xp = store.xp;
    evict();
    await t.pumpWidget(
      MaterialApp(
        home: TransportLessonScreen(
          index: 1,
          store: store,
          partner: MannerPartner.monkey,
        ),
      ),
    );
    await ready(t);
    expect(find.byType(Subway02Screen), findsOneWidget);
    final s =
        t
                .widget<ListenableBuilder>(
                  find.descendant(
                    of: find.byType(Subway01Screen),
                    matching: find.byType(ListenableBuilder),
                  ),
                )
                .listenable
            as ActionDragState;
    for (var i = 0; i < 2; i++) {
      s.begin(1, const Offset(820, 720), true);
      s.release(1, const Offset(1200, 720));
      s.settle();
      await t.pump();
      await dismissResultPopup(t);
      await t.ensureVisible(find.text('해설 보기'));
      await tapAfterResult(t, find.text('해설 보기'));
      await t.pumpAndSettle();
      await tapAfterResult(t, find.byKey(const Key('explanation-replay')));
      await t.pumpAndSettle();
      expect(jsonEncode(store.session('transport-2').toJson()), before);
      expect(store.xp, xp);
    }
  });

  for (final size in [const Size(320, 640), const Size(852, 393)]) {
    testWidgets('large text, reduced motion and muted feedback at $size', (
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
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: TextScaler.linear(2),
              disableAnimations: true,
            ),
            child: child!,
          ),
          home: Subway02Screen(
            soundMuted: true,
            playSound: (sound) async {
              sounds.add(sound);
            },
          ),
        ),
      );
      await ready(t);
      final s =
          t
                  .widget<ListenableBuilder>(
                    find.byKey(const Key('subway02-ready')),
                  )
                  .listenable
              as ActionDragState;
      await dismissResultPopup(t);
      await t.scrollUntilVisible(
        find.text('힌트 보기'),
        150,
        scrollable: find.byType(Scrollable).first,
      );
      await tapAfterResult(t, find.text('힌트 보기'));
      await t.pumpAndSettle();
      expect(find.text(subway02Copy['힌트 1']!), findsOneWidget);
      expect(t.takeException(), isNull);
      s.begin(1, const Offset(820, 720), true);
      s.release(1, const Offset(1200, 720));
      s.settle();
      await t.pump();
      await dismissResultPopup(t);
      await t.ensureVisible(find.text('해설 보기'));
      await tapAfterResult(t, find.text('해설 보기'));
      await t.pumpAndSettle();
      await dismissResultPopup(t);
      await t.ensureVisible(find.byKey(const Key('explanation-toggle')));
      await t.pumpAndSettle();
      await tapAfterResult(t, find.byKey(const Key('explanation-toggle')));
      await t.pumpAndSettle();
      await dismissResultPopup(t);
      await t.ensureVisible(find.byKey(const Key('explanation-source-2')));
      await t.pumpAndSettle();
      expect(t.takeException(), isNull);
      expect(sounds, isEmpty);
    });
  }
}

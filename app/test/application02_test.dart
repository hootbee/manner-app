import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mannerfit/screens/application02_state.dart';
import 'package:mannerfit/screens/application02_screen.dart';
import 'package:mannerfit/screens/common_result_popup.dart';
import 'package:mannerfit/screens/partner_selection_screen.dart';
import 'package:mannerfit/screens/lesson_explanation_screen.dart';
import 'package:mannerfit/screens/subway02_screen.dart';
import 'package:mannerfit/screens/action_drag_state.dart';
import 'result_popup_test_helpers.dart';
import 'sequence_feedback_revision_test.dart' as fonts;
import 'transit04_screen_test.dart' as fixture;

Map<String, dynamic> spec(String name) =>
    jsonDecode(File('assets/application02/spec/$name.json').readAsStringSync())
        as Map<String, dynamic>;
Application02State model() => Application02State(
  spec('drag_zones'),
  spec('state_asset_mapping'),
  spec('passenger_animation'),
);
Transit02Drop dropModel(Application02State s, Offset foot) {
  final start = s.foot + const Offset(0, -100);
  expect(s.begin(1, start, true), isTrue);
  s.move(1, foot + const Offset(0, -100), const Size(200, 250));
  return s.release(1, foot + const Offset(0, -100))!;
}

void stage2(Application02State s) {
  expect(dropModel(s, const Offset(1414, 715)), Transit02Drop.correct);
  s.advance(180);
  expect(s.phase, Transit02Phase.step1Success);
  s.advance(650);
  expect(s.phase, Transit02Phase.exiting);
  s.advance(1749);
  expect(s.stage, 1);
  expect(s.begin(2, s.foot, true), isFalse);
  s.advance(1);
  expect(s.stage, 2);
}

Application02State state(WidgetTester t) =>
    t
            .widget<ListenableBuilder>(
              find.byKey(const Key('application02-ready')),
            )
            .listenable
        as Application02State;
Future<void> mount(
  WidgetTester t,
  MannerPartner p,
  double width, {
  bool basic = false,
  double textScale = 1,
}) async {
  for (final name in [
    'asset_rules',
    'drag_zones',
    'state_asset_mapping',
    'passenger_animation',
  ]) {
    rootBundle.evict('assets/application02/spec/$name.json');
  }
  if (basic) {
    rootBundle.evict('assets/subway02/asset_rules.json');
    rootBundle.evict('assets/subway02/state_asset_mapping.json');
  }
  t.view.physicalSize = Size(width, 844);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.resetPhysicalSize);
  addTearDown(t.view.resetDevicePixelRatio);
  await t.pumpWidget(
    RepaintBoundary(
      key: fixture.boundary,
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: ThemeData(fontFamily: 'Pretendard'),
        builder: (c, child) => MediaQuery(
          data: MediaQuery.of(c).copyWith(
            padding: const EdgeInsets.only(top: 24, bottom: 20),
            textScaler: TextScaler.linear(textScale),
          ),
          child: child!,
        ),
        home: Builder(
          builder: (c) => TextButton(
            onPressed: () => Navigator.push(
              c,
              MaterialPageRoute(
                builder: (_) => basic
                    ? Subway02Screen(partner: p)
                    : Application02Screen(partner: p),
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
  await fixture.ready(t, basic ? 'subway02-ready' : 'application02-ready');
  await fonts.captureFonts(t);
  await t.pumpAndSettle();
}

Future<void> drag(
  WidgetTester t,
  Offset target, {
  bool offCenter = true,
}) async {
  final scene = find.byKey(const Key('application02-scene'));
  await t.ensureVisible(scene);
  await t.pumpAndSettle();
  final rect = t.getRect(scene), s = state(t), start = s.foot;
  final painter =
      t.widget<CustomPaint>(scene).painter as Application02ScenePainter;
  final hero = painter.bounds[painter.heroPath]!;
  final grab =
      start +
      (offCenter && s.stage == 2
          ? Offset(hero.width * s.scale / 2 + 1, -hero.height * s.scale / 2)
          : Offset(offCenter ? 18 : 0, -160 * s.scale));
  Offset screen(Offset p) => rect.topLeft + p * (rect.width / 1536);
  final g = await t.startGesture(screen(grab));
  expect(s.phase, Transit02Phase.dragging);
  await g.moveTo(screen(target + grab - start));
  await t.pump();
  expect(t.getRect(scene), rect);
  expect(s.wrongCount, lessThan(4));
  await g.up();
  await t.pump();
}

Future<void> capture(WidgetTester t, String name, {int copies = 0}) async {
  if (fixture.captureDir.isEmpty) return;
  final scroll = find.byType(Scrollable);
  if (scroll.evaluate().isNotEmpty) {
    t.state<ScrollableState>(scroll.first).position.jumpTo(0);
    await t.pump();
  }
  await fixture.capture(t, name, copies: copies);
}

Future<void> settleFeedback(WidgetTester t) async {
  await t.pumpAndSettle();
  await dismissResultPopup(t);
}

void main() {
  test(
    'alighting only unlocks stage2; instructions and manual judgement stay distinct',
    () {
      final s = model();
      expect(s.instruction, '캐릭터를 드래그해 보세요. · 1/2단계');
      dropModel(s, const Offset(1414, 715));
      s.advance(180);
      s.advance(650);
      expect(s.instruction, '승객들이 내리는 중이에요.');
      expect(s.canDrag, isFalse);
      s.advance(1750);
      s.advance(10000);
      expect(s.phase, Transit02Phase.ready);
      expect(s.success, isFalse);
      expect(s.instruction, Application02State.reboardInstruction);
      dropModel(s, const Offset(475, 835));
      expect(s.success, isFalse);
      s.advance(210);
      expect(s.phase, Transit02Phase.judging);
      s.advance(1750);
      expect(s.success, isTrue);
    },
  );
  test('walking position and scale have continuous velocity at path knots', () {
    for (final p
        in (spec('passenger_animation')['exiting_passengers'] as Map).values) {
      for (final key in (p['keyframes'] as List).skip(1).take(2)) {
        final ms =
            (p['delay_ms'] as num) +
            (key['t'] as num) * (p['duration_ms'] as num);
        final before = Transit02PassengerPose.at(p, ms - .01),
            at = Transit02PassengerPose.at(p, ms.toDouble()),
            after = Transit02PassengerPose.at(p, ms + .01);
        final left = (at.foot - before.foot) / .01,
            right = (after.foot - at.foot) / .01;
        expect((left - right).distance, lessThan(.01));
        expect(
          ((at.height - before.height) - (after.height - at.height)).abs(),
          lessThan(.01),
        );
      }
    }
  });
  test('v7 foot-point examples, structure precedence and safety gates', () {
    for (final row in spec('drag_zones')['testing_examples']) {
      final s = model();
      if (row['stage'] == 'step2') {
        stage2(s);
      }
      if (row['flags'] == false) {
        s.updateSafety(stopped: false, open: true, clear: true);
      }
      expect(
        s.classify(transit02Point(row['foot_anchor'])).name,
        row['expected'] == 'blocked_no_count' ? 'invalid' : row['expected'],
      );
      expect(s.wrongCount, 0);
      s.dispose();
    }
  });
  test(
    'offset preserved, duplicate pointer ignored, invalid/tap/cancel never count',
    () {
      final s = model();
      expect(s.begin(1, const Offset(680, 600), true), isTrue);
      expect(s.begin(2, Offset.zero, true), isFalse);
      s.cancel(2);
      expect(s.pointer, 1);
      s.cancel(1);
      expect(dropModel(s, const Offset(1500, 470)), Transit02Drop.invalid);
      expect(s.wrongCount, 0);
      expect(s.begin(1, s.foot, true), isTrue);
      expect(s.release(1, s.foot), Transit02Drop.invalid);
      final result = dropModel(s, const Offset(1350, 810));
      expect(result, Transit02Drop.correct);
      expect(s.wrongCount, 0);
      s.advance(180);
      expect(s.foot, const Offset(1414, 715));
      expect(s.scale, .61);
    },
  );
  test(
    '4 wrong drops across both stages, hints retained, explicit reveal without success',
    () {
      final s = model();
      s.showHint();
      s.showHint();
      expect(s.hint, 2);
      for (var i = 0; i < 2; i++) {
        expect(dropModel(s, const Offset(1110, 835)), Transit02Drop.wrong);
        s.advance(1750);
        s.retry();
      }
      stage2(s);
      for (var i = 0; i < 2; i++) {
        expect(dropModel(s, const Offset(760, 820)), Transit02Drop.wrong);
        s.advance(1750);
        if (i == 0) s.retry();
      }
      expect(s.wrongCount, 4);
      expect(s.phase, Transit02Phase.failure);
      expect(s.finished, isFalse);
      s.reveal();
      expect(s.phase, Transit02Phase.revealed);
      expect(s.success, isFalse);
      expect(s.foot, const Offset(475, 835));
      expect(s.scale, .58);
      expect(s.hint, 2);
    },
  );
  test(
    'all four safety flags required; changing a flag cancels reboard without count',
    () {
      final s = model();
      s.updateSafety(stopped: true, open: false, clear: true);
      stage2(s);
      expect(s.phase, Transit02Phase.blocked);
      s.updateSafety(stopped: true, open: true, clear: true);
      expect(s.canDrag, isTrue);
      expect(s.begin(1, s.foot, true), isTrue);
      s.updateSafety(stopped: false, open: true, clear: true);
      expect(s.pointer, isNull);
      expect(s.wrongCount, 0);
      s.updateSafety(stopped: true, open: true, clear: true);
      dropModel(s, const Offset(475, 835));
      s.advance(210);
      s.updateSafety(stopped: true, open: true, clear: false);
      expect(s.phase, Transit02Phase.blocked);
      expect(s.wrongCount, 0);
    },
  );
  test(
    'five delayed waiting/walking paths, continuous endpoints, all offscreen at 1750ms',
    () {
      final m = spec('passenger_animation');
      expect(m['duration_ms'], 1750);
      for (final p in (m['exiting_passengers'] as Map).values) {
        final delay = (p['delay_ms'] as num).toDouble();
        final waiting = Transit02PassengerPose.at(p, delay - 1);
        expect(waiting.asset, p['waiting_asset']);
        final a = Transit02PassengerPose.at(p, delay),
            b = Transit02PassengerPose.at(p, delay + .01);
        expect((a.foot - b.foot).distance, lessThan(.1));
        expect(a.asset, p['walking_a_asset']);
        final end = Transit02PassengerPose.at(p, 1750);
        expect(end.foot.dx, greaterThan(1536));
        expect(end.height, closeTo((p['render_height_px'] as num) * .9, .001));
      }
    },
  );
  for (final width in [320.0, 360.0, 390.0]) {
    for (final p in MannerPartner.values) {
      testWidgets(
        '${p.name} at $width: real offset drag, invalid/wrong, 1750ms exit, reboard, popup and replay',
        (t) async {
          await mount(t, p, width);
          final s = state(t);
          await capture(t, '${p.name}-${width.toInt()}-initial', copies: 0);
          await drag(t, const Offset(1500, 470));
          expect(s.wrongCount, 0);
          expect(s.phase, Transit02Phase.ready);
          await drag(t, const Offset(1110, 835));
          expect(s.wrongCount, 1);
          await settleFeedback(t);
          await fixture.tap(t, find.byKey(const Key('application02-primary')));
          await drag(t, const Offset(1350, 810));
          expect(s.wrongCount, 1);
          await t.pump(const Duration(milliseconds: 200));
          await t.pump(const Duration(milliseconds: 10));
          expect(s.phase, Transit02Phase.step1Success);
          expect(find.byType(CommonResultPopup), findsNothing);
          await capture(t, '${p.name}-${width.toInt()}-platform', copies: 0);
          await t.pump(const Duration(milliseconds: 700));
          expect(s.phase, Transit02Phase.exiting);
          await t.pump(const Duration(milliseconds: 1000));
          expect(s.stage, 1);
          await capture(t, '${p.name}-${width.toInt()}-exiting', copies: 0);
          await t.pumpAndSettle();
          expect(s.stage, 2);
          expect(s.safe, isTrue);
          expect(s.foot, const Offset(1414, 715));
          await capture(
            t,
            '${p.name}-${width.toInt()}-reboard-ready',
            copies: 0,
          );
          await drag(t, const Offset(557, 870));
          await settleFeedback(t);
          expect(s.success, isTrue);
          expect(s.foot, const Offset(475, 835));
          expect(s.scale, .58);
          await capture(t, '${p.name}-${width.toInt()}-success', copies: 0);
          await fixture.tap(t, find.byKey(const Key('application02-primary')));
          await t.pumpAndSettle();
          expect(find.byType(LessonExplanationScreen), findsOneWidget);
          expect(find.text('응용 02/20 · 2/2'), findsOneWidget);
          await fixture.tap(t, find.byKey(const Key('explanation-replay')));
          await t.pumpAndSettle();
          expect(state(t).stage, 1);
          expect(state(t).wrongCount, 0);
          expect(state(t).hint, 0);
          expect(state(t).exitingComplete, isFalse);
          expect(t.takeException(), isNull);
          await t.pumpWidget(const SizedBox());
        },
      );
    }
  }
  testWidgets('02 basic explanation enters application with selected partner', (
    t,
  ) async {
    await mount(t, MannerPartner.cat, 390, basic: true);
    final basic =
        t
                .widget<ListenableBuilder>(
                  find.byKey(const Key('subway02-ready')),
                )
                .listenable
            as ActionDragState;
    // Existing basic interaction is already covered by its own pointer tests.
    basic.begin(1, basic.initial.center, true);
    basic.release(1, basic.initial.center + const Offset(380, 0));
    basic.settle();
    expect(basic.success, isTrue);
    await t.pump();
    await fixture.tap(t, find.text('해설 보기'));
    await t.pumpAndSettle();
    expect(find.text('응용 문제로 이동'), findsOneWidget);
    await fixture.tap(t, find.byKey(const Key('explanation-next')));
    await t.pump(const Duration(milliseconds: 400));
    await fixture.ready(t, 'application02-ready');
    expect(
      t.widget<Application02Screen>(find.byType(Application02Screen)).partner,
      MannerPartner.cat,
    );
    await t.pumpWidget(const SizedBox());
  });
  testWidgets(
    'four wrong drops reveal the answer without a correct popup and retain explanation/replay',
    (t) async {
      await mount(t, MannerPartner.monkey, 360);
      for (var i = 0; i < 4; i++) {
        await drag(t, const Offset(1110, 835));
        await settleFeedback(t);
        if (i < 3) {
          await fixture.tap(t, find.byKey(const Key('application02-primary')));
        }
      }
      expect(state(t).phase, Transit02Phase.failure);
      await fixture.tap(t, find.byKey(const Key('application02-primary')));
      await t.pumpAndSettle();
      expect(state(t).phase, Transit02Phase.revealed);
      expect(state(t).success, isFalse);
      expect(find.byType(CommonResultPopup), findsNothing);
      await fixture.tap(t, find.byKey(const Key('application02-primary')));
      await t.pumpAndSettle();
      expect(
        t
            .widget<LessonExplanationScreen>(
              find.byType(LessonExplanationScreen),
            )
            .answerRevealed,
        isTrue,
      );
      await fixture.tap(t, find.byKey(const Key('explanation-replay')));
      await t.pumpAndSettle();
      expect(state(t).wrongCount, 0);
      expect(state(t).hint, 0);
      expect(t.takeException(), isNull);
      await t.pumpWidget(const SizedBox());
    },
  );
  testWidgets(
    'record full interaction from step1 drag through manual reboarding and explanation',
    (t) async {
      await mount(t, MannerPartner.dog, 390);
      final s = state(t), scene = find.byKey(const Key('application02-scene'));
      t
          .state<ScrollableState>(find.byType(Scrollable).first)
          .position
          .jumpTo(0);
      await t.pump();
      var frame = 0;
      final metadata = <Map<String, dynamic>>[];
      Future<void> record(Offset? pointer, {int count = 1}) async {
        for (var i = 0; i < count; i++) {
          await t.pump(const Duration(milliseconds: 50));
          final name = 'flow-${(frame++).toString().padLeft(4, '0')}';
          await fixture.capture(t, name, copies: 0);
          metadata.add({
            'file': '$name.png',
            'touch': pointer == null ? null : [pointer.dx, pointer.dy],
            'stage': s.stage,
            'phase': s.phase.name,
            'foot': [s.foot.dx, s.foot.dy],
          });
        }
      }

      Future<void> recordedDrag(Offset target) async {
        final rect = t.getRect(scene), foot = s.foot;
        final grab = foot + Offset(18, -160 * s.scale);
        Offset screen(Offset at) => rect.topLeft + at * (rect.width / 1536);
        final from = screen(grab), to = screen(target + grab - foot);
        final gesture = await t.startGesture(from);
        expect(s.phase, Transit02Phase.dragging);
        await record(from);
        for (var i = 1; i <= 14; i++) {
          final at = Offset.lerp(from, to, i / 14)!;
          await gesture.moveTo(at);
          await record(at);
          expect(s.success, isFalse);
        }
        await record(to, count: 2);
        await gesture.up();
        await record(null);
      }

      await record(null, count: 8);
      await recordedDrag(const Offset(1414, 715));
      var guard = 0;
      while (s.stage == 1 && guard++ < 100) {
        await record(null);
      }
      expect(s.stage, 2);
      expect(s.phase, Transit02Phase.ready);
      expect(s.success, isFalse);
      expect(
        t.widget<Text>(find.byKey(const Key('application02-instruction'))).data,
        Application02State.reboardInstruction,
      );
      await record(null, count: 10);
      expect(
        s.phase,
        Transit02Phase.ready,
        reason: 'Alighting alone must never finish the problem',
      );
      await recordedDrag(const Offset(475, 835));
      guard = 0;
      while (!s.success && guard++ < 60) {
        await record(null);
      }
      expect(s.success, isTrue);
      await record(null, count: 12);
      final popup = find.byKey(const Key('common-result-popup'));
      if (popup.evaluate().isNotEmpty) {
        final at = t.getCenter(popup),
            g = await t.startGesture(t.getCenter(popup));
        await record(at);
        await g.up();
        await record(null, count: 6);
      }
      final primary = find.byKey(const Key('application02-primary'));
      final at = t.getCenter(primary),
          g = await t.startGesture(t.getCenter(primary));
      await record(at);
      await g.up();
      await record(null, count: 10);
      expect(find.byType(LessonExplanationScreen), findsOneWidget);
      if (fixture.captureDir.isNotEmpty) {
        await t.runAsync(
          () => File(
            '${fixture.captureDir}/flow-metadata.json',
          ).writeAsString(jsonEncode(metadata)),
        );
      }
      expect(t.takeException(), isNull);
      await t.pumpWidget(const SizedBox());
    },
  );
  testWidgets(
    '320dp, text 2x, hint and scene remain accessible with SafeArea',
    (t) async {
      await mount(t, MannerPartner.dog, 320, textScale: 2);
      await fixture.tap(t, find.byKey(const Key('application02-hint')));
      expect(state(t).hint, 1);
      await drag(t, const Offset(1414, 715));
      await t.pumpAndSettle();
      expect(state(t).stage, 2);
      await drag(t, const Offset(475, 835));
      await settleFeedback(t);
      expect(state(t).success, isTrue);
      expect(t.takeException(), isNull);
      await t.pumpWidget(const SizedBox());
    },
  );
}

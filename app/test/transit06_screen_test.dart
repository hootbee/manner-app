import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mannerfit/screens/recline_lesson_state.dart';
import 'package:mannerfit/screens/transit06_screen.dart';
import 'package:mannerfit/screens/partner_selection_screen.dart';
import 'package:mannerfit/screens/lesson_explanation_content.dart';
import 'package:mannerfit/screens/transport_lesson_screen.dart';
import 'package:mannerfit/screens/transport_progress.dart';
import 'package:mannerfit/screens/choice_lesson_state.dart';
import 'transit04_screen_test.dart' as fixture;
import 'sequence_feedback_revision_test.dart' as fonts;
import 'application05_test.dart' as app5;
import 'application01_test.dart' as reward;
import 'package:mannerfit/screens/topic_completion.dart';

Offset rotated(Offset start, double progress) {
  final v = start - ReclineLessonState.pivot;
  final a = progress * 20 * math.pi / 180;
  return ReclineLessonState.pivot +
      Offset(
        v.dx * math.cos(a) - v.dy * math.sin(a),
        v.dx * math.sin(a) + v.dy * math.cos(a),
      );
}

Offset visible(String who, String state) {
  final bytes = File(
    'assets/transit06/hit/${who}_$state.mask',
  ).readAsBytesSync();
  for (var y = 260; y < 750; y++) {
    for (var x = 600; x < 850; x++) {
      final i = y * 1536 + x;
      if (bytes[i >> 3] & (1 << (i & 7)) != 0) {
        return Offset(x.toDouble(), y.toDouble());
      }
    }
  }
  throw StateError('No visible backrest');
}

ReclineLessonState state(WidgetTester t) =>
    t
            .widget<ListenableBuilder>(find.byKey(const Key('transit06-ready')))
            .listenable
        as ReclineLessonState;
Offset screen(WidgetTester t, Offset source) {
  final r = t.getRect(find.byKey(const Key('recline-rotation')));
  // The transformed child changes its bounds; use its untransformed ancestor.
  final scene = find
      .ancestor(
        of: find.byKey(const Key('recline-rotation')),
        matching: find.byType(AspectRatio),
      )
      .first;
  final box = t.getRect(scene);
  expect(r.width, greaterThan(0));
  return box.topLeft + source * (box.width / 1536);
}

Future<void> mount(
  WidgetTester t,
  MannerPartner p, {
  Size size = const Size(390, 844),
  double scale = 1,
}) async {
  t.view.physicalSize = size;
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.resetPhysicalSize);
  addTearDown(t.view.resetDevicePixelRatio);
  for (final name in [
    'runtime_manifest.json',
    'state_asset_mapping.json',
    'problem_transit06.json',
    'explanation.json',
  ]) {
    rootBundle.evict('assets/transit06/$name');
  }
  await t.pumpWidget(
    RepaintBoundary(
      key: fixture.boundary,
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: ThemeData(fontFamily: 'Pretendard'),
        builder: (c, child) => MediaQuery(
          data: MediaQuery.of(c).copyWith(textScaler: TextScaler.linear(scale)),
          child: child!,
        ),
        home: Transit06Screen(partner: p),
      ),
    ),
  );
  await fixture.ready(t, 'transit06-ready');
  await fonts.captureFonts(t);
  await t.pumpAndSettle();
}

Future<void> drag(
  WidgetTester t,
  String who,
  double progress, {
  bool record = false,
  String label = 'drag',
}) async {
  final s = state(t);
  final at = visible(who, '${s.character}_${s.passenger}');
  final attempts = s.attempts;
  final g = await t.startGesture(screen(t, at));
  expect(s.pointer, isNotNull);
  await g.moveTo(screen(t, const Offset(1600, 30)));
  await t.pump();
  expect(s.pointer, isNotNull);
  expect(s.attempts, attempts);
  for (var i = 1; i <= 16; i++) {
    await g.moveTo(screen(t, rotated(at, progress * i / 16)));
    await t.pump(const Duration(milliseconds: 50));
    expect(s.attempts, attempts, reason: 'No grading during drag');
    if (record) await fixture.capture(t, '$label-$i', copies: 1);
  }
  expect(s.progress, closeTo(progress, 1e-5));
  await g.up();
  await t.pump();
}

void main() {
  testWidgets(
    '05 basic/application/completion opens 06 with selected partner',
    (t) async {
      for (final name in [
        'problem_choice_transit05.json',
        'explanation.json',
        'scene_layout.json',
      ]) {
        rootBundle.evict('assets/transit05/$name');
      }
      for (final name in [
        'runtime_manifest.json',
        'state_asset_mapping.json',
        'problem_transit06.json',
        'explanation.json',
      ]) {
        rootBundle.evict('assets/transit06/$name');
      }
      final store = TransportProgress(persist: false);
      final beforeXp = store.xp;
      final memory = reward.MemoryRewards();
      await t.pumpWidget(
        TopicCompletionBinding(
          gateway: memory.gateway(),
          child: MaterialApp(
            home: TransportLessonScreen(
              index: 4,
              store: store,
              partner: MannerPartner.cat,
            ),
          ),
        ),
      );
      await fixture.ready(t, 'transit05-ready');
      final s =
          t
                  .widget<ListenableBuilder>(
                    find.byKey(const Key('transit05-ready')),
                  )
                  .listenable
              as ChoiceLessonState;
      s.select('B');
      s.submit();
      s.settle();
      await t.pump();
      await fixture.tap(t, find.byKey(const Key('transit05-primary')));
      await t.pumpAndSettle();
      await fixture.tap(t, find.byKey(const Key('explanation-next')));
      await t.pump(const Duration(milliseconds: 400));
      await fixture.ready(t, 'application05-ready');
      await t.pumpAndSettle();
      final application = app5.state(t);
      application.select('B');
      application.submit();
      application.settle();
      await t.pumpAndSettle();
      await app5.explanation(t);
      await app5.complete(t);
      await fixture.tap(t, find.byKey(const Key('topic-completion-next')));
      await t.pump(const Duration(milliseconds: 400));
      await fixture.ready(t, 'transit06-ready');
      expect(
        t.widget<Transit06Screen>(find.byType(Transit06Screen)).partner,
        MannerPartner.cat,
      );
      expect(store.xp, beforeXp);
      expect(store.completed, 0);
      expect(memory.total, 20);
      await t.pumpWidget(const SizedBox());
    },
  );
  for (final consent in [false, true]) {
    for (final p in [.09, .10, .45, .46, 1.0]) {
      test('release boundary consent=$consent progress=$p', () {
        final s = ReclineLessonState();
        if (consent) {
          s.ask();
          s.reply();
        }
        const at = Offset(740, 300);
        expect(s.begin(1, at, true), isTrue);
        expect(s.begin(2, at, true), isFalse);
        s.move(2, rotated(at, 1));
        expect(s.progress, 0);
        s.move(1, rotated(at, p));
        expect(s.attempts, 0);
        expect(s.release(1), p >= .10);
        expect(s.attempts, p >= .10 ? 1 : 0);
        expect(
          s.result,
          p < .10
              ? ''
              : !consent
              ? 'wrong_no_consent'
              : p <= .45
              ? 'correct'
              : 'wrong_excessive',
        );
        expect(s.release(1), isFalse);
        s.dispose();
      });
    }
  }
  test(
    'invalid starts, cancellation, four attempts and explicit demo preserve rule boundaries',
    () {
      final s = ReclineLessonState();
      const at = Offset(740, 300);
      expect(s.begin(1, at, false), isFalse);
      s.begin(1, at, true);
      s.move(1, rotated(at, .3));
      s.cancel(1);
      expect(s.attempts, 0);
      expect(s.progress, 0);
      s.hintTap();
      s.hintTap();
      s.hintTap();
      expect(s.hintOpen, isFalse);
      s.ask();
      s.reply();
      for (var i = 1; i <= 4; i++) {
        s.begin(i, at, true);
        s.move(i, rotated(at, .8));
        s.release(i);
        s.settle();
        expect(s.attempts, i);
        if (i < 4) {
          s.retry();
          expect(s.consent, isTrue);
          expect(s.hint, 2);
        }
      }
      expect(s.phase, 'failure');
      expect(s.progress, closeTo(.8, 1e-8));
      s.reveal();
      expect(s.progress, 0);
      expect(s.success, isFalse);
      s.demoConsent();
      s.demo(1);
      expect(s.phase, 'revealed');
      expect(s.success, isFalse);
      expect(s.attempts, 4);
      s.reset();
      expect(s.attempts, 0);
      expect(s.hint, 0);
      expect(s.consent, isFalse);
    },
  );
  test(
    'all runtime paths and nine corrected masks exist; complete education retained',
    () {
      final m = jsonDecode(
        File('assets/transit06/runtime_manifest.json').readAsStringSync(),
      );
      expect(m['pivot'], [711, 836]);
      expect(m['assets'].length, 27);
      expect(m['masks'].length, 9);
      for (final p in [...m['assets'], ...m['masks']]) {
        expect(File('assets/transit06/$p').existsSync(), isTrue, reason: p);
      }
      for (final p in m['masks']) {
        expect(File('assets/transit06/$p').lengthSync(), 1536 * 1024 ~/ 8);
      }
      final e = LessonExplanationContent.fromJson(
        jsonDecode(
          File('assets/transit06/explanation.json').readAsStringSync(),
        ),
      );
      final source = jsonDecode(
        File('assets/transit06/education_transit06.json').readAsStringSync(),
      );
      expect(e.core, source['core_manner']);
      expect(e.faqsInitiallyExpanded, isFalse);
      expect(e.reasons.length, 3);
      expect(e.faqs.length, 3);
      expect(e.sources.length, 2);
      for (var i = 0; i < 3; i++) {
        expect(e.reasons[i].body, source['why_important'][i]['body']);
        expect(e.faqs[i].answer, source['situational_qa'][i]['answer']);
      }
      expect(e.extraSections.single.body, source['learning_core_recap']);
    },
  );
  for (final p in MannerPartner.values) {
    final who = switch (p) {
      MannerPartner.dog => 'dangdang',
      MannerPartner.cat => 'nyangnyang',
      MannerPartner.monkey => 'mongmong',
    };
    testWidgets(
      '${p.name}: real pointer invalid/wrong/consent/correct and replay',
      (t) async {
        await mount(t, p);
        final s = state(t);
        await fixture.capture(t, '${p.name}-initial');
        // Foreground protagonist and fixed furniture cannot start a drag.
        for (final at in [
          const Offset(400, 500),
          const Offset(520, 760),
          const Offset(1100, 600),
        ]) {
          final g = await t.startGesture(screen(t, at));
          expect(s.pointer, isNull);
          await g.moveBy(const Offset(40, 30));
          await g.up();
        }
        expect(s.attempts, 0);
        await drag(t, who, .09);
        expect(s.attempts, 0);
        await drag(
          t,
          who,
          .3,
          record: p == MannerPartner.monkey,
          label: 'wrongA-drag',
        );
        expect(s.result, 'wrong_no_consent');
        await fixture.capture(t, '${p.name}-wrong-no-consent');
        await t.pump(const Duration(milliseconds: 1800));
        await fixture.tap(t, find.byKey(const Key('transit06-primary')));
        await t.tapAt(screen(t, const Offset(240, 300)));
        await t.pump();
        expect(s.phase, 'asking');
        expect(s.attempts, 1);
        await fixture.capture(t, '${p.name}-asking');
        await t.pump(const Duration(milliseconds: 700));
        expect(s.consent, isTrue);
        await drag(
          t,
          who,
          .7,
          record: p == MannerPartner.monkey,
          label: 'wrongB-drag',
        );
        expect(s.result, 'wrong_excessive');
        await fixture.capture(t, '${p.name}-wrong-excessive');
        await t.pump(const Duration(milliseconds: 1800));
        await fixture.tap(t, find.byKey(const Key('transit06-primary')));
        expect(s.consent, isTrue);
        await drag(t, who, .32, record: p == MannerPartner.monkey);
        expect(s.result, 'correct');
        await fixture.capture(t, '${p.name}-correct');
        await t.pump(const Duration(milliseconds: 1800));
        await fixture.tap(t, find.byKey(const Key('transit06-primary')));
        await t.pumpAndSettle();
        expect(find.byKey(const Key('explanation-toggle')), findsOneWidget);
        expect(
          t
              .widget<FilledButton>(find.byKey(const Key('explanation-next')))
              .onPressed,
          isNotNull,
        );
        await fixture.capture(t, '${p.name}-explanation');
        await fixture.tap(t, find.byKey(const Key('explanation-replay')));
        await t.pumpAndSettle();
        expect(s.attempts, 0);
        expect(s.progress, 0);
        expect(s.consent, isFalse);
        expect(t.takeException(), isNull);
        await t.pumpWidget(const SizedBox());
      },
    );
  }
  testWidgets('small screen, text scaling, hints, four failures and reveal', (
    t,
  ) async {
    await mount(t, MannerPartner.dog, size: const Size(320, 740), scale: 1.5);
    final s = state(t);
    for (var i = 0; i < 3; i++) {
      await fixture.tap(t, find.byKey(const Key('transit06-hint')));
    }
    expect(s.hint, 2);
    expect(s.hintOpen, isFalse);
    expect(s.attempts, 0);
    // Scroll scene back into view before real pointer input.
    await t.ensureVisible(find.byKey(const Key('recline-rotation')));
    await t.pumpAndSettle();
    for (var i = 0; i < 4; i++) {
      await drag(t, 'dangdang', .3);
      await t.pump(const Duration(milliseconds: 1800));
      if (i < 3) {
        await fixture.tap(t, find.byKey(const Key('transit06-primary')));
      }
    }
    expect(s.phase, 'failure');
    expect(s.attempts, 4);
    expect(s.revealed, isFalse);
    await fixture.tap(t, find.byKey(const Key('transit06-primary')));
    await t.pump(const Duration(milliseconds: 700));
    await t.pumpAndSettle();
    expect(s.revealed, isTrue);
    expect(s.success, isFalse);
    expect(s.attempts, 4);
    expect(t.takeException(), isNull);
    await t.pumpWidget(const SizedBox());
  });
  testWidgets(
    'catalogue routes 06 to dedicated screen without touching saved progress',
    (t) async {
      for (final name in [
        'runtime_manifest.json',
        'state_asset_mapping.json',
        'problem_transit06.json',
        'explanation.json',
      ]) {
        rootBundle.evict('assets/transit06/$name');
      }
      final store = TransportProgress(persist: false);
      final beforeXp = store.xp;
      final beforeSessions = jsonEncode(store.sessions);
      await t.pumpWidget(
        MaterialApp(
          home: TransportLessonScreen(
            index: 5,
            store: store,
            partner: MannerPartner.cat,
          ),
        ),
      );
      expect(find.byType(Transit06Screen), findsOneWidget);
      await fixture.ready(t, 'transit06-ready');
      expect(store.xp, beforeXp);
      expect(jsonEncode(store.sessions), beforeSessions);
      await t.pumpWidget(const SizedBox());
    },
  );
}

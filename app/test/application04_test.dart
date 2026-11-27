import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mannerfit/screens/application04_screen.dart';
import 'package:mannerfit/screens/common_result_popup.dart';
import 'package:mannerfit/screens/partner_selection_screen.dart';
import 'package:mannerfit/screens/sequence_lesson_state.dart';
import 'package:mannerfit/screens/transit04_screen.dart';
import 'sequence_feedback_revision_test.dart' as fonts;
import 'transit04_screen_test.dart' as fixture;
import 'result_popup_test_helpers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('approved data includes six safe orders and canonical reveal', () async {
    for (final partner in MannerPartner.values) {
      final data = await loadApplication04(partner);
      final s = SequenceLessonState(data.question);
      expect(s.order, ['A', 'B', 'C', 'D']);
      expect(s.question.correctOrder, ['B', 'D', 'A', 'C']);
      expect(s.question.acceptedOrders.length, 6);
      expect(s.question.gradingApproved, isTrue);
      expect(s.question.maxSubmissions, 4);
      expect(s.question.scenario, startsWith('${partner.name}는'));
      s.reorder(0, 3);
      expect(s.validSubmissions, 0);
      expect(s.success, isFalse);
      expect(s.phase, SequencePhase.editing);
      s.resetAttempt();
      expect(s.order, ['A', 'B', 'C', 'D']);
      s.dispose();
    }
    final raw = jsonDecode(
      File(
        'assets/application04/spec/problem_sequence_transit04.json',
      ).readAsStringSync(),
    );
    expect(raw['grading']['accepted_orders'].length, 6);
    expect(Directory('assets/application04/qa').existsSync(), isFalse);
    expect(Directory('assets/application04/content').existsSync(), isTrue);
  });

  for (final width in [320, 360, 390]) {
    for (final partner in MannerPartner.values) {
      testWidgets(
        '${partner.name} $width: scene, reorder, submit-only wrong feedback',
        (t) async {
          t.view.physicalSize = Size(width.toDouble(), 844);
          t.view.devicePixelRatio = 1;
          addTearDown(t.view.resetPhysicalSize);
          addTearDown(t.view.resetDevicePixelRatio);
          await t.pumpWidget(
            RepaintBoundary(
              key: fixture.boundary,
              child: MaterialApp(
                debugShowCheckedModeBanner: false,
                theme: ThemeData(fontFamily: 'Pretendard'),
                home: Application04Screen(partner: partner),
              ),
            ),
          );
          await fixture.ready(t);
          await fonts.captureFonts(t);
          await t.pumpAndSettle();
          final s = fixture.state(t);
          expect(find.text('응용 04/20 · 2/2'), findsOneWidget);
          expect(s.question.scenario, contains(partner.name));
          final scene = find.byKey(const Key('sequence-scene'));
          final image = t.widget<Image>(scene);
          expect(image.fit, BoxFit.contain);
          expect(
            (image.image as AssetImage).assetName,
            'assets/application04/assets/scenes/scene_${switch (partner) {
              MannerPartner.cat => 'nyangnyang',
              MannerPartner.dog => 'dangdang',
              MannerPartner.monkey => 'mongmong',
            }}.png',
          );
          final size = t.getSize(scene);
          expect(size.width / size.height, closeTo(976 / 397, .00001));
          expect(
            find.ancestor(of: scene, matching: find.byType(ClipRRect)),
            findsNothing,
          );
          final primary = find.byKey(const Key('sequence-primary'));
          expect(t.widget<FilledButton>(primary).onPressed, isNull);
          if (width == 390) {
            await fixture.capture(
              t,
              'application04-${partner.name}-initial',
              copies: 0,
            );
          }
          if (width == 390 && partner == MannerPartner.dog) {
            final handle = find.byKey(const ValueKey('sequence-handle-A'));
            await t.ensureVisible(handle);
            await t.pumpAndSettle();
            final start = t.getCenter(handle);
            await t.timedDragFrom(
              start,
              const Offset(0, 116),
              const Duration(milliseconds: 800),
            );
            await t.pumpAndSettle();
            expect(s.order, isNot(['A', 'B', 'C', 'D']));
            await fixture.capture(t, 'application04-dragged', copies: 0);
          } else {
            s.reorder(0, 3);
            await t.pumpAndSettle();
          }
          expect(s.validSubmissions, 0);
          expect(t.widget<FilledButton>(primary).onPressed, isNotNull);
          await t.tap(primary);
          await t.pump(const Duration(milliseconds: 1750));
          await dismissResultPopup(t);
          await t.pumpAndSettle();
          expect(s.phase, SequencePhase.wrongComplete);
          expect(s.validSubmissions, 1);
          expect(find.byType(CommonResultPopup), findsNothing);
          expect(find.text('해설 보기'), findsNothing);
          expect(t.takeException(), isNull);
          await t.pumpWidget(const SizedBox());
        },
      );
    }
  }

  testWidgets(
    'basic04 explanation opens selected application04 without changing basic grading',
    (t) async {
      await t.pumpWidget(
        const MaterialApp(
          home: Transit04Screen(partner: MannerPartner.cat, soundMuted: true),
        ),
      );
      await fixture.ready(t);
      final s = fixture.state(t);
      fixture.orderAs(s, s.question.correctOrder);
      expect(s.submit(), isTrue);
      s.settle();
      await t.pumpAndSettle();
      await t.tap(find.byKey(const Key('sequence-primary')));
      await t.pumpAndSettle();
      expect(find.text('응용 문제로 이동'), findsOneWidget);
      await t.tap(find.byKey(const Key('explanation-next')));
      await t.pump(const Duration(milliseconds: 400));
      final applicationReady = find.descendant(
        of: find.byType(Application04Screen),
        matching: find.byKey(const Key('sequence-ready')),
      );
      for (var i = 0; i < 400 && applicationReady.evaluate().isEmpty; i++) {
        await t.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 25)),
        );
        await t.pump(const Duration(milliseconds: 10));
      }
      expect(applicationReady, findsOneWidget);
      await t.pumpAndSettle();
      expect(find.byType(Application04Screen), findsOneWidget);
      expect(fixture.state(t).question.gradingApproved, isTrue);
      expect(fixture.state(t).question.scenario, startsWith('냥냥이는'));
      expect(t.takeException(), isNull);
    },
  );
}

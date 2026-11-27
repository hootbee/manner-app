import 'result_popup_test_helpers.dart';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mannerfit/screens/sequence_lesson_state.dart';
import 'package:mannerfit/screens/lesson_feedback_sound.dart';
import 'transit04_screen_test.dart' as fixture;

Future<void> captureFonts(WidgetTester t) async {
  if (fixture.captureDir.isEmpty) return;
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
  await t.pumpAndSettle();
}

void main() {
  for (final size in [const Size(320, 640), const Size(393, 900)]) {
    testWidgets('larger undistorted card frame, full text and handle $size', (
      t,
    ) async {
      await fixture.mount(t, size: size);
      await captureFonts(t);
      final s = fixture.state(t);
      final firstHandle = find.byKey(
        ValueKey('sequence-handle-${s.order.first}'),
      );
      if (firstHandle.evaluate().isEmpty) {
        await dismissResultPopup(t);
        await t.scrollUntilVisible(
          firstHandle,
          160,
          scrollable: find.byType(Scrollable).first,
        );
      }
      await dismissResultPopup(t);
      await t.ensureVisible(firstHandle);
      await t.pumpAndSettle();
      await fixture.capture(t, 'cards-${size.width.toInt()}');
      final frame = find.byKey(ValueKey('sequence-thumbnail-${s.order.first}'));
      expect(
        t.getSize(frame),
        size.width < 360 ? const Size(64, 64) : const Size(72, 72),
      );
      expect(
        t
            .widget<Image>(
              find.descendant(of: frame, matching: find.byType(Image)),
            )
            .fit,
        BoxFit.contain,
      );
      expect(
        t.getSize(find.byKey(ValueKey('sequence-handle-${s.order.first}'))),
        const Size(44, 44),
      );
      expect(s.validSubmissions, 0);
      expect(t.takeException(), isNull);
    });
  }

  for (final correct in [false, true]) {
    testWidgets(
      'large ${correct ? "green O" : "red X"}, 1750ms lock and persistent result',
      (t) async {
        final sounds = <LessonFeedbackSound>[];
        await fixture.mount(t, sounds: sounds);
        await captureFonts(t);
        final s = fixture.state(t);
        fixture.orderAs(
          s,
          correct
              ? s.question.correctOrder
              : s.question.correctOrder.reversed.toList(),
        );
        final scroll = t
            .state<ScrollableState>(find.byType(Scrollable).first)
            .position;
        scroll.jumpTo(460);
        await t.pumpAndSettle();
        final primary = find.byKey(const Key('sequence-primary'));
        expect(find.byKey(const Key('sequence-result-effect')), findsNothing);
        await tapAfterResult(t, primary);
        await t.pump();
        for (var i = 0; i < 17; i++) {
          await t.pump(const Duration(milliseconds: 100));
          expect(s.busy, isTrue);
          expect(s.validSubmissions, 1);
          expect(t.widget<FilledButton>(primary).onPressed, isNull);
          final effect = find.byKey(const Key('sequence-result-effect'));
          expect(t.getSize(effect), const Size(96, 96));
          final r = t.getRect(effect);
          expect(r.top, greaterThanOrEqualTo(0));
          expect(r.bottom, lessThanOrEqualTo(t.getRect(primary).top));
          expect(
            find.byKey(
              Key(
                correct ? 'sequence-overlay-correct' : 'sequence-overlay-wrong',
              ),
            ),
            findsOneWidget,
          );
          if (i == 9) {
            // The overlay follows the visible card region when the list scrolls.
            scroll.jumpTo(scroll.pixels + 35);
            await t.pump();
          }
          await fixture.capture(
            t,
            '${correct ? "correct" : "wrong"}-${i.toString().padLeft(2, '0')}',
            copies: 1,
          );
          s.submit();
          s.reorder(0, 4);
          expect(s.validSubmissions, 1);
        }
        await t.pump(const Duration(milliseconds: 60));
        await t.pumpAndSettle();
        expect(s.busy, isFalse);
        expect(find.byKey(const Key('sequence-result-effect')), findsNothing);
        final resultKey = Key(
          correct ? 'sequence-result-correct' : 'sequence-result-wrong',
        );
        await dismissResultPopup(t);
        await t.ensureVisible(find.byKey(resultKey));
        await t.pumpAndSettle();
        expect(find.byKey(resultKey), findsOneWidget);
        await fixture.capture(
          t,
          correct ? 'correct-persistent' : 'wrong-persistent',
        );
        if (!correct) {
          await fixture.tap(t, find.byKey(const Key('sequence-hint')));
          expect(find.byKey(resultKey), findsOneWidget);
          expect(s.hintStep, 1);
          final before = List.of(s.order);
          await tapAfterResult(t, primary);
          await t.pumpAndSettle();
          expect(s.order, before);
          expect(find.byKey(resultKey), findsNothing);
        }
        expect(sounds, [
          correct ? LessonFeedbackSound.correct : LessonFeedbackSound.wrong,
        ]);
        expect(t.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'large text landscape, reduced motion, mute and rotation keep result legible',
    (t) async {
      final sounds = <LessonFeedbackSound>[];
      await fixture.mount(
        t,
        size: const Size(320, 640),
        scale: 2,
        reduced: true,
        sounds: sounds,
      );
      final s = fixture.state(t);
      fixture.orderAs(s, s.question.correctOrder);
      await t.pump();
      await tapAfterResult(t, find.byKey(const Key('sequence-primary')));
      await t.pump(const Duration(milliseconds: 800));
      expect(s.busy, isTrue);
      t.view.physicalSize = const Size(852, 393);
      await t.pump();
      await t.pump(const Duration(milliseconds: 1000));
      await t.pumpAndSettle();
      expect(s.phase, SequencePhase.correctComplete);
      final result = find.byKey(const Key('sequence-result-correct'));
      if (result.evaluate().isEmpty) {
        await dismissResultPopup(t);
        await t.scrollUntilVisible(
          result,
          160,
          scrollable: find.byType(Scrollable).first,
        );
      }
      await dismissResultPopup(t);
      await t.ensureVisible(result);
      await t.pumpAndSettle();
      expect(sounds, isEmpty);
      expect(t.takeException(), isNull);
    },
  );
}

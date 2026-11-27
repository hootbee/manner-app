import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mannerfit/screens/action_drag_state.dart';
import 'package:mannerfit/screens/manners_hint_bubble.dart';
import 'package:mannerfit/screens/partner_selection_screen.dart';
import 'package:mannerfit/screens/lesson_feedback_sound.dart';
import 'package:mannerfit/screens/learning_screens.dart';
import 'package:mannerfit/screens/subway01_screen.dart';

void main() {
  testWidgets(
    'selected partner reaches subway through category and lesson routes',
    (t) async {
      await t.pumpWidget(
        const MaterialApp(
          home: LearningCategoryScreen(partner: MannerPartner.cat),
        ),
      );
      await t.tap(find.text('대중교통 매너'));
      await t.pump();
      await t.pump(const Duration(milliseconds: 400));
      expect(
        t
            .widget<LearningLessonScreen>(find.byType(LearningLessonScreen))
            .partner,
        MannerPartner.cat,
      );
      await t.tap(find.text('혼잡한 지하철에서 백팩 관리하기'));
      await t.pump();
      await t.pump(const Duration(milliseconds: 400));
      expect(
        t.widget<Subway01Screen>(find.byType(Subway01Screen)).partner,
        MannerPartner.cat,
      );
      await t.pumpWidget(const SizedBox());
      await t.pump();
    },
  );
  test('mask dilation accepts near-bag touch but excludes background', () {
    final bytes = Uint8List(40 * 40 * 4);
    bytes[(20 * 40 + 20) * 4] = 255;
    final mask = DragStartMask(
      rgba: bytes,
      width: 40,
      height: 40,
      bounds: const Rect.fromLTWH(20, 20, 1, 1),
    );
    expect(mask.hit(const Offset(22, 20), 0), isFalse);
    expect(mask.hit(const Offset(22, 20), 3), isTrue);
    expect(mask.hit(const Offset(24, 20), 3), isFalse);
    expect(mask.hit(const Offset(1, 1), 3), isFalse);
    expect(mask.hit(const Offset(-1, 20), 3), isFalse);
  });
  test('independent sounds respect mute and swallow player failures', () async {
    final played = <LessonFeedbackSound>[];
    Future<void> play(LessonFeedbackSound sound) async {
      played.add(sound);
    }

    await playLessonFeedbackSound(
      play,
      LessonFeedbackSound.correct,
      muted: true,
    );
    expect(played, isEmpty);
    await playLessonFeedbackSound(
      play,
      LessonFeedbackSound.correct,
      muted: false,
    );
    await playLessonFeedbackSound(
      play,
      LessonFeedbackSound.wrong,
      muted: false,
    );
    expect(played, [LessonFeedbackSound.correct, LessonFeedbackSound.wrong]);
    await playLessonFeedbackSound(
      (_) async => throw StateError('audio unavailable'),
      LessonFeedbackSound.correct,
      muted: false,
    );
  });
  for (final partner in MannerPartner.values) {
    testWidgets(
      '${partner.name} hint keeps geometry and scrolls with large text',
      (t) async {
        Future<void> mount(int stage) => t.pumpWidget(
          MaterialApp(
            home: MediaQuery(
              data: const MediaQueryData(textScaler: TextScaler.linear(2.5)),
              child: Scaffold(
                body: Center(
                  child: SizedBox(
                    width: 284,
                    child: MannersHintBubble(partner: partner, stage: stage),
                  ),
                ),
              ),
            ),
          ),
        );
        await mount(1);
        await t.pump();
        final bubble = t.getRect(find.byKey(const Key('hint-bubble')));
        final profile = t.getRect(find.byKey(const Key('hint-profile')));
        expect(bubble.height, 84);
        expect(profile.size, const Size(56, 56));
        expect(t.getSize(find.byType(MannersHintBubble)).height, 96);
        await t.drag(
          find.byKey(const ValueKey('hint-body-1')),
          const Offset(0, -100),
        );
        await t.pump();
        await mount(2);
        await t.pump();
        expect(t.getRect(find.byKey(const Key('hint-bubble'))), bubble);
        expect(t.getRect(find.byKey(const Key('hint-profile'))), profile);
        expect(t.takeException(), isNull);
      },
    );
  }
}

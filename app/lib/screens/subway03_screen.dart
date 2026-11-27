import 'package:flutter/material.dart';
import 'choice_lesson_screen.dart';
import 'lesson_feedback_sound.dart';
import 'partner_selection_screen.dart';
import 'application03_screen.dart';

class Subway03Screen extends StatelessWidget {
  const Subway03Screen({
    super.key,
    this.partner = MannerPartner.dog,
    this.playSound,
    this.soundMuted = false,
    this.onNextProblem,
  });
  final MannerPartner partner;
  final LessonSoundPlayer? playSound;
  final bool soundMuted;
  final VoidCallback? onNextProblem;
  @override
  Widget build(BuildContext context) => ChoiceLessonScreen(
    partner: partner,
    playSound: playSound,
    soundMuted: soundMuted,
    onNextProblem: onNextProblem,
    applicationBuilder: (_, answerRevealed) => Application03Screen(
      partner: partner,
      playSound: playSound,
      soundMuted: soundMuted,
      hasNextProblem: onNextProblem != null,
    ),
  );
}

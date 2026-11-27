import 'package:flutter/material.dart';
import 'lesson_feedback_sound.dart';
import 'partner_selection_screen.dart';
import 'subway01_screen.dart';

/// 02 uses the same interaction shell, hint, effects and explanation as 01.
class Subway02Screen extends StatelessWidget {
  const Subway02Screen({
    super.key,
    this.partner = MannerPartner.dog,
    this.playSound,
    this.soundMuted = false,
    this.debugHitboxes = const bool.fromEnvironment('SUBWAY02_DEBUG_HITBOXES'),
    this.onNextProblem,
  });
  final MannerPartner partner;
  final LessonSoundPlayer? playSound;
  final bool soundMuted;
  final bool debugHitboxes;
  final VoidCallback? onNextProblem;

  @override
  Widget build(BuildContext context) => Subway01Screen(
    lesson: SubwayLesson.exit,
    partner: partner,
    playSound: playSound,
    soundMuted: soundMuted,
    debugHitboxes: debugHitboxes,
    onNextProblem: onNextProblem,
  );
}

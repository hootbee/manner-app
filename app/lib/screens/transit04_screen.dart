import 'package:flutter/material.dart';
import 'dart:math';
import 'sequence_lesson_screen.dart';
import 'lesson_feedback_sound.dart';
import 'partner_selection_screen.dart';
import 'application04_screen.dart';
import 'topic_completion.dart';

class Transit04Screen extends StatelessWidget {
  const Transit04Screen({
    super.key,
    this.partner = MannerPartner.dog,
    this.playSound,
    this.soundMuted = false,
    this.random,
    this.onNextProblem,
  });
  final MannerPartner partner;
  final LessonSoundPlayer? playSound;
  final bool soundMuted;
  final Random? random;
  final VoidCallback? onNextProblem;
  @override
  Widget build(BuildContext context) => SequenceLessonScreen(
    questionAsset: 'assets/transit04/problem_sequence_transit04.json',
    explanationAsset: 'assets/transit04/explanation.json',
    assetPrefix: 'assets/transit04/',
    sceneAsset: 'assets/transit04/assets/scene/bus_scene_approved_flat.png',
    sceneAspectRatio: 960 / 384,
    sceneLabel: '몽몽이와 앞서 내리는 어르신, 뒤에서 기다리는 승객들이 포함된 승인 버스 장면',
    number: 4,
    partner: partner,
    playSound: playSound,
    soundMuted: soundMuted,
    random: random,
    onNextProblem: onNextProblem,
    applicationBuilder: (_, state) => Application04Screen(
      partner: partner,
      basicOutcome: state.solutionRevealed
          ? LearningEnd.answerRevealed
          : LearningEnd.directCorrect,
      playSound: playSound,
      soundMuted: soundMuted,
      hasNextProblem: onNextProblem != null,
    ),
  );
}

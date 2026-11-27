import 'package:flutter/material.dart';
import 'choice_lesson_screen.dart';
import 'partner_selection_screen.dart';
import 'application05_screen.dart';
import 'topic_completion.dart';

class Transit05Screen extends StatelessWidget {
  const Transit05Screen({
    super.key,
    this.partner = MannerPartner.dog,
    this.onNextProblem,
  });
  final MannerPartner partner;
  final VoidCallback? onNextProblem;
  @override
  Widget build(BuildContext context) => ChoiceLessonScreen(
    partner: partner,
    onNextProblem: onNextProblem,
    assetRoot: 'assets/transit05/',
    questionFile: 'problem_choice_transit05.json',
    number: 5,
    keyPrefix: 'transit05',
    enhancedFeedback: true,
    applicationBuilder: (_, revealed) => Application05Screen(
      partner: partner,
      basicOutcome: revealed
          ? LearningEnd.answerRevealed
          : LearningEnd.directCorrect,
      hasNextProblem: onNextProblem != null,
    ),
  );
}

import 'package:flutter/foundation.dart';

class ChoiceOption {
  const ChoiceOption(this.id, this.text);
  final String id, text;
}

class ChoiceProblem {
  ChoiceProblem.fromJson(Map<String, dynamic> j)
    : id = j['problem_id'] ?? j['id'],
      situations = Map.unmodifiable({
        for (final e in (j['situationByCharacter'] as Map? ?? {}).entries)
          ({'dangdang': '댕댕이', 'nyangnyang': '냥냥이', 'mongmong': '몽몽이'}[e.key] ??
                  e.key):
              e.value as String,
      }),
      title = j['title'],
      situation =
          j['situation'] ?? (j['situationByCharacter'] as Map)['mongmong'],
      instruction = j['instruction'],
      correctId = j['correct_choice_id'] ?? j['correctOptionId'],
      choices = List.unmodifiable(
        ((j['choices'] ?? j['options']) as List).map(
          (c) => ChoiceOption(c['id'], c['text']),
        ),
      ),
      feedback = Map.unmodifiable(Map<String, String>.from(j['feedback'])),
      hints = List.unmodifiable(
        (j['hints'] as List).map((h) => h['text'] as String),
      ),
      maxSubmissions =
          j['attempts']['max_valid_submissions'] ??
          j['attempts']['maxJudgedAttempts'],
      submitLabel = j['submit_button'] ?? '제출하기',
      correctLabel = j['post_correct_button'] ?? '해설 보기',
      retryLabel = (j['post_wrong_buttons'] as List?)?.last ?? '다시 시도하기',
      failLabel = j['fail_button'] ?? '정답 확인';
  final String id, title, situation, instruction, correctId;
  final String submitLabel, correctLabel, retryLabel, failLabel;
  final List<ChoiceOption> choices;
  final Map<String, String> situations;
  final Map<String, String> feedback;
  final List<String> hints;
  final int maxSubmissions;
}

enum ChoicePhase {
  choosing,
  correctJustJudged,
  correctComplete,
  wrongJustJudged,
  wrongComplete,
  finalFailure,
  solutionRevealed,
}

/// Local practice state only: never saves records or grants completion/XP.
class ChoiceLessonState extends ChangeNotifier {
  ChoiceLessonState(this.problem);
  final ChoiceProblem problem;
  ChoicePhase phase = ChoicePhase.choosing;
  String? selectedId;
  int validSubmissions = 0, hintStep = 0;
  bool get busy =>
      phase == ChoicePhase.correctJustJudged ||
      phase == ChoicePhase.wrongJustJudged;
  bool get success =>
      phase == ChoicePhase.correctJustJudged ||
      phase == ChoicePhase.correctComplete;
  bool get solutionRevealed => phase == ChoicePhase.solutionRevealed;
  bool get canSelect => phase == ChoicePhase.choosing;
  bool get canSubmit => canSelect && selectedId != null;
  bool get canHint =>
      (canSelect || phase == ChoicePhase.wrongComplete) &&
      hintStep < problem.hints.length;
  String get feedback =>
      selectedId == null ? '' : problem.feedback[selectedId]!;
  void select(String id) {
    if (!canSelect || !problem.choices.any((c) => c.id == id)) return;
    selectedId = id;
    notifyListeners();
  }

  bool submit() {
    if (!canSubmit) return false;
    validSubmissions++;
    phase = selectedId == problem.correctId
        ? ChoicePhase.correctJustJudged
        : ChoicePhase.wrongJustJudged;
    notifyListeners();
    return true;
  }

  void settle() {
    if (!busy) return;
    phase = success
        ? ChoicePhase.correctComplete
        : validSubmissions >= problem.maxSubmissions
        ? ChoicePhase.finalFailure
        : ChoicePhase.wrongComplete;
    notifyListeners();
  }

  void retry() {
    if (phase != ChoicePhase.wrongComplete) return;
    selectedId = null;
    phase = ChoicePhase.choosing;
    notifyListeners();
  }

  void showHint() {
    if (!canHint) return;
    hintStep++;
    notifyListeners();
  }

  void reveal() {
    if (phase != ChoicePhase.finalFailure) return;
    phase = ChoicePhase.solutionRevealed;
    notifyListeners();
  }

  void resetAttempt() {
    phase = ChoicePhase.choosing;
    selectedId = null;
    validSubmissions = 0;
    hintStep = 0;
    notifyListeners();
  }
}

import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:mannerfit/screens/choice_lesson_state.dart';

void main() {
  late ChoiceLessonState s;
  setUp(
    () => s = ChoiceLessonState(
      ChoiceProblem.fromJson(
        jsonDecode(
          File(
            'assets/subway03/problem_choice_subway03.json',
          ).readAsStringSync(),
        ),
      ),
    ),
  );
  tearDown(() => s.dispose());
  test('selection changes are ungraded; only explicit submit judges once', () {
    expect(s.canSubmit, isFalse);
    expect(s.submit(), isFalse);
    for (final id in ['A', 'C', 'B']) {
      s.select(id);
      expect(s.selectedId, id);
      expect(s.validSubmissions, 0);
      expect(s.phase, ChoicePhase.choosing);
      expect(s.canSubmit, isTrue);
    }
    expect(s.submit(), isTrue);
    expect(s.validSubmissions, 1);
    expect(s.success, isTrue);
    expect(s.busy, isTrue);
    expect(s.submit(), isFalse);
    s.select('A');
    expect(s.selectedId, 'B');
    s.settle();
    expect(s.phase, ChoicePhase.correctComplete);
  });
  test('A/C keep their own feedback; retry preserves attempts and hints', () {
    for (final id in ['A', 'C']) {
      s.showHint();
      s.select(id);
      s.submit();
      expect(s.feedback, s.problem.feedback[id]);
      expect(s.success, isFalse);
      s.settle();
      s.retry();
      expect(s.selectedId, isNull);
      expect(s.phase, ChoicePhase.choosing);
    }
    expect(s.validSubmissions, 2);
    expect(s.hintStep, 2);
    s.showHint();
    expect(s.hintStep, 2);
  });
  test(
    'four wrong submissions require reveal; reveal never credits success',
    () {
      for (var i = 0; i < 4; i++) {
        s.select(i.isEven ? 'A' : 'C');
        s.submit();
        s.settle();
        s.retry();
        expect(s.validSubmissions, i + 1);
      }
      expect(s.phase, ChoicePhase.finalFailure);
      expect(s.selectedId, 'C');
      expect(s.solutionRevealed, isFalse);
      expect(s.canSubmit, isFalse);
      s.select('B');
      expect(s.selectedId, 'C');
      s.reveal();
      expect(s.phase, ChoicePhase.solutionRevealed);
      expect(s.selectedId, 'C');
      expect(s.success, isFalse);
      s.resetAttempt();
      expect(s.phase, ChoicePhase.choosing);
      expect(s.validSubmissions, 0);
      expect(s.hintStep, 0);
      expect(s.selectedId, isNull);
    },
  );
  test('data supplies the answer, including a different correct choice', () {
    final raw = jsonDecode(
      File('assets/subway03/problem_choice_subway03.json').readAsStringSync(),
    );
    raw['correct_choice_id'] = 'C';
    final other = ChoiceLessonState(ChoiceProblem.fromJson(raw));
    addTearDown(other.dispose);
    other.select('C');
    other.submit();
    expect(other.success, isTrue);
  });
}

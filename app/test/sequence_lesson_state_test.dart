import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:mannerfit/screens/sequence_lesson_state.dart';

void main() {
  final q = SequenceQuestion.fromJson(
    jsonDecode(
      File(
        'assets/transit04/problem_sequence_transit04.json',
      ).readAsStringSync(),
    ),
  );
  late SequenceLessonState s;
  setUp(() => s = SequenceLessonState(q, random: Random(7)));
  tearDown(() => s.dispose());
  void moveTo(List<String> order) {
    for (var i = 0; i < order.length; i++) {
      final old = s.order.indexOf(order[i]);
      if (old != i) s.reorder(old, old < i ? i + 1 : i);
    }
  }

  test(
    'fresh shuffle varies, excludes correct, and preserves all card IDs',
    () {
      final seen = <String>{};
      for (var seed = 0; seed < 80; seed++) {
        final other = SequenceLessonState(q, random: Random(seed));
        expect(other.order, isNot(q.correctOrder));
        expect(other.order.toSet(), q.correctOrder.toSet());
        expect(other.canSubmit, isFalse);
        seen.add(other.order.join(','));
        other.dispose();
      }
      expect(seen.length, greaterThan(8));
    },
  );
  test('no-op, drag and hints never grade; real reorder enables submit', () {
    final before = List.of(s.order);
    s.reorder(0, 0);
    s.reorder(0, 1);
    expect(s.order, before);
    expect(s.canSubmit, isFalse);
    expect(s.submit(), isFalse);
    s.startDrag();
    expect(s.canSubmit, isFalse);
    s.endDrag();
    s.showHint();
    s.showHint();
    expect(s.order, before);
    expect(s.validSubmissions, 0);
    s.reorder(0, 4);
    expect(s.order, [...before.skip(1), before.first]);
    expect(s.validSubmissions, 0);
    expect(s.canSubmit, isTrue);
  });
  test('all four positions use old/new insertion-index correction', () {
    for (var old = 0; old < 4; old++) {
      for (var target = 0; target < 4; target++) {
        final before = List.of(s.order);
        final expected = List.of(before);
        expected.insert(target, expected.removeAt(old));
        s.reorder(old, target > old ? target + 1 : target);
        expect(s.order, expected);
      }
    }
    expect(s.validSubmissions, 0);
  });
  test('all IDs must match on submit; locks duplicate input', () {
    moveTo(q.correctOrder);
    expect(s.validSubmissions, 0);
    expect(s.success, isFalse);
    if (!s.hasReordered) {
      s.reorder(0, 4);
      moveTo(q.correctOrder);
    }
    expect(s.submit(), isTrue);
    expect(s.validSubmissions, 1);
    expect(s.success, isTrue);
    final saved = List.of(s.order);
    s.reorder(0, 4);
    s.showHint();
    expect(s.order, saved);
    expect(s.submit(), isFalse);
    s.settle();
    expect(s.phase, SequencePhase.correctComplete);
  });
  test(
    'wrong retry and hints preserve user order; fourth failure waits for reveal',
    () {
      final wrong = q.correctOrder.reversed.toList();
      moveTo(wrong);
      if (!s.hasReordered) {
        s.reorder(0, 4);
        moveTo(wrong);
      }
      s.showHint();
      for (var n = 0; n < 4; n++) {
        s.submit();
        s.settle();
        expect(s.order, wrong);
        expect(s.validSubmissions, n + 1);
        s.retry();
        expect(s.order, wrong);
        expect(s.hintStep, 1);
      }
      expect(s.phase, SequencePhase.finalFailure);
      expect(s.solutionRevealed, isFalse);
      s.reorder(0, 4);
      expect(s.order, wrong);
      s.reveal();
      expect(s.order, q.correctOrder);
      expect(s.success, isFalse);
      expect(s.solutionRevealed, isTrue);
      s.resetAttempt();
      expect(s.canSubmit, isFalse);
      expect(s.validSubmissions, 0);
      expect(s.hintStep, 0);
      expect(s.order, isNot(q.correctOrder));
    },
  );
}

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mannerfit/screens/action_drag_state.dart';

void main() {
  late ActionDragState state;
  setUp(
    () => state = ActionDragState(
      jsonDecode(File('assets/subway01/asset_rules.json').readAsStringSync()),
    ),
  );
  tearDown(() => state.dispose());
  test('replay clears only disposable interaction state', () {
    state.showHint();
    state.showHint();
    for (var i = 0; i < 4; i++) {
      state.begin(1, state.initial.center, true);
      state.release(1, const Offset(1020, 821));
      state.settle();
      state.retry();
    }
    state.reveal();
    state.resetAttempt();
    expect(state.phase, ActionPhase.initial);
    expect(state.hint, 0);
    expect(state.wrongAttempts, 0);
    expect(state.revealed, isFalse);
    expect(state.pointer, isNull);
    expect(state.delta, Offset.zero);
    expect(state.canDrag, isTrue);
  });
  test(
    'expanded aisle covers both floor sides, correct zone stays distinct',
    () {
      for (final point in [const Offset(300, 920), const Offset(1300, 920)]) {
        expect(state.contains('wrong', point), isTrue);
        expect(state.contains('correct', point), isFalse);
        state.begin(1, state.initial.center, true);
        state.release(1, point);
        expect(state.phase, ActionPhase.wrongJustJudged);
        state.settle();
        state.retry();
      }
      expect(state.contains('correct', const Offset(774, 727)), isTrue);
      expect(state.contains('wrong', const Offset(774, 727)), isFalse);
      state.begin(1, state.initial.center, true);
      state.release(1, const Offset(1000, 180));
      expect(state.canDrag, isTrue);
      expect(state.wrongAttempts, 2);
    },
  );
  test(
    'pointer offset is retained, other pointers ignored, cancel is free',
    () {
      expect(state.begin(1, const Offset(920, 660), false), isFalse);
      state.begin(1, const Offset(920, 660), true);
      expect(state.delta, Offset.zero);
      expect(state.begin(2, const Offset(920, 660), true), isFalse);
      state.move(2, const Offset(800, 700));
      expect(state.delta, Offset.zero);
      state.move(1, const Offset(930, 650));
      expect(state.delta, const Offset(10, -10));
      state.cancel(1);
      expect(state.wrongAttempts, 0);
      expect(state.canDrag, isTrue);
    },
  );
  test('invalid and outside drops do not spend attempts', () {
    for (final position in [const Offset(500, 550), const Offset(-1, 700)]) {
      state.begin(1, state.initial.center, true);
      state.release(1, position);
      expect(state.wrongAttempts, 0);
      expect(state.delta, Offset.zero);
    }
  });
  test('four wrong judgments lock retries; reveal never succeeds', () {
    state.showHint();
    state.showHint();
    state.showHint();
    expect(state.hint, 2);
    for (var i = 0; i < 4; i++) {
      state.begin(1, state.initial.center, true);
      state.release(1, const Offset(1020, 821));
      expect(state.busy, isTrue);
      expect(state.begin(2, state.initial.center, true), isFalse);
      state.settle();
      state.retry();
    }
    expect(state.wrongAttempts, 4);
    expect(state.phase, ActionPhase.finalFailure);
    state.reveal();
    expect(state.revealed, isTrue);
    expect(state.success, isFalse);
  });
  test('judges bag center instead of finger; correct state persists', () {
    final finger = state.initial.topLeft;
    state.begin(1, finger, true);
    state.release(1, finger + (const Offset(774, 727) - state.initial.center));
    expect(state.success, isTrue);
    state.settle();
    expect(state.phase, ActionPhase.correctComplete);
  });
}

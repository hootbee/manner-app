import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mannerfit/screens/action_drag_state.dart';

void main() {
  late ActionDragState s;
  setUp(
    () => s = ActionDragState(
      jsonDecode(File('assets/subway02/asset_rules.json').readAsStringSync()),
    ),
  );
  tearDown(() => s.dispose());
  void drop(Offset delta, {Offset touch = const Offset(800, 650)}) {
    expect(s.begin(1, touch, true), isTrue);
    expect(s.delta, Offset.zero);
    s.release(1, touch + delta);
  }

  test('feet, not finger or body center, judge a valid correct drop', () {
    drop(const Offset(380, 0)); // Feet (1210,902), finger (1180,650).
    expect(s.success, isTrue);
    expect(s.wrongAttempts, 0);
    expect(s.begin(2, const Offset(800, 650), true), isFalse);
    s.settle();
    expect(s.phase, ActionPhase.correctComplete);
  });
  test('a finger in the correct zone cannot substitute for feet', () {
    drop(
      const Offset(380, 250),
    ); // Feet outside bounds, finger in correct zone.
    expect(s.phase, ActionPhase.initial);
    expect(s.wrongAttempts, 0);
  });
  test('26 canvas px threshold; wrong retains the exact actual delta', () {
    drop(const Offset(25.99, 0));
    expect(s.phase, ActionPhase.initial);
    expect(s.wrongAttempts, 0);
    drop(const Offset(26, 0));
    expect(s.phase, ActionPhase.wrongJustJudged);
    expect(s.delta, const Offset(26, 0));
    s.settle();
    s.retry();
    expect(s.delta, Offset.zero);
    expect(s.wrongAttempts, 1);
  });
  test('gap, outside scene/bounds and cancellation are free', () {
    for (final delta in [
      const Offset(240, 0),
      const Offset(-360, 0),
      const Offset(0, 100),
      const Offset(900, 0),
      const Offset(0, -700),
    ]) {
      drop(delta);
      expect(s.phase, ActionPhase.initial);
      expect(s.wrongAttempts, 0);
      expect(s.delta, Offset.zero);
    }
    s.begin(1, const Offset(800, 650), true);
    s.move(2, const Offset(1200, 650));
    expect(s.delta, Offset.zero);
    s.move(1, const Offset(1200, 650));
    s.cancel(1);
    expect(s.wrongAttempts, 0);
    expect(s.canDrag, isTrue);
  });
  test(
    'four failures stay wrong until explicit reveal; reveal is not success',
    () {
      s.showHint();
      s.showHint();
      s.showHint();
      expect(s.hint, 2);
      for (var i = 0; i < 4; i++) {
        drop(const Offset(60, 0));
        s.settle();
        s.retry();
        expect(s.wrongAttempts, i + 1);
      }
      expect(s.phase, ActionPhase.finalFailure);
      expect(s.revealed, isFalse);
      expect(s.success, isFalse);
      s.reveal();
      expect(s.revealed, isTrue);
      expect(s.success, isFalse);
      s.resetAttempt();
      expect(s.phase, ActionPhase.initial);
      expect(s.wrongAttempts, 0);
      expect(s.hint, 0);
      expect(s.revealed, isFalse);
    },
  );
  test(
    'alpha 60 mask accepts black opaque pixels and rejects transparent white',
    () {
      final mask = DragStartMask(
        rgba: Uint8List.fromList([255, 255, 255, 0, 0, 0, 0, 59, 0, 0, 0, 60]),
        width: 3,
        height: 1,
        bounds: const Rect.fromLTWH(0, 0, 3, 1),
        channel: 3,
        threshold: 60,
      );
      expect(mask.hit(const Offset(0, 0), 0), isFalse);
      expect(mask.hit(const Offset(1, 0), 0), isFalse);
      expect(mask.hit(const Offset(2, 0), 0), isTrue);
    },
  );
}

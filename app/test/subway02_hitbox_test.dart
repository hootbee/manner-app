import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:mannerfit/screens/action_drag_state.dart';
import 'package:mannerfit/screens/lesson_explanation_content.dart';

void main() {
  late ActionDragState s;
  setUp(
    () => s = ActionDragState(
      jsonDecode(File('assets/subway02/asset_rules.json').readAsStringSync()),
    ),
  );
  tearDown(() => s.dispose());
  void drop(Offset foot) {
    const touch = Offset(830, 700);
    expect(s.begin(1, touch, true), isTrue);
    s.release(1, touch + foot - s.anchor);
  }

  test('latest configuration uses full canvas and both correct rectangles', () {
    expect(s.rules['judgement']['drag_bounds_px'], [0, 0, 1536, 1024]);
    expect(
      [for (final z in s.rules['judgement']['correct_zones']) z['rect_px']],
      [
        [0, 810, 430, 960],
        [1105, 810, 1355, 960],
      ],
    );
    expect(s.rules['judgement']['wrong_zones'][0]['rect_px'], [
      500,
      810,
      1035,
      963,
    ]);
  });
  for (final point in [
    const Offset(200, 900),
    const Offset(30, 900),
    const Offset(0, 810),
    const Offset(0, 960),
    const Offset(430, 810),
    const Offset(430, 960),
    const Offset(1200, 900),
    const Offset(1105, 810),
    const Offset(1105, 960),
    const Offset(1355, 810),
    const Offset(1355, 960),
  ]) {
    test('inclusive correct edge $point is judged before snap', () {
      drop(point);
      expect(s.success, isTrue);
      expect(s.wrongAttempts, 0);
    });
  }
  for (final point in [
    const Offset(750, 900),
    const Offset(500, 810),
    const Offset(1035, 810),
    const Offset(500, 963),
    const Offset(1035, 963),
  ]) {
    test('inclusive wrong edge $point', () {
      drop(point);
      expect(s.phase, ActionPhase.wrongJustJudged);
      expect(s.wrongAttempts, 1);
    });
  }
  for (final point in [
    const Offset(470, 900),
    const Offset(1070, 900),
    const Offset(430.01, 900),
    const Offset(1104.99, 900),
    const Offset(30, 809.99),
    const Offset(30, 960.01),
    const Offset(1200, 960.01),
    const Offset(750, 963.01),
  ]) {
    test('gap or outside zone $point resets without a failure', () {
      drop(point);
      expect(s.phase, ActionPhase.initial);
      expect(s.wrongAttempts, 0);
    });
  }
  test('movement reaches upper/left/right canvas; outside release is free', () {
    for (final p in [
      const Offset(20, 220),
      const Offset(1500, 300),
      const Offset(800, 220),
    ]) {
      s.begin(1, const Offset(830, 700), true);
      s.move(1, p);
      expect(s.delta, p - const Offset(830, 700));
      s.cancel(1);
      expect(s.wrongAttempts, 0);
    }
    for (final p in [
      const Offset(-1, 700),
      const Offset(1537, 700),
      const Offset(800, -1),
    ]) {
      s.begin(1, const Offset(830, 700), true);
      s.release(1, p);
      expect(s.phase, ActionPhase.initial);
      expect(s.wrongAttempts, 0);
    }
  });
  test('user-requested cross-question sentence is absent from explanation', () {
    final body = lessonExplanations['subway_02_basic']!.reasons.first.body;
    expect(body, isNot(contains('01번 백팩')));
    expect(body, endsWith('도시철도 이용 예절이기도 합니다.'));
  });
}

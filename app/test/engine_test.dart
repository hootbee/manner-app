// ADR 0001 §4: XP, 레벨, 연속 학습일은 기록 집합만으로 계산한다.
import 'package:flutter_test/flutter_test.dart';
import 'package:mannerfit/engine/engine.dart';

DateTime d(int month, int day) => DateTime.utc(2026, month, day);

Attempt a(Grade grade, [String id = '']) =>
    Attempt(id: id, scenarioId: 'A-sidewalk~partner.right', grade: grade, solvedOn: d(10, 25));

DayCompletion c(DateTime on, [String id = '']) =>
    DayCompletion(id: id, dayId: 'day-01', completedOn: on);

void main() {
  group('xp', () {
    test('빈 집합은 0', () => expect(xp([]), 0));
    test('best, ok, avoid 세 기록은 15', () {
      expect(xp([a(Grade.best), a(Grade.ok), a(Grade.avoid)]), 15);
    });
    test('순서를 섞어도 같다', () {
      expect(xp([a(Grade.avoid), a(Grade.best), a(Grade.ok), a(Grade.best)]), 25);
    });
  });

  group('level', () {
    test('0 XP는 레벨 1, 진행 0', () {
      expect(level(0), 1);
      expect(levelProgress(0), 0.0);
    });
    test('99 XP는 레벨 1, 진행 0.99', () {
      expect(level(99), 1);
      expect(levelProgress(99), 0.99);
    });
    test('100 XP는 레벨 2, 진행 0', () {
      expect(level(100), 2);
      expect(levelProgress(100), 0.0);
    });
    test('199 XP는 레벨 2, 진행 0.99', () {
      expect(level(199), 2);
      expect(levelProgress(199), 0.99);
    });
  });

  group('streak', () {
    final today = d(10, 25);

    test('빈 집합은 0', () => expect(streak([], today), 0));
    test('오늘만 했으면 1', () => expect(streak([c(today)], today), 1));
    test('오늘에서 끝나는 연속 일수', () {
      expect(streak([c(d(10, 23)), c(d(10, 24)), c(today)], today), 3);
    });
    test('같은 날 완료 여러 개는 하루로 센다', () {
      expect(streak([c(today, 'x'), c(today, 'y'), c(d(10, 24))], today), 2);
    });
    test('오늘 안 했지만 어제까지 이어졌으면 어제에서 끝나는 일수', () {
      expect(streak([c(d(10, 22)), c(d(10, 23)), c(d(10, 24))], today), 3);
    });
    test('마지막 완료가 이틀 전이면 0', () {
      expect(streak([c(d(10, 22)), c(d(10, 23))], today), 0);
    });
    test('중간에 빈 날이 있으면 그 뒤만 센다', () {
      expect(streak([c(d(10, 20)), c(d(10, 21)), c(d(10, 23)), c(d(10, 24)), c(today)], today), 3);
    });
    test('달이 바뀌어도 이어진다', () {
      expect(streak([c(d(9, 30)), c(d(10, 1))], d(10, 1)), 2);
    });
    test('시각과 시간대는 무시하고 연월일만 쓴다', () {
      final completions = [c(DateTime(2026, 10, 24, 0, 30)), c(DateTime.utc(2026, 10, 25))];
      expect(streak(completions, DateTime(2026, 10, 25, 23, 59)), 2);
    });
    test('입력 순서를 섞어도 같다', () {
      final sorted = [c(d(10, 21)), c(d(10, 22)), c(d(10, 23)), c(d(10, 24)), c(today)];
      final shuffled = [sorted[3], sorted[0], sorted[4], sorted[2], sorted[1], sorted[4]];
      expect(streak(shuffled, today), streak(sorted, today));
      expect(streak(shuffled, today), 5);
    });
  });
}

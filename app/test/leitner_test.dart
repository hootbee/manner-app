// ADR 0004 §2·§5: Leitner 칸과 복습 대상은 기록 집합 + 콘텐츠 + 오늘 날짜로 계산한다.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mannerfit/content/content.dart';
import 'package:mannerfit/engine/engine.dart';
import 'package:mannerfit/engine/leitner.dart';

DateTime d(int month, int day) => DateTime.utc(2026, month, day);

Attempt a(DateTime on, Grade grade, [String scenarioId = 'A-sidewalk~partner.right']) =>
    Attempt(id: '', scenarioId: scenarioId, grade: grade, solvedOn: on);

void main() {
  final content = parseContent(File('assets/content.json').readAsStringSync());
  final retired = Content(content.schema, content.version, content.principles,
      [for (final m in content.manners) m['id'] == 1 ? {...m, 'retired': true} : m],
      content.scenarios, content.days);

  group('boxes', () {
    test('10-25 best 하나면 Box(2, 10-28)', () {
      expect(boxes(content, [a(d(10, 25), Grade.best)]), {1: Box(2, d(10, 28))});
    });
    test('같은 날 best와 avoid면 순서와 상관없이 Box(1, 10-26)', () {
      final best = a(d(10, 25), Grade.best), avoid = a(d(10, 25), Grade.avoid);
      expect(boxes(content, [best, avoid]), {1: Box(1, d(10, 26))});
      expect(boxes(content, [avoid, best]), {1: Box(1, d(10, 26))});
    });
    test('10-25 best, 10-26 best면 Box(3, 11-02), 10-27 best를 더하면 Box(3, 11-03)', () {
      final two = [a(d(10, 25), Grade.best), a(d(10, 26), Grade.best)];
      expect(boxes(content, two), {1: Box(3, d(11, 2))});
      expect(boxes(content, [...two, a(d(10, 27), Grade.best)]), {1: Box(3, d(11, 3))});
    });
    test('입력 순서가 날짜 역순이어도 같다', () {
      final three = [a(d(10, 27), Grade.best), a(d(10, 26), Grade.best), a(d(10, 25), Grade.best)];
      expect(boxes(content, three), {1: Box(3, d(11, 3))});
    });
    test('3칸에서 틀리면 1칸으로 간다', () {
      final attempts = [a(d(10, 25), Grade.best), a(d(10, 26), Grade.best), a(d(10, 27), Grade.avoid)];
      expect(boxes(content, attempts), {1: Box(1, d(10, 28))});
    });
    test('ok는 best가 아니므로 1칸', () {
      expect(boxes(content, [a(d(10, 25), Grade.ok)]), {1: Box(1, d(10, 26))});
    });
    test('같은 기록이 두 번 있어도 한 번과 같다', () {
      final best = a(d(10, 25), Grade.best);
      expect(boxes(content, [best, best]), {1: Box(2, d(10, 28))});
    });
    test('매너마다 따로 계산한다', () {
      final attempts = [a(d(10, 25), Grade.best), a(d(10, 25), Grade.avoid, 'A-umbrella-01')];
      expect(boxes(content, attempts), {1: Box(2, d(10, 28)), 2: Box(1, d(10, 26))});
    });
    test('은퇴한 매너도 칸은 계산한다', () {
      expect(boxes(retired, [a(d(10, 25), Grade.best)]), {1: Box(2, d(10, 28))});
    });
    test('시각과 시간대는 무시하고 연월일만 쓴다', () {
      final attempts = [a(DateTime(2026, 10, 25, 0, 30), Grade.avoid), a(d(10, 25), Grade.best)];
      expect(boxes(content, attempts), {1: Box(1, d(10, 26))});
    });
    test('콘텐츠에 없는 기록만 있으면 빈 맵', () {
      expect(boxes(content, [a(d(10, 25), Grade.best, 'Z-unknown~a')]), isEmpty);
    });
    test('펼친 문제가 없어도 기본 시나리오가 있으면 그 매너로 센다', () {
      expect(boxes(content, [a(d(10, 25), Grade.best, 'A-sidewalk~new.right')]), {1: Box(2, d(10, 28))});
    });
  });

  group('reviewsDue', () {
    final b = {1: Box(2, d(10, 28))};

    test('복습일이 오늘이면 1', () => expect(reviewsDue(content, b, d(10, 28)), 1));
    test('복습일이 내일이면 0', () => expect(reviewsDue(content, b, d(10, 27)), 0));
    test('복습일이 지났어도(밀림) 1', () => expect(reviewsDue(content, b, d(11, 30)), 1));
    test('오늘의 시각은 무시한다', () {
      expect(reviewsDue(content, b, DateTime(2026, 10, 28, 0, 30)), 1);
    });
    test('은퇴한 매너는 복습일이 지나도 0', () => expect(reviewsDue(retired, b, d(11, 30)), 0));
  });

  group('dueManners', () {
    test('복습일이 오래된 순, 같으면 매너 id 순', () {
      final b = {3: Box(1, d(10, 25)), 2: Box(1, d(10, 20)), 1: Box(1, d(10, 25))};
      expect(dueManners(content, b, d(10, 27)), [2, 1, 3]);
    });
  });
}

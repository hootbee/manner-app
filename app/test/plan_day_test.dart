// ADR 0004 §4 세트 구성(planDay): 문제 고르기와 복습 섞기. 무작위는 정확한 순서 대신 성질만 확인한다.
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:mannerfit/content/content.dart';
import 'package:mannerfit/engine/daily.dart';
import 'package:mannerfit/engine/engine.dart';
import 'package:mannerfit/engine/leitner.dart';

DateTime d(int month, int day) => DateTime.utc(2026, month, day);

Json scenario(int manner, List<String> keys) => {
  'id': 'M$manner',
  'manner': manner,
  'vary': [
    [
      for (final k in keys) {'key': k},
    ],
  ],
};

// 매너 1은 문제 3개(M1~a·b·c), 2~8은 2개씩(Mn~a·b). 매너 8은 은퇴. 하루의 장면 매너는 1·3·2.
final content = Content(
  1,
  1,
  [],
  [
    for (var m = 1; m <= 8; m++) {'id': m, 'name': '매너 $m', if (m == 8) 'retired': true},
  ],
  [
    scenario(1, ['a', 'b', 'c']),
    for (var m = 2; m <= 8; m++) scenario(m, ['a', 'b']),
  ],
  [],
);
final Json day1 = {
  'id': 'day-01',
  'scenes': [
    {'manner': 1},
    {'manner': 3},
    {'manner': 2},
  ],
};

Attempt a(String scenarioId, DateTime on) => Attempt(id: '', scenarioId: scenarioId, grade: Grade.best, solvedOn: on);

/// 문제 id의 매너.
int manner(String id) => content.questions[id]!['manner'] as int;

void main() {
  final today = d(10, 27);

  group('문제 고르기', () {
    test('매너 1 문제 중 하나만 안 풀었으면 첫 장면에 그 문제가 들어간다', () {
      final attempts = [a('M1~a', d(10, 20)), a('M1~b', d(10, 21))];
      for (var seed = 0; seed < 20; seed++) {
        expect(planDay(content, day1, attempts, {}, today, Random(seed))[0], contains('M1~c'));
      }
    });
    test('모두 풀었으면 가장 오래전에 푼 두 문제가 나온다', () {
      final attempts = [a('M1~c', d(10, 25)), a('M1~b', d(10, 20)), a('M1~a', d(10, 22))];
      for (var seed = 0; seed < 20; seed++) {
        expect(planDay(content, day1, attempts, {}, today, Random(seed))[0], ['M1~b', 'M1~a']);
      }
    });
    test('같은 문제를 여러 번 풀었으면 마지막으로 푼 날로 센다', () {
      final attempts = [a('M1~a', d(10, 1)), a('M1~a', d(10, 26)), a('M1~b', d(10, 20)), a('M1~c', d(10, 22))];
      expect(planDay(content, day1, attempts, {}, today, Random(0))[0], ['M1~b', 'M1~c']);
    });
    test('같은 날 다른 시각에 푼 두 문제는 같은 날로 쳐서 무작위로 먼저 나온다', () {
      final attempts = [a('M1~a', DateTime(2026, 10, 20, 9)), a('M1~b', DateTime(2026, 10, 20, 21)), a('M1~c', d(10, 25))];
      final firsts = {for (var seed = 0; seed < 20; seed++) planDay(content, day1, attempts, {}, today, Random(seed))[0][0]};
      expect(firsts, {'M1~a', 'M1~b'});
    });
    test('seed 0~19에서 3장면 2문제씩, 한 세트에 같은 id가 두 번 나오지 않는다', () {
      for (var seed = 0; seed < 20; seed++) {
        final plan = planDay(content, day1, [], {}, today, Random(seed));
        expect(plan.map((s) => s.length), [2, 2, 2]);
        expect(plan.expand((s) => s).toSet(), hasLength(6));
      }
    });
    test('같으면 무작위: seed에 따라 다른 문제가 나온다', () {
      final firsts = {for (var seed = 0; seed < 20; seed++) planDay(content, day1, [], {}, today, Random(seed))[0][0]};
      expect(firsts, hasLength(greaterThan(1)));
    });
  });

  group('복습 섞기', () {
    List<List<int>> manners(Map<int, Box> boxes) => [
      for (final s in planDay(content, day1, [], boxes, today, Random(0))) [for (final id in s) manner(id)],
    ];

    test('장면 매너 1·3·2, 매너 4가 복습 대상이면 첫 장면만 [매너 1, 매너 4]', () {
      expect(manners({4: Box(2, today)}), [
        [1, 4],
        [3, 3],
        [2, 2],
      ]);
    });
    test('복습 대상이 4개면 복습일이 오래된 3개만, 같으면 매너 id 순', () {
      final boxes = {6: Box(1, d(10, 25)), 5: Box(1, d(10, 21)), 4: Box(1, d(10, 21)), 7: Box(1, d(10, 20))};
      expect(manners(boxes), [
        [1, 7],
        [3, 4],
        [2, 5],
      ]);
    });
    test('복습 대상이 장면 매너뿐이면 모든 장면이 장면 매너 2문제', () {
      expect(manners({1: Box(1, d(10, 20)), 2: Box(1, today)}), [
        [1, 1],
        [3, 3],
        [2, 2],
      ]);
    });
    test('복습일이 내일인 매너와 은퇴한 매너는 넣지 않는다', () {
      expect(manners({4: Box(1, d(10, 28)), 8: Box(1, d(10, 1))}), [
        [1, 1],
        [3, 3],
        [2, 2],
      ]);
    });
  });
}

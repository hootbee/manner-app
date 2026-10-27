// 영역 스탯 (ADR 0004 §3·§5).
import 'dart:math';

import '../content/content.dart';
import 'engine.dart';
import 'leitner.dart';

const areas = ['연애', '친구', '어른·가족', '직장', '공공장소', '메시지'];

/// areas 순서 그대로 6개. 영역마다 min(100, 그 영역 문제로 푼 매너들의 칸 합 × 5).
/// 밀린 매너(복습일 < 오늘)는 한 칸 낮게, 은퇴한 매너와 펼친 문제를 못 찾은 기록은 뺀다.
List<(String area, int value)> areaStats(Content c, Iterable<Attempt> attempts, Map<int, Box> boxes, DateTime today) {
  final solved = {
    for (final a in attempts)
      if (c.lookup(a.scenarioId) case (:final manner, question: final q?) when manner['retired'] != true)
        (q['area'], manner['id']),
  };
  int sum(String area) => boxes.entries
      .where((e) => solved.contains((area, e.key)))
      .fold(0, (s, e) => s + e.value.n - (e.value.due.isBefore(day(today)) ? 1 : 0));
  return [for (final area in areas) (area, min(100, sum(area) * 5))];
}

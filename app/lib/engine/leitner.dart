// Leitner 복습 칸 (ADR 0004 §2·§5).
import '../content/content.dart';
import 'engine.dart';

const intervals = {1: 1, 2: 3, 3: 7}; // 칸 → 다음 복습까지 일수

class Box {
  const Box(this.n, this.due);
  final int n; // 칸 1~3
  final DateTime due; // 다음 복습일

  @override
  bool operator ==(Object other) => other is Box && other.n == n && other.due == due;
  @override
  int get hashCode => Object.hash(n, due);
  @override
  String toString() => 'Box($n, $due)';
}

/// 매너 id → 칸. 날짜 순으로, 그날 그 매너의 기록이 모두 best면 한 칸 오르고(최대 3) 아니면 1칸.
/// 매너를 찾지 못한 기록은 뺀다(5절).
Map<int, Box> boxes(Content c, Iterable<Attempt> attempts) {
  final allBest = <int, Map<DateTime, bool>>{}; // 매너 → 날짜 → 그날 모두 best인가
  for (final a in attempts) {
    final m = c.lookup(a.scenarioId)?.manner['id'] as int?;
    if (m == null) continue;
    final days = allBest.putIfAbsent(m, () => {});
    days[day(a.solvedOn)] = (days[day(a.solvedOn)] ?? true) && a.grade == Grade.best;
  }
  return allBest.map((m, days) {
    final sorted = days.keys.toList()..sort();
    var n = 1;
    for (final t in sorted) {
      n = days[t]! ? (n + 1).clamp(1, 3) : 1;
    }
    final last = sorted.last;
    return MapEntry(m, Box(n, DateTime.utc(last.year, last.month, last.day + intervals[n]!)));
  });
}

/// 복습 대상(은퇴하지 않았고 due <= today)인 매너 id. 복습일이 오래된 순, 같으면 매너 id 순.
List<int> dueManners(Content c, Map<int, Box> boxes, DateTime today) => [
      for (final e in boxes.entries)
        if (!e.value.due.isAfter(day(today)) && c.manners.any((m) => m['id'] == e.key && m['retired'] != true))
          e.key,
    ]..sort((x, y) {
        final by = boxes[x]!.due.compareTo(boxes[y]!.due);
        return by != 0 ? by : x.compareTo(y);
      });

/// 복습 대상인 매너 수.
int reviewsDue(Content c, Map<int, Box> boxes, DateTime today) => dueManners(c, boxes, today).length;

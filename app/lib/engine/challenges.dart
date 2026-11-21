// 도전과제 (ADR 0010). 미션 = 지표 하나 × 기간 하나 × 목표 수. 아무것도 저장하지 않는다.
import '../content/content.dart';
import 'engine.dart';

/// value는 min(지표, goal). category는 categoryMaster만(카테고리 id).
typedef Row = ({String id, String? category, int value, int goal});

/// 주는 월요일에 시작한다. DateTime.weekday는 월요일 1 ~ 일요일 7.
DateTime weekStart(DateTime t) {
  final d = day(t);
  return DateTime.utc(d.year, d.month, d.day - (d.weekday - 1));
}

/// 기간 안 기록에서 센 지표 (ADR 0010 §4).
class _Counts {
  int solves = 0, positionBest = 0, orderBest = 0, reviews = 0;
  final days = <DateTime>{}, manners = <Object?>{}, cats = <String>{};
  final catBest = {for (final c in categories) c: 0};
}

/// 목록은 ADR 0010 §5 표 순서. 목표 수는 아래 반환 목록에만 있다.
({List<Row> daily, List<Row> weekly, List<Row> achievements, int todayXp, int weekXp}) challenges(
    Content c, Iterable<Attempt> attempts, Iterable<DayCompletion> done, DateTime today) {
  final t = day(today), w = weekStart(today);
  final periods = [(DateTime x) => x == t, (DateTime x) => weekStart(x) == w, (DateTime _) => true];
  final counts = [for (final _ in periods) _Counts()];

  // 다시 푼 매너: (매너, 날짜) 쌍 중 그 매너를 더 앞선 날짜에도 푼 것. 앞선 날짜는 기간 밖이어도 된다.
  final first = <Object?, DateTime>{};
  final pairs = <(Object?, DateTime)>{};
  for (final a in attempts) {
    final m = c.lookup(a.scenarioId)?.manner['id'];
    if (m == null) continue;
    final on = day(a.solvedOn);
    pairs.add((m, on));
    if (first[m]?.isAfter(on) != false) first[m] = on;
  }
  for (final (m, on) in pairs) {
    if (!on.isAfter(first[m]!)) continue;
    for (final (i, inPeriod) in periods.indexed) {
      if (inPeriod(on)) counts[i].reviews++;
    }
  }

  for (final a in attempts) {
    final r = c.lookup(a.scenarioId);
    final q = r?.question;
    final cat = (q?['tags'] as List?)?.whereType<String>().where(categories.contains).firstOrNull;
    final best = a.grade == Grade.best;
    for (final (i, inPeriod) in periods.indexed) {
      if (!inPeriod(day(a.solvedOn))) continue;
      final n = counts[i];
      n.solves++;
      if (r != null) n.manners.add(r.manner['id']);
      if (cat != null) n.cats.add(cat);
      if (!best || q == null) continue;
      if (q['format'] == 'position') n.positionBest++;
      if (q['format'] == 'order') n.orderBest++;
      if (cat != null) n.catBest[cat] = n.catBest[cat]! + 1;
    }
  }
  for (final x in done) {
    final on = day(x.completedOn);
    for (final (i, inPeriod) in periods.indexed) {
      if (inPeriod(on)) counts[i].days.add(on);
    }
  }

  Row row(String id, int v, int goal, [String? category]) =>
      (id: id, category: category, value: v < goal ? v : goal, goal: goal);
  final [today_, week, all] = counts;
  final masters = [for (final cat in categories) row('categoryMaster', all.catBest[cat]!, 30, cat)];
  return (
    daily: [
      row('todayStart', today_.solves, 1),
      row('todayHalf', today_.solves, 3),
      row('todayDone', today_.days.length, 1),
    ],
    weekly: [
      row('weekDays', week.days.length, 5),
      row('weekManners', week.manners.length, 10),
      row('weekCategories', week.cats.length, 3),
      row('weekReviews', week.reviews, 5),
    ],
    achievements: [
      row('firstStep', all.solves, 1),
      row('collector', all.manners.length, 30),
      row('steady', all.days.length, 30),
      row('explorer', all.cats.length, 6),
      row('positionBest', all.positionBest, 50),
      row('orderBest', all.orderBest, 20),
      row('reviews', all.reviews, 50),
      ...masters,
      row('allCategories', masters.where((m) => m.value == m.goal).length, categories.length),
    ],
    todayXp: xp(attempts.where((a) => day(a.solvedOn) == t)),
    weekXp: xp(attempts.where((a) => weekStart(a.solvedOn) == w)),
  );
}

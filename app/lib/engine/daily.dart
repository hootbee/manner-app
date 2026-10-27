// 데일리 진행 위치, 세트 구성, 내일 다시 볼 매너 (ADR 0004 §4, §5). 날짜는 연월일만 쓴다.
import 'dart:math';

import '../content/content.dart';
import 'engine.dart';
import 'leitner.dart';

const perScene = 2;

/// 오늘 홈에 보여 줄 하루. 경로는 은퇴하지 않은 days(배열 순서), next는 완료 기록이 없는 첫 하루,
/// 보여 줄 하루는 오늘 마친 하루 중 경로에서 마지막이고 없으면 next. 둘 다 없으면 null.
/// doneToday는 오늘 완료 기록이 하나라도 있으면 참이다(모르는 day_id 포함).
({Json day, int number, bool doneToday, Json? next})? dailyPosition(
    Content c, Iterable<DayCompletion> done, DateTime today) {
  bool isToday(DateTime t) => t.year == today.year && t.month == today.month && t.day == today.day;
  final path = [for (final d in c.days) if (d['retired'] != true) d];
  final doneIds = {for (final x in done) x.dayId};
  final todayIds = {for (final x in done) if (isToday(x.completedOn)) x.dayId};
  final next = path.where((d) => !doneIds.contains(d['id'])).firstOrNull;
  final day = path.where((d) => todayIds.contains(d['id'])).lastOrNull ?? next;
  if (day == null) return null;
  return (day: day, number: path.indexOf(day) + 1, doneToday: todayIds.isNotEmpty, next: next);
}

/// 하루 d의 장면마다 문제 id perScene개. 장면 매너 문제가 먼저이고, 복습 대상(은퇴하지 않았고 due <= today) 중
/// 장면 매너가 아닌 것을 복습일·매너 id 순으로 최대 3개 장면 1·2·3의 둘째 자리에 넣는다.
/// 문제는 그 매너의 출제 가능한 문제 중 마지막으로 푼 날이 가장 오래된 것(안 푼 것이 가장 오래됨, 같으면 rng),
/// 이 세트에서 이미 고른 것은 뺀다.
List<List<String>> planDay(
    Content c, Json d, Iterable<Attempt> attempts, Map<int, Box> boxes, DateTime today, Random rng) {
  final scenes = [for (final s in (d['scenes'] as List).cast<Json>()) s['manner'] as int];
  final reviews = dueManners(c, boxes, today).where((m) => !scenes.contains(m)).toList();
  final last = <String, DateTime>{}; // 문제 id → 마지막으로 푼 날
  for (final a in attempts) {
    final t = day(a.solvedOn);
    if (last[a.scenarioId]?.isAfter(t) != true) last[a.scenarioId] = t;
  }
  final never = DateTime.utc(0);
  final picked = <String>{};
  String pick(int manner) {
    final ids = [
      for (final q in c.selectable)
        if (q['manner'] == manner && !picked.contains(q['id'])) q['id'] as String,
    ];
    final oldest = ids.map((id) => last[id] ?? never).reduce((x, y) => x.isBefore(y) ? x : y);
    final ties = ids.where((id) => (last[id] ?? never) == oldest).toList();
    final id = ties[rng.nextInt(ties.length)];
    picked.add(id);
    return id;
  }

  return [
    for (final (i, m) in scenes.indexed)
      List.generate(perScene, (k) => pick(k == 1 && i < reviews.length ? reviews[i] : m)),
  ];
}

/// 이 세트에서 best가 아닌 기록이 있는 매너 이름(처음 나온 순서). 매너를 찾지 못한 기록은 뺀다.
List<String> retryTomorrow(Content c, Iterable<Attempt> session) => {
      for (final a in session)
        if (a.grade != Grade.best)
          if (c.lookup(a.scenarioId) case final r?) r.manner['name'] as String,
    }.toList();

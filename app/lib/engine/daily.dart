// 데일리 진행 위치와 내일 다시 볼 매너 (ADR 0004 §4, §5). 날짜는 연월일만 쓴다.
import '../content/content.dart';
import 'engine.dart';

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

/// 이 세트에서 best가 아닌 기록이 있는 매너 이름(처음 나온 순서). 매너를 찾지 못한 기록은 뺀다.
List<String> retryTomorrow(Content c, Iterable<Attempt> session) => {
      for (final a in session)
        if (a.grade != Grade.best)
          if (c.lookup(a.scenarioId) case final r?) r.manner['name'] as String,
    }.toList();

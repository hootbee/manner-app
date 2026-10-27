// 학습 엔진. 기록 집합만 받아 값을 돌려준다(ADR 0001 §4). 날짜는 기기 날짜의 연월일만 쓴다. 시각과 시간대는 무시한다.

/// 3단계 채점 결과. 값 이름은 `attempts.grade`, `content.json`의 문자열과 같다.
enum Grade {
  best(10),
  ok(5),
  avoid(0);

  const Grade(this.xp);
  final int xp;
}

/// 풀이 기록 (`attempts`, ADR 0001 §1).
class Attempt {
  const Attempt({required this.id, required this.scenarioId, required this.grade, required this.solvedOn});
  final String id;
  final String scenarioId;
  final Grade grade;
  final DateTime solvedOn;
}

/// 데일리 완료 기록 (`day_completions`, ADR 0001 §1).
class DayCompletion {
  const DayCompletion({required this.id, required this.dayId, required this.completedOn});
  final String id;
  final String dayId;
  final DateTime completedOn;
}

int xp(Iterable<Attempt> attempts) => attempts.fold(0, (sum, a) => sum + a.grade.xp);

int level(int xp) => xp ~/ 100 + 1;

double levelProgress(int xp) => (xp % 100) / 100;

/// T가 완료 날짜에 있으면 T에서, 아니고 T-1이 있으면 T-1에서 끝나는 연속 일수. 둘 다 아니면 0.
int streak(Iterable<DayCompletion> completions, DateTime today) {
  DateTime day(DateTime t) => DateTime.utc(t.year, t.month, t.day);
  final days = {for (final c in completions) day(c.completedOn)};
  var t = day(today);
  if (!days.contains(t)) t = DateTime.utc(t.year, t.month, t.day - 1);
  var n = 0;
  while (days.contains(t)) {
    n++;
    t = DateTime.utc(t.year, t.month, t.day - 1);
  }
  return n;
}

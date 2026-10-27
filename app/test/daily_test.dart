// ADR 0004 §4: 데일리 진행 위치와 내일 다시 볼 매너.
import 'package:flutter_test/flutter_test.dart';
import 'package:mannerfit/content/content.dart';
import 'package:mannerfit/engine/daily.dart';
import 'package:mannerfit/engine/engine.dart';

DateTime d(int month, int day) => DateTime.utc(2026, month, day);

// 경로는 day-01, day-02. 사이의 day-old는 은퇴해서 빠진다.
final content = Content(1, 1, [], [
  {'id': 1, 'name': '동행자를 인도 안쪽으로'},
  {'id': 3, 'name': '계단에서는 상대보다 아래 칸'},
], [
  {'id': 'A-sidewalk', 'manner': 1},
  {'id': 'A-stairs', 'manner': 3},
], [
  {'id': 'day-01', 'title': '평범한 화요일'},
  {'id': 'day-old', 'title': '은퇴한 하루', 'retired': true},
  {'id': 'day-02', 'title': '수요일'},
]);

DayCompletion c(String dayId, DateTime on) => DayCompletion(id: '', dayId: dayId, completedOn: on);

Attempt a(String scenarioId, Grade grade) =>
    Attempt(id: '', scenarioId: scenarioId, grade: grade, solvedOn: d(10, 27));

void main() {
  final today = d(10, 27);

  group('dailyPosition', () {
    test('기록 없음 → day-01, number 1, doneToday 거짓', () {
      final p = dailyPosition(content, [], today)!;
      expect(p.day['id'], 'day-01');
      expect(p.number, 1);
      expect(p.doneToday, false);
    });
    test('어제 day-01 완료 → day-02, 은퇴한 하루는 경로에서 빠져 number 2', () {
      final p = dailyPosition(content, [c('day-01', d(10, 26))], today)!;
      expect(p.day['id'], 'day-02');
      expect(p.number, 2);
      expect(p.doneToday, false);
    });
    test('오늘 day-01 완료 → day-01, doneToday 참, next는 day-02', () {
      final p = dailyPosition(content, [c('day-01', today)], today)!;
      expect(p.day['id'], 'day-01');
      expect(p.doneToday, true);
      expect(p.next?['id'], 'day-02');
    });
    test('오늘 모르는 day-99 완료 → doneToday 참, 하루는 day-01', () {
      final p = dailyPosition(content, [c('day-99', today)], today)!;
      expect(p.day['id'], 'day-01');
      expect(p.doneToday, true);
    });
    test('모두 완료 → null', () {
      expect(dailyPosition(content, [c('day-01', d(10, 25)), c('day-02', d(10, 26))], today), null);
    });
    test('시각과 시간대는 무시하고 연월일만 쓴다', () {
      final p = dailyPosition(content, [c('day-01', DateTime(2026, 10, 27, 0, 30))], DateTime(2026, 10, 27, 23, 59))!;
      expect(p.doneToday, true);
    });
    test('어제 23:00 완료는 오늘 00:30에 doneToday 거짓', () {
      final p = dailyPosition(content, [c('day-01', DateTime(2026, 10, 26, 23))], DateTime(2026, 10, 27, 0, 30))!;
      expect(p.doneToday, false);
    });
    test('한 달 전 같은 일(9-27) 완료는 오늘 10-27에 doneToday 거짓', () {
      expect(dailyPosition(content, [c('day-01', d(9, 27))], today)!.doneToday, false);
    });
    test('마지막 하루를 오늘 마침 → day-02, number 2, doneToday 참, next null', () {
      final p = dailyPosition(content, [c('day-01', d(10, 26)), c('day-02', today)], today)!;
      expect(p.day['id'], 'day-02');
      expect(p.number, 2);
      expect(p.doneToday, true);
      expect(p.next, null);
    });
    test('오늘 마친 하루가 둘이면 입력 순서와 상관없이 경로에서 마지막', () {
      final p = dailyPosition(content, [c('day-02', today), c('day-01', today)], today)!;
      expect(p.day['id'], 'day-02');
    });
  });

  group('retryTomorrow', () {
    test('[매너 1 avoid, 매너 1 best, 매너 3 best] → 매너 1 이름', () {
      final session = [a('A-sidewalk', Grade.avoid), a('A-sidewalk', Grade.best), a('A-stairs', Grade.best)];
      expect(retryTomorrow(content, session), ['동행자를 인도 안쪽으로']);
    });
    test('처음 나온 순서, 중복 없음', () {
      // 이름순(계단 < 동행자)과 반대가 되도록 매너 1이 먼저 나온다.
      final session = [
        a('A-sidewalk', Grade.ok),
        a('A-stairs', Grade.avoid),
        a('A-sidewalk', Grade.avoid),
      ];
      expect(retryTomorrow(content, session), ['동행자를 인도 안쪽으로', '계단에서는 상대보다 아래 칸']);
    });
    test('콘텐츠에 없는 기록은 예외 없이 뺀다', () {
      final session = [a('Z-unknown~a', Grade.avoid), a('A-sidewalk', Grade.avoid)];
      expect(retryTomorrow(content, session), ['동행자를 인도 안쪽으로']);
    });
  });
}

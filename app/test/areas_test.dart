// ADR 0004 §3·§5: 영역 스탯 = min(100, 그 영역 문제로 푼 매너들의 칸 합 × 5). 밀리면 한 칸 낮게, 은퇴한 매너는 뺀다.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mannerfit/content/content.dart';
import 'package:mannerfit/engine/areas.dart';
import 'package:mannerfit/engine/engine.dart';
import 'package:mannerfit/engine/leitner.dart';

DateTime d(int month, int day) => DateTime.utc(2026, month, day);

Attempt a(DateTime on, Grade grade, [String scenarioId = 'A-sidewalk~partner.right']) =>
    Attempt(id: '', scenarioId: scenarioId, grade: grade, solvedOn: on);

int stat(List<(String, int)> stats, String area) => stats.firstWhere((s) => s.$1 == area).$2;

void main() {
  final content = parseContent(File('assets/content.json').readAsStringSync());
  final retired = Content(content.schema, content.version, content.principles,
      [for (final m in content.manners) m['id'] == 1 ? {...m, 'retired': true} : m],
      content.scenarios, content.days);

  List<(String, int)> stats(List<Attempt> attempts, DateTime today, [Content? c]) =>
      areaStats(c ?? content, attempts, boxes(c ?? content, attempts), today);

  final partnerBest = [a(d(10, 25), Grade.best)]; // 매너 1, 연애, Box(2, 10-28)

  test('기록이 없으면 6개 모두 0이고 순서가 areas와 같다', () {
    expect(stats([], d(10, 25)), [for (final area in areas) (area, 0)]);
    expect(areas, ['연애', '친구', '어른·가족', '직장', '공공장소', '메시지']);
  });
  test('10-25에 partner.right를 best로 풀면 오늘 10-25에 연애 10, 직장 0', () {
    final s = stats(partnerBest, d(10, 25));
    expect((stat(s, '연애'), stat(s, '직장')), (10, 0));
  });
  test('복습일 당일(10-28)은 밀린 것이 아니라 10', () {
    expect(stat(stats(partnerBest, d(10, 28)), '연애'), 10);
  });
  test('10-29에는 밀려서 연애 5', () {
    expect(stat(stats(partnerBest, d(10, 29)), '연애'), 5);
  });
  test('1칸 매너가 밀리면 0', () {
    expect(stat(stats([a(d(10, 25), Grade.avoid)], d(10, 27)), '연애'), 0);
  });
  test('ok와 avoid 기록도 푼 매너로 센다(1칸, 5)', () {
    expect(stat(stats([a(d(10, 25), Grade.ok)], d(10, 25)), '연애'), 5);
    expect(stat(stats([a(d(10, 25), Grade.avoid)], d(10, 25)), '연애'), 5);
  });
  test('한 매너를 두 영역 문제로 풀면 두 영역 모두에 들어간다', () {
    final s = stats([...partnerBest, a(d(10, 25), Grade.best, 'A-sidewalk~boss.right')], d(10, 25));
    expect((stat(s, '연애'), stat(s, '직장'), stat(s, '친구')), (10, 10, 0));
  });
  test('한 매너를 같은 영역 여러 문제로 풀어도 한 번만 더한다', () {
    final s = stats([
      ...partnerBest,
      a(d(10, 25), Grade.best, 'A-sidewalk~partner.left'),
      a(d(10, 25), Grade.best, 'A-alley~partner'),
    ], d(10, 25));
    expect(stat(s, '연애'), 10);
  });
  test('펼친 문제가 없으면 기본 시나리오에 area가 있어도 영역에 넣지 않는다', () {
    expect(stat(stats([a(d(10, 25), Grade.best, 'A-crosswalk-01~x')], d(10, 25)), '공공장소'), 0);
  });
  test('한 영역의 여러 매너는 칸을 더한다', () {
    final s = stats([...partnerBest, a(d(10, 25), Grade.ok, 'A-umbrella-01')], d(10, 25));
    expect(stat(s, '연애'), 15);
  });
  test('3칸 매너 7개가 한 영역에 있으면 100', () {
    final c = Content(1, 1, [], [for (var i = 1; i <= 7; i++) {'id': i}],
        [for (var i = 1; i <= 7; i++) {'id': 'F-$i', 'manner': i, 'area': '친구'}], []);
    final attempts = [for (var i = 1; i <= 7; i++) a(d(10, 25), Grade.best, 'F-$i')];
    final b = {for (var i = 1; i <= 7; i++) i: Box(3, d(11, 1))};
    expect(stat(areaStats(c, attempts, b, d(10, 25)), '친구'), 100);
  });
  test('은퇴한 매너는 넣지 않는다', () {
    expect(stat(stats(partnerBest, d(10, 25), retired), '연애'), 0);
  });
  test('펼친 문제를 찾지 못한 기록은 영역에 넣지 않는다', () {
    final s = stats([a(d(10, 25), Grade.best, 'A-sidewalk~new.right'), a(d(10, 25), Grade.best, 'Z-unknown~a')],
        d(10, 25));
    expect(s, [for (final area in areas) (area, 0)]);
  });
  test('오늘이 로컬 시각이어도 연월일만 쓴다(10-28 23:59는 밀리지 않음)', () {
    expect(stat(stats(partnerBest, DateTime(2026, 10, 28, 23, 59)), '연애'), 10);
  });
}

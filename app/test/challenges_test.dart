// ADR 0010: 도전과제(일일·주간·업적)를 기록에서 계산한다.
import 'package:flutter_test/flutter_test.dart';
import 'package:mannerfit/content/content.dart';
import 'package:mannerfit/engine/challenges.dart';
import 'package:mannerfit/engine/engine.dart';

DateTime d(int month, int day) => DateTime.utc(2026, month, day);

// 2026-11-18은 수요일이다.
final today = d(11, 18);

// A-sidewalk는 위치 형식·transport, A-order는 순서 형식·dining, A-plain은 카테고리 없음.
// A-old는 은퇴했다. cat-<카테고리>는 카테고리마다 하나씩이다.
final content = Content(1, 1, [], [
  {'id': 1},
  {'id': 2},
  for (var i = 0; i < categories.length; i++) {'id': 10 + i},
], [
  {
    'id': 'A-sidewalk',
    'manner': 1,
    'format': 'position',
    'tags': ['transport'],
    'vary': [
      [
        {'key': 'friend'},
      ],
      [
        {'key': 'left'},
      ],
    ],
  },
  {
    'id': 'A-order',
    'manner': 2,
    'format': 'order',
    'tags': ['dining'],
  },
  {'id': 'A-plain', 'manner': 1, 'format': 'ox'},
  {
    'id': 'A-old',
    'manner': 2,
    'format': 'ox',
    'tags': ['public'],
    'retired': true,
  },
  for (var i = 0; i < categories.length; i++)
    {
      'id': 'cat-${categories[i]}',
      'manner': 10 + i,
      'format': 'ox',
      'tags': [categories[i]],
    },
], []);

Attempt a(String scenarioId, DateTime on, [Grade grade = Grade.best]) =>
    Attempt(id: '', scenarioId: scenarioId, grade: grade, solvedOn: on);

DayCompletion c(DateTime on) => DayCompletion(id: '', dayId: 'day-01', completedOn: on);

typedef Result = ({List<Row> daily, List<Row> weekly, List<Row> achievements, int todayXp, int weekXp});

Result run(List<Attempt> attempts, [List<DayCompletion> done = const []]) =>
    challenges(content, attempts, done, today);

int value(List<Row> rows, String id, [String? category]) =>
    rows.singleWhere((r) => r.id == id && r.category == category).value;

void main() {
  group('weekStart (월요일 시작)', () {
    test('11-18(수) → 11-16', () => expect(weekStart(d(11, 18)), d(11, 16)));
    test('11-16(월) → 11-16', () => expect(weekStart(d(11, 16)), d(11, 16)));
    test('11-22(일) → 11-16', () => expect(weekStart(d(11, 22)), d(11, 16)));
    test('11-23(월) → 11-23', () => expect(weekStart(d(11, 23)), d(11, 23)));
    test('시각은 무시한다', () => expect(weekStart(DateTime(2026, 11, 22, 23, 59)), d(11, 16)));
  });

  group('기간별 지표', () {
    test('11-15(일) best, 11-16 ok, 11-18 best 둘 → 오늘 풀이 2, todayXp 20, weekXp 25', () {
      // 날짜마다 매너를 달리해 주간·전체 기록 필터를 매너 수로 본다(풀이 수 미션은 목표로 잘린다).
      final r = run([
        a('cat-transport', d(11, 15)),
        a('cat-public', d(11, 16), Grade.ok),
        a('A-plain', today),
        a('A-plain', today),
      ]);
      expect(value(r.daily, 'todayStart'), 1);
      expect(value(r.daily, 'todayHalf'), 2);
      expect(value(r.weekly, 'weekManners'), 2);
      expect(value(r.achievements, 'collector'), 3);
      expect(r.todayXp, 20);
      expect(r.weekXp, 25);
    });
    test('같은 날 데일리를 두 번 마쳐도 마친 날은 1이다', () {
      final r = run([], [c(today), c(today), c(d(11, 17)), c(d(11, 10))]);
      expect(value(r.daily, 'todayDone'), 1);
      expect(value(r.weekly, 'weekDays'), 2);
      expect(value(r.achievements, 'steady'), 3);
    });
    test('기기 시계가 앞서 오늘보다 늦은 같은 주 날짜도 이번 주다', () {
      final r = run([], [c(d(11, 20))]);
      expect(value(r.daily, 'todayDone'), 0);
      expect(value(r.weekly, 'weekDays'), 1);
    });
    test('서로 다른 매너: 은퇴한 시나리오의 기록도 센다', () {
      final r = run([a('A-plain', today), a('A-sidewalk~friend.left', today), a('A-old', d(11, 1))]);
      expect(value(r.weekly, 'weekManners'), 1);
      expect(value(r.achievements, 'collector'), 2);
    });
  });

  group('다시 푼 매너', () {
    test('매너 1을 11-10, 11-18에 풀면 주 1·전체 1', () {
      final r = run([a('A-plain', d(11, 10)), a('A-sidewalk~friend.left', today)]);
      expect(value(r.weekly, 'weekReviews'), 1);
      expect(value(r.achievements, 'reviews'), 1);
    });
    test('11-18에 두 번 더 풀어도 1이다', () {
      final r = run([a('A-plain', d(11, 10)), a('A-plain', today), a('A-plain', today)]);
      expect(value(r.weekly, 'weekReviews'), 1);
      expect(value(r.achievements, 'reviews'), 1);
    });
    test('11-10, 11-12에 풀면 다시 푼 날이 지난주라 주 0·전체 1', () {
      final r = run([a('A-plain', d(11, 10)), a('A-plain', d(11, 12))]);
      expect(value(r.weekly, 'weekReviews'), 0);
      expect(value(r.achievements, 'reviews'), 1);
    });
    test('11-18에만 풀면 0이다', () {
      final r = run([a('A-plain', today), a('A-plain', today)]);
      expect(value(r.weekly, 'weekReviews'), 0);
      expect(value(r.achievements, 'reviews'), 0);
    });
  });

  group('카테고리와 형식', () {
    test('transport 문제를 best로 풀면 transport 마스터 1, 탐험가 1', () {
      final r = run([a('A-sidewalk~friend.left', today)]);
      expect(value(r.achievements, 'categoryMaster', 'transport'), 1);
      expect(value(r.achievements, 'explorer'), 1);
      expect(value(r.weekly, 'weekCategories'), 1);
      expect(value(r.achievements, 'positionBest'), 1);
    });
    test('ok는 마스터와 형식 업적에 들어가지 않고 탐험가에는 들어간다', () {
      final r = run([a('A-order', today, Grade.ok)]);
      expect(value(r.achievements, 'categoryMaster', 'dining'), 0);
      expect(value(r.achievements, 'orderBest'), 0);
      expect(value(r.achievements, 'explorer'), 1);
    });
    test('은퇴한 시나리오의 기록도 카테고리 마스터와 탐험가에 들어간다', () {
      final r = run([a('A-old', today)]);
      expect(value(r.achievements, 'categoryMaster', 'public'), 1);
      expect(value(r.achievements, 'explorer'), 1);
    });
    test('Z-unknown~a는 풀이 수에만 들어간다', () {
      final r = run([a('Z-unknown~a', today)]);
      expect(value(r.achievements, 'firstStep'), 1);
      expect(value(r.achievements, 'collector'), 0);
      expect(value(r.achievements, 'explorer'), 0);
    });
    test('A-sidewalk~new.right는 서로 다른 매너에 들어가고 카테고리와 형식에는 들어가지 않는다', () {
      final r = run([a('A-sidewalk~new.right', today)]);
      expect(value(r.achievements, 'collector'), 1);
      expect(value(r.achievements, 'explorer'), 0);
      expect(value(r.achievements, 'positionBest'), 0);
    });
  });

  group('challenges() 목록과 목표', () {
    test('기록이 없으면 목록 길이 3·4·14, 순서는 ADR 0010 §5, 모든 value 0', () {
      final r = run([]);
      expect(r.daily.map((x) => x.id), ['todayStart', 'todayHalf', 'todayDone']);
      expect(r.weekly.map((x) => x.id), ['weekDays', 'weekManners', 'weekCategories', 'weekReviews']);
      expect(r.achievements.map((x) => x.id), [
        'firstStep', 'collector', 'steady', 'explorer', 'positionBest', 'orderBest', 'reviews',
        for (final _ in categories) 'categoryMaster',
        'allCategories',
      ]);
      expect(r.achievements.where((x) => x.id == 'categoryMaster').map((x) => x.category), categories);
      expect([...r.daily, ...r.weekly, ...r.achievements].every((x) => x.value == 0), true);
      expect(r.todayXp, 0);
      expect(r.weekXp, 0);
    });
    test('목표: 일일 1·3·1, 주간 5·10·3·5, 업적 1·30·30·6·50·20·50, 마스터 30, 전체 6', () {
      final r = run([]);
      expect(r.daily.map((x) => x.goal), [1, 3, 1]);
      expect(r.weekly.map((x) => x.goal), [5, 10, 3, 5]);
      expect(r.achievements.map((x) => x.goal), [1, 30, 30, 6, 50, 20, 50, for (final _ in categories) 30, 6]);
    });
    test('풀이 수가 5여도 todayHalf의 value는 3이다', () {
      final r = run([for (var i = 0; i < 5; i++) a('A-plain', today)]);
      expect(value(r.daily, 'todayHalf'), 3);
    });
    test('카테고리 마스터 6개가 모두 달성이면 allCategories가 6/6이다', () {
      final r = run([
        for (final cat in categories)
          for (var i = 0; i < 30; i++) a('cat-$cat', today),
      ]);
      for (final cat in categories) {
        expect(value(r.achievements, 'categoryMaster', cat), 30);
      }
      expect(value(r.achievements, 'allCategories'), 6);
      expect(value(r.achievements, 'explorer'), 6);
    });
    test('마스터 하나가 29면 allCategories는 5다', () {
      final r = run([
        for (final cat in categories)
          for (var i = 0; i < (cat == 'digital' ? 29 : 30); i++) a('cat-$cat', today),
      ]);
      expect(value(r.achievements, 'allCategories'), 5);
    });
  });
}

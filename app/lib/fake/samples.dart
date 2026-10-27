// 가짜 구현의 고정 데이터(ADR 0002 §3). docs/prototype/content.json의 day-01과 문제 몇 개를 옮겼다.
import '../backend.dart';

const motto = '위험은 내가, 편한 건 상대가';

const dayTitle = '평범한 화요일';
const nextDayTitle = '붐비는 수요일';

/// day-01의 장면 3개와 소개 문구.
const scenes = <(SceneCard, String)>[
  (SceneCard(time: '08:10', title: '출근길 인도', short: '출근길'), '회사 앞 인도. 같은 방향으로 가는 일행을 만났다.'),
  (SceneCard(time: '12:40', title: '점심 후 계단', short: '점심'), '점심을 먹고 사무실로 돌아가는 계단.'),
  (SceneCard(time: '18:50', title: '퇴근길 비', short: '퇴근길'), '퇴근하려는데 비가 쏟아진다. 우산은 하나뿐.'),
];

/// 영역 6개, ADR 0004 §3 순서. 육각형을 그려 볼 수 있게 값을 넣었다.
const stats = [
  AreaStat('연애', 40),
  AreaStat('친구', 15),
  AreaStat('어른·가족', 25),
  AreaStat('직장', 10),
  AreaStat('공공장소', 30),
  AreaStat('메시지', 0),
];

const _walkSafety = Source(
  title: '봄철 어린이 보행자 교통사고 발생 주의 당부',
  publisher: '메디컬데일리 (질병관리본부 보행 안전수칙 인용)',
  date: '2019-03-05',
  locator: '안전수칙: 보도 이용, 보도가 없으면 길 안쪽으로 통행',
  url: 'https://medicaldaily.co.kr/news/8529',
);

/// 하루 세트. scene은 scenes의 순번, manner는 retryTomorrow에 쓰는 매너 이름, e는 정답을 골랐을 때의 해설.
const samples = <({int scene, String manner, Question q, Explanation e})>[
  (
    scene: 0,
    manner: '동행자를 인도 안쪽으로',
    q: PositionQuestion(
      area: '연애',
      prompt: '연인과 인도를 걷는다. 차도는 오른쪽에 있다. 나는 어느 쪽에서 걸을까?',
      motto: motto,
      template: 'sidewalk',
      me: '나',
      other: '연인',
      vars: {'mirror': false},
      spots: [Spot('inner', '건물 쪽'), Spot('outer', '차도 쪽')],
    ),
    e: Explanation(
      grade: Grade.best,
      xp: 10,
      combo: 0,
      title: '차도 쪽은 내 자리예요',
      why: '차가 물을 튀기면 맞는 건 차도 쪽이에요. 차도가 오른쪽에 있으면 나도 오른쪽.',
      correct: ['outer'],
      evidence: Evidence(
        summary: "'안쪽이 더 안전하다'는 공식 안전수칙이다. 그 자리를 상대에게 양보하는 것은 배려 관례다.",
        sources: [
          _walkSafety,
          Source(
            title: '[기고문] 어린이 보행 교통사고 예방 우리 모두 동참하자',
            publisher: '쿠키뉴스 (삼척경찰서 경찰관 기고)',
            date: '2020-06-11',
            locator: '수칙 ④ 차도와 먼 안쪽 인도로 걷기',
            url: 'https://www.kukinews.com/article/view/kuk202006110102',
          ),
        ],
      ),
    ),
  ),
  (
    scene: 0,
    manner: '동행자를 인도 안쪽으로',
    q: PositionQuestion(
      area: '친구',
      prompt: '인도가 없는 골목길. 뒤에서 차가 다가온다. 친구와 나란히 비켜설 때 나는 어느 쪽에 설까?',
      motto: motto,
      template: 'alley',
      me: '나',
      other: '친구',
      vars: {},
      spots: [Spot('wall', '벽 쪽'), Spot('carside', '차 쪽')],
    ),
    e: Explanation(
      grade: Grade.best,
      xp: 10,
      combo: 0,
      title: '차 쪽은 내 자리예요',
      why: '인도가 없어도 같아요. 친구는 벽 쪽, 나는 친구와 차 사이.',
      correct: ['carside'],
      evidence: Evidence(
        summary: '보도가 없으면 길 안쪽(가장자리)으로 다니라는 것이 공식 안전수칙이다. 그 자리를 상대에게 주고 내가 차 쪽을 맡는 것은 배려 관례다.',
        sources: [_walkSafety],
      ),
    ),
  ),
  (
    scene: 1,
    manner: '계단에서는 상대보다 아래 칸',
    q: PositionQuestion(
      area: '어른·가족',
      prompt: '할머니와 계단을 올라간다. 나는 어디에 있을까?',
      motto: motto,
      template: 'stairs',
      me: '나',
      other: '할머니',
      vars: {'direction': 'up'},
      spots: [Spot('above', '한 칸 위'), Spot('same', '같은 칸'), Spot('below', '한 칸 아래')],
    ),
    e: Explanation(
      grade: Grade.best,
      xp: 10,
      combo: 0,
      title: '오를 땐 한 칸 아래, 뒤에서',
      why: '할머니가 뒤로 넘어지면 아래에서 받쳐 줄 수 있어요.',
      correct: ['below'],
      evidence: Evidence(
        summary: '환자 보행을 돕는 의료 안내문의 기준이다. 보조자는 오를 때 뒤, 내려갈 때 앞에 선다. 일상 동행에도 같은 이유(넘어지는 쪽에서 받친다)가 적용된다.',
        sources: [
          Source(
            title: '목발 보행 (Crutch Walking, 한국어판)',
            publisher: 'UW Medicine 환자 안내문',
            date: '2013',
            locator: "2쪽 '계단 오르기': 도와주는 사람은 오를 때 뒤, 내려갈 때 앞",
            url: 'https://healthonline.washington.edu/document/health_online/pdf/Crutch-Walking-KO.pdf',
          ),
        ],
      ),
    ),
  ),
  // 가짜: 견본에 순서 형식 예가 없어서 만든 문제다.
  (
    scene: 1,
    manner: '계단에서는 상대보다 아래 칸',
    q: OrderQuestion(
      area: '어른·가족',
      prompt: '할머니와 계단을 내려간다. 할 일을 순서대로 놓아 보세요.',
      motto: motto,
      cards: [
        Option('c', '할머니 앞에서 한 칸씩 같이 내려간다'),
        Option('a', '난간 쪽을 할머니에게 내준다'),
        Option('b', '내가 먼저 한 칸 아래로 내려선다'),
      ],
    ),
    e: Explanation(
      grade: Grade.best,
      xp: 10,
      combo: 0,
      title: '내려갈 땐 내가 먼저 아래 칸으로',
      why: '앞으로 넘어지기 쉬워요. 난간은 할머니에게 주고, 나는 항상 아래 칸이에요.',
      correct: ['a', 'b', 'c'],
    ),
  ),
  (
    scene: 2,
    manner: '우산은 상대 쪽으로',
    q: ChoiceQuestion(
      area: '연애',
      prompt: '비가 오는데 우산이 하나뿐이다. 둘이 같이 쓰고 걷는다. 어떻게 들까?',
      motto: motto,
      options: [
        Option('b', '우산을 두 사람 가운데에 똑바로 세워 든다'),
        Option('d', '키 큰 내가 드니까 내 쪽으로 기울여 든다'),
        Option('a', '우산을 상대 쪽으로 기울이고 내 어깨는 좀 젖는다'),
        Option('c', '우산은 상대에게 주고 나는 먼저 뛰어간다'),
      ],
    ),
    e: Explanation(
      grade: Grade.best,
      xp: 10,
      combo: 0,
      title: '우산은 상대 쪽으로 기울여요',
      why: '마른 쪽도 편한 쪽이에요. 내 바깥 어깨는 좀 젖어도 괜찮아요.',
      correct: ['a'],
      options: {
        'a': (grade: Grade.best, note: null),
        'b': (grade: Grade.ok, note: '나쁘진 않지만 바람이 불면 상대 쪽이 먼저 젖어요.'),
        'c': (grade: Grade.avoid, note: '같이 걷다 혼자 떠나면 상대가 더 불편해요.'),
        'd': (grade: Grade.avoid, note: '누가 들든 마른 쪽은 상대에게 줘요.'),
      },
    ),
  ),
  // 장면 매너가 아닌 문제: 복습 자리(장면의 둘째 문제, ADR 0004 §4)를 보여 준다. 출처가 없어 evidence는 null.
  (
    scene: 2,
    manner: '동행자를 인도 안쪽으로',
    q: OxQuestion(
      area: '공공장소',
      prompt: '횡단보도에서 신호를 기다린다. 동행자를 차도와 가장 가까운 맨 앞에 세운다.',
      motto: motto,
    ),
    e: Explanation(
      grade: Grade.best,
      xp: 10,
      combo: 0,
      title: '동행자는 한 걸음 안쪽에서',
      why: '멈춰 서 있을 때도 차도 쪽은 내 자리예요.',
      correct: ['x'],
    ),
  ),
];

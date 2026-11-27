import 'dart:convert';
import 'subway02_content.dart';

/// Presentation content only. Completion records and rewards do not live here.
class LessonExplanationContent {
  LessonExplanationContent.fromJson(Map<String, dynamic> json)
    : problemId = json['problemId'] as String,
      faqsInitiallyExpanded = json['faqsInitiallyExpanded'] as bool? ?? true,
      core = json['core'] as String,
      learningCore = json['learningCore'] as String,
      practice = json['practice'] as String,
      disclaimer = json['disclaimer'] as String,
      sourceIntro = json['sourceIntro'] as String? ?? '',
      extraSections = List.unmodifiable(
        (json['extraSections'] as List? ?? const []).map(
          (j) => ExplanationReason(j['title'] as String, j['body'] as String),
        ),
      ),
      reasons = List.unmodifiable(
        (json['reasons'] as List).map(
          (j) => ExplanationReason(j['title'] as String, j['body'] as String),
        ),
      ),
      faqs = List.unmodifiable(
        (json['faqs'] as List).map(
          (j) => ExplanationFaq(j['question'] as String, j['answer'] as String),
        ),
      ),
      sources = List.unmodifiable(
        (json['sources'] as List).map(
          (j) => ExplanationSource(
            title: j['title'] as String,
            body: j['body'] as String,
            agency: j['agency'] as String,
            date: j['date'] as String,
            url: Uri.parse(j['url'] as String),
            kind: j['kind'] as String,
          ),
        ),
      );
  final String problemId, core, learningCore, practice, disclaimer, sourceIntro;
  final List<ExplanationReason> reasons;
  final bool faqsInitiallyExpanded;
  final List<ExplanationReason> extraSections;
  final List<ExplanationFaq> faqs;
  final List<ExplanationSource> sources;
  String get learningPlain => learningCore.replaceAll('**', '');
  String get allText => [
    core,
    learningPlain,
    practice,
    sourceIntro,
    for (final r in reasons) ...[r.title, r.body],
    for (final q in faqs) ...[q.question, q.answer],
    for (final section in extraSections) ...[section.title, section.body],
    for (final s in sources) ...[
      s.title,
      s.body,
      s.agency,
      s.date,
      s.url.toString(),
    ],
    disclaimer,
  ].join('\n\n');
}

class ExplanationReason {
  const ExplanationReason(this.title, this.body);
  final String title, body;
}

class ExplanationFaq {
  const ExplanationFaq(this.question, this.answer);
  final String question, answer;
}

class ExplanationSource {
  const ExplanationSource({
    required this.title,
    required this.body,
    required this.agency,
    required this.date,
    required this.url,
    required this.kind,
  });
  final String title, body, agency, date, kind;
  final Uri url;
}

// Exact educational copy from education_content_subway_01.md in the supplied ZIP.
final lessonExplanations = Map<String, LessonExplanationContent>.unmodifiable({
  'transport-1': LessonExplanationContent.fromJson(
    jsonDecode(_subway01Json) as Map<String, dynamic>,
  ),
  'subway_02_basic': LessonExplanationContent.fromJson(
    jsonDecode(subway02ExplanationJson) as Map<String, dynamic>,
  ),
});

const _subway01Json = r'''
{
  "problemId": "transport-1",
  "core": "혼잡한 지하철에서는 백팩을 몸 앞쪽으로 옮겨 잡거나, 주변 승객과 부딪히지 않도록 몸 가까이 관리하는 것이 좋습니다.",
  "learningCore": "좋은 매너는 정해진 행동을 무조건 따라 하는 것이 아니라, **자신의 행동이 주변 사람에게 어떤 영향을 주는지 생각하고 상황에 맞게 배려하는 것**입니다.",
  "practice": "가방은 몸 가까이! 다른 사람이 지나갈 공간도 살펴봐요!",
  "reasons": [
    {
      "body": "지하철이 혼잡할 때는 승객 사이의 공간이 좁아집니다.\n\n등에 멘 백팩은 자신의 시야에 잘 들어오지 않기 때문에 뒤쪽에 있는 사람과 얼마나 가까운지 알아차리기 어렵습니다.\n\n특히 몸을 돌리거나 방향을 바꿀 때 백팩이 주변 사람의 몸이나 소지품에 부딪힐 수 있습니다.",
      "title": "등에 멘 백팩은 주변 사람과 부딪히기 쉽습니다."
    },
    {
      "body": "부피가 큰 백팩은 좁은 통로에서 다른 승객이 지나갈 수 있는 공간을 줄일 수 있습니다.\n\n특히 출입문이나 승객의 이동이 잦은 통로에서는 다른 사람의 승하차에 불편을 줄 수 있습니다.",
      "title": "통행을 방해할 수 있습니다."
    },
    {
      "body": "백팩을 몸 앞쪽으로 옮겨 잡으면 가방의 위치를 직접 확인하면서 관리하기 쉬워집니다.\n\n주변 승객과의 거리를 살피고 가방이 부딪히지 않도록 조절하는 데도 도움이 됩니다.\n\n다만 앞으로 멘 가방이 지나치게 크거나 주변 승객을 압박하는 경우에는 다른 방법으로 관리해야 합니다.",
      "title": "몸 앞쪽으로 옮기면 가방을 관리하기 쉬워집니다."
    }
  ],
  "faqs": [
    {
      "answer": "반드시 하나의 방법만 가능한 것은 아닙니다.\n\n몸 앞쪽으로 옮겨 메는 것은 대표적인 권장 행동이지만, 중요한 것은 다른 승객의 이동과 안전을 방해하지 않도록 가방을 관리하는 것입니다.",
      "question": "백팩을 꼭 앞으로 메야 하나요?"
    },
    {
      "answer": "통로 한가운데에 가방을 내려놓으면 다른 승객이 지나가기 어렵거나 걸려 넘어질 위험이 생길 수 있습니다.\n\n반면 자신의 발 사이처럼 통행을 방해하지 않는 위치에 가방을 두고 직접 관리하는 방법은 상황에 따라 가능합니다.\n\n가방을 바닥에 두는 것 자체보다 위치, 혼잡도, 안전, 소지품 관리 여부가 중요합니다.",
      "question": "가방을 바닥에 내려놓아도 되나요?"
    },
    {
      "answer": "억지로 몸을 돌려 주변 승객과 부딪히기보다는 안전한 공간이 확보되었을 때 가방을 옮기는 것이 좋습니다.\n\n당장 옮기기 어렵다면 몸의 움직임을 줄이고 주변 사람에게 가방이 부딪히지 않도록 주의해야 합니다.",
      "question": "사람이 너무 많아서 가방을 앞으로 옮길 수 없다면요?"
    }
  ],
  "sources": [
    {
      "date": "2017.04.05",
      "body": "부산시는 대중교통에서 백팩으로 인한 승객의 불편을 줄이기 위해 가방을 앞으로 메거나 통행에 방해되지 않는 위치에서 관리하는 캠페인을 추진했습니다.",
      "agency": "연합뉴스",
      "title": "부산시 대중교통 '백 허그' 캠페인 (2017)",
      "url": "https://www.yna.co.kr/view/AKR20170405051400051",
      "kind": "캠페인 보도"
    },
    {
      "date": "2015.09.03",
      "body": "지하철에서 백팩이 통행을 방해하거나 주변 승객에게 불편을 주는 상황을 소개하고, 백팩허그 캠페인을 다룬 자료입니다.",
      "agency": "KTV 국민방송",
      "title": "KTV 국민방송 — 가방 앞으로 안고 타세요 (2015)",
      "url": "https://m.ktv.go.kr/program/again/view?content_id=510725&program_id=PG2150012D",
      "kind": "방송 자료 · 캠페인"
    },
    {
      "date": "2017.03.14",
      "body": "혼잡한 지하철에서 배낭이 다른 승객의 이동을 방해할 수 있다는 문제와 함께, 배낭 이용자가 고려할 수 있는 현실적인 대안들을 설명한 시민기자 칼럼입니다.",
      "agency": "서울시 대표 소통 포털",
      "title": "서울시 '내 손안에 서울' — 지하철 입석 에티켓 (2017)",
      "url": "https://mediahub.seoul.go.kr/archives/1068157",
      "kind": "시민기자 칼럼"
    }
  ],
  "disclaimer": "위 자료는 권장 예절과 캠페인을 설명하는 참고 근거입니다. 일반적인 백팩 착용에 관한 전국 공통의 법적 의무로 해석하지 않습니다."
}
''';

import 'transport_progress.dart';

enum LessonStatus { notStarted, inProgress, completed }

/// Prototype presentation data; no authentication, persistence or backend calls.
class LearningLesson {
  const LearningLesson({
    required this.id,
    required this.title,
    this.keywords = '',
    LessonStatus status = LessonStatus.notStarted,
  }) : _status = status;
  final String id, title, keywords;
  final LessonStatus _status;
  bool get hasFailed =>
      TransportProgress.instance.sessions[id]?.hasFailed ?? false;
  LessonStatus get status {
    if (!id.startsWith('transport-') &&
        !id.startsWith('public-') &&
        !id.startsWith('dining-') &&
        !id.startsWith('conversation-') &&
        !id.startsWith('school-work-') &&
        !id.startsWith('digital-'))
      return _status;
    final session = TransportProgress.instance.sessions[id];
    return session?.firstCompletedAt != null
        ? LessonStatus.completed
        : session != null
        ? LessonStatus.inProgress
        : LessonStatus.notStarted;
  }

  bool matches(String query) => matchesLearningQuery('$title $keywords', query);
}

bool matchesLearningQuery(String text, String query) {
  final normalized = text.toLowerCase().replaceAll(RegExp(r'\s+'), '');
  return query
      .toLowerCase()
      .trim()
      .split(RegExp(r'\s+'))
      .every((term) => normalized.contains(term));
}

class LearningCategory {
  const LearningCategory({
    required this.id,
    required this.title,
    required this.description,
    required this.artIndex,
    required this.lessons,
  });
  final String id, title, description;
  final int artIndex;
  final List<LearningLesson> lessons;
  int get completed =>
      lessons.where((l) => l.status == LessonStatus.completed).length;
  double get progress => lessons.isEmpty ? 0 : completed / lessons.length;
  List<LearningLesson> search(String query) =>
      lessons.where((l) => l.matches(query)).toList();
  bool matches(String query) =>
      matchesLearningQuery('$title $description', query) ||
      search(query).isNotEmpty;
}

List<LearningLesson> _lessons(
  String category,
  List<(String, String)> topics,
  int completed, {
  bool transport = false,
}) => List.unmodifiable(
  List.generate(topics.length, (i) {
    final done = transport ? [0, 2, 3, 4].contains(i) : i < completed;
    final ongoing = transport ? i == 1 : i == completed;
    return LearningLesson(
      id: '$category-${i + 1}',
      title: topics[i].$1,
      keywords: topics[i].$2,
      status: done
          ? LessonStatus.completed
          : ongoing
          ? LessonStatus.inProgress
          : LessonStatus.notStarted,
    );
  }),
);

final List<LearningCategory> learningCategories = List.unmodifiable([
  LearningCategory(
    id: 'transport',
    title: '대중교통 매너',
    artIndex: 0,
    description: '모두가 더 편안한 이동을 위해\n지켜야 할 대중교통 매너를 배워요.',
    lessons: _lessons(
      'transport',
      [
        ('자리 양보하기', '좌석 교통약자 노약자 임산부'),
        ('탑승 전 질서 지키기', '버스 지하철 줄서기 승하차'),
        ('큰 소리로 통화하지 않기', '소음 전화 조용히'),
        ('음식물 섭취 자제하기', '음료 냄새 음식'),
        ('가방은 앞으로 메기', '배낭 짐 공간'),
        ('내리기 전 승객 먼저 보내기', '하차 승차 문'),
        ('노약자석 이용 예절', '좌석 자리 교통약자'),
        ('혼잡 시간대 매너', '출퇴근 공간 밀치기'),
        ('좌석에 바르게 앉기', '다리 자세 자리'),
        ('분실물 발견 시 대처 방법', '유실물 신고 물건'),
      ],
      4,
      transport: true,
    ),
  ),
  LearningCategory(
    id: 'dining',
    title: '식사 매너',
    artIndex: 1,
    description: '함께하는 식사 시간을 즐겁게!\n서로를 배려하는 식사 매너를 배워요.',
    lessons: _lessons('dining', [
      ('식사 전 손 위생 지키기', '식사 전 손 위생 지키기'),
      ('함께 식사 시작하기', '함께 식사를 시작할 때 배려하기'),
      ('공용 식기 위생 지키기', '공용 음식과 집게 위생 지키기'),
      ('식사 중 대화 예절', '식사 중 대화 예절 지키기'),
      ('상대방에게 물 따라주기', '상대방에게 물 따라주기'),
      ('자리 비울 때 배려하기', '식사 도중 자리 비울 때 배려하기'),
      ('식사 중 기침 예절', '식사 중 기침 예절 지키기'),
      ('흘린 음식 대처하기', '식탁에서 음식을 흘렸을 때 대처하기'),
      ('식사 후 자리 정돈하기', '식사 후 자리 정돈하기'),
      ('알레르기와 취향 존중하기', '음식 알레르기와 식사 취향 존중하기'),
    ], 3),
  ),
  LearningCategory(
    id: 'public',
    title: '공공장소 매너',
    artIndex: 2,
    description: '여럿이 함께 쓰는 공간에서\n모두가 편안해지는 배려를 배워요.',
    lessons: _lessons('public', [
      ('공공장소에서 줄 서기', '공공장소에서 줄 서기'),
      ('공용 통로 비워두기', '공용 통로에 물건 놓지 않기'),
      ('엘리베이터 이용 예절', '엘리베이터 이용 예절 지키기'),
      ('도서관에서 소음 줄이기', '도서관에서 소음 줄이기'),
      ('쓰레기 올바르게 배출하기', '공공장소에서 쓰레기 올바르게 배출하기'),
      ('공원 시설 함께 사용하기', '공원 시설을 함께 사용하기'),
      ('사진 촬영 권리 존중하기', '다른 사람의 사진 촬영 권리 존중하기'),
      ('공용 좌석 함께 쓰기', '공용 좌석을 혼자 차지하지 않기'),
      ('공중화장실 청결 지키기', '공중화장실을 청결하게 이용하기'),
      ('공공장소 기침 예절', '공공장소에서 기침 예절 지키기'),
    ], 2),
  ),
  LearningCategory(
    id: 'conversation',
    title: '대화 매너',
    artIndex: 3,
    description: '말 한마디에 배려를 담아\n기분 좋은 대화를 시작해 봐요.',
    lessons: _lessons('conversation', [
      ('상대방 말 끝까지 듣기', '상대방의 말을 끝까지 경청하기 경청'),
      ('말할 차례 존중하기', '상대방이 말할 차례 존중하기'),
      ('오해를 차분히 확인하기', '오해가 생겼을 때 차분하게 확인하기'),
      ('서로 다른 의견 존중하기', '서로 다른 의견 존중하기'),
      ('관심을 보이며 대화하기', '상대방에게 관심을 보이며 대화하기'),
      ('대화 중 방해 요소 치우기', '대화 중 방해 요소 치우기'),
      ('진심으로 사과하기', '실수했을 때 진심으로 사과하기'),
      ('감사한 마음 표현하기', '감사한 마음을 적절하게 표현하기'),
      ('정중히 부탁하고 거절하기', '정중하게 부탁하고 거절하기'),
      ('갈등 후 대화 마무리하기', '갈등 후 대화 마무리하기'),
    ], 5),
  ),
  LearningCategory(
    id: 'school-work',
    title: '학교 · 직장 매너',
    artIndex: 4,
    description: '함께 배우고 일하는 공간에서\n믿음을 만드는 기본 매너를 배워요.',
    lessons: _lessons('school-work', [
      ('지각 전 미리 연락하기', '지각이 예상될 때 미리 연락하기'),
      ('학교·직장에서 인사하기', '학교와 직장에서 먼저 인사하기'),
      ('회의 발언 순서 지키기', '회의에서 발언 순서 지키기'),
      ('공동 자료와 정보 보호하기', '공동 자료와 개인정보 보호하기'),
      ('공용 책상과 공간 정리하기', '공용 책상과 업무 공간 정리하기'),
      ('팀 일정 조율하기', '팀 일정 조율하기'),
      ('업무 메일·메신저 예절', '업무 메일과 메신저 예절 지키기'),
      ('팀원 의견과 역할 존중하기', '팀원의 의견과 역할 존중하기'),
      ('공용 기기 사용 후 정리하기', '공용 기기 사용 후 정리하기'),
      ('실수를 책임 있게 보고하기', '실수했을 때 책임 있게 보고하기'),
    ], 6),
  ),
  LearningCategory(
    id: 'digital',
    title: '디지털 매너',
    artIndex: 5,
    description: '화면 너머에도 사람이 있어요.\n서로를 존중하는 디지털 매너를 배워요.',
    lessons: _lessons('digital', [
      ('단체 채팅방 소통 예절', '단체 채팅방에서 배려하며 소통하기'),
      ('사진 속 개인정보 가리기', '개인정보가 보이지 않도록 사진 공유하기'),
      ('사진 게시 전 동의 구하기', '다른 사람의 사진을 올리기 전 동의 구하기'),
      ('존중하는 댓글 작성하기', '온라인 댓글을 존중하는 표현으로 작성하기'),
      ('정보 확인 후 공유하기', '온라인 정보를 공유하기 전 확인하기'),
      ('의심 메시지와 링크 대처', '의심스러운 메시지와 링크 대처하기'),
      ('화면 공유 전 정보 정리하기', '화면 공유 전에 개인정보 정리하기'),
      ('콘텐츠 저작권 존중하기', '다른 사람의 콘텐츠 저작권 존중하기'),
      ('온라인 괴롭힘에 대응하기', '온라인 괴롭힘 상황에 안전하게 대응하기'),
      ('기기 잠금과 정보 보호하기', '디지털 기기 잠금과 정보 보호하기'),
    ], 4),
  ),
]);

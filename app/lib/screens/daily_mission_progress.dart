/// Prototype presentation data. Replace with learning results when that flow is connected.
class DailyMissionProgress {
  const DailyMissionProgress({this.completed = 0, this.total = 10})
    : assert(total > 0),
      assert(completed >= 0 && completed <= total);
  final int completed, total;
  double get fraction => completed / total;
  bool get isComplete => completed == total;
  String get encouragement => isComplete
      ? '오늘도 고생했어요!! 멋지게 해냈어요.'
      : completed == 0
      ? '오늘도 화이팅! 작은 배려를 시작해 볼까요?'
      : '${total - completed}문제만 더 풀면 오늘의 문제를 다 풀어요!';
  String get action => isComplete
      ? '오늘의 학습 완료'
      : completed == 0
      ? '시작하기'
      : '이어서 하기';
  String titleAt(int i) => const [
    '지하철에서 다른 승객 배려하기',
    '버스 승하차 예절',
    '교통약자에게 자리 양보하기',
    '혼잡한 대중교통 이용하기',
    '엘리베이터 이용 예절',
    '공공장소에서 조용히 대화하기',
    '문을 잡아 주는 배려',
    '식사 시간의 기본 매너',
    '고마운 마음 표현하기',
    '하루의 작은 배려 돌아보기',
  ][i % 10];
  String timeAt(int i) {
    final minutes = 8 * 60 + 24 + i * 5;
    return '오전 ${(minutes ~/ 60).toString().padLeft(2, '0')}:${(minutes % 60).toString().padLeft(2, '0')}';
  }
}

import 'package:flutter/material.dart';

/// Presentation preview until the backend challenge contract is agreed.
/// No learning records, reward calculation, or persistence live in this screen.
class ChallengesScreen extends StatefulWidget {
  const ChallengesScreen({super.key});
  @override
  State<ChallengesScreen> createState() => _ChallengesScreenState();
}

class _ChallengesScreenState extends State<ChallengesScreen> {
  int _tab = 0;
  static const _green = Color(0xFF476B5B);
  static const _titles = [
    ['오늘의 첫걸음', '배려를 쌓는 하루', '다시 한번!', '오늘의 매너 완주'],
    ['꾸준한 매너 습관', '다양한 매너 배우기', '매너 탐험가', '행동으로 실천하기', '순서의 달인', '복습하는 습관'],
    [
      '첫걸음',
      '매너 수집가',
      '꾸준함',
      '탐험가',
      '행동 달인',
      '순서 고수',
      '복습 습관',
      '대중교통 마스터',
      '식사 마스터',
      '공공장소 마스터',
      '대화 마스터',
      '학교·직장 마스터',
      '디지털 마스터',
      '매너스 마스터',
    ],
  ];
  static const _icons = <String, IconData>{
    '오늘의 첫걸음': Icons.directions_walk,
    '배려를 쌓는 하루': Icons.favorite_outline,
    '다시 한번!': Icons.replay,
    '오늘의 매너 완주': Icons.flag_outlined,
    '꾸준한 매너 습관': Icons.calendar_month_outlined,
    '다양한 매너 배우기': Icons.auto_stories_outlined,
    '매너 탐험가': Icons.explore_outlined,
    '행동으로 실천하기': Icons.touch_app_outlined,
    '순서의 달인': Icons.format_list_numbered,
    '복습하는 습관': Icons.history,
    '첫걸음': Icons.directions_walk,
    '매너 수집가': Icons.collections_bookmark_outlined,
    '꾸준함': Icons.local_fire_department_outlined,
    '탐험가': Icons.explore_outlined,
    '행동 달인': Icons.touch_app_outlined,
    '순서 고수': Icons.format_list_numbered,
    '복습 습관': Icons.history,
    '대중교통 마스터': Icons.directions_bus_outlined,
    '식사 마스터': Icons.restaurant,
    '공공장소 마스터': Icons.park_outlined,
    '대화 마스터': Icons.forum_outlined,
    '학교·직장 마스터': Icons.business_center_outlined,
    '디지털 마스터': Icons.devices_outlined,
    '매너스 마스터': Icons.emoji_events_outlined,
  };
  static const _descriptions = [
    ['오늘의 학습 시작하기', '오늘의 학습 절반 진행하기', '복습할 매너 다시 살펴보기', '오늘의 데일리 학습 마치기'],
    [
      '서로 다른 날에도 꾸준히 학습해요.',
      '다양한 주제를 살펴봐요.',
      '여러 카테고리의 매너를 배워요.',
      '행동형 문제로 직접 실천해요.',
      '올바른 행동 순서를 익혀요.',
      '배운 매너를 다시 떠올려요.',
    ],
  ];
  Widget _panel(Widget child) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: const Color(0xFFE7E8EA)),
    ),
    child: child,
  );
  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xFFF9F9F9),
    bottomNavigationBar: SafeArea(
      top: false,
      child: Material(
        color: Colors.white,
        child: Row(
          children: [
            _navigation(
              Icons.home_outlined,
              '홈',
              () => Navigator.of(context).pop('home'),
            ),
            _navigation(
              Icons.menu_book_outlined,
              '학습하기',
              () => Navigator.of(context).pop('learn'),
            ),
            _navigation(Icons.emoji_events, '도전과제', () {}, selected: true),
            _navigation(
              Icons.person_outline,
              '마이페이지',
              () => Navigator.of(context).pop('profile'),
            ),
          ],
        ),
      ),
    ),
    body: SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 22, 20, 24),
        children: [
          const Text(
            '도전과제',
            style: TextStyle(fontSize: 25, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 6),
          const Text(
            '작은 도전을 하며 매너 습관을 쌓아보세요.',
            style: TextStyle(fontSize: 12, color: Colors.black54),
          ),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: const Color(0xFFEEEEEE),
              borderRadius: BorderRadius.circular(24),
            ),
            child: Row(
              children: List.generate(
                3,
                (i) => Expanded(
                  child: Semantics(
                    selected: _tab == i,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(22),
                      onTap: () => setState(() => _tab = i),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: _tab == i
                              ? const Color(0xFF191D1A)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(22),
                        ),
                        child: Text(
                          ['일일', '주간', '업적'][i],
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: _tab == i ? Colors.white : Colors.black54,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          _panel(
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  ['오늘의 달성 현황', '이번 주 학습 현황', '나의 업적'][_tab],
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  '학습 기록 연결을 기다리고 있어요.',
                  style: TextStyle(fontSize: 12, color: Colors.black54),
                ),
                const SizedBox(height: 16),
                const Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '— / — 달성',
                      style: TextStyle(
                        fontSize: 21,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text('—%', style: TextStyle(fontWeight: FontWeight.w700)),
                  ],
                ),
                const SizedBox(height: 10),
                const LinearProgressIndicator(
                  value: 0,
                  minHeight: 8,
                  color: _green,
                  backgroundColor: Color(0xFFE9EAEC),
                  borderRadius: BorderRadius.all(Radius.circular(8)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _panel(
            Row(
              children: [
                Icon(
                  _tab == 2
                      ? Icons.workspace_premium_outlined
                      : Icons.insights_outlined,
                  color: _green,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _tab == 1
                        ? '이번 주 획득 XP  —'
                        : _tab == 2
                        ? '획득한 배지  —'
                        : '오늘의 학습 기록  —',
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          for (final i in List.generate(
            _titles[_tab].length,
            (index) => index,
          )) ...[
            _panel(
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(_icons[_titles[_tab][i]], size: 30, color: _green),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _titles[_tab][i],
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          _tab == 2
                              ? '차곡차곡 쌓은 배움을 확인해요.'
                              : _descriptions[_tab][i],
                          style: const TextStyle(
                            fontSize: 11,
                            color: Colors.black54,
                          ),
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          '기록 연결 후 표시',
                          style: TextStyle(fontSize: 10, color: Colors.black45),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
          ],
        ],
      ),
    ),
  );
  Widget _navigation(
    IconData icon,
    String label,
    VoidCallback onTap, {
    bool selected = false,
  }) => Expanded(
    child: InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 25, color: selected ? Colors.black : Colors.grey),
            const SizedBox(height: 3),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                color: selected ? Colors.black : Colors.grey,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

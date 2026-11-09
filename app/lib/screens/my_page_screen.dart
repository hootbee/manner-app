import '../backend.dart';
import 'manner_stats_screen.dart';
import 'wardrobe_screen.dart';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'partner_selection_screen.dart';

/// Profile presentation only. Account assets and XP await the backend contract.
class MyPageScreen extends StatefulWidget {
  const MyPageScreen({super.key, required this.partner});
  final MannerPartner partner;
  @override
  State<MyPageScreen> createState() => _MyPageScreenState();
}

class _MyPageScreenState extends State<MyPageScreen>
    with SingleTickerProviderStateMixin {
  late final _laugh = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  );
  double _angle = 0;
  static const _ink = Color(0xFF191D1A);
  static const _menus = [
    (Icons.checkroom_outlined, '캐릭터 꾸미기', '나만의 매너 파트너를 꾸며보세요.'),
    (Icons.shopping_bag_outlined, '꾸미기 상점', '다양한 아이템을 구경해보세요.'),
    (Icons.bar_chart_rounded, '나의 매너 스탯', '6개 분야의 성장 현황을 확인해요.'),
    (Icons.menu_book_outlined, '학습 기록', '지금까지의 학습 내용을 모아보세요.'),
    (Icons.share_outlined, '스탯 공유', '나의 성장을 친구들에게 공유해요.'),
    (Icons.settings_outlined, '설정', '계정 및 앱 설정을 관리해보세요.'),
  ];
  @override
  void dispose() {
    _laugh.dispose();
    super.dispose();
  }

  void _notice(String label) => ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text('$label는 준비 중이에요.')));
  void _react() {
    _laugh.forward(from: 0);
  }

  Widget _panel(Widget child) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: const Color(0xFFE7E8EA)),
    ),
    child: Material(color: Colors.transparent, child: child),
  );
  @override
  Widget build(BuildContext context) {
    final reduced = MediaQuery.disableAnimationsOf(context);
    return Scaffold(
      backgroundColor: const Color(0xFFF9F9F9),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Material(
          color: Colors.white,
          child: Row(
            children: [
              _nav(Icons.home_outlined, '홈', 'home'),
              _nav(Icons.menu_book_outlined, '학습하기', 'learn'),
              _nav(Icons.emoji_events_outlined, '도전과제', 'challenges'),
              _nav(Icons.person, '마이페이지', null),
            ],
          ),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 22),
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  '마이페이지',
                  style: TextStyle(fontSize: 25, fontWeight: FontWeight.w900),
                ),
                IconButton(
                  tooltip: '설정',
                  onPressed: () => _notice('설정'),
                  icon: const Icon(Icons.settings_outlined),
                ),
              ],
            ),
            AnimatedBuilder(
              animation: _laugh,
              builder: (context, _) {
                final laughing = _laugh.isAnimating;
                final bounce = reduced
                    ? 0.0
                    : math.sin(_laugh.value * math.pi * 6) *
                          math.sin(_laugh.value * math.pi);
                return Column(
                  children: [
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: const Color(0xFFE7E8EA)),
                      ),
                      child: Text(
                        laughing ? '꺄르르! 함께하니 즐거워요!' : '오늘도 함께\n작은 배려를 배워요.',
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 12, height: 1.5),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      widget.partner.name,
                      style: const TextStyle(
                        fontSize: 21,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      '레벨 · XP 연결 대기',
                      style: TextStyle(fontSize: 11, color: Colors.black54),
                    ),
                    SizedBox(
                      height: 238,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Positioned(
                            bottom: 12,
                            child: Container(
                              width: 224,
                              height: 24,
                              decoration: BoxDecoration(
                                color: const Color(0xFFE9EBE9),
                                borderRadius: BorderRadius.circular(100),
                              ),
                            ),
                          ),
                          Semantics(
                            label:
                                '${widget.partner.name}, 터치하면 웃고 좌우로 드래그하면 회전해요.',
                            button: true,
                            onTap: _react,
                            child: GestureDetector(
                              key: const Key('profile-character'),
                              behavior: HitTestBehavior.opaque,
                              onTap: _react,
                              onHorizontalDragUpdate: (details) => setState(
                                () => _angle =
                                    (_angle + details.delta.dx * .012) %
                                    (math.pi * 2),
                              ),
                              child: SizedBox(
                                width: 236,
                                height: 236,
                                child: Transform(
                                  key: const Key('character-turn'),
                                  alignment: Alignment.center,
                                  transform: Matrix4.identity()
                                    ..setEntry(3, 2, .001)
                                    ..rotateY(_angle),
                                  child: Transform.translate(
                                    offset: Offset(0, -bounce.abs() * 9),
                                    child: Transform.rotate(
                                      angle: bounce * .06,
                                      child: AppliedClothingCharacter(
                                        partner: widget.partner,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
            const Text(
              '좌우로 돌려보고, 톡 눌러 인사해요.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 11, color: Colors.black54),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _panel(
                    const Row(
                      children: [
                        Icon(Icons.stars_outlined, color: Color(0xFFB58C4E)),
                        SizedBox(width: 8),
                        Expanded(child: PreviewCoinLabel()),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _panel(
                    const Row(
                      children: [
                        Icon(Icons.workspace_premium_outlined),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '—\n획득한 배지',
                            style: TextStyle(fontSize: 12, height: 1.5),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _panel(
              Column(
                children: [
                  for (var i = 0; i < _menus.length; i++) ...[
                    if (i > 0)
                      const Divider(height: 1, color: Color(0xFFEEEEEE)),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      minLeadingWidth: 30,
                      leading: CircleAvatar(
                        radius: 19,
                        backgroundColor: const Color(0xFFF4F5F4),
                        child: Icon(_menus[i].$1, color: _ink, size: 22),
                      ),
                      title: Text(
                        _menus[i].$2,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      subtitle: Text(
                        _menus[i].$3,
                        style: const TextStyle(
                          fontSize: 10,
                          color: Colors.black54,
                        ),
                      ),
                      trailing: const Icon(Icons.chevron_right, size: 20),
                      onTap: () {
                        if (i < 2) {
                          Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => WardrobeScreen(
                                partner: widget.partner,
                                shop: i == 1,
                              ),
                            ),
                          );
                        } else if (i == 2) {
                          Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => MannerStatsScreen(
                                stats: backend.stats,
                                partner: widget.partner,
                                preview: true,
                              ),
                            ),
                          );
                        } else {
                          _notice(_menus[i].$2);
                        }
                      },
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _nav(IconData icon, String label, String? destination) => Expanded(
    child: InkWell(
      onTap: destination == null
          ? null
          : () => Navigator.of(context).pop(destination),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 25,
              color: destination == null ? _ink : Colors.grey,
            ),
            const SizedBox(height: 3),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                color: destination == null ? _ink : Colors.grey,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

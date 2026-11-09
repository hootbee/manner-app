import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../backend.dart';
import 'partner_artwork.dart';
import 'partner_selection_screen.dart';

/// Renders the backend's area values. Learning and review calculations stay there.
class MannerStatsScreen extends StatefulWidget {
  const MannerStatsScreen({
    super.key,
    required this.stats,
    this.partner = MannerPartner.dog,
    this.preview = false,
  });
  final ValueListenable<List<AreaStat>> stats;
  final MannerPartner partner;
  final bool preview;
  @override
  State<MannerStatsScreen> createState() => _MannerStatsScreenState();
}

class _MannerStatsScreenState extends State<MannerStatsScreen> {
  String? _selected;
  static const _green = Color(0xFF476B5B);
  static const _icons = <String, IconData>{
    '대화': Icons.forum_outlined,
    '식사': Icons.restaurant,
    '공공장소': Icons.park_outlined,
    '대중교통': Icons.directions_bus_outlined,
    '학교·직장': Icons.business_center_outlined,
    '디지털': Icons.devices_outlined,
    '연애': Icons.favorite_outline,
    '친구': Icons.people_outline,
    '어른·가족': Icons.family_restroom,
    '직장': Icons.business_center_outlined,
    '메시지': Icons.chat_bubble_outline,
  };
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
    appBar: AppBar(
      backgroundColor: const Color(0xFFF9F9F9),
      title: const Text(
        '나의 매너 스탯',
        style: TextStyle(fontSize: 21, fontWeight: FontWeight.w800),
      ),
    ),
    body: ValueListenableBuilder<List<AreaStat>>(
      valueListenable: widget.stats,
      builder: (context, stats, _) {
        final selected = stats.any((s) => s.area == _selected)
            ? _selected
            : null;
        final visible = selected == null
            ? stats
            : stats.where((s) => s.area == selected).toList();
        return ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          children: [
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (final label in ['전체', ...stats.map((s) => s.area)])
                    Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: ChoiceChip(
                        label: Text(label),
                        selected: label == (selected ?? '전체'),
                        showCheckmark: false,
                        selectedColor: const Color(0xFF191D1A),
                        backgroundColor: const Color(0xFFF0F1F0),
                        side: BorderSide.none,
                        labelStyle: TextStyle(
                          fontSize: 12,
                          color: label == (selected ?? '전체')
                              ? Colors.white
                              : Colors.black54,
                        ),
                        onSelected: (_) => setState(
                          () => _selected = label == '전체' ? null : label,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            if (widget.preview) ...[
              const Text(
                '미리보기 데이터 · 실제 풀이 기록 연결 대기',
                style: TextStyle(fontSize: 11, color: Colors.black54),
              ),
              const SizedBox(height: 10),
            ],
            if (stats.isEmpty)
              _panel(
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 40),
                  child: Text(
                    '아직 표시할 학습 스탯이 없어요.',
                    textAlign: TextAlign.center,
                  ),
                ),
              )
            else
              _panel(
                Column(
                  children: [
                    if (stats.length == 6)
                      _RadarChart(stats: stats, selected: selected)
                    else
                      const Padding(
                        padding: EdgeInsets.all(24),
                        child: Text('6개 분야의 스탯이 준비되면 그래프를 표시해요.'),
                      ),
                    const SizedBox(height: 8),
                    const Text(
                      '학습과 복습으로 차곡차곡 성장해요.',
                      style: TextStyle(fontSize: 11, color: Colors.black54),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 20),
            Text(
              selected == null ? '분야별 상세 수치' : '$selected 분야',
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 10),
            _panel(
              Column(
                children: [
                  for (var i = 0; i < visible.length; i++) ...[
                    if (i > 0)
                      const Divider(height: 24, color: Color(0xFFEFEFEF)),
                    Row(
                      children: [
                        Icon(
                          _icons[visible[i].area] ??
                              Icons.auto_stories_outlined,
                          size: 22,
                        ),
                        const SizedBox(width: 10),
                        SizedBox(
                          width: 66,
                          child: Text(
                            visible[i].area,
                            style: const TextStyle(fontSize: 12),
                          ),
                        ),
                        Expanded(
                          child: TweenAnimationBuilder<double>(
                            duration: MediaQuery.disableAnimationsOf(context)
                                ? Duration.zero
                                : const Duration(milliseconds: 450),
                            tween: Tween(
                              end: visible[i].value.clamp(0, 100) / 100,
                            ),
                            builder: (context, value, _) =>
                                LinearProgressIndicator(
                                  value: value,
                                  color: _green,
                                  backgroundColor: const Color(0xFFE9EAEC),
                                  minHeight: 7,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        SizedBox(
                          width: 38,
                          child: Text(
                            '${visible[i].value.clamp(0, 100)}%',
                            textAlign: TextAlign.right,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 16),
            _panel(
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(
                        Icons.auto_awesome_outlined,
                        size: 17,
                        color: _green,
                      ),
                      SizedBox(width: 8),
                      Text(
                        '매너 파트너의 한마디',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    selected == null
                        ? '잘 아는 매너도 다시 떠올려보세요.\n꾸준한 복습이 배려하는 습관을 만들어요!'
                        : '$selected 매너를 차근차근 익혀봐요.\n배운 내용을 복습하면 더 오래 기억할 수 있어요.',
                    style: const TextStyle(
                      fontSize: 12,
                      height: 1.6,
                      color: Colors.black54,
                    ),
                  ),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: SizedBox(
                      width: 95,
                      height: 95,
                      child: PartnerArtwork(
                        partner: widget.partner,
                        showSparkles: false,
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
  );
}

class _RadarChart extends StatelessWidget {
  const _RadarChart({required this.stats, required this.selected});
  final List<AreaStat> stats;
  final String? selected;
  @override
  Widget build(BuildContext context) => Semantics(
    container: true,
    label:
        '매너 스탯: ${stats.map((s) => '${s.area} ${s.value.clamp(0, 100)}%').join(', ')}',
    child: ExcludeSemantics(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final side = math.min(constraints.maxWidth, 320.0);
          final values = stats.map((s) => s.value.clamp(0, 100) / 100).toList();
          return Center(
            child: SizedBox(
              width: side,
              height: side,
              child: Stack(
                children: [
                  Positioned.fill(
                    child: TweenAnimationBuilder<List<double>>(
                      duration: MediaQuery.disableAnimationsOf(context)
                          ? Duration.zero
                          : const Duration(milliseconds: 600),
                      tween: _ValuesTween(
                        begin: List.filled(6, 0),
                        end: values,
                      ),
                      builder: (context, value, _) => CustomPaint(
                        painter: _RadarPainter(
                          value,
                          stats.indexWhere((s) => s.area == selected),
                        ),
                      ),
                    ),
                  ),
                  for (var i = 0; i < 6; i++)
                    Positioned(
                      left:
                          side / 2 +
                          math.cos(-math.pi / 2 + i * math.pi / 3) *
                              side *
                              .405 -
                          38,
                      top:
                          side / 2 +
                          math.sin(-math.pi / 2 + i * math.pi / 3) *
                              side *
                              .405 -
                          18,
                      width: 76,
                      height: 40,
                      child: Column(
                        children: [
                          Text(
                            stats[i].area,
                            maxLines: 1,
                            style: TextStyle(
                              fontSize: 10,
                              color: selected == stats[i].area
                                  ? const Color(0xFF476B5B)
                                  : Colors.black54,
                            ),
                          ),
                          Text(
                            '${stats[i].value.clamp(0, 100)}%',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    ),
  );
}

class _ValuesTween extends Tween<List<double>> {
  _ValuesTween({required super.begin, required super.end});
  @override
  List<double> lerp(double t) =>
      List.generate(6, (i) => begin![i] + (end![i] - begin![i]) * t);
}

class _RadarPainter extends CustomPainter {
  const _RadarPainter(this.values, this.selected);
  final List<double> values;
  final int selected;
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width * .285;
    Offset point(int i, double scale) =>
        center +
        Offset(
              math.cos(-math.pi / 2 + i * math.pi / 3),
              math.sin(-math.pi / 2 + i * math.pi / 3),
            ) *
            radius *
            scale;
    Path polygon(List<double> scales) {
      final path = Path()
        ..moveTo(point(0, scales[0]).dx, point(0, scales[0]).dy);
      for (var i = 1; i < 6; i++) {
        path.lineTo(point(i, scales[i]).dx, point(i, scales[i]).dy);
      }
      return path..close();
    }

    final grid = Paint()
      ..color = const Color(0xFFDADFDA)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    for (final step in [.25, .5, .75, 1.0]) {
      canvas.drawPath(polygon(List.filled(6, step)), grid);
    }
    for (var i = 0; i < 6; i++) {
      canvas.drawLine(center, point(i, 1), grid);
    }
    final shape = polygon(values);
    canvas.drawPath(shape, Paint()..color = const Color(0x55476B5B));
    canvas.drawPath(
      shape,
      Paint()
        ..color = const Color(0xFF476B5B)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
    for (var i = 0; i < 6; i++) {
      canvas.drawCircle(
        point(i, values[i]),
        i == selected ? 5 : 3,
        Paint()
          ..color = i == selected
              ? const Color(0xFF476B5B)
              : const Color(0xFF191D1A),
      );
    }
  }

  @override
  bool shouldRepaint(_RadarPainter oldDelegate) =>
      !listEquals(oldDelegate.values, values) ||
      oldDelegate.selected != selected;
}

import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'welcome_screen.dart';
import 'partner_growth_screen.dart';

const _ink = Color(0xFF191D1A);
const _muted = Color(0xFF6B7079);

/// Display data only; choosing a partner does not change learning rewards.
enum MannerPartner {
  cat(
    '냥냥이',
    '차분형',
    '침착하게 상황을 살펴봐요.\n작은 행동도 꼼꼼하게 함께 생각해요.',
    '관찰, 존중, 신중함, 차분함',
    '“잠깐의 생각이 모여\n기분 좋은 배려가 돼요.”',
  ),
  dog(
    '댕댕이',
    '다정형',
    '따뜻하고 배려심이 많아요.\n친근하게 다가가 좋은 분위기를 만들어요.',
    '배려, 친절, 공감, 따뜻함',
    '“작은 배려가 모여\n더 좋은 일상을 만들 수 있어요!”',
  ),
  monkey(
    '몽몽이',
    '활발형',
    '밝은 에너지로 용기를 북돋워요.\n어려운 상황도 즐겁게 함께 풀어가요.',
    '용기, 긍정, 소통, 활기',
    '“우리 함께 한 걸음씩!\n오늘도 멋진 매너를 만들어봐요.”',
  );

  const MannerPartner(
    this.name,
    this.type,
    this.description,
    this.keywords,
    this.quote,
  );
  final String name, type, description, keywords, quote;
}

class PartnerSelectionScreen extends StatefulWidget {
  const PartnerSelectionScreen({super.key, this.onConfirm});
  final ValueChanged<MannerPartner>? onConfirm;

  @override
  State<PartnerSelectionScreen> createState() => _PartnerSelectionScreenState();
}

class _PartnerSelectionScreenState extends State<PartnerSelectionScreen>
    with TickerProviderStateMixin {
  late final _turn = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 480),
  );
  late final _ambient = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 4200),
  );
  ui.Image? _image;
  int _selected = 1;
  double _from = 1, _to = 1;
  bool? _reduceMotion;

  @override
  void initState() {
    super.initState();
    _loadImage();
  }

  Future<void> _loadImage() async {
    final data = await rootBundle.load('assets/welcome/characters.png');
    final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
    final frame = await codec.getNextFrame();
    codec.dispose();
    if (!mounted) {
      frame.image.dispose();
      return;
    }
    setState(() => _image = frame.image);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduced = MediaQuery.disableAnimationsOf(context);
    if (_reduceMotion == reduced) return;
    _reduceMotion = reduced;
    if (reduced) {
      _ambient.stop();
      _turn.value = 1;
    } else {
      _ambient.repeat();
    }
  }

  void _rotate(int direction) {
    if (_turn.isAnimating) return;
    setState(() {
      _from = _to;
      _to += direction;
      _selected = (_selected + direction) % 3;
    });
    if (_reduceMotion == true) {
      _turn.value = 1;
    } else {
      _turn.forward(from: 0);
    }
  }

  void _confirm() {
    final partner = MannerPartner.values[_selected];
    if (widget.onConfirm != null) {
      widget.onConfirm!(partner);
      return;
    }
    _showGrowth(partner);
  }

  void _showGrowth(MannerPartner partner) {
    if (_turn.isAnimating) return;
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => PartnerGrowthScreen(partner: partner),
      ),
    );
  }

  void _tapCharacter(TapUpDetails details) {
    final width = context.size!.width;
    final x = details.localPosition.dx / width * 360;
    var nearest = _selected;
    var distance = double.infinity;
    for (var i = 0; i < 3; i++) {
      final center = 180 + 138 * math.sin((i - _to) * math.pi * 2 / 3);
      if ((center - x).abs() < distance) {
        nearest = i;
        distance = (center - x).abs();
      }
    }
    _showGrowth(MannerPartner.values[nearest]);
  }

  @override
  void dispose() {
    _turn.dispose();
    _ambient.dispose();
    _image?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final partner = MannerPartner.values[_selected];
    return Scaffold(
      backgroundColor: const Color(0xFFF8F8F8),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: Column(
                  children: [
                    SizedBox(
                      height: 120,
                      child: Stack(
                        children: [
                          Positioned(
                            left: 8,
                            top: 8,
                            child: IconButton(
                              tooltip: '뒤로 가기',
                              icon: const Icon(Icons.chevron_left),
                              onPressed: () => Navigator.of(context).pop(),
                            ),
                          ),
                          const Positioned(
                            left: 50,
                            right: 50,
                            top: 22,
                            child: Column(
                              children: [
                                Text(
                                  '나의 매너 파트너를\n선택해 주세요!',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 20,
                                    height: 1.3,
                                    fontWeight: FontWeight.w800,
                                    color: _ink,
                                  ),
                                ),
                                SizedBox(height: 6),
                                Text(
                                  '함께할 캐릭터를 선택하고\n매너를 배워보세요.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 13,
                                    height: 1.4,
                                    color: _muted,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(
                      height: 212,
                      width: double.infinity,
                      child: GestureDetector(
                        key: const ValueKey('partner-carousel'),
                        behavior: HitTestBehavior.opaque,
                        onTapUp: _tapCharacter,
                        child: AnimatedBuilder(
                          animation: Listenable.merge([_turn, _ambient]),
                          builder: (_, _) => CustomPaint(
                            painter: _PartnerCarousel(
                              _image,
                              _from +
                                  (_to - _from) *
                                      Curves.easeInOutCubic.transform(
                                        _turn.value,
                                      ),
                              _ambient.value,
                              _reduceMotion ?? false,
                            ),
                          ),
                        ),
                      ),
                    ),
                    SizedBox(
                      height: 54,
                      child: Stack(
                        children: [
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 44),
                            child: Row(
                              children: List.generate(3, (slot) {
                                final index = (_selected + slot - 1) % 3;
                                final p = MannerPartner.values[index];
                                return Expanded(
                                  child: AnimatedSwitcher(
                                    duration: Duration(
                                      milliseconds: _reduceMotion == true
                                          ? 0
                                          : 220,
                                    ),
                                    child: Column(
                                      key: ValueKey(index),
                                      children: [
                                        Text(
                                          p.name,
                                          style: TextStyle(
                                            fontSize: slot == 1 ? 19 : 15,
                                            fontWeight: slot == 1
                                                ? FontWeight.w800
                                                : FontWeight.w500,
                                            color: slot == 1 ? _ink : _muted,
                                          ),
                                        ),
                                        Text(
                                          p.type,
                                          style: const TextStyle(
                                            fontSize: 13,
                                            color: _muted,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              }),
                            ),
                          ),
                          Positioned(
                            left: 8,
                            top: 0,
                            child: _Arrow(
                              label: '이전 캐릭터',
                              icon: Icons.chevron_left,
                              onTap: () => _rotate(-1),
                            ),
                          ),
                          Positioned(
                            right: 8,
                            top: 0,
                            child: _Arrow(
                              label: '다음 캐릭터',
                              icon: Icons.chevron_right,
                              onTap: () => _rotate(1),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: AnimatedSwitcher(
                        duration: Duration(
                          milliseconds: _reduceMotion == true ? 0 : 220,
                        ),
                        child: _PartnerDetails(
                          key: ValueKey(partner),
                          partner: partner,
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      child: Semantics(
                        label: '${_selected + 1}/3, ${partner.name} 선택됨',
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: List.generate(
                            3,
                            (i) => Container(
                              margin: const EdgeInsets.symmetric(horizontal: 3),
                              width: 7,
                              height: 7,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: i == _selected
                                    ? _ink
                                    : const Color(0xFFD4D6D8),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 2, 20, 20),
                      child: SizedBox(
                        width: double.infinity,
                        child: WelcomeButton(
                          label: '이 캐릭터로 시작하기',
                          primary: true,
                          onPressed: _confirm,
                        ),
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
}

class _Arrow extends StatelessWidget {
  const _Arrow({required this.label, required this.icon, required this.onTap});
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => SizedBox(
    width: 44,
    height: 44,
    child: Material(
      color: Colors.white,
      shape: const CircleBorder(),
      elevation: 5,
      shadowColor: Colors.black26,
      child: IconButton(
        tooltip: label,
        onPressed: onTap,
        icon: Icon(icon, color: _ink),
      ),
    ),
  );
}

class _PartnerDetails extends StatelessWidget {
  const _PartnerDetails({super.key, required this.partner});
  final MannerPartner partner;
  Widget _row(String title, Widget value) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 76,
          child: Text(
            title,
            style: const TextStyle(fontSize: 13, color: _muted),
          ),
        ),
        Expanded(child: value),
      ],
    ),
  );
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: .65),
      borderRadius: BorderRadius.circular(24),
      border: Border.all(color: const Color(0xFFE7E8EA)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _row(
          '성격 유형',
          Text(
            partner.type,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
          ),
        ),
        _row(
          '특징',
          Text(
            partner.description,
            style: const TextStyle(fontSize: 13, height: 1.5, color: _muted),
          ),
        ),
        _row(
          '대표 키워드',
          Text(
            partner.keywords,
            style: const TextStyle(fontSize: 12, color: _muted),
          ),
        ),
        _row(
          '한마디 소개',
          Text(
            partner.quote,
            style: const TextStyle(
              fontSize: 14,
              height: 1.5,
              fontWeight: FontWeight.w600,
              color: _ink,
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFFF0F1F1),
            borderRadius: BorderRadius.circular(16),
          ),
          child: const Row(
            children: [
              Icon(Icons.info, size: 26, color: _muted),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  '모든 캐릭터는 학습할 수 있는 능력과\n획득하는 경험치(XP)가 동일합니다.',
                  style: TextStyle(fontSize: 12, height: 1.4, color: _muted),
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _PartnerCarousel extends CustomPainter {
  const _PartnerCarousel(this.image, this.position, this.time, this.still);
  final ui.Image? image;
  final double position, time;
  final bool still;
  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 360, size.height / 212);
    final background = Paint()..color = const Color(0xFFE9EAEA);
    canvas.drawOval(const Rect.fromLTWH(-65, -20, 170, 235), background);
    canvas.drawOval(const Rect.fromLTWH(285, -35, 160, 250), background);
    background.color = const Color(0xFFF0F1F1);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(100, 28, 160, 180),
        const Radius.circular(50),
      ),
      background,
    );
    const sources = [
      Rect.fromLTWH(35, 290, 425, 620),
      Rect.fromLTWH(467, 185, 580, 725),
      Rect.fromLTWH(1055, 320, 475, 590),
    ];
    final figures = List.generate(3, (i) {
      final angle = (i - position) * math.pi * 2 / 3;
      return (
        i: i,
        x: 180 + 138 * math.sin(angle),
        depth: (math.cos(angle) + 1) / 2,
      );
    })..sort((a, b) => a.depth.compareTo(b.depth));
    if (image != null) {
      for (final f in figures) {
        final h = 120 + 54 * f.depth;
        final w = h * sources[f.i].width / sources[f.i].height;
        final phase = time * math.pi * 2 + f.i * 1.8;
        final bob = still ? 0.0 : math.sin(phase) * 2.2;
        final bottom = 204 - 5 * f.depth + bob;
        canvas.save();
        canvas.translate(f.x, bottom);
        canvas.rotate(still ? 0 : math.sin(phase) * .014);
        canvas.drawImageRect(
          image!,
          sources[f.i],
          Rect.fromLTWH(-w / 2, -h, w, h),
          Paint()..filterQuality = FilterQuality.high,
        );
        canvas.restore();
      }
    }
    // Selection badge remains above the front character as the ring rotates.
    canvas.drawCircle(const Offset(180, 13), 13, Paint()..color = _ink);
    canvas.drawPath(
      Path()
        ..moveTo(174, 13)
        ..lineTo(178, 17)
        ..lineTo(186, 8),
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
    for (final (x, y, r, p) in [
      (35.0, 48.0, 8.0, 0.0),
      (315.0, 51.0, 9.0, 2.0),
      (115.0, 69.0, 6.0, 4.0),
      (235.0, 52.0, 6.0, 1.0),
    ]) {
      final glow = still ? .7 : (math.sin(time * math.pi * 4 + p) + 1) / 2;
      final radius = r * (.5 + glow * .5);
      final center = Offset(x, y);
      canvas.drawCircle(
        center,
        r * 2,
        Paint()
          ..shader = ui.Gradient.radial(center, r * 2, [
            Colors.white.withValues(alpha: glow),
            Colors.white.withValues(alpha: 0),
          ]),
      );
      final ray = Paint()
        ..color = _ink.withValues(alpha: .15 + glow * .7)
        ..strokeWidth = 1.2
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(
        center - Offset(radius, 0),
        center + Offset(radius, 0),
        ray,
      );
      canvas.drawLine(
        center - Offset(0, radius),
        center + Offset(0, radius),
        ray,
      );
      canvas.drawCircle(center, 1.5, Paint()..color = Colors.white);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_PartnerCarousel old) =>
      old.image != image ||
      old.position != position ||
      old.time != time ||
      old.still != still;
}

import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

const _ink = Color(0xFF191D1A);
const _paper = Color(0xFFF8F8F8);
const _muted = Color(0xFF6B7079);

/// 360 × 780 reference including the device's real safe areas.
/// Callbacks are UI boundaries; this screen never calls authentication APIs.
class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key, this.onStart, this.onGoogle, this.onLogin});

  final VoidCallback? onStart;
  final VoidCallback? onGoogle;
  final VoidCallback? onLogin;

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen>
    with TickerProviderStateMixin {
  late final _entrance = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1700),
  );
  late final _ambient = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 4200),
  );
  ui.Image? _reference;
  ui.Image? _characters;
  bool? _reduceMotion;

  @override
  void initState() {
    super.initState();
    _load(
      'assets/welcome/design_reference.webp',
      (image) => _reference = image,
    );
    _load('assets/welcome/characters.webp', (image) => _characters = image);
  }

  Future<void> _load(String path, void Function(ui.Image) assign) async {
    final data = await rootBundle.load(path);
    final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
    final frame = await codec.getNextFrame();
    codec.dispose();
    if (!mounted) {
      frame.image.dispose();
      return;
    }
    setState(() => assign(frame.image));
    _syncMotion();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    if (_reduceMotion == reduceMotion) return;
    _reduceMotion = reduceMotion;
    _syncMotion();
  }

  void _syncMotion() {
    if (_reduceMotion == true) {
      _entrance.value = 1;
      _ambient.stop();
    } else if (_reference != null && _characters != null) {
      _entrance.forward();
      if (!_ambient.isAnimating) _ambient.repeat();
    }
  }

  @override
  void dispose() {
    _entrance.dispose();
    _ambient.dispose();
    _reference?.dispose();
    _characters?.dispose();
    super.dispose();
  }

  void _activate(VoidCallback? action) {
    if (action != null) {
      action();
      return;
    }
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(
          content: Text('프로토타입 화면입니다. 기능은 추후 연결됩니다.'),
          duration: Duration(seconds: 2),
        ),
      );
  }

  double _progress(double start, double end) =>
      ((_entrance.value - start) / (end - start)).clamp(0.0, 1.0);

  Widget _reveal(Widget child, double start, double end) {
    final t = _progress(start, end);
    return IgnorePointer(
      ignoring: t < 1,
      child: ExcludeSemantics(
        excluding: t < 1,
        child: Opacity(
          opacity: Curves.easeOut.transform(t),
          child: Transform.translate(
            offset: Offset(0, 18 * (1 - Curves.easeOutCubic.transform(t))),
            child: Transform.scale(
              scale: 0.95 + 0.05 * Curves.easeOutBack.transform(t),
              child: child,
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: _paper,
    body: SafeArea(
      child: LayoutBuilder(
        builder: (context, constraints) {
          // Keep touch targets full size on short phones; scroll only if needed.
          final width = math.min(constraints.maxWidth, 440.0);
          final height = math.max(constraints.maxHeight, 732.0);
          return Center(
            child: SizedBox(
              width: width,
              child: SingleChildScrollView(
                child: SizedBox(
                  height: height,
                  child: AnimatedBuilder(
                    animation: Listenable.merge([_entrance, _ambient]),
                    builder: (context, _) {
                      final sx = width / 360;
                      final sy = height / 732;
                      return Stack(
                        clipBehavior: Clip.hardEdge,
                        children: [
                          const Positioned.fill(
                            child: CustomPaint(painter: _Backdrop()),
                          ),
                          Positioned(
                            left: 80 * sx,
                            top: 49 * sy,
                            width: 200 * sx,
                            height: 96 * sy,
                            child: _reveal(
                              Semantics(
                                label: '매너스 MANNERS',
                                header: true,
                                child: CustomPaint(painter: _Logo(_reference)),
                              ),
                              0,
                              0.42,
                            ),
                          ),
                          Positioned(
                            top: 160 * sy,
                            left: 0,
                            right: 0,
                            child: _reveal(
                              const Text(
                                '작은 배려가 만드는\n더 좋은 일상',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 19,
                                  height: 1.4,
                                  fontWeight: FontWeight.w700,
                                  color: _ink,
                                ),
                              ),
                              0.07,
                              0.47,
                            ),
                          ),
                          Positioned(
                            top: 210 * sy,
                            left: 0,
                            right: 0,
                            height: 300 * sy,
                            child: _reveal(
                              ExcludeSemantics(
                                child: CustomPaint(
                                  painter: _Cast(
                                    _characters,
                                    _ambient.value,
                                    _reduceMotion ?? false,
                                  ),
                                ),
                              ),
                              0.03,
                              0.5,
                            ),
                          ),
                          Positioned(
                            left: 0,
                            right: 0,
                            top: 452 * sy,
                            height: 70 * sy,
                            child: CustomPaint(painter: _Foreground()),
                          ),
                          Positioned(
                            bottom: 0,
                            left: 20 * sx,
                            right: 20 * sx,
                            child: _reveal(
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  WelcomeButton(
                                    label: '시작하기',
                                    primary: true,
                                    onPressed: () => _activate(widget.onStart),
                                  ),
                                  const SizedBox(height: 10),
                                  const Row(
                                    children: [
                                      Expanded(
                                        child: Divider(
                                          color: Color(0xFFE0E2E4),
                                        ),
                                      ),
                                      Padding(
                                        padding: EdgeInsets.symmetric(
                                          horizontal: 12,
                                        ),
                                        child: Text(
                                          '또는',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: _muted,
                                          ),
                                        ),
                                      ),
                                      Expanded(
                                        child: Divider(
                                          color: Color(0xFFE0E2E4),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 10),
                                  WelcomeButton(
                                    label: '구글로 계속하기',
                                    icon: const CustomPaint(
                                      size: Size(23, 23),
                                      painter: _GoogleMark(),
                                    ),
                                    onPressed: () => _activate(widget.onGoogle),
                                  ),
                                  Center(
                                    child: TextButton(
                                      style: TextButton.styleFrom(
                                        foregroundColor: _muted,
                                        minimumSize: const Size(48, 48),
                                      ),
                                      onPressed: () =>
                                          _activate(widget.onLogin),
                                      child: const Text.rich(
                                        TextSpan(
                                          children: [
                                            TextSpan(
                                              text: '이미 계정이 있으신가요?  ',
                                              style: TextStyle(
                                                decoration:
                                                    TextDecoration.underline,
                                              ),
                                            ),
                                            TextSpan(
                                              text: '로그인',
                                              style: TextStyle(
                                                color: _ink,
                                                fontWeight: FontWeight.w700,
                                                decoration:
                                                    TextDecoration.underline,
                                              ),
                                            ),
                                          ],
                                        ),
                                        style: TextStyle(fontSize: 13),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              0.53,
                              0.94,
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ),
            ),
          );
        },
      ),
    ),
  );
}

/// Shared pill button with an optional provider mark and a centered label.
class WelcomeButton extends StatelessWidget {
  const WelcomeButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.primary = false,
  });
  final String label;
  final VoidCallback onPressed;
  final Widget? icon;
  final bool primary;

  @override
  Widget build(BuildContext context) => Material(
    color: primary ? _ink : Colors.white,
    shape: StadiumBorder(
      side: BorderSide(color: primary ? _ink : const Color(0xFFE1E3E6)),
    ),
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      onTap: onPressed,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 52),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null) ...[icon!, const SizedBox(width: 20)],
              Flexible(
                child: Text(
                  label,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: primary ? 18 : 15,
                    height: 1.3,
                    fontWeight: FontWeight.w700,
                    color: primary ? Colors.white : _ink,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _Logo extends CustomPainter {
  const _Logo(this.image);
  final ui.Image? image;
  @override
  void paint(Canvas canvas, Size size) {
    if (image == null) return;
    // Render only the supplied wordmark, retaining the approved lettering.
    canvas.drawImageRect(
      image!,
      const Rect.fromLTWH(89, 91, 171, 85),
      Offset.zero & size,
      Paint()..filterQuality = FilterQuality.high,
    );
  }

  @override
  bool shouldRepaint(_Logo oldDelegate) => image != oldDelegate.image;
}

class _Cast extends CustomPainter {
  const _Cast(this.image, this.time, this.still);
  final ui.Image? image;
  final double time;
  final bool still;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 360, size.height / 300);
    if (image != null) {
      // Independent sprites let each character breathe at its own rhythm.
      const boxes = [
        Rect.fromLTWH(-4, 100, 134, 196),
        Rect.fromLTWH(88, 28, 200, 250),
        Rect.fromLTWH(245, 118, 122, 152),
      ];
      const sources = [
        Rect.fromLTWH(35, 290, 425, 620),
        Rect.fromLTWH(467, 185, 580, 725),
        Rect.fromLTWH(1055, 320, 475, 590),
      ];
      for (final index in [0, 2, 1]) {
        final phase = time * math.pi * 2 + index * 1.9;
        final bob = still ? 0.0 : math.sin(phase) * 2.4;
        canvas.save();
        final box = boxes[index];
        canvas.translate(box.center.dx, box.bottom + bob);
        canvas.rotate(still ? 0 : math.sin(phase) * 0.012);
        canvas.translate(-box.center.dx, -box.bottom);
        canvas.drawImageRect(
          image!,
          sources[index],
          box,
          Paint()..filterQuality = FilterQuality.high,
        );
        canvas.restore();
      }
    }
    for (final (x, y, radius, phase) in [
      (45.0, 76.0, 9.0, 0.0),
      (309.0, 43.0, 12.0, 2.1),
      (285.0, 94.0, 6.0, 4.0),
    ]) {
      final pulse = still
          ? 0.65
          : math
                .pow((math.sin(time * math.pi * 4 + phase) + 1) / 2, 2)
                .toDouble();
      final r = radius * (0.55 + pulse * 0.65);
      final center = Offset(x, y);
      canvas.drawCircle(
        center,
        r * 2.6,
        Paint()
          ..shader = ui.Gradient.radial(center, r * 2.6, [
            Colors.white.withValues(alpha: pulse * 0.9),
            Colors.white.withValues(alpha: 0),
          ]),
      );
      final paint = Paint()
        ..color = _ink.withValues(alpha: 0.12 + pulse * 0.78)
        ..strokeWidth = 1.1
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(center - Offset(r, 0), center + Offset(r, 0), paint);
      canvas.drawLine(center - Offset(0, r), center + Offset(0, r), paint);
      canvas.drawCircle(center, 1.7 + pulse, Paint()..color = Colors.white);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_Cast oldDelegate) =>
      image != oldDelegate.image ||
      time != oldDelegate.time ||
      still != oldDelegate.still;
}

class _Backdrop extends CustomPainter {
  const _Backdrop();
  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = ui.Gradient.linear(Offset.zero, Offset(0, size.height), [
          Colors.white,
          _paper,
        ]),
    );
    final p = Paint()..color = const Color(0xFFECEDED);
    canvas.drawOval(
      Rect.fromLTWH(
        -size.width * 0.53,
        size.height * 0.20,
        size.width * 0.79,
        size.height * 0.48,
      ),
      p,
    );
    canvas.drawOval(
      Rect.fromLTWH(
        size.width * 0.78,
        size.height * 0.23,
        size.width * 0.67,
        size.height * 0.50,
      ),
      p,
    );
    p.color = const Color(0xFFE6E7E7);
    canvas.drawOval(
      Rect.fromLTWH(
        -size.width * 0.22,
        size.height * 0.37,
        size.width * 0.85,
        size.height * 0.32,
      ),
      p,
    );
    canvas.drawOval(
      Rect.fromLTWH(
        size.width * 0.52,
        size.height * 0.33,
        size.width * 0.93,
        size.height * 0.38,
      ),
      p,
    );
  }

  @override
  bool shouldRepaint(_Backdrop oldDelegate) => false;
}

class _Foreground extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(0, size.height * 0.4)
      ..quadraticBezierTo(
        size.width * 0.5,
        -size.height * 0.18,
        size.width,
        size.height * 0.4,
      )
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(path, Paint()..color = _paper);
  }

  @override
  bool shouldRepaint(_Foreground oldDelegate) => false;
}

class _GoogleMark extends CustomPainter {
  const _GoogleMark();
  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 24, size.height / 24);
    final p = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4.5;
    const circle = Rect.fromLTWH(3.5, 3.5, 17, 17);
    for (final (color, start, sweep) in [
      (Color(0xFF4285F4), -0.05, 0.84),
      (Color(0xFF34A853), 0.79, 1.56),
      (Color(0xFFFBBC05), 2.35, 0.94),
      (Color(0xFFEA4335), 3.29, 2.18),
    ]) {
      canvas.drawArc(circle, start, sweep, false, p..color = color);
    }
    canvas.drawLine(
      const Offset(12, 12),
      const Offset(22, 12),
      p..color = const Color(0xFF4285F4),
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_GoogleMark oldDelegate) => false;
}

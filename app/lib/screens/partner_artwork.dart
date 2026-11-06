import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'partner_selection_screen.dart';

/// Shared decorative animation. Honors the operating system's reduced-motion setting.
class AmbientMotion extends StatefulWidget {
  const AmbientMotion({super.key, required this.builder});
  final Widget Function(BuildContext, double) builder;
  @override
  State<AmbientMotion> createState() => _AmbientMotionState();
}

class _AmbientMotionState extends State<AmbientMotion>
    with SingleTickerProviderStateMixin {
  late final _clock = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 5),
  );
  bool? _reduced;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduced = MediaQuery.disableAnimationsOf(context);
    if (reduced == _reduced) return;
    _reduced = reduced;
    if (reduced) {
      _clock.stop();
      _clock.value = .25;
    } else {
      _clock.repeat();
    }
  }

  @override
  void dispose() {
    _clock.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _clock,
    builder: (context, _) => widget.builder(context, _clock.value),
  );
}

class PartnerArtwork extends StatelessWidget {
  const PartnerArtwork({super.key, required this.partner, this.stage = 3});
  final MannerPartner partner;
  final int stage;
  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: AmbientMotion(
      builder: (context, t) {
        final reduced = MediaQuery.disableAnimationsOf(context);
        final wave = reduced ? 0.0 : math.sin(t * math.pi * 2 + stage * .8);
        return Stack(
          fit: StackFit.expand,
          children: [
            CustomPaint(painter: _Sparkles(t)),
            Transform.translate(
              offset: Offset(0, wave * 2.2),
              child: Transform.rotate(
                angle: wave * .014,
                child: FittedBox(
                  fit: BoxFit.contain,
                  child: SizedBox(
                    width: 512,
                    height: 512,
                    child: ClipRect(
                      child: OverflowBox(
                        alignment: Alignment.topLeft,
                        minWidth: 1536,
                        maxWidth: 1536,
                        minHeight: 2048,
                        maxHeight: 2048,
                        child: Transform.translate(
                          offset: Offset(
                            -partner.index * 512.0,
                            -stage * 512.0,
                          ),
                          child: Image.asset(
                            'assets/welcome/growth_stages.png',
                            width: 1536,
                            height: 2048,
                            fit: BoxFit.fill,
                            filterQuality: FilterQuality.high,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    ),
  );
}

class _Sparkles extends CustomPainter {
  const _Sparkles(this.t);
  final double t;
  @override
  void paint(Canvas canvas, Size size) {
    for (final (x, y, phase) in [
      (.12, .32, 0.0),
      (.83, .24, 2.0),
      (.87, .68, 4.0),
    ]) {
      final glow = (math.sin(t * math.pi * 4 + phase) + 1) / 2;
      final c = Offset(size.width * x, size.height * y);
      final radius = 2 + glow * 3;
      canvas.drawCircle(
        c,
        radius * 2,
        Paint()
          ..shader = RadialGradient(
            colors: [
              Colors.white.withValues(alpha: glow),
              Colors.white.withValues(alpha: 0),
            ],
          ).createShader(Rect.fromCircle(center: c, radius: radius * 2)),
      );
      final p = Paint()
        ..color = Colors.black.withValues(alpha: .2 + glow * .6)
        ..strokeWidth = 1.2;
      canvas.drawLine(c - Offset(radius, 0), c + Offset(radius, 0), p);
      canvas.drawLine(c - Offset(0, radius), c + Offset(0, radius), p);
    }
  }

  @override
  bool shouldRepaint(_Sparkles old) => t != old.t;
}

class PrismaticButton extends StatelessWidget {
  const PrismaticButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.complete = false,
  });
  final String label;
  final VoidCallback onPressed;
  final bool complete;
  @override
  Widget build(BuildContext context) => AmbientMotion(
    builder: (context, t) => Container(
      padding: const EdgeInsets.all(1.5),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30),
        gradient: SweepGradient(
          transform: GradientRotation(t * math.pi * 2),
          colors: [
            const Color(0xFFB8D8FF),
            const Color(0xFFE4C7FF),
            const Color(0xFFFFD5C4),
            const Color(0xFFCFF2D8),
            const Color(0xFFB8D8FF),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: Color.lerp(
              const Color(0xFFBBCAFF),
              const Color(0xFFE9C4FF),
              t,
            )!.withValues(alpha: complete ? .55 : .28),
            blurRadius: complete ? 14 : 8,
          ),
        ],
      ),
      child: Material(
        color: const Color(0xFF191D1A),
        borderRadius: BorderRadius.circular(30),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onPressed,
          child: CustomPaint(
            painter: _ButtonSheen(t),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Flexible(
                    child: Text(
                      label,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Icon(
                    complete ? Icons.check : Icons.chevron_right,
                    color: Colors.white,
                    size: 18,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

class _ButtonSheen extends CustomPainter {
  const _ButtonSheen(this.t);
  final double t;
  @override
  void paint(Canvas canvas, Size size) {
    final x = -size.width + t * size.width * 3;
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = LinearGradient(
          colors: [
            Colors.transparent,
            const Color(0xFFBFD6FF).withValues(alpha: .16),
            const Color(0xFFF6D0FF).withValues(alpha: .2),
            Colors.transparent,
          ],
        ).createShader(Rect.fromLTWH(x, 0, size.width * .7, size.height)),
    );
  }

  @override
  bool shouldRepaint(_ButtonSheen old) => t != old.t;
}

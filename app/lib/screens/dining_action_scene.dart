import 'package:flutter/material.dart';

class DiningSceneArtwork extends StatelessWidget {
  const DiningSceneArtwork({super.key, required this.panel});
  final int panel;
  @override
  Widget build(BuildContext context) => FittedBox(
    fit: BoxFit.contain,
    child: SizedBox(
      width: 512,
      height: 512,
      child: ClipRect(
        child: OverflowBox(
          alignment: Alignment.topLeft,
          minWidth: 1536,
          maxWidth: 1536,
          minHeight: 1024,
          maxHeight: 1024,
          child: Transform.translate(
            offset: Offset(-(panel % 3) * 512.0, -(panel ~/ 3) * 512.0),
            child: Image.asset(
              'assets/dining/action_scenes.webp',
              width: 1536,
              height: 1024,
              fit: BoxFit.contain,
            ),
          ),
        ),
      ),
    ),
  );
}

class DiningActionScene extends StatefulWidget {
  const DiningActionScene({
    super.key,
    required this.number,
    required this.answered,
    required this.success,
    required this.onAnswer,
  });
  final int number;
  final bool answered, success;
  final ValueChanged<bool> onAnswer;
  @override
  State<DiningActionScene> createState() => _DiningActionSceneState();
}

class _DiningActionSceneState extends State<DiningActionScene> {
  Offset position = const Offset(.2, .72);
  Offset? touch;
  bool correct = false, moving = false;
  int get panel => widget.number == 3
      ? 0
      : widget.number == 5
      ? 1
      : 2;
  @override
  Widget build(BuildContext context) => AspectRatio(
    key: const ValueKey('dining-action'),
    aspectRatio: 1,
    child: LayoutBuilder(
      builder: (context, c) {
        final w = c.maxWidth, h = c.maxHeight;
        return ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Stack(
            children: [
              Positioned.fill(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTapUp: widget.number != 7 || widget.answered
                      ? null
                      : (d) {
                          final p = Offset(
                            d.localPosition.dx / w,
                            d.localPosition.dy / h,
                          );
                          final ok = const Rect.fromLTWH(
                            .63,
                            .55,
                            .35,
                            .43,
                          ).contains(p);
                          setState(() {
                            touch = p;
                            correct = ok;
                          });
                          widget.onAnswer(ok);
                        },
                  child: DiningSceneArtwork(
                    panel: widget.success ? panel + 3 : panel,
                  ),
                ),
              ),
              if (widget.number != 7 && !widget.answered)
                AnimatedPositioned(
                  duration: Duration(milliseconds: moving ? 0 : 250),
                  left: position.dx * w,
                  top: position.dy * h,
                  width: w * .2,
                  height: h * .2,
                  child: GestureDetector(
                    key: const ValueKey('dining-drag-object'),
                    onLongPressStart: (_) => setState(() => moving = true),
                    onLongPressMoveUpdate: (d) => setState(
                      () => position = Offset(
                        (.2 + d.offsetFromOrigin.dx / w).clamp(0, .8),
                        (.72 + d.offsetFromOrigin.dy / h).clamp(0, .8),
                      ),
                    ),
                    onLongPressEnd: (_) {
                      final target = widget.number == 3
                          ? const Rect.fromLTWH(.6, .25, .38, .45)
                          : const Rect.fromLTWH(.6, .3, .38, .48);
                      final ok = target.contains(
                        Offset(position.dx + .1, position.dy + .1),
                      );
                      setState(() {
                        moving = false;
                        if (!ok) position = const Offset(.2, .72);
                      });
                      widget.onAnswer(ok);
                    },
                    child: CustomPaint(
                      painter: _UtensilPainter(bottle: widget.number == 5),
                    ),
                  ),
                ),
              if (touch != null)
                Positioned(
                  left: (touch!.dx * w - 18).clamp(0, w - 36),
                  top: (touch!.dy * h - 18).clamp(0, h - 36),
                  child: IgnorePointer(
                    child: CircleAvatar(
                      radius: 18,
                      backgroundColor: correct
                          ? const Color(0xFF31815A)
                          : const Color(0xFFD84C50),
                      child: Text(
                        correct ? 'O' : 'X',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    ),
  );
}

class _UtensilPainter extends CustomPainter {
  const _UtensilPainter({required this.bottle});
  final bool bottle;
  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 64, size.height / 64);
    final outline = Paint()
      ..color = const Color(0xFF222222)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;
    final fill = Paint()..color = const Color(0xFFE9ECEB);
    if (bottle) {
      final body = RRect.fromRectAndRadius(
        const Rect.fromLTWH(17, 16, 30, 44),
        const Radius.circular(6),
      );
      canvas.drawRRect(body, fill);
      canvas.drawRRect(body, outline);
      canvas.drawRect(const Rect.fromLTWH(24, 5, 16, 11), fill);
      canvas.drawRect(const Rect.fromLTWH(24, 5, 16, 11), outline);
      canvas.drawRect(
        const Rect.fromLTWH(20, 35, 24, 18),
        Paint()..color = const Color(0xFFADBBB9),
      );
    } else {
      final path = Path()
        ..moveTo(12, 50)
        ..quadraticBezierTo(4, 34, 18, 12)
        ..lineTo(24, 14)
        ..quadraticBezierTo(14, 32, 18, 41)
        ..lineTo(48, 18)
        ..lineTo(53, 24)
        ..lineTo(18, 54)
        ..close();
      canvas.drawPath(path, fill);
      canvas.drawPath(path, outline);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_UtensilPainter old) => old.bottle != bottle;
}

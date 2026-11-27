import 'package:flutter/material.dart';

/// A temporary group result, clipped to the visible card-list area.
/// The caller owns grading and input locking; this widget has no reward effects.
class ResultFeedbackOverlay extends StatelessWidget {
  const ResultFeedbackOverlay({
    super.key,
    required this.correct,
    required this.animation,
    required this.bounds,
    this.reduceMotion = false,
  });
  static const duration = Duration(milliseconds: 1750);
  static const green = Color(0xFF2E7D32);
  static const red = Color(0xFFC62828);
  final bool correct, reduceMotion;
  final Animation<double> animation;
  final Rect bounds;

  @override
  Widget build(BuildContext context) => Positioned.fromRect(
    rect: bounds,
    child: IgnorePointer(
      child: ClipRect(
        child: Center(
          child: AnimatedBuilder(
            animation: animation,
            builder: (context, _) {
              final ms = animation.value * duration.inMilliseconds;
              final opacity = reduceMotion
                  ? 1.0
                  : ms < 250
                  ? ms / 250
                  : ms < 1450
                  ? 1.0
                  : (1750 - ms) / 300;
              final scale = reduceMotion
                  ? 1.0
                  : ms < 250
                  ? .8 + .2 * Curves.easeOut.transform(ms / 250)
                  : 1.0;
              return Opacity(
                opacity: opacity.clamp(0, 1),
                child: Transform.scale(
                  scale: scale,
                  child: Container(
                    key: const Key('sequence-result-effect'),
                    width: 96,
                    height: 96,
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(color: Color(0x33000000), blurRadius: 12),
                      ],
                    ),
                    child: ResultFeedbackSymbol(
                      correct: correct,
                      key: Key(
                        correct
                            ? 'sequence-overlay-correct'
                            : 'sequence-overlay-wrong',
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    ),
  );
}

/// Shape, color and spoken label all express the result (not color alone).
class ResultFeedbackSymbol extends StatelessWidget {
  const ResultFeedbackSymbol({
    super.key,
    required this.correct,
    this.size = 96,
  });
  final bool correct;
  final double size;
  @override
  Widget build(BuildContext context) => Semantics(
    label: correct ? '정답 O' : '오답 X',
    child: SizedBox(
      width: size,
      height: size,
      child: CustomPaint(painter: _ResultPainter(correct)),
    ),
  );
}

class _ResultPainter extends CustomPainter {
  const _ResultPainter(this.correct);
  final bool correct;
  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 96, size.height / 96);
    final p = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    void shape() {
      if (correct) {
        canvas.drawCircle(const Offset(48, 48), 38.5, p);
      } else {
        canvas.drawLine(const Offset(10, 10), const Offset(86, 86), p);
        canvas.drawLine(const Offset(86, 10), const Offset(10, 86), p);
      }
    }

    p
      ..color = Colors.white
      ..strokeWidth = 18;
    shape();
    p
      ..color = correct
          ? ResultFeedbackOverlay.green
          : ResultFeedbackOverlay.red
      ..strokeWidth = 12;
    shape();
    canvas.restore();
  }

  @override
  bool shouldRepaint(_ResultPainter oldDelegate) =>
      correct != oldDelegate.correct;
}

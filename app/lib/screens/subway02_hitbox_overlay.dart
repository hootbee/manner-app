import 'package:flutter/material.dart';

/// Debug-only caller; geometry comes from exactly the same rules as judging.
class Subway02HitboxPainter extends CustomPainter {
  const Subway02HitboxPainter({required this.rules, required this.anchor});
  final Map<String, dynamic> rules;
  final Offset anchor;
  @override
  void paint(Canvas canvas, Size size) {
    final j = rules['judgement'];
    void box(List p, Color color, String label) {
      final rect = Rect.fromLTRB(
        (p[0] as num).toDouble(),
        (p[1] as num).toDouble(),
        (p[2] as num).toDouble(),
        (p[3] as num).toDouble(),
      );
      canvas.drawRect(rect, Paint()..color = color.withValues(alpha: .12));
      canvas.drawRect(
        rect.deflate(2),
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 4,
      );
      final text = TextPainter(
        text: TextSpan(
          text: label,
          style: TextStyle(
            fontFamily: 'Pretendard',
            fontSize: 25,
            color: color,
            fontWeight: FontWeight.w700,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      text.paint(canvas, rect.topLeft + const Offset(8, 8));
    }

    box(j['drag_bounds_px'], Colors.blue, 'drag_bounds');
    for (final zone in j['correct_zones']) {
      box(zone['rect_px'], Colors.green, zone['id']);
    }
    for (final zone in j['wrong_zones']) {
      box(zone['rect_px'], Colors.red, zone['id']);
    }
    canvas.drawCircle(anchor, 10, Paint()..color = Colors.orange);
    canvas.drawLine(
      anchor - const Offset(18, 0),
      anchor + const Offset(18, 0),
      Paint()
        ..color = Colors.black
        ..strokeWidth = 3,
    );
    canvas.drawLine(
      anchor - const Offset(0, 18),
      anchor + const Offset(0, 18),
      Paint()
        ..color = Colors.black
        ..strokeWidth = 3,
    );
  }

  @override
  bool shouldRepaint(Subway02HitboxPainter oldDelegate) =>
      oldDelegate.rules != rules || oldDelegate.anchor != anchor;
}

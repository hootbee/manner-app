import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'wardrobe_catalog.dart';

/// The same vector shapes are used on product cards and on the character/room.
class WardrobeItemArt extends StatelessWidget {
  const WardrobeItemArt({super.key, required this.id});
  final String id;
  @override
  Widget build(BuildContext context) =>
      CustomPaint(painter: WardrobeItemPainter(id), size: const Size(100, 100));
}

class WardrobeItemPainter extends CustomPainter {
  const WardrobeItemPainter(this.id);
  final String id;
  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    final scale = math.min(size.width, size.height) / 100;
    canvas.translate(
      (size.width - 100 * scale) / 2,
      (size.height - 100 * scale) / 2,
    );
    canvas.scale(scale);
    if (id.endsWith('-none')) {
      canvas.drawCircle(
        const Offset(50, 50),
        25,
        Paint()
          ..color = const Color(0xFFB0B4B1)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3,
      );
      canvas.drawLine(
        const Offset(33, 67),
        const Offset(67, 33),
        Paint()
          ..color = const Color(0xFFB0B4B1)
          ..strokeWidth = 3,
      );
    } else {
      switch (wardrobeCategory(id)) {
        case 0:
          _hat(canvas);
          break;
        case 1:
          _garment(canvas);
          break;
        case 2:
          _accessory(canvas);
          break;
        case 3:
          _furniture(canvas);
          break;
        case 4:
          _prop(canvas);
          break;
      }
    }
    canvas.restore();
  }

  static const ink = Color(0xFF202320),
      paper = Color(0xFFFAFAF7),
      gray = Color(0xFFB7BAB5);
  void shape(Canvas c, Path p, [Color color = paper]) {
    c.drawPath(p, Paint()..color = color);
    c.drawPath(
      p,
      Paint()
        ..color = ink
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.2
        ..strokeJoin = StrokeJoin.round
        ..strokeCap = StrokeCap.round,
    );
  }

  void line(
    Canvas c,
    Offset a,
    Offset b, [
    Color color = ink,
    double width = 2,
  ]) => c.drawLine(
    a,
    b,
    Paint()
      ..color = color
      ..strokeWidth = width
      ..strokeCap = StrokeCap.round,
  );
  void box(Canvas c, Rect r, [Color color = paper, double radius = 4]) {
    final p = Path()
      ..addRRect(RRect.fromRectAndRadius(r, Radius.circular(radius)));
    shape(c, p, color);
  }

  void oval(Canvas c, Rect r, [Color color = paper]) =>
      shape(c, Path()..addOval(r), color);
  void text(
    Canvas c,
    String value,
    Offset p,
    double fontSize, {
    Color color = ink,
  }) {
    final t = TextPainter(
      text: TextSpan(
        text: value,
        style: TextStyle(
          fontSize: fontSize,
          color: color,
          fontWeight: FontWeight.w800,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    t.paint(c, p);
  }

  void _hat(Canvas c) {
    if (id == 'hat-party') {
      shape(
        c,
        Path()
          ..moveTo(50, 12)
          ..lineTo(79, 78)
          ..quadraticBezierTo(50, 91, 21, 78)
          ..close(),
        gray,
      );
      for (final p in [
        const Offset(47, 36),
        const Offset(37, 60),
        const Offset(59, 62),
      ]) {
        c.drawCircle(p, 4, Paint()..color = paper);
      }
      oval(c, const Rect.fromLTWH(44, 6, 12, 12));
      return;
    }
    if (id == 'hat-beret') {
      shape(
        c,
        Path()
          ..moveTo(14, 61)
          ..cubicTo(7, 29, 68, 18, 83, 43)
          ..quadraticBezierTo(98, 67, 68, 70)
          ..lineTo(24, 74)
          ..close(),
        ink,
      );
      line(c, const Offset(60, 30), const Offset(66, 17), ink, 5);
      return;
    }
    if (id == 'hat-beanie') {
      shape(
        c,
        Path()
          ..moveTo(17, 63)
          ..cubicTo(16, 9, 85, 9, 84, 63)
          ..close(),
        gray,
      );
      for (double x = 28; x < 80; x += 12) {
        line(c, Offset(x, 32), Offset(x - 3, 65), const Color(0xFF747A74), 1);
      }
      box(c, const Rect.fromLTWH(13, 61, 75, 19), gray);
      box(c, const Rect.fromLTWH(65, 64, 13, 11));
      return;
    }
    oval(
      c,
      const Rect.fromLTWH(6, 64, 88, 20),
      id == 'hat-ribbon' ? paper : ink,
    );
    if (id == 'hat-cap') {
      shape(
        c,
        Path()
          ..moveTo(20, 65)
          ..cubicTo(17, 14, 80, 17, 83, 64)
          ..close(),
      );
      shape(
        c,
        Path()
          ..moveTo(65, 25)
          ..quadraticBezierTo(84, 32, 83, 64)
          ..lineTo(66, 62)
          ..close(),
        ink,
      );
      text(c, 'M', const Offset(36, 37), 19);
      return;
    }
    if (id == 'hat-detective') {
      shape(
        c,
        Path()
          ..moveTo(13, 65)
          ..cubicTo(20, 15, 80, 15, 88, 65)
          ..close(),
        gray,
      );
      for (double x = 25; x < 90; x += 13) {
        line(c, Offset(x, 34), Offset(x - 8, 68), paper, 1);
      }
      for (double y = 41; y < 67; y += 11) {
        line(c, Offset(19, y), Offset(82, y), paper, 1);
      }
    } else {
      shape(
        c,
        Path()
          ..moveTo(26, 68)
          ..lineTo(24, id == 'hat-top' ? 20 : 37)
          ..quadraticBezierTo(
            49,
            id == 'hat-top' ? 12 : 24,
            76,
            id == 'hat-top' ? 20 : 37,
          )
          ..lineTo(73, 68)
          ..close(),
        id == 'hat-ribbon' ? paper : ink,
      );
      box(
        c,
        const Rect.fromLTWH(25, 56, 49, 9),
        id == 'hat-ribbon' ? ink : paper,
        1,
      );
      if (id == 'hat-ribbon') _bow(c, const Offset(72, 67));
    }
  }

  void _garment(Canvas c) {
    final light = ['hoodie', 'shirt', 'vest'].contains(id);
    final color = light
        ? paper
        : ['trench', 'duffle', 'bear'].contains(id)
        ? gray
        : const Color(0xFF393C39);
    final p = Path()
      ..moveTo(33, 19)
      ..lineTo(22, 25)
      ..lineTo(6, 65)
      ..lineTo(22, 72)
      ..lineTo(28, 52)
      ..lineTo(25, 88)
      ..quadraticBezierTo(50, 94, 75, 88)
      ..lineTo(72, 52)
      ..lineTo(78, 72)
      ..lineTo(94, 65)
      ..lineTo(78, 25)
      ..lineTo(67, 19)
      ..close();
    shape(c, p, color);
    if (id == 'hoodie' || id == 'bear') {
      shape(
        c,
        Path()
          ..moveTo(33, 19)
          ..quadraticBezierTo(50, 4, 67, 19)
          ..quadraticBezierTo(50, 49, 33, 19)
          ..close(),
        id == 'bear' ? gray : paper,
      );
      line(c, const Offset(44, 34), const Offset(44, 56));
      line(c, const Offset(56, 34), const Offset(56, 56));
      box(c, const Rect.fromLTWH(35, 65, 30, 13), color);
      if (id == 'bear') {
        oval(c, const Rect.fromLTWH(38, 48, 24, 26));
        oval(c, const Rect.fromLTWH(35, 44, 10, 10));
        oval(c, const Rect.fromLTWH(55, 44, 10, 10));
        c.drawCircle(const Offset(45, 58), 1.7, Paint());
        c.drawCircle(const Offset(55, 58), 1.7, Paint());
        oval(c, const Rect.fromLTWH(47, 61, 6, 4), ink);
      }
    } else if (id == 'duffle') {
      line(c, const Offset(50, 26), const Offset(50, 89));
      for (double y = 42; y < 77; y += 15) {
        box(c, Rect.fromLTWH(42, y, 17, 4), ink, 1);
      }
      shape(
        c,
        Path()
          ..moveTo(32, 20)
          ..quadraticBezierTo(50, 7, 68, 20)
          ..lineTo(59, 34)
          ..lineTo(41, 34)
          ..close(),
        gray,
      );
    } else {
      line(c, const Offset(50, 31), const Offset(50, 89));
      shape(
        c,
        Path()
          ..moveTo(33, 19)
          ..lineTo(41, 48)
          ..lineTo(50, 31)
          ..lineTo(59, 48)
          ..lineTo(67, 19)
          ..lineTo(50, 27)
          ..close(),
        paper,
      );
      if (id != 'shirt' && id != 'varsity') {
        shape(
          c,
          Path()
            ..moveTo(46, 28)
            ..lineTo(54, 28)
            ..lineTo(52, 36)
            ..lineTo(56, 48)
            ..lineTo(50, 55)
            ..lineTo(44, 48)
            ..lineTo(48, 36)
            ..close(),
          ink,
        );
      }
      if (id == 'varsity') {
        line(c, const Offset(23, 34), const Offset(14, 62), paper, 9);
        line(c, const Offset(77, 34), const Offset(86, 62), paper, 9);
      }
      if (id == 'trench') {
        box(c, const Rect.fromLTWH(27, 64, 46, 6), gray, 1);
        box(c, const Rect.fromLTWH(46, 62, 9, 10), ink, 1);
      }
      if (id == 'school') {
        shape(
          c,
          Path()
            ..moveTo(64, 45)
            ..lineTo(73, 45)
            ..lineTo(72, 55)
            ..quadraticBezierTo(68, 61, 64, 55)
            ..close(),
          gray,
        );
      }
      if (id == 'vest') {
        shape(
          c,
          Path()
            ..moveTo(34, 25)
            ..lineTo(50, 49)
            ..lineTo(66, 25)
            ..lineTo(73, 86)
            ..lineTo(50, 90)
            ..lineTo(27, 86)
            ..close(),
          const Color(0xFF414540),
        );
        line(c, const Offset(50, 49), const Offset(50, 88));
      }
      for (double y = 57; y < 85; y += 12) {
        c.drawCircle(
          Offset(54, y),
          1.5,
          Paint()..color = id == 'shirt' ? ink : paper,
        );
      }
    }
  }

  void _bow(Canvas c, Offset p) {
    shape(
      c,
      Path()
        ..moveTo(p.dx, p.dy)
        ..lineTo(p.dx - 18, p.dy - 12)
        ..quadraticBezierTo(p.dx - 24, p.dy, p.dx - 18, p.dy + 12)
        ..close(),
      ink,
    );
    shape(
      c,
      Path()
        ..moveTo(p.dx, p.dy)
        ..lineTo(p.dx + 18, p.dy - 12)
        ..quadraticBezierTo(p.dx + 24, p.dy, p.dx + 18, p.dy + 12)
        ..close(),
      ink,
    );
    box(
      c,
      Rect.fromCenter(center: p, width: 10, height: 12),
      const Color(0xFF525852),
    );
  }

  void _accessory(Canvas c) {
    switch (id) {
      case 'acc-glasses':
        for (final x in [12.0, 55.0]) {
          box(c, Rect.fromLTWH(x, 36, 33, 24), ink, 8);
          line(c, Offset(x + 7, 54), Offset(x + 18, 39), gray, 3);
        }
        line(c, const Offset(45, 40), const Offset(55, 40), ink, 4);
        break;
      case 'acc-bow':
        _bow(c, const Offset(50, 50));
        break;
      case 'acc-backpack':
        box(c, const Rect.fromLTWH(40, 13, 22, 20), ink);
        box(c, const Rect.fromLTWH(22, 25, 57, 65), gray, 15);
        box(c, const Rect.fromLTWH(32, 57, 38, 25));
        box(c, const Rect.fromLTWH(31, 40, 39, 9), paper, 1);
        break;
      case 'acc-watch':
        box(c, const Rect.fromLTWH(40, 7, 22, 86), ink);
        oval(c, const Rect.fromLTWH(23, 23, 55, 55));
        for (var i = 0; i < 12; i++) {
          final a = i * math.pi / 6;
          line(
            c,
            Offset(50 + 20 * math.sin(a), 50 + 20 * math.cos(a)),
            Offset(50 + 23 * math.sin(a), 50 + 23 * math.cos(a)),
            ink,
            1.5,
          );
        }
        line(c, const Offset(50, 50), const Offset(50, 35));
        line(c, const Offset(50, 50), const Offset(62, 45));
        break;
      case 'acc-badges':
        oval(c, const Rect.fromLTWH(13, 30, 35, 35), ink);
        text(c, '★', const Offset(20, 30), 24, color: paper);
        shape(
          c,
          Path()
            ..moveTo(58, 25)
            ..lineTo(83, 25)
            ..lineTo(80, 57)
            ..lineTo(70, 65)
            ..lineTo(60, 57)
            ..close(),
        );
        text(c, 'M', const Offset(63, 32), 19);
        break;
      case 'acc-scarf':
        shape(
          c,
          Path()
            ..moveTo(30, 19)
            ..lineTo(73, 26)
            ..lineTo(65, 43)
            ..lineTo(57, 86)
            ..lineTo(37, 80)
            ..lineTo(44, 45)
            ..lineTo(27, 40)
            ..close(),
          gray,
        );
        for (double y = 38; y < 80; y += 15) {
          line(c, Offset(39, y), Offset(62, y + 5), paper, 6);
        }
        break;
      case 'acc-briefcase':
        box(c, const Rect.fromLTWH(38, 19, 25, 20), ink);
        box(c, const Rect.fromLTWH(15, 33, 70, 51), gray);
        line(c, const Offset(15, 50), const Offset(85, 50));
        box(c, const Rect.fromLTWH(45, 46, 11, 12));
        break;
      case 'acc-headphones':
        c.drawArc(
          const Rect.fromLTWH(14, 16, 72, 71),
          math.pi,
          math.pi,
          false,
          Paint()
            ..color = ink
            ..style = PaintingStyle.stroke
            ..strokeWidth = 8,
        );
        box(c, const Rect.fromLTWH(10, 47, 22, 39), gray, 10);
        box(c, const Rect.fromLTWH(68, 47, 22, 39), gray, 10);
        text(c, 'M', const Offset(71, 54), 18);
        break;
    }
  }

  void _furniture(Canvas c) {
    switch (id) {
      case 'furniture-rug':
        oval(c, const Rect.fromLTWH(5, 34, 90, 39), gray);
        oval(c, const Rect.fromLTWH(13, 39, 74, 29));
        oval(c, const Rect.fromLTWH(27, 45, 46, 17), const Color(0xFFD9DAD5));
        break;
      case 'furniture-chair':
        box(c, const Rect.fromLTWH(25, 16, 50, 22));
        for (final x in [32.0, 49.0, 66.0]) {
          line(c, Offset(x, 38), Offset(x, 56), ink, 3);
        }
        box(c, const Rect.fromLTWH(20, 54, 60, 13));
        for (final x in [29.0, 71.0]) {
          line(c, Offset(x, 66), Offset(x < 50 ? x - 8 : x + 8, 91), ink, 4);
        }
        break;
      case 'furniture-desk':
        box(c, const Rect.fromLTWH(10, 28, 80, 16));
        box(c, const Rect.fromLTWH(17, 45, 7, 46));
        box(c, const Rect.fromLTWH(60, 45, 24, 43));
        line(c, const Offset(60, 65), const Offset(84, 65));
        box(c, const Rect.fromLTWH(68, 53, 8, 2), ink);
        box(c, const Rect.fromLTWH(68, 74, 8, 2), ink);
        break;
      case 'furniture-lamp':
        oval(c, const Rect.fromLTWH(34, 85, 34, 6));
        line(c, const Offset(50, 31), const Offset(50, 86), ink, 4);
        shape(
          c,
          Path()
            ..moveTo(34, 15)
            ..lineTo(67, 15)
            ..lineTo(79, 42)
            ..quadraticBezierTo(50, 52, 21, 42)
            ..close(),
        );
        line(c, const Offset(66, 47), const Offset(66, 59));
        break;
      case 'furniture-sofa':
        box(c, const Rect.fromLTWH(18, 25, 65, 45), gray, 18);
        box(c, const Rect.fromLTWH(9, 46, 17, 32));
        box(c, const Rect.fromLTWH(75, 46, 17, 32));
        box(c, const Rect.fromLTWH(22, 60, 55, 19));
        box(c, const Rect.fromLTWH(58, 37, 20, 23));
        line(c, const Offset(21, 79), const Offset(21, 86), ink, 4);
        line(c, const Offset(79, 79), const Offset(79, 86), ink, 4);
        break;
      case 'furniture-plant':
        for (final (x, y) in [
          (30.0, 27.0),
          (63.0, 20.0),
          (68.0, 42.0),
          (28.0, 48.0),
        ]) {
          line(c, const Offset(50, 72), Offset(x, y));
          oval(
            c,
            Rect.fromCenter(center: Offset(x, y), width: 21, height: 14),
            gray,
          );
        }
        shape(
          c,
          Path()
            ..moveTo(32, 67)
            ..lineTo(70, 67)
            ..lineTo(65, 89)
            ..quadraticBezierTo(50, 96, 37, 89)
            ..close(),
        );
        break;
      case 'furniture-rack':
        line(c, const Offset(20, 17), const Offset(20, 83), ink, 4);
        line(c, const Offset(80, 17), const Offset(80, 83), ink, 4);
        line(c, const Offset(20, 20), const Offset(80, 20), ink, 4);
        shape(
          c,
          Path()
            ..moveTo(50, 28)
            ..lineTo(31, 46)
            ..lineTo(69, 46)
            ..close(),
        );
        oval(c, const Rect.fromLTWH(12, 82, 17, 8), gray);
        oval(c, const Rect.fromLTWH(72, 82, 17, 8), gray);
        break;
      case 'furniture-drawers':
        box(c, const Rect.fromLTWH(20, 20, 62, 64));
        for (double y = 40; y < 81; y += 20) {
          line(c, Offset(20, y), Offset(82, y));
        }
        for (double y = 30; y < 81; y += 20) {
          c.drawCircle(Offset(51, y), 2, Paint());
        }
        line(c, const Offset(29, 84), const Offset(29, 91), ink, 4);
        line(c, const Offset(73, 84), const Offset(73, 91), ink, 4);
        break;
    }
  }

  void _prop(Canvas c) {
    switch (id) {
      case 'prop-mug':
        oval(c, const Rect.fromLTWH(61, 36, 28, 33));
        box(c, const Rect.fromLTWH(20, 24, 49, 58), paper, 8);
        oval(c, const Rect.fromLTWH(20, 22, 49, 14), gray);
        text(c, '☺', const Offset(32, 43), 22);
        break;
      case 'prop-books':
        for (var i = 0; i < 3; i++) {
          box(
            c,
            Rect.fromLTWH(14 + i * 2, 26 + i * 19, 71, 16),
            i == 1 ? gray : paper,
            3,
          );
          line(
            c,
            Offset(21 + i * 2, 34 + i * 19),
            Offset(68, 34 + i * 19),
            gray,
            1,
          );
        }
        break;
      case 'prop-laptop':
        box(c, const Rect.fromLTWH(21, 18, 64, 48), gray);
        box(c, const Rect.fromLTWH(27, 23, 52, 36), const Color(0xFF777E77));
        shape(
          c,
          Path()
            ..moveTo(21, 66)
            ..lineTo(85, 66)
            ..lineTo(75, 84)
            ..lineTo(7, 84)
            ..close(),
        );
        line(c, const Offset(29, 72), const Offset(69, 72), gray, 3);
        break;
      case 'prop-umbrella':
        shape(
          c,
          Path()
            ..moveTo(12, 44)
            ..quadraticBezierTo(50, -7, 88, 44)
            ..quadraticBezierTo(70, 33, 62, 45)
            ..quadraticBezierTo(50, 33, 38, 45)
            ..quadraticBezierTo(25, 32, 12, 44)
            ..close(),
          gray,
        );
        line(c, const Offset(50, 17), const Offset(50, 78), ink, 3);
        c.drawArc(
          const Rect.fromLTWH(33, 66, 17, 21),
          0,
          math.pi,
          false,
          Paint()
            ..color = ink
            ..style = PaintingStyle.stroke
            ..strokeWidth = 3,
        );
        break;
      case 'prop-flowers':
        shape(
          c,
          Path()
            ..moveTo(16, 48)
            ..lineTo(50, 91)
            ..lineTo(84, 48)
            ..close(),
          gray,
        );
        for (final p in [
          const Offset(29, 43),
          const Offset(51, 27),
          const Offset(72, 44),
        ]) {
          for (var i = 0; i < 5; i++) {
            final a = i * math.pi * 2 / 5;
            oval(
              c,
              Rect.fromCircle(
                center: p + Offset(math.cos(a) * 9, math.sin(a) * 9),
                radius: 7,
              ),
            );
          }
          c.drawCircle(p, 4, Paint()..color = gray);
        }
        break;
      case 'prop-trophy':
        oval(c, const Rect.fromLTWH(10, 20, 30, 33), gray);
        oval(c, const Rect.fromLTWH(60, 20, 30, 33), gray);
        shape(
          c,
          Path()
            ..moveTo(27, 15)
            ..lineTo(73, 15)
            ..quadraticBezierTo(72, 60, 52, 61)
            ..lineTo(54, 78)
            ..lineTo(68, 84)
            ..lineTo(32, 84)
            ..lineTo(46, 78)
            ..lineTo(48, 61)
            ..quadraticBezierTo(28, 60, 27, 15)
            ..close(),
        );
        text(c, '★', const Offset(38, 29), 24);
        break;
      case 'prop-cookies':
        oval(c, const Rect.fromLTWH(7, 47, 86, 34));
        for (final p in [
          const Offset(31, 53),
          const Offset(52, 39),
          const Offset(69, 57),
        ]) {
          oval(c, Rect.fromCenter(center: p, width: 30, height: 22), gray);
          for (var j = 0; j < 3; j++) {
            c.drawCircle(p + Offset(j * 6 - 6, j.isEven ? -3 : 3), 2, Paint());
          }
        }
        break;
      case 'prop-greeting':
        shape(
          c,
          Path()
            ..moveTo(18, 69)
            ..cubicTo(-4, 22, 98, 11, 91, 56)
            ..quadraticBezierTo(85, 77, 38, 76)
            ..lineTo(15, 89)
            ..close(),
        );
        text(c, '안녕!', const Offset(27, 35), 22);
        break;
    }
  }

  @override
  bool shouldRepaint(WardrobeItemPainter oldDelegate) => id != oldDelegate.id;
}

class WardrobeCoin extends StatelessWidget {
  const WardrobeCoin({super.key, this.size = 22});
  final double size;
  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: size,
    child: CustomPaint(painter: _CoinPainter()),
  );
}

class _CoinPainter extends CustomPainter {
  @override
  void paint(Canvas c, Size s) {
    final r = s.width / 2;
    final center = Offset(r, r);
    c.drawCircle(center, r, Paint()..color = const Color(0xFFE4A334));
    c.drawCircle(
      center,
      r * .82,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = r * .08,
    );
    final path = Path();
    for (var i = 0; i < 10; i++) {
      final a = -math.pi / 2 + i * math.pi / 5;
      final length = r * (i.isEven ? .61 : .29);
      final point = center + Offset(math.cos(a), math.sin(a)) * length;
      if (i == 0) {
        path.moveTo(point.dx, point.dy);
      } else {
        path.lineTo(point.dx, point.dy);
      }
    }
    c.drawPath(path..close(), Paint()..color = Colors.white);
  }

  @override
  bool shouldRepaint(_CoinPainter oldDelegate) => false;
}

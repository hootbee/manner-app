import 'package:flutter/material.dart';
import 'partner_selection_screen.dart';
import 'original_body_garment.dart';

// Approved outfits share the original body, pose, face, feet and tail.
// Extend this set only after fitting each garment to that same anatomy.
bool _usesOriginalBody(String outfit) =>
    const {'suit', 'school', 'bear', 'trench'}.contains(outfit);

/// Product thumbnails are never used as body parts.
class FittedPartnerClothes extends StatelessWidget {
  const FittedPartnerClothes({
    super.key,
    required this.partner,
    required this.outfit,
    required this.hat,
    required this.accessory,
  });
  final MannerPartner partner;
  final String outfit, hat, accessory;
  @override
  Widget build(BuildContext context) => FittedBox(
    fit: BoxFit.contain,
    child: SizedBox(
      width: 264,
      height: 295,
      child: Stack(
        fit: StackFit.expand,
        children: [
          CustomPaint(
            painter: _WornPainter(
              partner: partner,
              outfit: outfit,
              accessory: accessory,
              layer: 0,
            ),
          ),
          if (!_usesOriginalBody(outfit))
            CustomPaint(
              painter: _WornPainter(
                partner: partner,
                outfit: outfit,
                accessory: accessory,
                layer: 1,
              ),
            ),
          ClipPath(
            clipper: _AnatomyClipper(partner, _usesOriginalBody(outfit)),
            child: ClipRect(
              child: OverflowBox(
                alignment: Alignment.topLeft,
                minWidth: 793,
                maxWidth: 793,
                minHeight: 1983,
                maxHeight: 1983,
                child: Transform.translate(
                  offset: Offset(-partner.index * 793 / 3, -1205),
                  child: Image.asset(
                    'assets/welcome/partner_design_v2.png',
                    width: 793,
                    height: 1983,
                    fit: BoxFit.fill,
                    filterQuality: FilterQuality.high,
                  ),
                ),
              ),
            ),
          ),
          if (outfit == 'bear' || outfit == 'trench')
            OriginalBodyGarment(partner: partner, outfit: outfit),
          CustomPaint(
            painter: _WornPainter(
              partner: partner,
              outfit: outfit,
              hat: hat,
              accessory: accessory,
              layer: 2,
            ),
          ),
        ],
      ),
    ),
  );
}

class _AnatomyClipper extends CustomClipper<Path> {
  const _AnatomyClipper(this.partner, this.full);
  final MannerPartner partner;
  final bool full;
  @override
  Path getClip(Size size) {
    if (full) return Path()..addRect(Offset.zero & size);
    final headHeight = partner == MannerPartner.monkey ? 165.0 : 174.0;
    // Preserve only the supplied face. The worn body owns its tail and paws.
    if (partner == MannerPartner.monkey) {
      // The atlas tail curls beside the chin. Exclude that corner of the crop.
      return Path()
        ..addRect(const Rect.fromLTWH(0, 0, 264, 148))
        ..addRect(const Rect.fromLTWH(0, 148, 209, 17));
    }
    return Path()..addRect(Rect.fromLTWH(0, 0, 264, headHeight));
  }

  @override
  bool shouldReclip(_AnatomyClipper oldClipper) =>
      partner != oldClipper.partner || full != oldClipper.full;
}

class _WornPainter extends CustomPainter {
  const _WornPainter({
    required this.partner,
    required this.outfit,
    required this.accessory,
    required this.layer,
    this.hat = 'hat-none',
  });
  final MannerPartner partner;
  final String outfit, accessory, hat;
  final int layer;
  static const ink = Color(0xFF20211F),
      paper = Color(0xFFFAFAF5),
      dark = Color(0xFF373936),
      gray = Color(0xFF9C9E97),
      gold = Color(0xFFD6B655);
  Color get fur => switch (partner) {
    MannerPartner.cat => const Color(0xFFFFF8EA),
    MannerPartner.dog => const Color(0xFFFEFEFA),
    MannerPartner.monkey => const Color(0xFFF3D7C0),
  };
  void shape(Canvas c, Path p, Color fill, {double width = 4}) {
    c.drawPath(p, Paint()..color = fill);
    c.drawPath(
      p,
      Paint()
        ..color = ink
        ..style = PaintingStyle.stroke
        ..strokeWidth = width
        ..strokeJoin = StrokeJoin.round
        ..strokeCap = StrokeCap.round,
    );
  }

  void line(
    Canvas c,
    Offset a,
    Offset b, {
    Color color = ink,
    double width = 3,
  }) => c.drawLine(
    a,
    b,
    Paint()
      ..color = color
      ..strokeWidth = width
      ..strokeCap = StrokeCap.round,
  );
  void curve(Canvas c, Path p, {Color color = ink, double width = 3}) =>
      c.drawPath(
        p,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = width
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round,
      );
  void oval(Canvas c, Rect r, Color fill, {double width = 3}) =>
      shape(c, Path()..addOval(r), fill, width: width);
  void rounded(
    Canvas c,
    Rect r,
    Color fill, {
    double radius = 5,
    double width = 3,
  }) => shape(
    c,
    Path()..addRRect(RRect.fromRectAndRadius(r, Radius.circular(radius))),
    fill,
    width: width,
  );
  @override
  void paint(Canvas c, Size size) {
    c.save();
    c.scale(size.width / 264, size.height / 295);
    if (layer == 0) {
      if (!_usesOriginalBody(outfit)) _tail(c);
      if (accessory == 'acc-backpack') _backpack(c);
    }
    if (layer == 1) _body(c);
    if (layer == 2) {
      if (outfit == 'school') _schoolPocket(c);
      if (_usesOriginalBody(outfit) && accessory == 'acc-backpack') _straps(c);
      _accessory(c);
      _hat(c);
    }
    c.restore();
  }

  /// Sewn-on detail in the original atlas coordinates, never a replacement torso.
  void _schoolPocket(Canvas c) {
    final bounds = switch (partner) {
      MannerPartner.cat => const Rect.fromLTWH(154, 197, 18, 22),
      MannerPartner.dog => const Rect.fromLTWH(160, 196, 18, 22),
      MannerPartner.monkey => const Rect.fromLTWH(139, 185, 18, 22),
    };
    c.save();
    if (partner == MannerPartner.monkey) {
      // Its folded forearm covers the bottom of the chest pocket. Never paint
      // the pocket on top of that arm or move it onto the outer sleeve.
      c.clipPath(
        Path()
          ..moveTo(132, 175)
          ..lineTo(168, 175)
          ..lineTo(168, 189)
          ..lineTo(132, 204)
          ..close(),
      );
    }
    c.translate(bounds.left, bounds.top);
    c.scale(bounds.width / 18, bounds.height / 22);
    shape(
      c,
      Path()
        ..moveTo(1, 1)
        ..lineTo(17, 1)
        ..lineTo(16, 15)
        ..quadraticBezierTo(14, 20, 9, 21)
        ..quadraticBezierTo(4, 20, 2, 15)
        ..close(),
      paper,
      width: 2,
    );
    shape(
      c,
      Path()
        ..moveTo(4, 4)
        ..lineTo(14, 4)
        ..lineTo(13.5, 14)
        ..quadraticBezierTo(12, 17, 9, 18)
        ..quadraticBezierTo(6, 17, 4.5, 14)
        ..close(),
      gray,
      width: 1.4,
    );
    line(c, const Offset(7, 7), const Offset(7, 13), color: paper, width: 1.3);
    line(
      c,
      const Offset(11, 7),
      const Offset(11, 13),
      color: paper,
      width: 1.3,
    );
    line(c, const Offset(7, 7), const Offset(9, 10), color: paper, width: 1.3);
    line(c, const Offset(9, 10), const Offset(11, 7), color: paper, width: 1.3);
    c.restore();
  }

  void _tail(Canvas c) {
    if (partner == MannerPartner.dog) {
      shape(
        c,
        Path()
          ..moveTo(177, 241)
          ..quadraticBezierTo(195, 243, 201, 225)
          ..cubicTo(196, 214, 204, 204, 211, 210)
          ..cubicTo(217, 193, 232, 202, 225, 214)
          ..cubicTo(242, 214, 238, 231, 227, 233)
          ..quadraticBezierTo(216, 256, 181, 254)
          ..close(),
        fur,
      );
    } else {
      final path = partner == MannerPartner.cat
          ? (Path()
              ..moveTo(179, 245)
              ..cubicTo(208, 255, 215, 231, 236, 226)
              ..quadraticBezierTo(254, 222, 253, 236))
          : (Path()
              ..moveTo(179, 245)
              ..cubicTo(228, 268, 254, 236, 247, 210)
              ..cubicTo(242, 187, 215, 190, 214, 207)
              ..cubicTo(212, 223, 233, 225, 235, 212));
      curve(c, path, width: 18);
      curve(
        c,
        path,
        color: partner == MannerPartner.monkey ? const Color(0xFFB18C78) : fur,
        width: 10,
      );
    }
  }

  void _body(Canvas c) {
    final color = switch (outfit) {
      'hoodie' || 'shirt' => paper,
      'bear' => const Color(0xFFB0B0AA),
      'trench' || 'duffle' => gray,
      _ => dark,
    };
    final sleeves = outfit == 'varsity' || outfit == 'vest' ? paper : color;
    // Rounded thighs remain visible below the garment, rather than a long coat icon.
    shape(
      c,
      Path()
        ..moveTo(90, 238)
        ..lineTo(175, 238)
        ..lineTo(181, 274)
        ..quadraticBezierTo(161, 281, 144, 275)
        ..lineTo(132, 259)
        ..lineTo(121, 275)
        ..quadraticBezierTo(99, 281, 82, 273)
        ..close(),
      outfit == 'bear' ? color : dark,
    );
    for (final x in [81.0, 143.0]) {
      shape(
        c,
        Path()
          ..moveTo(x + 7, 268)
          ..quadraticBezierTo(x + 25, 263, x + 39, 269)
          ..quadraticBezierTo(x + 49, 275, x + 44, 282)
          ..quadraticBezierTo(x + 23, 287, x + 1, 281)
          ..quadraticBezierTo(x - 3, 275, x + 7, 268)
          ..close(),
        fur,
      );
    }
    // Sleeves follow bent arms, with small exposed paws at each cuff.
    shape(
      c,
      Path()
        ..moveTo(102, 170)
        ..cubicTo(79, 167, 63, 189, 66, 215)
        ..quadraticBezierTo(67, 229, 83, 231)
        ..lineTo(98, 215)
        ..lineTo(111, 185)
        ..close(),
      sleeves,
    );
    shape(
      c,
      Path()
        ..moveTo(161, 170)
        ..cubicTo(185, 167, 202, 188, 200, 215)
        ..quadraticBezierTo(199, 229, 183, 231)
        ..lineTo(168, 215)
        ..lineTo(154, 185)
        ..close(),
      sleeves,
    );
    oval(c, const Rect.fromLTWH(72, 218, 20, 17), fur);
    oval(c, const Rect.fromLTWH(174, 218, 20, 17), fur);
    curve(
      c,
      Path()
        ..moveTo(68, 214)
        ..quadraticBezierTo(78, 223, 89, 218),
      width: 3,
    );
    curve(
      c,
      Path()
        ..moveTo(178, 218)
        ..quadraticBezierTo(189, 223, 199, 214),
      width: 3,
    );
    // One fitted torso, broad at the shoulders and rounded at the hips.
    shape(
      c,
      Path()
        ..moveTo(104, 164)
        ..quadraticBezierTo(132, 158, 158, 164)
        ..quadraticBezierTo(174, 178, 177, 197)
        ..quadraticBezierTo(178, 223, 187, 246)
        ..quadraticBezierTo(161, 263, 132, 252)
        ..quadraticBezierTo(105, 263, 78, 246)
        ..quadraticBezierTo(87, 222, 87, 197)
        ..quadraticBezierTo(90, 177, 104, 164)
        ..close(),
      color,
    );
    if (outfit == 'hoodie') {
      shape(
        c,
        Path()
          ..moveTo(103, 167)
          ..quadraticBezierTo(131, 183, 160, 167)
          ..quadraticBezierTo(153, 190, 132, 192)
          ..quadraticBezierTo(110, 186, 103, 167)
          ..close(),
        paper,
        width: 3,
      );
      for (final x in [120.0, 145.0]) {
        line(c, Offset(x, 183), Offset(x, 208), color: gray, width: 2);
        oval(c, Rect.fromLTWH(x - 1, 205, 3, 5), gray, width: 1);
      }
      curve(
        c,
        Path()
          ..moveTo(106, 222)
          ..lineTo(103, 238)
          ..quadraticBezierTo(130, 244, 158, 238)
          ..lineTo(155, 222),
        color: gray,
        width: 2,
      );
      curve(
        c,
        Path()
          ..moveTo(91, 247)
          ..quadraticBezierTo(133, 257, 175, 247),
        color: gray,
        width: 2,
      );
    } else if (outfit == 'bear') {
      oval(c, const Rect.fromLTWH(109, 196, 45, 47), paper, width: 2);
      oval(c, const Rect.fromLTWH(115, 197, 11, 12), paper, width: 2);
      oval(c, const Rect.fromLTWH(139, 197, 11, 12), paper, width: 2);
      oval(c, const Rect.fromLTWH(119, 205, 26, 23), paper, width: 2);
      c.drawCircle(const Offset(126, 214), 1.6, Paint()..color = ink);
      c.drawCircle(const Offset(138, 214), 1.6, Paint()..color = ink);
      oval(c, const Rect.fromLTWH(130, 218, 4, 3), ink, width: 1);
    } else if (outfit == 'duffle') {
      shape(
        c,
        Path()
          ..moveTo(101, 166)
          ..quadraticBezierTo(131, 176, 162, 166)
          ..lineTo(153, 188)
          ..quadraticBezierTo(130, 197, 110, 186)
          ..close(),
        gray,
        width: 3,
      );
      line(c, const Offset(131, 187), const Offset(131, 252), width: 2);
      for (var y = 205.0; y < 239; y += 16) {
        line(c, Offset(117, y), Offset(146, y), color: dark, width: 4);
        rounded(
          c,
          Rect.fromLTWH(129, y - 3, 11, 6),
          paper,
          radius: 2,
          width: 1.5,
        );
      }
    } else {
      _collar(c, color);
      if (outfit == 'varsity') {
        shape(
          c,
          Path()
            ..moveTo(109, 168)
            ..quadraticBezierTo(131, 180, 156, 168)
            ..lineTo(151, 181)
            ..quadraticBezierTo(131, 191, 113, 181)
            ..close(),
          dark,
          width: 3,
        );
        line(
          c,
          const Offset(132, 185),
          const Offset(132, 252),
          color: gray,
          width: 2,
        );
        for (var y = 199.0; y < 245; y += 15) {
          oval(c, Rect.fromLTWH(136, y, 3, 3), paper, width: 1);
        }
        curve(
          c,
          Path()
            ..moveTo(89, 247)
            ..quadraticBezierTo(132, 256, 177, 247),
          color: paper,
          width: 2,
        );
      } else if (outfit == 'shirt') {
        line(
          c,
          const Offset(133, 190),
          const Offset(133, 252),
          color: gray,
          width: 1.5,
        );
        for (var y = 202.0; y < 246; y += 14) {
          c.drawCircle(Offset(137, y), 1.6, Paint()..color = gray);
        }
        curve(
          c,
          Path()
            ..moveTo(150, 205)
            ..lineTo(166, 205)
            ..lineTo(164, 220)
            ..quadraticBezierTo(157, 225, 151, 220)
            ..close(),
          color: gray,
          width: 1.5,
        );
      } else {
        if (outfit == 'vest') {
          shape(
            c,
            Path()
              ..moveTo(105, 169)
              ..lineTo(132, 204)
              ..lineTo(158, 169)
              ..quadraticBezierTo(167, 205, 177, 248)
              ..lineTo(144, 253)
              ..lineTo(132, 245)
              ..lineTo(120, 253)
              ..lineTo(88, 248)
              ..quadraticBezierTo(98, 207, 105, 169)
              ..close(),
            dark,
            width: 3,
          );
        } else {
          // Lapels wrap the chest; they share the shoulder and waist contours.
          shape(
            c,
            Path()
              ..moveTo(104, 168)
              ..lineTo(97, 186)
              ..lineTo(109, 193)
              ..lineTo(104, 202)
              ..lineTo(132, 224)
              ..lineTo(120, 188)
              ..close(),
            color,
            width: 2.5,
          );
          shape(
            c,
            Path()
              ..moveTo(159, 168)
              ..lineTo(167, 186)
              ..lineTo(155, 193)
              ..lineTo(160, 202)
              ..lineTo(132, 224)
              ..lineTo(145, 187)
              ..close(),
            color,
            width: 2.5,
          );
        }
        line(c, const Offset(132, 224), const Offset(132, 251), width: 2);
        oval(c, const Rect.fromLTWH(130, 233, 4, 4), gold, width: 1);
        if (outfit == 'trench') {
          rounded(
            c,
            const Rect.fromLTWH(88, 230, 89, 9),
            gray,
            radius: 2,
            width: 2,
          );
          rounded(
            c,
            const Rect.fromLTWH(126, 228, 14, 13),
            dark,
            radius: 2,
            width: 2,
          );
          rounded(
            c,
            const Rect.fromLTWH(130, 231, 6, 7),
            gray,
            radius: 1,
            width: 1,
          );
        }
      }
    }
    if (accessory == 'acc-backpack') {
      _straps(c);
    }
  }

  void _straps(Canvas c) {
    curve(
      c,
      Path()
        ..moveTo(102, 175)
        ..quadraticBezierTo(91, 192, 95, 216),
      color: ink,
      width: 7,
    );
    curve(
      c,
      Path()
        ..moveTo(164, 175)
        ..quadraticBezierTo(175, 191, 170, 216),
      color: ink,
      width: 7,
    );
    curve(
      c,
      Path()
        ..moveTo(102, 175)
        ..quadraticBezierTo(91, 192, 95, 216),
      color: gray,
      width: 3,
    );
    curve(
      c,
      Path()
        ..moveTo(164, 175)
        ..quadraticBezierTo(175, 191, 170, 216),
      color: gray,
      width: 3,
    );
  }

  void _collar(Canvas c, Color color) {
    shape(
      c,
      Path()
        ..moveTo(106, 163)
        ..quadraticBezierTo(133, 172, 158, 163)
        ..lineTo(146, 190)
        ..lineTo(132, 219)
        ..lineTo(117, 188)
        ..close(),
      paper,
      width: 2.5,
    );
    shape(
      c,
      Path()
        ..moveTo(107, 165)
        ..lineTo(132, 176)
        ..lineTo(121, 191)
        ..close(),
      paper,
      width: 2,
    );
    shape(
      c,
      Path()
        ..moveTo(157, 165)
        ..lineTo(132, 176)
        ..lineTo(143, 191)
        ..close(),
      paper,
      width: 2,
    );
    if (outfit != 'shirt' && outfit != 'varsity') {
      shape(
        c,
        Path()
          ..moveTo(127, 179)
          ..lineTo(136, 179)
          ..lineTo(138, 186)
          ..lineTo(134, 191)
          ..lineTo(141, 207)
          ..lineTo(132, 218)
          ..lineTo(124, 207)
          ..lineTo(129, 191)
          ..lineTo(125, 186)
          ..close(),
        dark,
        width: 2,
      );
    }
  }

  void _backpack(Canvas c) {
    rounded(
      c,
      const Rect.fromLTWH(168, 176, 45, 77),
      dark,
      radius: 14,
      width: 4,
    );
    rounded(
      c,
      const Rect.fromLTWH(182, 207, 28, 35),
      gray,
      radius: 8,
      width: 2,
    );
    curve(
      c,
      Path()
        ..moveTo(173, 183)
        ..quadraticBezierTo(170, 162, 189, 169),
      width: 5,
    );
  }

  void _accessory(Canvas c) {
    switch (accessory) {
      case 'acc-bow':
        shape(
          c,
          Path()
            ..moveTo(128, 182)
            ..quadraticBezierTo(116, 169, 109, 177)
            ..quadraticBezierTo(105, 187, 110, 194)
            ..lineTo(128, 187)
            ..close(),
          dark,
          width: 3,
        );
        shape(
          c,
          Path()
            ..moveTo(136, 182)
            ..quadraticBezierTo(148, 169, 155, 177)
            ..quadraticBezierTo(159, 187, 154, 194)
            ..lineTo(136, 187)
            ..close(),
          dark,
          width: 3,
        );
        rounded(
          c,
          const Rect.fromLTWH(126, 178, 12, 13),
          dark,
          radius: 4,
          width: 2,
        );
      case 'acc-watch':
        if (partner == MannerPartner.monkey &&
            (outfit == 'suit' || outfit == 'school')) {
          break;
        }
        // Strap wraps the sleeve wrist; the face follows the forearm's tilt.
        c.save();
        if (partner == MannerPartner.monkey && _usesOriginalBody(outfit)) {
          c.translate(118, 199);
        } else {
          c.translate(190, 220);
        }
        c.rotate(-.3);
        rounded(
          c,
          const Rect.fromLTWH(-8, -14, 16, 29),
          dark,
          radius: 6,
          width: 2,
        );
        oval(c, const Rect.fromLTWH(-10, -10, 20, 20), gold, width: 2);
        oval(c, const Rect.fromLTWH(-7, -7, 14, 14), paper, width: 1);
        line(c, Offset.zero, const Offset(0, -4), width: 1.3);
        line(c, Offset.zero, const Offset(4, 1), width: 1.3);
        c.restore();
      case 'acc-badges':
        oval(c, const Rect.fromLTWH(156, 199, 13, 13), gold, width: 2);
        shape(
          c,
          Path()
            ..moveTo(160, 202)
            ..lineTo(164, 202)
            ..lineTo(164, 208)
            ..lineTo(160, 208)
            ..close(),
          paper,
          width: 1,
        );
      case 'acc-scarf':
        shape(
          c,
          Path()
            ..moveTo(100, 165)
            ..quadraticBezierTo(130, 182, 164, 165)
            ..lineTo(161, 180)
            ..quadraticBezierTo(130, 196, 103, 181)
            ..close(),
          paper,
          width: 3,
        );
        shape(
          c,
          Path()
            ..moveTo(142, 183)
            ..lineTo(158, 181)
            ..lineTo(167, 221)
            ..lineTo(149, 225)
            ..close(),
          gray,
          width: 3,
        );
        for (var y = 193.0; y < 222; y += 10) {
          line(c, Offset(148, y), Offset(160, y - 3), color: paper, width: 4);
        }
      case 'acc-briefcase':
        rounded(
          c,
          const Rect.fromLTWH(181, 239, 51, 34),
          dark,
          radius: 6,
          width: 3,
        );
        curve(
          c,
          Path()
            ..moveTo(195, 239)
            ..lineTo(195, 232)
            ..quadraticBezierTo(206, 225, 216, 232)
            ..lineTo(216, 239),
          width: 4,
        );
        line(
          c,
          const Offset(184, 250),
          const Offset(229, 250),
          color: gray,
          width: 2,
        );
        rounded(
          c,
          const Rect.fromLTWH(202, 246, 8, 10),
          gray,
          radius: 2,
          width: 2,
        );
      case 'acc-headphones':
        curve(
          c,
          Path()
            ..moveTo(43, 112)
            ..cubicTo(36, 8, 221, 8, 221, 112),
          width: 12,
        );
        curve(
          c,
          Path()
            ..moveTo(43, 111)
            ..cubicTo(40, 16, 218, 16, 221, 111),
          color: gray,
          width: 5,
        );
        rounded(
          c,
          const Rect.fromLTWH(29, 95, 24, 46),
          dark,
          radius: 11,
          width: 3,
        );
        rounded(
          c,
          const Rect.fromLTWH(211, 95, 24, 46),
          dark,
          radius: 11,
          width: 3,
        );
      // The supplied adult face already wears black sunglasses. Reuse them,
      // rather than laying a second product-card pair over the original lenses.
      case 'acc-glasses':
      case 'acc-backpack':
      case 'acc-none':
        break;
    }
  }

  void _hat(Canvas c) {
    if (hat == 'hat-none') return;
    final shift =
        (partner == MannerPartner.dog ? 5.0 : 0.0) +
        switch (hat) {
          'hat-party' => 30.0,
          'hat-top' => 20.0,
          'hat-beret' => 15.0,
          _ => 10.0,
        };
    c.save();
    c.translate(0, shift);
    if (hat == 'hat-beanie') {
      shape(
        c,
        Path()
          ..moveTo(76, 45)
          ..cubicTo(73, -9, 189, -9, 189, 45)
          ..close(),
        gray,
        width: 4,
      );
      for (var x = 94.0; x < 181; x += 17) {
        curve(
          c,
          Path()
            ..moveTo(x, 9)
            ..quadraticBezierTo(x - 8, 23, x - 7, 44),
          color: dark,
          width: 1.5,
        );
      }
      shape(
        c,
        Path()
          ..moveTo(74, 36)
          ..quadraticBezierTo(131, 26, 191, 36)
          ..lineTo(192, 56)
          ..quadraticBezierTo(132, 47, 73, 56)
          ..close(),
        gray,
        width: 4,
      );
      rounded(
        c,
        const Rect.fromLTWH(157, 35, 21, 15),
        paper,
        radius: 3,
        width: 2,
      );
    } else if (hat == 'hat-beret') {
      shape(
        c,
        Path()
          ..moveTo(66, 38)
          ..cubicTo(54, 2, 160, -13, 192, 20)
          ..quadraticBezierTo(211, 46, 168, 50)
          ..lineTo(84, 52)
          ..close(),
        dark,
        width: 4,
      );
      curve(
        c,
        Path()
          ..moveTo(84, 46)
          ..quadraticBezierTo(130, 36, 179, 44),
        color: gray,
        width: 2,
      );
      curve(
        c,
        Path()
          ..moveTo(142, 5)
          ..quadraticBezierTo(142, -5, 150, -7),
        width: 6,
      );
    } else if (hat == 'hat-cap' || hat == 'hat-detective') {
      shape(
        c,
        Path()
          ..moveTo(75, 42)
          ..cubicTo(74, -14, 187, -14, 190, 43)
          ..quadraticBezierTo(133, 54, 75, 42)
          ..close(),
        hat == 'hat-cap' ? paper : gray,
        width: 4,
      );
      if (hat == 'hat-cap') {
        shape(
          c,
          Path()
            ..moveTo(147, 3)
            ..quadraticBezierTo(190, 7, 190, 43)
            ..lineTo(159, 46)
            ..quadraticBezierTo(165, 22, 147, 3)
            ..close(),
          dark,
          width: 3,
        );
      } else {
        for (var x = 92.0; x < 184; x += 16) {
          line(c, Offset(x, 13), Offset(x - 2, 40), color: dark, width: 1);
        }
        for (var y = 15.0; y < 41; y += 12) {
          line(c, Offset(91, y), Offset(178, y), color: paper, width: 1);
        }
      }
      shape(
        c,
        Path()
          ..moveTo(79, 39)
          ..quadraticBezierTo(126, 30, 165, 44)
          ..quadraticBezierTo(111, 46, 66, 62)
          ..quadraticBezierTo(55, 58, 61, 51)
          ..close(),
        dark,
        width: 4,
      );
    } else if (hat == 'hat-party') {
      shape(
        c,
        Path()
          ..moveTo(132, -19)
          ..lineTo(176, 49)
          ..quadraticBezierTo(132, 61, 89, 49)
          ..close(),
        gray,
        width: 4,
      );
      for (final point in [
        const Offset(130, 6),
        const Offset(116, 28),
        const Offset(148, 36),
      ]) {
        c.drawCircle(point, 5, Paint()..color = paper);
      }
      oval(c, const Rect.fromLTWH(125, -25, 15, 15), paper, width: 3);
    } else {
      final ribbon = hat == 'hat-ribbon';
      shape(
        c,
        Path()
          ..moveTo(85, 38)
          ..lineTo(92, hat == 'hat-top' ? -14 : 4)
          ..quadraticBezierTo(133, -10, 175, 4)
          ..lineTo(181, 38)
          ..close(),
        ribbon ? paper : dark,
        width: 4,
      );
      shape(
        c,
        Path()
          ..moveTo(87, 25)
          ..quadraticBezierTo(133, 35, 178, 25)
          ..lineTo(181, 38)
          ..quadraticBezierTo(133, 47, 85, 38)
          ..close(),
        ribbon ? dark : paper,
        width: 2,
      );
      oval(
        c,
        const Rect.fromLTWH(60, 34, 145, 23),
        ribbon ? paper : dark,
        width: 4,
      );
      if (ribbon) {
        shape(
          c,
          Path()
            ..moveTo(164, 43)
            ..lineTo(146, 30)
            ..quadraticBezierTo(140, 46, 146, 53)
            ..close(),
          dark,
          width: 2,
        );
        shape(
          c,
          Path()
            ..moveTo(164, 43)
            ..lineTo(184, 32)
            ..quadraticBezierTo(192, 46, 184, 55)
            ..close(),
          dark,
          width: 2,
        );
      }
    }
    c.restore();
  }

  @override
  bool shouldRepaint(_WornPainter oldDelegate) =>
      partner != oldDelegate.partner ||
      outfit != oldDelegate.outfit ||
      hat != oldDelegate.hat ||
      accessory != oldDelegate.accessory ||
      layer != oldDelegate.layer;
}

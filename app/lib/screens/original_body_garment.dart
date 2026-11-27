import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'partner_selection_screen.dart';

/// Recolors the original garment pixels and stitches details onto the same pose.
/// Face, tail, feet and the exterior silhouette come from the original atlas.
class OriginalBodyGarment extends StatefulWidget {
  const OriginalBodyGarment({
    super.key,
    required this.partner,
    required this.outfit,
  });
  final MannerPartner partner;
  final String outfit;
  @override
  State<OriginalBodyGarment> createState() => _OriginalBodyGarmentState();
}

class _OriginalBodyGarmentState extends State<OriginalBodyGarment> {
  ImageStream? _stream;
  ImageInfo? _info;
  late final _listener = ImageStreamListener((info, _) {
    if (!mounted) {
      info.dispose();
      return;
    }
    setState(() {
      _info?.dispose();
      _info = info;
    });
  });
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final stream = const AssetImage(
      'assets/welcome/partner_design_v2.png',
    ).resolve(createLocalImageConfiguration(context));
    if (_stream?.key == stream.key) return;
    _stream?.removeListener(_listener);
    _stream = stream..addListener(_listener);
  }

  @override
  void dispose() {
    _stream?.removeListener(_listener);
    _info?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: CustomPaint(
      painter: _OriginalGarmentPainter(
        _info?.image,
        widget.partner,
        widget.outfit,
      ),
    ),
  );
}

class _OriginalGarmentPainter extends CustomPainter {
  const _OriginalGarmentPainter(this.image, this.partner, this.outfit);
  final ui.Image? image;
  final MannerPartner partner;
  final String outfit;
  static const ink = Color(0xFF20211F),
      cloth = Color(0xFFA2A49F),
      paper = Color(0xFFF5F4EC);
  Path get jacket => switch (partner) {
    MannerPartner.cat =>
      (Path()
        ..moveTo(103, 163)
        ..lineTo(164, 163)
        ..cubicTo(189, 172, 207, 194, 204, 213)
        ..quadraticBezierTo(201, 226, 185, 232)
        ..lineTo(194, 249)
        ..quadraticBezierTo(161, 262, 134, 244)
        ..quadraticBezierTo(109, 261, 78, 249)
        ..lineTo(87, 229)
        ..quadraticBezierTo(66, 227, 76, 202)
        ..quadraticBezierTo(80, 180, 103, 163)
        ..close()),
    MannerPartner.dog =>
      (Path()
        ..moveTo(102, 163)
        ..lineTo(164, 163)
        ..cubicTo(187, 173, 201, 195, 196, 215)
        ..quadraticBezierTo(191, 229, 177, 231)
        ..lineTo(189, 249)
        ..quadraticBezierTo(160, 260, 132, 243)
        ..quadraticBezierTo(105, 260, 77, 249)
        ..lineTo(86, 230)
        ..quadraticBezierTo(67, 227, 73, 207)
        ..quadraticBezierTo(77, 179, 102, 163)
        ..close()),
    MannerPartner.monkey =>
      (Path()
        ..moveTo(101, 160)
        ..lineTo(163, 160)
        ..cubicTo(190, 169, 205, 189, 197, 211)
        ..quadraticBezierTo(195, 229, 175, 238)
        ..lineTo(187, 250)
        ..quadraticBezierTo(158, 260, 129, 244)
        ..quadraticBezierTo(103, 259, 77, 248)
        ..lineTo(83, 231)
        ..cubicTo(58, 228, 53, 205, 65, 189)
        ..quadraticBezierTo(75, 171, 101, 160)
        ..close()),
  };
  Path get torso => Path()
    ..moveTo(105, 168)
    ..lineTo(159, 168)
    ..cubicTo(173, 182, 176, 207, 172, 220)
    ..lineTo(179, 244)
    ..quadraticBezierTo(157, 249, 132, 237)
    ..quadraticBezierTo(110, 251, 87, 244)
    ..lineTo(96, 208)
    ..quadraticBezierTo(96, 183, 105, 168)
    ..close();
  Path get foldedArms => Path()
    ..moveTo(73, 181)
    ..quadraticBezierTo(86, 182, 105, 195)
    ..quadraticBezierTo(130, 206, 159, 192)
    ..quadraticBezierTo(187, 183, 195, 199)
    ..quadraticBezierTo(198, 215, 177, 224)
    ..quadraticBezierTo(144, 238, 113, 221)
    ..quadraticBezierTo(82, 232, 67, 214)
    ..quadraticBezierTo(59, 198, 73, 181)
    ..close();
  void stroke(Canvas c, Path path, {double width = 2, Color color = ink}) =>
      c.drawPath(
        path,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = width
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round,
      );
  void shape(Canvas c, Path path, Color color, {double width = 2}) {
    c.drawPath(path, Paint()..color = color);
    stroke(c, path, width: width);
  }

  void source(Canvas c, Paint paint) => c.drawImageRect(
    image!,
    Rect.fromLTWH(partner.index * 793 / 3, 1205, 264, 295),
    const Rect.fromLTWH(0, 0, 264, 295),
    paint..filterQuality = FilterQuality.high,
  );
  void tint(Canvas c, Path region) {
    c.save();
    c.clipPath(region);
    // Smoothly lift charcoal to gray, retaining source alpha and black seams.
    c.saveLayer(
      const Rect.fromLTWH(50, 155, 160, 118),
      Paint()
        ..colorFilter = const ColorFilter.matrix([
          .65,
          0,
          0,
          0,
          0,
          0,
          .65,
          0,
          0,
          0,
          0,
          0,
          .65,
          0,
          0,
          0,
          0,
          0,
          1,
          0,
        ]),
    );
    source(
      c,
      Paint()
        ..colorFilter = const ColorFilter.matrix([
          1.8,
          3.6,
          .6,
          0,
          0,
          1.8,
          3.6,
          .6,
          0,
          0,
          1.8,
          3.6,
          .6,
          0,
          0,
          0,
          0,
          0,
          1,
          0,
        ]),
    );
    c.restore();
    c.restore();
  }

  @override
  void paint(Canvas c, Size size) {
    if (image == null) return;
    c.save();
    c.scale(size.width / 264, size.height / 295);
    final headBottom = partner == MannerPartner.monkey ? 165.0 : 174.0;
    c.clipRect(Rect.fromLTRB(0, headBottom, 264, 295));
    c.saveLayer(const Rect.fromLTWH(0, 0, 264, 295), Paint());
    final area = jacket;
    tint(c, area);
    if (outfit == 'bear') {
      tint(c, Path()..addRect(const Rect.fromLTWH(78, 247, 113, 19)));
    }
    c.save();
    c.clipPath(area);
    if (outfit == 'bear') {
      // Clear shirt/lapels inside the existing torso, not its outside contour.
      c.save();
      final upperPanel = Path()
        ..moveTo(91, 166)
        ..lineTo(169, 166)
        ..lineTo(176, 193)
        ..lineTo(93, 194)
        ..close();
      final panel = partner == MannerPartner.monkey
          ? Path.combine(PathOperation.union, torso, upperPanel)
          : torso;
      if (partner == MannerPartner.monkey) {
        c.clipPath(Path.combine(PathOperation.difference, panel, foldedArms));
      } else {
        c.clipPath(panel);
      }
      c.drawPath(panel, Paint()..color = cloth);
      stroke(
        c,
        Path()
          ..moveTo(105, 171)
          ..quadraticBezierTo(132, 190, 159, 171),
        width: 3,
      );
      final belly = Path()..addOval(const Rect.fromLTWH(111, 201, 41, 37));
      shape(c, belly, paper, width: 1.8);
      shape(
        c,
        Path()..addOval(const Rect.fromLTWH(118, 201, 9, 10)),
        paper,
        width: 1.5,
      );
      shape(
        c,
        Path()..addOval(const Rect.fromLTWH(137, 201, 9, 10)),
        paper,
        width: 1.5,
      );
      shape(
        c,
        Path()..addOval(const Rect.fromLTWH(123, 205, 18, 17)),
        paper,
        width: 1.5,
      );
      for (final x in [128.0, 136.0]) {
        c.drawCircle(Offset(x, 212), 1.3, Paint()..color = ink);
      }
      c.drawOval(const Rect.fromLTWH(130, 216, 4, 3), Paint()..color = ink);
      c.restore();
      // Original arm folds stay above the pajama belly, including the monkey's
      // crossed sleeves. The original trousers are recolored without moving feet.
    } else {
      c.save();
      if (partner == MannerPartner.monkey) {
        c.clipPath(Path.combine(PathOperation.difference, torso, foldedArms));
      }
      shape(
        c,
        Path()
          ..moveTo(87, 230)
          ..quadraticBezierTo(131, 235, 179, 230)
          ..lineTo(180, 239)
          ..quadraticBezierTo(132, 245, 86, 239)
          ..close(),
        cloth,
        width: 2.3,
      );
      shape(
        c,
        Path()..addRRect(
          RRect.fromRectAndRadius(
            const Rect.fromLTWH(126, 231, 15, 13),
            const Radius.circular(2),
          ),
        ),
        ink,
        width: 1.5,
      );
      c.drawRRect(
        RRect.fromRectAndRadius(
          const Rect.fromLTWH(130, 234, 7, 7),
          const Radius.circular(1),
        ),
        Paint()..color = cloth,
      );
      for (final x in [121.0, 145.0]) {
        for (final y in [212.0, 224.0]) {
          c.drawCircle(Offset(x, y), 2, Paint()..color = ink);
        }
      }
      stroke(
        c,
        Path()
          ..moveTo(96, 221)
          ..lineTo(108, 224),
        width: 2,
      );
      stroke(
        c,
        Path()
          ..moveTo(157, 224)
          ..lineTo(169, 221),
        width: 2,
      );
      c.restore();
    }
    c.restore();
    // The garment cannot extend beyond even one edge of the source silhouette.
    source(c, Paint()..blendMode = BlendMode.dstIn);
    c.restore();
    c.restore();
  }

  @override
  bool shouldRepaint(_OriginalGarmentPainter oldDelegate) =>
      image != oldDelegate.image ||
      partner != oldDelegate.partner ||
      outfit != oldDelegate.outfit;
}

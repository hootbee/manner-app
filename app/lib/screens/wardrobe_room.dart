import 'package:flutter/material.dart';
import 'wardrobe_visuals.dart';

/// Quiet room decoration, painted behind the interactive partner.
class WardrobeRoomPainter extends CustomPainter {
  const WardrobeRoomPainter();
  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 320, size.height / 224);
    final line = Paint()
      ..color = const Color(0xFFAAA69D)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    final fill = Paint();
    void rect(Rect r, Color c) => canvas.drawRect(r, fill..color = c);
    void oval(Rect r, Color c) => canvas.drawOval(r, fill..color = c);
    rect(const Rect.fromLTWH(0, 0, 320, 170), const Color(0xFFF0EDE5));
    rect(const Rect.fromLTWH(0, 170, 320, 54), const Color(0xFFD9D4C9));
    canvas.drawLine(const Offset(0, 170), const Offset(320, 170), line);
    canvas.drawLine(
      const Offset(0, 174),
      const Offset(320, 174),
      line..color = const Color(0xFFC3BDAF),
    );
    // A softly lit window with distant rooftops.
    final window = RRect.fromRectAndRadius(
      const Rect.fromLTWH(182, 22, 106, 116),
      const Radius.circular(3),
    );
    canvas.drawRRect(window, fill..color = const Color(0xFFC8D3D6));
    canvas.save();
    canvas.clipRRect(window);
    oval(const Rect.fromLTWH(195, 34, 34, 14), const Color(0xFFE4E8E6));
    for (final (x, y, w) in [
      (187.0, 99.0, 19.0),
      (211.0, 88.0, 24.0),
      (242.0, 105.0, 22.0),
      (268.0, 93.0, 18.0),
    ]) {
      rect(Rect.fromLTWH(x, y, w, 138 - y), const Color(0xFFB0BEC1));
    }
    canvas.restore();
    canvas.drawRRect(
      window,
      line
        ..color = const Color(0xFF918E87)
        ..strokeWidth = 2,
    );
    canvas.drawLine(const Offset(235, 22), const Offset(235, 138), line);
    canvas.drawLine(const Offset(182, 73), const Offset(288, 73), line);
    rect(const Rect.fromLTWH(176, 138, 118, 5), const Color(0xFFB9B4A8));
    // Curtains are outside the window, leaving the center clear for the partner.
    for (final left in [true, false]) {
      final x = left ? 172.0 : 280.0;
      final curtain = Path()
        ..moveTo(x, 19)
        ..lineTo(x + 20, 19)
        ..quadraticBezierTo(
          left ? x + 11 : x + 1,
          70,
          left ? x + 4 : x + 18,
          92,
        )
        ..lineTo(x + 20, 147)
        ..lineTo(x - 3, 147)
        ..close();
      canvas.drawPath(curtain, fill..color = const Color(0xFFD3CEC2));
      canvas.drawPath(
        curtain,
        line
          ..color = const Color(0xFFB7B1A5)
          ..strokeWidth = 1,
      );
      canvas.drawLine(Offset(x + 5, 24), Offset(x + 3, 137), line);
    }
    canvas.drawLine(
      const Offset(166, 18),
      const Offset(306, 18),
      line
        ..color = const Color(0xFF99958C)
        ..strokeWidth = 2,
    );
    // Pendant light and warm halo.
    oval(const Rect.fromLTWH(12, 24, 93, 82), const Color(0x16FFFFFF));
    canvas.drawLine(
      const Offset(55, 0),
      const Offset(55, 30),
      line..strokeWidth = 1,
    );
    final shade = Path()
      ..moveTo(42, 30)
      ..lineTo(68, 30)
      ..lineTo(77, 56)
      ..lineTo(33, 56)
      ..close();
    canvas.drawPath(shade, fill..color = const Color(0xFFFFFAE9));
    canvas.drawPath(shade, line);
    // Potted plant and oval rug, matching the room reference.
    oval(const Rect.fromLTWH(13, 191, 42, 7), const Color(0x22000000));
    canvas.drawLine(
      const Offset(34, 170),
      const Offset(34, 106),
      line..color = const Color(0xFF858B7B),
    );
    for (final (x, y, angle) in [
      (25.0, 123.0, -.6),
      (42.0, 115.0, .6),
      (24.0, 141.0, -.7),
      (43.0, 135.0, .7),
    ]) {
      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(angle);
      oval(const Rect.fromLTWH(-6, -11, 12, 22), const Color(0xFFA3AC96));
      canvas.drawOval(
        const Rect.fromLTWH(-6, -11, 12, 22),
        line..strokeWidth = .8,
      );
      canvas.restore();
    }
    final pot = Path()
      ..moveTo(20, 162)
      ..lineTo(48, 162)
      ..lineTo(44, 191)
      ..quadraticBezierTo(34, 196, 24, 191)
      ..close();
    canvas.drawPath(pot, fill..color = const Color(0xFFFFFDFA));
    canvas.drawPath(
      pot,
      line
        ..color = const Color(0xFFA19B8E)
        ..strokeWidth = 1.2,
    );
    oval(const Rect.fromLTWH(65, 184, 222, 31), const Color(0xFFF9F6EE));
    canvas.drawOval(
      const Rect.fromLTWH(65, 184, 222, 31),
      line..color = const Color(0xFFC4BDAF),
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(WardrobeRoomPainter oldDelegate) => false;
}

/// Theme art can later be replaced by photographic assets without changing state.
class WardrobeRoom extends StatelessWidget {
  const WardrobeRoom({
    super.key,
    this.background = 'bg-room',
    this.furniture = 'furniture-none',
    this.prop = 'prop-none',
  });
  final String background, furniture, prop;
  @override
  Widget build(BuildContext context) => ClipRect(
    child: Stack(
      fit: StackFit.expand,
      children: [
        CustomPaint(
          painter: background == 'bg-room'
              ? const WardrobeRoomPainter()
              : _ThemeRoomPainter(background),
        ),
        if (furniture != 'furniture-none')
          Align(
            alignment: const Alignment(-.87, .79),
            child: FractionallySizedBox(
              widthFactor: furniture == 'furniture-rug' ? .8 : .30,
              heightFactor: furniture == 'furniture-rug' ? .22 : .43,
              child: WardrobeItemArt(id: furniture),
            ),
          ),
        if (prop != 'prop-none')
          Align(
            alignment: const Alignment(.88, .83),
            child: FractionallySizedBox(
              widthFactor: .23,
              heightFactor: .28,
              child: WardrobeItemArt(id: prop),
            ),
          ),
      ],
    ),
  );
}

class _ThemeRoomPainter extends CustomPainter {
  const _ThemeRoomPainter(this.id);
  final String id;
  @override
  void paint(Canvas c, Size size) {
    c.save();
    c.scale(size.width / 320, size.height / 224);
    final night = id == 'bg-night' || id == 'bg-secret';
    final library = id == 'bg-library' || id == 'bg-secret';
    final sky = night ? const Color(0xFF29354E) : const Color(0xFFBCD6DF);
    final wall = night ? const Color(0xFF4B5055) : const Color(0xFFE4DFD4);
    final p = Paint();
    void rect(Rect r, Color color) {
      c.drawRect(r, p..color = color);
    }

    void line(Offset a, Offset b, Color color, {double width = 1}) {
      c.drawLine(
        a,
        b,
        p
          ..color = color
          ..strokeWidth = width,
      );
    }

    rect(const Rect.fromLTWH(0, 0, 320, 224), wall);
    c.drawRect(
      const Rect.fromLTWH(0, 0, 320, 176),
      Paint()
        ..shader = LinearGradient(
          colors: [wall, Color.lerp(wall, Colors.white, .3)!],
        ).createShader(const Rect.fromLTWH(0, 0, 320, 176)),
    );
    rect(
      const Rect.fromLTWH(0, 176, 320, 48),
      night ? const Color(0xFF49413A) : const Color(0xFFC5B39C),
    );
    for (var y = 184.0; y < 224; y += 13) {
      line(Offset(0, y), Offset(320, y), const Color(0xFFAC9C86));
    }
    for (var x = 0.0; x < 340; x += 64) {
      line(Offset(x, 176), Offset(x - 30, 224), const Color(0xFFAC9C86));
    }
    rect(const Rect.fromLTWH(87, 18, 211, 139), const Color(0xFF938A7C));
    rect(const Rect.fromLTWH(93, 24, 199, 127), sky);
    if (night) {
      c.drawCircle(
        const Offset(257, 49),
        13,
        p..color = const Color(0xFFF3EBCB),
      );
      for (var i = 0; i < 18; i++) {
        c.drawCircle(
          Offset(
            100 + (i * 37 % 186).toDouble(),
            31 + (i * 23 % 85).toDouble(),
          ),
          1,
          p..color = Colors.white70,
        );
      }
    }
    if (id != 'bg-night' && id != 'bg-park') {
      for (var i = 0; i < 10; i++) {
        final x = 95 + i * 20.0;
        final h = 30 + (i * 17 % 51).toDouble();
        rect(
          Rect.fromLTWH(x, 151 - h, 16, h),
          night ? const Color(0xFF1D2731) : const Color(0xFF9AA9AE),
        );
      }
    } else if (id == 'bg-park') {
      rect(const Rect.fromLTWH(0, 0, 320, 176), sky);
      for (var i = 0; i < 5; i++) {
        c.drawCircle(
          Offset(i * 83.0, 145),
          62,
          p
            ..color = Color.lerp(
              const Color(0xFFA2B593),
              const Color(0xFFD1D8B9),
              i / 5,
            )!,
        );
      }
      rect(const Rect.fromLTWH(0, 176, 320, 48), const Color(0xFFCBCAC0));
    }
    if (id != 'bg-park') {
      for (final x in [159.0, 225.0]) {
        rect(Rect.fromLTWH(x, 24, 4, 127), const Color(0xFFD1C9BA));
      }
      rect(const Rect.fromLTWH(93, 83, 199, 4), const Color(0xFFD1C9BA));
    }
    if (library) {
      rect(const Rect.fromLTWH(8, 10, 74, 169), const Color(0xFF544B40));
      for (var row = 0; row < 4; row++) {
        for (var j = 0; j < 7; j++) {
          rect(
            Rect.fromLTWH(13 + j * 9.0, 20 + row * 38.0, 6, 27 - (j % 3) * 3.0),
            Color.lerp(
              const Color(0xFF9E8B6D),
              const Color(0xFF555C53),
              j / 7,
            )!,
          );
        }
        rect(Rect.fromLTWH(8, 49 + row * 38.0, 74, 4), const Color(0xFF88765D));
      }
    }
    if (id == 'bg-office' ||
        id == 'bg-secret' ||
        id == 'bg-study' ||
        id == 'bg-digital') {
      rect(const Rect.fromLTWH(180, 143, 132, 7), const Color(0xFF635F56));
      rect(const Rect.fromLTWH(188, 150, 7, 39), const Color(0xFF635F56));
      rect(const Rect.fromLTWH(301, 150, 7, 39), const Color(0xFF635F56));
      rect(const Rect.fromLTWH(227, 105, 52, 34), const Color(0xFF343C3F));
      rect(const Rect.fromLTWH(230, 108, 46, 27), const Color(0xFFA4BEC3));
      rect(const Rect.fromLTWH(249, 137, 6, 6), const Color(0xFF343C3F));
    }
    if (id == 'bg-cafe' || id == 'bg-dining') {
      c.drawOval(
        const Rect.fromLTWH(192, 141, 105, 18),
        p..color = const Color(0xFFEDE5D7),
      );
      rect(const Rect.fromLTWH(239, 156, 7, 35), const Color(0xFF827260));
      c.drawOval(
        const Rect.fromLTWH(227, 132, 17, 10),
        p..color = Colors.white,
      );
      rect(const Rect.fromLTWH(230, 126, 11, 10), Colors.white);
    }
    c.drawOval(
      const Rect.fromLTWH(64, 188, 201, 26),
      p..color = night ? const Color(0xFF787366) : const Color(0xFFEDE8DD),
    );
    c.restore();
  }

  @override
  bool shouldRepaint(_ThemeRoomPainter oldDelegate) => id != oldDelegate.id;
}

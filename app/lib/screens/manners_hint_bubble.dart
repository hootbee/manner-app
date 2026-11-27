import 'package:flutter/material.dart';
import 'partner_selection_screen.dart';

/// Stable geometry for both hint stages; only the body scrolls with large text.
class MannersHintBubble extends StatelessWidget {
  const MannersHintBubble({
    super.key,
    required this.partner,
    required this.stage,
    this.hintMessages = messages,
    this.profileAsset,
    this.fitLongestMessage = false,
  });
  final MannerPartner partner;
  final int stage;
  final List<String> hintMessages;
  final String? profileAsset;
  final bool fitLongestMessage;
  static const messages = [
    '등에 멘 가방이 다른 승객과 부딪히고 있어요. 어디로 옮기면 좋을까요?',
    '가방을 몸 가까이 관리하면 다른 승객과 부딪힐 위험을 줄일 수 있어요.',
  ];

  @override
  Widget build(BuildContext context) {
    if (!fitLongestMessage) return _bubble(context, 84);
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = (constraints.maxWidth - 56 - 8 - 32).clamp(
          1.0,
          double.infinity,
        );
        var height = 84.0;
        for (final text in hintMessages) {
          final painter = TextPainter(
            text: TextSpan(
              text: text,
              style: DefaultTextStyle.of(context).style.merge(
                const TextStyle(
                  fontSize: 13,
                  height: 1.5,
                  color: Color(0xFF191D1A),
                ),
              ),
            ),
            textDirection: Directionality.of(context),
            textScaler: MediaQuery.textScalerOf(context),
          )..layout(maxWidth: width);
          final candidate = painter.height + 36;
          if (candidate > height) height = candidate;
          painter.dispose();
        }
        return _bubble(context, height);
      },
    );
  }

  Widget _bubble(BuildContext context, double bodyHeight) => SizedBox(
    height: bodyHeight + 12,
    child: Row(
      children: [
        Semantics(
          label: '${partner.name}의 힌트',
          image: true,
          child: ClipOval(
            child: Image.asset(
              profileAsset ??
                  'assets/subway01/${partner.name == '댕댕이'
                      ? 'dog'
                      : partner.name == '냥냥이'
                      ? 'cat'
                      : 'monkey'}_thinking.png',
              key: const Key('hint-profile'),
              width: 56,
              height: 56,
              fit: BoxFit.contain,
              cacheWidth: 224,
              cacheHeight: 224,
              excludeFromSemantics: true,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: 1),
            builder: (context, opacity, child) =>
                Opacity(opacity: opacity, child: child),
            duration: Duration(
              milliseconds: MediaQuery.disableAnimationsOf(context) ? 0 : 200,
            ),
            child: CustomPaint(
              key: const Key('hint-bubble'),
              painter: const _BubbleOutline(),
              child: SizedBox(
                height: bodyHeight,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 6,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        height: 22,
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF0F0F0),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                '힌트 $stage/2',
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        child: SingleChildScrollView(
                          key: ValueKey('hint-body-$stage'),
                          child: Text(
                            hintMessages[stage - 1],
                            textAlign: TextAlign.left,
                            style: const TextStyle(
                              fontSize: 13,
                              height: 1.4,
                              color: Color(0xFF191D1A),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    ),
  );
}

class _BubbleOutline extends CustomPainter {
  const _BubbleOutline({this.body, this.tailTip, this.strokeWidth = 1.2});
  final Rect? body;
  final Offset? tailTip;
  final double strokeWidth;
  @override
  void paint(Canvas canvas, Size size) {
    if (body case final Rect oval) {
      final tip = tailTip!;
      final tail = Path()
        ..moveTo(oval.left + oval.width * .47, oval.bottom - 8)
        ..quadraticBezierTo(tip.dx - 25, tip.dy - 4, tip.dx, tip.dy)
        ..quadraticBezierTo(
          tip.dx - 10,
          tip.dy - 18,
          oval.left + oval.width * .57,
          oval.bottom - 8,
        )
        ..close();
      final outline = Path.combine(
        PathOperation.union,
        Path()..addOval(oval),
        tail,
      );
      canvas.drawPath(outline, Paint()..color = Colors.white);
      canvas.drawPath(
        outline,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = strokeWidth
          ..color = const Color(0xFF191D1A),
      );
      return;
    }
    final rect = Path()
      ..addRRect(
        RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(14)),
      );
    final tail = Path()
      ..moveTo(1, 33)
      ..lineTo(-7, 42)
      ..lineTo(1, 51)
      ..close();
    final outline = Path.combine(PathOperation.union, rect, tail);
    canvas.drawPath(outline, Paint()..color = Colors.white);
    canvas.drawPath(
      outline,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..color = const Color(0xFF191D1A),
    );
  }

  @override
  bool shouldRepaint(_BubbleOutline oldDelegate) =>
      body != oldDelegate.body ||
      tailTip != oldDelegate.tailTip ||
      strokeWidth != oldDelegate.strokeWidth;
}

/// Scene-sized variant of the existing native bubble; never uses a raster label.
class MannersSceneSpeechBubble extends StatelessWidget {
  const MannersSceneSpeechBubble({
    super.key,
    required this.text,
    required this.body,
    required this.tailTip,
    required this.strokeWidth,
  });
  final String text;
  final Rect body;
  final Offset tailTip;
  final double strokeWidth;
  @override
  Widget build(BuildContext context) => Semantics(
    label: text.replaceAll('\n', ' '),
    child: CustomPaint(
      key: const Key('scene-speech-bubble'),
      painter: _BubbleOutline(
        body: body,
        tailTip: tailTip,
        strokeWidth: strokeWidth,
      ),
      child: Stack(
        children: [
          Positioned.fromRect(
            rect: body.deflate(18),
            child: Center(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: ExcludeSemantics(
                  child: Text(
                    text,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontFamily: 'Pretendard',
                      fontSize: 60,
                      height: 1.25,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF191D1A),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

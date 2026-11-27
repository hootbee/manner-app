import 'package:flutter/material.dart';
import 'sequence_lesson_state.dart';

/// Sliver-based shared list: one parent scroll view handles scrolling and drag auto-scroll.
class SequenceCardList extends StatelessWidget {
  const SequenceCardList({
    super.key,
    required this.state,
    required this.assetPrefix,
    this.shake = 0,
    this.cardAnchors = const {},
  });
  final SequenceLessonState state;
  final String assetPrefix;
  final double shake;
  final Map<String, GlobalKey> cardAnchors;
  @override
  Widget build(BuildContext context) => SliverReorderableList(
    itemCount: state.order.length,
    // ignore: deprecated_member_use
    onReorder: state.reorder,
    onReorderStart: (_) => state.startDrag(),
    onReorderEnd: (_) => state.endDrag(),
    proxyDecorator: (child, index, animation) => AnimatedBuilder(
      animation: animation,
      child: child,
      builder: (context, child) => Transform.scale(
        scale: MediaQuery.disableAnimationsOf(context)
            ? 1
            : 1 + .02 * animation.value,
        child: Material(
          color: Colors.transparent,
          elevation: MediaQuery.disableAnimationsOf(context)
              ? 0
              : 4 * animation.value,
          borderRadius: BorderRadius.circular(16),
          child: child,
        ),
      ),
    ),
    itemBuilder: (context, index) {
      final id = state.order[index], card = state.question.card(id);
      final pictureHeight = MediaQuery.sizeOf(context).width < 360
          ? 64.0
          : 72.0;
      // Until final square art arrives, a wider frame improves the full landscape
      // picture without stretching or cropping. Square data uses a square frame.
      final pictureWidth = card.thumbnailAspectRatio > 1.3
          ? (pictureHeight == 64 ? 80.0 : 96.0)
          : pictureHeight;
      return Padding(
        key: ValueKey(id),
        padding: const EdgeInsets.only(bottom: 12),
        child: Transform.translate(
          key: ValueKey('sequence-offset-$id'),
          offset: Offset(shake, 0),
          child: Container(
            key: cardAnchors[id],
            constraints: const BoxConstraints(minHeight: 88),
            padding: const EdgeInsets.fromLTRB(12, 12, 8, 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE1E1E1)),
            ),
            child: Row(
              children: [
                SizedBox(
                  key: ValueKey('sequence-thumbnail-$id'),
                  width: pictureWidth,
                  height: pictureHeight,
                  child: Padding(
                    // Approved square art already includes its rounded frame.
                    // Keep the complete picture, without a second crop or inset.
                    padding: EdgeInsets.all(
                      card.thumbnailAspectRatio > 1.3 ? 4 : 0,
                    ),
                    child: Image.asset(
                      '$assetPrefix${card.thumbnail}',
                      fit: BoxFit.contain,
                      excludeFromSemantics: true,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, space) {
                      const regular = TextStyle(
                        fontSize: 16,
                        height: 1.4,
                        fontWeight: FontWeight.w600,
                      );
                      const compact = TextStyle(
                        fontSize: 15,
                        height: 1.4,
                        fontWeight: FontWeight.w600,
                      );
                      final scaler = MediaQuery.textScalerOf(context);
                      double textWidth(TextStyle style) =>
                          TextPainter.computeWidth(
                            text: TextSpan(
                              text: card.label,
                              style: DefaultTextStyle.of(
                                context,
                              ).style.merge(style),
                            ),
                            textDirection: Directionality.of(context),
                            textScaler: scaler,
                          );
                      // Prefer one line when a modest 1sp adjustment is enough.
                      // Never shrink accessibility text or truncate a long label.
                      final useCompact =
                          scaler.scale(16) <= 16 &&
                          textWidth(regular) > space.maxWidth &&
                          textWidth(compact) <= space.maxWidth;
                      return Text(
                        card.label,
                        key: ValueKey('sequence-label-$id'),
                        style: useCompact ? compact : regular,
                      );
                    },
                  ),
                ),
                const SizedBox(width: 4),
                ReorderableDragStartListener(
                  index: index,
                  enabled: state.canEdit,
                  child: Semantics(
                    label: '${card.label} 순서 바꾸기',
                    child: SizedBox(
                      key: ValueKey('sequence-handle-$id'),
                      width: 44,
                      height: 44,
                      child: Center(
                        child: CustomPaint(
                          size: const Size(14, 22),
                          painter: const _GripPainter(),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}

class _GripPainter extends CustomPainter {
  const _GripPainter();
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()..color = const Color(0xFF8A8D8A);
    for (var row = 0; row < 3; row++) {
      for (var col = 0; col < 2; col++) {
        canvas.drawCircle(Offset(3 + col * 8, 3 + row * 8), 2, p);
      }
    }
  }

  @override
  bool shouldRepaint(_GripPainter oldDelegate) => false;
}

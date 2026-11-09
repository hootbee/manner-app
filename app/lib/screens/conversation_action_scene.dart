import 'dart:async';
import 'package:flutter/material.dart';

class ConversationSceneArtwork extends StatelessWidget {
  const ConversationSceneArtwork({super.key, required this.panel});
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
          minWidth: 1024,
          maxWidth: 1024,
          minHeight: 1024,
          maxHeight: 1024,
          child: Transform.translate(
            offset: Offset(-(panel % 2) * 512.0, -(panel ~/ 2) * 512.0),
            child: Image.asset(
              'assets/conversation/action_scenes.webp',
              width: 1024,
              height: 1024,
              fit: BoxFit.contain,
            ),
          ),
        ),
      ),
    ),
  );
}

class ConversationActionScene extends StatefulWidget {
  const ConversationActionScene({
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
  State<ConversationActionScene> createState() =>
      _ConversationActionSceneState();
}

class _ConversationActionSceneState extends State<ConversationActionScene> {
  Timer? _speech;
  bool speaking = true, moving = false;
  Offset phone = const Offset(.2, .67);
  Offset? touch;
  bool correct = false;
  @override
  void initState() {
    super.initState();
    if (widget.number == 2) {
      _speech = Timer(const Duration(seconds: 3), () {
        if (mounted) setState(() => speaking = false);
      });
    }
  }

  @override
  void dispose() {
    _speech?.cancel();
    super.dispose();
  }

  void tap(Offset p, bool ok) {
    setState(() {
      touch = p;
      correct = ok;
    });
    widget.onAnswer(ok);
  }

  @override
  Widget build(BuildContext context) => AspectRatio(
    key: const ValueKey('conversation-action'),
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
                  onTapUp: widget.answered || widget.number == 6
                      ? null
                      : (d) {
                          final p = Offset(
                            d.localPosition.dx / w,
                            d.localPosition.dy / h,
                          );
                          tap(
                            p,
                            widget.number == 2
                                ? !speaking &&
                                      const Rect.fromLTWH(
                                        .56,
                                        .65,
                                        .42,
                                        .33,
                                      ).contains(p)
                                : const Rect.fromLTWH(
                                    .14,
                                    .5,
                                    .36,
                                    .47,
                                  ).contains(p),
                          );
                        },
                  child: ConversationSceneArtwork(
                    panel: widget.number == 2
                        ? (widget.success ? 1 : 0)
                        : (widget.success || (widget.number == 6 && moving)
                              ? 3
                              : 2),
                  ),
                ),
              ),
              if (widget.number == 2 && !widget.answered) ...[
                Positioned(
                  left: 12,
                  top: 12,
                  right: 12,
                  child: IgnorePointer(
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: .95),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(
                        speaking ? '친구가 이야기하고 있어요…' : '친구의 이야기가 끝났어요.',
                        key: const ValueKey('conversation-speaking'),
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: w * .56,
                  top: h * .65,
                  width: w * .42,
                  height: h * .33,
                  child: IgnorePointer(
                    child: Container(
                      key: const ValueKey('my-speech-bubble'),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: .95),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: Colors.black26),
                      ),
                      child: const Icon(Icons.chat_bubble_outline, size: 30),
                    ),
                  ),
                ),
              ],
              if (widget.number == 6 && !widget.answered)
                AnimatedPositioned(
                  duration: Duration(milliseconds: moving ? 0 : 250),
                  left: phone.dx * w,
                  top: phone.dy * h,
                  width: w * .18,
                  height: h * .25,
                  child: GestureDetector(
                    key: const ValueKey('conversation-phone'),
                    behavior: HitTestBehavior.opaque,
                    onLongPressStart: (_) => setState(() => moving = true),
                    onLongPressMoveUpdate: (d) => setState(
                      () => phone = Offset(
                        (.2 + d.offsetFromOrigin.dx / w).clamp(0, .82),
                        (.67 + d.offsetFromOrigin.dy / h).clamp(0, .75),
                      ),
                    ),
                    onLongPressEnd: (_) {
                      final ok = const Rect.fromLTWH(
                        .72,
                        .62,
                        .28,
                        .37,
                      ).contains(Offset(phone.dx + .09, phone.dy + .12));
                      setState(() {
                        moving = false;
                        if (!ok) phone = const Offset(.2, .67);
                      });
                      widget.onAnswer(ok);
                    },
                    child: moving
                        ? const Icon(
                            Icons.smartphone,
                            size: 60,
                            color: Colors.black,
                          )
                        : const SizedBox.expand(),
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

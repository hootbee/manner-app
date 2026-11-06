import 'package:flutter/material.dart';

class PublicSceneArtwork extends StatelessWidget {
  const PublicSceneArtwork({super.key, required this.panel});
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
              'assets/public/action_scenes.png',
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

class PublicActionScene extends StatefulWidget {
  const PublicActionScene({
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
  State<PublicActionScene> createState() => _PublicActionSceneState();
}

class _PublicActionSceneState extends State<PublicActionScene> {
  Offset? touch;
  bool correct = false, moving = false;
  Offset bag = const Offset(.35, .7);
  void _tap(Offset p, bool value) {
    setState(() {
      touch = p;
      correct = value;
    });
    widget.onAnswer(value);
  }

  @override
  Widget build(BuildContext context) => AspectRatio(
    key: const ValueKey('public-action'),
    aspectRatio: 1,
    child: LayoutBuilder(
      builder: (context, c) {
        final w = c.maxWidth, h = c.maxHeight;
        return ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Stack(
            children: [
              if (widget.number == 4 && !widget.answered)
                Positioned.fill(
                  child: Container(
                    color: const Color(0xFFF4F4F4),
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      children: [
                        const Padding(
                          padding: EdgeInsets.all(10),
                          child: Text(
                            '휴대전화 설정',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                        Expanded(
                          child: GridView.count(
                            physics: const NeverScrollableScrollPhysics(),
                            crossAxisCount: 2,
                            mainAxisSpacing: 8,
                            crossAxisSpacing: 8,
                            children: List.generate(
                              4,
                              (i) => Material(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(18),
                                child: InkWell(
                                  key: ValueKey('phone-setting-$i'),
                                  onTapUp: (details) {
                                    final box =
                                        context.findRenderObject() as RenderBox;
                                    final point = box.globalToLocal(
                                      details.globalPosition,
                                    );
                                    _tap(
                                      Offset(point.dx / w, point.dy / h),
                                      i == 0,
                                    );
                                  },
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        [
                                          Icons.notifications_off_outlined,
                                          Icons.brightness_6_outlined,
                                          Icons.camera_alt_outlined,
                                          Icons.music_note_outlined,
                                        ][i],
                                        size: 32,
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        ['무음 모드', '화면 밝기', '카메라', '음악 재생'][i],
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
                  ),
                ),
              if (widget.number != 4 || widget.answered)
                Positioned.fill(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTapUp: widget.answered || widget.number == 2
                        ? null
                        : (d) {
                            final p = Offset(
                              d.localPosition.dx / w,
                              d.localPosition.dy / h,
                            );
                            _tap(
                              p,
                              const Rect.fromLTWH(
                                .2,
                                .48,
                                .37,
                                .43,
                              ).contains(p),
                            );
                          },
                    child: PublicSceneArtwork(
                      panel: widget.number == 2
                          ? 0
                          : widget.number == 4
                          ? 5
                          : widget.success
                          ? 4
                          : 1,
                    ),
                  ),
                ),
              if (widget.number == 2 && !widget.answered) ...[
                Positioned(
                  left: w * .31,
                  top: h * .68,
                  width: w * .37,
                  height: h * .28,
                  child: const IgnorePointer(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Color(0xFFEEEEEE), Color(0xFFE6E6E6)],
                        ),
                      ),
                    ),
                  ),
                ),
                AnimatedPositioned(
                  duration: Duration(milliseconds: moving ? 0 : 250),
                  left: bag.dx * w,
                  top: bag.dy * h,
                  width: w * .26,
                  height: h * .22,
                  child: GestureDetector(
                    key: const ValueKey('public-bag'),
                    onLongPressStart: (_) => setState(() => moving = true),
                    onLongPressMoveUpdate: (d) => setState(
                      () => bag = Offset(
                        (.35 + d.offsetFromOrigin.dx / w).clamp(0, .74),
                        (.7 + d.offsetFromOrigin.dy / h).clamp(0, .78),
                      ),
                    ),
                    onLongPressEnd: (_) {
                      final ok = const Rect.fromLTWH(
                        .7,
                        .28,
                        .29,
                        .65,
                      ).contains(Offset(bag.dx + .13, bag.dy + .11));
                      setState(() {
                        moving = false;
                        if (!ok) bag = const Offset(.35, .7);
                      });
                      widget.onAnswer(ok);
                    },
                    child: const Icon(
                      Icons.work_rounded,
                      size: 65,
                      color: Color(0xFF333333),
                    ),
                  ),
                ),
              ],
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

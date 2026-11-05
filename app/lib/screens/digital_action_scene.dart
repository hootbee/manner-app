import 'package:flutter/material.dart';

/// Reference art only: screenshot text and controls are never part of the UI.
class DigitalReferenceArt extends StatelessWidget {
  const DigitalReferenceArt({super.key, required this.number});
  final int number;
  @override
  Widget build(BuildContext context) => FittedBox(
    fit: BoxFit.contain,
    child: SizedBox(
      width: 370,
      height: 345,
      child: ClipRect(
        child: OverflowBox(
          alignment: Alignment.topLeft,
          minWidth: 941,
          maxWidth: 941,
          minHeight: 1672,
          maxHeight: 1672,
          child: Transform.translate(
            offset: const Offset(-495, -278),
            child: Image.asset(
              'assets/digital/question_$number.png',
              width: 941,
              height: 1672,
              fit: BoxFit.contain,
            ),
          ),
        ),
      ),
    ),
  );
}

class DigitalActionScene extends StatefulWidget {
  const DigitalActionScene({
    super.key,
    required this.number,
    required this.answered,
    required this.success,
    required this.placements,
    required this.onPlacement,
    required this.onAnswer,
  });
  final int number;
  final bool answered, success;
  final Map<String, String> placements;
  final void Function(String, String) onPlacement;
  final ValueChanged<bool> onAnswer;
  @override
  State<DigitalActionScene> createState() => _DigitalActionSceneState();
}

class _DigitalActionSceneState extends State<DigitalActionScene> {
  Offset? touch;
  bool correct = false;
  final positions = <String, Offset>{};
  void tap(Offset p, bool ok) {
    if (widget.answered) return;
    setState(() {
      touch = p;
      correct = ok;
    });
    widget.onAnswer(ok);
  }

  Widget window(String title, IconData icon, {bool sensitive = false}) =>
      Container(
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: Colors.black54, width: 2),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: const BoxDecoration(
                color: Color(0xFF555555),
                borderRadius: BorderRadius.vertical(top: Radius.circular(7)),
              ),
              child: Row(
                children: [
                  Icon(icon, size: 15, color: Colors.white),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(color: Colors.white, fontSize: 11),
                    ),
                  ),
                  const Icon(Icons.close, size: 16, color: Colors.white),
                ],
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(9),
                child: sensitive
                    ? Column(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: List.generate(
                          3,
                          (i) => Container(height: 8, color: Colors.black12),
                        ),
                      )
                    : const Center(
                        child: Icon(
                          Icons.bar_chart,
                          size: 45,
                          color: Colors.black54,
                        ),
                      ),
              ),
            ),
          ],
        ),
      );
  @override
  Widget build(BuildContext context) => AspectRatio(
    key: const ValueKey('digital-action'),
    aspectRatio: 1,
    child: LayoutBuilder(
      builder: (context, c) {
        final w = c.maxWidth, h = c.maxHeight;
        return ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Container(
            color: const Color(0xFFF0F0F0),
            child: Stack(
              children: [
                if (widget.number == 2) ...[
                  Positioned(
                    left: w * .08,
                    top: h * .14,
                    width: w * .84,
                    height: h * .72,
                    child: Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFFD2D2D2),
                        border: Border.all(color: Colors.black54, width: 2),
                        borderRadius: BorderRadius.circular(15),
                      ),
                    ),
                  ),
                  Positioned(
                    left: w * .14,
                    top: h * .28,
                    width: w * .72,
                    height: h * .44,
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        border: Border.all(color: Colors.black54),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      padding: const EdgeInsets.all(9),
                      child: widget.success
                          ? const Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.visibility_off_outlined, size: 40),
                                  SizedBox(height: 8),
                                  Text(
                                    '개인정보를 가렸어요',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  SizedBox(height: 6),
                                  SizedBox(
                                    width: 130,
                                    height: 8,
                                    child: ColoredBox(color: Colors.black54),
                                  ),
                                ],
                              ),
                            )
                          : const Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: [
                                Text(
                                  '받는 사람  홍길동',
                                  style: TextStyle(fontSize: 12),
                                ),
                                Text(
                                  '배송지  서울시 예시로 123',
                                  style: TextStyle(fontSize: 12),
                                ),
                                Text(
                                  '연락처  010-1234-5678',
                                  style: TextStyle(fontSize: 12),
                                ),
                                Icon(Icons.qr_code, size: 28),
                              ],
                            ),
                    ),
                  ),
                  if (!widget.answered)
                    Positioned.fill(
                      child: GestureDetector(
                        key: const ValueKey('digital-label'),
                        behavior: HitTestBehavior.opaque,
                        onTapUp: (d) {
                          final p = Offset(
                            d.localPosition.dx / w,
                            d.localPosition.dy / h,
                          );
                          tap(
                            p,
                            const Rect.fromLTWH(.13, .27, .74, .46).contains(p),
                          );
                        },
                      ),
                    ),
                  Positioned(
                    bottom: 10,
                    left: 0,
                    right: 0,
                    child: Text(
                      widget.success ? '공유할 준비가 되었어요' : '사진에서 가릴 정보를 찾아보세요',
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                ] else if (widget.number == 10) ...[
                  Positioned(
                    left: w * .06,
                    top: h * .12,
                    width: w * .88,
                    height: h * .75,
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF333333),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Container(
                        color: Colors.white,
                        child: widget.success
                            ? const Center(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.lock, size: 55),
                                    SizedBox(height: 12),
                                    Text(
                                      '화면이 잠겼어요',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    Text(
                                      '개인 자료를 보호하고 있어요',
                                      style: TextStyle(fontSize: 11),
                                    ),
                                  ],
                                ),
                              )
                            : GridView.count(
                                physics: const NeverScrollableScrollPhysics(),
                                padding: const EdgeInsets.all(14),
                                crossAxisCount: 2,
                                mainAxisSpacing: 12,
                                crossAxisSpacing: 12,
                                children: List.generate(
                                  4,
                                  (i) => OutlinedButton(
                                    key: ValueKey('digital-lock-$i'),
                                    onPressed: widget.answered
                                        ? null
                                        : () => tap(
                                            Offset(
                                              .3 + (i % 2) * .4,
                                              .36 + (i ~/ 2) * .3,
                                            ),
                                            i == 0,
                                          ),
                                    child: Icon(
                                      [
                                        Icons.lock_outline,
                                        Icons.music_note,
                                        Icons.search,
                                        Icons.add_box_outlined,
                                      ][i],
                                      size: 32,
                                      color: Colors.black,
                                    ),
                                  ),
                                ),
                              ),
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 15,
                    left: w * .02,
                    right: w * .02,
                    height: 12,
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.black26,
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ] else ...[
                  Positioned(
                    left: w * .02,
                    top: h * .03,
                    width: w * .96,
                    height: h * .94,
                    child: Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFFDDDDDD),
                        border: Border.all(color: Colors.black54, width: 3),
                        borderRadius: BorderRadius.circular(15),
                      ),
                    ),
                  ),
                  Positioned(
                    left: w * .08,
                    top: h * .12,
                    width: w * .55,
                    height: h * .5,
                    child: GestureDetector(
                      key: const ValueKey('digital-project'),
                      onLongPress: widget.answered
                          ? null
                          : () => tap(const Offset(.3, .3), false),
                      child: window('프로젝트 진행 현황', Icons.bar_chart),
                    ),
                  ),
                  if (!widget.answered)
                    Positioned(
                      left: w * .7,
                      top: h * .06,
                      width: w * .25,
                      height: h * .2,
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: .9),
                          border: Border.all(color: Colors.black38),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.close, size: 25),
                            Text(
                              '닫기',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  for (var i = 0; i < 2; i++)
                    if (!widget.placements.containsKey(
                          ['messenger', 'contacts'][i],
                        ) &&
                        !widget.success)
                      Positioned(
                        left:
                            (positions[['messenger', 'contacts'][i]] ??
                                    Offset(.13 + i * .45, .52))
                                .dx *
                            w,
                        top:
                            (positions[['messenger', 'contacts'][i]] ??
                                    const Offset(.13, .52))
                                .dy *
                            h,
                        width: w * .36,
                        height: h * .37,
                        child: GestureDetector(
                          key: ValueKey(
                            'digital-window-${['messenger', 'contacts'][i]}',
                          ),
                          behavior: HitTestBehavior.opaque,
                          onLongPressStart: widget.answered ? null : (_) {},
                          onLongPressMoveUpdate: widget.answered
                              ? null
                              : (d) => setState(
                                  () =>
                                      positions[[
                                        'messenger',
                                        'contacts',
                                      ][i]] = Offset(
                                        (.13 +
                                                i * .45 +
                                                d.offsetFromOrigin.dx / w)
                                            .clamp(0, .64),
                                        (.52 + d.offsetFromOrigin.dy / h).clamp(
                                          0,
                                          .63,
                                        ),
                                      ),
                                ),
                          onLongPressEnd: widget.answered
                              ? null
                              : (_) {
                                  final id = ['messenger', 'contacts'][i];
                                  final p =
                                      (positions[id] ??
                                          Offset(.13 + i * .45, .52)) +
                                      const Offset(.18, .185);
                                  final ok = const Rect.fromLTWH(
                                    .67,
                                    0,
                                    .33,
                                    .35,
                                  ).contains(p);
                                  setState(() {
                                    positions.remove(id);
                                  });
                                  if (!ok) {
                                    tap(p, false);
                                    return;
                                  }
                                  widget.onPlacement(id, 'closed');
                                  if (widget.placements.containsKey(
                                    i == 0 ? 'contacts' : 'messenger',
                                  )) {
                                    widget.onAnswer(true);
                                  }
                                },
                          child: window(
                            i == 0 ? '개인 메신저' : '연락처',
                            i == 0
                                ? Icons.chat_bubble_outline
                                : Icons.contacts_outlined,
                            sensitive: true,
                          ),
                        ),
                      ),
                  if (widget.success)
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 18,
                      child: const Text(
                        '개인 창을 닫았어요 · 프로젝트만 공유해요',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                ],
                if (touch != null)
                  Positioned(
                    left: (touch!.dx * w - 17).clamp(0, w - 34),
                    top: (touch!.dy * h - 17).clamp(0, h - 34),
                    child: IgnorePointer(
                      child: CircleAvatar(
                        radius: 17,
                        backgroundColor: correct
                            ? const Color(0xFF31815A)
                            : const Color(0xFFD84C50),
                        child: Text(
                          correct ? 'O' : 'X',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 22,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    ),
  );
}

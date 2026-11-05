import 'package:flutter/material.dart';

class SchoolSceneArtwork extends StatelessWidget {
  const SchoolSceneArtwork({super.key, required this.panel});
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
              'assets/school-work/action_scenes.png',
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

class SchoolActionScene extends StatefulWidget {
  const SchoolActionScene({
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
  State<SchoolActionScene> createState() => _SchoolActionSceneState();
}

class _SchoolActionSceneState extends State<SchoolActionScene> {
  final positions = <String, Offset>{};
  String? moving;
  int? selectedAction;
  @override
  Widget build(BuildContext context) => Column(
    children: [
      AspectRatio(
        key: const ValueKey('school-action'),
        aspectRatio: 1,
        child: LayoutBuilder(
          builder: (context, c) {
            final w = c.maxWidth, h = c.maxHeight;
            final table = widget.number == 5;
            final items = table
                ? ['laptop', 'book', 'cup']
                : ['own-paper', 'other-paper'];
            Offset start(int i) => Offset(.12 + i * .29, .43);
            return ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Stack(
                children: [
                  Positioned.fill(
                    child: SchoolSceneArtwork(
                      panel: widget.number == 3
                          ? (widget.success ? 3 : 0)
                          : widget.number == 5
                          ? 1
                          : 2,
                    ),
                  ),
                  if (widget.number != 3 && !widget.answered) ...[
                    for (var i = 0; i < items.length; i++)
                      if (!widget.placements.containsKey(items[i]))
                        AnimatedPositioned(
                          duration: Duration(
                            milliseconds: moving == items[i] ? 0 : 250,
                          ),
                          left: (positions[items[i]] ?? start(i)).dx * w,
                          top: (positions[items[i]] ?? start(i)).dy * h,
                          width: w * .23,
                          height: h * .25,
                          child: GestureDetector(
                            key: ValueKey('school-object-${items[i]}'),
                            behavior: HitTestBehavior.opaque,
                            onLongPressStart: (_) =>
                                setState(() => moving = items[i]),
                            onLongPressMoveUpdate: (d) => setState(
                              () => positions[items[i]] = Offset(
                                (start(i).dx + d.offsetFromOrigin.dx / w).clamp(
                                  0,
                                  .77,
                                ),
                                (start(i).dy + d.offsetFromOrigin.dy / h).clamp(
                                  0,
                                  .75,
                                ),
                              ),
                            ),
                            onLongPressEnd: (_) {
                              final id = items[i],
                                  p =
                                      (positions[id] ?? start(i)) +
                                      const Offset(.115, .125);
                              final target = table
                                  ? (id == 'cup' ? 'bin' : 'bag')
                                  : 'storage';
                              final rect = table
                                  ? (target == 'bag'
                                        ? const Rect.fromLTWH(.02, .7, .43, .3)
                                        : const Rect.fromLTWH(.57, .7, .43, .3))
                                  : const Rect.fromLTWH(.63, .65, .37, .35);
                              final ok =
                                  id != 'other-paper' && rect.contains(p);
                              setState(() {
                                moving = null;
                                positions.remove(id);
                              });
                              if (!ok) {
                                widget.onAnswer(false);
                                return;
                              }
                              widget.onPlacement(id, target);
                              final completed = {
                                ...widget.placements,
                                id: target,
                              };
                              if ((table
                                      ? ['laptop', 'book', 'cup']
                                      : ['own-paper'])
                                  .every(completed.containsKey)) {
                                widget.onAnswer(true);
                              }
                            },
                            child: Container(
                              padding: const EdgeInsets.all(3),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: .93),
                                border: Border.all(color: Colors.black26),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    table
                                        ? [
                                            Icons.laptop,
                                            Icons.menu_book,
                                            Icons.local_drink_outlined,
                                          ][i]
                                        : Icons.description_outlined,
                                    size: 32,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    table
                                        ? ['노트북', '책', '빈 컵'][i]
                                        : i == 0
                                        ? '내 출력물'
                                        : '다른 사람 출력물',
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                    Positioned(
                      left: table ? w * .02 : w * .63,
                      bottom: 0,
                      width: table ? w * .43 : w * .37,
                      height: h * .3,
                      child: IgnorePointer(
                        child: _Target(
                          label: table ? '내 가방' : '내 보관함',
                          icon: table
                              ? Icons.backpack_outlined
                              : Icons.inventory_2_outlined,
                        ),
                      ),
                    ),
                    if (table)
                      Positioned(
                        right: 0,
                        bottom: 0,
                        width: w * .43,
                        height: h * .3,
                        child: const IgnorePointer(
                          child: _Target(
                            label: '정리함 · 빈 컵',
                            icon: Icons.recycling,
                          ),
                        ),
                      ),
                  ],
                ],
              ),
            );
          },
        ),
      ),
      if (widget.number == 3 && !widget.answered)
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Row(
            children: List.generate(
              3,
              (i) => Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 3),
                  child: OutlinedButton(
                    key: ValueKey('meeting-action-$i'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 2,
                        vertical: 12,
                      ),
                    ),
                    onPressed: () {
                      setState(() => selectedAction = i);
                      widget.onAnswer(i == 0);
                    },
                    child: Column(
                      children: [
                        Icon(
                          [
                            Icons.front_hand_outlined,
                            Icons.slideshow,
                            Icons.phone_android,
                          ][i],
                          color: Colors.black,
                        ),
                        if (selectedAction == i)
                          Text(
                            i == 0 ? 'O' : 'X',
                            style: TextStyle(
                              color: i == 0 ? Colors.green : Colors.red,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        const SizedBox(height: 4),
                        Text(
                          ['손들기', '발표 자료', '휴대전화'][i],
                          style: const TextStyle(
                            color: Colors.black,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
    ],
  );
}

class _Target extends StatelessWidget {
  const _Target({required this.label, required this.icon});
  final String label;
  final IconData icon;
  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.all(3),
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: .94),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: Colors.black26),
    ),
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, size: 30, color: Colors.black54),
        const SizedBox(height: 5),
        Text(
          label,
          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
        ),
      ],
    ),
  );
}

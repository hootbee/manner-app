import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'topic_completion.dart';
import 'partner_selection_screen.dart';
import 'lesson_feedback_sound.dart';

class TopicCompletionScreen extends StatefulWidget {
  const TopicCompletionScreen({
    super.key,
    required this.complete,
    required this.partner,
    required this.topicTitle,
    required this.spec,
    required this.onNext,
  });
  final Future<TopicCompletionReceipt> Function() complete;
  final MannerPartner partner;
  final String topicTitle;
  final Map<String, dynamic> spec;
  final VoidCallback? onNext;
  @override
  State<TopicCompletionScreen> createState() => _TopicCompletionScreenState();
}

class _TopicCompletionScreenState extends State<TopicCompletionScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  static const root = 'assets/application01/';
  late final animation = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 3200),
  );
  TopicCompletionReceipt? receipt;
  String? error;
  bool loading = false, resume = false;
  String get who => switch (widget.partner) {
    MannerPartner.dog => 'dangdang',
    MannerPartner.cat => 'nyangnyang',
    MannerPartner.monkey => 'mongmong',
  };
  double segment(double ms, double start, double duration) =>
      ((ms - start) / duration).clamp(0, 1);
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    load();
  }

  Future<void> load() async {
    if (loading) return;
    loading = true;
    try {
      final value = await widget.complete();
      await waitLessonAudioIdle();
      if (!mounted) return;
      setState(() => receipt = value);
      if (MediaQuery.disableAnimationsOf(context)) {
        animation.value = 1;
      } else if (WidgetsBinding.instance.lifecycleState == null ||
          WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed) {
        animation.forward(from: 0);
      } else {
        resume = true;
      }
    } catch (e) {
      if (mounted) setState(() => error = '완료 기록을 저장하지 못했어요. 다시 시도해 주세요.');
    } finally {
      loading = false;
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      if (resume) animation.forward();
      resume = false;
    } else {
      resume = resume || animation.isAnimating;
      animation.stop();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    animation.dispose();
    super.dispose();
  }

  /// Settle once into a balanced frame around the character, then hold.
  Widget _confetti(double ms) => LayoutBuilder(
    builder: (context, bounds) => Stack(
      key: const Key('completion-confetti-layer'),
      clipBehavior: Clip.none,
      children: [
        for (var i = 0; i < 12; i++)
          if (ms >= 480 + (i * 73 % 260)) _confettiPiece(i, ms, bounds.biggest),
      ],
    ),
  );

  Widget _confettiPiece(int i, double ms, Size area) {
    final progress = segment(
      ms,
      480 + (i * 73 % 260).toDouble(),
      2150 + (i * 97 % 300).toDouble(),
    );
    const anchors = [
      Offset(.18, .08),
      Offset(.79, .03),
      Offset(.10, .28),
      Offset(.90, .22),
      Offset(.24, .45),
      Offset(.78, .48),
      Offset(.08, .60),
      Offset(.91, .64),
      Offset(.19, .82),
      Offset(.81, .86),
      Offset(.28, .04),
      Offset(.72, .12),
    ];
    final settle = Curves.easeInOutCubic.transform(progress);
    final anchor = anchors[i];
    final startY = -140.0 - (i % 4) * 10;
    final startX = area.width * (.06 + .88 * ((i * .61803398875) % 1)) - 9;
    final targetX = area.width * anchor.dx - 9;
    final targetY = area.height * anchor.dy - 12;
    final sway =
        math.sin(progress * math.pi * 2 + i * .9) *
        (6 + i % 5) *
        math.pow(1 - progress, 2);
    final x = startX + (targetX - startX) * settle + sway;
    final y = startY + (targetY - startY) * settle;
    final opacity =
        segment(progress, 0, .1) * (1 - .25 * segment(progress, .7, .3));
    return Positioned(
      left: x,
      top: y,
      child: Opacity(
        key: ValueKey('completion-confetti-opacity-$i'),
        opacity: opacity,
        child: Transform.rotate(
          angle:
              i * .4 +
              (i.isEven ? 1 : -1) * settle * math.pi * (1 + i % 3 * .3),
          child: Image.asset(
            '${root}runtime/completion/decor/${['confetti_gold', 'confetti_gray', 'sparkle_gold', 'ribbon_gold', 'ribbon_gray', 'burst_gold'][i % 6]}.png',
            key: ValueKey('completion-confetti-piece-$i'),
            width: 18,
            height: 24,
            fit: BoxFit.contain,
          ),
        ),
      ),
    );
  }

  Widget card(Widget child, {bool border = false}) => Container(
    width: double.infinity,
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    decoration: BoxDecoration(
      color: border ? Colors.white : const Color(0xFFF7F8FA),
      borderRadius: BorderRadius.circular(16),
      border: border ? Border.all(color: const Color(0xFFE5E9EF)) : null,
    ),
    child: child,
  );
  @override
  Widget build(BuildContext context) {
    if (receipt == null) {
      return Scaffold(
        body: SafeArea(
          child: Center(
            child: error == null
                ? const CircularProgressIndicator()
                : Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(error!),
                      TextButton(onPressed: load, child: const Text('다시 시도하기')),
                    ],
                  ),
          ),
        ),
      );
    }
    final r = receipt!;
    final state =
        widget.spec['states'][switch (r.kind) {
          TopicCompletionKind.firstDirect => 'FIRST_DIRECT',
          TopicCompletionKind.firstReveal => 'FIRST_ANSWER_REVEAL',
          TopicCompletionKind.review => 'REVIEW',
        }];
    return AnimatedBuilder(
      animation: animation,
      builder: (context, _) {
        final reduced = MediaQuery.disableAnimationsOf(context);
        final ms = (reduced ? 1.0 : animation.value) * 3200;
        final enter = Curves.easeOut.transform(segment(ms, 120, 320));
        final cheer = math.sin(segment(ms, 430, 360) * math.pi);
        final xp = Curves.easeOutBack.transform(segment(ms, 800, 300));
        final t = segment(ms, 1050, 650);
        final wrap = r.after.level > r.before.level;
        final fraction = wrap
            ? (t < .5
                  ? r.before.fraction + (1 - r.before.fraction) * t * 2
                  : r.after.fraction * (t - .5) * 2)
            : r.before.fraction + (r.after.fraction - r.before.fraction) * t;
        final shownLevel = wrap && t < .5 ? r.before.level : r.after.level;
        final shownMax = wrap && t < .5 ? r.before.levelMax : r.after.levelMax;
        // Keep the existing button, character, XP and gauge timing unchanged.
        final stable = reduced || ms >= 1700;
        return Opacity(
          opacity: reduced ? 1 : segment(ms, 0, 200),
          child: Scaffold(
            backgroundColor: Colors.white,
            bottomNavigationBar: SafeArea(
              top: false,
              child: Center(
                heightFactor: 1,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 440),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: FilledButton(
                      key: const Key('topic-completion-next'),
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF1B1E1B),
                        foregroundColor: Colors.white,
                        minimumSize: const Size.fromHeight(48),
                      ),
                      onPressed: stable ? widget.onNext : null,
                      child: const Text('다음 문제로 이동'),
                    ),
                  ),
                ),
              ),
            ),
            body: SafeArea(
              bottom: false,
              child: Align(
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 440),
                  child: SingleChildScrollView(
                    key: const Key('topic-completion-scroll'),
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Stack(
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    IconButton(
                                      tooltip: '뒤로 가기',
                                      onPressed: () =>
                                          Navigator.maybePop(context),
                                      icon: const Icon(Icons.chevron_left),
                                    ),
                                    IconButton(
                                      tooltip: '알림',
                                      onPressed: () {
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          const SnackBar(
                                            content: Text('새로운 알림이 없어요.'),
                                          ),
                                        );
                                      },
                                      icon: const Icon(
                                        Icons.notifications_none,
                                      ),
                                    ),
                                  ],
                                ),
                                Semantics(
                                  liveRegion: true,
                                  label: '${state['title']} ${r.awarded} XP',
                                  child: Text(
                                    state['title'],
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      fontSize: 32,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  state['subtitle'],
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    color: Color(0xFF737D8C),
                                  ),
                                ),
                                SizedBox(
                                  height:
                                      MediaQuery.sizeOf(context).height < 700
                                      ? 152
                                      : 180,
                                  child: LayoutBuilder(
                                    builder: (c, b) => Stack(
                                      alignment: Alignment.center,
                                      clipBehavior: Clip.none,
                                      children: [
                                        Positioned.fill(
                                          child: IgnorePointer(
                                            child: ExcludeSemantics(
                                              child: _confetti(
                                                reduced ? 3200 : ms,
                                              ),
                                            ),
                                          ),
                                        ),
                                        Transform.translate(
                                          offset: Offset(
                                            0,
                                            reduced
                                                ? 0
                                                : 24 * (1 - enter) - 7 * cheer,
                                          ),
                                          child: Transform.rotate(
                                            angle: reduced
                                                ? 0
                                                : math.sin(
                                                        segment(ms, 430, 360) *
                                                            math.pi *
                                                            2,
                                                      ) *
                                                      math.pi /
                                                      90,
                                            child: Transform.scale(
                                              scale: reduced
                                                  ? 1
                                                  : .92 + .08 * enter,
                                              child: Opacity(
                                                opacity: reduced ? 1 : enter,
                                                child: Image.asset(
                                                  '${root}runtime/completion/characters/${who}_celebrate_rgba.png',
                                                  key: const Key(
                                                    'completion-character',
                                                  ),
                                                  height: b.maxHeight,
                                                  fit: BoxFit.contain,
                                                  semanticLabel:
                                                      widget.partner.name,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                if (state['speech_bubble'] != null) ...[
                                  Row(
                                    children: [
                                      Image.asset(
                                        '${root}runtime/explanation/profiles/${who}_profile_rgba_256.png',
                                        width: 52,
                                        height: 52,
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: card(
                                          Text(
                                            state['speech_bubble'],
                                            style: const TextStyle(
                                              fontSize: 14,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                ],
                                card(
                                  Row(
                                    children: [
                                      Image.asset(
                                        '${root}runtime/completion/xp_reward_medal_rgba.png',
                                        height: 64,
                                        width: 64,
                                      ),
                                      const SizedBox(width: 16),
                                      const SizedBox(
                                        height: 64,
                                        child: VerticalDivider(),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            const Text(
                                              '획득한 보상',
                                              style: TextStyle(
                                                fontWeight: FontWeight.w700,
                                                fontSize: 16,
                                              ),
                                            ),
                                            const SizedBox(height: 6),
                                            Transform.scale(
                                              scale: reduced
                                                  ? 1
                                                  : .85 + .15 * xp,
                                              alignment: Alignment.centerLeft,
                                              child: Opacity(
                                                opacity: reduced
                                                    ? 1
                                                    : segment(ms, 800, 300),
                                                child: Text(
                                                  '+${r.awarded} XP',
                                                  key: const Key(
                                                    'completion-xp',
                                                  ),
                                                  style: const TextStyle(
                                                    color: Color(0xFFD99A28),
                                                    fontSize: 30,
                                                    fontWeight: FontWeight.w800,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        card(
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Wrap(
                                alignment: WrapAlignment.spaceBetween,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                children: [
                                  Text(
                                    'Lv. $shownLevel',
                                    key: const Key('completion-level'),
                                    style: const TextStyle(
                                      fontSize: 24,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  Text('현재 경험치 ${r.after.totalXp} XP'),
                                ],
                              ),
                              const SizedBox(height: 10),
                              LinearProgressIndicator(
                                key: const Key('completion-gauge'),
                                value: fraction.clamp(0, 1),
                                minHeight: 10,
                                borderRadius: BorderRadius.circular(8),
                                color: const Color(0xFF666666),
                                backgroundColor: const Color(0xFFE5E5E5),
                              ),
                              const SizedBox(height: 10),
                              Wrap(
                                alignment: WrapAlignment.spaceBetween,
                                children: [
                                  Text(
                                    '다음 레벨까지 ${r.after.levelMax - r.after.levelXp} XP 남았어요!',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Colors.black54,
                                    ),
                                  ),
                                  Text(
                                    '${(fraction * shownMax).round()} / $shownMax XP',
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          border: true,
                        ),
                        const SizedBox(height: 12),
                        card(
                          Row(
                            children: [
                              const Icon(
                                Icons.menu_book,
                                size: 32,
                                color: Colors.black54,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      '이번에 배운 매너',
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      widget.topicTitle,
                                      style: const TextStyle(
                                        fontSize: 14,
                                        height: 1.5,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

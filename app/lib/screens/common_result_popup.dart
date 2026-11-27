import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'lesson_feedback_sound.dart';
import 'partner_selection_screen.dart';

/// The app supplies playback; a standalone lesson can be rendered without a platform player.
class ResultPopupAudioScope extends InheritedWidget {
  const ResultPopupAudioScope({
    super.key,
    required this.play,
    required super.child,
  });
  final LessonSoundPlayer play;
  static LessonSoundPlayer? of(BuildContext context) =>
      context.getInheritedWidgetOfExactType<ResultPopupAudioScope>()?.play;
  @override
  bool updateShouldNotify(ResultPopupAudioScope oldWidget) =>
      play != oldWidget.play;
}

/// Called only after a valid judgement's existing visual feedback has settled.
/// It has no knowledge of grading, retries, rewards or persistence.
class LessonResultPresenter {
  bool _showing = false, _disposed = false;
  void dispose() => _disposed = true;
  Future<void> show(
    BuildContext context, {
    required MannerPartner partner,
    required bool correct,
    required bool finalFailure,
    required bool muted,
  }) async {
    if (_disposed ||
        _showing ||
        !context.mounted ||
        ModalRoute.of(context)?.isCurrent == false) {
      return;
    }
    _showing = true;
    final player = ResultPopupAudioScope.of(context);
    // This shares the legacy feedback queue, including audio still playing after dismissal.
    unawaited(
      playLessonFeedbackSound(
        player,
        correct ? LessonFeedbackSound.correct : LessonFeedbackSound.wrong,
        muted: muted,
      ),
    );
    try {
      await showGeneralDialog<void>(
        context: context,
        barrierDismissible: true,
        barrierLabel: '결과 팝업 닫기',
        barrierColor: const Color(0x7A000000),
        transitionDuration: Duration.zero,
        routeSettings: const RouteSettings(name: 'lesson-result-popup'),
        pageBuilder: (popupContext, _, _) => SafeArea(
          child: LayoutBuilder(
            builder: (c, bounds) {
              final width = math.min(344.0, bounds.maxWidth - 32);
              final scale = MediaQuery.textScalerOf(c).scale(15) / 15;
              final desired = width * 1.11 + math.max(0.0, scale - 1) * 150;
              final maxHeight = math.max(1.0, bounds.maxHeight - 24);
              final contentHeight = math.max(
                300 + math.max(0.0, scale - 1) * 150,
                math.min(desired, maxHeight),
              );
              return Center(
                child: GestureDetector(
                  key: const Key('common-result-popup'),
                  behavior: HitTestBehavior.opaque,
                  onTap: () => Navigator.of(popupContext).pop(),
                  child: Material(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    clipBehavior: Clip.antiAlias,
                    child: ConstrainedBox(
                      constraints: BoxConstraints(maxHeight: maxHeight),
                      child: SingleChildScrollView(
                        child: SizedBox(
                          width: width,
                          height: contentHeight,
                          child: CommonResultPopup(
                            partner: partner,
                            correct: correct,
                            finalFailure: finalFailure,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      );
    } finally {
      _showing = false;
    }
  }
}

class CommonResultPopup extends StatefulWidget {
  const CommonResultPopup({
    super.key,
    required this.partner,
    required this.correct,
    this.finalFailure = false,
  });
  final MannerPartner partner;
  final bool correct, finalFailure;
  @override
  State<CommonResultPopup> createState() => _CommonResultPopupState();
}

class _CommonResultPopupState extends State<CommonResultPopup>
    with SingleTickerProviderStateMixin {
  late final AnimationController _confetti = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 950),
  );
  bool _started = false;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_started) {
      _started = true;
      if (widget.correct && !MediaQuery.disableAnimationsOf(context)) {
        _confetti.forward();
      }
    }
  }

  @override
  void dispose() {
    _confetti.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final who = switch (widget.partner) {
      MannerPartner.dog => 'dangdang',
      MannerPartner.cat => 'nyangnyang',
      MannerPartner.monkey => 'mongmong',
    };
    final color = widget.correct
        ? const Color(0xFF6F9B83)
        : const Color(0xFFC65D60);
    return Stack(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
          child: Column(
            children: [
              Semantics(
                liveRegion: true,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(
                      width: 42,
                      height: 42,
                      child: widget.correct
                          ? Container(
                              key: const Key('popup-correct-symbol'),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(color: color, width: 8),
                              ),
                            )
                          : Icon(
                              Icons.close_rounded,
                              key: const Key('popup-wrong-symbol'),
                              size: 48,
                              color: color,
                            ),
                    ),
                    const SizedBox(width: 12),
                    Flexible(
                      child: Text(
                        widget.correct ? '정답입니다!' : '오답입니다!',
                        style: const TextStyle(
                          fontFamily: 'Pretendard',
                          fontSize: 26,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF222831),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: Semantics(
                  label:
                      '${widget.partner.name}의 ${widget.correct ? '기뻐하는' : '아쉬워하는'} 모습',
                  image: true,
                  child: ClipRect(
                    child: FittedBox(
                      fit: BoxFit.contain,
                      child: SizedBox(
                        width: 768,
                        height: 800,
                        child: Stack(
                          clipBehavior: Clip.hardEdge,
                          children: [
                            Positioned(
                              left: -128,
                              top: -160,
                              width: 1024,
                              height: 1024,
                              child: Image.asset(
                                'assets/result_popup/characters/${who}_${widget.correct ? 'correct' : 'wrong'}.png',
                                key: const Key('popup-character'),
                                excludeFromSemantics: true,
                                fit: BoxFit.contain,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                widget.correct
                    ? '좋아요! 배려 있는 행동이었어요.'
                    : widget.finalFailure
                    ? '정답을 함께 확인해 볼까요?'
                    : '다시 생각해 볼까요?',
                key: const Key('popup-message'),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontFamily: 'Pretendard',
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF222831),
                ),
              ),
              const SizedBox(height: 14),
              Container(
                width: 28,
                height: 3,
                decoration: BoxDecoration(
                  color: const Color(0xFFBBBBBB),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                '화면을 터치하면 닫힙니다.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'Pretendard',
                  fontSize: 12,
                  color: Color(0xFF989898),
                ),
              ),
            ],
          ),
        ),
        if (widget.correct)
          Positioned.fill(
            child: IgnorePointer(
              child: AnimatedBuilder(
                animation: _confetti,
                builder: (_, _) => _confetti.isAnimating
                    ? CustomPaint(
                        key: const Key('popup-confetti'),
                        painter: _ConfettiPainter(_confetti.value),
                      )
                    : const SizedBox(),
              ),
            ),
          ),
      ],
    );
  }
}

class _ConfettiPainter extends CustomPainter {
  const _ConfettiPainter(this.progress);
  final double progress;
  @override
  void paint(Canvas canvas, Size size) {
    final random = math.Random(64);
    final opacity = math.min(1.0, (1 - progress) * 4).clamp(0.0, 1.0);
    const colors = [Color(0xFFFFCF66), Color(0xFF6F9B83), Color(0xFFAAAAAA)];
    for (var i = 0; i < 30; i++) {
      final startX = random.nextDouble();
      final drift = (random.nextDouble() - .5) * 70;
      final startY = .15 + random.nextDouble() * .4;
      canvas.save();
      canvas.translate(
        startX * size.width + drift * progress,
        (startY + progress * .4) * size.height,
      );
      canvas.rotate(progress * math.pi * 3 + i);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          const Rect.fromLTWH(-3, -5, 6, 10),
          const Radius.circular(2),
        ),
        Paint()..color = colors[i % 3].withValues(alpha: opacity),
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_ConfettiPainter old) => progress != old.progress;
}

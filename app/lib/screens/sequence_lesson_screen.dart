import 'common_result_popup.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'sequence_lesson_state.dart';
import 'sequence_card_list.dart';
import 'result_feedback_overlay.dart';
import 'lesson_explanation_content.dart';
import 'lesson_explanation_screen.dart';
import 'lesson_feedback_sound.dart';
import 'manners_hint_bubble.dart';
import 'manners_learning_header.dart';
import 'manners_lesson_progress.dart';
import 'partner_selection_screen.dart';

/// Reusable sequence lesson: callers supply data, art, progress and optional next route.
class SequenceLessonScreen extends StatefulWidget {
  const SequenceLessonScreen({
    super.key,
    required this.questionAsset,
    required this.explanationAsset,
    required this.assetPrefix,
    required this.sceneAsset,
    required this.sceneAspectRatio,
    required this.sceneLabel,
    required this.number,
    this.partner = MannerPartner.dog,
    this.profileAsset,
    this.playSound,
    this.soundMuted = false,
    this.onNextProblem,
    this.random,
    this.question,
    this.application = false,
    this.clipScene = true,
    this.applicationBuilder,
    this.educationContent,
    this.shortDetails,
    this.inlineExplanation = false,
    this.onLearningComplete,
    this.revealExplanation,
    this.showRemainingAttempts = false,
    this.fitLongestHint = false,
  });
  final String questionAsset,
      explanationAsset,
      assetPrefix,
      sceneAsset,
      sceneLabel;
  final double sceneAspectRatio;
  final int number;
  final MannerPartner partner;
  final String? profileAsset;
  final LessonSoundPlayer? playSound;
  final bool soundMuted;
  final VoidCallback? onNextProblem;
  final math.Random? random;
  final SequenceQuestion? question;
  final bool application, clipScene;
  final Widget Function(BuildContext, SequenceLessonState)? applicationBuilder;
  final LessonExplanationContent? educationContent;
  final List<ExplanationReason>? shortDetails;
  final bool inlineExplanation, showRemainingAttempts, fitLongestHint;
  final String? revealExplanation;
  final Future<void> Function(SequenceLessonState)? onLearningComplete;
  @override
  State<SequenceLessonScreen> createState() => _SequenceLessonScreenState();
}

class _SequenceLessonScreenState extends State<SequenceLessonScreen>
    with SingleTickerProviderStateMixin {
  SequenceLessonState? _state;
  LessonExplanationContent? _education;
  String? _error;
  bool _viewingHint = false;
  bool _openingExplanation = false;
  Timer? _timer;
  final _resultPopup = LessonResultPresenter();
  final _viewportKey = GlobalKey();
  final _cardAnchors = <String, GlobalKey>{};
  final _resultBounds = ValueNotifier<Rect?>(null);
  bool _boundsQueued = false;
  late final _scroll = ScrollController()..addListener(_scheduleOverlayBounds);
  late final _effect = AnimationController(
    vsync: this,
    duration: ResultFeedbackOverlay.duration,
  );
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      // Precache needs inherited image configuration after initState completes,
      // including when the caller already supplied in-memory question data.
      await Future<void>.delayed(Duration.zero);
      if (!mounted) return;
      final text = widget.question != null
          ? null
          : await Future.wait([
              rootBundle.loadString(widget.questionAsset),
              rootBundle.loadString(widget.explanationAsset),
            ]);
      final q =
          widget.question ?? SequenceQuestion.fromJson(jsonDecode(text![0]));
      final education = text == null
          ? widget.educationContent
          : LessonExplanationContent.fromJson(jsonDecode(text[1]));
      if (!mounted) return;
      await Future.wait(
        [
          widget.sceneAsset,
          ...q.cards.map((c) => '${widget.assetPrefix}${c.thumbnail}'),
        ].map((asset) => precacheImage(AssetImage(asset), context)),
      );
      if (!mounted) return;
      setState(() {
        _education = education;
        for (final card in q.cards) {
          _cardAnchors[card.id] = GlobalKey();
        }
        _state = SequenceLessonState(q, random: widget.random);
      });
    } catch (error) {
      debugPrint('Sequence load failed: $error');
      if (mounted) setState(() => _error = '학습 자료를 불러오지 못했어요. 다시 시도해 주세요.');
    }
  }

  @override
  void dispose() {
    _resultPopup.dispose();
    _timer?.cancel();
    _effect.dispose();
    _scroll.dispose();
    _resultBounds.dispose();
    _state?.dispose();
    super.dispose();
  }

  void _submit() {
    final s = _state!;
    if (!s.question.gradingApproved) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('정답 인정 순서가 승인되면 채점할 수 있어요. 지금은 카드 순서만 바꿔 볼 수 있어요.'),
        ),
      );
      return;
    }
    if (!s.submit()) return;
    _viewingHint = false;
    unawaited(
      playLessonFeedbackSound(
        widget.playSound,
        s.success ? LessonFeedbackSound.correct : LessonFeedbackSound.wrong,
        muted: widget.soundMuted,
      ),
    );
    if (!kIsWeb &&
        !MediaQuery.disableAnimationsOf(context) &&
        (defaultTargetPlatform == TargetPlatform.android ||
            defaultTargetPlatform == TargetPlatform.iOS)) {
      unawaited(HapticFeedback.lightImpact().catchError((Object _) {}));
    }
    _effect.forward(from: 0);
    _timer?.cancel();
    _timer = Timer(ResultFeedbackOverlay.duration, () {
      if (mounted) {
        s.settle();
        unawaited(
          _resultPopup.show(
            context,
            partner: widget.partner,
            correct: s.success,
            finalFailure: s.phase == SequencePhase.finalFailure,
            muted: widget.soundMuted,
          ),
        );
      }
    });
  }

  void _scheduleOverlayBounds() {
    if (_boundsQueued) return;
    _boundsQueued = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _boundsQueued = false;
      if (!mounted) return;
      final view = _viewportKey.currentContext?.findRenderObject();
      if (_state?.busy != true || view is! RenderBox || !view.hasSize) {
        _resultBounds.value = null;
        return;
      }
      final origin = view.localToGlobal(Offset.zero);
      final viewport = origin & view.size;
      Rect? visibleCards;
      for (final key in _cardAnchors.values) {
        final card = key.currentContext?.findRenderObject();
        if (card is! RenderBox || !card.attached || !card.hasSize) continue;
        final rect = (card.localToGlobal(Offset.zero) & card.size).intersect(
          viewport,
        );
        if (rect.isEmpty) continue;
        visibleCards = visibleCards?.expandToInclude(rect) ?? rect;
      }
      _resultBounds.value = visibleCards?.shift(-origin);
    });
  }

  @override
  Widget build(BuildContext context) {
    final s = _state;
    if (s == null) {
      return Scaffold(
        body: SafeArea(
          child: Column(
            children: [
              const MannersLearningHeader(),
              Expanded(
                child: Center(
                  child: _error == null
                      ? const CircularProgressIndicator()
                      : Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(_error!),
                            TextButton(
                              onPressed: () {
                                setState(() => _error = null);
                                _load();
                              },
                              child: const Text('다시 불러오기'),
                            ),
                          ],
                        ),
                ),
              ),
            ],
          ),
        ),
      );
    }
    return ListenableBuilder(
      key: const Key('sequence-ready'),
      listenable: s,
      builder: (context, _) {
        _scheduleOverlayBounds();
        return Scaffold(
          backgroundColor: Colors.white,
          bottomNavigationBar: _footer(s),
          body: SafeArea(
            bottom: false,
            child: Stack(
              key: _viewportKey,
              children: [
                CustomScrollView(
                  controller: _scroll,
                  key: const Key('sequence-scroll'),
                  slivers: [
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                      sliver: SliverToBoxAdapter(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const MannersLearningHeader(),
                            const SizedBox(height: 12),
                            MannersLessonProgress(
                              number: widget.number,
                              application: widget.application,
                            ),
                            const Divider(height: 28, color: Color(0xFFEEEEEE)),
                            Text(
                              _words(s.question.title),
                              semanticsLabel: s.question.title,
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w900,
                                height: 1.45,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              s.question.scenario,
                              style: const TextStyle(
                                fontSize: 14,
                                height: 1.5,
                                color: Colors.black54,
                              ),
                            ),
                            const SizedBox(height: 16),
                            if (!widget.clipScene)
                              AspectRatio(
                                aspectRatio: widget.sceneAspectRatio,
                                child: Image.asset(
                                  widget.sceneAsset,
                                  key: const Key('sequence-scene'),
                                  fit: BoxFit.contain,
                                  semanticLabel: widget.sceneLabel,
                                ),
                              )
                            else
                              ClipRRect(
                                borderRadius: BorderRadius.circular(18),
                                child: AspectRatio(
                                  aspectRatio: widget.sceneAspectRatio,
                                  child: Image.asset(
                                    widget.sceneAsset,
                                    key: const Key('sequence-scene'),
                                    fit: BoxFit.contain,
                                    semanticLabel: widget.sceneLabel,
                                  ),
                                ),
                              ),
                            const SizedBox(height: 16),
                            Text(
                              s.question.instruction,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                height: 1.5,
                              ),
                            ),
                            const SizedBox(height: 16),
                          ],
                        ),
                      ),
                    ),
                    SliverPadding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      sliver: AnimatedBuilder(
                        animation: _effect,
                        builder: (context, _) => SequenceCardList(
                          state: s,
                          assetPrefix: widget.assetPrefix,
                          cardAnchors: _cardAnchors,
                          shake:
                              s.phase == SequencePhase.wrongJustJudged &&
                                  !MediaQuery.disableAnimationsOf(context) &&
                                  _effect.value * 1750 < 200
                              ? math.sin(
                                      _effect.value * 1750 / 200 * math.pi * 8,
                                    ) *
                                    3
                              : 0,
                        ),
                      ),
                    ),
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                      sliver: SliverToBoxAdapter(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _feedback(s),
                            const SizedBox(height: 8),
                            SizedBox(
                              key: const Key('sequence-hint-slot'),
                              height: 48,
                              child: s.canHint
                                  ? Align(
                                      alignment: Alignment.centerLeft,
                                      child: TextButton(
                                        key: const Key('sequence-hint'),
                                        onPressed: () {
                                          setState(() => _viewingHint = true);
                                          s.showHint();
                                        },
                                        style: TextButton.styleFrom(
                                          foregroundColor: const Color(
                                            0xFF191D1A,
                                          ),
                                        ),
                                        child: Text(
                                          s.hintStep == 0
                                              ? '힌트 보기'
                                              : '다음 힌트 보기',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ),
                                    )
                                  : const SizedBox.shrink(),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                ValueListenableBuilder<Rect?>(
                  valueListenable: _resultBounds,
                  builder: (context, bounds, _) => s.busy && bounds != null
                      ? ResultFeedbackOverlay(
                          correct: s.success,
                          animation: _effect,
                          bounds: bounds,
                          reduceMotion: MediaQuery.disableAnimationsOf(context),
                        )
                      : const SizedBox.shrink(),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  String _words(String text) =>
      text.split(' ').map((w) => w.split('').join('\u2060')).join(' ');
  Widget _feedback(SequenceLessonState s) {
    if (!s.question.gradingApproved) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 16),
        child: Column(
          children: [
            Text('정답 판정 · 힌트 · 해설 승인 대기', textAlign: TextAlign.center),
            TextButton(onPressed: null, child: Text('힌트 보기')),
          ],
        ),
      );
    }
    final showHint =
        _viewingHint && s.hintStep > 0 && !s.success && !s.solutionRevealed;
    if (s.canEdit && !showHint) return const SizedBox(height: 96);
    final text = s.solutionRevealed
        ? widget.revealExplanation ?? '정답 시범 · 성공으로 기록되지 않아요.'
        : s.success
        ? s.question.correctFeedback
        : s.question.wrongFeedback;
    final result = Semantics(
      liveRegion: true,
      child: Container(
        key: const Key('sequence-feedback'),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: s.success ? const Color(0xFFF0F7ED) : const Color(0xFFF4F4F4),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!s.solutionRevealed) ...[
              ResultFeedbackSymbol(
                correct: s.success,
                size: 44,
                key: Key(
                  s.success
                      ? 'sequence-result-correct'
                      : 'sequence-result-wrong',
                ),
              ),
              const SizedBox(width: 12),
            ],
            Expanded(
              child: Text(
                text,
                style: const TextStyle(
                  fontSize: 14,
                  height: 1.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!s.canEdit) result,
        if (widget.showRemainingAttempts &&
            !s.canEdit &&
            !s.success &&
            !s.solutionRevealed)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              '남은 시도 횟수: ${s.question.maxSubmissions - s.validSubmissions}/${s.question.maxSubmissions}',
              key: const Key('sequence-remaining-attempts'),
            ),
          ),
        if (showHint) ...[
          if (!s.canEdit) const SizedBox(height: 12),
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 319),
              child: MannersHintBubble(
                partner: widget.partner,
                stage: s.hintStep,
                hintMessages: s.question.hints,
                profileAsset: widget.profileAsset,
                fitLongestMessage: widget.fitLongestHint,
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _footer(SequenceLessonState s) {
    final String label;
    final VoidCallback? action;
    if (s.success || s.solutionRevealed) {
      label = '해설 보기';
      action = s.busy ? null : _explanation;
    } else if (s.phase == SequencePhase.finalFailure) {
      label = '정답 확인';
      action = s.reveal;
    } else if (s.phase == SequencePhase.wrongComplete) {
      label = '다시 시도하기';
      action = () {
        _effect.reset();
        _viewingHint = s.hintStep > 0;
        s.retry();
      };
    } else {
      label = '제출하기';
      action = s.canSubmit ? _submit : null;
    }
    return SafeArea(
      top: false,
      child: Container(
        color: Colors.white,
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
        child: FilledButton(
          key: const Key('sequence-primary'),
          onPressed: action,
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFF191D1A),
            foregroundColor: Colors.white,
            minimumSize: const Size.fromHeight(48),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
        ),
      ),
    );
  }

  Future<void> _explanation() async {
    if (_openingExplanation || _education == null) return;
    _openingExplanation = true;
    final action = await Navigator.of(context).push<ExplanationAction>(
      MaterialPageRoute(
        builder: (_) => LessonExplanationScreen(
          content: _education!,
          partner: widget.partner,
          progressHeader: MannersLessonProgress(
            number: widget.number,
            application: widget.application,
          ),
          profileAsset: widget.profileAsset,
          shortDetails: widget.shortDetails,
          inlineDetails: widget.inlineExplanation,
          answerRevealed: _state!.solutionRevealed,
          hasNextProblem:
              widget.onLearningComplete != null ||
              widget.applicationBuilder != null ||
              widget.onNextProblem != null,
          nextLabel: widget.onLearningComplete != null
              ? '학습 완료'
              : widget.applicationBuilder == null
              ? '다음 문제로 이동'
              : '응용 문제로 이동',
        ),
      ),
    );
    if (!mounted) return;
    _openingExplanation = false;
    if (action == ExplanationAction.replay) {
      _timer?.cancel();
      _effect.reset();
      _viewingHint = false;
      _state!.resetAttempt();
    } else if (action == ExplanationAction.next) {
      if (widget.onLearningComplete != null) {
        await widget.onLearningComplete!(_state!);
      } else if (widget.applicationBuilder != null) {
        final next = await Navigator.of(context).push<bool>(
          MaterialPageRoute(
            builder: (c) => widget.applicationBuilder!(c, _state!),
          ),
        );
        if (mounted && next == true) widget.onNextProblem?.call();
      } else {
        widget.onNextProblem?.call();
      }
    }
  }
}

import 'common_result_popup.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'choice_lesson_state.dart';
import 'lesson_explanation_content.dart';
import 'lesson_explanation_screen.dart';
import 'lesson_feedback_sound.dart';
import 'manners_hint_bubble.dart';
import 'manners_learning_header.dart';
import 'manners_lesson_progress.dart';
import 'partner_selection_screen.dart';
import 'subway03_scene.dart';
import 'result_feedback_overlay.dart';

/// Optional adapter for handoffs whose JSON schema differs from older lessons.
class ChoiceLessonData {
  const ChoiceLessonData(this.problem, this.education, this.scene);
  final Map<String, dynamic> problem, education, scene;
}

class ChoiceLessonScreen extends StatefulWidget {
  const ChoiceLessonScreen({
    super.key,
    this.partner = MannerPartner.dog,
    this.playSound,
    this.soundMuted = false,
    this.onNextProblem,
    this.assetRoot = "assets/subway03/",
    this.questionFile = "problem_choice_subway03.json",
    this.number = 3,
    this.keyPrefix = "subway03",
    this.enhancedFeedback = false,
    this.application = false,
    this.dataLoader,
    this.applicationBuilder,
    this.shortDetails,
    this.inlineExplanation = false,
    this.fitLongestHint = false,
    this.revealExplanation,
    this.onLearningComplete,
    this.openSource,
  });
  final MannerPartner partner;
  final String assetRoot, questionFile, keyPrefix;
  final int number;
  final bool enhancedFeedback;
  final bool application;
  final Future<ChoiceLessonData> Function()? dataLoader;
  final Widget Function(BuildContext, bool answerRevealed)? applicationBuilder;
  final LessonSoundPlayer? playSound;
  final bool soundMuted;
  final VoidCallback? onNextProblem;
  final List<ExplanationReason>? shortDetails;
  final bool inlineExplanation, fitLongestHint;
  final String? revealExplanation;
  final Future<void> Function(bool answerRevealed)? onLearningComplete;
  final ExplanationSourceOpener? openSource;
  @override
  State<ChoiceLessonScreen> createState() => _ChoiceLessonScreenState();
}

class _ChoiceLessonScreenState extends State<ChoiceLessonScreen>
    with SingleTickerProviderStateMixin {
  ChoiceLessonState? _state;
  LessonExplanationContent? _education;
  Subway03SceneConfig? _art;
  bool _viewingHint = false;
  bool _openingExplanation = false;
  String? _error;
  Timer? _timer;
  final _resultPopup = LessonResultPresenter();
  late final _effect = AnimationController(
    vsync: this,
    duration: widget.enhancedFeedback
        ? ResultFeedbackOverlay.duration
        : const Duration(milliseconds: 200),
  );
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final custom = await widget.dataLoader?.call();
      final data = custom == null
          ? await Future.wait([
              for (final name in [
                widget.questionFile,
                'explanation.json',
                'scene_layout.json',
              ])
                rootBundle.loadString('${widget.assetRoot}$name'),
            ])
          : null;
      final problem = ChoiceProblem.fromJson(
        custom?.problem ?? jsonDecode(data![0]),
      );
      final education = LessonExplanationContent.fromJson(
        custom?.education ?? jsonDecode(data![1]),
      );
      final art = Subway03SceneConfig(
        custom?.scene ?? jsonDecode(data![2]),
        root: widget.assetRoot,
      );
      if (!mounted) return;
      await Future.wait(
        art.allAssets.map((name) => precacheImage(AssetImage(name), context)),
      );
      if (!mounted) return;
      setState(() {
        _art = art;
        _education = education;
        _state = ChoiceLessonState(problem);
      });
    } catch (error) {
      debugPrint('Subway03 load failed: $error');
      if (mounted) setState(() => _error = '학습 자료를 불러오지 못했어요. 다시 시도해 주세요.');
    }
  }

  @override
  void dispose() {
    _resultPopup.dispose();
    _timer?.cancel();
    _effect.dispose();
    _state?.dispose();
    super.dispose();
  }

  void _submit() {
    final s = _state!;
    if (!s.submit()) return;
    _viewingHint = false;
    unawaited(
      playLessonFeedbackSound(
        widget.playSound,
        s.success ? LessonFeedbackSound.correct : LessonFeedbackSound.wrong,
        muted: widget.soundMuted,
      ),
    );
    if (!s.success &&
        !kIsWeb &&
        !MediaQuery.disableAnimationsOf(context) &&
        (defaultTargetPlatform == TargetPlatform.android ||
            defaultTargetPlatform == TargetPlatform.iOS)) {
      unawaited(HapticFeedback.lightImpact().catchError((Object _) {}));
    }
    _effect.forward(from: 0);
    _timer?.cancel();
    _timer = Timer(
      widget.enhancedFeedback
          ? ResultFeedbackOverlay.duration
          : const Duration(milliseconds: 250),
      () {
        if (mounted) {
          s.settle();
          unawaited(
            _resultPopup.show(
              context,
              partner: widget.partner,
              correct: s.success,
              finalFailure: s.phase == ChoicePhase.finalFailure,
              muted: widget.soundMuted,
            ),
          );
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = _state;
    if (state == null) {
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
      key: Key('${widget.keyPrefix}-ready'),
      listenable: state,
      builder: (context, _) {
        final s = state;
        final pose = s.success || s.solutionRevealed
            ? Subway03Pose.positive
            : _viewingHint || (!s.canSelect && !s.success)
            ? Subway03Pose.thinking
            : Subway03Pose.tired;
        return Scaffold(
          backgroundColor: Colors.white,
          bottomNavigationBar: _footer(s),
          body: SafeArea(
            bottom: false,
            child: SingleChildScrollView(
              key: Key('${widget.keyPrefix}-scroll'),
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
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
                    _words(s.problem.title),
                    semanticsLabel: s.problem.title,
                    key: Key('${widget.keyPrefix}-title'),
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      height: 1.45,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    s.problem.situations[widget.partner.name] ??
                        s.problem.situation,
                    style: const TextStyle(
                      fontSize: 14,
                      height: 1.5,
                      color: Colors.black54,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Subway03SceneRenderer(
                    config: _art!,
                    partner: widget.partner,
                    pose: pose,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    s.problem.instruction,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Stack(
                    children: [
                      Column(
                        children: [
                          for (final option in s.problem.choices)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: _choice(s, option),
                            ),
                        ],
                      ),
                      if (widget.enhancedFeedback && s.busy)
                        Positioned.fill(
                          child: LayoutBuilder(
                            builder: (context, box) => Stack(
                              children: [
                                ResultFeedbackOverlay(
                                  correct: s.success,
                                  animation: _effect,
                                  bounds: Offset.zero & box.biggest,
                                  reduceMotion: MediaQuery.disableAnimationsOf(
                                    context,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  _feedback(s),
                  const SizedBox(height: 8),
                  SizedBox(
                    key: Key('${widget.keyPrefix}-hint-slot'),
                    height: 48,
                    child: s.canHint
                        ? Align(
                            alignment: Alignment.centerLeft,
                            child: TextButton(
                              key: Key('${widget.keyPrefix}-hint'),
                              onPressed: () {
                                setState(() => _viewingHint = true);
                                s.showHint();
                              },
                              style: TextButton.styleFrom(
                                foregroundColor: const Color(0xFF191D1A),
                              ),
                              child: Text(
                                s.hintStep == 0 ? '힌트 보기' : '다음 힌트 보기',
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
        );
      },
    );
  }

  Widget _choice(ChoiceLessonState s, ChoiceOption option) {
    final selected = s.solutionRevealed
        ? option.id == s.problem.correctId
        : s.selectedId == option.id;
    final judged = s.success || s.solutionRevealed;
    final popup = !widget.enhancedFeedback && s.busy && selected;
    final child = Semantics(
      button: true,
      selected: selected,
      enabled: s.canSelect,
      inMutuallyExclusiveGroup: true,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          key: ValueKey('choice-${option.id}'),
          borderRadius: BorderRadius.circular(16),
          onTap: s.canSelect ? () => s.select(option.id) : null,
          child: AnimatedContainer(
            duration: Duration(
              milliseconds: MediaQuery.disableAnimationsOf(context) ? 0 : 150,
            ),
            constraints: const BoxConstraints(minHeight: 56),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: selected ? const Color(0xFFF0F0F0) : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: selected
                    ? const Color(0xFF191D1A)
                    : const Color(0xFFE2E2E2),
                width: selected ? 1.5 : 1,
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  width: 28,
                  height: 28,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: selected
                        ? const Color(0xFF191D1A)
                        : const Color(0xFFF3F3F3),
                  ),
                  child: Text(
                    option.id,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: selected ? Colors.white : const Color(0xFF191D1A),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _words(option.text),
                    semanticsLabel: option.text,
                    style: const TextStyle(fontSize: 15, height: 1.45),
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 28,
                  height: 28,
                  child: popup
                      ? AnimatedBuilder(
                          animation: _effect,
                          builder: (context, _) => Transform.scale(
                            scale: MediaQuery.disableAnimationsOf(context)
                                ? 1
                                : _effect.value < .5
                                ? .8 + .8 * _effect.value
                                : 1.4 - .4 * _effect.value,
                            child: Icon(
                              s.success
                                  ? Icons.radio_button_unchecked
                                  : Icons.close,
                              key: const Key('choice-result-effect'),
                              color: const Color(0xFF191D1A),
                              size: 28,
                            ),
                          ),
                        )
                      : selected && judged
                      ? const Icon(Icons.check_circle_outline, size: 24)
                      : null,
                ),
              ],
            ),
          ),
        ),
      ),
    );
    return AnimatedBuilder(
      animation: _effect,
      child: child,
      builder: (context, child) => Transform.translate(
        key: ValueKey('choice-offset-${option.id}'),
        offset: Offset(
          s.phase == ChoicePhase.wrongJustJudged &&
                  selected &&
                  !MediaQuery.disableAnimationsOf(context)
              ? math.sin(_effect.value * math.pi * 8) * 3
              : 0,
          0,
        ),
        child: child,
      ),
    );
  }

  String _words(String text) =>
      text.split(' ').map((word) => word.split('').join('\u2060')).join(' ');

  Widget _feedback(ChoiceLessonState s) {
    if (_viewingHint && s.hintStep > 0 && !s.success && !s.solutionRevealed) {
      return Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 319),
          child: MannersHintBubble(
            partner: widget.partner,
            stage: s.hintStep,
            hintMessages: s.problem.hints,
            profileAsset: _art!.profile(widget.partner),
            fitLongestMessage: widget.fitLongestHint,
          ),
        ),
      );
    }
    if (s.canSelect) return const SizedBox(height: 96);
    final message = s.solutionRevealed
        ? widget.revealExplanation ??
              '정답 시범 · 성공으로 기록되지 않아요.\n${s.problem.choices.firstWhere((c) => c.id == s.problem.correctId).text}'
        : s.feedback;
    return Semantics(
      liveRegion: true,
      child: Container(
        key: const Key('choice-feedback'),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFFF4F4F4),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(
          children: [
            if (widget.enhancedFeedback && !s.solutionRevealed) ...[
              ResultFeedbackSymbol(correct: s.success, size: 44),
              const SizedBox(width: 12),
            ],
            Expanded(
              child: Text(
                message,
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
  }

  Widget _footer(ChoiceLessonState s) {
    final String label;
    final VoidCallback? action;
    if (s.success || s.solutionRevealed) {
      label = s.problem.correctLabel;
      action = s.busy ? null : _explanation;
    } else if (s.phase == ChoicePhase.finalFailure) {
      label = s.problem.failLabel;
      action = s.reveal;
    } else if (s.phase == ChoicePhase.wrongComplete) {
      label = s.problem.retryLabel;
      action = () {
        _effect.reset();
        _viewingHint = s.hintStep > 0;
        s.retry();
      };
    } else {
      label = s.problem.submitLabel;
      action = s.canSubmit ? _submit : null;
    }
    return SafeArea(
      top: false,
      child: Container(
        color: Colors.white,
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
        child: FilledButton(
          key: Key('${widget.keyPrefix}-primary'),
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
    if (_openingExplanation) return;
    _openingExplanation = true;
    final result = await Navigator.of(context).push<ExplanationAction>(
      MaterialPageRoute(
        builder: (_) => LessonExplanationScreen(
          content: _education!,
          partner: widget.partner,
          progressHeader: MannersLessonProgress(
            number: widget.number,
            application: widget.application,
          ),
          profileAsset: _art!.profile(widget.partner),
          shortDetails: widget.shortDetails,
          inlineDetails: widget.inlineExplanation,
          openSource: widget.openSource,
          answerRevealed: _state!.solutionRevealed,
          hasNextProblem:
              widget.onLearningComplete != null ||
              widget.onNextProblem != null ||
              widget.applicationBuilder != null,
          nextLabel: widget.onLearningComplete != null
              ? '학습 완료'
              : widget.applicationBuilder != null
              ? '응용 문제로 이동'
              : '다음 문제로 이동',
        ),
      ),
    );
    if (!mounted) return;
    _openingExplanation = false;
    if (result == ExplanationAction.next) {
      if (widget.onLearningComplete != null) {
        await widget.onLearningComplete!(_state!.solutionRevealed);
        return;
      }
      if (widget.applicationBuilder != null) {
        final next = await Navigator.of(context).push<bool>(
          MaterialPageRoute(
            builder: (context) =>
                widget.applicationBuilder!(context, _state!.solutionRevealed),
          ),
        );
        if (!mounted || next != true) return;
      }
      widget.onNextProblem?.call();
      return;
    }
    if (result != ExplanationAction.replay) return;
    _timer?.cancel();
    _effect.reset();
    _viewingHint = false;
    _state!.resetAttempt();
  }
}

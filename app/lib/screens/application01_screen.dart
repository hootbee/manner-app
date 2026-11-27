import 'dart:async';
import 'dart:convert';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'application01_state.dart';
import 'topic_completion.dart';
import 'topic_completion_screen.dart';
import 'common_result_popup.dart';
import 'lesson_feedback_sound.dart';
import 'lesson_explanation_content.dart';
import 'lesson_explanation_screen.dart';
import 'manners_hint_bubble.dart';
import 'manners_lesson_progress.dart';
import 'manners_learning_header.dart';
import 'partner_selection_screen.dart';
import 'result_feedback_overlay.dart';

class Application01Screen extends StatefulWidget {
  const Application01Screen({
    super.key,
    required this.basicOutcome,
    this.partner = MannerPartner.dog,
    this.playSound,
    this.soundMuted = false,
  });
  final LearningEnd basicOutcome;
  final MannerPartner partner;
  final LessonSoundPlayer? playSound;
  final bool soundMuted;
  @override
  State<Application01Screen> createState() => _Application01ScreenState();
}

class _Application01ScreenState extends State<Application01Screen> {
  static const root = 'assets/application01/';
  final sceneKey = GlobalKey(), popup = LessonResultPresenter();
  Application01State? lesson;
  Map<String, dynamic>? copy, completionSpec;
  TopicRewardConfig? rewards;
  List<int>? alpha;
  Timer? timer;
  bool invalid = false, opening = false;
  String? error;
  String get who => switch (widget.partner) {
    MannerPartner.dog => 'dangdang',
    MannerPartner.cat => 'nyangnyang',
    MannerPartner.monkey => 'mongmong',
  };
  String charPath(String name) =>
      '${root}runtime/characters/$who/${name}_1536x1024.png';
  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    try {
      final strings = await Future.wait([
        for (final name in [
          'geometry.json',
          'application_explanation_01.json',
          'completion_screen_spec.json',
          'reward_config.json',
        ])
          rootBundle.loadString('$root$name'),
      ]);
      final geom = ApplicationGeometry(jsonDecode(strings[0]));
      final sprite = await rootBundle.load(
        '${root}runtime/luggage/suitcase_drag_sprite_274x410.png',
      );
      final codec = await ui.instantiateImageCodec(
        sprite.buffer.asUint8List(sprite.offsetInBytes, sprite.lengthInBytes),
      );
      final frame = await codec.getNextFrame();
      final bytes = await frame.image.toByteData(
        format: ui.ImageByteFormat.rawRgba,
      );
      final pixels = bytes!.buffer.asUint8List(
        bytes.offsetInBytes,
        bytes.lengthInBytes,
      );
      alpha = [for (var i = 3; i < pixels.length; i += 4) pixels[i]];
      frame.image.dispose();
      codec.dispose();
      if (!mounted) return;
      await Future.wait([
        for (final path in [
          '${root}runtime/background_subway_no_hero_no_suitcase_1536x1024.png',
          '${root}runtime/luggage/suitcase_drag_sprite_274x410.png',
          charPath('seated_idle'),
          charPath('seated_correct_body'),
          charPath('correct_grasp_hand_FRONT'),
        ])
          precacheImage(AssetImage(path), context),
      ]);
      if (!mounted) return;
      setState(() {
        lesson = Application01State(geom);
        copy = jsonDecode(strings[1]);
        completionSpec = jsonDecode(strings[2]);
        rewards = TopicRewardConfig.fromJson(jsonDecode(strings[3]));
      });
    } catch (e) {
      if (mounted) setState(() => error = '응용 학습 자료를 불러오지 못했어요.');
    }
  }

  @override
  void dispose() {
    timer?.cancel();
    popup.dispose();
    lesson?.dispose();
    super.dispose();
  }

  Offset point(Offset global) {
    final box = sceneKey.currentContext!.findRenderObject()! as RenderBox;
    return box.globalToLocal(global) / (box.size.width / 1536);
  }

  bool hit(Offset p) {
    final local = p - (lesson!.renderCenter - const Offset(137, 205));
    final x = local.dx.floor(), y = local.dy.floor();
    return x >= 0 && y >= 0 && x < 274 && y < 410 && alpha![y * 274 + x] > 0;
  }

  void release(PointerUpEvent e) {
    final s = lesson!;
    if (s.pointer != e.pointer) return;
    if (!s.release(e.pointer, point(e.position))) {
      setState(() => invalid = true);
      return;
    }
    invalid = false;
    unawaited(
      playLessonFeedbackSound(
        widget.playSound,
        s.success ? LessonFeedbackSound.correct : LessonFeedbackSound.wrong,
        muted: widget.soundMuted,
      ),
    );
    timer = Timer(ResultFeedbackOverlay.duration, () {
      if (!mounted) return;
      s.settle();
      unawaited(
        popup.show(
          context,
          partner: widget.partner,
          correct: s.success,
          finalFailure: s.phase == ApplicationPhase.failure,
          muted: widget.soundMuted,
        ),
      );
    });
  }

  Widget scene(Application01State s) => AspectRatio(
    aspectRatio: 1.5,
    child: SizedBox(
      key: sceneKey,
      child: Listener(
        behavior: HitTestBehavior.opaque,
        onPointerDown: (e) {
          s.begin(e.pointer, point(e.position), hit(point(e.position)));
        },
        onPointerMove: (e) => s.move(e.pointer, point(e.position)),
        onPointerUp: release,
        onPointerCancel: (e) => s.cancel(e.pointer),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: Stack(
            fit: StackFit.expand,
            children: [
              FittedBox(
                fit: BoxFit.contain,
                child: SizedBox(
                  width: 1536,
                  height: 1024,
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: Image.asset(
                          '${root}runtime/background_subway_no_hero_no_suitcase_1536x1024.png',
                        ),
                      ),
                      Positioned.fill(
                        child: Image.asset(
                          charPath(
                            s.showingCorrect
                                ? 'seated_correct_body'
                                : 'seated_idle',
                          ),
                          key: const Key('application-hero'),
                        ),
                      ),
                      Positioned(
                        left: s.renderCenter.dx - 137,
                        top: s.renderCenter.dy - 205,
                        width: 274,
                        height: 410,
                        child: Image.asset(
                          '${root}runtime/luggage/suitcase_drag_sprite_274x410.png',
                          key: const Key('application-suitcase'),
                          fit: BoxFit.fill,
                        ),
                      ),
                      if (s.showingCorrect)
                        Positioned.fill(
                          child: Image.asset(
                            charPath('correct_grasp_hand_FRONT'),
                            key: const Key('application-grasp-hand'),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              if (s.phase == ApplicationPhase.judging)
                Center(child: ResultFeedbackSymbol(correct: s.success)),
            ],
          ),
        ),
      ),
    ),
  );
  Future<void> explanation() async {
    final s = lesson!;
    final data = copy!['explanation'];
    final sections = {for (final v in data['sections']) v['id'] as String: v};
    final content = LessonExplanationContent.fromJson({
      'problemId': 'transit_01_application',
      'core': sections['core_manner']['text'],
      'learningCore': sections['learning_key']['text'],
      'practice': data['character_speech']['text'],
      'disclaimer': '',
      'reasons': [],
      'faqs': [],
      'sources': [],
    });
    final action = await Navigator.of(context).push<ExplanationAction>(
      MaterialPageRoute(
        builder: (_) => LessonExplanationScreen(
          content: content,
          partner: widget.partner,
          progressHeader: const MannersLessonProgress(
            number: 1,
            application: true,
          ),
          shortDetails: [
            for (final id in ['why_important', 'practical_tip'])
              ExplanationReason(sections[id]['title'], sections[id]['text']),
          ],
          hasNextProblem: true,
          nextLabel: '학습 완료',
        ),
      ),
    );
    if (!mounted) return;
    if (action == ExplanationAction.replay) {
      setState(() {
        lesson = Application01State(s.geometry);
        invalid = false;
      });
      s.dispose();
      return;
    }
    if (action != ExplanationAction.next || opening) return;
    final gateway = TopicCompletionBinding.of(context);
    if (gateway == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('학습 완료 서비스를 연결해 주세요.')));
      return;
    }
    opening = true;
    final outcome = TopicSetOutcome(
      topicId: 'transit_01',
      basic: widget.basicOutcome,
      application: s.phase == ApplicationPhase.revealed
          ? LearningEnd.answerRevealed
          : LearningEnd.directCorrect,
    );
    final next = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (c) => TopicCompletionScreen(
          complete: () => gateway.complete(outcome, rewards!),
          partner: widget.partner,
          topicTitle: '지하철에서 다른 승객을 배려하며 짐 관리하기',
          spec: completionSpec!,
          onNext: () => Navigator.of(c).pop(true),
        ),
      ),
    );
    if (!mounted) return;
    opening = false;
    if (next == true) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    if (lesson == null) {
      return Scaffold(
        body: SafeArea(
          child: Center(
            child: error == null
                ? const CircularProgressIndicator()
                : Text(error!),
          ),
        ),
      );
    }
    final s = lesson!;
    return ListenableBuilder(
      key: const Key('application01-ready'),
      listenable: s,
      builder: (context, _) => Scaffold(
        backgroundColor: Colors.white,
        bottomNavigationBar: SafeArea(
          top: false,
          child: Center(
            heightFactor: 1,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    if (s.canDrag ||
                        s.phase == ApplicationPhase.dragging ||
                        s.phase == ApplicationPhase.wrong)
                      Expanded(
                        child: OutlinedButton(
                          key: const Key('application-hint'),
                          onPressed: s.pointer == null ? s.hintTap : null,
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.black,
                            minimumSize: const Size.fromHeight(48),
                          ),
                          child: Text(
                            s.hint == 0
                                ? '힌트 보기'
                                : s.hint < 2
                                ? '다음 힌트 보기'
                                : s.hintOpen
                                ? '힌트 닫기'
                                : '힌트 다시 보기',
                          ),
                        ),
                      ),
                    if (s.phase != ApplicationPhase.editing &&
                        s.phase != ApplicationPhase.dragging) ...[
                      if (s.phase == ApplicationPhase.wrong)
                        const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton(
                          key: const Key('application-primary'),
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFF191D1A),
                            foregroundColor: Colors.white,
                            minimumSize: const Size.fromHeight(48),
                          ),
                          onPressed: s.phase == ApplicationPhase.wrong
                              ? s.retry
                              : s.phase == ApplicationPhase.failure
                              ? s.reveal
                              : s.phase == ApplicationPhase.complete ||
                                    s.phase == ApplicationPhase.revealed
                              ? explanation
                              : null,
                          child: Text(
                            s.phase == ApplicationPhase.wrong
                                ? '다시 시도하기'
                                : s.phase == ApplicationPhase.failure
                                ? '정답 확인'
                                : s.phase == ApplicationPhase.judging
                                ? '판정 중'
                                : '해설 보기',
                          ),
                        ),
                      ),
                    ],
                  ],
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
                physics: s.pointer != null
                    ? const NeverScrollableScrollPhysics()
                    : null,
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const MannersLearningHeader(),
                    const SizedBox(height: 12),
                    const MannersLessonProgress(number: 1, application: true),
                    const Divider(height: 28),
                    Text(
                      copy!['prompt'],
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        height: 1.45,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      (copy!['situation'] as String).replaceAll(
                        '{characterName}',
                        widget.partner.name,
                      ),
                      style: const TextStyle(
                        fontSize: 14,
                        color: Colors.black54,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      copy!['instruction'],
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 12),
                    scene(s),
                    const SizedBox(height: 16),
                    if (invalid ||
                        s.phase == ApplicationPhase.wrong ||
                        s.phase == ApplicationPhase.complete ||
                        s.phase == ApplicationPhase.failure ||
                        s.phase == ApplicationPhase.revealed ||
                        s.phase == ApplicationPhase.judging)
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF4F4F4),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Text(
                          invalid
                              ? copy!['feedback']['invalid_drag']
                              : s.phase == ApplicationPhase.revealed
                              ? '정답을 확인했어요. 해설에서 짐을 관리하는 방법을 살펴보세요.'
                              : s.phase == ApplicationPhase.failure
                              ? copy!['feedback']['on_fourth_valid_wrong']
                              : s.success
                              ? copy!['feedback']['correct']
                              : copy!['feedback']['wrong'][switch (s.result) {
                                  LuggageDrop.aisle => 'public_aisle',
                                  LuggageDrop.neighbor => 'neighbor_footspace',
                                  _ => 'other_valid_wrong',
                                }],
                        ),
                      ),
                    if (s.hintOpen)
                      MannersHintBubble(
                        partner: widget.partner,
                        stage: s.hint,
                        hintMessages: [
                          for (final h in copy!['hints']) h['text'] as String,
                        ],
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

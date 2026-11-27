import 'common_result_popup.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'recline_lesson_state.dart';
import 'partner_selection_screen.dart';
import 'manners_learning_header.dart';
import 'manners_lesson_progress.dart';
import 'manners_hint_bubble.dart';
import 'lesson_explanation_content.dart';
import 'lesson_explanation_screen.dart';
import 'lesson_feedback_sound.dart';
import 'result_feedback_overlay.dart';
import 'application06_screen.dart';
import 'topic_completion.dart';

class Transit06Screen extends StatefulWidget {
  const Transit06Screen({
    super.key,
    this.partner = MannerPartner.dog,
    this.playSound,
    this.soundMuted = false,
  });
  final MannerPartner partner;
  final LessonSoundPlayer? playSound;
  final bool soundMuted;
  @override
  State<Transit06Screen> createState() => _Transit06ScreenState();
}

class _Transit06ScreenState extends State<Transit06Screen>
    with TickerProviderStateMixin {
  static const root = 'assets/transit06/';
  final lesson = ReclineLessonState(), sceneKey = GlobalKey();
  final masks = <String, Uint8List>{};
  Map<String, dynamic>? problem;
  LessonExplanationContent? education;
  String? error;
  Timer? timer;
  final _resultPopup = LessonResultPresenter();
  int? talkPointer;
  Offset? talkDown;
  late final AnimationController demo = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..addListener(() => lesson.demo(demo.value));
  String get who => switch (widget.partner) {
    MannerPartner.dog => 'dangdang',
    MannerPartner.cat => 'nyangnyang',
    MannerPartner.monkey => 'mongmong',
  };
  String path(String rel) => '${root}assets/runtime/$rel.webp';
  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    try {
      final m = jsonDecode(
        await rootBundle.loadString('${root}runtime_manifest.json'),
      );
      if ((m['pivot'] as List).join(',') != '711,836') {
        throw const FormatException('Wrong rotation pivot');
      }
      // Validate every runtime reference at the bundle boundary, including normalized state paths.
      final mapping = jsonDecode(
        await rootBundle.loadString('${root}state_asset_mapping.json'),
      );
      void validate(dynamic v) {
        if (v is Map) {
          for (final x in v.values) {
            validate(x);
          }
        } else if (v is List) {
          for (final x in v) {
            validate(x);
          }
        } else if (v is String &&
            v.startsWith('assets/runtime/') &&
            !(m['assets'] as List).contains(v)) {
          throw FormatException('Missing runtime path: $v');
        }
      }

      validate(mapping);
      for (final rel in [...m['assets'], ...m['masks']]) {
        final data = await rootBundle.load('$root$rel');
        if (rel.endsWith('.mask')) {
          masks[rel] = data.buffer.asUint8List(
            data.offsetInBytes,
            data.lengthInBytes,
          );
        }
      }
      final p =
          jsonDecode(
                await rootBundle.loadString('${root}problem_transit06.json'),
              )
              as Map<String, dynamic>;
      final e = LessonExplanationContent.fromJson(
        jsonDecode(await rootBundle.loadString('${root}explanation.json')),
      );
      if (!mounted) return;
      await Future.wait(
        (m['assets'] as List)
            .where(
              (x) =>
                  !x.contains('/masks/') &&
                  (!x.contains('/characters/') || x.contains('/${who}_')),
            )
            .map((x) => precacheImage(AssetImage('$root$x'), context)),
      );
      if (mounted) {
        setState(() {
          problem = p;
          education = e;
        });
      }
    } catch (e) {
      if (mounted) setState(() => error = '학습 자료를 불러오지 못했어요: $e');
    }
  }

  @override
  void dispose() {
    _resultPopup.dispose();
    timer?.cancel();
    demo.dispose();
    lesson.dispose();
    super.dispose();
  }

  Offset point(Offset global) {
    final b = sceneKey.currentContext!.findRenderObject()! as RenderBox;
    final p = b.globalToLocal(global);
    final k = math.min(b.size.width / 1536, b.size.height / 1024);
    return (p -
            Offset(
              (b.size.width - 1536 * k) / 2,
              (b.size.height - 1024 * k) / 2,
            )) /
        k;
  }

  bool hit(Offset p) {
    if (p.dx < 0 || p.dy < 0 || p.dx >= 1536 || p.dy >= 1024) return false;
    final bits =
        masks['hit/${who}_${lesson.character}_${lesson.passenger}.mask']!;
    final i = p.dy.floor() * 1536 + p.dx.floor();
    return bits[i >> 3] & (1 << (i & 7)) != 0;
  }

  void down(PointerDownEvent e) {
    if (!lesson.editable || lesson.pointer != null || talkPointer != null) {
      return;
    }
    final p = point(e.position);
    if (!lesson.consent &&
        const Rect.fromLTRB(150, 215, 328, 390).contains(p)) {
      talkPointer = e.pointer;
      talkDown = p;
      return;
    }
    lesson.begin(e.pointer, p, hit(p));
  }

  void up(PointerUpEvent e) {
    if (talkPointer == e.pointer) {
      final tap = (point(e.position) - talkDown!).distance < 40;
      talkPointer = null;
      if (tap) {
        lesson.ask();
        timer?.cancel();
        timer = Timer(const Duration(milliseconds: 650), lesson.reply);
      }
      return;
    }
    if (lesson.release(e.pointer)) {
      unawaited(
        playLessonFeedbackSound(
          widget.playSound,
          lesson.success
              ? LessonFeedbackSound.correct
              : LessonFeedbackSound.wrong,
          muted: widget.soundMuted,
        ),
      );
      timer?.cancel();
      timer = Timer(const Duration(milliseconds: 1750), () {
        if (!mounted) return;
        lesson.settle();
        unawaited(
          _resultPopup.show(
            context,
            partner: widget.partner,
            correct: lesson.success,
            finalFailure: lesson.phase == 'failure',
            muted: widget.soundMuted,
          ),
        );
      });
    }
  }

  Widget image(String rel) =>
      Image.asset(path(rel), fit: BoxFit.fill, excludeFromSemantics: true);
  Widget scene() => AspectRatio(
    aspectRatio: 1.5,
    child: SizedBox(
      key: sceneKey,
      child: Stack(
        fit: StackFit.expand,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: FittedBox(
              fit: BoxFit.contain,
              child: SizedBox(
                width: 1536,
                height: 1024,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    image('background/train_cabin_empty'),
                    image('furniture/rear_fixed_seat'),
                    image('furniture/front_fixed_seat_base'),
                    Transform.rotate(
                      key: const Key('recline-rotation'),
                      angle: lesson.progress * 20 * math.pi / 180,
                      alignment: const Alignment(
                        711 * 2 / 1536 - 1,
                        836 * 2 / 1024 - 1,
                      ),
                      child: image('furniture/front_backrest_rotating'),
                    ),
                    image('characters/${who}_${lesson.character}'),
                    image('passenger/rear_${lesson.passenger}'),
                    image('furniture/rear_fixed_table_laptop'),
                    image('furniture/front_fixed_armrest_support'),
                    if (lesson.editable && !lesson.consent)
                      image('overlays/conversation'),
                    if (lesson.hintOpen) image('overlays/curved_arrow'),
                    if (lesson.busy)
                      image(
                        lesson.success
                            ? 'effects/effect_correct_o'
                            : 'effects/effect_wrong_x',
                      ),
                  ],
                ),
              ),
            ),
          ),
          if (lesson.busy)
            Center(
              child: IgnorePointer(
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                  child: ResultFeedbackSymbol(correct: lesson.success),
                ),
              ),
            ),
        ],
      ),
    ),
  );
  String get feedback => lesson.phase == 'failure'
      ? problem!['feedback']['final_failure']
      : lesson.revealed
      ? problem!['feedback']['answer_reveal']
      : lesson.result.isNotEmpty
      ? problem!['feedback'][lesson.result]
      : lesson.phase == 'asking' ||
            lesson.phase == 'revealing' ||
            lesson.consent
      ? '${problem!['dialogue']['protagonist']}\n${lesson.consent ? problem!['dialogue']['rear_passenger'] : ''}'
      : '';
  Future<void> explanation() async {
    final result = await Navigator.push<ExplanationAction>(
      context,
      MaterialPageRoute(
        builder: (_) => LessonExplanationScreen(
          content: education!,
          partner: widget.partner,
          progressHeader: const MannersLessonProgress(number: 6),
          answerRevealed: lesson.revealed,
          hasNextProblem: true,
          nextLabel: '응용 문제로 이동',
        ),
      ),
    );
    if (!mounted) return;
    if (result == ExplanationAction.next) {
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => Application06Screen(
            partner: widget.partner,
            basicOutcome: lesson.revealed
                ? LearningEnd.answerRevealed
                : LearningEnd.directCorrect,
            playSound: widget.playSound,
            soundMuted: widget.soundMuted,
          ),
        ),
      );
      return;
    }
    if (result == ExplanationAction.replay) {
      timer?.cancel();
      demo.reset();
      lesson.reset();
    }
  }

  void reveal() {
    lesson.reveal();
    timer?.cancel();
    timer = Timer(const Duration(milliseconds: 650), () {
      if (!mounted) return;
      lesson.demoConsent();
      if (MediaQuery.disableAnimationsOf(context)) {
        lesson.demo(1);
      } else {
        demo.forward(from: 0);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (problem == null) {
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
    return ListenableBuilder(
      key: const Key('transit06-ready'),
      listenable: lesson,
      builder: (context, _) => Scaffold(
        backgroundColor: Colors.white,
        bottomNavigationBar: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                if (lesson.editable || lesson.phase == 'wrong')
                  Expanded(
                    child: OutlinedButton(
                      key: const Key('transit06-hint'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF191D1A),
                        minimumSize: const Size.fromHeight(48),
                      ),
                      onPressed: lesson.pointer == null ? lesson.hintTap : null,
                      child: Text(
                        lesson.hint >= 2
                            ? '힌트 닫기'
                            : lesson.hint == 0
                            ? '힌트 보기'
                            : '다음 힌트 보기',
                      ),
                    ),
                  ),
                if (lesson.phase == 'wrong') const SizedBox(width: 12),
                if (!lesson.editable && lesson.phase != 'asking')
                  Expanded(
                    child: FilledButton(
                      key: const Key('transit06-primary'),
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF191D1A),
                        foregroundColor: Colors.white,
                        minimumSize: const Size.fromHeight(48),
                      ),
                      onPressed: lesson.phase == 'complete' || lesson.revealed
                          ? explanation
                          : lesson.phase == 'wrong'
                          ? lesson.retry
                          : lesson.phase == 'failure'
                          ? reveal
                          : null,
                      child: Text(
                        lesson.phase == 'complete' || lesson.revealed
                            ? '해설 보기'
                            : lesson.phase == 'wrong'
                            ? '다시 시도하기'
                            : lesson.phase == 'failure'
                            ? '정답 확인'
                            : lesson.phase == 'revealing'
                            ? '정답 시범 중'
                            : '판정 중',
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        body: SafeArea(
          bottom: false,
          child: Listener(
            behavior: HitTestBehavior.translucent,
            onPointerDown: down,
            onPointerMove: (e) {
              if (lesson.pointer == e.pointer) {
                lesson.move(e.pointer, point(e.position));
              }
            },
            onPointerUp: up,
            onPointerCancel: (e) {
              if (talkPointer == e.pointer) talkPointer = null;
              lesson.cancel(e.pointer);
            },
            child: SingleChildScrollView(
              physics: lesson.pointer != null
                  ? const NeverScrollableScrollPhysics()
                  : null,
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const MannersLearningHeader(),
                  const SizedBox(height: 12),
                  const MannersLessonProgress(number: 6),
                  const Divider(height: 28),
                  Text(
                    problem!['title'],
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      height: 1.45,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    (problem!['description_template'] as String).replaceAll(
                      '{character_name}',
                      widget.partner.name,
                    ),
                    style: const TextStyle(
                      fontSize: 14,
                      height: 1.5,
                      color: Colors.black54,
                    ),
                  ),
                  const SizedBox(height: 16),
                  scene(),
                  const SizedBox(height: 16),
                  Text(
                    problem!['instruction'],
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 16),
                  if (feedback.isNotEmpty)
                    Container(
                      key: const Key('transit06-feedback'),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: lesson.result.isEmpty
                            ? const Color(0xFFF4F4F4)
                            : lesson.success
                            ? const Color(0xFFEAF5EA)
                            : const Color(0xFFFCEDED),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        children: [
                          if (lesson.result.isNotEmpty) ...[
                            ResultFeedbackSymbol(
                              correct: lesson.success,
                              size: 44,
                            ),
                            const SizedBox(width: 12),
                          ],
                          Expanded(child: Text(feedback)),
                        ],
                      ),
                    ),
                  if (lesson.hintOpen)
                    MannersHintBubble(
                      partner: widget.partner,
                      stage: lesson.hint,
                      hintMessages: [
                        for (final h in problem!['hints']) h['text'] as String,
                      ],
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

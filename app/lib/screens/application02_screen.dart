import 'dart:async';
import 'dart:convert';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'application02_state.dart';
import 'common_result_popup.dart';
import 'lesson_explanation_content.dart';
import 'lesson_explanation_screen.dart';
import 'lesson_feedback_sound.dart';
import 'manners_hint_bubble.dart';
import 'manners_learning_header.dart';
import 'manners_lesson_progress.dart';
import 'partner_selection_screen.dart';
import 'result_feedback_overlay.dart';

class Application02Screen extends StatefulWidget {
  const Application02Screen({
    super.key,
    required this.partner,
    this.playSound,
    this.soundMuted = false,
  });
  final MannerPartner partner;
  final LessonSoundPlayer? playSound;
  final bool soundMuted;
  @override
  State<Application02Screen> createState() => _Application02ScreenState();
}

class _Application02ScreenState extends State<Application02Screen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  static const root = 'assets/application02/';
  final sceneKey = GlobalKey();
  final popup = LessonResultPresenter();
  final images = <String, ui.Image>{}, bounds = <String, Rect>{};
  List<int>? heroAlpha;
  Map<String, dynamic>? rules;
  Application02State? lesson;
  String? error;
  late final Ticker ticker = createTicker(tick);
  Duration last = Duration.zero;
  bool resume = false;
  String get who => switch (widget.partner) {
    MannerPartner.dog => 'dangdang',
    MannerPartner.cat => 'nyangnyang',
    MannerPartner.monkey => 'mongmong',
  };
  String get profile =>
      'assets/subway02/assets/characters/${switch (widget.partner) {
        MannerPartner.dog => 'dog',
        MannerPartner.cat => 'cat',
        MannerPartner.monkey => 'monkey',
      }}_thinking_avatar_256.png';
  String get heroPath => rules!['characters'][who]['path'];
  Size get heroSize {
    final b = bounds[heroPath]!;
    return Size(b.width * lesson!.scale, b.height * lesson!.scale);
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    load();
  }

  Future<void> load() async {
    try {
      final jsons = await Future.wait([
        for (final name in [
          'asset_rules',
          'drag_zones',
          'state_asset_mapping',
          'passenger_animation',
        ])
          rootBundle.loadString('${root}spec/$name.json'),
      ]);
      if (!mounted) return;
      rules = jsonDecode(jsons[0]);
      final motion = jsonDecode(jsons[3]) as Map<String, dynamic>;
      final paths = <String>{
        rules!['background'],
        heroPath,
        for (final p in (motion['stay_passengers'] as Map).values) p['asset'],
        for (final p in (motion['exiting_passengers'] as Map).values) ...[
          p['waiting_asset'],
          p['walking_a_asset'],
          p['walking_asset'],
        ],
      };
      for (final path in paths) {
        final data = await rootBundle.load('$root$path');
        final codec = await ui.instantiateImageCodec(
          data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
        );
        final image = (await codec.getNextFrame()).image;
        codec.dispose();
        final rgba = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
        final bytes = rgba!.buffer.asUint8List(
          rgba.offsetInBytes,
          rgba.lengthInBytes,
        );
        if (!mounted) {
          image.dispose();
          return;
        }
        var left = image.width, top = image.height, right = 0, bottom = 0;
        for (var y = 0; y < image.height; y++) {
          for (var x = 0; x < image.width; x++) {
            if (bytes[(y * image.width + x) * 4 + 3] > 0) {
              if (x < left) left = x;
              if (x >= right) right = x + 1;
              if (y < top) top = y;
              if (y >= bottom) bottom = y + 1;
            }
          }
        }
        images[path] = image;
        bounds[path] = Rect.fromLTRB(
          left.toDouble(),
          top.toDouble(),
          right.toDouble(),
          bottom.toDouble(),
        );
        if (path == heroPath) {
          heroAlpha = [for (var i = 3; i < bytes.length; i += 4) bytes[i]];
        }
      }
      if (!mounted) return;
      setState(
        () => lesson = Application02State(
          jsonDecode(jsons[1]),
          jsonDecode(jsons[2]),
          motion,
        ),
      );
    } catch (e) {
      debugPrint('Application02 load failed: $e');
      if (mounted) setState(() => error = '문제 자료를 불러오지 못했어요.');
    }
  }

  void startTicker() {
    if (!ticker.isActive) {
      last = Duration.zero;
      ticker.start();
    }
  }

  void tick(Duration elapsed) {
    final s = lesson!;
    final before = s.phase;
    s.advance((elapsed - last).inMicroseconds / 1000);
    last = elapsed;
    if (before == Transit02Phase.snapping &&
        s.phase == Transit02Phase.judging) {
      feedback(true);
    }
    if (before == Transit02Phase.judging &&
        [
          Transit02Phase.complete,
          Transit02Phase.wrong,
          Transit02Phase.failure,
        ].contains(s.phase)) {
      unawaited(
        popup.show(
          context,
          partner: widget.partner,
          correct: s.success,
          finalFailure: s.phase == Transit02Phase.failure,
          muted: widget.soundMuted,
        ),
      );
    }
    if (!s.ticking) ticker.stop();
  }

  void feedback(bool correct) {
    unawaited(
      playLessonFeedbackSound(
        widget.playSound,
        correct ? LessonFeedbackSound.correct : LessonFeedbackSound.wrong,
        muted: widget.soundMuted,
      ),
    );
    unawaited(HapticFeedback.lightImpact());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      if (resume && lesson?.ticking == true) startTicker();
      resume = false;
    } else {
      resume = resume || ticker.isActive;
      ticker.stop();
      if (lesson?.pointer case final int id) {
        lesson!.cancel(id);
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    ticker.dispose();
    popup.dispose();
    lesson?.dispose();
    for (final image in images.values) {
      image.dispose();
    }
    super.dispose();
  }

  Offset point(Offset global) {
    final b = sceneKey.currentContext!.findRenderObject()! as RenderBox;
    return b.globalToLocal(global) / (b.size.width / 1536);
  }

  bool hit(Offset p) {
    final s = lesson!, b = bounds[heroPath]!, size = heroSize;
    final local =
        (p - Offset(s.foot.dx - size.width / 2, s.foot.dy - size.height)) /
            s.scale +
        b.topLeft;
    final x = local.dx.floor(), y = local.dy.floor();
    final alphaHit =
        x >= 0 &&
        y >= 0 &&
        x < images[heroPath]!.width &&
        y < images[heroPath]!.height &&
        heroAlpha![y * images[heroPath]!.width + x] > 0;
    if (alphaHit) return true;
    // A small platform hero still has a 48dp grip. Drop zones stay unchanged.
    final scene = sceneKey.currentContext!.findRenderObject()! as RenderBox;
    final minimum = 48 * 1536 / scene.size.width;
    final grip = Rect.fromCenter(
      center: s.foot - Offset(0, size.height / 2),
      width: size.width < minimum ? minimum : size.width,
      height: size.height < minimum ? minimum : size.height,
    );
    return grip.contains(p) &&
        const Rect.fromLTWH(0, 0, 1536, 1024).contains(p);
  }

  Future<void> explanation() async {
    final s = lesson!;
    final action = await Navigator.push<ExplanationAction>(
      context,
      MaterialPageRoute(
        builder: (_) => LessonExplanationScreen(
          content: lessonExplanations['subway_02_basic']!,
          profileAsset: profile,
          partner: widget.partner,
          progressHeader: const MannersLessonProgress(
            number: 2,
            application: true,
          ),
          answerRevealed: s.phase == Transit02Phase.revealed,
          hasNextProblem: true,
        ),
      ),
    );
    if (!mounted) return;
    if (action == ExplanationAction.replay) {
      setState(() => lesson = Application02State(s.zones, s.mapping, s.motion));
      s.dispose();
    } else if (action == ExplanationAction.next) {
      Navigator.pop(context, true);
    }
  }

  String message(Application02State s) {
    if (s.invalid) return '이곳에는 설 수 없어요. 안전한 바닥으로 옮겨 보세요.';
    return switch (s.phase) {
      Transit02Phase.step1Success => '좋아요! 안전한 공간에서 승객들이 내리기를 기다려요.',
      Transit02Phase.exiting => '승객들이 먼저 내리고 있어요.',
      Transit02Phase.blocked => '열차가 멈추고 문과 이동 공간이 안전할 때 다시 탑승해요.',
      Transit02Phase.failure => '정답을 함께 확인해 볼까요?',
      Transit02Phase.revealed => '정답을 확인했어요. 직접 성공이나 XP로 기록하지 않아요.',
      Transit02Phase.complete => '좋아요! 승객들이 모두 내린 뒤 안전하게 다시 탑승했어요.',
      Transit02Phase.wrong => '안전선과 하차 통로를 피하고 다른 승객의 길을 비워 주세요.',
      Transit02Phase.judging =>
        s.result == Transit02Drop.correct
            ? '좋아요! 안전하게 다시 탑승했어요.'
            : '다른 승객의 길과 안전한 위치를 다시 살펴보세요.',
      _ =>
        s.stage == 1
            ? '출입문 앞을 비우고 승강장 안전 공간으로 이동해 보세요.'
            : '하차가 끝났어요. 안전하게 다시 탑승해 보세요.',
    };
  }

  @override
  Widget build(BuildContext context) {
    final s = lesson;
    if (s == null) {
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
      key: const Key('application02-ready'),
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
                    Expanded(
                      child: OutlinedButton(
                        key: const Key('application02-hint'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF191D1A),
                          minimumSize: const Size(0, 48),
                          textStyle: const TextStyle(
                            fontFamily: 'Pretendard',
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        onPressed: s.canDrag || s.phase == Transit02Phase.wrong
                            ? s.showHint
                            : null,
                        child: Text(s.hint == 1 ? '다음 힌트 보기' : '힌트 보기'),
                      ),
                    ),
                    if (s.finished ||
                        s.phase == Transit02Phase.wrong ||
                        s.phase == Transit02Phase.failure) ...[
                      const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton(
                          key: const Key('application02-primary'),
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFF191D1A),
                            foregroundColor: Colors.white,
                            minimumSize: const Size(0, 48),
                            textStyle: const TextStyle(
                              fontFamily: 'Pretendard',
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          onPressed: s.finished
                              ? explanation
                              : s.phase == Transit02Phase.failure
                              ? s.reveal
                              : s.retry,
                          child: Text(
                            s.finished
                                ? '해설 보기'
                                : s.phase == Transit02Phase.failure
                                ? '정답 확인'
                                : '다시 시도하기',
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
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const MannersLearningHeader(),
                    const SizedBox(height: 12),
                    const MannersLessonProgress(number: 2, application: true),
                    const SizedBox(height: 24),
                    const Text(
                      '내리는 승객이 있다면 어떻게 해야 할까요?',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${widget.partner.name}는 출입문 앞에 서 있어요. 잠시 내려 다른 승객의 길을 비운 뒤, 안전하게 다시 탑승해 보세요.',
                      style: const TextStyle(fontSize: 14, height: 1.5),
                    ),
                    const SizedBox(height: 12),
                    Stack(
                      children: [
                        const ExcludeSemantics(
                          child: Opacity(
                            opacity: 0,
                            child: Text(
                              Application02State.reboardInstruction,
                              style: TextStyle(fontWeight: FontWeight.w600),
                            ),
                          ),
                        ),
                        Positioned.fill(
                          child: Text(
                            s.instruction,
                            key: const Key('application02-instruction'),
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    AspectRatio(
                      aspectRatio: 1.5,
                      child: RawGestureDetector(
                        gestures: {
                          EagerGestureRecognizer:
                              GestureRecognizerFactoryWithHandlers<
                                EagerGestureRecognizer
                              >(EagerGestureRecognizer.new, (_) {}),
                        },
                        child: Listener(
                          key: sceneKey,
                          behavior: HitTestBehavior.opaque,
                          onPointerDown: (e) {
                            final p = point(e.position);
                            s.begin(e.pointer, p, hit(p));
                          },
                          onPointerMove: (e) =>
                              s.move(e.pointer, point(e.position), heroSize),
                          onPointerCancel: (e) => s.cancel(e.pointer),
                          onPointerUp: (e) {
                            final result = s.release(
                              e.pointer,
                              point(e.position),
                            );
                            if (result == Transit02Drop.wrong) feedback(false);
                            if (s.ticking) startTicker();
                          },
                          child: Stack(
                            children: [
                              Positioned.fill(
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(16),
                                  child: CustomPaint(
                                    key: const Key('application02-scene'),
                                    painter: Application02ScenePainter(
                                      s,
                                      rules!,
                                      images,
                                      bounds,
                                      heroPath,
                                    ),
                                  ),
                                ),
                              ),
                              if (s.phase == Transit02Phase.judging)
                                Center(
                                  child: ResultFeedbackSymbol(
                                    correct: s.result == Transit02Drop.correct,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      constraints: const BoxConstraints(minHeight: 72),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF4F4F4),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(
                        message(s),
                        style: const TextStyle(fontSize: 14, height: 1.5),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 96,
                      child: s.hintOpen
                          ? MannersHintBubble(
                              partner: widget.partner,
                              profileAsset: profile,
                              stage: s.hint,
                              hintMessages: const [
                                '출입문 앞을 비우면 내리는 승객들이 편하게 지나갈 수 있어요. 안전선에서 떨어진 곳을 찾아볼까요?',
                                '승객들이 모두 내린 뒤, 문 앞을 막지 않는 객실 안의 안전한 공간으로 다시 탑승해요.',
                              ],
                            )
                          : null,
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

class Application02ScenePainter extends CustomPainter {
  Application02ScenePainter(
    this.state,
    this.rules,
    this.images,
    this.bounds,
    this.heroPath,
  );
  final Application02State state;
  final Map<String, dynamic> rules;
  final Map<String, ui.Image> images;
  final Map<String, Rect> bounds;
  final String heroPath;
  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 1536);
    canvas.clipRect(const Rect.fromLTWH(0, 0, 1536, 1024));
    final bg = images[rules['background']]!;
    canvas.drawImageRect(
      bg,
      Rect.fromLTWH(0, 0, bg.width.toDouble(), bg.height.toDouble()),
      const Rect.fromLTWH(0, 0, 1536, 1024),
      Paint(),
    );
    void draw(String path, Offset foot, double height) {
      final source = bounds[path]!,
          width = source.width / source.height * height;
      canvas.drawImageRect(
        images[path]!,
        source,
        Rect.fromLTWH(foot.dx - width / 2, foot.dy - height, width, height),
        Paint()..filterQuality = FilterQuality.medium,
      );
    }

    final stays = (state.motion['stay_passengers'] as Map).values.toList()
      ..sort(
        (a, b) => (a['foot_anchor_px'][1] as num).compareTo(
          b['foot_anchor_px'][1] as num,
        ),
      );
    for (final p in stays) {
      draw(
        p['asset'],
        transit02Point(p['foot_anchor_px']),
        (p['render_height_px'] as num).toDouble(),
      );
    }
    if (state.passengersVisible) {
      final poses = [
        for (final p in (state.motion['exiting_passengers'] as Map).values)
          Transit02PassengerPose.at(
            p,
            state.phase == Transit02Phase.exiting ? state.elapsed : -1,
          ),
      ];
      poses.sort((a, b) => a.foot.dy.compareTo(b.foot.dy));
      for (final pose in poses) {
        draw(pose.asset, pose.foot, pose.height);
      }
    }
    draw(heroPath, state.foot, bounds[heroPath]!.height * state.scale);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant Application02ScenePainter oldDelegate) => true;
}

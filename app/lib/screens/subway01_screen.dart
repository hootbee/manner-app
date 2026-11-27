import 'subway03_screen.dart';
import 'application02_screen.dart';
import 'application01_screen.dart';
import 'topic_completion.dart';
import 'subway02_screen.dart';
import 'common_result_popup.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'action_drag_state.dart';
import 'partner_selection_screen.dart';
import 'manners_hint_bubble.dart';
import 'manners_learning_header.dart';
import 'lesson_feedback_sound.dart';
import 'lesson_explanation_screen.dart';
import 'lesson_explanation_content.dart';
import 'subway02_content.dart';
import 'subway02_hitbox_overlay.dart';

enum SubwayLesson { backpack, exit }

/// Shared action-lesson shell. The default remains the approved 01 experience.
class Subway01Screen extends StatefulWidget {
  const Subway01Screen({
    super.key,
    this.partner = MannerPartner.dog,
    this.playSound,
    this.soundMuted = false,
    this.onNextProblem,
    this.lesson = SubwayLesson.backpack,
    this.debugHitboxes = false,
  });
  final MannerPartner partner;
  final LessonSoundPlayer? playSound;
  final bool soundMuted;
  final SubwayLesson lesson;
  final bool debugHitboxes;

  /// Only set when an actual linked application problem exists in the catalog.
  final VoidCallback? onNextProblem;
  @override
  State<Subway01Screen> createState() => _Subway01ScreenState();
}

class _Subway01ScreenState extends State<Subway01Screen>
    with SingleTickerProviderStateMixin {
  ActionDragState? _state;
  DragStartMask? _hitMask;
  Map<String, dynamic>? _exitMapping;
  bool _viewingHint = false;
  static final _maskCache = <SubwayLesson, Uint8List>{};
  bool get _isExit => widget.lesson == SubwayLesson.exit;
  String get _assets => _isExit ? 'assets/subway02/' : 'assets/subway01/';
  String get _sceneKey => _isExit ? 'subway02' : 'subway01';
  String get _profile =>
      'assets/subway02/assets/characters/${widget.partner.name == '댕댕이'
          ? 'dog'
          : widget.partner.name == '냥냥이'
          ? 'cat'
          : 'monkey'}_thinking_avatar_256.png';
  bool _showPopup = false;
  String? _error;
  Timer? _timer;
  final _resultPopup = LessonResultPresenter();
  Timer? _popupTimer;
  late final _effect = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 1),
  );
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final rules =
          jsonDecode(await rootBundle.loadString('${_assets}asset_rules.json'))
              as Map<String, dynamic>;
      if (!_maskCache.containsKey(widget.lesson)) {
        final data = await rootBundle.load(
          '$_assets${_isExit ? rules['draggable']['hit_mask'] : 'backpack_start_hit_mask.png'}',
        );
        final codec = await ui.instantiateImageCodec(
          data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
        );
        final frame = await codec.getNextFrame();
        final bytes = await frame.image.toByteData(
          format: ui.ImageByteFormat.rawRgba,
        );
        _maskCache[widget.lesson] = bytes!.buffer.asUint8List(
          bytes.offsetInBytes,
          bytes.lengthInBytes,
        );
        frame.image.dispose();
        codec.dispose();
      }
      if (!mounted) return;
      // Preload every scene layer so feedback cannot briefly lose a character.
      final mapping = jsonDecode(
        await rootBundle.loadString('${_assets}state_asset_mapping.json'),
      );
      if (!mounted) return;
      final names = <String>{
        if (!_isExit) ...[
          'backpack_drag.png',
          'effect_correct.png',
          'effect_wrong.png',
        ],
      };
      final entries = _isExit
          ? (mapping['states'] as Map).values
          : mapping as List;
      for (final entry in entries) {
        for (final name in entry[_isExit ? 'layer_assets' : 'layers'] as List) {
          names.add((name as String).split(' (').first);
        }
        if (_isExit && entry['variants'] != null) {
          for (final variant in (entry['variants'] as Map).values) {
            names.addAll(List<String>.from(variant['layer_assets']));
          }
        }
      }
      await Future.wait(
        names.map(
          (name) => precacheImage(AssetImage('$_assets$name'), context),
        ),
      );
      if (!mounted) return;
      setState(() {
        final d = rules['draggable'];
        final box = _isExit
            ? [
                d['initial_top_left'][0],
                d['initial_top_left'][1],
                (d['initial_top_left'][0] as num) + (d['size_px'][0] as num),
                (d['initial_top_left'][1] as num) + (d['size_px'][1] as num),
              ]
            : rules['zones']['backpack_drag_start']['bounding_rect'] as List;
        _hitMask = DragStartMask(
          rgba: _maskCache[widget.lesson]!,
          width: 1536,
          height: 1024,
          channel: _isExit ? 3 : 0,
          threshold: _isExit
              ? rules['draggable']['hit_alpha_threshold'] as int
              : 128,
          bounds: Rect.fromLTRB(
            (box[0] as num).toDouble(),
            (box[1] as num).toDouble(),
            (box[2] as num).toDouble(),
            (box[3] as num).toDouble(),
          ),
        );
        _state = ActionDragState(rules);
        if (_isExit) _exitMapping = mapping['states'] as Map<String, dynamic>;
      });
    } catch (error) {
      debugPrint('Subway01 asset load failed: $error');
      if (mounted) setState(() => _error = '상황 그림을 불러오지 못했어요. 다시 시도해 주세요.');
    }
  }

  @override
  void dispose() {
    _resultPopup.dispose();
    _timer?.cancel();
    _popupTimer?.cancel();
    _effect.dispose();
    _state?.dispose();
    super.dispose();
  }

  bool _hit(Offset p) => _hitMask!.hit(
    p,
    _isExit
        ? 0
        : (_state!.rules['interaction_overrides']['drag_start_tolerance_px']
                  as num)
              .toDouble(),
  );

  void _release(PointerUpEvent e) {
    final s = _state!;
    if (s.pointer != e.pointer) return;
    s.release(e.pointer, e.localPosition);
    if (!s.busy) return;
    _viewingHint = false;
    if (_isExit) {
      setState(() => _showPopup = true);
      _popupTimer?.cancel();
      _popupTimer = Timer(
        Duration(milliseconds: s.rules['timing_ms']['correct_O_popup'] as int),
        () {
          if (mounted) setState(() => _showPopup = false);
        },
      );
    }
    final wrong = !s.success;
    unawaited(
      playLessonFeedbackSound(
        widget.playSound,
        wrong ? LessonFeedbackSound.wrong : LessonFeedbackSound.correct,
        muted: widget.soundMuted,
      ),
    );
    if (wrong &&
        !kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.android ||
            defaultTargetPlatform == TargetPlatform.iOS)) {
      unawaited(HapticFeedback.lightImpact().catchError((Object _) {}));
    }
    if (!MediaQuery.disableAnimationsOf(context)) _effect.forward(from: 0);
    _timer?.cancel();
    _timer = Timer(
      Duration(
        milliseconds: _isExit
            ? s.rules['timing_ms']['correct_feedback'] as int
            : 1000,
      ),
      () {
        if (mounted) {
          s.settle();
          unawaited(
            _resultPopup.show(
              context,
              partner: widget.partner,
              correct: s.success,
              finalFailure: s.phase == ActionPhase.finalFailure,
              muted: widget.soundMuted,
            ),
          );
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_state == null) {
      return Scaffold(
        body: SafeArea(
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
                      TextButton(
                        onPressed: () => Navigator.maybePop(context),
                        child: const Text('돌아가기'),
                      ),
                    ],
                  ),
          ),
        ),
      );
    }
    return ListenableBuilder(
      key: Key('$_sceneKey-ready'),
      listenable: _state!,
      builder: (context, _) {
        final s = _state!;
        return Scaffold(
          backgroundColor: Colors.white,
          body: SafeArea(
            child: ListView(
              physics: s.pointer == null
                  ? null
                  : const NeverScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(18, 8, 18, 24),
              children: [
                const MannersLearningHeader(),
                const SizedBox(height: 12),
                _progressHeader(),
                const Divider(height: 28, color: Color(0xFFEEEEEE)),
                _questionHeading(),
                const SizedBox(height: 10),
                Text(
                  _isExit
                      ? subway02Copy['상황 설명']!
                      : '등에 멘 백팩이 주변 승객과 자꾸 부딪히고 있어요.',
                  style: const TextStyle(
                    fontSize: 14,
                    height: 1.5,
                    color: Colors.black54,
                  ),
                ),
                const SizedBox(height: 18),
                Center(
                  child: Chip(
                    avatar: const Icon(
                      Icons.touch_app_outlined,
                      size: 19,
                      color: Color(0xFF191D1A),
                    ),
                    shape: const StadiumBorder(),
                    label: Text(
                      _isExit ? subway02Copy['조작 안내']! : '가방을 드래그해 보세요.',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    side: BorderSide.none,
                    backgroundColor: const Color(0xFFF4F4F4),
                  ),
                ),
                const SizedBox(height: 8),
                AnimatedBuilder(
                  animation: _effect,
                  builder: (context, child) {
                    final shake =
                        s.phase == ActionPhase.wrongJustJudged &&
                            _effect.value < .2 &&
                            !MediaQuery.disableAnimationsOf(context)
                        ? math.sin(_effect.value * math.pi * 50) * 4
                        : 0.0;
                    return Transform.translate(
                      offset: Offset(shake, 0),
                      child: child,
                    );
                  },
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(18),
                    child: AspectRatio(
                      aspectRatio: 1536 / 1024,
                      child: FittedBox(
                        fit: BoxFit.contain,
                        child: SizedBox(
                          width: 1536,
                          height: 1024,
                          child: Listener(
                            key: Key('$_sceneKey-scene'),
                            behavior: HitTestBehavior.opaque,
                            onPointerDown: (e) => s.begin(
                              e.pointer,
                              e.localPosition,
                              _hit(e.localPosition),
                            ),
                            onPointerMove: (e) =>
                                s.move(e.pointer, e.localPosition),
                            onPointerUp: _release,
                            onPointerCancel: (e) => s.cancel(e.pointer),
                            child: _isExit ? _exitScene(s) : _scene(s),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                _feedback(s),
                const SizedBox(height: 8),
                _actions(s),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _progressHeader() {
    if (MediaQuery.textScalerOf(context).scale(14) > 14) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFFF7F7F7),
          border: Border.all(color: const Color(0xFFE7E7E7)),
          borderRadius: BorderRadius.circular(24),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Wrap(
              spacing: 12,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                const Icon(Icons.directions_subway),
                const Text(
                  '대중교통',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
                ),
                Text(
                  '기본 문제 ${_isExit ? 2 : 1}/20',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            LinearProgressIndicator(
              value: (_isExit ? 2 : 1) / 20,
              minHeight: 8,
              borderRadius: BorderRadius.circular(8),
              color: const Color(0xFF191D1A),
              backgroundColor: const Color(0xFFE4E4E4),
            ),
          ],
        ),
      );
    }
    return Container(
      height: 50,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F7F7),
        border: Border.all(color: const Color(0xFFE7E7E7)),
        borderRadius: BorderRadius.circular(24),
      ),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: SizedBox(
          width: 340,
          child: Row(
            children: [
              const CircleAvatar(
                radius: 17,
                backgroundColor: Color(0xFFECECEC),
                child: Icon(
                  Icons.directions_subway,
                  color: Colors.black,
                  size: 23,
                ),
              ),
              const SizedBox(height: 24, child: VerticalDivider(width: 16)),
              const Text(
                '대중교통',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
              ),
              const SizedBox(width: 10),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFEDEDED),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '기본 문제 ${_isExit ? 2 : 1}/20',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: LinearProgressIndicator(
                  value: (_isExit ? 2 : 1) / 20,
                  minHeight: 8,
                  borderRadius: BorderRadius.circular(8),
                  color: const Color(0xFF191D1A),
                  backgroundColor: const Color(0xFFE4E4E4),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _questionHeading() {
    final title = _isExit ? subway02Copy['질문']! : '혼잡한 지하철에서 백팩은 어떻게 해야 할까요?';
    // Keep each Korean word together while allowing normal space wrapping.
    final wrapped = title
        .split(' ')
        .map((word) => word.split('').join('\u2060'))
        .join(' ');
    return Text(
      wrapped,
      semanticsLabel: title,
      style: const TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w900,
        height: 1.45,
      ),
    );
  }

  Widget _feedback(ActionDragState s) {
    final showHint =
        s.hint > 0 &&
        (s.canDrag || s.phase == ActionPhase.dragging || _viewingHint);
    return Semantics(
      liveRegion: true,
      child: SizedBox(
        height: 96,
        child: showHint
            ? Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 319),
                  child: MannersHintBubble(
                    partner: widget.partner,
                    stage: s.hint,
                    hintMessages: _isExit
                        ? [subway02Copy['힌트 1']!, subway02Copy['힌트 2']!]
                        : MannersHintBubble.messages,
                    profileAsset: _isExit ? _profile : null,
                  ),
                ),
              )
            : Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFF4F4F4),
                  borderRadius: BorderRadius.circular(22),
                ),
                child: Row(
                  children: [
                    Icon(
                      s.success ? Icons.check_circle : Icons.info_outline,
                      size: 28,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: SingleChildScrollView(
                        child: Text(
                          _message(s),
                          style: const TextStyle(
                            fontSize: 14,
                            height: 1.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _actions(ActionDragState s) => SizedBox(
    key: Key('$_sceneKey-actions'),
    height: 48,
    child: s.success
        ? _button('해설 보기', s.busy ? null : _explanation)
        : s.phase == ActionPhase.finalFailure
        ? _button(
            s.revealed ? '해설 보기' : '정답 확인',
            s.revealed ? _explanation : s.reveal,
          )
        : s.hint == 1 && (s.canDrag || s.phase == ActionPhase.dragging)
        ? Align(
            alignment: Alignment.centerLeft,
            child: SizedBox(
              width: 170,
              height: 48,
              child: FilledButton(
                onPressed: s.pointer != null ? null : () => _openHint(s),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF505050),
                  foregroundColor: Colors.white,
                ),
                child: const FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    '다음 힌트 보기',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ),
          )
        : Row(
            children: [
              if (s.hint < 2)
                Expanded(
                  child: _button(
                    s.hint == 1 ? '다음 힌트 보기' : '힌트 보기',
                    s.busy || s.pointer != null ? null : () => _openHint(s),
                  ),
                ),
              if (s.phase == ActionPhase.wrongComplete) ...[
                if (s.hint < 2) const SizedBox(width: 8),
                Expanded(
                  child: _button('다시 시도하기', () {
                    _viewingHint = false;
                    _effect.reset();
                    _showPopup = false;
                    s.retry();
                  }),
                ),
              ],
            ],
          ),
  );

  void _openHint(ActionDragState s) {
    setState(() => _viewingHint = true);
    s.showHint();
  }

  String _message(ActionDragState s) {
    if (_isExit) {
      if (s.success) return subway02Copy['정답']!;
      if (s.revealed) return subway02Copy['최종 실패 안내']!;
      if (s.phase == ActionPhase.finalFailure) {
        return '네 번의 시도를 마쳤어요. 정답 확인을 눌러 권장 행동을 살펴보세요.';
      }
      return subway02Copy[s.canDrag || s.phase == ActionPhase.dragging
          ? '초기 하단 안내'
          : '오답']!;
    }
    if (s.success) return '좋아요! 가방을 몸 앞쪽으로 옮기니 주변 승객이 더 편해졌어요.';
    if (s.revealed) {
      return '정답을 확인했어요. 가방을 몸 앞쪽으로 내려 잡으면 다른 승객의 이동 공간을 배려할 수 있어요. 성공으로 기록되지는 않아요.';
    }
    if (s.phase == ActionPhase.finalFailure) {
      return '네 번의 시도를 마쳤어요. 정답 확인을 눌러 권장 행동을 살펴보세요.';
    }
    if (!s.canDrag && s.phase != ActionPhase.dragging) {
      return '가방이 통로를 막아 다른 승객이 지나가기 어려워요.';
    }
    return '다른 승객이 불편하지 않도록 가방을 옮겨주세요.';
  }

  Widget _button(String label, VoidCallback? onPressed) => SizedBox(
    height: 48,
    child: FilledButton(
      onPressed: onPressed,
      style: FilledButton.styleFrom(backgroundColor: const Color(0xFF191D1A)),
      child: Text(
        label,
        style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
      ),
    ),
  );

  /// Full-canvas layers retain their original origin, including on wrong drops.
  Widget _exitScene(ActionDragState s) {
    final correct = s.success || s.revealed;
    final wrong =
        !correct &&
        (s.phase == ActionPhase.wrongJustJudged ||
            s.phase == ActionPhase.wrongComplete ||
            s.phase == ActionPhase.finalFailure);
    final stateName = correct
        ? 'correct_complete'
        : wrong
        ? 'wrong_complete'
        : s.phase == ActionPhase.dragging
        ? 'dragging'
        : 'initial';
    final entry = _exitMapping![stateName];
    final variants = s.rules['correct_snap']['variants'] as Map;
    final zoneId = s.correctZoneId ?? variants.keys.last;
    final snap = variants[zoneId] as Map;
    final mapping = correct ? (entry['variants']?[zoneId] ?? entry) : entry;
    final names = List<String>.from(mapping['layer_assets']);
    // Mapping includes persistent O/X and a premature final-failure reveal.
    // The interaction state, not the image mapping, owns those decisions.
    names.removeWhere((n) => n.startsWith('assets/effects/'));
    Widget image(String path) => Image.asset(
      '$_assets$path',
      fit: BoxFit.fill,
      excludeFromSemantics: true,
    );
    return Semantics(
      label: correct
          ? '몽몽이가 출입문 옆 공간으로 비켜 하차 통로를 비운 장면'
          : '몽몽이가 출입문 앞 하차 통로를 막고 있어요. 몽몽이를 드래그하세요.',
      child: Stack(
        children: [
          for (final name in names)
            Positioned.fill(
              child: name.contains('/monkey_') && !correct
                  ? Transform.translate(
                      key: const Key('subway02-monkey-offset'),
                      offset: s.delta,
                      child: image(name),
                    )
                  : name.contains('/monkey_') && correct
                  ? _alignedMonkey(s, snap, image(name))
                  : image(name),
            ),
          if (s.canDrag && s.hint > 0)
            Positioned.fill(
              child: IgnorePointer(
                child: image('assets/effects/hint_${s.hint}_overlay.png'),
              ),
            ),
          if (_showPopup && !s.revealed)
            Positioned.fill(
              child: IgnorePointer(
                child: Transform.translate(
                  key: const Key('subway02-result-effect'),
                  // Wrong X follows the actual body, not a fixed central example.
                  offset: correct
                      ? Offset.zero
                      : Offset(
                          (985 + s.delta.dx).clamp(0, 1439).toDouble() - 1025,
                          (480 + s.delta.dy).clamp(0, 927).toDouble() - 500,
                        ),
                  child: image(
                    correct
                        ? snap['effect_asset'] as String
                        : 'assets/effects/effect_wrong.png',
                  ),
                ),
              ),
            ),
          if (kDebugMode && widget.debugHitboxes)
            Positioned.fill(
              child: IgnorePointer(
                child: CustomPaint(
                  key: const Key('subway02-hitboxes'),
                  painter: Subway02HitboxPainter(
                    rules: s.rules,
                    anchor: correct
                        ? Offset(
                            (snap['foot_anchor_px'][0] as num).toDouble(),
                            (snap['foot_anchor_px'][1] as num).toDouble(),
                          )
                        : s.anchor + s.delta,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _alignedMonkey(ActionDragState s, Map snap, Widget child) {
    final p = snap['top_left_px'], size = snap['sprite_size_px'];
    final target = snap['foot_anchor_px'];
    final delta =
        s.anchor +
        s.delta -
        Offset((target[0] as num).toDouble(), (target[1] as num).toDouble());
    // Judge the original drop first, then keep every snap frame fully visible.
    final start = Offset(
      delta.dx
          .clamp(
            -(p[0] as num).toDouble(),
            1536 - (p[0] as num) - (size[0] as num),
          )
          .toDouble(),
      delta.dy
          .clamp(
            -(p[1] as num).toDouble(),
            1024 - (p[1] as num) - (size[1] as num),
          )
          .toDouble(),
    );
    return TweenAnimationBuilder<Offset>(
      key: ValueKey('subway02-snap-${snap['asset']}'),
      tween: Tween(begin: start, end: Offset.zero),
      duration: Duration(
        milliseconds: MediaQuery.disableAnimationsOf(context) ? 0 : 220,
      ),
      curve: Curves.easeOut,
      builder: (context, offset, child) => Transform.translate(
        key: const Key('subway02-snap-offset'),
        offset: offset,
        child: child,
      ),
      child: child,
    );
  }

  Widget _scene(ActionDragState s) {
    final correct = s.success || s.revealed;
    final wrong =
        !correct &&
        (s.phase == ActionPhase.wrongJustJudged ||
            s.phase == ActionPhase.wrongComplete ||
            s.phase == ActionPhase.finalFailure);
    Widget layer(String name) => Positioned.fill(
      child: Image.asset(
        '$_assets$name',
        fit: BoxFit.fill,
        excludeFromSemantics: true,
      ),
    );
    final map = s.rules['layers_bottom_to_top'];
    final names = List<String>.from(
      map[correct
          ? 'correct'
          : wrong
          ? 'wrong'
          : 'initial'],
    );
    final dragging = s.phase == ActionPhase.dragging;
    if (dragging) names.remove('strap_front_overlay.png');
    final raised = dragging && s.delta.distance > 20;
    final dropCenter = s.initial.center + s.delta;
    final oldWrong = Path()
      ..addPolygon([
        for (final point in s.rules['zones']['wrong']['points'])
          Offset((point[0] as num).toDouble(), (point[1] as num).toDouble()),
      ], true);
    final floorDrop = wrong && !oldWrong.contains(dropCenter);
    final wrongPlacement = s.rules['backpack_placements']['wrong'];
    Widget bag() => Positioned(
      left: s.initial.left + s.delta.dx,
      top: s.initial.top + s.delta.dy,
      width: s.initial.width,
      height: s.initial.height,
      child: Image.asset(
        '${_assets}backpack_drag.png',
        excludeFromSemantics: true,
      ),
    );
    return Semantics(
      label: correct
          ? '가방을 몸 앞쪽으로 관리해 승객이 편안해진 장면'
          : wrong
          ? '통로 바닥의 가방이 승객의 이동을 막는 장면'
          : '등에 멘 백팩과 불편해하는 주변 승객. 백팩을 드래그하세요.',
      child: Stack(
        children: [
          for (final name in names)
            if (floorDrop && name == 'backpack_wrong_layer.png')
              Positioned(
                left: dropCenter.dx - (wrongPlacement['w'] as num) / 2,
                top: dropCenter.dy - (wrongPlacement['h'] as num) / 2,
                width: (wrongPlacement['w'] as num).toDouble(),
                height: (wrongPlacement['h'] as num).toDouble(),
                child: Image.asset(
                  '${_assets}backpack_drag.png',
                  excludeFromSemantics: true,
                ),
              )
            else if (dragging && name == 'backpack_initial_layer.png') ...[
              if (!raised) bag(),
            ] else
              layer(name),
          if (raised) bag(),
          if (s.hint == 1 && s.canDrag)
            Positioned(
              left: s.initial.left - 18,
              top: s.initial.top - 18,
              width: s.initial.width + 36,
              height: s.initial.height + 36,
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(50),
                    border: Border.all(
                      color: const Color(0x66C4A35A),
                      width: 8,
                    ),
                  ),
                ),
              ),
            ),
          if (s.busy)
            Positioned(
              left: correct
                  ? 820
                  : floorDrop
                  ? (dropCenter.dx + 70).clamp(0, 1416).toDouble()
                  : 1080,
              top: correct
                  ? 550
                  : floorDrop
                  ? dropCenter.dy - 145
                  : 680,
              width: 120,
              height: 120,
              child: AnimatedBuilder(
                animation: _effect,
                builder: (context, child) => Transform.scale(
                  scale: MediaQuery.disableAnimationsOf(context)
                      ? 1
                      : 1 + math.sin(_effect.value * math.pi) * .2,
                  child: child,
                ),
                child: Image.asset(
                  '$_assets${correct ? 'effect_correct.png' : 'effect_wrong.png'}',
                ),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _explanation() async {
    final action = await Navigator.of(context).push<ExplanationAction>(
      MaterialPageRoute<ExplanationAction>(
        builder: (_) => LessonExplanationScreen(
          content:
              lessonExplanations[_isExit ? 'subway_02_basic' : 'transport-1']!,
          partner: widget.partner,
          profileAsset: _isExit ? _profile : null,
          progressHeader: _progressHeader(),
          answerRevealed: _state!.revealed,
          hasNextProblem: true,
          nextLabel: '응용 문제로 이동',
        ),
      ),
    );
    if (!mounted) return;
    if (action == ExplanationAction.replay) {
      _timer?.cancel();
      _popupTimer?.cancel();
      _effect.reset();
      _showPopup = false;
      _viewingHint = false;
      _state!.resetAttempt();
    } else if (action == ExplanationAction.next) {
      if (_isExit) {
        final next = await Navigator.of(context).push<bool>(
          MaterialPageRoute(
            builder: (_) => Application02Screen(
              partner: widget.partner,
              playSound: widget.playSound,
              soundMuted: widget.soundMuted,
            ),
          ),
        );
        if (!mounted || next != true) return;
        if (widget.onNextProblem != null) {
          widget.onNextProblem!.call();
        } else {
          await Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (_) => Subway03Screen(partner: widget.partner),
            ),
          );
        }
      } else {
        final next = await Navigator.of(context).push<bool>(
          MaterialPageRoute(
            builder: (_) => Application01Screen(
              partner: widget.partner,
              basicOutcome: _state!.revealed
                  ? LearningEnd.answerRevealed
                  : LearningEnd.directCorrect,
              playSound: widget.playSound,
              soundMuted: widget.soundMuted,
            ),
          ),
        );
        if (!mounted || next != true) return;
        if (widget.onNextProblem != null) {
          widget.onNextProblem!.call();
        } else {
          await Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (_) => Subway02Screen(partner: widget.partner),
            ),
          );
        }
      }
    }
  }
}

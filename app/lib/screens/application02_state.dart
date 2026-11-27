import 'dart:math' as math;
import 'package:flutter/animation.dart';
import 'package:flutter/foundation.dart';

enum Transit02Phase {
  ready,
  dragging,
  snapping,
  step1Success,
  exiting,
  blocked,
  judging,
  wrong,
  failure,
  complete,
  revealed,
}

enum Transit02Drop { correct, wrong, invalid }

Offset transit02Point(List<dynamic> v) =>
    Offset((v[0] as num).toDouble(), (v[1] as num).toDouble());

class Application02State extends ChangeNotifier {
  Application02State(this.zones, this.mapping, this.motion) {
    foot = start;
    scale = stageScale;
  }
  final Map<String, dynamic> zones, mapping, motion;
  Transit02Phase phase = Transit02Phase.ready;
  Transit02Drop result = Transit02Drop.invalid;
  int stage = 1, wrongCount = 0, hint = 0;
  bool hintOpen = false, invalid = false;
  bool trainStopped = true,
      doorsOpen = true,
      reboardingSafe = true,
      exitingComplete = false;
  late Offset foot;
  late double scale;
  Offset? pointerOffset;
  int? pointer;
  double elapsed = 0;
  Offset snapFrom = Offset.zero;
  double snapScaleFrom = 1;
  Map<String, dynamic> get stageSpec => zones['stage$stage'];
  Offset get start => transit02Point(stageSpec['start_anchor_px']);
  Offset get target => transit02Point(stageSpec['target_anchor_px']);
  double get stageScale => stage == 1
      ? (mapping['stages']['initial']['character_scale'] as num).toDouble()
      : (mapping['stages']['step2_ready']['character_scale'] as num).toDouble();
  bool get safe =>
      trainStopped && doorsOpen && reboardingSafe && exitingComplete;
  bool get canDrag => phase == Transit02Phase.ready && (stage == 1 || safe);
  bool get success => phase == Transit02Phase.complete;
  bool get finished => success || phase == Transit02Phase.revealed;
  bool get passengersVisible =>
      !exitingComplete && phase != Transit02Phase.revealed;
  static const reboardInstruction = '하차가 끝났어요! 안전하게 다시 탑승해 보세요. · 2/2단계';
  String get instruction {
    if (phase == Transit02Phase.exiting) return '승객들이 내리는 중이에요.';
    if (phase == Transit02Phase.step1Success) return '안전한 공간에서 잠시 기다려요.';
    if (phase == Transit02Phase.blocked) return '안전한 탑승 조건을 기다려 주세요. · 2/2단계';
    if (phase == Transit02Phase.complete) return '안전하게 다시 탑승했어요. · 2/2단계';
    if (phase == Transit02Phase.revealed) return '정답 위치를 확인했어요. · 2/2단계';
    return stage == 1 ? '캐릭터를 드래그해 보세요. · 1/2단계' : reboardInstruction;
  }

  bool get ticking => [
    Transit02Phase.snapping,
    Transit02Phase.step1Success,
    Transit02Phase.exiting,
    Transit02Phase.judging,
  ].contains(phase);

  static bool inside(Offset p, List<dynamic> polygon) {
    var hit = false;
    for (var i = 0, j = polygon.length - 1; i < polygon.length; j = i++) {
      final a = transit02Point(polygon[i]), b = transit02Point(polygon[j]);
      final cross =
          (p.dx - a.dx) * (b.dy - a.dy) - (p.dy - a.dy) * (b.dx - a.dx);
      if (cross.abs() < 1e-6 &&
          p.dx >= math.min(a.dx, b.dx) &&
          p.dx <= math.max(a.dx, b.dx) &&
          p.dy >= math.min(a.dy, b.dy) &&
          p.dy <= math.max(a.dy, b.dy)) {
        return true;
      }
      if ((a.dy > p.dy) != (b.dy > p.dy) &&
          p.dx < (b.dx - a.dx) * (p.dy - a.dy) / (b.dy - a.dy) + a.dx) {
        hit = !hit;
      }
    }
    return hit;
  }

  Transit02Drop classify(Offset at) {
    if (stage == 2 && !safe ||
        !const Rect.fromLTWH(0, 0, 1536, 1024).contains(at)) {
      return Transit02Drop.invalid;
    }
    final matches = (zones['zones'] as List).where(
      (z) => z['stage'] == 'step$stage' && inside(at, z['polygon_px']),
    );
    for (final kind in ['invalid', 'wrong', 'correct']) {
      if (matches.any((z) => z['result'] == kind)) {
        return Transit02Drop.values.byName(kind);
      }
    }
    return Transit02Drop.invalid;
  }

  bool begin(int id, Offset at, bool hit) {
    if (!canDrag || pointer != null || !hit) return false;
    pointer = id;
    pointerOffset = at - foot;
    phase = Transit02Phase.dragging;
    notifyListeners();
    return true;
  }

  void move(int id, Offset at, Size sprite) {
    if (pointer != id) return;
    final candidate = at - pointerOffset!;
    foot = Offset(
      candidate.dx.clamp(sprite.width / 2, 1536 - sprite.width / 2),
      candidate.dy.clamp(sprite.height, 1024),
    );
    notifyListeners();
  }

  void cancel(int id) {
    if (pointer != id) return;
    pointer = null;
    pointerOffset = null;
    foot = start;
    scale = stageScale;
    phase = stage == 2 && !safe ? Transit02Phase.blocked : Transit02Phase.ready;
    notifyListeners();
  }

  Transit02Drop? release(int id, Offset at) {
    if (pointer != id) return null;
    final candidate = at - pointerOffset!;
    final grade =
        !const Rect.fromLTWH(0, 0, 1536, 1024).contains(at) ||
            (candidate - start).distance < 1
        ? Transit02Drop.invalid
        : classify(candidate);
    pointer = null;
    pointerOffset = null;
    result = grade;
    elapsed = 0;
    if (grade == Transit02Drop.invalid) {
      foot = start;
      scale = stageScale;
      invalid = true;
      phase = stage == 2 && !safe
          ? Transit02Phase.blocked
          : Transit02Phase.ready;
    } else if (grade == Transit02Drop.wrong) {
      invalid = false;
      hintOpen = false;
      wrongCount++;
      foot = start;
      scale = stageScale;
      phase = Transit02Phase.judging;
    } else {
      invalid = false;
      hintOpen = false;
      snapFrom = foot;
      snapScaleFrom = scale;
      phase = Transit02Phase.snapping;
    }
    notifyListeners();
    return grade;
  }

  void updateSafety({
    required bool stopped,
    required bool open,
    required bool clear,
  }) {
    trainStopped = stopped;
    doorsOpen = open;
    reboardingSafe = clear;
    if (stage == 2 &&
        !safe &&
        [
          Transit02Phase.ready,
          Transit02Phase.dragging,
          Transit02Phase.snapping,
          if (result == Transit02Drop.correct) Transit02Phase.judging,
        ].contains(phase)) {
      pointer = null;
      pointerOffset = null;
      foot = start;
      scale = stageScale;
      phase = Transit02Phase.blocked;
    } else if (phase == Transit02Phase.blocked && safe) {
      phase = Transit02Phase.ready;
    }
    notifyListeners();
  }

  void advance(double ms) {
    if (!ticking) return;
    elapsed += ms;
    if (phase == Transit02Phase.snapping) {
      final duration =
          (zones['drop_acceptance_v6']['step$stage']['snap_duration_ms'] as num)
              .toDouble();
      final t = Curves.easeOut.transform((elapsed / duration).clamp(0, 1));
      foot = Offset.lerp(snapFrom, target, t)!;
      scale =
          snapScaleFrom +
          ((stageSpec['target_visual_scale'] as num) - snapScaleFrom) * t;
      if (elapsed >= duration) {
        foot = target;
        phase = stage == 1
            ? Transit02Phase.step1Success
            : Transit02Phase.judging;
        elapsed = 0;
      }
    } else if (phase == Transit02Phase.step1Success && elapsed >= 650) {
      phase = Transit02Phase.exiting;
      elapsed = 0;
    } else if (phase == Transit02Phase.exiting &&
        elapsed >= (motion['duration_ms'] as num) &&
        (motion['exiting_passengers'] as Map).values.every(
          (p) => elapsed >= (p['delay_ms'] as num) + (p['duration_ms'] as num),
        )) {
      exitingComplete = true;
      stage = 2;
      phase = safe ? Transit02Phase.ready : Transit02Phase.blocked;
      elapsed = 0;
    } else if (phase == Transit02Phase.judging && elapsed >= 1750) {
      phase = result == Transit02Drop.correct
          ? Transit02Phase.complete
          : wrongCount >= 4
          ? Transit02Phase.failure
          : Transit02Phase.wrong;
      elapsed = 0;
    }
    notifyListeners();
  }

  void retry() {
    if (phase != Transit02Phase.wrong) return;
    foot = start;
    scale = stageScale;
    phase = stage == 2 && !safe ? Transit02Phase.blocked : Transit02Phase.ready;
    notifyListeners();
  }

  void showHint() {
    if (!canDrag && phase != Transit02Phase.wrong) return;
    if (hint < 2) {
      hint++;
      hintOpen = true;
    } else {
      hintOpen = !hintOpen;
    }
    notifyListeners();
  }

  void reveal() {
    if (phase != Transit02Phase.failure) return;
    phase = Transit02Phase.revealed;
    exitingComplete = true;
    stage = 2;
    foot = target;
    scale = (stageSpec['target_visual_scale'] as num).toDouble();
    notifyListeners();
  }
}

class Transit02PassengerPose {
  const Transit02PassengerPose(this.asset, this.foot, this.height);
  final String asset;
  final Offset foot;
  final double height;
  static double smoothValue(List<dynamic> frames, double t, int component) {
    final times = [for (final f in frames) (f['t'] as num).toDouble()];
    final values = [
      for (final f in frames)
        (component == 2 ? f['scale'] as num : f['anchor_px'][component] as num)
            .toDouble(),
    ];
    final slopes = [
      for (var i = 0; i < frames.length - 1; i++)
        (values[i + 1] - values[i]) / (times[i + 1] - times[i]),
    ];
    final tangents = List<double>.filled(frames.length, 0);
    tangents.last = slopes.last;
    for (var i = 1; i < frames.length - 1; i++) {
      final a = slopes[i - 1], b = slopes[i];
      if (a * b > 0) tangents[i] = 2 * a * b / (a + b);
    }
    var i = 0;
    while (i < frames.length - 2 && t > times[i + 1]) {
      i++;
    }
    final h = times[i + 1] - times[i], u = (t - times[i]) / h;
    final u2 = u * u, u3 = u2 * u;
    return ((2 * u3 - 3 * u2 + 1) * values[i] +
            (u3 - 2 * u2 + u) * h * tangents[i] +
            (-2 * u3 + 3 * u2) * values[i + 1] +
            (u3 - u2) * h * tangents[i + 1])
        .clamp(
          math.min(values[i], values[i + 1]),
          math.max(values[i], values[i + 1]),
        );
  }

  static Transit02PassengerPose at(Map<String, dynamic> p, double ms) {
    final local = ms - (p['delay_ms'] as num),
        duration = p['duration_ms'] as num;
    if (local < 0) {
      return Transit02PassengerPose(
        p['waiting_asset'],
        transit02Point(p['start_foot_anchor_px']),
        (p['render_height_px'] as num).toDouble(),
      );
    }
    final t = (local / duration).clamp(0.0, 1.0);
    final frames = p['keyframes'] as List;
    if (p['interpolation'] == 'monotone_cubic') {
      return Transit02PassengerPose(
        (local ~/ 130).isEven ? p['walking_a_asset'] : p['walking_asset'],
        Offset(smoothValue(frames, t, 0), smoothValue(frames, t, 1)),
        (p['render_height_px'] as num) * smoothValue(frames, t, 2),
      );
    }
    var a = frames[0], b = frames[1];
    for (var i = 1; i < frames.length; i++) {
      a = frames[i - 1];
      b = frames[i];
      if (t <= (b['t'] as num)) break;
    }
    final f = (t - (a['t'] as num)) / ((b['t'] as num) - (a['t'] as num));
    final scale =
        (a['scale'] as num) + ((b['scale'] as num) - (a['scale'] as num)) * f;
    return Transit02PassengerPose(
      (local ~/ 130).isEven ? p['walking_a_asset'] : p['walking_asset'],
      Offset.lerp(
        transit02Point(a['anchor_px']),
        transit02Point(b['anchor_px']),
        f,
      )!,
      (p['render_height_px'] as num) * scale,
    );
  }
}

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

enum ActionPhase {
  initial,
  dragging,
  correctJustJudged,
  correctComplete,
  wrongJustJudged,
  wrongComplete,
  finalFailure,
}

/// Disposable interaction state: never awards XP or writes learning records.
class ActionDragState extends ChangeNotifier {
  ActionDragState(this.rules);
  final Map<String, dynamic> rules;
  ActionPhase phase = ActionPhase.initial;
  int wrongAttempts = 0, hint = 0;
  bool revealed = false;
  String? correctZoneId;
  int? pointer;
  Offset? _down;
  Offset delta = Offset.zero;
  bool get _feetAnchor => rules['draggable'] != null;
  Offset get anchor {
    if (!_feetAnchor) return initial.center;
    final p = rules['draggable']['sprite_foot_anchor_px'] as List;
    return Offset((p[0] as num).toDouble(), (p[1] as num).toDouble());
  }

  Rect get initial {
    if (_feetAnchor) {
      final d = rules['draggable'];
      return Rect.fromLTWH(
        (d['initial_top_left'][0] as num).toDouble(),
        (d['initial_top_left'][1] as num).toDouble(),
        (d['size_px'][0] as num).toDouble(),
        (d['size_px'][1] as num).toDouble(),
      );
    }
    final p = rules['backpack_placements']['initial'];
    return Rect.fromLTWH(
      (p['x'] as num).toDouble(),
      (p['y'] as num).toDouble(),
      (p['w'] as num).toDouble(),
      (p['h'] as num).toDouble(),
    );
  }

  bool get canDrag => phase == ActionPhase.initial;
  bool get busy =>
      phase == ActionPhase.correctJustJudged ||
      phase == ActionPhase.wrongJustJudged;
  bool get success =>
      phase == ActionPhase.correctComplete ||
      phase == ActionPhase.correctJustJudged;
  bool contains(String name, Offset point) {
    if (_feetAnchor) {
      final judgement = rules['judgement'];
      final rectangles = name == 'drag_bounds'
          ? [judgement['drag_bounds_px']]
          : [for (final zone in judgement['${name}_zones']) zone['rect_px']];
      return rectangles.any((r) => _inRect(r, point));
    }
    final zone = rules['interaction_overrides']?[name] ?? rules['zones'][name];
    if (zone['type'] == 'polygons') {
      return (zone['polygons'] as List).any(
        (polygon) => _inside(polygon['points'] as List, point),
      );
    }
    return _inside(zone['points'] as List, point);
  }

  String? _correctZoneAt(Offset point) {
    if (!_feetAnchor) return null;
    for (final zone in rules['judgement']['correct_zones']) {
      final r = zone['rect_px'];
      if (_inRect(r, point)) {
        return zone['id'] as String;
      }
    }
    return null;
  }

  // Contain transforms can put an exact edge a few floating-point ulps away.
  // This is sub-pixel numerical tolerance, not a larger gameplay hitbox.
  bool _inRect(List r, Offset p) {
    const epsilon = 1e-7;
    return p.dx >= (r[0] as num) - epsilon &&
        p.dx <= (r[2] as num) + epsilon &&
        p.dy >= (r[1] as num) - epsilon &&
        p.dy <= (r[3] as num) + epsilon;
  }

  bool _inside(List points, Offset point) {
    final path = Path()
      ..addPolygon([
        for (final p in points)
          Offset((p[0] as num).toDouble(), (p[1] as num).toDouble()),
      ], true);
    return path.contains(point);
  }

  bool begin(int id, Offset position, bool hit) {
    if (!canDrag || !hit || pointer != null) return false;
    pointer = id;
    _down = position;
    delta = Offset.zero;
    phase = ActionPhase.dragging;
    notifyListeners();
    return true;
  }

  void move(int id, Offset position) {
    if (pointer != id) return;
    delta = position - _down!;
    notifyListeners();
  }

  void cancel(int id) {
    if (pointer != id) return;
    pointer = null;
    delta = Offset.zero;
    phase = ActionPhase.initial;
    notifyListeners();
  }

  void release(int id, Offset position) {
    if (pointer != id) return;
    delta = position - _down!;
    final center = anchor + delta;
    final outside = _feetAnchor
        ? !contains('drag_bounds', position)
        : !(const Rect.fromLTWH(0, 0, 1536, 1024)).contains(position);
    if (outside ||
        (_feetAnchor &&
            delta.distance <
                (rules['draggable']['movement_threshold_px'] as num)) ||
        !contains('drag_bounds', center)) {
      cancel(id);
      return;
    }
    if (contains('correct', center)) {
      correctZoneId = _correctZoneAt(center);
      phase = ActionPhase.correctJustJudged;
    } else if (contains('wrong', center)) {
      wrongAttempts++;
      phase = ActionPhase.wrongJustJudged;
    } else {
      cancel(id);
      return;
    }
    pointer = null;
    notifyListeners();
  }

  void settle() {
    if (phase == ActionPhase.correctJustJudged) {
      phase = ActionPhase.correctComplete;
    }
    if (phase == ActionPhase.wrongJustJudged) {
      phase = wrongAttempts >= 4
          ? ActionPhase.finalFailure
          : ActionPhase.wrongComplete;
    }
    notifyListeners();
  }

  void retry() {
    if (phase != ActionPhase.wrongComplete) return;
    delta = Offset.zero;
    phase = ActionPhase.initial;
    notifyListeners();
  }

  void showHint() {
    if (hint >= 2 ||
        busy ||
        success ||
        phase == ActionPhase.finalFailure ||
        pointer != null) {
      return;
    }
    hint++;
    notifyListeners();
  }

  void reveal() {
    if (phase != ActionPhase.finalFailure) return;
    revealed = true;
    notifyListeners();
  }

  /// Starts a fresh local attempt. This state owns no persisted completion/XP.
  void resetAttempt() {
    correctZoneId = null;
    phase = ActionPhase.initial;
    wrongAttempts = 0;
    hint = 0;
    revealed = false;
    pointer = null;
    _down = null;
    delta = Offset.zero;
    notifyListeners();
  }
}

/// Dilation follows the visible mask instead of making the entire character a target.
class DragStartMask {
  DragStartMask({
    required this.rgba,
    required this.width,
    required this.height,
    required this.bounds,
    this.channel = 0,
    this.threshold = 128,
  });
  final Uint8List rgba;
  final int width, height;
  final Rect bounds;

  /// 01 uses a white mask; 02 uses alpha, including black opaque pixels.
  final int channel, threshold;
  bool hit(Offset point, double tolerance) {
    if (!(Offset.zero & Size(width.toDouble(), height.toDouble())).contains(
          point,
        ) ||
        !bounds.inflate(tolerance).contains(point)) {
      return false;
    }
    final x = point.dx.floor(), y = point.dy.floor(), radius = tolerance.ceil();
    for (var dy = -radius; dy <= radius; dy++) {
      for (var dx = -radius; dx <= radius; dx++) {
        if (dx * dx + dy * dy > tolerance * tolerance) continue;
        final px = x + dx, py = y + dy;
        if (px >= 0 &&
            py >= 0 &&
            px < width &&
            py < height &&
            rgba[(py * width + px) * 4 + channel] >= threshold) {
          return true;
        }
      }
    }
    return false;
  }
}

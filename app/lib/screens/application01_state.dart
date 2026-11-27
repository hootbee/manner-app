import 'package:flutter/painting.dart';
import 'package:flutter/foundation.dart';

enum ApplicationPhase {
  editing,
  dragging,
  judging,
  wrong,
  failure,
  complete,
  revealed,
}

enum LuggageDrop { correct, aisle, neighbor, other, invalid }

/// Clips any simple zone polygon to an axis-aligned footprint/body rectangle.
/// Positive area counts as intrusion; merely touching a boundary does not.
double polygonRectArea(List<Offset> polygon, Rect rect) {
  var result = List<Offset>.of(polygon);
  for (var edge = 0; edge < 4; edge++) {
    if (result.isEmpty) return 0;
    final input = result;
    result = [];
    double distance(Offset p) => switch (edge) {
      0 => p.dx - rect.left,
      1 => rect.right - p.dx,
      2 => p.dy - rect.top,
      _ => rect.bottom - p.dy,
    };
    var a = input.last;
    for (final b in input) {
      final da = distance(a), db = distance(b);
      if ((da >= 0) != (db >= 0)) result.add(a + (b - a) * (da / (da - db)));
      if (db >= 0) result.add(b);
      a = b;
    }
  }
  var sum = 0.0;
  for (var i = 0; i < result.length; i++) {
    final a = result[i], b = result[(i + 1) % result.length];
    sum += a.dx * b.dy - b.dx * a.dy;
  }
  return sum.abs() / 2;
}

class ApplicationGeometry {
  ApplicationGeometry(this.json);
  final Map<String, dynamic> json;
  Offset center(String name) {
    final a = json['examples'][name]['center'];
    return Offset((a[0] as num).toDouble(), (a[1] as num).toDouble());
  }

  List<Offset> zone(String name) => [
    for (final p in json['zones'][name])
      Offset((p[0] as num).toDouble(), (p[1] as num).toDouble()),
  ];
  Rect relativeRect(String key, Offset center) {
    final p = json['sprite'][key] as List;
    final vertices = [
      for (final v in p)
        Offset((v[0] as num).toDouble(), (v[1] as num).toDouble()),
    ];
    var r = Rect.fromPoints(vertices.first, vertices.first);
    for (final v in vertices.skip(1)) {
      r = r.expandToInclude(Rect.fromPoints(v, v));
    }
    return r.shift(center);
  }

  LuggageDrop classify(Offset at) {
    final bounds =
        json['sprite']['render_in_canvas']['pixel_alpha_bounds_local_xyxy']
            as List;
    final visual = Rect.fromLTRB(
      (bounds[0] as num).toDouble(),
      (bounds[1] as num).toDouble(),
      (bounds[2] as num).toDouble(),
      (bounds[3] as num).toDouble(),
    ).shift(at - const Offset(137, 205));
    if (visual.left < 0 ||
        visual.top < 0 ||
        visual.right > 1536 ||
        visual.bottom > 1024) {
      return LuggageDrop.invalid;
    }
    final feet = relativeRect('ground_contact_relative_to_center_polygon', at);
    final area = feet.width * feet.height;
    if (polygonRectArea(zone('supported_floor_polygon'), feet) < area - 1e-5) {
      return LuggageDrop.invalid;
    }
    final body = relativeRect('visual_body_relative_to_center_polygon', at);
    if (polygonRectArea(zone('public_aisle_polygon'), body) > 1e-5 ||
        polygonRectArea(zone('public_aisle_polygon'), feet) > 1e-5) {
      return LuggageDrop.aisle;
    }
    if (polygonRectArea(zone('neighbor_footspace_polygon'), body) > 1e-5 ||
        polygonRectArea(zone('neighbor_footspace_polygon'), feet) > 1e-5) {
      return LuggageDrop.neighbor;
    }
    if (polygonRectArea(zone('safe_own_ground_polygon'), feet) < area - 1e-5) {
      return LuggageDrop.other;
    }
    return LuggageDrop.correct;
  }
}

class Application01State extends ChangeNotifier {
  Application01State(this.geometry) : center = geometry.center('initial');
  final ApplicationGeometry geometry;
  ApplicationPhase phase = ApplicationPhase.editing;
  Offset center, delta = Offset.zero;
  Offset? down;
  int? pointer;
  int attempts = 0, hint = 0;
  bool hintOpen = false;
  LuggageDrop result = LuggageDrop.invalid;
  bool get success =>
      result == LuggageDrop.correct && phase != ApplicationPhase.revealed;
  bool get showingCorrect => success || phase == ApplicationPhase.revealed;
  bool get canDrag => phase == ApplicationPhase.editing;
  Offset get renderCenter => showingCorrect
      ? geometry.center('correct')
      : phase == ApplicationPhase.judging ||
            phase == ApplicationPhase.wrong ||
            phase == ApplicationPhase.failure
      ? geometry.center('wrong')
      : center + delta;
  bool begin(int id, Offset at, bool alphaHit) {
    if (!canDrag || pointer != null || !alphaHit) return false;
    pointer = id;
    down = at;
    delta = Offset.zero;
    phase = ApplicationPhase.dragging;
    notifyListeners();
    return true;
  }

  void move(int id, Offset at) {
    if (pointer != id) return;
    delta = at - down!;
    notifyListeners();
  }

  void cancel(int id) {
    if (pointer != id) return;
    pointer = null;
    down = null;
    delta = Offset.zero;
    center = geometry.center('initial');
    phase = ApplicationPhase.editing;
    notifyListeners();
  }

  bool release(int id, Offset at) {
    if (pointer != id) return false;
    move(id, at);
    final candidate = center + delta;
    final grade = geometry.classify(candidate);
    if (!const Rect.fromLTWH(0, 0, 1536, 1024).contains(at) ||
        delta.distance < 1 ||
        grade == LuggageDrop.invalid) {
      cancel(id);
      return false;
    }
    pointer = null;
    down = null;
    result = grade;
    attempts++;
    phase = ApplicationPhase.judging;
    hintOpen = false;
    notifyListeners();
    return true;
  }

  void settle() {
    if (phase != ApplicationPhase.judging) return;
    phase = success
        ? ApplicationPhase.complete
        : attempts >= 4
        ? ApplicationPhase.failure
        : ApplicationPhase.wrong;
    notifyListeners();
  }

  void retry() {
    if (phase != ApplicationPhase.wrong) return;
    center = geometry.center('initial');
    delta = Offset.zero;
    result = LuggageDrop.invalid;
    phase = ApplicationPhase.editing;
    notifyListeners();
  }

  void hintTap() {
    if (!canDrag && phase != ApplicationPhase.wrong) return;
    if (hint < 2) {
      hint++;
      hintOpen = true;
    } else {
      hintOpen = !hintOpen;
    }
    notifyListeners();
  }

  void reveal() {
    if (phase != ApplicationPhase.failure) return;
    phase = ApplicationPhase.revealed;
    result = LuggageDrop.invalid;
    notifyListeners();
  }
}

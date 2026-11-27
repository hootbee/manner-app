import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

/// Disposable lesson state. Only a valid pointer release judges; no record/XP writes.
class ReclineLessonState extends ChangeNotifier {
  static const pivot = Offset(711, 836);
  String phase = 'editing', result = '';
  bool consent = false, hintOpen = false;
  int attempts = 0, hint = 0;
  int? pointer;
  Offset? down;
  double progress = 0;
  bool get editable => phase == 'editing';
  bool get busy => phase == 'judging';
  bool get success => result == 'correct' && phase != 'revealed';
  bool get revealed => phase == 'revealed';
  String get character => success || revealed
      ? 'positive'
      : result.isNotEmpty && !hintOpen
      ? 'initial'
      : consent || phase == 'asking' || phase == 'revealing' || hintOpen
      ? 'asking'
      : 'initial';
  String get passenger => success || revealed
      ? 'comfortable'
      : result == 'wrong_no_consent'
      ? 'surprised'
      : result == 'wrong_excessive'
      ? 'uncomfortable'
      : consent
      ? 'agree'
      : 'working';
  void ask() {
    if (!editable || pointer != null || consent) return;
    phase = 'asking';
    notifyListeners();
  }

  void reply() {
    if (phase != 'asking') return;
    consent = true;
    phase = 'editing';
    notifyListeners();
  }

  bool begin(int id, Offset at, bool visible) {
    if (!editable || pointer != null || !visible) return false;
    pointer = id;
    down = at;
    notifyListeners();
    return true;
  }

  void move(int id, Offset at) {
    if (pointer != id || !editable) return;
    final a = down! - pivot, b = at - pivot;
    progress =
        (math.atan2(a.dx * b.dy - a.dy * b.dx, a.dx * b.dx + a.dy * b.dy) /
                (20 * math.pi / 180))
            .clamp(0, 1);
    notifyListeners();
  }

  bool release(int id) {
    if (pointer != id) return false;
    pointer = null;
    down = null;
    if (progress < .10 - 1e-9) {
      progress = 0;
      notifyListeners();
      return false;
    }
    attempts++;
    result = !consent
        ? 'wrong_no_consent'
        : progress <= .45 + 1e-9
        ? 'correct'
        : 'wrong_excessive';
    phase = 'judging';
    hintOpen = false;
    notifyListeners();
    return true;
  }

  void cancel(int id) {
    if (pointer != id) return;
    pointer = null;
    down = null;
    progress = 0;
    notifyListeners();
  }

  void settle() {
    if (!busy) return;
    phase = success
        ? 'complete'
        : attempts >= 4
        ? 'failure'
        : 'wrong';
    notifyListeners();
  }

  void retry() {
    if (phase != 'wrong') return;
    phase = 'editing';
    progress = 0;
    result = '';
    notifyListeners();
  }

  void hintTap() {
    if ((!editable && phase != 'wrong') || pointer != null) return;
    if (hint >= 2) {
      hintOpen = false;
    } else {
      hint++;
      hintOpen = true;
    }
    notifyListeners();
  }

  void reveal() {
    if (phase != 'failure') return;
    phase = 'revealing';
    consent = false;
    progress = 0;
    result = '';
    hintOpen = false;
    notifyListeners();
  }

  void demoConsent() {
    if (phase != 'revealing') return;
    consent = true;
    notifyListeners();
  }

  void demo(double value) {
    if (phase != 'revealing') return;
    progress = .32 * value;
    if (value >= 1) phase = 'revealed';
    notifyListeners();
  }

  void reset() {
    phase = 'editing';
    result = '';
    consent = false;
    hintOpen = false;
    attempts = 0;
    hint = 0;
    pointer = null;
    down = null;
    progress = 0;
    notifyListeners();
  }
}

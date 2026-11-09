import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'lesson_storage.dart';
import 'transport_questions.dart';

class QuestionSession {
  QuestionSession({
    this.attempts = 0,
    this.phase = 'question',
    this.selected,
    this.lastCorrect,
    this.hasFailed = false,
    this.order = const [],
    this.placements = const {},
    this.firstCompletedAt,
  });
  int attempts;
  String phase;
  String? selected;
  bool? lastCorrect;
  bool hasFailed;
  List<int> order;
  Map<String, String> placements;
  DateTime? firstCompletedAt;
  bool get solved => phase != 'question';
  int get hintLevel => attempts.clamp(0, 3);
  Map<String, dynamic> toJson() => {
    'attemptCount': attempts,
    'phase': phase,
    'selected': selected,
    'lastCorrect': lastCorrect,
    'hasFailed': hasFailed,
    'order': order,
    'placements': placements,
    'firstCompletedAt': firstCompletedAt?.toIso8601String(),
  };
  factory QuestionSession.fromJson(Map<String, dynamic> j) => QuestionSession(
    attempts: j['attemptCount'] as int? ?? 0,
    phase:
        j['phase'] != 'complete' &&
            j['lastCorrect'] == false &&
            (j['attemptCount'] as int? ?? 0) >= 3
        ? 'review'
        : j['phase'] as String? ?? 'question',
    selected: j['selected'] as String?,
    lastCorrect: j['lastCorrect'] as bool?,
    hasFailed:
        j['hasFailed'] as bool? ??
        ((j['attemptCount'] as int? ?? 0) >= 3 && j['lastCorrect'] == false),
    order: List<int>.from(j['order'] as List? ?? []),
    placements: Map<String, String>.from(j['placements'] as Map? ?? {}),
    firstCompletedAt: DateTime.tryParse(j['firstCompletedAt'] as String? ?? ''),
  );
}

class TransportProgress extends ChangeNotifier {
  TransportProgress({this.persist = true});
  static final instance = TransportProgress();
  final bool persist;
  final Map<String, QuestionSession> sessions = {};
  String? storageError;
  Future<void> _pending = Future.value();
  Future<void> load() async {
    if (!persist) return;
    try {
      final raw = await readLessons();
      if (raw != null) {
        final j = jsonDecode(raw) as Map<String, dynamic>;
        for (final e in j.entries) {
          sessions[e.key] = QuestionSession.fromJson(
            Map<String, dynamic>.from(e.value as Map),
          );
        }
      }
    } catch (_) {
      storageError = '저장된 학습 기록을 불러오지 못했어요.';
    }
  }

  QuestionSession session(String id) =>
      sessions.putIfAbsent(id, () => QuestionSession());
  int get completed =>
      sessions.values.where((s) => s.firstCompletedAt != null).length;
  int get xp => 320 + completed * 10;
  List<MapEntry<String, QuestionSession>> get todayRecords =>
      sessions.entries.where((e) {
        final t = e.value.firstCompletedAt;
        final n = DateTime.now();
        return t != null &&
            t.year == n.year &&
            t.month == n.month &&
            t.day == n.day;
      }).toList()..sort(
        (a, b) =>
            a.value.firstCompletedAt!.compareTo(b.value.firstCompletedAt!),
      );
  void changed() {
    notifyListeners();
    if (!persist) return;
    final raw = jsonEncode(sessions.map((k, v) => MapEntry(k, v.toJson())));
    _pending = _pending.then((_) => writeLessons(raw)).catchError((Object e) {
      storageError = '학습 기록 저장에 실패했어요. 이 창을 닫기 전에 다시 시도해 주세요.';
      notifyListeners();
    });
  }

  Future<void> flush() => _pending;
  void restart(String id) {
    final previous = session(id);
    sessions[id] = QuestionSession(
      firstCompletedAt: previous.firstCompletedAt,
      hasFailed: previous.hasFailed,
    );
    changed();
  }

  bool submit(TransportQuestion q, bool correct, {String? selected}) {
    final s = session(q.id);
    if (s.solved) return false;
    s.attempts++;
    s.lastCorrect = correct;
    s.selected = selected;
    if (correct) {
      s.phase = 'explanation';
    } else if (s.attempts >= 3) {
      s.phase = 'review';
      s.hasFailed = true;
    }
    changed();
    return correct;
  }

  int complete(String id) {
    final s = session(id);
    if (s.phase != 'explanation' || s.lastCorrect != true) return 0;
    final reward = s.firstCompletedAt == null ? 10 : 0;
    s.firstCompletedAt ??= DateTime.now();
    s.phase = 'complete';
    changed();
    return reward;
  }
}

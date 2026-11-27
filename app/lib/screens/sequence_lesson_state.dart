import 'dart:math';
import 'package:flutter/foundation.dart';

class SequenceCard {
  const SequenceCard(
    this.id,
    this.label,
    this.thumbnail, {
    this.thumbnailAspectRatio = 1,
  });
  final String id, label, thumbnail;

  /// Layout metadata only. Replace path + ratio when approved square art arrives.
  final double thumbnailAspectRatio;
}

class SequenceQuestion {
  SequenceQuestion.fromJson(Map<String, dynamic> j)
    : id = j['problemId'],
      title = j['title'],
      scenario = j['scenario'],
      instruction = j['instruction'],
      cards = List.unmodifiable(
        (j['cards'] as List).map(
          (c) => SequenceCard(
            c['id'],
            c['label'],
            c['thumbnail'],
            thumbnailAspectRatio:
                (c['thumbnailAspectRatio'] as num?)?.toDouble() ?? 1,
          ),
        ),
      ),
      gradingApproved = j['gradingApproved'] as bool? ?? true,
      correctOrder = List.unmodifiable(
        List<String>.from(j['correctOrder'] ?? []),
      ),
      acceptedOrders = List.unmodifiable(
        (j['acceptedOrders'] as List? ?? [j['correctOrder'] ?? []]).map(
          (order) => List<String>.unmodifiable(List<String>.from(order)),
        ),
      ),
      initialOrder = j['initialOrder'] == null
          ? null
          : List.unmodifiable(List<String>.from(j['initialOrder'])),
      hints = List.unmodifiable(List<String>.from(j['hints'])),
      correctFeedback = j['feedback']['correct'],
      wrongFeedback = j['feedback']['wrong'],
      maxSubmissions = j['maxValidSubmissions'] {
    final ids = cards.map((c) => c.id).toSet();
    if (cards.length < 2 ||
        ids.length != cards.length ||
        (gradingApproved &&
            (correctOrder.length != cards.length ||
                correctOrder.toSet().length != cards.length ||
                !ids.containsAll(correctOrder))) ||
        (gradingApproved &&
            (acceptedOrders.isEmpty ||
                acceptedOrders.any(
                  (order) =>
                      order.length != cards.length ||
                      order.toSet().length != cards.length ||
                      !ids.containsAll(order),
                ) ||
                !acceptedOrders.any(
                  (order) => listEquals(order, correctOrder),
                ))) ||
        (!gradingApproved && correctOrder.isNotEmpty) ||
        (initialOrder != null &&
            (initialOrder!.length != cards.length ||
                initialOrder!.toSet().length != cards.length ||
                !ids.containsAll(initialOrder!)))) {
      throw const FormatException(
        'Sequence cards and correctOrder must be one matching permutation.',
      );
    }
  }
  final String id, title, scenario, instruction, correctFeedback, wrongFeedback;
  final List<SequenceCard> cards;
  final List<String> correctOrder, hints;
  final List<List<String>> acceptedOrders;
  final bool gradingApproved;
  final List<String>? initialOrder;
  final int maxSubmissions;
  SequenceCard card(String id) => cards.firstWhere((c) => c.id == id);
}

enum SequencePhase {
  editing,
  correctJustJudged,
  correctComplete,
  wrongJustJudged,
  wrongComplete,
  finalFailure,
  solutionRevealed,
}

/// Disposable sequence practice only; no storage, XP or completion side effects.
class SequenceLessonState extends ChangeNotifier {
  SequenceLessonState(this.question, {Random? random})
    : _random = random ?? Random() {
    _shuffle();
  }
  final SequenceQuestion question;
  final Random _random;
  late List<String> _order;
  List<String> get order => List.unmodifiable(_order);
  SequencePhase phase = SequencePhase.editing;
  int validSubmissions = 0, hintStep = 0;
  bool hasReordered = false, dragging = false;
  bool get busy =>
      phase == SequencePhase.correctJustJudged ||
      phase == SequencePhase.wrongJustJudged;
  bool get success =>
      phase == SequencePhase.correctJustJudged ||
      phase == SequencePhase.correctComplete;
  bool get solutionRevealed => phase == SequencePhase.solutionRevealed;
  bool get canEdit => phase == SequencePhase.editing;
  bool get canSubmit =>
      canEdit &&
      hasReordered &&
      !dragging &&
      validSubmissions < question.maxSubmissions;
  bool get canHint =>
      !dragging &&
      hintStep < question.hints.length &&
      (canEdit || phase == SequencePhase.wrongComplete);
  void _shuffle() {
    if (question.initialOrder != null) {
      _order = List.of(question.initialOrder!);
      return;
    }
    _order = question.cards.map((c) => c.id).toList()..shuffle(_random);
    if (listEquals(_order, question.correctOrder)) {
      _order.add(_order.removeAt(0));
    }
  }

  void startDrag() {
    if (!canEdit) return;
    dragging = true;
    notifyListeners();
  }

  void endDrag() {
    if (!dragging) return;
    dragging = false;
    notifyListeners();
  }

  /// Flutter onReorder uses the pre-removal insertion index.
  void reorder(int oldIndex, int newIndex) {
    if (!canEdit ||
        oldIndex < 0 ||
        oldIndex >= _order.length ||
        newIndex < 0 ||
        newIndex > _order.length) {
      return;
    }
    if (newIndex > oldIndex) newIndex--;
    if (newIndex == oldIndex) return;
    _order.insert(newIndex, _order.removeAt(oldIndex));
    hasReordered = true;
    notifyListeners();
  }

  bool submit() {
    if (!question.gradingApproved || !canSubmit) return false;
    validSubmissions++;
    phase = question.acceptedOrders.any((order) => listEquals(_order, order))
        ? SequencePhase.correctJustJudged
        : SequencePhase.wrongJustJudged;
    notifyListeners();
    return true;
  }

  void settle() {
    if (!busy) return;
    phase = success
        ? SequencePhase.correctComplete
        : validSubmissions >= question.maxSubmissions
        ? SequencePhase.finalFailure
        : SequencePhase.wrongComplete;
    notifyListeners();
  }

  void retry() {
    if (phase != SequencePhase.wrongComplete) return;
    phase = SequencePhase.editing;
    notifyListeners();
  }

  void showHint() {
    if (!canHint) return;
    hintStep++;
    notifyListeners();
  }

  void reveal() {
    if (!question.gradingApproved || phase != SequencePhase.finalFailure) {
      return;
    }
    _order = List.of(question.correctOrder);
    phase = SequencePhase.solutionRevealed;
    notifyListeners();
  }

  void resetAttempt() {
    _shuffle();
    phase = SequencePhase.editing;
    validSubmissions = 0;
    hintStep = 0;
    hasReordered = false;
    dragging = false;
    notifyListeners();
  }
}

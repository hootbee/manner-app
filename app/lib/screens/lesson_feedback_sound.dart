/// Callbacks complete when playback finishes. Legacy and popup sounds share
/// one queue, including audio still playing after dismissal and rapid retry.
enum LessonFeedbackSound { correct, wrong }

typedef LessonSoundPlayer = Future<void> Function(LessonFeedbackSound sound);
Future<void>? _soundTail;
Future<void> playLessonFeedbackSound(
  LessonSoundPlayer? player,
  LessonFeedbackSound sound, {
  required bool muted,
}) {
  if (player == null || muted) return Future<void>.value();
  final next = (_soundTail ?? Future<void>.value()).then((_) async {
    try {
      await player(sound);
    } catch (_) {
      // Audio failure/autoplay restrictions must not interrupt learning.
    }
  });
  _soundTail = next;
  next.then((_) {
    if (identical(_soundTail, next)) _soundTail = null;
  });
  return next;
}

/// Completion adds no sound and waits until every queued result effect has ended.
Future<void> waitLessonAudioIdle() async {
  while (_soundTail != null) {
    await _soundTail;
  }
}

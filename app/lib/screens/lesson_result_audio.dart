import 'dart:async';
import 'package:audioplayers/audioplayers.dart';
import 'lesson_feedback_sound.dart';

/// One-shot playback supplied at app startup. Dismissal does not stop audio.
Future<void> playBundledResultSound(
  LessonFeedbackSound sound, {
  AudioPlayer Function()? createPlayer,
}) async {
  final player = (createPlayer ?? AudioPlayer.new)();
  final completion = Completer<void>();
  final subscription = player.onPlayerComplete.listen(
    (_) {
      if (!completion.isCompleted) completion.complete();
    },
    onError: (Object error, StackTrace stack) {
      if (!completion.isCompleted) completion.complete();
    },
  );
  try {
    await player.setReleaseMode(ReleaseMode.release);
    await player.play(
      AssetSource('result_popup/audio/popup_${sound.name}.mp3'),
    );
    // Failure recovery only; normal completion comes from the native/web player.
    await completion.future.timeout(const Duration(seconds: 8));
  } finally {
    await subscription.cancel();
    await player.dispose();
  }
}

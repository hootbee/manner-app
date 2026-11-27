import 'dart:async';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mannerfit/screens/lesson_result_audio.dart';
import 'package:mannerfit/screens/lesson_feedback_sound.dart';

class FakeResultPlayer implements AudioPlayer {
  final events = StreamController<void>();
  final started = Completer<void>();
  Source? playedSource;
  ReleaseMode? configuredRelease;
  bool disposed = false, fail = false;
  @override
  Stream<void> get onPlayerComplete => events.stream;
  @override
  Future<void> setReleaseMode(ReleaseMode value) async {
    configuredRelease = value;
  }

  @override
  Future<void> play(
    Source value, {
    double? volume,
    double? balance,
    AudioContext? ctx,
    Duration? position,
    PlayerMode? mode,
  }) async {
    playedSource = value;
    started.complete();
    if (fail) throw StateError('playback unavailable');
  }

  @override
  Future<void> dispose() async {
    disposed = true;
    await events.close();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('$invocation');
}

void main() {
  for (final sound in LessonFeedbackSound.values) {
    test(
      '$sound uses supplied asset, waits for completion and releases resources',
      () async {
        final player = FakeResultPlayer();
        var finished = false;
        final playback =
            playBundledResultSound(sound, createPlayer: () => player).then((_) {
              finished = true;
            });
        await player.started.future;
        await Future<void>.delayed(Duration.zero);
        expect(
          (player.playedSource! as AssetSource).path,
          'result_popup/audio/popup_${sound.name}.mp3',
        );
        expect(player.configuredRelease, ReleaseMode.release);
        expect(finished, isFalse);
        expect(player.disposed, isFalse);
        player.events.add(null);
        await playback;
        expect(finished, isTrue);
        expect(player.disposed, isTrue);
      },
    );
  }
  test('playback error cleans up so the queue can recover', () async {
    final player = FakeResultPlayer()..fail = true;
    await expectLater(
      playBundledResultSound(
        LessonFeedbackSound.wrong,
        createPlayer: () => player,
      ),
      throwsStateError,
    );
    expect(player.disposed, isTrue);
  });
}

import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mannerfit/screens/stat_image_export.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('gal');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  tearDown(() => messenger.setMockMethodCallHandler(channel, null));

  for (final fails in [false, true]) {
    test('share channel maps cancellation/exception: fails=$fails', () async {
      const shareChannel = MethodChannel('dev.fluttercommunity.plus/share');
      const paths = MethodChannel('plugins.flutter.io/path_provider');
      final temp = await Directory.systemTemp.createTemp('manners-share-test-');
      addTearDown(() async {
        messenger.setMockMethodCallHandler(shareChannel, null);
        messenger.setMockMethodCallHandler(paths, null);
        await temp.delete(recursive: true);
      });
      messenger.setMockMethodCallHandler(paths, (_) async => temp.path);
      var calls = 0;
      messenger.setMockMethodCallHandler(shareChannel, (call) async {
        calls++;
        expect(call.method, 'share');
        if (fails) throw PlatformException(code: 'SHARE_FAILED');
        return '';
      });
      expect(
        await shareStatImage(
          Uint8List.fromList([137, 80, 78, 71]),
          const Rect.fromLTWH(0, 0, 100, 100),
        ),
        fails ? StatImageResult.failed : StatImageResult.dismissed,
      );
      expect(calls, 1);
    });
  }
  test('gallery save forwards bytes and maps denied/storage errors', () async {
    final calls = <MethodCall>[];
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      return call.method == 'requestAccess' ? true : null;
    });
    final bytes = Uint8List.fromList([137, 80, 78, 71]);
    expect(await saveStatImage(bytes, Rect.zero), StatImageResult.saved);
    expect(calls.any((c) => c.method == 'putImageBytes'), isTrue);
    for (final (code, result) in [
      ('ACCESS_DENIED', StatImageResult.denied),
      ('NOT_ENOUGH_SPACE', StatImageResult.noSpace),
    ]) {
      messenger.setMockMethodCallHandler(channel, (call) async {
        throw PlatformException(code: code);
      });
      expect(await saveStatImage(bytes, Rect.zero), result);
    }
  });
}

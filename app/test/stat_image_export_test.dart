import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mannerfit/screens/stat_image_export.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('gal');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  tearDown(() => messenger.setMockMethodCallHandler(channel, null));
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

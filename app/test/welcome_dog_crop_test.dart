import 'dart:ui' as ui;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mannerfit/screens/welcome_screen.dart';

void main() {
  testWidgets('reference dog crop excludes the source monkey face and ear', (
    tester,
  ) async {
    late ui.Image reference;
    await tester.runAsync(() async {
      final bytes = await rootBundle.load(
        'assets/welcome/welcome_dog_reference.png',
      );
      final codec = await ui.instantiateImageCodec(bytes.buffer.asUint8List());
      reference = (await codec.getNextFrame()).image;
      codec.dispose();
      final recorder = ui.PictureRecorder();
      paintWelcomeReferenceDog(ui.Canvas(recorder), reference);
      final picture = recorder.endRecording();
      final shot = await picture.toImage(360, 300);
      final pixels = (await shot.toByteData(
        format: ui.ImageByteFormat.rawRgba,
      ))!.buffer.asUint8List();
      var brown = 0, visible = 0;
      // The reference monkey overlaps this part of the dog's right shoulder.
      // Its brown hair/skin must not accompany the separately drawn new monkey.
      for (var y = 115; y < 285; y++) {
        for (var x = 210; x < 290; x++) {
          final i = (y * 360 + x) * 4;
          if (pixels[i + 3] < 200) continue;
          visible++;
          if (pixels[i] > pixels[i + 1] + 12 &&
              pixels[i + 1] > pixels[i + 2] + 8) {
            brown++;
          }
        }
      }
      expect(brown, 0);
      expect(
        visible,
        greaterThan(1000),
        reason: 'The dog shoulder must not be erased',
      );
      shot.dispose();
      picture.dispose();
      reference.dispose();
    });
  });
}

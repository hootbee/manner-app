import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mannerfit/screens/welcome_screen.dart';

void main() {
  const capturePath = String.fromEnvironment('WELCOME_CAPTURE_PATH');
  const previewFontPath = String.fromEnvironment('WELCOME_PREVIEW_FONT');
  testWidgets(
    'actions wait for entrance and dispatch individual UI callbacks',
    (tester) async {
      tester.view.physicalSize = const Size(360, 780);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final calls = <String>[];
      await tester.pumpWidget(
        MaterialApp(
          home: WelcomeScreen(
            onStart: () => calls.add('start'),
            onGoogle: () => calls.add('google'),
            onKakao: () => calls.add('kakao'),
            onLogin: () => calls.add('login'),
          ),
        ),
      );
      await tester.tap(find.text('시작하기'), warnIfMissed: false);
      expect(calls, isEmpty);
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 400));
      });
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 1800));
      for (final label in ['시작하기', '구글로 계속하기', '카톡으로 계속하기']) {
        await tester.tap(find.text(label));
      }
      await tester.tap(find.byType(TextButton));
      expect(calls, ['start', 'google', 'kakao', 'login']);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  for (final size in [
    const Size(360, 780),
    const Size(320, 568),
    const Size(430, 932),
  ]) {
    testWidgets('layout and reduced motion at $size', (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final capture = GlobalKey();
      // Capture uses a locally installed Korean font; it is not bundled in the app.
      if (previewFontPath.isNotEmpty) {
        await tester.runAsync(() async {
          final font = File(previewFontPath);
          if (await font.exists()) {
            final loader = FontLoader('PreviewKorean')
              ..addFont(
                font.readAsBytes().then((bytes) => ByteData.sublistView(bytes)),
              );
            await loader.load();
          }
        });
      }
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(fontFamily: 'PreviewKorean'),
          home: MediaQuery(
            data: MediaQueryData(
              size: size,
              disableAnimations: true,
              padding: const EdgeInsets.only(top: 24, bottom: 24),
            ),
            child: RepaintBoundary(key: capture, child: const WelcomeScreen()),
          ),
        ),
      );
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 400));
      });
      await tester.pump();
      await tester.ensureVisible(find.text('카톡으로 계속하기'));
      await tester.tap(find.text('카톡으로 계속하기'));
      await tester.pump();
      expect(find.text('프로토타입 화면입니다. 기능은 추후 연결됩니다.'), findsOneWidget);
      expect(tester.takeException(), isNull);
      if (capturePath.isNotEmpty && size.width == 360) {
        ScaffoldMessenger.of(
          tester.element(find.byType(WelcomeScreen)),
        ).removeCurrentSnackBar();
        await tester.pump();
        await tester.runAsync(() async {
          final boundary =
              capture.currentContext!.findRenderObject()!
                  as RenderRepaintBoundary;
          final image = await boundary.toImage(pixelRatio: 2);
          final data = await image.toByteData(format: ui.ImageByteFormat.png);
          await File(capturePath).writeAsBytes(data!.buffer.asUint8List());
          image.dispose();
        });
      }
      await tester.pumpWidget(const SizedBox());
    });
  }
}

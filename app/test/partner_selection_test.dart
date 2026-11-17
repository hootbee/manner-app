import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mannerfit/main_prototype.dart';
import 'package:mannerfit/screens/partner_selection_screen.dart';

void main() {
  testWidgets('start opens partner selection and back returns to welcome', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 780);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(const MannersPrototype());
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 400)),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 2));
    await tester.tap(find.text('시작하기'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.byType(PartnerSelectionScreen), findsOneWidget);
    await tester.tap(find.byTooltip('뒤로 가기'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.text('시작하기'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  for (final size in [
    const Size(360, 780),
    const Size(320, 568),
    const Size(430, 932),
  ]) {
    testWidgets('cyclic selection, details and confirmation at $size', (
      tester,
    ) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final selected = <MannerPartner>[];
      final capture = GlobalKey();
      const capturePath = String.fromEnvironment('PARTNER_CAPTURE_PATH');
      const fontPath = String.fromEnvironment('PREVIEW_FONT');
      if (fontPath.isNotEmpty) {
        await tester.runAsync(() async {
          await (FontLoader('PreviewKorean')..addFont(
                File(
                  fontPath,
                ).readAsBytes().then((bytes) => ByteData.sublistView(bytes)),
              ))
              .load();
        });
      }
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(fontFamily: 'PreviewKorean'),
          home: RepaintBoundary(
            key: capture,
            child: PartnerSelectionScreen(onConfirm: selected.add),
          ),
        ),
      );
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 400)),
      );
      await tester.pump();
      if (capturePath.isNotEmpty && size.width == 360) {
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
      for (final expected in [
        MannerPartner.monkey,
        MannerPartner.cat,
        MannerPartner.dog,
      ]) {
        await tester.ensureVisible(find.byTooltip('다음 캐릭터'));
        await tester.tap(find.byTooltip('다음 캐릭터'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 600));
        expect(find.text(expected.description), findsOneWidget);
        expect(find.text(expected.quote), findsOneWidget);
      }
      await tester.tap(find.byTooltip('이전 캐릭터'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
      expect(find.text(MannerPartner.cat.description), findsOneWidget);
      await tester.ensureVisible(find.text('이 캐릭터로 시작하기'));
      await tester.tap(find.text('이 캐릭터로 시작하기'));
      expect(selected, [MannerPartner.cat]);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  }
}

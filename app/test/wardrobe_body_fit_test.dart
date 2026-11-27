import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mannerfit/screens/partner_selection_screen.dart';
import 'package:mannerfit/screens/wardrobe_screen.dart';

void main() {
  testWidgets('school jacket preserves the original body outside its sewn pocket', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(792, 590);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final boundary = GlobalKey();
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: Scaffold(
            body: RepaintBoundary(
              key: boundary,
              child: ColoredBox(
                color: Colors.white,
                child: Column(
                  children: [
                    for (final outfit in ['suit', 'school'])
                      SizedBox(
                        height: 295,
                        child: Row(
                          children: [
                            for (final partner in MannerPartner.values)
                              SizedBox(
                                width: 264,
                                height: 295,
                                child: ClothingCharacter(
                                  partner: partner,
                                  outfit: outfit,
                                ),
                              ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.runAsync(() async {
      await precacheImage(
        const AssetImage('assets/welcome/partner_design_v2.png'),
        tester.element(find.byType(Scaffold)),
      );
    });
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    late Uint8List pixels;
    await tester.runAsync(() async {
      final render =
          boundary.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final shot = await render.toImage();
      final raw = await shot.toByteData(format: ui.ImageByteFormat.rawRgba);
      pixels = raw!.buffer.asUint8List();
      const capture = String.fromEnvironment('WARDROBE_BODY_CAPTURE');
      if (capture.isNotEmpty) {
        final png = await shot.toByteData(format: ui.ImageByteFormat.png);
        await File(capture).writeAsBytes(png!.buffer.asUint8List());
      }
      shot.dispose();
    });
    // Independent bounds: all other pixels, including shoulders, hands, trousers,
    // feet, tails and faces, must remain identical when changing to this jacket.
    const pockets = [
      Rect.fromLTWH(151, 194, 24, 28),
      Rect.fromLTWH(157, 193, 24, 28),
      Rect.fromLTWH(136, 182, 24, 28),
    ];
    for (var partner = 0; partner < 3; partner++) {
      var changedInside = 0, changedOutside = 0;
      for (var y = 0; y < 295; y++) {
        for (var x = 0; x < 264; x++) {
          final before = (y * 792 + partner * 264 + x) * 4;
          final after = ((y + 295) * 792 + partner * 264 + x) * 4;
          var changed = false;
          for (var channel = 0; channel < 4; channel++) {
            if (pixels[before + channel] != pixels[after + channel]) {
              changed = true;
            }
          }
          if (changed) {
            if (pockets[partner].contains(Offset(x.toDouble(), y.toDouble()))) {
              changedInside++;
            } else {
              changedOutside++;
            }
          }
        }
      }
      expect(
        changedOutside,
        0,
        reason:
            '${MannerPartner.values[partner].name}: anatomy moved outside the pocket',
      );
      expect(
        changedInside,
        greaterThan(50),
        reason: 'The school pocket must actually be visible',
      );
    }
  });

  testWidgets(
    'owned pajamas and trench keep original head feet and tail pixels',
    (tester) async {
      tester.view.physicalSize = const Size(792, 1180);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final key = GlobalKey();
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(disableAnimations: true),
            child: Scaffold(
              body: RepaintBoundary(
                key: key,
                child: ColoredBox(
                  color: Colors.white,
                  child: Column(
                    children: [
                      for (final outfit in ['suit', 'school', 'bear', 'trench'])
                        SizedBox(
                          height: 295,
                          child: Row(
                            children: [
                              for (final partner in MannerPartner.values)
                                SizedBox(
                                  width: 264,
                                  height: 295,
                                  child: ClothingCharacter(
                                    partner: partner,
                                    outfit: outfit,
                                  ),
                                ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.runAsync(() async {
        await precacheImage(
          const AssetImage('assets/welcome/partner_design_v2.png'),
          tester.element(find.byType(Scaffold)),
        );
      });
      await tester.pumpAndSettle();
      late Uint8List pixels;
      await tester.runAsync(() async {
        final render =
            key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
        final shot = await render.toImage();
        pixels = (await shot.toByteData(
          format: ui.ImageByteFormat.rawRgba,
        ))!.buffer.asUint8List();
        const capture = String.fromEnvironment('OWNED_OUTFIT_CAPTURE');
        if (capture.isNotEmpty) {
          final png = await shot.toByteData(format: ui.ImageByteFormat.png);
          await File(capture).writeAsBytes(png!.buffer.asUint8List());
        }
        shot.dispose();
      });
      for (final row in [2, 3]) {
        for (var partner = 0; partner < 3; partner++) {
          var changedBody = 0, changedFixedParts = 0;
          final headBottom = partner == 2 ? 165 : 174;
          for (var y = 0; y < 295; y++) {
            for (var x = 0; x < 264; x++) {
              final before = (y * 792 + partner * 264 + x) * 4,
                  after = ((y + 295 * row) * 792 + partner * 264 + x) * 4;
              var changed = false;
              for (var channel = 0; channel < 4; channel++) {
                if (pixels[before + channel] != pixels[after + channel]) {
                  changed = true;
                }
              }
              if (changed) {
                if (y < headBottom || y >= 270 || x >= 211) {
                  changedFixedParts++;
                } else {
                  changedBody++;
                }
              }
            }
          }
          expect(
            changedFixedParts,
            0,
            reason: 'row $row partner $partner: a fixed body part moved',
          );
          expect(
            changedBody,
            greaterThan(500),
            reason: 'The purchased garment must be visible',
          );
        }
      }
      expect(tester.takeException(), isNull);
    },
  );
}

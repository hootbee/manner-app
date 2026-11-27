import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mannerfit/screens/wardrobe_preview.dart';
import 'package:mannerfit/screens/wardrobe_catalog.dart';
import 'package:mannerfit/screens/wardrobe_screen.dart';
import 'package:mannerfit/screens/wardrobe_visuals.dart';
import 'package:mannerfit/screens/wardrobe_room.dart';
import 'package:mannerfit/screens/partner_selection_screen.dart';

void main() {
  testWidgets('all headgear and accessories render on each partner', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 2100);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final boundary = GlobalKey();
    final wearables = WardrobePreview.catalog.where(
      (item) =>
          [0, 2].contains(wardrobeCategory(item.id)) &&
          !item.id.endsWith('-none'),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: Scaffold(
            body: RepaintBoundary(
              key: boundary,
              child: ColoredBox(
                color: Colors.white,
                child: GridView.count(
                  crossAxisCount: 6,
                  childAspectRatio: .85,
                  physics: const NeverScrollableScrollPhysics(),
                  children: [
                    for (final item in wearables)
                      for (final partner in MannerPartner.values)
                        ClothingCharacter(
                          partner: partner,
                          outfit: 'school',
                          equipment: {
                            equipmentKey(
                              partner.name,
                              wardrobeCategory(item.id),
                            ): item.id,
                          },
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
    const capture = String.fromEnvironment('WARDROBE_FITTING_CAPTURE');
    if (capture.isNotEmpty) {
      await tester.runAsync(() async {
        final render =
            boundary.currentContext!.findRenderObject()!
                as RenderRepaintBoundary;
        final image = await render.toImage();
        final png = await image.toByteData(format: ui.ImageByteFormat.png);
        await File(capture).writeAsBytes(png!.buffer.asUint8List());
        image.dispose();
      });
    }
  });
  testWidgets(
    'all product art and dressed partners render without layout errors',
    (tester) async {
      tester.view.physicalSize = const Size(1080, 2300);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final boundary = GlobalKey();
      final outfits = WardrobePreview.catalog
          .where((e) => wardrobeCategory(e.id) == 1)
          .toList();
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(disableAnimations: true),
            child: Scaffold(
              body: RepaintBoundary(
                key: boundary,
                child: Column(
                  children: [
                    SizedBox(
                      height: 1080,
                      child: GridView.count(
                        crossAxisCount: 6,
                        childAspectRatio: .85,
                        physics: const NeverScrollableScrollPhysics(),
                        children: [
                          for (var i = 0; i < outfits.length; i++)
                            for (final partner in MannerPartner.values)
                              ClothingCharacter(
                                partner: partner,
                                outfit: outfits[i].id,
                              ),
                        ],
                      ),
                    ),
                    SizedBox(
                      height: 760,
                      child: GridView.count(
                        crossAxisCount: 10,
                        physics: const NeverScrollableScrollPhysics(),
                        children: [
                          for (final item in WardrobePreview.catalog)
                            item.id.startsWith('bg-')
                                ? WardrobeRoom(background: item.id)
                                : WardrobeItemArt(id: item.id),
                        ],
                      ),
                    ),
                    SizedBox(
                      height: 300,
                      child: Row(
                        children: [
                          for (final partner in MannerPartner.values)
                            Expanded(
                              child: Stack(
                                fit: StackFit.expand,
                                children: [
                                  const WardrobeRoom(
                                    background: 'bg-library',
                                    furniture: 'furniture-plant',
                                    prop: 'prop-mug',
                                  ),
                                  ClothingCharacter(
                                    partner: partner,
                                    outfit: 'hoodie',
                                    equipment: {
                                      equipmentKey(partner.name, 0):
                                          'hat-beanie',
                                      equipmentKey(partner.name, 2):
                                          'acc-watch',
                                    },
                                  ),
                                ],
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
      );
      await tester.runAsync(() async {
        await precacheImage(
          const AssetImage('assets/welcome/partner_design_v2.png'),
          tester.element(find.byType(Scaffold)),
        );
      });
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      const capture = String.fromEnvironment('WARDROBE_CAPTURE');
      if (capture.isNotEmpty) {
        await tester.runAsync(() async {
          final render =
              boundary.currentContext!.findRenderObject()!
                  as RenderRepaintBoundary;
          final shot = await render.toImage();
          final png = await shot.toByteData(format: ui.ImageByteFormat.png);
          await File(capture).writeAsBytes(png!.buffer.asUint8List());
          shot.dispose();
        });
      }
    },
  );
}

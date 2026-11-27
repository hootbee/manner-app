import 'dart:async';
import 'package:flutter/services.dart';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mannerfit/backend.dart';
import 'package:mannerfit/screens/stat_image_export.dart';
import 'package:mannerfit/screens/stat_share_screen.dart';
import 'package:mannerfit/screens/partner_selection_screen.dart';

void main() {
  const home = Home(
    today: null,
    streak: 0,
    reviewsDue: 0,
    xp: 75,
    level: 1,
    levelProgress: .75,
  );
  testWidgets(
    'exports a decodable card PNG; save permission denial and share cancellation handled',
    (tester) async {
      tester.view.physicalSize = const Size(360, 780);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      Uint8List? saved, shared;
      var saveCalls = 0;
      final pendingSave = Completer<StatImageResult>();
      await tester.pumpWidget(
        MaterialApp(
          home: StatShareScreen(
            home: home,
            stats: const [
              AreaStat('연애', 80),
              AreaStat('친구', 60),
              AreaStat('공공장소', 70),
              AreaStat('직장', 90),
              AreaStat('어른·가족', 65),
              AreaStat('메시지', 75),
            ],
            partner: MannerPartner.dog,
            preview: true,
            onSave: (png, origin) async {
              saveCalls++;
              saved = png;
              expect(origin.isEmpty, isFalse);
              return pendingSave.future;
            },
            onShare: (png, origin) async {
              shared = png;
              return StatImageResult.dismissed;
            },
          ),
        ),
      );
      // PNG encoding and asset decoding run outside the test's fake clock.
      await tester.runAsync(
        () => precacheImage(
          const AssetImage('assets/welcome/growth_stages.webp'),
          tester.element(find.byType(StatShareCard)),
        ),
      );
      for (var i = 0; i < 20; i++) {
        await tester.pump(const Duration(milliseconds: 100));
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 50)),
        );
        if (tester
                .widget<FilledButton>(find.byKey(const Key('save-stat-image')))
                .onPressed !=
            null) {
          break;
        }
      }
      expect(
        tester
            .widget<FilledButton>(find.byKey(const Key('save-stat-image')))
            .onPressed,
        isNotNull,
      );
      await tester.ensureVisible(find.byKey(const Key('save-stat-image')));
      await tester.tap(find.byKey(const Key('save-stat-image')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('save-stat-image')));
      await tester.pump();
      expect(saveCalls, 1);
      pendingSave.complete(StatImageResult.denied);
      await tester.pumpAndSettle();

      expect(find.text('사진 저장 권한이 필요해요. 기기 설정에서 권한을 허용해주세요.'), findsOneWidget);
      expect(saved!.take(8), [137, 80, 78, 71, 13, 10, 26, 10]);
      await tester.runAsync(() async {
        final codec = await ui.instantiateImageCodec(saved!);
        final frame = await codec.getNextFrame();
        expect(frame.image.width, 960);
        expect(frame.image.height, greaterThan(1000));
        frame.image.dispose();
        codec.dispose();
      });
      expect(
        find.descendant(
          of: find.byType(StatShareCard),
          matching: find.byType(FilledButton),
        ),
        findsNothing,
      );
      ScaffoldMessenger.of(
        tester.element(find.byType(StatShareScreen)),
      ).clearSnackBars();
      await tester.pump(const Duration(seconds: 1));
      await tester.ensureVisible(find.byKey(const Key('share-stat-image')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('share-stat-image')));
      await tester.pumpAndSettle();
      expect(shared, orderedEquals(saved!));
      expect(find.text('공유 창을 열었어요.'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}

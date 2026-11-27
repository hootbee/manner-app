import 'result_popup_test_helpers.dart';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mannerfit/screens/subway01_screen.dart';
import 'package:mannerfit/screens/lesson_feedback_sound.dart';
import 'package:mannerfit/screens/manners_hint_bubble.dart';
import 'package:mannerfit/screens/partner_selection_screen.dart';
import 'package:mannerfit/screens/lesson_explanation_screen.dart';

void main() {
  for (final width in [320.0, 430.0]) {
    testWidgets(
      'mask, transformed drag, retry and correct explanation at $width',
      (t) async {
        t.view.physicalSize = Size(width, 900);
        t.view.devicePixelRatio = 1;
        addTearDown(t.view.resetPhysicalSize);
        addTearDown(t.view.resetDevicePixelRatio);
        const font = String.fromEnvironment('PREVIEW_FONT');
        if (font.isNotEmpty) {
          await t.runAsync(() async {
            await (FontLoader(
                  'PreviewKorean',
                )..addFont(File(font).readAsBytes().then(ByteData.sublistView)))
                .load();
            const icons = String.fromEnvironment('PREVIEW_ICONS_FONT');
            if (icons.isNotEmpty) {
              await (FontLoader('MaterialIcons')..addFont(
                    File(icons).readAsBytes().then(ByteData.sublistView),
                  ))
                  .load();
            }
          });
        }
        rootBundle.evict('assets/subway01/asset_rules.json');
        rootBundle.evict('assets/subway01/state_asset_mapping.json');
        final capture = GlobalKey();
        final sounds = <LessonFeedbackSound>[];
        await t.pumpWidget(
          RepaintBoundary(
            key: capture,
            child: MaterialApp(
              debugShowCheckedModeBanner: false,
              theme: ThemeData(fontFamily: 'PreviewKorean'),
              home: Subway01Screen(
                partner: MannerPartner.monkey,
                playSound: (sound) async {
                  sounds.add(sound);
                },
              ),
            ),
          ),
        );
        for (
          var i = 0;
          i < 400 && find.byKey(const Key('subway01-scene')).evaluate().isEmpty;
          i++
        ) {
          await t.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 50)),
          );
          await t.pump(const Duration(milliseconds: 10));
        }
        final scene = find.byKey(const Key('subway01-scene'));
        expect(scene, findsOneWidget);
        expect(find.text('제출하기'), findsNothing);
        Future<void> shot(String name) async {
          await t.pump(const Duration(milliseconds: 300));
          const output = String.fromEnvironment('CAPTURE_DIR');
          if (output.isEmpty) return;
          final image = await t.runAsync(
            () =>
                (capture.currentContext!.findRenderObject()
                        as RenderRepaintBoundary)
                    .toImage(),
          );
          final png = await t.runAsync(
            () => image!.toByteData(format: ui.ImageByteFormat.png),
          );
          await t.runAsync(
            () => File(
              '$output/subway01-$width-$name.png',
            ).writeAsBytes(png!.buffer.asUint8List()),
          );
          image!.dispose();
        }

        await shot('initial');
        final initialSceneRect = t.getRect(scene);
        await dismissResultPopup(t);
        await t.ensureVisible(find.text('힌트 보기'));
        await t.pump();
        await tapAfterResult(t, find.text('힌트 보기'));
        await t.pump(const Duration(milliseconds: 250));
        expect(find.text('힌트 1/2'), findsOneWidget);
        expect(find.byType(MannersHintBubble), findsOneWidget);
        final firstBubble = t.getRect(find.byKey(const Key('hint-bubble')));
        final firstProfile = t.getRect(find.byKey(const Key('hint-profile')));
        final buttonSlot = t.getRect(find.byKey(const Key('subway01-actions')));
        final profileProvider = t
            .widget<Image>(find.byKey(const Key('hint-profile')))
            .image;
        final profileAsset = profileProvider is ResizeImage
            ? profileProvider.imageProvider
            : profileProvider;
        expect(
          (profileAsset as AssetImage).assetName,
          endsWith('monkey_thinking.png'),
        );
        await shot('hint1');
        await tapAfterResult(t, find.text('다음 힌트 보기'));
        await t.pump(const Duration(milliseconds: 250));
        expect(find.text('힌트 2/2'), findsOneWidget);
        expect(find.text('다음 힌트 보기'), findsNothing);
        expect(t.getRect(find.byKey(const Key('hint-bubble'))), firstBubble);
        expect(t.getRect(find.byKey(const Key('hint-profile'))), firstProfile);
        expect(
          t.getRect(find.byKey(const Key('subway01-actions'))),
          buttonSlot,
        );
        expect(t.getRect(scene), initialSceneRect);
        expect(sounds, isEmpty);
        await shot('hint2');
        const start = Offset(965, 720);
        Offset global(Offset p) {
          final r = t.getRect(scene);
          return r.topLeft +
              Offset(p.dx / 1536 * r.width, p.dy / 1024 * r.height);
        }

        Future<void> drop(Offset target) async {
          final g = await t.startGesture(global(start));
          await t.pump();
          await g.moveTo(global(start + target - const Offset(901, 697)));
          await t.pump();
          await g.up();
          await t.pump();
          await t.pump(const Duration(milliseconds: 1100));
        }

        // An unrelated target cannot pick up the backpack.
        await t.dragFrom(global(const Offset(200, 700)), const Offset(20, 0));
        await t.pump();
        expect(find.text('다시 시도하기'), findsNothing);
        await drop(const Offset(1000, 150));
        expect(sounds, isEmpty);
        await drop(const Offset(300, 920));
        expect(find.text('가방이 통로를 막아 다른 승객이 지나가기 어려워요.'), findsOneWidget);
        await shot('wrong');
        await dismissResultPopup(t);
        await t.ensureVisible(find.text('다시 시도하기'));
        await t.pump();
        await tapAfterResult(t, find.text('다시 시도하기'));
        await t.pump();
        await dismissResultPopup(t);
        await t.ensureVisible(scene);
        await t.pump();
        await drop(const Offset(774, 727));
        expect(
          find.text('좋아요! 가방을 몸 앞쪽으로 옮기니 주변 승객이 더 편해졌어요.'),
          findsOneWidget,
        );
        await shot('correct');
        expect(sounds, [
          LessonFeedbackSound.wrong,
          LessonFeedbackSound.correct,
        ]);
        await dismissResultPopup(t);
        await t.ensureVisible(find.text('해설 보기'));
        await t.pump();
        await tapAfterResult(t, find.text('해설 보기'));
        await t.pumpAndSettle();
        expect(find.text('핵심 매너'), findsOneWidget);
        await shot('explanation');
        await dismissResultPopup(t);
        await t.scrollUntilVisible(
          find.text('응용 문제로 이동'),
          200,
          scrollable: find.byType(Scrollable).last,
        );
        await t.pump();
        expect(
          t
              .widget<FilledButton>(
                find.widgetWithText(FilledButton, '응용 문제로 이동'),
              )
              .onPressed,
          isNotNull,
        );
        expect(find.byType(LessonExplanationScreen), findsOneWidget);
        expect(find.byKey(const Key('explanation-details')), findsNothing);
        expect(find.text('교육 해설'), findsNothing);
        await dismissResultPopup(t);
        await t.ensureVisible(find.byKey(const Key('explanation-toggle')));
        await t.pumpAndSettle();
        await tapAfterResult(t, find.byKey(const Key('explanation-toggle')));
        await t.pumpAndSettle();
        await shot('explanation-expanded');
        await tapAfterResult(t, find.text('문제 다시 풀기'));
        await t.pumpAndSettle();
        expect(find.text('힌트 보기'), findsOneWidget);
        expect(find.text('힌트 2/2'), findsNothing);
        expect(find.text('좋아요! 가방을 몸 앞쪽으로 옮기니 주변 승객이 더 편해졌어요.'), findsNothing);
        expect(t.takeException(), isNull);
        await t.pumpWidget(const SizedBox());
        await t.pump();
      },
    );
  }
}

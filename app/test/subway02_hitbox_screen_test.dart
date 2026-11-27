import 'result_popup_test_helpers.dart';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mannerfit/screens/action_drag_state.dart';
import 'package:mannerfit/screens/lesson_explanation_content.dart';
import 'package:mannerfit/screens/lesson_explanation_screen.dart';
import 'package:mannerfit/screens/lesson_feedback_sound.dart';
import 'package:mannerfit/screens/partner_selection_screen.dart';
import 'package:mannerfit/screens/subway02_screen.dart';
import 'package:mannerfit/screens/subway02_hitbox_overlay.dart';

void main() {
  for (final width in [320.0, 393.0]) {
    for (final left in [true, false]) {
      testWidgets(
        'actual ${left ? 'left edge' : 'right'} drag, snap and Pretendard at $width',
        (t) async {
          t.view.physicalSize = Size(width, 900);
          t.view.devicePixelRatio = 1;
          addTearDown(t.view.resetPhysicalSize);
          addTearDown(t.view.resetDevicePixelRatio);
          await t.runAsync(() async {
            await (FontLoader('Pretendard')
                  ..addFont(
                    rootBundle.load(
                      'assets/fonts/pretendard/Pretendard-Regular.otf',
                    ),
                  )
                  ..addFont(
                    rootBundle.load(
                      'assets/fonts/pretendard/Pretendard-SemiBold.otf',
                    ),
                  )
                  ..addFont(
                    rootBundle.load(
                      'assets/fonts/pretendard/Pretendard-Bold.otf',
                    ),
                  ))
                .load();
            const icons = String.fromEnvironment('PREVIEW_ICONS_FONT');
            if (icons.isNotEmpty) {
              await (FontLoader('MaterialIcons')..addFont(
                    File(icons).readAsBytes().then(ByteData.sublistView),
                  ))
                  .load();
            }
          });
          rootBundle.evict('assets/subway02/asset_rules.json');
          rootBundle.evict('assets/subway02/state_asset_mapping.json');
          final capture = GlobalKey();
          final sounds = <LessonFeedbackSound>[];
          await t.pumpWidget(
            RepaintBoundary(
              key: capture,
              child: MaterialApp(
                debugShowCheckedModeBanner: false,
                theme: ThemeData(fontFamily: 'Pretendard'),
                home: Subway02Screen(
                  debugHitboxes: left,
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
            i < 400 &&
                find.byKey(const Key('subway02-scene')).evaluate().isEmpty;
            i++
          ) {
            await t.runAsync(
              () => Future<void>.delayed(const Duration(milliseconds: 50)),
            );
            await t.pump(const Duration(milliseconds: 10));
          }
          final scene = find.byKey(const Key('subway02-scene'));
          expect(scene, findsOneWidget);
          final state =
              t
                      .widget<ListenableBuilder>(
                        find.byKey(const Key('subway02-ready')),
                      )
                      .listenable
                  as ActionDragState;
          if (left) {
            final painter =
                t
                        .widget<CustomPaint>(
                          find.byKey(const Key('subway02-hitboxes')),
                        )
                        .painter
                    as Subway02HitboxPainter;
            expect(identical(painter.rules, state.rules), isTrue);
          } else {
            expect(find.byKey(const Key('subway02-hitboxes')), findsNothing);
          }
          Future<void> shot(String name) async {
            const output = String.fromEnvironment('CAPTURE_DIR');
            if (output.isEmpty) return;
            await t.runAsync(
              () => Future<void>.delayed(const Duration(milliseconds: 100)),
            );
            await t.pump();
            final image = await t.runAsync(
              () =>
                  (capture.currentContext!.findRenderObject()
                          as RenderRepaintBoundary)
                      .toImage(),
            );
            final bytes = await t.runAsync(
              () => image!.toByteData(format: ui.ImageByteFormat.png),
            );
            await t.runAsync(
              () => File(
                '$output/hitbox-$width-${left ? 'left' : 'right'}-$name.png',
              ).writeAsBytes(bytes!.buffer.asUint8List()),
            );
            image!.dispose();
          }

          Offset screen(Offset p) {
            final r = t.getRect(scene);
            return r.topLeft + p * (r.width / 1536);
          }

          await shot('initial');
          final foot = Offset(left ? (width == 320 ? 0 : 30) : 1200, 900);
          final g = await t.startGesture(screen(const Offset(830, 720)));
          await g.moveTo(screen(const Offset(830, 720) + foot - state.anchor));
          await t.pump();
          await shot('dragging');
          await g.up();
          await t.pump();
          expect(state.success, isTrue);
          expect(
            state.correctZoneId,
            left ? 'left_safe_standing' : 'right_safe_standing',
          );
          expect((state.anchor + state.delta - foot).distance, lessThan(1e-7));
          expect(sounds, [LessonFeedbackSound.correct]);
          final variant =
              state.rules['correct_snap']['variants'][state.correctZoneId];
          final box = variant['top_left_px'], size = variant['sprite_size_px'];
          void checkInside() {
            final m = t
                .widget<Transform>(
                  find.byKey(const Key('subway02-snap-offset')),
                )
                .transform;
            expect((box[0] as num) + m.storage[12], greaterThanOrEqualTo(0));
            expect(
              (box[0] as num) + (size[0] as num) + m.storage[12],
              lessThanOrEqualTo(1536),
            );
            expect((box[1] as num) + m.storage[13], greaterThanOrEqualTo(0));
            expect(
              (box[1] as num) + (size[1] as num) + m.storage[13],
              lessThanOrEqualTo(1024),
            );
          }

          checkInside();
          await t.pump(const Duration(milliseconds: 100));
          checkInside();
          await t.pump(const Duration(milliseconds: 130));
          checkInside();
          expect(
            t
                .widget<Transform>(
                  find.byKey(const Key('subway02-snap-offset')),
                )
                .transform
                .storage[12],
            0,
          );
          final images = t
              .widgetList<Image>(find.byType(Image))
              .where((w) => w.image is AssetImage)
              .map((w) => (w.image as AssetImage).assetName);
          expect(images, contains('assets/subway02/${variant['asset']}'));
          expect(
            images,
            contains('assets/subway02/${variant['effect_asset']}'),
          );
          await shot('correct');
          await t.pump(const Duration(milliseconds: 700));
          expect(find.byKey(const Key('subway02-result-effect')), findsNothing);
          await dismissResultPopup(t);
          await t.ensureVisible(find.text('해설 보기'));
          await tapAfterResult(t, find.text('해설 보기'));
          await t.pumpAndSettle();
          await shot('explanation');
          await dismissResultPopup(t);
          await t.ensureVisible(find.byKey(const Key('explanation-toggle')));
          await tapAfterResult(t, find.byKey(const Key('explanation-toggle')));
          await t.pumpAndSettle();
          final data = lessonExplanations['subway_02_basic']!;
          expect(find.text(data.reasons.first.body), findsOneWidget);
          expect(find.textContaining('01번 백팩'), findsNothing);
          await dismissResultPopup(t);
          await t.ensureVisible(find.text(data.reasons.first.body));
          await t.pumpAndSettle();
          await shot('explanation-expanded');
          expect(
            t
                .widget<LessonExplanationScreen>(
                  find.byType(LessonExplanationScreen),
                )
                .content
                .problemId,
            'subway_02_basic',
          );
          expect(t.takeException(), isNull);
        },
      );
    }
  }
}

import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mannerfit/screens/transport_lesson_screen.dart';
import 'package:mannerfit/screens/transport_progress.dart';

void main() {
  const output = String.fromEnvironment('CAPTURE_DIR');
  if (output.isEmpty) return;
  for (final index in [0, 2, 4, 7]) {
    testWidgets('preview transport $index', (t) async {
      t.view.physicalSize = const Size(360, 780);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.resetPhysicalSize);
      addTearDown(t.view.resetDevicePixelRatio);
      await t.runAsync(() async {
        await (FontLoader('MaterialIcons')..addFont(
              File(
                'C:/Users/gjo49/flutter/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
              ).readAsBytes().then(ByteData.sublistView),
            ))
            .load();
        await (FontLoader('Korean')..addFont(
              File(
                'C:/Windows/Fonts/malgun.ttf',
              ).readAsBytes().then(ByteData.sublistView),
            ))
            .load();
      });
      final key = GlobalKey();
      final store = TransportProgress(persist: false);
      await t.pumpWidget(
        MaterialApp(
          theme: ThemeData(fontFamily: 'Korean'),
          builder: (c, child) => MediaQuery(
            data: MediaQuery.of(c).copyWith(disableAnimations: true),
            child: child!,
          ),
          home: RepaintBoundary(
            key: key,
            child: TransportLessonScreen(index: index, store: store),
          ),
        ),
      );
      await t.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 300)),
      );
      await t.pumpAndSettle();
      Future<void> shot(String name) async {
        await t.runAsync(() async {
          final img =
              await (key.currentContext!.findRenderObject()!
                      as RenderRepaintBoundary)
                  .toImage(pixelRatio: 2);
          final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
          await File(
            '$output/$name.png',
          ).writeAsBytes(bytes!.buffer.asUint8List());
          img.dispose();
        });
      }

      await shot('transport_${index + 1}');
      if (index == 4) {
        final bag = find.byIcon(Icons.backpack);
        await t.ensureVisible(bag); await t.pumpAndSettle();
        final gesture = await t.startGesture(t.getCenter(bag));
        await t.pump(const Duration(milliseconds:600));
        await gesture.moveBy(const Offset(100,-20)); await t.pump();
        await gesture.up(); await t.pumpAndSettle();
        await t.runAsync(()=>Future<void>.delayed(const Duration(milliseconds:300))); await t.pumpAndSettle();
        await shot('transport_drag_success');
      }
      if(index==0||index==7){
        final scene=find.byKey(const ValueKey('action-scene'));await t.ensureVisible(scene);await t.pumpAndSettle();
        final rect=t.getRect(scene);await t.tapAt(Offset(rect.left+rect.width*.2,rect.top+rect.height*.75));await t.pumpAndSettle();
        await t.runAsync(()=>Future<void>.delayed(const Duration(milliseconds:300)));await t.pumpAndSettle();
        await shot('transport_touch_success_${index+1}');
      }
      if (index == 2) {
        await t.tap(find.text('B'));
        await t.pumpAndSettle();
        await shot('transport_correct');
        await t.ensureVisible(find.text('학습 완료'));
        await t.tap(find.text('학습 완료'));
        await t.pumpAndSettle();
        await shot('transport_complete');
      }
      expect(t.takeException(), isNull);
    });
  }
}

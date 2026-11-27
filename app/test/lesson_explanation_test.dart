import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mannerfit/screens/lesson_explanation_content.dart';
import 'package:mannerfit/screens/lesson_explanation_screen.dart';
import 'package:mannerfit/screens/partner_selection_screen.dart';

Future<void> _fonts(WidgetTester t) async {
  const font = String.fromEnvironment('PREVIEW_FONT');
  const icons = String.fromEnvironment('PREVIEW_ICONS_FONT');
  if (font.isEmpty) return;
  await t.runAsync(() async {
    await (FontLoader(
      'PreviewKorean',
    )..addFont(File(font).readAsBytes().then(ByteData.sublistView))).load();
    if (icons.isNotEmpty) {
      await (FontLoader(
        'MaterialIcons',
      )..addFont(File(icons).readAsBytes().then(ByteData.sublistView))).load();
    }
  });
}

Future<void> _capture(WidgetTester t, GlobalKey key, String name) async {
  const output = String.fromEnvironment('CAPTURE_DIR');
  if (output.isEmpty) return;
  await t.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 100)),
  );
  await t.pumpAndSettle();
  final image = await t.runAsync(
    () => (key.currentContext!.findRenderObject() as RenderRepaintBoundary)
        .toImage(),
  );
  final bytes = await t.runAsync(
    () => image!.toByteData(format: ui.ImageByteFormat.png),
  );
  await t.runAsync(
    () => File('$output/$name.png').writeAsBytes(bytes!.buffer.asUint8List()),
  );
  image!.dispose();
}

void main() {
  final data = lessonExplanations['transport-1']!;
  test(
    'all educational paragraphs match the supplied original, including references',
    () {
      final original = File(
        '../docs/design/education_content_subway_01.md',
      ).readAsStringSync().replaceAll('\r\n', '\n');
      expect(data.reasons.length, 3);
      expect(data.faqs.length, 3);
      expect(data.sources.length, 3);
      final allText = data.allText;
      for (final paragraph in original.split(RegExp(r'\n\s*\n'))) {
        final text = paragraph.trim();
        if (text.isEmpty ||
            text.startsWith('#') ||
            text == '---' ||
            text.startsWith('문제:') ||
            text.startsWith('해설 내부에서')) {
          continue;
        }
        if (text.startsWith('출처:')) {
          final fields = RegExp(
            r'^출처: (.*?), (\d{4}\.\d{2}\.\d{2})\s*\n(https?://\S+)$',
          ).firstMatch(text)!;
          expect(
            data.sources.any(
              (s) =>
                  s.agency == fields[1] &&
                  s.date == fields[2] &&
                  s.url.toString() == fields[3],
            ),
            isTrue,
          );
        } else {
          expect(
            allText,
            contains(text.replaceAll('**', '')),
            reason: 'Missing original paragraph: $text',
          );
        }
      }
      expect(data.practice, '가방은 몸 가까이! 다른 사람이 지나갈 공간도 살펴봐요!');
    },
  );

  testWidgets(
    'starts collapsed, expands in place, exposes every Q&A and exact source URL',
    (t) async {
      t.view.physicalSize = const Size(393, 852);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.resetPhysicalSize);
      addTearDown(t.view.resetDevicePixelRatio);
      await _fonts(t);
      final capture = GlobalKey();
      final opened = <Uri>[];
      await t.pumpWidget(
        RepaintBoundary(
          key: capture,
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: ThemeData(fontFamily: 'PreviewKorean'),
            home: LessonExplanationScreen(
              content: data,
              partner: MannerPartner.dog,
              progressHeader: const Text(
                '대중교통  ·  01/20',
                textAlign: TextAlign.center,
              ),
              openSource: (url) async {
                opened.add(url);
                return true;
              },
            ),
          ),
        ),
      );
      await t.pumpAndSettle();
      expect(find.text('교육 해설'), findsNothing);
      expect(find.text(data.core), findsOneWidget);
      expect(find.text(data.learningPlain), findsOneWidget);
      expect(find.text('학습 핵심'), findsOneWidget);
      expect(find.byKey(const Key('explanation-details')), findsNothing);
      expect(
        t
            .widget<FilledButton>(find.byKey(const Key('explanation-next')))
            .onPressed,
        isNull,
      );
      await _capture(t, capture, 'basic-dog');
      await t.ensureVisible(find.byKey(const Key('explanation-toggle')));
      await t.pumpAndSettle();
      final coreRect = t.getRect(find.byKey(const Key('explanation-core')));
      final learningRect = t.getRect(
        find.byKey(const Key('explanation-learning')),
      );
      await t.tap(find.byKey(const Key('explanation-toggle')));
      await t.pumpAndSettle();
      expect(find.text('상세 해설 접기'), findsOneWidget);
      expect(t.getRect(find.byKey(const Key('explanation-core'))), coreRect);
      expect(
        t.getRect(find.byKey(const Key('explanation-learning'))),
        learningRect,
      );
      expect(find.text('학습 핵심'), findsOneWidget);
      for (final reason in data.reasons) {
        expect(find.text(reason.title), findsOneWidget);
        expect(find.text(reason.body), findsOneWidget);
      }
      for (final faq in data.faqs) {
        expect(find.text(faq.answer), findsOneWidget);
      }
      await _capture(t, capture, 'expanded-viewport');
      final firstQuestion = find.text('Q. ${data.faqs.first.question}');
      await t.ensureVisible(firstQuestion);
      await t.pumpAndSettle();
      await t.tap(firstQuestion);
      await t.pumpAndSettle();
      expect(find.text(data.faqs.first.answer), findsNothing);
      await t.tap(firstQuestion);
      await t.pumpAndSettle();
      expect(find.text(data.faqs.first.answer), findsOneWidget);
      await _capture(t, capture, 'qa');
      for (var i = 0; i < 3; i++) {
        final title = find.text('자료 ${i + 1}. ${data.sources[i].title}');
        await t.ensureVisible(title);
        await t.pumpAndSettle();
        await t.tap(title);
        await t.pump();
      }
      expect(opened, data.sources.map((s) => s.url).toList());
      expect(find.text(data.disclaimer), findsOneWidget);
      await _capture(t, capture, 'sources');
      await t.ensureVisible(find.byKey(const Key('explanation-toggle')));
      await t.pumpAndSettle();
      await t.tap(find.byKey(const Key('explanation-toggle')));
      await t.pumpAndSettle();
      expect(find.byKey(const Key('explanation-details')), findsNothing);
      expect(find.text(data.core), findsOneWidget);
      expect(t.takeException(), isNull);
    },
  );

  testWidgets(
    'profiles change without changing practice text or card geometry',
    (t) async {
      t.view.physicalSize = const Size(393, 852);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.resetPhysicalSize);
      addTearDown(t.view.resetDevicePixelRatio);
      await _fonts(t);
      Rect? first;
      for (final partner in MannerPartner.values) {
        final capture = GlobalKey();
        await t.pumpWidget(
          RepaintBoundary(
            key: capture,
            child: MaterialApp(
              debugShowCheckedModeBanner: false,
              theme: ThemeData(fontFamily: 'PreviewKorean'),
              home: LessonExplanationScreen(
                key: ValueKey(partner),
                content: data,
                partner: partner,
                progressHeader: const Text('대중교통  ·  01/20'),
              ),
            ),
          ),
        );
        await t.pumpAndSettle();
        expect(find.text(data.practice), findsOneWidget);
        expect(
          t.getSize(find.byKey(const Key('explanation-profile'))),
          const Size(48, 48),
        );
        final provider =
            t.widget<Image>(find.byKey(const Key('explanation-profile'))).image
                as ResizeImage;
        expect(
          (provider.imageProvider as AssetImage).assetName,
          endsWith(
            '${switch (partner) {
              MannerPartner.dog => 'dog',
              MannerPartner.cat => 'cat',
              MannerPartner.monkey => 'monkey',
            }}_thinking.png',
          ),
        );
        final rect = t.getRect(find.byKey(const Key('explanation-learning')));
        first ??= rect;
        expect(rect, first);
        await _capture(t, capture, 'basic-${partner.index}');
        expect(t.takeException(), isNull);
      }
    },
  );

  testWidgets(
    'small screen and enlarged text keep all content above the fixed footer',
    (t) async {
      t.view.physicalSize = const Size(320, 568);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.resetPhysicalSize);
      addTearDown(t.view.resetDevicePixelRatio);
      await t.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(2)),
            child: LessonExplanationScreen(
              content: data,
              partner: MannerPartner.cat,
              progressHeader: const SizedBox(height: 50),
            ),
          ),
        ),
      );
      await t.pumpAndSettle();
      await t.ensureVisible(find.byKey(const Key('explanation-toggle')));
      await t.pumpAndSettle();
      await t.tap(find.byKey(const Key('explanation-toggle')));
      await t.pumpAndSettle();
      await t.ensureVisible(find.text(data.disclaimer));
      await t.pumpAndSettle();
      final bottom = t.getRect(find.text(data.disclaimer));
      final footer = t.getRect(find.byKey(const Key('explanation-replay')));
      expect(bottom.bottom, lessThanOrEqualTo(footer.top));
      expect(footer.height, greaterThanOrEqualTo(48));
      expect(t.takeException(), isNull);
    },
  );

  testWidgets(
    'failed source launch keeps the explanation and reports an error',
    (t) async {
      await t.pumpWidget(
        MaterialApp(
          home: LessonExplanationScreen(
            content: data,
            partner: MannerPartner.dog,
            progressHeader: const SizedBox(height: 50),
            openSource: (_) async => false,
          ),
        ),
      );
      await t.pumpAndSettle();
      await t.ensureVisible(find.byKey(const Key('explanation-toggle')));
      await t.pumpAndSettle();
      await t.tap(find.byKey(const Key('explanation-toggle')));
      await t.pumpAndSettle();
      final title = find.text('자료 1. ${data.sources.first.title}');
      await t.ensureVisible(title);
      await t.pumpAndSettle();
      await t.tap(title);
      await t.pump();
      expect(find.text('자료를 열지 못했어요. 잠시 후 다시 시도해 주세요.'), findsOneWidget);
      expect(find.byType(LessonExplanationScreen), findsOneWidget);
      expect(t.takeException(), isNull);
    },
  );
}

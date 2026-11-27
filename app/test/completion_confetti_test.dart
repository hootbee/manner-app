import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mannerfit/screens/partner_selection_screen.dart';
import 'package:mannerfit/screens/topic_completion.dart';
import 'package:mannerfit/screens/topic_completion_screen.dart';
import 'sequence_feedback_revision_test.dart' as fonts;
import 'transit04_screen_test.dart' as fixture;

void main() {
  const receipt = TopicCompletionReceipt(
    kind: TopicCompletionKind.firstDirect,
    awarded: 20,
    before: CompletionProfile(
      totalXp: 30,
      level: 1,
      levelXp: 30,
      levelMax: 100,
    ),
    after: CompletionProfile(totalXp: 50, level: 1, levelXp: 50, levelMax: 100),
  );
  final spec =
      jsonDecode(
            File(
              'assets/application01/completion_screen_spec.json',
            ).readAsStringSync(),
          )
          as Map<String, dynamic>;

  testWidgets(
    'confetti settles around the character and holds without replay; original layout and button timing remain',
    (t) async {
      t.view.physicalSize = const Size(390, 844);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.resetPhysicalSize);
      addTearDown(t.view.resetDevicePixelRatio);
      var calls = 0;
      Widget screen() => RepaintBoundary(
        key: fixture.boundary,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: ThemeData(fontFamily: 'Pretendard'),
          home: TopicCompletionScreen(
            complete: () async {
              calls++;
              return receipt;
            },
            partner: MannerPartner.dog,
            topicTitle: '지하철에서 다른 승객을 배려하며 짐 관리하기',
            spec: spec,
            onNext: () {},
          ),
        ),
      );
      await t.pumpWidget(screen());
      await t.pump();
      await fonts.captureFonts(t);
      // Loading capture fonts may settle the ticker; restart a fresh screen for
      // the time-based checks and the optional execution recording.
      await t.pumpWidget(const SizedBox());
      calls = 0;
      await t.pumpWidget(screen());
      await t.pump();
      final piece = find.byKey(const Key('completion-confetti-piece-0'));
      final next = find.byKey(const Key('topic-completion-next'));
      final xp = find.byKey(const Key('completion-xp'));
      final rewardCard = find
          .ancestor(of: xp, matching: find.byType(Container))
          .first;
      final rewardRect = t.getRect(rewardCard);
      final footerRect = t.getRect(next);
      double? earlyY, middleY;
      for (var ms = 0; ms <= 3300; ms += 100) {
        if (ms > 0) await t.pump(const Duration(milliseconds: 100));
        if (ms == 800) {
          earlyY = t.getCenter(piece).dy;
          expect(earlyY, lessThan(100));
        }
        if (ms == 1500) {
          middleY = t.getCenter(piece).dy;
          expect(middleY, greaterThan(earlyY! + 40));
          expect(t.widget<FilledButton>(next).onPressed, isNull);
        }
        if (ms == 1800) {
          expect(t.widget<FilledButton>(next).onPressed, isNotNull);
          expect(
            t
                .widget<LinearProgressIndicator>(
                  find.byKey(const Key('completion-gauge')),
                )
                .value,
            .5,
          );
        }
        if (ms == 2500) {
          expect(t.getCenter(piece).dy, greaterThan(middleY!));
          expect(t.getCenter(piece).dy, lessThan(t.getRect(xp).top));
          final opacity = t
              .widget<Opacity>(
                find.byKey(const Key('completion-confetti-opacity-0')),
              )
              .opacity;
          expect(opacity, inInclusiveRange(.7, 1));
        }
        if (ms >= 3200) {
          expect(
            find.byWidgetPredicate(
              (w) =>
                  w is Image &&
                  w.key.toString().contains('completion-confetti-piece-'),
            ),
            findsNWidgets(12),
          );
        }
        if (fixture.captureDir.isNotEmpty) {
          await fixture.capture(
            t,
            'confetti-${ms.toString().padLeft(4, '0')}',
            copies: 0,
          );
        }
      }
      expect(t.getRect(rewardCard), rewardRect);
      expect(t.getRect(next), footerRect);
      final layer = t.getRect(
        find.byKey(const Key('completion-confetti-layer')),
      );
      final settled = [
        for (var i = 0; i < 12; i++)
          t.getCenter(find.byKey(ValueKey('completion-confetti-piece-$i'))),
      ];
      for (final at in settled) {
        expect(layer.contains(at), isTrue);
      }
      await t.pumpWidget(screen());
      await t.pump(const Duration(seconds: 5));
      for (var i = 0; i < 12; i++) {
        expect(
          t.getCenter(find.byKey(ValueKey('completion-confetti-piece-$i'))),
          settled[i],
        );
      }
      expect(calls, 1);
      expect(find.text('이번에 배운 매너'), findsOneWidget);
      expect(t.takeException(), isNull);
      await t.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'reduced motion immediately shows the settled character decoration',
    (t) async {
      await t.pumpWidget(
        MaterialApp(
          builder: (c, child) => MediaQuery(
            data: MediaQuery.of(c).copyWith(disableAnimations: true),
            child: child!,
          ),
          home: TopicCompletionScreen(
            complete: () async => receipt,
            partner: MannerPartner.dog,
            topicTitle: '짐 관리하기',
            spec: spec,
            onNext: () {},
          ),
        ),
      );
      await t.pumpAndSettle();
      expect(
        find.byKey(const Key('completion-confetti-layer')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('completion-confetti-piece-0')),
        findsOneWidget,
      );
      expect(
        t
            .widget<FilledButton>(
              find.byKey(const Key('topic-completion-next')),
            )
            .onPressed,
        isNotNull,
      );
      expect(find.text('+20 XP'), findsOneWidget);
      expect(t.takeException(), isNull);
      await t.pumpWidget(const SizedBox());
    },
  );
}

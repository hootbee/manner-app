import 'result_popup_test_helpers.dart';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mannerfit/screens/action_drag_state.dart';
import 'package:mannerfit/screens/lesson_explanation_content.dart';
import 'package:mannerfit/screens/lesson_explanation_screen.dart';
import 'package:mannerfit/screens/partner_selection_screen.dart';
import 'package:mannerfit/screens/subway01_screen.dart';
import 'package:mannerfit/screens/transport_lesson_screen.dart';
import 'package:mannerfit/screens/transport_progress.dart';

void main() {
  testWidgets(
    'back preserves the answer; replay clears the attempt and preserves saved completion/XP',
    (t) async {
      t.view.physicalSize = const Size(393, 852);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.resetPhysicalSize);
      addTearDown(t.view.resetDevicePixelRatio);
      final store = TransportProgress(persist: false);
      addTearDown(store.dispose);
      final timestamp = DateTime.utc(2026, 11, 1, 10);
      store.sessions['transport-1'] = QuestionSession(
        firstCompletedAt: timestamp,
        phase: 'complete',
        lastCorrect: true,
        attempts: 2,
      );
      final original = jsonEncode(store.session('transport-1').toJson());
      final originalXp = store.xp;
      rootBundle.evict('assets/subway01/asset_rules.json');
      rootBundle.evict('assets/subway01/state_asset_mapping.json');
      await t.pumpWidget(
        MaterialApp(
          home: TransportLessonScreen(
            index: 0,
            store: store,
            partner: MannerPartner.cat,
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
      expect(find.byKey(const Key('subway01-scene')), findsOneWidget);
      final state =
          t
                  .widget<ListenableBuilder>(
                    find.descendant(
                      of: find.byType(Subway01Screen),
                      matching: find.byType(ListenableBuilder),
                    ),
                  )
                  .listenable
              as ActionDragState;
      void solve() {
        state.begin(1, state.initial.center, true);
        state.release(1, const Offset(774, 727));
        state.settle();
      }

      Future<void> explanation() async {
        await t.pump();
        await dismissResultPopup(t);
        await t.ensureVisible(find.text('해설 보기'));
        await t.pump();
        await tapAfterResult(t, find.text('해설 보기'));
        await t.pumpAndSettle();
        expect(find.byType(LessonExplanationScreen), findsOneWidget);
        expect(find.byKey(const Key('explanation-details')), findsNothing);
      }

      state.showHint();
      state.showHint();
      state.begin(1, state.initial.center, true);
      state.release(1, const Offset(300, 920));
      state.settle();
      state.retry();
      solve();
      await explanation();
      await dismissResultPopup(t);
      await t.ensureVisible(find.byKey(const Key('explanation-toggle')));
      await t.pumpAndSettle();
      await tapAfterResult(t, find.byKey(const Key('explanation-toggle')));
      await t.pumpAndSettle();
      expect(find.byKey(const Key('explanation-details')), findsOneWidget);
      await dismissResultPopup(t);
      await t.ensureVisible(find.byTooltip('뒤로 가기'));
      await t.pumpAndSettle();
      await tapAfterResult(t, find.byTooltip('뒤로 가기'));
      await t.pumpAndSettle();
      expect(state.phase, ActionPhase.correctComplete);
      expect(state.hint, 2);
      expect(state.wrongAttempts, 1);
      await explanation();
      await tapAfterResult(t, find.byKey(const Key('explanation-replay')));
      await t.pumpAndSettle();
      expect(state.phase, ActionPhase.initial);
      expect(state.hint, 0);
      expect(state.wrongAttempts, 0);
      expect(state.delta, Offset.zero);
      expect(state.pointer, isNull);
      expect(state.revealed, isFalse);
      expect(find.text('힌트 보기'), findsOneWidget);
      expect(
        find.byWidgetPredicate(
          (w) =>
              w is Image &&
              w.image is AssetImage &&
              (w.image as AssetImage).assetName.endsWith(
                'strap_front_overlay.png',
              ),
        ),
        findsOneWidget,
      );
      expect(store.session('transport-1').firstCompletedAt, timestamp);
      expect(store.xp, originalXp);
      expect(store.completed, 1);
      expect(jsonEncode(store.session('transport-1').toJson()), original);
      solve();
      await explanation();
      await tapAfterResult(t, find.byKey(const Key('explanation-replay')));
      await t.pumpAndSettle();
      expect(store.xp, originalXp);
      expect(jsonEncode(store.session('transport-1').toJson()), original);
      expect(t.takeException(), isNull);
    },
  );

  testWidgets(
    'enabled next button returns an intent to the existing learning flow',
    (t) async {
      ExplanationAction? result;
      await t.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () async {
                  result = await Navigator.of(context).push<ExplanationAction>(
                    MaterialPageRoute(
                      builder: (_) => LessonExplanationScreen(
                        content: lessonExplanations['transport-1']!,
                        partner: MannerPartner.dog,
                        progressHeader: const SizedBox(height: 50),
                        hasNextProblem: true,
                      ),
                    ),
                  );
                },
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );
      await tapAfterResult(t, find.text('open'));
      await t.pumpAndSettle();
      expect(
        t
            .widget<FilledButton>(find.byKey(const Key('explanation-next')))
            .onPressed,
        isNotNull,
      );
      await tapAfterResult(t, find.byKey(const Key('explanation-next')));
      await t.pumpAndSettle();
      expect(result, ExplanationAction.next);
    },
  );
}

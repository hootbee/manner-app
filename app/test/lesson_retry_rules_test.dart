import 'package:mannerfit/screens/digital_questions.dart';
import 'package:mannerfit/screens/school_questions.dart';
import 'package:mannerfit/screens/conversation_questions.dart';
import 'package:mannerfit/screens/dining_questions.dart';
import 'package:mannerfit/screens/public_questions.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:mannerfit/screens/transport_lesson_screen.dart';
import 'package:mannerfit/screens/learning_screens.dart';
import 'package:mannerfit/screens/learning_catalog.dart';
import 'package:mannerfit/screens/transport_progress.dart';
import 'package:mannerfit/screens/transport_questions.dart';

void main() {
  for (final questions in [
    transportQuestions,
    publicQuestions,
    diningQuestions,
    conversationQuestions,
    schoolQuestions,
    digitalQuestions,
  ]) {
    for (final kind in [QuestionKind.sequence, QuestionKind.drag]) {
      final index = questions.indexWhere((q) => q.kind == kind);
      final q = questions[index];
      testWidgets(
        '${q.categoryId} $kind visibly marks incorrect input after resume',
        (t) async {
          final store = TransportProgress(persist: false);
          store.submit(q, false);
          await t.pumpWidget(
            MaterialApp(
              builder: (c, child) => MediaQuery(
                data: MediaQuery.of(c).copyWith(disableAnimations: true),
                child: child!,
              ),
              home: TransportLessonScreen(
                index: index,
                categoryId: q.categoryId,
                store: store,
              ),
            ),
          );
          await t.pumpAndSettle();
          expect(
            find.byKey(const ValueKey('action-wrong-feedback')),
            findsOneWidget,
          );
          expect(
            find.descendant(
              of: find.byKey(const ValueKey('action-wrong-feedback')),
              matching: find.byIcon(Icons.cancel),
            ),
            findsOneWidget,
          );
          expect(find.text(q.explanation), findsNothing);
          expect(store.session(q.id).attempts, 1);
          if (kind == QuestionKind.drag) {
            final frame = t.widget<Container>(
              find.byKey(const ValueKey('drag-feedback-frame')),
            );
            expect(
              ((frame.decoration as BoxDecoration).border as Border).top.color,
              const Color(0xFFD84C50),
            );
          }
          expect(t.takeException(), isNull);
          await t.pumpWidget(const SizedBox());
        },
      );
    }
  }
  test(
    'third wrong answer requires retry and cannot grant completion or XP',
    () {
      final store = TransportProgress(persist: false);
      final q = transportQuestions[2];
      for (var i = 0; i < 2; i++) {
        store.submit(q, false);
        expect(store.session(q.id).phase, 'question');
      }
      store.submit(q, false);
      expect(store.session(q.id).phase, 'review');
      expect(store.complete(q.id), 0);
      expect(store.completed, 0);
      expect(store.xp, 320);
      final saved = QuestionSession.fromJson(store.session(q.id).toJson());
      expect(saved.hasFailed, isTrue);
      store.restart(q.id);
      expect(store.session(q.id).attempts, 0);
      expect(store.session(q.id).hasFailed, isTrue);
      store.submit(q, true);
      expect(store.complete(q.id), 10);
      expect(store.session(q.id).hasFailed, isTrue);
      final time = store.session(q.id).firstCompletedAt;
      store.restart(q.id);
      store.submit(q, true);
      expect(store.complete(q.id), 0);
      expect(store.session(q.id).firstCompletedAt, time);
    },
  );
  test(
    'legacy exhausted explanation resumes as review without deleting existing awards',
    () {
      final old = QuestionSession.fromJson({
        'attemptCount': 4,
        'phase': 'explanation',
        'lastCorrect': false,
      });
      expect(old.phase, 'review');
      expect(old.hasFailed, isTrue);
      final ongoing = QuestionSession.fromJson({
        'attemptCount': 3,
        'phase': 'question',
        'lastCorrect': false,
      });
      expect(ongoing.phase, 'review');
      final completed = QuestionSession.fromJson({
        'attemptCount': 4,
        'phase': 'complete',
        'lastCorrect': false,
        'firstCompletedAt': '2026-11-04T12:00:00',
      });
      expect(completed.phase, 'complete');
      expect(completed.firstCompletedAt, isNotNull);
    },
  );
  testWidgets(
    'review button restarts, success only offers completion, failed history remains visible',
    (t) async {
      final store = TransportProgress(persist: false);
      final q = transportQuestions[2];
      await t.pumpWidget(
        MaterialApp(
          builder: (c, child) => MediaQuery(
            data: MediaQuery.of(c).copyWith(disableAnimations: true),
            child: child!,
          ),
          home: TransportLessonScreen(index: 2, store: store),
        ),
      );
      for (var i = 0; i < 3; i++) {
        await t.tap(find.text('A'));
        await t.pumpAndSettle();
      }
      expect(find.text(q.explanation), findsOneWidget);
      expect(find.text('학습 완료'), findsNothing);
      expect(store.xp, 320);
      await t.ensureVisible(find.text('다시 풀기'));
      await t.tap(find.text('다시 풀기'));
      await t.pumpAndSettle();
      expect(store.session(q.id).attempts, 0);
      await t.ensureVisible(find.text('B'));
      await t.tap(find.text('B'));
      await t.pumpAndSettle();
      expect(find.text(q.explanation), findsOneWidget);
      expect(find.text('학습 완료'), findsOneWidget);
      await t.tap(find.text('학습 완료'));
      await t.pumpAndSettle();
      expect(store.xp, 330);
      TransportProgress.instance.sessions[q.id] = store.session(q.id);
      addTearDown(() => TransportProgress.instance.sessions.remove(q.id));
      await t.pumpWidget(
        MaterialApp(
          builder: (c, child) => MediaQuery(
            data: MediaQuery.of(c).copyWith(disableAnimations: true),
            child: child!,
          ),
          home: LearningLessonScreen(category: learningCategories.first),
        ),
      );
      await t.pumpAndSettle();
      expect(find.text('오답 이력 · 복습 완료'), findsOneWidget);
      expect(t.takeException(), isNull);
    },
  );
  testWidgets(
    'unresolved failed topic has a visible retry message in the list',
    (t) async {
      final id = transportQuestions[2].id;
      TransportProgress.instance.sessions[id] = QuestionSession(
        attempts: 3,
        phase: 'review',
        lastCorrect: false,
        hasFailed: true,
      );
      addTearDown(() => TransportProgress.instance.sessions.remove(id));
      await t.pumpWidget(
        MaterialApp(
          builder: (c, child) => MediaQuery(
            data: MediaQuery.of(c).copyWith(disableAnimations: true),
            child: child!,
          ),
          home: LearningLessonScreen(category: learningCategories.first),
        ),
      );
      await t.pumpAndSettle();
      expect(find.text('3회 오답 · 다시 풀어보세요'), findsOneWidget);
      expect(
        learningCategories.first.lessons[2].status,
        LessonStatus.inProgress,
      );
      expect(t.takeException(), isNull);
    },
  );
}

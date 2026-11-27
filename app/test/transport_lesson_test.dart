import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mannerfit/screens/transport_questions.dart';
import 'package:mannerfit/screens/transport_progress.dart';
import 'package:mannerfit/screens/transport_lesson_screen.dart';

void main() {
  test(
    'three failures require retry before completion, replay gives no XP',
    () {
      final store = TransportProgress(persist: false);
      final q = transportQuestions[2];
      for (var i = 0; i < 2; i++) {
        store.submit(q, false);
        expect(store.session(q.id).phase, 'question');
        expect(store.completed, 0);
      }
      store.submit(q, false);
      expect(store.session(q.id).phase, 'review');
      expect(store.xp, 320);
      expect(store.complete(q.id), 0);
      store.restart(q.id);
      store.submit(q, true);
      expect(store.complete(q.id), 10);
      final time = store.session(q.id).firstCompletedAt;
      expect(store.complete(q.id), 0);
      expect(store.xp, 330);
      store.restart(q.id);
      store.submit(q, true);
      expect(store.complete(q.id), 0);
      expect(store.session(q.id).firstCompletedAt, time);
    },
  );
  test('saved interaction, attempt and explanation state round-trip', () {
    final session = QuestionSession(
      attempts: 3,
      selected: '2',
      order: [2, 1, 3, 0],
      phase: 'question',
    );
    final restored = QuestionSession.fromJson(session.toJson());
    expect(restored.order, [2, 1, 3, 0]);
    expect(restored.attempts, 3);
    expect(restored.selected, '2');
    expect(restored.hintLevel, 3);
    for (final q in transportQuestions.where(
      (q) => q.kind == QuestionKind.sequence,
    )) {
      expect(
        q.order.toSet(),
        Set.of(List.generate(q.options.length, (i) => i)),
      );
    }
  });
  Future<void> mount(WidgetTester t, int index, TransportProgress store) async {
    t.view.physicalSize = const Size(360, 780);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    await t.pumpWidget(
      MaterialApp(
        builder: (c, child) => MediaQuery(
          data: MediaQuery.of(c).copyWith(disableAnimations: true),
          child: child!,
        ),
        home: TransportLessonScreen(
          key: ValueKey(index),
          index: index,
          store: store,
        ),
      ),
    );
    await t.pumpAndSettle();
  }

  testWidgets('choice wrong hint, correct explanation, XP and next question', (
    t,
  ) async {
    final store = TransportProgress(persist: false);
    // Keep immediate-choice regression coverage on legacy 07; 03/04 have dedicated flows.
    await mount(t, 6, store);
    await t.tap(find.text('A'));
    await t.pumpAndSettle();
    expect(store.session('transport-7').attempts, 1);
    await t.tap(find.text('B'));
    await t.pumpAndSettle();
    expect(find.text('정답이에요!'), findsOneWidget);
    expect(store.completed, 0);
    await t.ensureVisible(find.text('학습 완료'));
    await t.tap(find.text('학습 완료'));
    await t.pumpAndSettle();
    expect(find.text('매너 하나를 배웠어요!'), findsOneWidget);
    expect(store.xp, 330);
    await t.tap(find.text('다음 문제 풀러가기'));
    await t.pumpAndSettle();
    expect(find.textContaining(transportQuestions[7].title), findsOneWidget);
    expect(t.takeException(), isNull);
  });
  testWidgets('sequence retains incorrect order and can reorder then confirm', (
    t,
  ) async {
    final store = TransportProgress(persist: false);
    // 06 now has a dedicated recline interaction; 10 retains the legacy sequence UI.
    await mount(t, 9, store);
    await t.ensureVisible(find.text('정답 확인하기'));
    await t.tap(find.text('정답 확인하기'));
    await t.pumpAndSettle();
    expect(store.session('transport-10').order, [0, 1, 2]);
    final list = t.widget<ReorderableListView>(
      find.byType(ReorderableListView),
    );
    // Flutter versions differ in callback nullability.
    // ignore: unnecessary_non_null_assertion, deprecated_member_use
    list.onReorder!(1, 0);
    await t.pump();
    // ignore: unnecessary_non_null_assertion, deprecated_member_use
    list.onReorder!(2, 1);
    await t.pump();
    expect(store.session('transport-10').order, [1, 2, 0]);
    await t.ensureVisible(find.text('정답 확인하기'));
    await t.tap(find.text('정답 확인하기'));
    await t.pumpAndSettle();
    expect(store.session('transport-10').phase, 'explanation');
    expect(t.takeException(), isNull);
  });
  testWidgets('last problem completion shows last-question notice', (t) async {
    final store = TransportProgress(persist: false);
    store.session('transport-10').phase = 'explanation';
    store.session('transport-10').lastCorrect = true;
    await mount(t, 9, store);
    await t.ensureVisible(find.text('학습 완료'));
    await t.tap(find.text('학습 완료'));
    await t.pumpAndSettle();
    await t.tap(find.text('다음 문제 풀러가기'));
    await t.pumpAndSettle();
    expect(find.text('마지막 문제입니다.'), findsOneWidget);
  });
  testWidgets('05 now routes to the dedicated submit-only choice lesson', (
    t,
  ) async {
    t.view.physicalSize = const Size(393, 900);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    final store = TransportProgress(persist: false);
    addTearDown(store.dispose);
    await t.pumpWidget(
      MaterialApp(home: TransportLessonScreen(index: 4, store: store)),
    );
    for (
      var i = 0;
      i < 400 && find.byKey(const Key('transit05-ready')).evaluate().isEmpty;
      i++
    ) {
      await t.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 25)),
      );
      await t.pump(const Duration(milliseconds: 10));
    }
    expect(find.byKey(const Key('transit05-ready')), findsOneWidget);
    expect(store.session('transport-5').attempts, 0);
    expect(
      t
          .widget<FilledButton>(find.byKey(const Key('transit05-primary')))
          .onPressed,
      isNull,
    );
    expect(t.takeException(), isNull);
  });
  testWidgets('remaining touch question retains wrong mark and changes scene', (
    t,
  ) async {
    for (final index in [7]) {
      final store = TransportProgress(persist: false);
      await mount(t, index, store);
      final scene = find.byKey(const ValueKey('action-scene'));
      await t.ensureVisible(scene);
      await t.pumpAndSettle();
      var rect = t.getRect(scene);
      await t.tapAt(
        Offset(rect.left + rect.width * .8, rect.top + rect.height * .3),
      );
      await t.pumpAndSettle();
      expect(find.text('X'), findsOneWidget);
      expect(store.session('transport-${index + 1}').attempts, 1);
      rect = t.getRect(scene);
      await t.tapAt(
        Offset(rect.left + rect.width * .2, rect.top + rect.height * .75),
      );
      await t.pumpAndSettle();
      expect(find.text('O'), findsWidgets);
      expect(store.session('transport-${index + 1}').phase, 'explanation');
      expect(
        find.byWidgetPredicate(
          (w) =>
              w is Image &&
              w.image is AssetImage &&
              (w.image as AssetImage).assetName.endsWith('touch_success.webp'),
        ),
        findsOneWidget,
      );
      expect(t.takeException(), isNull);
    }
  });
}

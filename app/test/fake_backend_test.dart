// ADR 0002 작업 1, ADR 0004 작업 10: 가짜 구현의 세트 진행과 다시 풀기.
import 'package:flutter_test/flutter_test.dart';
import 'package:mannerfit/backend.dart';
import 'package:mannerfit/fake/fake_backend.dart';
import 'package:mannerfit/fake/samples.dart';

/// Intro는 넘기고 다음 Asking까지 간다.
Asking askNext(Session s) {
  do {
    s.next();
  } while (s.phase.value is Intro);
  return s.phase.value as Asking;
}

/// 샘플의 정답으로 답한다.
Answer right(Question q) {
  final c = samples.firstWhere((s) => identical(s.q, q)).e.correct;
  return switch (q) {
    PositionQuestion() => PickSpot(c.single),
    ChoiceQuestion() => PickOption(c.single),
    OxQuestion() => PickOx(c.single == 'o'),
    OrderQuestion() => PlaceOrder(c),
  };
}

void main() {
  setUp(() => backend = FakeBackend(delay: Duration.zero));

  test('틀린 문제는 맞힐 때까지 세트 맨 뒤에 retry로 다시 오고, 마지막 next 뒤 하루가 끝난다', () {
    final s = backend.startDaily();
    expect(s.phase.value, isA<Intro>());

    final first = askNext(s);
    expect(first.retry, isFalse);
    s.answer(PickSpot('inner')); // A-sidewalk의 정답은 outer
    expect((s.phase.value as Answered).e.grade, Grade.avoid);

    for (var i = 0; i < 5; i++) {
      final a = askNext(s);
      expect(a.retry, isFalse);
      s.answer(right(a.q));
    }

    var again = askNext(s);
    expect(again.q, same(first.q));
    expect(again.retry, isTrue);
    s.answer(PickSpot('inner')); // 또 틀린다

    again = askNext(s);
    expect(again.q, same(first.q));
    expect(again.retry, isTrue);
    s.answer(right(again.q));
    expect((s.phase.value as Answered).last, isTrue); // 맞히면 더 오지 않는다

    expect(backend.home.value.streak, 0);
    s.next();
    final f = s.phase.value as Finished;
    expect((f.xpGained, f.firstTry, f.total, f.bestCombo, f.streak), (60, 5, 6, 5, 1));
    expect(f.retryTomorrow, ['동행자를 인도 안쪽으로']);
    expect(backend.home.value.streak, 1);
    expect(backend.home.value.today!.doneToday, isTrue);
    expect(backend.home.value.xp, 60);
  });

  test('같은 요청 두 번: 두 번째 answer와 Finished 뒤 next는 무시된다', () {
    final s = backend.startDaily();
    s.answer(PickSpot('outer')); // Intro에서는 받지 않는다
    expect(s.phase.value, isA<Intro>());

    final a = askNext(s);
    s.answer(right(a.q));
    s.answer(right(a.q));
    expect(backend.home.value.xp, 10);

    while (s.phase.value is! Finished) {
      if (s.phase.value is Asking) s.answer(right((s.phase.value as Asking).q));
      s.next();
    }
    s.next();
    expect(backend.home.value.streak, 1);
  });

  test('프리셋마다 경계 상태가 재현된다', () async {
    FakeBackend p(String name) => FakeBackend.preset(name);

    expect(p('guest').account.value, isNull);
    expect(p('signedIn').account.value, isNotNull);
    expect(p('doneToday').home.value.today!.doneToday, isTrue);
    expect(p('noDay').home.value.today, isNull);
    expect(p('offline').online.value, isFalse);
    expect(await p('offline').signIn(), SignInResult.offline);
    expect(await p('signInFails').signIn(), SignInResult.failed);
    expect(((await p('wouldLose').signOut()) as WouldLose).count, 3);
    expect(await p('deleteFails').deleteAccount(), DeleteResult.failed);
    expect(await p('offline').deleteAccount(), DeleteResult.offline);
    expect(() => p('nope'), throwsArgumentError);
  });

  test('ok 보기도 best가 아니므로 xp 5를 받고 같은 문제가 맨 뒤에 retry로 온다', () {
    final s = backend.startDaily();
    for (var i = 0; i < 4; i++) {
      s.answer(right(askNext(s).q));
    }
    final umbrella = askNext(s);
    expect(umbrella.q, isA<ChoiceQuestion>());
    s.answer(const PickOption('b')); // 가운데에 똑바로: ok
    final e = (s.phase.value as Answered).e;
    expect((e.grade, e.xp), (Grade.ok, 5));
    expect(backend.home.value.xp, 45);

    s.answer(right(askNext(s).q)); // 횡단보도
    final again = askNext(s);
    expect(again.q, same(umbrella.q));
    expect(again.retry, isTrue);
  });

  test('setOnline이 online 값을 바꾼다', () {
    final fake = FakeBackend(delay: Duration.zero);
    fake.setOnline(false);
    expect(fake.online.value, isFalse);
    fake.setOnline(true);
    expect(fake.online.value, isTrue);
  });

  group('로그아웃과 탈퇴에 성공하면 로컬 기록이 지워진 것처럼 home이 처음으로 돌아간다', () {
    const me = Account(name: '김매너', email: 'manner@example.com');
    late FakeBackend fake;

    setUp(() {
      fake = FakeBackend(account: me, unsynced: 3, delay: Duration.zero);
      final s = fake.startDaily();
      while (s.phase.value is! Finished) {
        if (s.phase.value is Asking) s.answer(right((s.phase.value as Asking).q));
        s.next();
      }
      expect((fake.home.value.xp, fake.home.value.streak, fake.home.value.today!.doneToday), (60, 1, true));
    });

    test('signOut(discardUnsynced: true)', () async {
      expect(await fake.signOut(discardUnsynced: true), isA<SignedOut>());
      expect(fake.account.value, isNull);
      expect((fake.home.value.xp, fake.home.value.streak, fake.home.value.today!.doneToday), (0, 0, false));
    });

    test('deleteAccount', () async {
      expect(await fake.deleteAccount(), DeleteResult.ok);
      expect(fake.account.value, isNull);
      expect((fake.home.value.xp, fake.home.value.streak, fake.home.value.today!.doneToday), (0, 0, false));
    });
  });
}

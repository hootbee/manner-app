// ADR 0007 §4, 작업 3: 화면 동작을 한 줄씩 남기는 감싸개.
import 'package:flutter_test/flutter_test.dart';
import 'package:mannerfit/backend.dart';
import 'package:mannerfit/fake/fake_backend.dart';
import 'package:mannerfit/logged_backend.dart';

/// 안쪽이 비동기로 던지는 경우(ADR 0007 §4 표의 `signIn threw PostgrestException`).
class _ThrowingSignIn extends FakeBackend {
  @override
  Future<SignInResult> signIn() async => throw StateError('홍길동 a@b.c');
}

void main() {
  test('signIn은 결과 이름과 걸린 시간 한 줄을 남긴다', () async {
    final lines = <String>[];
    final b = LoggedBackend(FakeBackend(signIn: SignInResult.offline), log: lines.add);

    expect(await b.signIn(), SignInResult.offline);
    expect(lines, [matches(RegExp(r'^signIn offline \d+ms$'))]);
  });

  test('startDaily는 phase 클래스 이름을, 두 번 탭한 답은 두 줄을 남긴다', () {
    final lines = <String>[];
    final b = LoggedBackend(FakeBackend(), log: lines.add);

    final s = b.startDaily();
    expect(lines.single, matches(RegExp(r'^startDaily Intro \d+ms$')));

    s.next(); // Intro → Asking
    expect(s.phase.value, isA<Asking>());
    s.answer(const PickSpot('inner')); // 첫 문제 A-sidewalk
    s.answer(const PickSpot('inner')); // 두 번째 탭은 안쪽이 무시한다
    expect(lines.where((l) => RegExp(r'^answer Answered \d+ms$').hasMatch(l)), hasLength(2));
  });

  test('안쪽이 던지면 타입 이름 한 줄을 남기고 같은 예외를 다시 던진다', () async {
    final lines = <String>[];

    final sync = FakeBackend(doneToday: true); // startDaily가 StateError를 던진다
    Object? thrown;
    try {
      LoggedBackend(sync, log: lines.add).startDaily();
    } catch (e) {
      thrown = e;
    }
    expect(thrown, isA<StateError>());
    expect(lines, [matches(RegExp(r'^startDaily threw StateError \d+ms$'))]);

    lines.clear();
    final b = LoggedBackend(_ThrowingSignIn(), log: lines.add);
    await expectLater(b.signIn(), throwsA(isA<StateError>()));
    expect(lines, [matches(RegExp(r'^signIn threw StateError \d+ms$'))]);
  });

  test('signOut은 WouldLose의 개수를 남기지 않는다', () async {
    final lines = <String>[];
    final b = LoggedBackend(FakeBackend(unsynced: 3, delay: Duration.zero), log: lines.add);

    expect(await b.signOut(), isA<WouldLose>());
    expect(lines, [matches(RegExp(r'^signOut WouldLose \d+ms$'))]);
  });

  test('모든 메서드를 불러도 이름·이메일은 줄에 없다', () async {
    final lines = <String>[];
    final b = LoggedBackend(
      FakeBackend(account: const Account(name: '홍길동', email: 'a@b.c'), delay: Duration.zero),
      log: lines.add,
    );

    b.home.value;
    b.stats.value;
    b.account.value;
    b.online.value;
    final s = b.startDaily();
    s.next();
    s.answer(const PickSpot('inner'));
    s.next();
    s.quit();
    await b.signIn();
    await b.signOut();
    await b.deleteAccount();

    expect(lines, hasLength(8)); // 값 읽기는 남기지 않는다
    for (final l in lines) {
      expect(l, matches(RegExp(r'^\w+ \w+ \d+ms$'))); // 메서드, 결과 종류, 시간 말고는 없다
      expect(l, isNot(contains('홍길동')));
      expect(l, isNot(contains('@')));
    }
  });
}

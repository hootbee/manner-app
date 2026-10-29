// ADR 0007 §4: 화면 동작마다 `<메서드> <결과 종류> <걸린 ms>ms` 한 줄을 log로 남긴다.
// backend.dart만 import한다. Firebase를 모른다. 인자, 결과 안의 값, 이름·이메일, 예외 메시지는 남기지 않는다.
import 'backend.dart';

class LoggedBackend implements Backend {
  LoggedBackend(this._inner, {required void Function(String) log}) : _log = log;
  final Backend _inner;
  final void Function(String) _log;

  // 값 읽기는 기록하지 않는다. 반환 타입은 Backend에서 물려받는다.
  @override
  get home => _inner.home;
  @override
  get stats => _inner.stats;
  @override
  get account => _inner.account;
  @override
  get online => _inner.online;

  @override
  Session startDaily() =>
      _timed(_log, 'startDaily', () => _LoggedSession(_inner.startDaily(), _log), (s) => _kind(s.phase.value));

  @override
  Future<SignInResult> signIn() => _timedAsync('signIn', _inner.signIn, (r) => r.name);

  @override
  Future<SignOutResult> signOut({bool discardUnsynced = false}) =>
      _timedAsync('signOut', () => _inner.signOut(discardUnsynced: discardUnsynced), _kind);

  @override
  Future<DeleteResult> deleteAccount() => _timedAsync('deleteAccount', _inner.deleteAccount, (r) => r.name);

  Future<R> _timedAsync<R>(String method, Future<R> Function() call, String Function(R) kind) async {
    final sw = Stopwatch()..start();
    try {
      final r = await call();
      _log('$method ${kind(r)} ${sw.elapsedMilliseconds}ms');
      return r;
    } catch (e) {
      _log('$method threw ${e.runtimeType} ${sw.elapsedMilliseconds}ms');
      rethrow;
    }
  }
}

class _LoggedSession implements Session {
  _LoggedSession(this._inner, this._log);
  final Session _inner;
  final void Function(String) _log;

  @override
  get phase => _inner.phase;

  @override
  void answer(Answer a) => _timed(_log, 'answer', () => _inner.answer(a), (_) => _kind(phase.value));
  @override
  void next() => _timed(_log, 'next', _inner.next, (_) => _kind(phase.value));
  @override
  void quit() => _timed(_log, 'quit', _inner.quit, (_) => _kind(phase.value));
}

String _kind(Object o) => '${o.runtimeType}';

R _timed<R>(void Function(String) log, String method, R Function() call, String Function(R) kind) {
  final sw = Stopwatch()..start();
  try {
    final r = call();
    log('$method ${kind(r)} ${sw.elapsedMilliseconds}ms');
    return r;
  } catch (e) {
    log('$method threw ${e.runtimeType} ${sw.elapsedMilliseconds}ms');
    rethrow;
  }
}

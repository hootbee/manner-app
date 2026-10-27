// 가짜 구현(ADR 0002 §3). 메모리에만 상태를 둔다. 화면을 만들 때 경계 상태를 재현하는 도구다.
import 'dart:math';

import 'package:flutter/foundation.dart';

import '../backend.dart';
import 'samples.dart' as data;

class FakeBackend implements Backend {
  FakeBackend({
    bool online = true,
    Account? account,
    bool doneToday = false,
    bool noDay = false,
    SignInResult signIn = SignInResult.ok,
    int unsynced = 0,
    DeleteResult delete = DeleteResult.ok,
    Duration delay = const Duration(milliseconds: 300),
  })  : _online = ValueNotifier(online),
        _account = ValueNotifier(account),
        _done = doneToday,
        _streak = doneToday ? 1 : 0,
        _noDay = noDay,
        _signIn = signIn,
        _unsynced = unsynced,
        _delete = delete,
        _delay = delay;

  /// `flutter run --dart-define=FAKE=<이름>`으로 고르는 묶음.
  factory FakeBackend.preset(String name) => switch (name) {
        'guest' => FakeBackend(),
        'signedIn' => FakeBackend(account: _me),
        'doneToday' => FakeBackend(doneToday: true),
        'noDay' => FakeBackend(noDay: true),
        'offline' => FakeBackend(online: false, account: _me), // 탈퇴 버튼이 막힌다. 게스트 오프라인은 FakeBackend(online: false)
        'signInFails' => FakeBackend(signIn: SignInResult.failed),
        'wouldLose' => FakeBackend(account: _me, unsynced: 3),
        'deleteFails' => FakeBackend(account: _me, delete: DeleteResult.failed),
        _ => throw ArgumentError.value(name, 'FAKE', '프리셋 이름이 아니다'),
      };

  static const _me = Account(name: '김매너', email: 'manner@example.com');

  final ValueNotifier<bool> _online;
  final ValueNotifier<Account?> _account;
  final bool _noDay;
  final SignInResult _signIn;
  final int _unsynced;
  final DeleteResult _delete;
  final Duration _delay;
  bool _done;
  int _streak, _xp = 0;

  late final _home = ValueNotifier(_build());
  final _stats = ValueNotifier(data.stats);

  @override
  ValueListenable<Home> get home => _home;
  @override
  ValueListenable<List<AreaStat>> get stats => _stats;
  @override
  ValueListenable<Account?> get account => _account;
  @override
  ValueListenable<bool> get online => _online;

  void setOnline(bool v) => _online.value = v;

  Home _build() => Home(
        today: _noDay
            ? null
            : DayCard(
                number: 1,
                title: data.dayTitle,
                scenes: [for (final s in data.scenes) s.$1],
                doneToday: _done,
                nextTitle: _done ? data.nextDayTitle : null,
              ),
        streak: _streak,
        reviewsDue: _done ? 0 : 1, // 횡단보도 문제가 복습 자리에 있다
        xp: _xp,
        level: _xp ~/ 100 + 1,
        levelProgress: _xp % 100 / 100,
      );

  void _addXp(int xp) {
    _xp += xp;
    _home.value = _build();
  }

  /// 실제 구현은 로그아웃·탈퇴 때 로컬 기록을 지운다(ADR 0001 §3·§5-3). 기록이 없으면 처음 상태다.
  void _signedOut() {
    _account.value = null;
    _xp = 0;
    _streak = 0;
    _done = false;
    _home.value = _build();
  }

  void _finishDay() {
    _streak++;
    _done = true;
    _home.value = _build();
  }

  @override
  Session startDaily() {
    if (_noDay || _done) throw StateError('준비된 하루가 없거나 오늘 이미 마쳤다');
    return _FakeSession(this);
  }

  @override
  Future<SignInResult> signIn() async {
    await Future.delayed(_delay);
    if (!_online.value) return SignInResult.offline;
    if (_signIn == SignInResult.ok) _account.value = _me;
    return _signIn;
  }

  @override
  Future<SignOutResult> signOut({bool discardUnsynced = false}) async {
    await Future.delayed(_delay);
    if (_unsynced > 0 && !discardUnsynced) return WouldLose(_unsynced);
    _signedOut();
    return const SignedOut();
  }

  @override
  Future<DeleteResult> deleteAccount() async {
    await Future.delayed(_delay);
    if (!_online.value) return DeleteResult.offline;
    if (_delete == DeleteResult.ok) _signedOut();
    return _delete;
  }
}

/// day-01 세트. best가 아닌 문제는 같은 문제를 맨 뒤에 retry로 다시 넣는다(ADR 0004 §4).
class _FakeSession implements Session {
  _FakeSession(this._b);
  final FakeBackend _b;

  final _queue = [for (final s in data.samples) (s: s, retry: false)];
  var _i = 0;
  int _xp = 0, _combo = 0, _bestCombo = 0, _firstTry = 0;
  final _missed = <String>{}; // 처음 나온 순서

  late final _phase = ValueNotifier<Phase>(_intro(0));
  @override
  ValueListenable<Phase> get phase => _phase;

  Intro _intro(int scene) => Intro(_i / _queue.length,
      dayTitle: data.dayTitle, intro: data.scenes[scene].$2, scene: data.scenes[scene].$1);

  Asking _asking() => Asking(_i / _queue.length, q: _queue[_i].s.q, retry: _queue[_i].retry);

  @override
  void answer(Answer a) {
    if (_phase.value is! Asking) return;
    final (:s, :retry) = _queue[_i];
    final c = s.e.correct;
    final grade = switch (a) {
      PickOption(:final id) => s.e.options[id]?.grade ?? Grade.avoid,
      PickSpot(:final id) => listEquals([id], c) ? Grade.best : Grade.avoid,
      PickOx(:final o) => listEquals([o ? 'o' : 'x'], c) ? Grade.best : Grade.avoid,
      PlaceOrder(:final ids) => listEquals(ids, c) ? Grade.best : Grade.avoid,
    };
    final xp = switch (grade) { Grade.best => 10, Grade.ok => 5, Grade.avoid => 0 };
    _combo = grade == Grade.best ? _combo + 1 : 0;
    _bestCombo = max(_bestCombo, _combo);
    _xp += xp;
    if (!retry && grade == Grade.best) _firstTry++;
    if (grade != Grade.best) {
      _queue.add((s: s, retry: true));
      _missed.add(s.manner);
    }
    _b._addXp(xp);

    final last = _i + 1 == _queue.length;
    final n = last ? null : _queue[_i + 1];
    _phase.value = Answered(
      (_i + 1) / _queue.length,
      q: s.q,
      e: Explanation(
        grade: grade,
        xp: xp,
        combo: _combo,
        title: s.e.title,
        why: s.e.why,
        correct: c,
        options: s.e.options,
        evidence: s.e.evidence,
      ),
      nextScene: n != null && !n.retry && n.s.scene != s.scene ? data.scenes[n.s.scene].$1 : null,
      last: last,
    );
  }

  @override
  void next() {
    switch (_phase.value) {
      case Intro():
        _phase.value = _asking();
      case Answered(last: true):
        _b._finishDay();
        _phase.value = Finished(
          xpGained: _xp,
          firstTry: _firstTry,
          total: data.samples.length,
          bestCombo: _bestCombo,
          streak: _b._streak,
          retryTomorrow: _missed.toList(),
        );
      case Answered():
        final scene = _queue[_i].s.scene;
        _i++;
        final n = _queue[_i];
        _phase.value = !n.retry && n.s.scene != scene ? _intro(n.s.scene) : _asking();
      case Asking() || Finished():
        return;
    }
  }

  @override
  void quit() {} // 답한 XP는 answer에서 이미 home에 들어갔다
}

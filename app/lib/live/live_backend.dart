// 화면 인터페이스의 실제 구현(ADR 0002 §1). 콘텐츠, 엔진, 저장소, 인증을 이어 붙이기만 한다.
// 홈과 스테이터스 값은 기록이 바뀔 때마다 기록 + 콘텐츠 + 오늘로 다시 계산한다(ADR 0004).
import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:path_provider/path_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide Session;

import '../auth/auth.dart';
import '../backend.dart';
import '../content/content.dart';
import '../engine/areas.dart' as engine;
import '../engine/daily.dart' as engine;
import '../engine/engine.dart' as engine;
import '../engine/leitner.dart' as engine;
import '../sync/store.dart';
import 'content_update.dart';
import 'question.dart';

/// 공개 식별자다. publishable 키는 RLS를 거치는 클라이언트용 키다. service role·secret 키는 앱에 넣지 않는다.
const supabaseUrl = 'https://zyjrygavqubomqgojavw.supabase.co';
const publishableKey = 'sb_publishable_EbqpO11yypaObh3k_vREFQ_XWUaEh3F';

class LiveBackend implements Backend {
  /// 테스트는 자기 저장소, 인증, 콘텐츠, 날짜를 넣는다. 앱은 [start]를 쓴다.
  LiveBackend({
    required Content content,
    required Store store,
    required Auth auth,
    required SupabaseClient client,
    DateTime Function() now = DateTime.now,
  })  : _content = content,
        _store = store,
        _auth = auth,
        _client = client,
        _now = now,
        _account = ValueNotifier(_accountOf(client.auth.currentUser)) {
    _refresh();
  }

  /// ADR 0003 §5, ADR 0005 §4: 콘텐츠 고르기 → 저장소 → 인증. 새 콘텐츠 받기와 시작 sync는 기다리지 않는다.
  static Future<LiveBackend> start() async {
    await Supabase.initialize(url: supabaseUrl, publishableKey: publishableKey);
    final client = Supabase.instance.client;
    final dir = await getApplicationSupportDirectory();
    final content = pickContent(dir, parseContent(await rootBundle.loadString('assets/content.json')));
    final store = Store(File('${dir.path}/records.json'), client);
    final b = LiveBackend(
      content: content,
      store: store,
      client: client,
      auth: await Auth.google(client, clearLocal: store.clear),
    );
    unawaited(fetchContent(supabaseUrl, dir, content)); // 받은 것은 다음 시작부터 쓴다
    unawaited(b.sync());
    AppLifecycleListener(onResume: b.onResume);
    return b;
  }

  final Content _content;
  final Store _store;
  final Auth _auth;
  final SupabaseClient _client;
  final DateTime Function() _now;
  final _rng = Random();

  final _home = ValueNotifier(const Home(today: null, streak: 0, reviewsDue: 0, xp: 0, level: 1, levelProgress: 0));
  final _stats = ValueNotifier(const <AreaStat>[]);
  final ValueNotifier<Account?> _account;
  final _online = ValueNotifier(true); // 게스트는 항상 true. 로그인하면 마지막 Supabase 요청이 서버에 닿았는가
  var _deleting = false;

  @override
  ValueListenable<Home> get home => _home;
  @override
  ValueListenable<List<AreaStat>> get stats => _stats;
  @override
  ValueListenable<Account?> get account => _account;
  @override
  ValueListenable<bool> get online => _online;

  void _refresh() {
    final today = _now(), attempts = _store.attempts, done = _store.dayCompletions;
    final boxes = engine.boxes(_content, attempts);
    final pos = engine.dailyPosition(_content, done, today);
    final xp = engine.xp(attempts);
    _home.value = Home(
      today: pos == null
          ? null
          : DayCard(
              number: pos.number,
              title: pos.day['title'] as String,
              scenes: [for (final s in _scenes(pos.day)) _card(s)],
              doneToday: pos.doneToday,
              nextTitle: pos.doneToday ? (pos.next?['title'] as String?) : null,
            ),
      streak: engine.streak(done, today),
      reviewsDue: engine.reviewsDue(_content, boxes, today),
      xp: xp,
      level: engine.level(xp),
      levelProgress: engine.levelProgress(xp),
    );
    _stats.value = [for (final (area, value) in engine.areaStats(_content, attempts, boxes, today)) AreaStat(area, value)];
  }

  @override
  Session startDaily() {
    final today = _now(), attempts = _store.attempts;
    final pos = engine.dailyPosition(_content, _store.dayCompletions, today);
    if (pos == null || pos.doneToday) throw StateError('준비된 하루가 없거나 오늘 이미 마쳤다');
    final plan = engine.planDay(_content, pos.day, attempts, engine.boxes(_content, attempts), today, _rng);
    return _LiveSession(this, pos.day, plan);
  }

  /// 앱이 앞으로 올 때. sync가 끝나면 다시 계산하므로 자정을 넘겨 켜 둔 앱도 새 날짜로 보인다. 게스트는 요청을 보내지 않는다.
  void onResume() => unawaited(sync());

  /// 앱 시작, 세트 끝, 로그인 뒤에 부른다. 실패하면 다음 호출에서 다시 한다(ADR 0001 §3).
  /// 23503(다른 기기에서 탈퇴)이거나, 세션이 없는데 synced=true 행이 있으면(갱신 실패) 로컬을 지우고 로그아웃한다(ADR 0001 §5-5).
  Future<void> sync() async {
    if (_deleting) return; // ADR 0001 §5-2: 탈퇴 중에는 sync를 멈춘다
    Object? error;
    try {
      for (final t in tables) {
        await _store.sync(t);
      }
    } catch (e) {
      error = e;
    }
    _online.value = error == null || _reached(error); // 게스트는 요청을 보내지 않으므로 늘 true다
    final gone = error is PostgrestException && error.code == '23503';
    // 세션이 없는데 서버에서 온 행(synced=true)이 있으면 세션이 사라진 것이다. 게스트 행은 synced가 될 수 없다.
    final lost = _client.auth.currentUser == null &&
        _store.attempts.length + _store.dayCompletions.length > _store.unsynced;
    if (gone || lost) {
      await _forget();
    } else {
      _account.value = _accountOf(_client.auth.currentUser); // 세션이 사라졌으면 게스트로 보인다
      _refresh();
    }
  }

  /// 로컬 기록·커서와 Supabase 세션을 지우고(`Store.clear`) Google에서도 로그아웃한다.
  Future<void> _forget() async {
    await _store.clear();
    await _auth.signOut();
    _account.value = null;
    _online.value = true;
    _refresh();
  }

  @override
  Future<SignInResult> signIn() async {
    final r = await _auth.signIn();
    if (r == SignInStatus.ok) {
      _account.value = _accountOf(_client.auth.currentUser);
      await sync(); // 게스트 기록을 올리고 다른 기기 기록을 받는다(ADR 0001 §3)
    }
    return SignInResult.values.byName(r.name);
  }

  /// ADR 0005 §4: sync → 못 올린 행이 있으면 확인 → Store.clear → Google 로그아웃.
  @override
  Future<SignOutResult> signOut({bool discardUnsynced = false}) async {
    await sync();
    if (_store.unsynced > 0 && !discardUnsynced) return WouldLose(_store.unsynced);
    await _forget();
    return const SignedOut();
  }

  /// ADR 0001 §5-2~4. 로컬을 지울지는 auth/가 정한다(clearLocal = Store.clear).
  @override
  Future<DeleteResult> deleteAccount() async {
    _deleting = true;
    final DeleteStatus r;
    try {
      r = await _auth.deleteAccount();
    } finally {
      _deleting = false;
    }
    _account.value = _accountOf(_client.auth.currentUser);
    _online.value = r != DeleteStatus.offline;
    _refresh();
    return DeleteResult.values.byName(r.name);
  }
}

/// 서버가 응답했는가. statusCode가 있는 AuthRetryableFetchException(5xx), PostgrestException, 그 밖의 AuthException은
/// 닿은 것이다. 목록에 없는 오류(statusCode 없는 AuthRetryableFetchException, ClientException 같은 전송 오류)는 닿지 않은 것으로 본다.
bool _reached(Object e) => switch (e) {
      AuthRetryableFetchException(:final statusCode) => statusCode != null,
      PostgrestException() || AuthException() => true,
      _ => false,
    };

Account? _accountOf(User? u) => u == null
    ? null
    : Account(name: (u.userMetadata?['full_name'] ?? u.userMetadata?['name'] ?? '') as String, email: u.email ?? '');

List<Json> _scenes(Json day) => (day['scenes'] as List).cast<Json>();

SceneCard _card(Json s) => SceneCard(time: s['time'] as String, title: s['title'] as String, short: s['short'] as String);

/// 데일리 세트 하나. best가 아닌 문제는 같은 문제를 맨 뒤에 retry로 다시 넣는다(ADR 0004 §4).
/// 답은 로컬 기록을 쓴 뒤에 Answered를 낸다. 마지막 next에서 하루 완료를 쓰고 Finished를 낸다.
class _LiveSession implements Session {
  _LiveSession(this._b, this._day, List<List<String>> plan) {
    for (final (i, ids) in plan.indexed) {
      for (final id in ids) {
        _queue.add((shown: Shown(_b._content, id, _b._rng), scene: i, retry: false));
      }
    }
    _total = _queue.length;
  }

  final LiveBackend _b;
  final Json _day;
  final _queue = <({Shown shown, int scene, bool retry})>[];
  late final int _total;
  var _i = 0;
  int _combo = 0, _bestCombo = 0, _firstTry = 0;
  final _attempts = <engine.Attempt>[]; // 이 세트의 기록. retryTomorrow에 쓴다

  late final _phase = ValueNotifier<Phase>(_intro(0));
  @override
  ValueListenable<Phase> get phase => _phase;

  Intro _intro(int scene) => Intro(_i / _queue.length,
      dayTitle: _day['title'] as String, intro: _scenes(_day)[scene]['intro'] as String, scene: _card(_scenes(_day)[scene]));

  Asking _asking() => Asking(_i / _queue.length, q: _queue[_i].shown.q, retry: _queue[_i].retry);

  @override
  void answer(Answer a) {
    if (_phase.value is! Asking) return;
    final (:shown, :scene, :retry) = _queue[_i];
    final grade = shown.grade(a);
    final g = engine.Grade.values.byName(grade.name);
    final attempt = engine.Attempt(id: newId(), scenarioId: shown.id, grade: g, solvedOn: _b._now());
    _b._store.addAttempt(attempt); // 파일에 쓰고 돌아온다
    _b._refresh();
    _attempts.add(attempt);

    _combo = grade == Grade.best ? _combo + 1 : 0;
    _bestCombo = max(_bestCombo, _combo);
    if (!retry && grade == Grade.best) _firstTry++;
    if (grade != Grade.best) _queue.add((shown: shown, scene: scene, retry: true));

    final last = _i + 1 == _queue.length;
    final n = last ? null : _queue[_i + 1];
    _phase.value = Answered(
      (_i + 1) / _queue.length,
      q: shown.q,
      e: shown.explain(grade, g.xp, _combo),
      nextScene: n != null && !n.retry && n.scene != scene ? _card(_scenes(_day)[n.scene]) : null,
      last: last,
    );
  }

  @override
  void next() {
    switch (_phase.value) {
      case Intro():
        _phase.value = _asking();
      case Answered(last: true):
        _b._store.addDayCompletion(engine.DayCompletion(id: newId(), dayId: _day['id'] as String, completedOn: _b._now()));
        _b._refresh();
        _phase.value = Finished(
          xpGained: engine.xp(_attempts),
          firstTry: _firstTry,
          total: _total,
          bestCombo: _bestCombo,
          streak: _b._home.value.streak,
          retryTomorrow: engine.retryTomorrow(_b._content, _attempts),
        );
        unawaited(_b.sync());
      case Answered():
        final scene = _queue[_i].scene;
        _i++;
        final n = _queue[_i];
        _phase.value = !n.retry && n.scene != scene ? _intro(n.scene) : _asking();
      case Asking() || Finished():
        return;
    }
  }

  @override
  void quit() => unawaited(_b.sync()); // 중간 저장 없음. 답한 기록은 answer에서 이미 썼다
}

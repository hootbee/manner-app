// ADR 0002 작업 11: 실제 구현이 모듈을 이어 붙인 결과. Supabase는 가짜 HTTP나 닿지 않는 주소, Google은 가짜 함수.
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mannerfit/auth/auth.dart';
import 'package:mannerfit/backend.dart';
import 'package:mannerfit/content/content.dart';
import 'package:mannerfit/live/live_backend.dart';
import 'package:mannerfit/sync/store.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide Session;

/// 매너 3개, 매너마다 ox 문제 2개(정답은 모두 O), 하루 2개.
final content = fixture('ox');

/// [format]이 choice면 문제마다 보기 0 best, 1 ok, 2 avoid.
Content fixture(String format) => parseContent(jsonEncode({
  'schema': 1,
  'version': 1,
  'principles': [
    {'id': 'A', 'name': '원칙', 'motto': '모토'},
  ],
  'manners': [
    for (final m in [1, 2, 3]) {'id': m, 'name': '매너$m', 'principle': 'A', 'places': <String>[]},
  ],
  'scenarios': [
    for (final m in [1, 2, 3])
      for (final k in ['a', 'b'])
        {
          'id': 'X-$m$k',
          'manner': m,
          'format': format,
          'area': '연애',
          'prompt': '문제 $m$k',
          'answer': true,
          'options': [
            {'text': '최선', 'grade': 'best'},
            {'text': '괜찮음', 'grade': 'ok'},
            {'text': '피함', 'grade': 'avoid'},
          ],
          'feedback': {'title': '제목', 'why': '이유'},
        },
  ],
  'days': [
    for (final d in ['day-01', 'day-02'])
      {
        'id': d,
        'title': '$d 제목',
        'scenes': [
          for (final m in [1, 2, 3]) {'time': '0$m:00', 'title': '장면$m', 'short': '짧게$m', 'intro': '소개$m', 'manner': m},
        ],
      },
  ],
}));

const right = PickOx(true), wrong = PickOx(false);
var today = DateTime(2026, 10, 27, 9); // 자정 테스트가 바꾼다. setUp에서 되돌린다

Map<String, Object> session(String token) => {
      'access_token': token,
      'token_type': 'bearer',
      'expires_in': 3600,
      'refresh_token': 'r-$token',
      'user': {
        'id': 'u1',
        'aud': 'authenticated',
        'email': 'me@example.com',
        'created_at': '2026-10-27T00:00:00Z',
        'app_metadata': {},
        'user_metadata': {'full_name': '김매너'},
      },
    };

http.Response status(int code) => http.Response('', code);
http.Response json(Object body, [int code = 200]) =>
    http.Response(jsonEncode(body), code, headers: {'content-type': 'application/json'});

/// 다 받아 주는 서버. 로그인은 세션을 주고, 탈퇴는 204, 받기는 빈 목록, 나머지는 201.
Future<http.Response> accepting(http.Request r) async => switch ((r.method, r.url.path)) {
      (_, '/auth/v1/token') => json(session('new')),
      (_, '/functions/v1/delete-account') => status(204),
      ('GET', _) => json([]),
      _ => status(201),
    };

Future<http.Response> down(http.Request r) async => throw http.ClientException('down');

/// Intro는 넘기고 다음 Asking까지 간다.
Asking askNext(Session s) {
  do {
    s.next();
  } while (s.phase.value is Intro);
  return s.phase.value as Asking;
}

void main() {
  late Directory dir;
  late File file;
  late List<String> log; // 서버 요청과 Google 콜백을 부른 순서
  late List<Object> reported; // ADR 0007 §3: non-fatal로 보낸 오류
  late List<(String, Map<String, Object>)> logged; // ADR 0006 §2: 분석 이벤트
  late List<({int attempts, int days})> rowsAtLog; // 이벤트를 받은 순간의 로컬 행 수(logged와 같은 순서)
  setUp(() {
    dir = Directory.systemTemp.createTempSync('live_backend_test');
    file = File('${dir.path}/records.json');
    log = [];
    reported = [];
    logged = [];
    rowsAtLog = [];
    today = DateTime(2026, 10, 27, 9);
  });
  tearDown(() => dir.deleteSync(recursive: true));

  int rowCount(String table) =>
      file.existsSync() ? ((jsonDecode(file.readAsStringSync()) as Map)[table] as List? ?? []).length : 0;

  LiveBackend make(SupabaseClient client, [Content? c, Future<String?> Function()? googleIdToken]) {
    final store = Store(file, client);
    return LiveBackend(
      content: c ?? content,
      store: store,
      client: client,
      auth: Auth(client,
          clearLocal: store.clear,
          googleIdToken: googleIdToken ?? () async => 'gid',
          googleSignOut: () async => log.add('google.signOut'),
          googleDisconnect: () async => log.add('google.disconnect'),
          report: (e, _) => reported.add(e)),
      now: () => today,
      report: (e, _) => reported.add(e),
      log: (n, p) {
        logged.add((n, p));
        rowsAtLog.add((attempts: rowCount('attempts'), days: rowCount('day_completions')));
      },
    );
  }

  /// 레코드 안의 Map은 ==로 비교되지 않아 목록으로 바꿔 비교한다.
  List<List<Object>> events() => [for (final (n, p) in logged) [n, p]];

  /// 게스트. 닿지 않는 주소라 요청을 보내면 예외가 난다.
  LiveBackend guest() => make(SupabaseClient('http://127.0.0.1:1', 'x'));

  SupabaseClient mock(Future<http.Response> Function(http.Request r) server) => SupabaseClient(
        'http://sb.test',
        'anon',
        authOptions: const AuthClientOptions(autoRefreshToken: false),
        httpClient: MockClient((r) async {
          log.add('${r.method} ${r.url.path}');
          final res = await server(r); // postgrest는 응답의 request를 읽는다
          return http.Response.bytes(res.bodyBytes, res.statusCode, headers: res.headers, request: r);
        }),
      );

  /// 로그인한 상태로 시작한다. 그 뒤의 요청은 [server]가 받는다.
  Future<LiveBackend> signedIn(Future<http.Response> Function(http.Request r) server) async {
    final client = mock(server);
    await client.auth.recoverSession(jsonEncode(session('old')));
    log.clear();
    return make(client);
  }

  List<Map<String, dynamic>> rows(String table) =>
      ((jsonDecode(file.readAsStringSync()) as Map)[table] as List? ?? []).cast<Map<String, dynamic>>();

  /// 하루를 끝까지 정답으로 풀고 마지막 next까지 부른다.
  Finished finishDay(Session s) {
    do {
      askNext(s);
      s.answer(right);
    } while (!(s.phase.value as Answered).last);
    s.next();
    return s.phase.value as Finished;
  }

  test('answer() 한 번에 로컬 attempts에 synced=false 행이 하나 생기고 home.xp가 10 는다', () {
    final b = guest();
    final before = b.home.value.xp;
    final s = b.startDaily();
    askNext(s);
    s.answer(right);

    expect(rows('attempts'), hasLength(1));
    expect(rows('attempts').single['synced'], false);
    expect(b.home.value.xp, before + 10);
  });

  test('처음 홈은 기록에서 계산한다: day-01, 연속 0, XP 0, 영역 6개', () {
    final b = guest();
    final h = b.home.value;
    expect([h.today!.number, h.today!.title, h.today!.doneToday, h.streak, h.xp, h.level], [1, 'day-01 제목', false, 0, 0, 1]);
    expect(h.today!.scenes.map((s) => s.title), ['장면1', '장면2', '장면3']);
    expect(b.stats.value.map((s) => s.area), ['연애', '친구', '어른·가족', '직장', '공공장소', '메시지']);
    expect(b.account.value, isNull);
  });

  test('틀린 문제는 맞힐 때까지 맨 뒤에 retry로 다시 오고, 마지막 next에서 하루 완료를 쓰고 연속 학습일과 doneToday가 갱신된다', () {
    final b = guest();
    final s = b.startDaily();
    expect(s.phase.value, isA<Intro>());

    final first = askNext(s);
    s.answer(wrong);
    expect((s.phase.value as Answered).e.grade, Grade.avoid);
    for (var i = 0; i < 5; i++) {
      expect(askNext(s).retry, isFalse);
      s.answer(right);
    }
    var again = askNext(s);
    expect([again.retry, again.q], [true, same(first.q)]);
    s.answer(wrong);
    again = askNext(s);
    expect([again.retry, again.q], [true, same(first.q)]);
    s.answer(right);
    expect((s.phase.value as Answered).last, isTrue);
    expect(rows('day_completions'), isEmpty);

    s.next();
    final f = s.phase.value as Finished;
    expect([f.xpGained, f.firstTry, f.total, f.streak], [60, 5, 6, 1]);
    expect(f.retryTomorrow, ['매너1']);
    expect(rows('day_completions'), hasLength(1));
    expect(rows('day_completions').single['day_id'], 'day-01');
    final h = b.home.value;
    expect([h.streak, h.today!.doneToday, h.today!.nextTitle, h.xp], [1, true, 'day-02 제목', 60]);
  });

  test('choice에서 ok 보기를 고르면 best가 아니므로 같은 문제가 맨 뒤에 retry로 다시 온다', () {
    final b = make(SupabaseClient('http://127.0.0.1:1', 'x'), fixture('choice'));
    final s = b.startDaily();
    final first = askNext(s);
    s.answer(const PickOption('1'));
    expect((s.phase.value as Answered).e.grade, Grade.ok);
    expect((s.phase.value as Answered).last, isFalse);
    for (var i = 0; i < 5; i++) {
      askNext(s);
      s.answer(const PickOption('0'));
    }
    final again = askNext(s);
    expect([again.retry, again.q], [true, same(first.q)]);
  });

  test('콤보는 best마다 1 늘고 best가 아니면 0이다. bestCombo는 세트의 최고값, progress는 지난 문제 수 / 큐 길이다', () {
    final b = guest();
    final s = b.startDaily();
    final progress = <double>[];
    final combos = <int>[];
    s.phase.addListener(() {
      final p = s.phase.value;
      if (p is Asking || p is Answered) progress.add(p.progress);
      if (p is Answered) combos.add(p.e.combo);
    });
    for (final a in [right, wrong, right]) {
      askNext(s);
      s.answer(a);
    }
    expect(combos, [1, 0, 1]);
    // 큐가 6에서 다시 풀기로 7이 된다. 없었다면 2/6이었을 진행이 2/7로 줄어든다(가짜와 같은 규칙).
    expect(progress, [0, 1 / 6, 1 / 6, 2 / 7, 2 / 7, 3 / 7]);

    do {
      askNext(s);
      s.answer(right);
    } while (!(s.phase.value as Answered).last);
    expect(progress.last, 1);
    expect(combos, [1, 0, 1, 2, 3, 4, 5]);
    s.next();
    expect((s.phase.value as Finished).bestCombo, 5);
  });

  test('장면이 바뀌면 nextScene과 Intro가 나온다. 다시 풀기 문제의 nextScene은 null이고 그 뒤에 Intro가 없다', () {
    final b = guest();
    final s = b.startDaily();
    askNext(s);
    s.answer(wrong); // 장면 1의 첫 문제
    s.next();
    s.answer(right); // 장면 1의 마지막 문제
    expect((s.phase.value as Answered).nextScene?.title, '장면2');
    s.next();
    expect((s.phase.value as Intro).scene.title, '장면2');
    s.next();
    s.answer(wrong); // 장면 2의 첫 문제
    for (var i = 0; i < 3; i++) {
      askNext(s);
      s.answer(right);
    }
    expect((s.phase.value as Answered).nextScene, isNull); // 다음은 다시 풀기
    expect(askNext(s).retry, isTrue);
    s.answer(right); // 장면 1 문제의 다시 풀기. 다음은 장면 2 문제의 다시 풀기
    expect((s.phase.value as Answered).nextScene, isNull);
    s.next();
    expect(s.phase.value, isA<Asking>().having((a) => a.retry, 'retry', true));
  });

  group('세트 끝 sync', () {
    test('quit() 뒤 sync를 불러 답한 기록을 올린다', () async {
      final b = await signedIn(accepting);
      final s = b.startDaily();
      askNext(s);
      s.answer(right);
      s.quit();
      await pumpEventQueue();
      expect(log, contains('POST /rest/v1/attempts'));
    });

    test('Finished로 갈 때 sync를 불러 기록과 하루 완료를 올린다', () async {
      final b = await signedIn(accepting);
      finishDay(b.startDaily());
      await pumpEventQueue();
      expect(log, containsAllInOrder(['POST /rest/v1/attempts', 'POST /rest/v1/day_completions']));
    });
  });

  group('네트워크 없음', () {
    test('게스트: 풀이, 하루 완료, 홈 값이 로컬만으로 돈다', () async {
      final b = guest();
      final f = finishDay(b.startDaily());
      await b.sync();

      expect([f.xpGained, f.streak], [60, 1]);
      expect([b.home.value.xp, b.home.value.streak, b.home.value.today!.doneToday], [60, 1, true]);
      expect(b.stats.value.first.value, greaterThan(0)); // 연애
      expect([rows('attempts').length, rows('day_completions').length], [6, 1]);
    });

    test('로그인 상태에서 서버에 닿지 않으면 기록은 synced=false로 남고 online이 거짓이 된다. 홈 값은 그대로다', () async {
      final b = await signedIn(down);
      finishDay(b.startDaily());
      await b.sync();

      expect(b.online.value, isFalse);
      expect(rows('attempts').every((r) => r['synced'] == false), isTrue);
      expect([b.home.value.xp, b.home.value.streak], [60, 1]);
      expect(b.account.value?.email, 'me@example.com'); // 로그인은 그대로
    });
  });

  group('같은 요청 두 번', () {
    test('answer는 Asking이 아니면 무시하고, 로컬 기록을 쓴 뒤에 Answered를 낸다', () {
      final b = guest();
      final s = b.startDaily();
      s.answer(right); // Intro
      expect(file.existsSync(), isFalse);

      int? seen;
      s.phase.addListener(() {
        if (s.phase.value is Answered) seen = rows('attempts').length;
      });
      askNext(s);
      s.answer(right);
      s.answer(right);
      s.answer(wrong);
      expect(seen, 1);
      expect(rows('attempts'), hasLength(1));
      expect(b.home.value.xp, 10);
    });

    test('next는 Finished에서 무시한다. 하루 완료는 한 번만 쓰인다', () {
      final b = guest();
      final s = b.startDaily();
      final f = finishDay(s);
      s.next();
      s.next();
      expect(s.phase.value, same(f));
      expect(rows('day_completions'), hasLength(1));
      expect(b.home.value.streak, 1);
    });
  });

  test('기기 두 대: pull로 받은 다른 기기 기록으로 home과 stats를 다시 계산해 내보낸다', () async {
    final b = await signedIn((r) async => switch ((r.method, r.url.path)) {
          ('GET', '/rest/v1/attempts') => json([
              {'id': '00000000-0000-4000-8000-000000000001', 'user_id': 'u1', 'scenario_id': 'X-1a', 'grade': 'best', 'solved_on': '2026-10-27', 'created_at': '2026-10-27T00:00:00Z'},
            ]),
          ('GET', '/rest/v1/day_completions') => json([
              {'id': '00000000-0000-4000-8000-000000000002', 'user_id': 'u1', 'day_id': 'day-01', 'completed_on': '2026-10-27', 'created_at': '2026-10-27T00:00:00Z'},
            ]),
          _ => status(201),
        });
    var homes = 0, stats = 0;
    b.home.addListener(() => homes++);
    b.stats.addListener(() => stats++);
    expect(b.home.value.xp, 0);

    await b.sync();
    expect([homes, stats], [1, 1]);
    final h = b.home.value;
    expect([h.xp, h.streak, h.today!.doneToday], [10, 1, true]);
    expect(b.stats.value.first.value, 10); // 연애: 매너 1이 2칸
    expect(b.online.value, isTrue);
  });

  group('로그아웃', () {
    test('못 올린 기록이 있으면 WouldLose(N)이고 아무것도 지우지 않는다. discardUnsynced면 지우고 로그아웃한다', () async {
      final b = await signedIn(down);
      final s = b.startDaily();
      askNext(s);
      s.answer(right);

      final r = await b.signOut();
      expect(r, isA<WouldLose>().having((w) => w.count, 'count', 1));
      expect(b.account.value, isNotNull);
      expect(rows('attempts'), hasLength(1));

      expect(await b.signOut(discardUnsynced: true), isA<SignedOut>());
      expect(file.existsSync(), isFalse);
      expect(b.account.value, isNull);
      expect(b.home.value.xp, 0);
      expect(log.last, 'google.signOut');
    });

    test('sync로 다 올리면 확인 없이 sync → Store.clear(signOut local) → Google 로그아웃 순서다', () async {
      final b = await signedIn(accepting);
      final s = b.startDaily();
      askNext(s);
      s.answer(right);

      expect(await b.signOut(), isA<SignedOut>());
      expect(log, [
        'POST /rest/v1/attempts',
        'GET /rest/v1/attempts',
        'GET /rest/v1/day_completions',
        'POST /auth/v1/logout',
        'google.signOut',
      ]);
      expect(file.existsSync(), isFalse);
      expect(b.account.value, isNull);
    });
  });

  group('탈퇴', () {
    test('204면 ok, 로컬이 지워지고 account가 null이다. 탈퇴 중에는 sync를 멈춘다', () async {
      final b = await signedIn(accepting);
      final s = b.startDaily();
      askNext(s);
      s.answer(right);

      final f = b.deleteAccount();
      await b.sync(); // 탈퇴 중: 요청을 보내지 않는다
      expect(await f, DeleteResult.ok);
      expect(log, ['POST /functions/v1/delete-account', 'POST /auth/v1/logout', 'google.disconnect']);
      expect(b.account.value, isNull);
      expect(file.existsSync(), isFalse);
      expect(b.home.value.xp, 0);
    });

    test('서버에 닿지 않으면 offline이고 기록과 로그인이 그대로이며 online이 거짓이 된다', () async {
      final b = await signedIn(down);
      final s = b.startDaily();
      askNext(s);
      s.answer(right);

      expect(await b.deleteAccount(), DeleteResult.offline);
      expect(b.online.value, isFalse);
      expect(b.account.value, isNotNull);
      expect(rows('attempts'), hasLength(1));
    });
  });

  group('로그인', () {
    test('성공하면 account를 채우고 sync로 게스트 기록을 올린다', () async {
      final b = make(mock(accepting));
      final s = b.startDaily();
      askNext(s);
      s.answer(right);

      expect(await b.signIn(), SignInResult.ok);
      expect([b.account.value?.name, b.account.value?.email], ['김매너', 'me@example.com']);
      expect(log, containsAllInOrder(['POST /auth/v1/token', 'POST /rest/v1/attempts']));
      expect(rows('attempts').single['synced'], isTrue);
      expect(b.home.value.xp, 10);
    });

    test('서버에 닿지 않으면 offline이고 게스트로 남는다. 게스트의 online은 그대로 true다', () async {
      final b = make(mock(down));
      expect(await b.signIn(), SignInResult.offline);
      expect(b.account.value, isNull);
      expect(b.online.value, isTrue); // 게스트는 항상 true. 결과 offline이 이미 알린다
    });
  });

  group('online: 게스트는 항상 true, 로그인하면 마지막 Supabase 요청이 서버에 닿았는가', () {
    test('로그인한 사용자: sync가 닿지 않으면 false, 다음 sync가 닿으면 true', () async {
      var up = false;
      final b = await signedIn((r) => up ? accepting(r) : down(r));
      final s = b.startDaily();
      askNext(s);
      s.answer(right);

      await b.sync();
      expect(b.online.value, isFalse);
      up = true;
      await b.sync();
      expect(b.online.value, isTrue);
    });

    test('연결 오류가 아닌 예외(코드 버그)는 Zone으로 넘기지 않고 report로 보낸다. 오프라인으로 보지 않는다(ADR 0007 §3)', () async {
      final b = await signedIn((r) async => r.method == 'POST' ? throw StateError('bug') : accepting(r));
      final s = b.startDaily();
      askNext(s);
      s.answer(right);

      final errors = <Object>[];
      await runZonedGuarded(b.sync, (e, _) => errors.add(e));
      expect(errors, isEmpty);
      expect(reported, [isA<StateError>()]);
      expect(b.online.value, isTrue);
      expect(rows('attempts').single['synced'], isFalse);
    });

    test('연결 오류는 Zone으로 넘기지 않는다', () async {
      final b = await signedIn(down);
      final s = b.startDaily();
      askNext(s);
      s.answer(right);

      final errors = <Object>[];
      await runZonedGuarded(b.sync, (e, _) => errors.add(e));
      expect(errors, isEmpty);
      expect(b.online.value, isFalse);
    });

    test('Postgrest 5xx 응답은 서버에 닿은 것이다', () async {
      final b = await signedIn((r) async => status(503));
      final s = b.startDaily();
      askNext(s);
      s.answer(right);

      await b.sync();
      expect(log, contains('POST /rest/v1/attempts'));
      expect(b.online.value, isTrue);
    });

    test('세션 갱신이 5xx(AuthRetryableFetchException, statusCode 있음)여도 닿은 것이다. 로그인은 그대로다', () async {
      String b64(Object o) => base64Url.encode(utf8.encode(jsonEncode(o))).replaceAll('=', '');
      final exp = DateTime.now().millisecondsSinceEpoch ~/ 1000 - 10;
      final expired = '${b64({'alg': 'none'})}.${b64({'exp': exp, 'sub': 'u1'})}.x';
      var refreshes = 0;
      final client = mock((r) async => switch (r.url.path) {
            '/auth/v1/token' => refreshes++ == 0 ? json(session(expired)) : status(503),
            _ => status(201),
          });
      await client.auth.setSession('r-old');
      final b = make(client);
      final s = b.startDaily();
      askNext(s);
      s.answer(right);

      await b.sync();
      expect(b.online.value, isTrue);
      expect(b.account.value, isNotNull);
      expect(rows('attempts'), hasLength(1));
    });

    test('로그아웃해서 게스트가 되면 online이 true로 돌아온다', () async {
      final b = await signedIn(down);
      final s = b.startDaily();
      askNext(s);
      s.answer(right);
      await b.sync();
      expect(b.online.value, isFalse);

      expect(await b.signOut(discardUnsynced: true), isA<SignedOut>());
      expect(b.online.value, isTrue);
    });

    test('탈퇴해서 게스트가 되면 online이 true로 돌아온다', () async {
      var up = false;
      final b = await signedIn((r) => up ? accepting(r) : down(r));
      final s = b.startDaily();
      askNext(s);
      s.answer(right);
      await b.sync();
      expect(b.online.value, isFalse);

      up = true;
      expect(await b.deleteAccount(), DeleteResult.ok);
      expect(b.online.value, isTrue);
    });
  });

  group('앱이 앞으로 올 때', () {
    test('sync를 불러 기록을 올린다', () async {
      final b = await signedIn(accepting);
      final s = b.startDaily();
      askNext(s);
      s.answer(right);

      b.onResume();
      await pumpEventQueue();
      expect(log, contains('POST /rest/v1/attempts'));
    });

    test('자정을 넘겼으면 홈을 다시 계산한다(게스트는 요청 없이)', () async {
      final b = guest();
      finishDay(b.startDaily());
      await pumpEventQueue(); // 세트 끝 sync를 먼저 끝낸다
      expect(b.home.value.today!.doneToday, isTrue);

      today = DateTime(2026, 10, 28, 9);
      b.onResume();
      await pumpEventQueue();
      expect([b.home.value.today!.doneToday, b.home.value.today!.number], [false, 2]);
      expect(log, isEmpty);
    });
  });

  group('ADR 0001 §5-5', () {
    test('세션이 없는데 synced=true 행이 있으면(시작 중 갱신 실패로 처음부터 게스트) sync에서 로컬을 지우고 로그아웃한다', () async {
      file.writeAsStringSync(jsonEncode({
        'attempts': [
          {'id': '00000000-0000-4000-8000-000000000001', 'scenario_id': 'X-1a', 'grade': 'best', 'solved_on': '2026-10-27', 'synced': true},
        ],
      }));
      final b = guest();
      expect([b.account.value, b.home.value.xp], [null, 10]);

      await b.sync();
      expect(file.existsSync(), isFalse);
      expect(b.home.value.xp, 0);
      expect(log.last, 'google.signOut');
    });

    test('게스트 기록(synced=false)만 있으면 sync해도 그대로다', () async {
      final b = guest();
      final s = b.startDaily();
      askNext(s);
      s.answer(right);

      await b.sync();
      expect(rows('attempts'), hasLength(1));
      expect(log, isEmpty);
    });

    test('push가 23503(다른 기기에서 탈퇴)이면 로컬을 지우고 로그아웃한다', () async {
      final b = await signedIn((r) async => r.url.path == '/rest/v1/attempts'
          ? json({'code': '23503', 'message': 'insert or update violates foreign key constraint'}, 409)
          : status(204));
      final s = b.startDaily();
      askNext(s);
      s.answer(right);

      await b.sync();
      expect(file.existsSync(), isFalse);
      expect(b.account.value, isNull);
      expect(b.home.value.xp, 0);
      expect(log.last, 'google.signOut');
    });

    test('토큰이 만료돼 세션 갱신이 거절되면 로컬을 지우고 로그아웃한다', () async {
      String b64(Object o) => base64Url.encode(utf8.encode(jsonEncode(o))).replaceAll('=', '');
      final exp = DateTime.now().millisecondsSinceEpoch ~/ 1000 - 10;
      final expired = '${b64({'alg': 'none'})}.${b64({'exp': exp, 'sub': 'u1'})}.x';
      var refreshes = 0;
      final client = mock((r) async => switch (r.url.path) {
            // 첫 갱신은 setSession이 쓴다. 만료된 토큰을 준다. 그 뒤 갱신은 거절한다.
            '/auth/v1/token' => refreshes++ == 0
                ? json(session(expired))
                : json({'code': 'refresh_token_not_found', 'msg': 'Invalid Refresh Token'}, 400),
            _ => status(201),
          });
      await client.auth.setSession('r-old');
      file.writeAsStringSync(jsonEncode({
        'attempts': [
          {'id': '00000000-0000-4000-8000-000000000001', 'scenario_id': 'X-1a', 'grade': 'best', 'solved_on': '2026-10-26', 'synced': true},
        ],
      })); // 전에 올린 기록이 있는 사용자
      final b = make(client);
      expect(b.account.value, isNotNull);
      final s = b.startDaily();
      askNext(s);
      s.answer(right);

      await b.sync();
      expect(file.existsSync(), isFalse);
      expect(b.account.value, isNull);
      expect(log, isNot(contains('POST /rest/v1/attempts'))); // 요청 전에 갱신이 실패했다
      expect(reported, [isA<AuthException>(), isA<StateError>()]); // ADR 0007 §3: 서버가 응답한 오류 + 세션 없음과 synced 행
    });

    test('한 번도 올리지 못한 사용자의 세션 갱신이 거절되면 기록은 남기고 게스트가 된다(account null, online true)', () async {
      String b64(Object o) => base64Url.encode(utf8.encode(jsonEncode(o))).replaceAll('=', '');
      final exp = DateTime.now().millisecondsSinceEpoch ~/ 1000 - 10;
      final expired = '${b64({'alg': 'none'})}.${b64({'exp': exp, 'sub': 'u1'})}.x';
      var refreshes = 0;
      final client = mock((r) async => switch (r.url.path) {
            '/auth/v1/token' => refreshes++ == 0
                ? json(session(expired))
                : json({'code': 'refresh_token_not_found', 'msg': 'Invalid Refresh Token'}, 400),
            _ => status(201),
          });
      await client.auth.setSession('r-old');
      final b = make(client);
      expect(b.account.value, isNotNull);
      final s = b.startDaily();
      askNext(s);
      s.answer(right);

      await b.sync();
      expect(rows('attempts'), hasLength(1));
      expect(b.account.value, isNull);
      expect(b.online.value, isTrue);
      expect(reported, [isA<AuthException>()]); // ADR 0007 §3: 서버가 응답한 오류. synced 행이 없어 StateError는 없다
    });
  });

  group('분석 이벤트 (ADR 0006 작업 4)', () {
    test('startDaily()는 daily_start 하나를 보낸다', () {
      guest().startDaily();
      expect(events(), [
        ['daily_start', {'day_id': 'day-01'}],
      ]);
    });

    test('첫 문제에 best를 두 번 탭하면 answer 하나뿐이다. 로컬 기록을 쓴 뒤에 보낸다', () {
      final s = guest().startDaily();
      logged.clear();
      askNext(s);
      s.answer(right);
      s.answer(right);
      expect(events(), [
        ['answer', {'scenario_id': rows('attempts').single['scenario_id'], 'grade': 'best', 'retry': 0}],
      ]);
    });

    test('다시 풀기 문제의 answer는 retry가 1이고 grade는 채점 결과다', () {
      final s = guest().startDaily();
      askNext(s);
      s.answer(wrong);
      for (var i = 0; i < 5; i++) {
        askNext(s);
        s.answer(right);
      }
      askNext(s);
      s.answer(right);
      final answers = logged.where((e) => e.$1 == 'answer').map((e) => e.$2).toList();
      expect(answers.first, containsPair('grade', 'avoid'));
      expect(answers.first, containsPair('retry', 0));
      expect(answers.last, {'scenario_id': answers.first['scenario_id'], 'grade': 'best', 'retry': 1});
    });

    test('둘째 장면에서 quit()하면 daily_quit의 scene이 2다', () {
      final s = guest().startDaily();
      askNext(s);
      s.answer(right);
      askNext(s);
      s.answer(right); // 장면 1의 마지막 문제
      askNext(s); // 장면 2의 Intro를 지나 첫 문제
      logged.clear();
      s.quit();
      expect(events(), [
        ['daily_quit', {'day_id': 'day-01', 'scene': 2}],
      ]);
    });

    test('장면 소개(Intro)에서 quit()하면 그 장면 번호다', () {
      final s = guest().startDaily();
      for (var i = 0; i < 2; i++) {
        askNext(s);
        s.answer(right);
      }
      s.next();
      expect((s.phase.value as Intro).scene.title, '장면2');
      logged.clear();
      s.quit();
      expect(events(), [
        ['daily_quit', {'day_id': 'day-01', 'scene': 2}],
      ]);
    });

    test('세트를 끝까지 풀면 daily_complete 하나다. Finished 뒤 next는 다시 보내지 않는다. 모든 값은 String이나 int다', () {
      final s = guest().startDaily();
      finishDay(s);
      s.next();
      expect(events().where((e) => e[0] == 'daily_complete'), [
        ['daily_complete', {'day_id': 'day-01'}],
      ]);
      expect(logged.map((e) => e.$1), ['daily_start', ...List.filled(6, 'answer'), 'daily_complete']);
      for (final (_, p) in logged) {
        expect(p.values, everyElement(anyOf(isA<String>(), isA<int>())));
      }
    });

    test('answer와 daily_complete는 로컬 기록을 쓴 뒤에 보낸다', () {
      finishDay(guest().startDaily());
      var answers = 0;
      for (final (i, (n, _)) in logged.indexed) {
        final rows = rowsAtLog[i];
        if (n == 'answer') expect(rows.attempts, ++answers, reason: '$answers번째 answer를 보낼 때 attempts 행');
        if (n == 'daily_complete') expect(rows.days, 1, reason: 'daily_complete를 보낼 때 day_completions 행');
      }
      expect(answers, 6);
    });

    test('Finished 뒤 quit()은 daily_quit을 보내지 않는다', () {
      final s = guest().startDaily();
      finishDay(s);
      logged.clear();
      s.quit();
      s.quit();
      expect(logged, isEmpty);
    });

    test('오늘 이미 마쳐 startDaily()가 StateError를 던지면 daily_start를 보내지 않는다', () {
      final b = guest();
      finishDay(b.startDaily());
      logged.clear();
      expect(b.startDaily, throwsStateError);
      expect(logged, isEmpty);
    });

    test('signIn()이 cancelled면 login이 없다', () async {
      final b = make(mock(accepting), null,
          () async => throw const GoogleSignInException(code: GoogleSignInExceptionCode.canceled));
      expect(await b.signIn(), SignInResult.cancelled);
      expect(logged, isEmpty);
    });

    test('signIn()이 ok면 login이 {method: google}로 하나다', () async {
      final b = make(mock(accepting));
      expect(await b.signIn(), SignInResult.ok);
      expect(events(), [
        ['login', {'method': 'google'}],
      ]);
    });
  });

  group('sync의 non-fatal 보고 (ADR 0007 §3)', () {
    Future<LiveBackend> answered(Future<http.Response> Function(http.Request r) server) async {
      final b = await signedIn(server);
      final s = b.startDaily();
      askNext(s);
      s.answer(right);
      return b;
    }

    test('서버가 42501(RLS 거절)이면 하나를 보내고 online은 참이다', () async {
      final b = await answered((r) async => r.method == 'POST' ? json({'code': '42501', 'message': 'rls'}, 403) : accepting(r));
      await b.sync();
      expect(reported, [isA<PostgrestException>().having((e) => e.code, 'code', '42501')]);
      expect(b.online.value, isTrue);
    });

    test('ClientException(전송 오류)이면 보내지 않고 online은 거짓이다', () async {
      final b = await answered(down);
      await b.sync();
      expect(reported, isEmpty);
      expect(b.online.value, isFalse);
    });

    test('23503이면 하나를 보내고 로컬이 지워진다', () async {
      final b = await answered((r) async => r.url.path == '/rest/v1/attempts'
          ? json({'code': '23503', 'message': 'insert or update violates foreign key constraint'}, 409)
          : status(204));
      await b.sync();
      expect(reported, [isA<PostgrestException>().having((e) => e.code, 'code', '23503')]);
      expect(file.existsSync(), isFalse);
    });

    test('저장소가 TypeError를 던지면 하나를 보내고 online은 참이다', () async {
      final b = await answered((r) async => r.method == 'POST' ? throw TypeError() : accepting(r));
      await b.sync();
      expect(reported, [isA<TypeError>()]);
      expect(b.online.value, isTrue);
    });

    test('세션이 없는데 synced=true 행이 있으면 StateError 하나를 보낸다', () async {
      file.writeAsStringSync(jsonEncode({
        'attempts': [
          {'id': '00000000-0000-4000-8000-000000000001', 'scenario_id': 'X-1a', 'grade': 'best', 'solved_on': '2026-10-27', 'synced': true},
        ],
      }));
      final b = guest();
      await b.sync();
      expect(reported, [isA<StateError>()]);
      expect(file.existsSync(), isFalse);
    });
  });
}

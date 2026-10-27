// ADR 0001 §5, ADR 0002 작업 10: 로그인, 로그아웃, 탈퇴 순서. Supabase는 가짜 HTTP, Google은 가짜 함수.
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mannerfit/auth/auth.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const _user = {'id': 'u1', 'aud': 'authenticated', 'created_at': '2026-10-27T00:00:00Z', 'app_metadata': {}, 'user_metadata': {}};
Map<String, Object> _session(String token) =>
    {'access_token': token, 'token_type': 'bearer', 'expires_in': 3600, 'refresh_token': 'r-$token', 'user': _user};

const _delete = 'POST /functions/v1/delete-account';
const _refresh = 'POST /auth/v1/token?grant_type=refresh_token';
const _logout = 'POST /auth/v1/logout?scope=local';

/// 가짜 서버와 Google. 서버 요청과 콜백을 부른 순서대로 [log]에 남긴다.
class _Rig {
  _Rig(Future<http.Response> Function(http.Request r) server) {
    client = SupabaseClient(
      'http://sb.test',
      'anon',
      authOptions: const AuthClientOptions(autoRefreshToken: false),
      httpClient: MockClient((r) {
        log.add('${r.method} ${r.url.path}${r.url.hasQuery ? '?${r.url.query}' : ''}');
        return server(r);
      }),
    );
    client.auth.onAuthStateChange.listen((s) {
      if (s.event == AuthChangeEvent.signedOut) signedOut++;
    }, onError: (_) {});
    // live/의 Store.clear처럼 로컬을 지우고 signOut(local)한다.
    auth = Auth(
      client,
      clearLocal: () async {
        log.add('clearLocal');
        await client.auth.signOut(scope: SignOutScope.local);
      },
      googleIdToken: () async => googleToken(),
      googleSignOut: () async => log.add('google.signOut'),
      googleDisconnect: () async => log.add('google.disconnect'),
    );
  }

  final log = <String>[];
  var signedOut = 0; // signedOut 이벤트 수
  late final SupabaseClient client;
  late final Auth auth;
  Future<String?> Function() googleToken = () async => 'gid';

  Future<void> signIn() async {
    await client.auth.recoverSession(jsonEncode(_session('old')));
    log.clear();
  }
}

/// 이미 만료된 access token. 요청 전에 gotrue가 갱신하고, 갱신이 실패하면 요청을 보내지 않는다.
String _expiredJwt() {
  String b64(Object o) => base64Url.encode(utf8.encode(jsonEncode(o))).replaceAll('=', '');
  final exp = DateTime.now().millisecondsSinceEpoch ~/ 1000 - 10;
  return '${b64({'alg': 'none'})}.${b64({'exp': exp, 'sub': 'u1'})}.x';
}

/// 만료된 세션으로 로그인한 rig. 그 뒤의 토큰 갱신 응답은 [refresh], 나머지는 204.
Future<_Rig> _expiredRig(Future<http.Response> Function() refresh) async {
  var refreshes = 0;
  final rig = _Rig((r) async => switch (r.url.path) {
        // 첫 갱신은 setSession이 쓴다. 만료된 토큰을 준다.
        '/auth/v1/token' => refreshes++ == 0 ? _json(_session(_expiredJwt())) : await refresh(),
        _ => _status(204),
      });
  await rig.client.auth.setSession('r-old');
  rig.log.clear();
  return rig;
}

final _rejected = _json({'code': 'refresh_token_not_found', 'msg': 'Invalid Refresh Token'}, 400);

http.Response _status(int code) => http.Response('', code);
http.Response _json(Object body, [int code = 200]) =>
    http.Response(jsonEncode(body), code, headers: {'content-type': 'application/json'});

void main() {
  group('탈퇴', () {
    test('delete-account가 401이고 세션 갱신도 거절되면 로컬을 지우고 로그아웃하되 결과는 failed(ADR 0001 §5-4)', () async {
      final rig = _Rig((r) async => r.url.path == '/auth/v1/token' ? _rejected : _status(401));
      await rig.signIn();

      expect(await rig.auth.deleteAccount(), DeleteStatus.failed);
      expect(rig.log, [_delete, _refresh, 'clearLocal', 'google.disconnect']);
      expect(rig.client.auth.currentUser, isNull);
    });

    test('세션 없이 401이면(AuthSessionMissingException) 위와 같다', () async {
      final rig = _Rig((r) async => _status(401));

      expect(await rig.auth.deleteAccount(), DeleteStatus.failed);
      expect(rig.log, [_delete, 'clearLocal', 'google.disconnect']);
    });

    test('요청 전 토큰이 만료돼 갱신이 거절되면 위와 같다', () async {
      final rig = await _expiredRig(() async => _rejected);

      expect(await rig.auth.deleteAccount(), DeleteStatus.failed);
      expect(rig.log, [_refresh, 'clearLocal', 'google.disconnect']); // delete-account 요청은 나가지 않는다
      expect(rig.client.auth.currentUser, isNull);
    });

    for (final (name, refresh, want) in [
      ('네트워크 오류', () async => throw http.ClientException('down'), DeleteStatus.offline),
      ('503', () async => _status(503), DeleteStatus.failed),
    ]) {
      test('요청 전 토큰이 만료돼 갱신이 $name이면 로컬을 지우지 않고 ${want.name}', () async {
        final rig = await _expiredRig(refresh);

        expect(await rig.auth.deleteAccount(), want);
        expect(rig.log, isNot(contains('clearLocal')));
        expect(rig.log, isNot(contains('google.disconnect')));
        expect(rig.client.auth.currentUser, isNotNull);
      });
    }

    test('204면 차례로 로컬 지우기(signOut(local) 포함) → Google disconnect. signOut은 한 번만', () async {
      final rig = _Rig((r) async => _status(204));
      await rig.signIn();

      expect(await rig.auth.deleteAccount(), DeleteStatus.ok);
      expect(rig.log, [_delete, 'clearLocal', _logout, 'google.disconnect']);
      expect(rig.client.auth.currentUser, isNull);
      await Future<void>.delayed(Duration.zero); // 이벤트 전달
      expect(rig.signedOut, 1);
    });

    test('401 뒤 세션 갱신에 성공하면 새 토큰으로 다시 불러 204면 같은 순서로 정리한다', () async {
      final rig = _Rig((r) async => switch (r.url.path) {
            '/auth/v1/token' => _json(_session('new')),
            '/functions/v1/delete-account' => _status(r.headers['Authorization'] == 'Bearer new' ? 204 : 401),
            _ => _status(204),
          });
      await rig.signIn();

      expect(await rig.auth.deleteAccount(), DeleteStatus.ok);
      expect(rig.log, [_delete, _refresh, _delete, 'clearLocal', _logout, 'google.disconnect']);
      expect(rig.client.auth.currentUser, isNull);
    });

    for (final (name, server, want) in [
      ('500', (http.Request r) async => _status(500), DeleteStatus.failed),
      ('네트워크 오류', (http.Request r) async => throw http.ClientException('down'), DeleteStatus.offline),
      ('401 뒤 갱신이 네트워크 오류',
          (http.Request r) async => r.url.path == '/auth/v1/token' ? throw http.ClientException('down') : _status(401),
          DeleteStatus.offline),
      ('401 뒤 갱신에 성공했는데 다시 401',
          (http.Request r) async => r.url.path == '/auth/v1/token' ? _json(_session('new')) : _status(401),
          DeleteStatus.failed),
    ]) {
      test('$name이면 로컬을 지우지 않고 ${want.name}', () async {
        final rig = _Rig(server);
        await rig.signIn();

        expect(await rig.auth.deleteAccount(), want);
        expect(rig.log, isNot(contains('clearLocal')));
        expect(rig.log, isNot(contains('google.disconnect')));
        expect(rig.client.auth.currentUser, isNotNull);
      });
    }
  });

  group('로그아웃', () {
    test('Google signOut만 한다. Supabase 세션은 live/가 Store.clear로 먼저 지운다(ADR 0005 §4)', () async {
      final rig = _Rig((r) async => _status(204));
      await rig.signIn();

      await rig.auth.signOut();
      expect(rig.log, ['google.signOut']);
    });
  });

  group('로그인', () {
    test('Google ID 토큰으로 signInWithIdToken을 부르고 ok', () async {
      Map<String, dynamic>? body;
      final rig = _Rig((r) async {
        body = jsonDecode(r.body);
        return _json(_session('new'));
      });

      expect(await rig.auth.signIn(), SignInStatus.ok);
      expect(rig.log, ['POST /auth/v1/token?grant_type=id_token']);
      expect(body, containsPair('provider', 'google'));
      expect(body, containsPair('id_token', 'gid'));
      expect(rig.client.auth.currentUser?.id, 'u1');
    });

    for (final (name, google, server, want) in [
      ('Google 취소', () async => throw const GoogleSignInException(code: GoogleSignInExceptionCode.canceled), null,
          SignInStatus.cancelled),
      ('Google 오류', () async => throw const GoogleSignInException(code: GoogleSignInExceptionCode.unknownError), null,
          SignInStatus.failed),
      ('ID 토큰 없음', () async => null, null, SignInStatus.failed),
      ('Supabase 네트워크 오류', null, (http.Request r) async => throw http.ClientException('down'), SignInStatus.offline),
      ('Supabase 거절', null, (http.Request r) async => _json({'code': 'bad_jwt', 'msg': 'bad'}, 400), SignInStatus.failed),
      ('Supabase 503', null, (http.Request r) async => _status(503), SignInStatus.failed),
    ]) {
      test('$name이면 ${want.name}이고 게스트로 남는다', () async {
        final rig = _Rig(server ?? (r) async => _json(_session('new')));
        if (google != null) rig.googleToken = google;

        expect(await rig.auth.signIn(), want);
        expect(rig.client.auth.currentUser, isNull);
      });
    }
  });
}

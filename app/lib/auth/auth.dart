// ADR 0002 작업 10: Google 로그인, 로그아웃, 탈퇴 순서(ADR 0001 §5). 실패와 취소는 값으로 돌려준다.
import 'package:google_sign_in/google_sign_in.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'offline.dart';

/// Google Cloud 웹 클라이언트 ID. 공개 식별자다. ID 토큰의 aud가 되고 Supabase Google 공급자가 이 값으로 검사한다.
const webClientId = '111140034242-d0d4s5hmqmjr1r1kqttsbes3hqtpt6hi.apps.googleusercontent.com';

/// backend.dart의 SignInResult와 같은 값. live/가 이름으로 옮긴다.
enum SignInStatus { ok, cancelled, offline, failed }

/// backend.dart의 DeleteResult와 같은 값.
enum DeleteStatus { ok, offline, failed }

class Auth {
  /// Google은 함수로 받는다. 테스트는 가짜를, 앱은 [Auth.google]을 쓴다.
  /// [clearLocal]은 로컬 기록과 Supabase 세션을 지운다(live/에서는 `Store.clear`).
  Auth(
    this._client, {
    required this.clearLocal,
    required this.googleIdToken,
    required this.googleSignOut,
    required this.googleDisconnect,
    required this.report,
  });

  /// 기기용. `GoogleSignIn.initialize`는 앱에서 한 번만 불러야 한다.
  /// nonce는 넘기지 않는다: Android 구현은 nonce를 받았을 때만 ID 토큰에 넣으므로 Supabase에도 넘길 것이 없다.
  static Future<Auth> google(SupabaseClient client,
      {required Future<void> Function() clearLocal, required void Function(Object, StackTrace) report}) async {
    final g = GoogleSignIn.instance;
    await g.initialize(serverClientId: webClientId);
    return Auth(
      client,
      clearLocal: clearLocal,
      googleIdToken: () async => (await g.authenticate()).authentication.idToken,
      googleSignOut: g.signOut,
      googleDisconnect: g.disconnect,
      report: report,
    );
  }

  final SupabaseClient _client;
  final Future<void> Function() clearLocal;
  final Future<String?> Function() googleIdToken; // 취소·실패는 GoogleSignInException
  final Future<void> Function() googleSignOut;
  final Future<void> Function() googleDisconnect;
  final void Function(Object, StackTrace) report; // 잡은 실패를 non-fatal로 보낸다(ADR 0007 §3)

  Future<SignInStatus> signIn() async {
    final String? idToken;
    try {
      idToken = await googleIdToken();
    } on GoogleSignInException catch (e, s) {
      if (e.code == GoogleSignInExceptionCode.canceled) return SignInStatus.cancelled;
      report(e, s);
      return SignInStatus.failed;
    }
    if (idToken == null) {
      report(StateError('idToken null'), StackTrace.current);
      return SignInStatus.failed;
    }
    try {
      await _client.auth.signInWithIdToken(provider: OAuthProvider.google, idToken: idToken);
      return SignInStatus.ok;
    } catch (e, s) {
      if (isOffline(e)) return SignInStatus.offline;
      report(e, s);
      return SignInStatus.failed;
    }
  }

  /// 로그아웃에서 auth 몫은 Google 로그아웃뿐이다. live/가 sync, WouldLose 판단, `Store.clear`(Supabase 세션 포함) 뒤에 부른다(ADR 0005 §4).
  Future<void> signOut() => _quietly(googleSignOut); // 실패해도 이 기기의 세션은 이미 없다

  /// ADR 0001 §5-2~4. 로컬은 서버가 지웠거나 세션이 거절됐을 때만 지운다.
  /// 세션이 거절되면 지우되 failed다. 계정이 서버에 남았을 수 있다(다시 로그인해 탈퇴).
  Future<DeleteStatus> deleteAccount() async {
    final bool deleted;
    try {
      deleted = await _callDelete();
      await clearLocal();
    } catch (e, s) {
      if (isOffline(e)) return DeleteStatus.offline;
      report(e, s);
      return DeleteStatus.failed;
    }
    await _quietly(googleDisconnect);
    if (!deleted) report(StateError('delete: session rejected'), StackTrace.current);
    return deleted ? DeleteStatus.ok : DeleteStatus.failed;
  }

  /// 204면 true. 401이면 세션을 갱신해 한 번 더 부른다.
  /// 세션이 서버에서 거절되면(401 뒤 갱신, 또는 요청 전 만료 토큰 갱신) false. 나머지 오류는 던진다.
  Future<bool> _callDelete() async {
    try {
      try {
        await _client.functions.invoke('delete-account');
      } on FunctionsHttpException catch (e) {
        if (e.status != 401) rethrow;
        await _client.auth.refreshSession();
        await _client.functions.invoke('delete-account');
      }
      return true;
    } catch (e) {
      // 요청 전 갱신 실패는 functions_client가 FunctionsFetchException(details:)으로 감싼다.
      final cause = e is FunctionsFetchException ? e.details : e;
      if (cause is AuthException && cause is! AuthRetryableFetchException) return false;
      rethrow;
    }
  }
}

Future<void> _quietly(Future<void> Function() f) async {
  try {
    await f();
  } catch (_) {}
}

# 0007. 크래시와 오류 보고: 잡지 않은 오류는 fatal, 잡은 실패는 non-fatal

상태: 채택
날짜: 2026-10-28

## 배경
크래시를 Firebase Crashlytics로 받는다는 것은 이미 정했다(`docs/decisions.md` 운영). 여기서는 어떻게 넣을지를 정한다. 어디서 켜는지, 무엇을 보내는지, 보고 직전에 무슨 일이 있었는지 어떻게 남기는지, 어느 빌드에서 보내는지, 무엇이 모이는지, 어떻게 확인하는지다.

2026-10-28 사용자 요청과 결정
- 로깅을 확실하게 하고 싶다(처음 제안은 AOP).
- 크래시가 아닌 실패(로그인·탈퇴 실패, 서버가 sync를 거절, 콘텐츠 받기 실패)도 Crashlytics non-fatal로 남긴다. 크래시 통계에는 넣지 않는다.
- 우리 코드가 잡은 것은 모두 non-fatal이다. 잡지 않은 오류만 fatal이다.
- 오프라인은 전송 오류 목록에 있는 것뿐이다. 모르는 오류를 포함해 나머지는 모두 보낸다.
- 다른 기기에서 탈퇴한 흔적(`23503`, 세션 갱신 거절, 세션 없음 + `synced` 행)도 모두 보낸다.
- 사용자는 많아야 약 1,000명으로 본다. 무료 한도는 이 숫자로 판단한다(11절).

이미 정한 것은 다시 적지 않고 가리킨다.
- Firebase 프로젝트 준비, `flutterfire configure`, 설정 파일 커밋: ADR 0006 §4
- `Firebase.initializeApp`은 `main.dart`에서 한 번 부른다: ADR 0006 §2
- 로컬 기록 파일을 읽다 실패하면 예외를 그대로 던진다. Crashlytics에 보이게 하려는 것이다: ADR 0005 §1
- ADR 0001 §6이 미뤄 둔 처리방침의 Crashlytics 항목과 국외 이전은 이 ADR 8절에서 정한다.

원칙은 ADR 0004·0006과 같은 "언제나 단순한 시스템"이다. 규칙 하나로 설명하고, 예외 규칙을 두지 않는다. 코드 기준은 최신 `dev`(`e3dc314`, PR #35 머지 뒤)다.

**규칙: 잡지 않은 오류는 fatal로 보낸다. 우리 코드가 잡은 실패는 전송 오류(2절 목록)가 아니면 non-fatal로 보낸다.**

- "실패"는 하려던 일(화면이 부른 동작, 앱이 스스로 하는 sync, 콘텐츠 받기와 고르기)이 뜻대로 끝나지 않은 것이다. 사용자 취소(`cancelled`)와 `WouldLose`는 실패가 아니다.
- 뒷정리(Google 로그아웃, 서버에 로그아웃 알리기처럼 실패해도 결과가 같은 일)는 하려던 일이 아니다.
- 서버 일시 장애(5xx)는 전송 오류가 아니므로 non-fatal로 간다. non-fatal은 실행마다 최대 8개가 남아 보내지고, 같은 원인은 이슈 하나로 묶이므로 1,000명에서 문제없다(3절). 따로 거르지 않는다.
- Crashlytics를 부르는 코드는 `main.dart`뿐이다. 다른 모듈은 `main.dart`가 넘겨준 함수(`report`, `log`)만 부른다.

## 결정
### 1. 잡지 않은 오류: 전역 처리기 (fatal)
| 오류 | 받는 방법 |
| --- | --- |
| Flutter 프레임워크가 잡은 오류(빌드, 레이아웃, 제스처 콜백) | `FlutterError.onError`에 `recordFlutterFatalError` |
| 그 밖의 잡지 않은 Dart 오류(기다리지 않은 `Future`, 시작 중 `LiveBackend.start()` 실패, 감싸개가 다시 던진 예외 포함) | `PlatformDispatcher.instance.onError`에서 `recordError(..., fatal: true)` |
| Android(Java·Kotlin) 크래시와 ANR | Crashlytics SDK가 알아서 받는다(Android는 ANR도 모은다, [시작 문서](https://firebase.google.com/docs/crashlytics/flutter/get-started)) |
| 네이티브(C·C++) 크래시 | 받지 않는다. Play Console Android vitals에서 본다(ADR 0008 G3) |

```dart
// app/lib/main.dart (dev e3dc314의 main에 더하는 줄)
import 'dart:ui' show PlatformDispatcher;
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'firebase_options.dart';
import 'logged_backend.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform); // ADR 0006 §2
  final crashlytics = FirebaseCrashlytics.instance;
  FlutterError.onError = crashlytics.recordFlutterFatalError;
  PlatformDispatcher.instance.onError = (error, stack) {
    crashlytics.recordError(error, stack, fatal: true);
    return true;
  };
  final inner = (kReleaseMode || fake.isEmpty)
      ? await LiveBackend.start(report: crashlytics.recordError) // 3절. 함수를 그대로 넘긴다(fatal 기본값 false)
      : FakeBackend.preset(fake);
  backend = LoggedBackend(inner, log: crashlytics.log); // 4절
  runApp(const MyApp());
}
```

- 순서는 `initializeApp` → 두 처리기 → `LiveBackend.start()` → `runApp`이다. 그래서 시작 중 기록 파일 읽기 실패(ADR 0005 §1)도 Crashlytics에 간다.
- 처리기 코드는 [FlutterFire 시작 문서](https://firebase.google.com/docs/crashlytics/flutter/get-started) 그대로다. fatal 보고는 앱을 다시 켜지 않아도 바로 보내진다([보고서 맞춤 설정](https://firebase.google.com/docs/crashlytics/flutter/customize-crash-reports)).
- `recordFlutterError`는 보내기 전에 `FlutterError.presentError`를 부르고, `recordError`는 디버그 빌드에서 오류를 콘솔에 찍는다([플러그인 소스](https://github.com/firebase/flutterfire/blob/main/packages/firebase_crashlytics/firebase_crashlytics/lib/src/firebase_crashlytics.dart)). 개발 중에 보던 오류 출력은 그대로 나온다.
- 처리기와 `recordError`는 예외의 문자열(`toString()`)과 Flutter 오류의 추가 정보(`informationCollector`)를 그대로 보낸다. 그래서 처리방침에 "오류 메시지"를 수집 항목으로 적는다(8절). 우리 코드가 만드는 예외 메시지에는 이름·이메일·답 내용을 넣지 않는다.
- `setCustomKey`, `setUserIdentifier`는 부르지 않는다.
- 앱은 isolate를 따로 만들지 않는다(`lib/`에 `Isolate`·`compute` 없음). isolate 오류 처리는 두지 않는다.
- `--obfuscate`와 `--split-debug-info`는 쓰지 않는다. 그래서 Dart 스택 트레이스는 기호 파일을 올리지 않아도 읽힌다. 쓰게 되면 `firebase crashlytics:symbols:upload`가 필요하다([시작 문서](https://firebase.google.com/docs/crashlytics/flutter/get-started)).
- Java·Kotlin 코드의 R8 매핑 파일은 `flutterfire configure`가 넣는 Crashlytics Gradle 플러그인이 올린다([난독화 해제](https://firebase.google.com/docs/crashlytics/android/get-deobfuscated-reports)). 릴리스 빌드의 기본값이 켜짐인지는 문서에 없다. 10절 수동 확인 3으로 본다.

### 2. 전송 오류 목록: `app/lib/auth/offline.dart`의 `isOffline` 하나
**전송 오류 = 서버의 응답을 받기 전에 연결에서 끝난 오류.** 목록에 있는 것만 오프라인이다. 목록에 없는 것은 모르는 오류까지 모두 서버에 닿은 실패로 본다.

```dart
// app/lib/auth/offline.dart. auth/와 live/가 함께 쓴다(live/는 auth/를 import할 수 있다).
bool isOffline(Object e) => switch (e) {
      SocketException() || TlsException() || HttpException() => true, // dart:io: 연결 실패, TLS 실패, 응답 도중 끊김
      ClientException() => true,                                       // package:http: supabase가 쓰는 전송 오류
      TimeoutException() => true,                                      // dart:async: 정한 시간 안에 응답이 없음
      AuthRetryableFetchException(:final statusCode) => statusCode == null, // 상태 코드가 있으면 5xx 응답이다
      FunctionsFetchException(:final details?) => isOffline(details),  // 감싼 오류는 안쪽으로 판단한다
      _ => false,
    };
```

- 한 곳에 두고 세 곳(sync, 로그인·탈퇴, 콘텐츠 받기)이 모두 이것을 부른다. 지금의 `auth.dart` `_unreachable`과 `live_backend.dart` `_reached`는 이 함수로 바꾼다. `online` 값은 `error == null || !isOffline(error)`가 된다.
- 바뀌는 동작: 지금 `_reached`는 목록에 없는 오류를 "닿지 않음"으로 친다. 이제는 모르는 오류도 닿은 실패로 보고 non-fatal을 보내고, `online`은 참이 된다.
- `FunctionsFetchException`은 `functions_client`가 요청 중 오류를 `details`에 감싸 던지는 예외다(`functions_client` 2.7.1 소스). `details`가 없으면 목록 밖이라 보낸다.
- `HttpException`은 응답 도중 연결이 끊긴 것이라 전송 오류다. 그래서 `content_update.dart`의 `httpGet`은 200이 아닌 응답에 `HttpException`을 던지지 않고 `Exception('HTTP ${res.statusCode} $uri')`을 던진다. 상태 코드는 메시지로 보이고, 콘텐츠의 비-200은 상태 코드와 관계없이 모두 보낸다(공개 Storage 경로라 메시지에 개인정보가 없다).
- `ClientException`을 쓰려면 `package:http`가 앱 의존성이어야 한다. 지금은 `dev_dependencies`에만 있으므로 `dependencies`로 옮긴다(supabase가 이미 쓰는 패키지라 앱 크기는 그대로다).
- 받아들이는 것: Google 로그인 단계에서 네트워크가 없으면 `GoogleSignInException(unknownError)`로 올 수 있다. 목록으로 가릴 수 없어 non-fatal로 간다. 사용자가 로그인 버튼을 눌렀을 때만 생기는 일이라 드물다.

### 3. 잡은 실패: `report` 함수 하나 (non-fatal)
`main.dart`는 `crashlytics.recordError`를 함수 그대로 `LiveBackend.start(report:)`에 넘긴다. `start()`는 같은 함수를 `LiveBackend` 생성자, `Auth.google(report:)`, `pickContent(report:)`, `fetchContent(report:)`에 넘긴다. 받는 쪽의 타입은 `void Function(Object, StackTrace)`라서 `fatal` 인자를 넘길 자리가 없다. 그래서 `report`로 가는 보고는 언제나 `recordError`의 기본값인 non-fatal이다. `live/`와 `auth/`는 Firebase를 import하지 않는다(ADR 0006의 `LogEvent`와 같은 방식). 테스트에서는 목록에 쌓는다.

부르는 곳은 실패를 결과로 바꾸는 `catch`다. 모양은 하나다: **`isOffline(e)`가 아니면 `report(e, s)` 한 줄.** 예외가 없는 실패는 고정 문구의 `StateError`와 `StackTrace.current`로 보낸다.

| 하려던 일 | 파일 | 보내는 것 | 보내지 않는 것 |
| --- | --- | --- | --- |
| 로그인 | `auth/auth.dart` `signIn` | `GoogleSignInException`(취소 제외), ID 토큰이 `null`(`StateError('idToken null')`), Supabase가 거절 | 취소, 전송 오류 |
| 탈퇴 | `auth/auth.dart` `deleteAccount` | 함수의 4xx·5xx, 세션 갱신 거절로 `failed`(`StateError('delete: session rejected')`) | 전송 오류 |
| sync | `live/live_backend.dart` `sync` | 서버가 응답한 오류 전부(RLS·스키마 거절, 5xx, `23503`), 코드 버그(`Error`), 세션이 없는데 `synced` 행이 있음(`StateError('session lost with synced rows')`) | 전송 오류 |
| 콘텐츠 받기 | `live/content_update.dart` `_fetch` | 200이 아닌 응답, 깨진 JSON, 검사 실패(지금은 `return`. `StateError('content invalid')`를 던져 같은 `catch`로 보낸다), 디스크 오류, 코드 버그 | 전송 오류(5초 시간 초과 포함) |
| 콘텐츠 고르기 | `live/content_update.dart` `pickContent` | 저장한 `content.json`을 읽었는데 깨짐(번들로 돌아간다) | 파일 없음(`PathNotFoundException`, 첫 실행이나 받은 적 없음) |

- **sync의 코드 버그**: 지금(dev `e3dc314`) `sync()`는 `on Error catch`에서 `Zone.current.handleUncaughtError(e, s)`로 넘겨 fatal이 된다. 우리 코드가 잡은 것이므로 작업 2에서 이 줄을 없애고 다른 오류와 같은 `catch (e, s)`에서 `report`로 보낸다. `Error`는 목록 밖이라 `online`은 지금처럼 참이 된다.
- **다른 기기에서 탈퇴한 흔적**: `23503`은 서버가 응답한 오류라 위 줄로 보내진다. 세션 갱신이 거절되면 세션이 사라지고 다음 판단에서 "세션 없음 + `synced` 행"이 되어 보내진다. 보낸 뒤의 처리(로컬을 지우고 로그아웃, ADR 0001 §5-5)는 그대로다.
- non-fatal은 기기에 쓰였다가 다음 fatal 보고나 다음 실행 때 보내진다. 실행마다 최근 8개만 남는다([보고서 맞춤 설정](https://firebase.google.com/docs/crashlytics/flutter/customize-crash-reports)).
- non-fatal은 크래시 없는 사용자 비율에 들어가지 않는다([크래시 없는 지표](https://firebase.google.com/docs/crashlytics/crash-free-metrics)). 그래서 ADR 0008 G4에 영향이 없다.
- `signOut`의 뒷정리(`_quietly(googleSignOut)`, `Store.clear`의 서버 로그아웃 알림)는 보내지 않는다.
- **남는 빈틈**: 서버가 sync를 거절해도 `online`은 참이고, 못 올린 기록(`unsynced`)만 쌓인다. 우리에게는 non-fatal로 보이지만, 사용자에게는 로그아웃할 때의 `WouldLose` 확인 말고는 알리지 않는다. 화면 안내는 이 ADR의 범위가 아니다.

### 4. 동작 기록: `Backend` 감싸개 하나 (`app/lib/logged_backend.dart`)
화면이 부르는 동작은 모두 `Backend`와 `Session` 메서드를 지난다(ADR 0002 §2). 그래서 이 두 인터페이스를 감싸는 클래스 하나가 모든 호출을 기록한다. 호출하는 곳마다 로그 줄을 쓰지 않는다.

```dart
// app/lib/logged_backend.dart. backend.dart만 import한다. Firebase를 모른다.
class LoggedBackend implements Backend {
  LoggedBackend(this._inner, {required void Function(String) log}) : _log = log;
  final Backend _inner;
  final void Function(String) _log;

  @override ValueListenable<Home> get home => _inner.home; // 값 읽기는 기록하지 않는다
  // stats, account, online도 같다

  @override
  Future<SignInResult> signIn() => _timed('signIn', _inner.signIn, (r) => r.name);
  // startDaily, signOut, deleteAccount, 그리고 Session의 answer, next, quit도 같은 모양
}
```

**한 줄의 모양**: `<메서드> <결과 종류> <걸린 ms>ms`

| 호출 | 남는 줄 (예) |
| --- | --- |
| `startDaily()` | `startDaily Intro 2ms` |
| `answer(a)` | `answer Answered 1ms` (두 번째 탭은 `answer Answered`가 한 번 더) |
| `next()` | `next Finished 4ms` |
| `quit()` | `quit Asking 0ms` |
| `signIn()` | `signIn offline 812ms` |
| `signOut()` | `signOut WouldLose 230ms` |
| `deleteAccount()` | `deleteAccount failed 1503ms` |
| 예외가 나면 | `signIn threw PostgrestException 40ms` 뒤 같은 예외를 다시 던진다(1절 처리기로 간다) |

- **결과 종류**: enum이면 이름(`offline`), 클래스면 클래스 이름(`WouldLose`). 돌려주는 값이 없는 `Session` 메서드와 `startDaily`는 호출 뒤 `phase` 값의 클래스 이름이다.
- **남기지 않는 것**: 메서드 인자(답 내용), 결과 안의 값(`WouldLose.count`, 문제 문장, XP), `Account`의 이름·이메일, 예외 메시지(타입 이름만). 값 읽기(`home`, `stats`, `account`, `online`)도 남기지 않는다.
- 기록은 Crashlytics `log()`로 보낸다. 로그는 다음 fatal·non-fatal 보고에 붙어서만 보이고, 세션마다 64KB를 넘으면 오래된 줄부터 지워진다([보고서 맞춤 설정](https://firebase.google.com/docs/crashlytics/flutter/customize-crash-reports)). 한 줄은 약 30바이트라 데일리 하나(약 30줄)는 1KB 안쪽이다.
- 로그는 보고의 맥락이다. 실패가 일어났다는 사실은 3절의 non-fatal 보고가 알린다. 예: 탈퇴가 `failed`로 끝나면 3절이 non-fatal을 보내고, 그 보고에 이 줄들이 붙는다.
- `log`는 함수로 받는다. 그래서 `logged_backend.dart`는 `firebase_crashlytics`를 import하지 않는다.
- 가짜 구현도 감싼다. `main.dart`는 고른 구현을 언제나 감싼다. 디버그 빌드에서는 Crashlytics가 꺼져 있으므로(6절) 보내지는 것은 없다.
- 앱이 스스로 하는 일(앱이 앞으로 올 때의 `sync()`, 콘텐츠 받기)은 감싸개를 지나지 않아 로그 줄이 없다. 이 일들의 실패는 3절 `report`가 덮는다.
- Analytics 브레드크럼(ADR 0006 §1의 5개 이벤트)도 같은 보고에 붙는다. 겹치는 것은 받아들인다. 감싸개는 Analytics가 보내지 않는 결과 종류와 걸린 시간을 남긴다.

### 5. 서버(Edge Function, PostgREST): Supabase 로그로 충분하다
- 서버 코드는 Edge Function `delete-account` 하나뿐이다(`supabase/functions/delete-account/index.ts`). 호출이 적고(탈퇴할 때만), 실패하면 앱이 3절로 non-fatal을 보낸다. 서버 쪽 원인은 Supabase 대시보드 로그에서 본다.
- 500을 돌려주는 곳에 원인이 남지 않는다. 그 자리에 한 줄을 더한다. 사용자 id와 이메일은 넣지 않는다.

```ts
if (delErr && delErr.status !== 404) {
  console.error('deleteUser failed', delErr.status, delErr.code)
  return new Response(null, { status: 500 })
}
```

- sync 요청이 서버에서 거절되면(RLS, 스키마) API 로그에 4xx로 남고, 앱도 3절로 non-fatal을 보낸다.
- 무료 플랜의 API·DB 로그 보관은 1일이다([Supabase 요금](https://supabase.com/pricing)). Edge Function 로그의 보관 기간은 문서에서 확인하지 못했다. non-fatal 보고를 보면 그날 안에 서버 로그를 본다. 로그 때문에 Pro로 올리지는 않는다(`docs/decisions.md` 예산).

### 6. 디버그 빌드는 보내지 않는다
`app/android/app/src/debug/AndroidManifest.xml`(Flutter가 만든 파일, 디버그 빌드에만 합쳐진다)에 한 줄을 더한다. 릴리스와 프로필 빌드는 보낸다.

```xml
<manifest xmlns:android="http://schemas.android.com/apk/res/android">
    <uses-permission android:name="android.permission.INTERNET"/>
    <application>
        <meta-data android:name="firebase_crashlytics_collection_enabled" android:value="false"/>
    </application>
</manifest>
```

- 이유: 디버그 빌드에서만 나는 오류(예: `RenderFlex overflowed` 같은 assert)가 화면을 만드는 동안 계속 fatal로 쌓인다. 사용자는 이 오류를 겪지 않는다. 크래시 없는 사용자 비율이 개발 기기 때문에 흐려진다.
- Analytics는 디버그 빌드도 보낸다(ADR 0006 §2). 디버그 빌드의 분석 이벤트는 사용자 이벤트와 같지만, 디버그 빌드의 오류는 사용자 오류와 다르기 때문에 규칙이 다르다.
- Dart에서 `setCrashlyticsCollectionEnabled(!kDebugMode)`를 부르지 않는 이유: 이 값은 다음 실행까지 저장되고, 끄는 것은 다음 실행부터 적용된다([보고서 맞춤 설정](https://firebase.google.com/docs/crashlytics/flutter/customize-crash-reports)). 같은 기기에서 릴리스 빌드를 쓰다 디버그 빌드를 처음 켜면 그 한 번은 보낸다. manifest는 빌드에 고정되고 테스트로 검사할 수 있다.

### 7. 모듈 경계
- `firebase_crashlytics`를 import하는 앱 코드는 `main.dart`뿐이다.
- `logged_backend.dart`는 `backend.dart`만 import한다. `auth/offline.dart`는 `auth/` 안의 파일이라 기존 `auth` 규칙을 따른다(`dart:io`, `package:http`, `supabase_flutter` 허용). `live/`는 이미 `auth/`를 import할 수 있다. `live/`와 `auth/`는 `report` 함수를 인자로 받을 뿐 Firebase import가 없다. `content/`, `engine/`, `sync/`, `fake/`, `screens/`는 Crashlytics를 모른다.
- Firebase 패키지는 패키지마다 한 곳에서만 import한다: `firebase_core`·`firebase_crashlytics`는 `main.dart`, `firebase_analytics`는 `live/`(ADR 0006 §2).
- `app/test/boundaries_test.dart`에 더할 것

```dart
'content': ([], ['package:flutter', 'package:supabase', 'dart:ui', 'package:firebase_']),
'engine': (['content'], ['package:flutter', 'package:supabase', 'dart:ui', 'package:firebase_']),
'sync': (['engine'], ['package:flutter', 'dart:ui', 'package:firebase_']),
'auth': ([], ['package:flutter', 'dart:ui', 'package:firebase_']),
'live': ([...], ['package:firebase_core', 'package:firebase_crashlytics']),
'logged_backend.dart': (['backend.dart'], _screenBanned),
'main.dart': ([..., 'logged_backend.dart'], [...]), // 허용 목록에 하나 더한다
// fake, screens는 이미 package:firebase_ 전부 금지.
```

- `content`·`engine`·`sync`·`auth`에 `package:firebase_`를 더하는 것은 새 규칙이 아니다. ADR 0002 §1의 "나머지 폴더는 `package:firebase_`를 import하지 않는다"를 지금 테스트가 검사하지 않아서 채운다.

### 8. 수집 항목과 개인정보
**모이는 것** ([Firebase 개인정보](https://firebase.google.com/support/privacy), [Play 공개 안내(Firebase)](https://firebase.google.com/docs/android/play-data-disclosure))
- 앱을 쓸 때마다(세션): Firebase Sessions SDK(Crashlytics가 함께 넣는다)가 앱 정보(패키지 이름, OS 정보, SDK 버전, 네트워크 연결 종류), 기기 정보(제조사, 모델), 앱을 앞으로 가져온 시각을 보낸다. 크래시 지표 계산에 쓴다. 보관 기간은 Firebase 개인정보 문서에 없다.
- 크래시, ANR, 3절의 실패가 날 때: 스택 트레이스, 오류 메시지, 그때의 앱 상태, 기기 정보(기기 모델, CPU 종류, 메모리·저장 공간, OS·앱 버전)
- Crashlytics 설치 UUID(영향받은 사용자 수를 센다), Firebase 설치 ID
- 4절의 동작 기록(메서드 이름, 결과 종류, 걸린 시간)
- 보고 직전의 Analytics 이벤트(브레드크럼). 우리 이벤트는 ADR 0006 §1의 5개와 자동 이벤트뿐이다.
- 네이티브 크래시용 minidump는 NDK를 넣지 않으므로 모이지 않는다. IP 주소는 Firebase 개인정보 문서의 Crashlytics 항목에 없다.

**정한 것** (2026-10-28 사용자)
- 사용자 식별자(`setUserIdentifier`)는 붙이지 않는다. 커스텀 키도 쓰지 않는다. 로그는 4절 감싸개만 쓴다.
- 동의와 거부: Analytics와 같게 동의 화면 없이 처리방침에 공개하고, 거부 방법은 앱 삭제다.
- 보존 기간: Crashlytics는 스택 트레이스와 식별자를 90일 동안 두었다가 지우기 시작한다([Firebase 개인정보](https://firebase.google.com/support/privacy)). 우리가 바꿀 설정은 없다. Sessions 데이터의 기간은 확인하지 못했다.
- 탈퇴: 사용자 식별자를 붙이지 않으므로 탈퇴 순서(ADR 0001 §5)에 더할 것이 없다.
- 오류 메시지에는 서버나 라이브러리가 만든 문장이 그대로 들어간다(1절). 그래서 처리방침에 "이름·이메일은 보내지 않는다"고 단정하지 않는다.

**개인정보처리방침에 더할 문구** (`docs/privacy/index.html`, 작업 4. 게시하기 전에 Sessions 데이터의 보관 기간을 확인해 넣는다)
- 1절 수집하는 항목: "계정과 연결하지 않는 앱 이용 통계" 줄을 "계정과 연결하지 않는 앱 이용 통계와 오류 보고: 아래 3절"로 바꾼다.
- 3절 제목을 "3. 앱 이용 통계와 오류 보고"로 바꾸고 문단 하나를 더한다.

> **오류 보고**: 오류를 고치기 위해 Google Firebase Crashlytics를 씁니다. 앱을 쓸 때마다 앱·기기 정보(앱 이름, OS·SDK 버전, 네트워크 연결 종류, 기기 제조사·모델)와 앱을 연 시각을 보냅니다. 앱이 비정상 종료되거나, 응답하지 않거나, 로그인·탈퇴·동기화·콘텐츠 받기·읽기가 실패하면 오류 내용(스택 트레이스와 오류 메시지), 그때의 앱 상태와 기기 정보(CPU 종류, 메모리·저장 공간, 앱 버전), 오류 직전의 앱 동작 기록(사용한 기능, 결과의 종류, 걸린 시간)과 앱 이용 기록(위 앱 이용 통계 항목)을 보냅니다. 앱 설치마다 무작위로 만든 식별자를 함께 보내며, 이 기록은 Google 계정과 연결하지 않습니다. 오류 내용과 식별자는 90일이 지나면 삭제됩니다.

- 4절 보유 기간: "오류 보고의 오류 내용과 식별자는 90일 뒤 삭제됩니다."를 더한다.
- 6절 국외 이전은 ADR 0006 §3의 항목 하나를 넓힌다(이전받는 자, 국가, 시기와 방법은 같다).
  - 이전 항목: "3절의 앱 이용 통계와 오류 보고 항목"
  - 목적: "앱 이용 통계, 오류 수정"
  - 보유 기간: "앱 이용 통계 개별 기록 2개월, 오류 보고의 오류 내용과 식별자 90일"
  - 거부 방법과 효과: "앱을 삭제하면 수집이 멈춥니다. 이미 모인 기록은 위 보유 기간이 지나면 삭제됩니다."
- 8절 탈퇴: "앱 이용 통계는 2개월, 오류 보고는 90일, 백업은 30일 뒤 사라집니다."
- 2절 처리 목적의 "크래시 보고: 오류 수정"을 "오류 보고: 오류 수정"으로, 5절 처리 위탁의 Crashlytics 줄 설명을 "앱 오류 보고"로 바꾼다.

**Play 데이터 보안 양식에 더할 줄** (ADR 0006 §3 표에 더한다)

| 데이터 유형 | 수집 | 공유 | 목적 | 이유 |
| --- | --- | --- | --- | --- |
| 앱 정보 및 성능 > 비정상 종료 로그 | 예 | 아니요 | 분석 | 스택 트레이스, 오류 메시지, 그때의 앱 상태, 4절 동작 기록 |
| 앱 정보 및 성능 > 진단 | 예 | 아니요 | 분석 | ANR, non-fatal 오류, 기기 메모리·저장 공간, 네트워크 연결 종류, 걸린 시간 |
| 앱 활동 > 앱 상호작용 | (0006 줄 그대로) | | | 이유에 "앱을 앞으로 가져온 시각(Firebase Sessions)"을 더한다 |
| 기기 또는 기타 ID | (0006 줄 그대로) | | | 이유에 "Crashlytics 설치 UUID, Firebase 설치 ID"를 더한다 |

- 목적은 "분석"이다. Play는 분석의 예로 "앱 상태 모니터링"을 든다([데이터 보안 안내](https://support.google.com/googleplay/android-developer/answer/10787469)).
- 공유는 "아니요", 전송 중 암호화는 "예"다(ADR 0006 §3과 같은 근거. Firebase는 HTTPS로 보낸다).
- Firebase는 이 항목들을 Play 데이터 유형에 대응시킨 표를 주지 않는다. 위 표는 Play의 유형 정의에 맞춰 고른 것이다. 적게 적어 심사에서 거절되는 것보다 넓게 적었다.

### 9. 준비 (사용자가 직접, ADR 0006 §4 1~3 다음)
1. `app/`에서 `flutter pub add firebase_crashlytics`를 한다(2026-10-28 기준 최신 6.0.1, `firebase_core` ^5.1.0 필요, [pub.dev](https://pub.dev/packages/firebase_crashlytics)).
2. `flutterfire configure`를 다시 실행한다. Android에서는 Crashlytics Gradle 플러그인을 넣는다([시작 문서](https://firebase.google.com/docs/crashlytics/flutter/get-started)). 바뀐 파일 목록을 PR 본문에 적는다.
3. Firebase 콘솔의 Crashlytics 알림 설정에서 새 fatal 이슈 알림이 운영 이메일로 오는지 확인하고, 새 non-fatal 이슈 알림도 켠다(기본으로 꺼져 있다).

### 10. 확인 방법
**단위 테스트로 검사하는 것**
- `app/test/boundaries_test.dart`: 7절 경계
- `app/test/manifest_test.dart`(ADR 0006 작업 3이 만드는 파일. 없으면 이 작업이 만든다): 디버그 manifest에 `firebase_crashlytics_collection_enabled`가 `false`인 `meta-data`가 있고, `src/main/AndroidManifest.xml`에는 그 이름이 없다
- `app/test/auth/offline_test.dart`: 2절 목록의 각 타입은 참, 목록 밖(`PostgrestException`, `AuthException`, 5xx `AuthRetryableFetchException`, `StateError`)은 거짓
- `app/test/auth/auth_test.dart`, `app/test/live/live_backend_test.dart`, `app/test/live/content_update_test.dart`: 3절 표의 보내는 것과 보내지 않는 것
- `app/test/logged_backend_test.dart`: 4절 표의 줄 모양, 예외를 다시 던지는지, 이름·이메일이 줄에 없는지
- fatal 여부는 `main.dart`에만 있다. `report`는 `recordError`를 그대로 넘기므로 `fatal`을 쓸 자리가 없고, 받는 쪽 타입(`void Function(Object, StackTrace)`)도 `fatal`을 받지 않는다. 누가 람다로 바꿔 `fatal: true`를 넣으면 수동 확인 4에서 콘솔의 "fatal" 표시로 잡는다. `main.dart`는 단위 테스트로 돌리지 않는다.

**기기에서 손으로 확인하는 것** (`main.dart`의 연결과 콘솔 도착은 단위 테스트로 볼 수 없다)

`flutter run --release`로 실기기나 에뮬레이터에서 하나씩 한다. 임시 줄은 커밋하지 않는다. 콘솔에 5분 안에 안 보이면 `adb shell setprop log.tag.FirebaseCrashlytics DEBUG`를 하고 `adb logcat -s FirebaseCrashlytics`에서 `Crashlytics report upload complete`를 찾는다([구현 테스트](https://firebase.google.com/docs/crashlytics/android/test-implementation)).

1. 프레임워크 오류: 아무 화면의 `build`에 `throw StateError('crash-check-1')` → 콘솔에 `crash-check-1` fatal 이슈가 생긴다.
2. 시작 중 오류: `main.dart`의 처리기 다음 줄에 `throw StateError('crash-check-2')` → 콘솔에 fatal로 생긴다. 처리기가 `LiveBackend.start()`보다 먼저 걸렸는지를 본다.
3. Android 크래시: `runApp` 뒤에 `Future.delayed(const Duration(seconds: 3), FirebaseCrashlytics.instance.crash)` → 앱이 닫힌다. 다시 켜면 보고가 올라간다. 스택 트레이스의 클래스 이름이 읽히는지(R8 매핑 업로드)도 본다.
4. non-fatal: `content_update.dart`의 manifest 주소를 잠깐 없는 경로로 바꿔 404를 받게 한다 → 앱을 다시 켜면 콘솔에 `HTTP 404` 이슈가 **non-fatal**로 생긴다. 비행기 모드로 켜면 생기지 않는다.
5. 디버그 빌드: `flutter run`(디버그)으로 1을 하면 10분이 지나도 콘솔에 생기지 않는다.
6. 1·4의 이슈 화면 "로그" 탭에 4절 줄(예: `startDaily Intro 2ms`)이, 브레드크럼에 Analytics 이벤트가 보인다.

### 11. 규모: 사용자 약 1,000명에서 무료 한도
| 항목 | 한도 | 1,000명에서 |
| --- | --- | --- |
| Crashlytics | 무료, 따로 적힌 한도 없음([Firebase 요금](https://firebase.google.com/pricing)) | 문제 없다 |
| Crashlytics non-fatal | 실행마다 최근 8개를 두었다가 다음 fatal이나 다음 실행 때 보낸다 | 서버 장애 때도 실행마다 최대 8개이고, 같은 원인은 이슈 하나로 묶인다. 문제없다 |
| Crashlytics 로그 | 세션당 64KB, 넘으면 오래된 줄부터 지움 | 데일리 하나가 1KB 안쪽이다 |
| Supabase 월간 활성 사용자 | 50,000([Supabase 요금](https://supabase.com/pricing)) | 2% |
| Supabase Edge Function 호출 | 월 500,000 | 탈퇴할 때만 부른다 |
| Supabase 로그 보관 | API·DB 1일 | 5절대로 non-fatal을 본 날 서버 로그를 본다 |

## 고려한 대안
**AOP로 로깅하기(사용자의 처음 제안)**: Dart·Flutter에는 실용적인 방법이 없다.
- `dart:mirrors`(런타임 리플렉션): Dart 라이브러리 문서가 "Native JIT only (not Flutter)"라고 적는다([Dart 라이브러리](https://dart.dev/libraries)). Flutter 릴리스 빌드는 AOT라 호출을 런타임에 가로챌 수 없다.
- AspectD(Alibaba의 Flutter AOP): 기본 브랜치의 마지막 커밋이 2021-07-28 "Compatible with stable/v2.2.3"이고, README에 `flutter_tools`에 패치를 대야 한다고 적혀 있다([저장소](https://github.com/alibaba-flutter/aspectd), GitHub API로 2026-10-28 확인). 우리 Flutter는 3.41.2다.
- Dart 매크로: Dart 팀이 2025년 1월 "macros 작업을 멈추기로 했다"고 발표했다([Dart 블로그](https://dart.dev/blog/an-update-on-dart-macros-data-serialization), [매크로 문서](https://dart.dev/language/macros)).
- 코드 생성(`build_runner`, `reflectable`): 감쌀 인터페이스가 둘뿐인데 빌드 단계와 의존성이 는다. 손으로 쓴 감싸개는 메서드 7개다.
- 대신 고른 것: 모든 화면 동작이 이미 인터페이스 하나를 지나므로(ADR 0002 §2), 그 인터페이스를 감싸는 데코레이터가 AOP의 "모든 호출 앞뒤에 끼우기"와 같은 일을 한다. 컴파일러가 `implements` 누락을 잡으므로 메서드를 빠뜨릴 수 없다. 화면 밖의 일은 3절 `report`가 맡는다.

**호출하는 곳마다 로그 줄 쓰기**: 빠뜨리기 쉽고, 개인정보를 넣지 않는 규칙을 곳곳에서 지켜야 한다.

**`logging` 패키지나 `Zone`으로 `print` 가로채기**: 보낼 곳이 Crashlytics 하나라 함수 하나로 충분하다. `Zone`은 오류와 출력만 가로채고 메서드 호출은 가로채지 못한다.

**non-fatal을 감싸개에서 보내기(결과가 `failed`일 때)**: `live/`·`auth/`를 건드리지 않지만 원인 예외가 사라지고(예: Google 로그인 설정 오류 코드), 백그라운드 sync와 콘텐츠 받기를 덮지 못한다.

**잡은 코드 버그(`Error`)는 fatal로 보내기**: 1차 안이었다. 앱이 죽지 않았는데 크래시 통계에 들어가고, 같은 `catch` 안에서 타입마다 다르게 보내는 규칙이 생긴다(2026-10-28 사용자가 버렸다).

**모르는 오류를 오프라인으로 보기(지금 `_reached`)**: 코드 버그나 처음 보는 서버 오류가 "연결 없음"으로 숨는다.

**`report`를 작은 함수(`nonFatal(record)`)로 감싸 테스트하기**: 테스트할 수 있지만 `main.dart`가 그 함수를 쓰는지는 여전히 테스트 밖이다. `recordError`를 그대로 넘기면 `fatal`을 쓸 자리 자체가 없어 더 단순하다.

**`report`를 전역 변수로 두기**: 생성자 인자가 줄지만, `auth/`·`live/`가 공유 파일을 import하게 되고 테스트끼리 값이 섞인다. 이 코드는 이미 함수 주입을 쓴다.

**5xx를 따로 거르기**: 규칙이 하나 더 생긴다. 실행마다 8개 한도와 이슈 묶음으로 충분하다.

**디버그 빌드도 보내기(ADR 0006과 같은 규칙)**: 6절 이유로 고르지 않았다.

**NDK 크래시 받기(`firebase-crashlytics-ndk`)**: Gradle 설정이 늘고 minidump라는 수집 항목이 하나 더 생긴다. 우리 코드에는 네이티브 코드가 없고, Flutter 엔진의 네이티브 크래시는 Play Console Android vitals에 무료로 나온다.

## 결과
- **쉬워지는 것**: Crashlytics를 부르는 코드는 `main.dart`의 몇 줄뿐이다. 다른 모듈은 함수 하나(`report` 또는 `log`)와 `isOffline`만 안다. 크래시와 실패마다 직전의 동작 순서와 결과가 붙는다. fatal은 잡지 않은 오류뿐이라 크래시 통계에 잡은 실패가 섞이지 않는다.
- **어려워지는 것**: `Backend`나 `Session`에 메서드가 생기면 `backend.dart`, 가짜, 실제 구현에 더해 감싸개까지 네 곳을 고친다(빠뜨리면 컴파일이 안 된다). 실패를 결과로 바꾸는 `catch`를 새로 쓸 때마다 `report` 한 줄을 잊지 않아야 한다(리뷰에서 본다). 새 전송 오류 타입이 보이면 2절 목록에 더한다. 처리방침과 데이터 보안 양식에 줄이 는다.
- **확인할 점**
  - 네트워크 없음: 학습은 영향이 없다. 전송 오류는 보내지 않는다. 처리기와 감싸개는 기록만 하고 기다리지 않는다. 오프라인에서 난 크래시를 기기에 두었다가 언제 보내는지는 공식 문서에서 확인하지 못했다.
  - 같은 요청 두 번: 두 번째 탭도 한 줄로 남는다(`answer Answered` 두 줄). 그래서 두 번 탭이 무시됐는지 보고서에서 보인다. 같은 오류는 콘솔에서 이슈 하나로 묶인다.
  - 기기 두 대: 설치마다 따로 센다. 계정과 연결하지 않는다. 다른 기기에서 탈퇴한 흔적은 non-fatal로 보인다(3절).
  - 탈퇴: 할 일이 없다. 오류 내용과 식별자는 90일 뒤 사라진다.
  - 콘텐츠 업데이트: 받기 실패는 3절로 보인다. 동작 기록에는 콘텐츠 id가 없고, 브레드크럼의 `scenario_id`는 지우지 않는 id다(ADR 0003 §1).
  - 시작 중 실패: 기록 파일 읽기가 실패하면(ADR 0005 §1) Crashlytics에는 fatal로 가지만 `runApp`에 닿지 않아 사용자는 빈 화면을 본다. 지금 ADR 0005의 동작 그대로이고 이 ADR에서 바꾸지 않는다.
  - sync 중 코드 버그: non-fatal로 가고 `online`은 참이다(오프라인으로 잘못 보이지 않는다).
- **넣지 않은 것과 넣을 시점**
  - 커스텀 키(예: 콘텐츠 버전): 콘텐츠 버전을 모르면 재현할 수 없는 크래시가 생기면.
  - 백그라운드 일의 로그 줄: 3절 보고만으로 원인을 못 찾는 일이 생기면. `LiveBackend`에 `log` 함수를 하나 더 받는다.
  - 서버 거절을 화면에 알리기: 못 올린 기록이 쌓였다는 신고가 오면.
  - NDK: Android vitals에 우리 탓으로 보이는 네이티브 크래시가 늘면.
  - 사용자 식별자: 특정 사용자의 신고를 크래시와 맞춰 봐야 하는 일이 반복되면.
- **다시 볼 조건**: iOS 출시(dSYM 업로드, Info.plist 설정, Apple 쪽 전송 오류 타입이 다르다), `--obfuscate`를 쓰게 될 때, 법률 확인에서 동의나 앱 안 거부 수단이 필요하다고 나올 때, 사용자가 1,000명을 크게 넘을 때(11절).

## 다른 문서에 미치는 영향
- `docs/decisions.md`: 결정이 바뀌는 것은 없다. 운영 줄의 "크래시는 Firebase Crashlytics로 받는다"를 따른다. 크래시가 아닌 실패도 Crashlytics로 보낸다는 것을 그 줄에 적을지("크래시와 오류는 Firebase Crashlytics로 받는다"), 사용자 규모(약 1,000명)를 예산 줄에 적을지는 사람이 정한다. 개인정보 줄은 ADR 0006 열린 질문 3에서 정한 대로 계정 정보 규칙으로 읽는다.
- ADR 0001 §6: 수집 항목, 처리 목적, 보유 기간, 탈퇴로 지우는 범위, Crashlytics 줄이 이 ADR 8절과 맞게 고쳤다(2026-10-28).
- ADR 0006 §2 `main.dart` import 줄, §3 Play 양식 머리말: 이 ADR을 가리키게 고쳤다(2026-10-28).
- ADR 0002 §1(표의 `auth/`·`logged_backend.dart`·`main.dart` 줄, 패키지 문장), §3 `main.dart` 코드, 결과 절(네 곳, `isOffline`): 이 ADR에 맞게 고쳤다(2026-10-28 채택).
- 작업 2에서 바뀌는 것
  - `Backend` 인터페이스(ADR 0002 §2)는 바뀌지 않는다. 바뀌는 시그니처는 `LiveBackend` 생성자, `LiveBackend.start`, `Auth` 생성자와 `Auth.google`, `pickContent`, `fetchContent`에 `report` 인자 하나씩이다.
  - 바뀌는 코드 동작(작업 2): `sync()`의 `on Error` → `Zone.current.handleUncaughtError` 줄을 없애고 `report`로 보낸다. `auth.dart` `_unreachable`과 `live_backend.dart` `_reached`를 `isOffline`으로 바꾼다. `httpGet`은 비-200에 `HttpException` 대신 `Exception('HTTP …')`을 던진다. 이에 따라 `content_update_test.dart`의 `throwsA(isA<HttpException>())` 기대값이 바뀐다(설계 변경이므로 이 ADR이 근거다). `package:http`를 `dependencies`로 옮긴다.
- `docs/privacy/index.html`: 작업 4에서 8절 문구를 넣는다.
- 출시 전 품질 기준(크래시 없는 사용자 비율, 열린 fatal·ANR 이슈, Android vitals)은 ADR 0008에 따로 둔다. 이 ADR은 보고를 모으는 방법까지만 정한다.

## 작업 목록
모두 dev `e3dc314` 위에서, ADR 0006 작업 1(Firebase 프로젝트, `initializeApp`)이 끝난 뒤 시작한다. 2·3은 1 다음이다.

| # | 담당 | 작업 (PR 하나) | 먼저 쓸 실패하는 테스트 | 확인 방법 |
| --- | --- | --- | --- | --- |
| 1 | 사용자 | `feat: 잡지 않은 오류를 Crashlytics로 보내기`: 9절 1~2, 1절 처리기(`report` 연결 빼고), 6절 디버그 manifest, 7절 경계(감싸개 줄 빼고) | `manifest_test`: `src/debug/AndroidManifest.xml`에 `firebase_crashlytics_collection_enabled`=`false` `meta-data`가 없거나 `src/main/AndroidManifest.xml`에 그 이름이 있으면 실패한다. `boundaries_test`: 규칙을 더한 뒤 `lib/live/`의 파일에 `import 'package:firebase_crashlytics/firebase_crashlytics.dart';`, `lib/engine/`에 `import 'package:firebase_core/firebase_core.dart';`를 잠깐 넣어 실패를 보고 뺀다 | `cd app && flutter analyze && flutter test`. 10절 수동 확인 1·2·3·5 결과를 PR 본문에 적는다 |
| 2 | 사용자 | `feat: 잡은 실패를 non-fatal로 보내기`: 2절 `isOffline`, 3절 `report`를 `main.dart` → `LiveBackend.start` → `LiveBackend`·`Auth`·`pickContent`·`fetchContent`로 넘기고 표의 다섯 곳에 한 줄씩. "작업 2에서 바뀌는 것"의 코드 동작 변경 전부 | `offline_test`: 2절 목록 타입마다 참, `PostgrestException`·`AuthException`·`AuthRetryableFetchException(statusCode: '503')`·`StateError`는 거짓, `FunctionsFetchException(details: ClientException(..))`은 참, `details: AuthException(..)`은 거짓. `auth_test` 로그인: `googleIdToken`이 `GoogleSignInException(code: unknownError)`를 던지면 `failed`이고 `reported`에 하나, `canceled`면 `cancelled`이고 없음, `googleIdToken`이 `null`을 돌려주면 `failed`이고 `StateError` 하나, `signInWithIdToken`이 `ClientException`이면 `offline`이고 없음. `auth_test` 탈퇴: 함수가 400·500이면 `failed`이고 하나, 401 뒤 세션 갱신이 거절되면 `failed`이고 `StateError` 하나, `FunctionsFetchException(details: ClientException)`이면 `offline`이고 없음. `live_backend_test` sync: `PostgrestException(code: '42501')`이면 하나이고 `online`은 참, `ClientException`이면 없음이고 `online`은 거짓, `23503`이면 하나이고 로컬이 지워진다, 저장소가 `TypeError`를 던지면 하나이고 `online`은 참, 세션 없음 + `synced` 행이면 `StateError` 하나. `content_update_test`: `get`이 `SocketException`·`TimeoutException`이면 없음, `HttpException`(도중 끊김)이면 없음, `httpGet`이 404를 받으면 `Exception`을 던지고(`HttpException` 아님) `_fetch`는 하나를 보낸다, 깨진 JSON이면 하나, 검사에 실패하는 본문이면 하나, `pickContent`는 파일이 없으면 없음이고 깨진 파일이면 하나. `fatal`을 넘길 수 없는 것은 타입으로 막는다(테스트가 아니다. 10절 수동 확인 4가 본다) | `cd app && flutter analyze && flutter test`(Supabase 환경 변수 넣고, `CLAUDE.md`). 10절 수동 확인 4(콘솔에 non-fatal로 뜬다) |
| 3 | 사용자 | `feat: 화면 동작을 크래시 보고에 기록`: `logged_backend.dart`, `main.dart`에서 감싸기, 7절 경계의 감싸개 줄 | `logged_backend_test`: `LoggedBackend(FakeBackend(signIn: SignInResult.offline), log: lines.add)`에서 `signIn()` 뒤 `lines`가 `^signIn offline \d+ms$` 한 줄이다. 이어서: `startDaily()` → `startDaily Intro`, 첫 문제에 답을 두 번 → `answer Answered` 두 줄, 안쪽이 `StateError`를 던지면 `… threw StateError …` 한 줄이 남고 같은 예외가 밖으로 나온다, `FakeBackend(account: Account(name: '홍길동', email: 'a@b.c'))`로 모든 메서드를 부른 뒤 어느 줄에도 `홍길동`이나 `@`가 없다 | `flutter analyze && flutter test`. 10절 수동 확인 6 |
| 4 | 사용자 | `docs: 처리방침에 오류 보고 항목 더하기`: 8절 문구를 `docs/privacy/index.html`에 넣는다. Sessions 데이터 보관 기간을 먼저 확인한다 | 문서라 테스트를 먼저 쓰지 않는다 | 페이지를 열어 1·2·3·4·5·6·8절이 8절 문구와 같은지 본다. 시행일을 고친다 |
| 5 | 사용자 | `fix: 탈퇴 함수 500 응답에 원인 로그 남기기`: 5절 `console.error` 한 줄 | 동작(응답 코드)이 바뀌지 않는 로그 한 줄이라 테스트를 먼저 쓰지 않는다. 기존 `deno test`가 그대로 통과해야 한다 | `supabase functions serve` 출력에서 500 경로의 줄을 보거나 코드 리뷰로 본다. 줄에 uid·이메일이 없다 |
| 6 | 사용자 | Play Console 데이터 보안 양식에 8절 줄 더하기(PR 없음, ADR 0006 작업 5와 함께) | 콘솔 설정이라 없다 | ADR 0008 출시 점검 |

## 열린 질문 (사용자 결정 필요)
없음.

정해진 것(2026-10-28 사용자)
- 사용자 식별자를 붙이지 않는다.
- 동의 화면 없이 처리방침에 공개하고, 거부 방법은 "앱을 삭제한다"로 적는다.
- 크래시가 아닌 실패도 non-fatal로 보낸다.
- 잡은 것은 모두 non-fatal, 잡지 않은 오류만 fatal이다.
- 전송 오류 목록에 있는 것만 오프라인이다.
- 다른 기기에서 탈퇴한 흔적도 모두 보낸다.

아래는 결정할 때 비교한 내용이다.
1. **크래시 보고에 사용자 식별자를 붙일지**
   - (A, 채택) 붙이지 않는다. 크래시는 설치 단위로만 센다. 탈퇴 때 할 일이 없고 처리방침에 "계정과 연결하지 않는다"고 쓸 수 있다.
   - (B) 로그인한 사용자의 Supabase 사용자 id를 `setUserIdentifier`로 붙인다. 신고한 사용자의 크래시를 찾을 수 있다. 대신 크래시 기록이 계정 데이터가 된다. 식별자를 지워도 이미 모인 기록은 지워지지 않으므로([보고서 맞춤 설정](https://firebase.google.com/docs/crashlytics/flutter/customize-crash-reports)) 탈퇴 뒤 최대 90일 남는다고 처리방침에 써야 한다.
2. **크래시 보고의 동의와 거부 방법**
   - (A, 채택) Analytics와 같게 동의 화면 없이 처리방침에 공개하고, 거부 방법은 "앱을 삭제한다"로 적는다. 코드가 없다. Play 양식에서는 "필수 수집"이다.
   - (B) 설정 화면에 "오류 보고 보내기" 스위치를 두고 `setCrashlyticsCollectionEnabled`로 끈다. `backend.dart`, 가짜, 실제 구현, 감싸개, 화면이 바뀐다.
   - 출시 전 법률 확인에서 앱 안 거부 수단이 필요하다고 나오면, Analytics와 Crashlytics를 함께 끄는 스위치 하나로 (B)를 한다.

## 확인하지 못한 것
- 오프라인에서 난 fatal 크래시를 기기에 얼마나 두었다가 언제 보내는지.
- Crashlytics Gradle 플러그인의 매핑 파일 업로드가 릴리스 빌드에서 기본으로 켜지는지(10절 수동 확인 3으로 본다). 문서는 `mappingFileUploadEnabled` 설정만 보이고 기본값을 적지 않았다.
- `flutterfire configure`가 Crashlytics를 위해 바꾸는 Gradle 파일 목록.
- 디버그 빌드에서 수집이 꺼진 채 기기에 쌓인 보고를, 같은 기기에 릴리스 빌드를 덮어 깔았을 때 보내는지(개발 기기에서만 생기는 일이다).
- Firebase Sessions 데이터의 보관 기간, 그리고 언제·얼마나 자주 보내는지. Firebase 개인정보 문서와 Play 공개 안내에 없다. 처리방침(작업 4)을 게시하기 전에 확인해야 한다.
- Android에서 네트워크가 없을 때 Google 로그인(Credential Manager)이 어떤 `GoogleSignInExceptionCode`로 오는지(2절에서 non-fatal로 받아들였다).
- `functions_client`가 `FunctionsFetchException.details`에 넣는 값의 종류 전체(2.7.1 소스에서 요청 중 오류를 그대로 넣는 것만 봤다).
- Supabase 무료 플랜의 Edge Function 로그 보관 기간. 요금표에는 "API·DB 로그 1일"만 있고, 로그 문서는 "요금제에 따라 다르다"고만 한다.
- Play 데이터 보안 양식에서 위 대응이 맞는지(Firebase가 대응표를 주지 않는다).
- 크래시 보고에 대한 한국 개인정보 보호법 판단(동의 필요 여부, 국외 이전 공개만으로 되는지)은 ADR 0006 "확인하지 못한 것"과 같다.
- Crashlytics 데이터가 처리되는 정확한 국가 목록. Firebase 문서는 Crashlytics를 "Google Cloud 어느 위치에서나 처리할 수 있는" 전역 서비스로 분류한다.

## 참고 (2026-10-28 확인)
- FlutterFire Crashlytics: [시작하기](https://firebase.google.com/docs/crashlytics/flutter/get-started), [보고서 맞춤 설정](https://firebase.google.com/docs/crashlytics/flutter/customize-crash-reports), [크래시 없는 지표](https://firebase.google.com/docs/crashlytics/crash-free-metrics), [플러그인 소스](https://github.com/firebase/flutterfire/tree/main/packages/firebase_crashlytics/firebase_crashlytics), [pub.dev](https://pub.dev/packages/firebase_crashlytics)
- Crashlytics Android: [구현 테스트](https://firebase.google.com/docs/crashlytics/android/test-implementation), [난독화 해제](https://firebase.google.com/docs/crashlytics/android/get-deobfuscated-reports)
- 개인정보: [Firebase 개인정보와 보안](https://firebase.google.com/support/privacy), [Play 공개 안내(Firebase)](https://firebase.google.com/docs/android/play-data-disclosure), [Play 데이터 보안 안내](https://support.google.com/googleplay/android-developer/answer/10787469)
- 요금과 한도: [Firebase 요금](https://firebase.google.com/pricing), [Supabase 요금](https://supabase.com/pricing), [Supabase 로그](https://supabase.com/docs/guides/telemetry/logs)
- AOP 대안: [Dart 라이브러리(dart:mirrors)](https://dart.dev/libraries), [Dart 매크로 중단](https://dart.dev/blog/an-update-on-dart-macros-data-serialization), [AspectD](https://github.com/alibaba-flutter/aspectd)
- 라이브러리 소스(로컬 pub 캐시): `functions_client` 2.7.1 `FunctionsFetchException(details: error)`, `gotrue` 2.27.3 전송 오류를 `AuthRetryableFetchException(message:)`로 감쌈, `postgrest` 2.9.1 전송 오류를 감싸지 않음
- 기준 문서: `docs/decisions.md`(운영, 개인정보, 예산), ADR 0001 §5·§6, ADR 0002 §1·§2·§3·결과 절, ADR 0003 §1, ADR 0005 §1, ADR 0006 §1·§2·§3·§4, `docs/privacy/index.html`, `supabase/functions/delete-account/index.ts`, dev `e3dc314`의 `app/lib/main.dart`·`app/lib/backend.dart`·`app/lib/live/live_backend.dart`·`app/lib/live/content_update.dart`·`app/lib/auth/auth.dart`·`app/test/boundaries_test.dart`·`app/test/live/content_update_test.dart`

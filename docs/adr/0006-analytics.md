# 0006. 사용자 행동 분석: Firebase Analytics 이벤트 5개

상태: 채택 (2026-10-29 3절 "AdServices 광고 권한도 뺀다" 수정 채택)
날짜: 2026-10-27

## 배경
출시 뒤에 알고 싶은 것은 다섯 가지다. 첫날 데일리를 끝까지 하는지, 어느 장면에서 그만두는지, 다음 날 다시 오는지, 로그인을 하는지, 어느 문제가 너무 어렵거나 쉬운지(기획서 "AI 활용 방식" 6번). 게스트 기록은 기기에만 있으므로(ADR 0001 §1) 서버 기록만으로는 알 수 없다.

2026-10-27 사용자 결정: 행동 분석은 Firebase Analytics로 하고, 이벤트는 최소한으로 둔다(`docs/decisions.md` 운영). 원칙은 ADR 0004와 같은 "언제나 단순한 시스템"이다. 규칙마다 한 문장으로 설명되게 하고, 예외와 조정 손잡이를 두지 않는다.

지금 앱에는 Firebase가 없다(`app/pubspec.yaml`). Crashlytics도 같은 Firebase 프로젝트를 쓰므로, 프로젝트 준비(4절)는 두 기능이 함께 쓴다. Analytics와 Crashlytics는 무료다([요금](https://firebase.google.com/pricing)).

## 결정
### 1. 이벤트
**자동으로 모이는 것은 만들지 않는다.** Firebase가 알아서 보내는 이벤트로 답할 수 있는 질문은 아래와 같다([자동 수집 이벤트](https://support.google.com/firebase/answer/9234069)).

| 질문 | 쓰는 것 |
| --- | --- |
| 다음 날 다시 오나 | `first_open`(설치 뒤 첫 실행), `session_start`(앱 사용 시작). 콘솔의 재사용(리텐션) 보고서 |
| 몇 명이 설치하고 지우나 | `first_open`, `app_remove`(Android) |

**직접 보내는 이벤트는 5개다.**

| 이벤트 | 언제 보내나 | 파라미터 | 답하는 질문 |
| --- | --- | --- | --- |
| `daily_start` | `startDaily()`가 세트를 만들 때 | `day_id` | 첫 실행 뒤 데일리를 시작하나 |
| `answer` | `answer()`가 답을 받아 기록을 쓴 뒤 | `scenario_id`, `grade`(`best`·`ok`·`avoid`), `retry`(0·1) | 어느 문제가 너무 어렵거나 쉬운가 |
| `daily_quit` | `quit()`로 세트를 그만둘 때 | `day_id`, `scene`(1~3) | 어느 장면에서 그만두나 |
| `daily_complete` | `next()`가 `Finished`로 넘어가며 완료 기록을 쓴 뒤 | `day_id` | 첫날 완주율(`day_id`가 `day-01`), 하루별 완주율 |
| `login` | `signIn()` 결과가 `ok`일 때 | `method`: `google` | 게스트가 로그인으로 넘어오나 |

- 이름 규칙: 영문 소문자·숫자·`_`만 쓰고, 문자로 시작하고, 40자 이하다. `firebase_`, `google_`, `ga_`로 시작하지 않고, 예약 이름(`first_open`, `session_start`, `error` 등)을 쓰지 않는다. 위 5개는 규칙과 예약 목록을 확인했다([Event 참고](https://firebase.google.com/docs/reference/android/com/google/firebase/analytics/FirebaseAnalytics.Event), [예약 이름](https://support.google.com/analytics/answer/13316687)).
- `login`과 `method`는 Firebase 권장 이벤트 이름을 그대로 쓴다.
- 파라미터 값은 콘텐츠 id, 채점 결과, 작은 정수만 넣는다. 이름, 이메일, Supabase 사용자 id, 자유 텍스트는 넣지 않는다.
- 값은 문자열이나 정수만 쓴다. Flutter `logEvent`는 String과 num만 받으므로 `retry`는 bool이 아니라 0·1이다([Flutter 이벤트](https://firebase.google.com/docs/analytics/flutter/events)).
- `scenario_id`는 펼친 문제 id이고 최대 91자다(ADR 0003 §1). 문자열 값 한도 100자 안에 들어간다([수집 한도](https://support.google.com/analytics/answer/9267744)).
- `scene`은 그만둔 순간의 문제가 처음 나온 장면 번호다. 장면 소개(`Intro`)에서 그만두면 그 장면 번호다.
- 앱을 강제로 닫으면 `daily_quit`은 오지 않는다. 그만둔 수는 `daily_start − daily_complete`로 세고, `daily_quit`은 장면별 분포를 볼 때만 쓴다.
- `answer`는 데일리와 카테고리 연습에서 모두 보낸다. 카테고리 연습의 시작·완료 이벤트는 그 기능을 넣을 때 정한다.

### 2. 어디서 보내나: `live/` 안에서만
- 이벤트 시점은 화면이 이미 부르는 `Backend` 메서드(`startDaily`, `answer`, `quit`, `next`, `signIn`)와 같다. 그래서 `live/`의 구현 안에서 보낸다. 화면과 `backend.dart`는 분석을 모르고, 인터페이스는 바뀌지 않는다(ADR 0002 §1·§2).
- `fake/`는 아무것도 보내지 않는다.
- `LiveBackend`는 보내는 함수 하나를 생성자 인자로 받는다. 인터페이스 클래스는 만들지 않는다.

```dart
// live/live_backend.dart
typedef LogEvent = void Function(String name, Map<String, Object> params);

// LiveBackend.start() 안에서 실제 함수를 넣는다
log: (name, params) => FirebaseAnalytics.instance.logEvent(name: name, parameters: params),

// 테스트에서는 목록에 쌓는다
final logged = <(String, Map<String, Object>)>[];
final live = LiveBackend(/* ... */, log: (n, p) => logged.add((n, p)));
```

- 로컬 기록을 쓴 다음에 보낸다. 결과를 기다리지 않는다(`await` 없음). 분석이 실패해도 학습은 그대로 이어진다.
- `Firebase.initializeApp`은 `main.dart`에서 한 번 부른다. Crashlytics도 이것을 쓴다.
- `firebase_analytics`를 import하는 앱 코드는 `live/`뿐이다. `main.dart`는 `firebase_core`, `firebase_options.dart`, `firebase_crashlytics`(ADR 0007)만 import한다.
- 디버그 빌드도 똑같이 보낸다. 빌드별로 끄는 설정은 두지 않는다.

### 3. 개인정보
**광고 ID는 모으지 않는다.** `app/android/app/src/main/AndroidManifest.xml`에 아래를 넣는다. Analytics SDK가 AD_ID 권한을 앱 manifest에 합쳐 넣기 때문에, 권한도 함께 뺀다([데이터 수집 설정](https://firebase.google.com/docs/analytics/android/configure-data-collection), [AD_ID 권한](https://developers.google.com/android/reference/com/google/android/gms/ads/identifier/AdvertisingIdClient.Info)).

```xml
<manifest xmlns:android="http://schemas.android.com/apk/res/android"
    xmlns:tools="http://schemas.android.com/tools">
    <uses-permission android:name="com.google.android.gms.permission.AD_ID" tools:node="remove"/>
    <uses-permission android:name="android.permission.ACCESS_ADSERVICES_AD_ID" tools:node="remove"/>
    <uses-permission android:name="android.permission.ACCESS_ADSERVICES_ATTRIBUTION" tools:node="remove"/>
    <application ...>
        <meta-data android:name="google_analytics_adid_collection_enabled" android:value="false"/>
```

`firebase_analytics` 13.0.1은 Android Privacy Sandbox 권한 `ACCESS_ADSERVICES_AD_ID`와 `ACCESS_ADSERVICES_ATTRIBUTION`(광고 측정과 귀속용)도 합쳐 넣는다. 2026-10-29 `./gradlew :app:processReleaseMainManifest`의 병합 manifest에서 확인했고, AD_ID와 같이 `tools:node="remove"`로 뺀다([병합 규칙](https://developer.android.com/build/manage-manifests#merge_rule_markers)).

- Google 신호, Google Ads 연결, BigQuery 연결은 켜지 않는다.
- **사용자 ID(`setUserId`)는 설정하지 않는다.**
  - 계정과 연결하지 않으면 분석 데이터는 계정 데이터가 아니다. 그래서 탈퇴 때 지울 것이 없다.
  - 연결하면 탈퇴할 때 GA 사용자 삭제 API를 불러야 한다. 이 API는 OAuth 권한(`analytics.edit`)이 필요하므로 서버 비밀이 하나 더 생긴다([사용자 삭제 API](https://developers.google.com/analytics/devguides/config/userdeletion/v3)).
  - 1절의 질문은 모두 기기 단위로 답할 수 있다.
- **보존 기간**: GA 속성의 데이터 보존을 이벤트 데이터 2개월, 사용자 데이터 2개월로 두고 "새 활동 시 재설정"은 끈다. 이 설정은 탐색 분석과 유입경로 보고서에만 적용된다. 표준 보고서의 합계(예: 날짜별 사용자 수)는 계속 남는다([데이터 보존](https://support.google.com/analytics/answer/7667196)).
- **탈퇴**: 탈퇴 순서(ADR 0001 §5)에 더할 것은 없다. 분석 데이터는 계정과 연결되지 않고, 개별 기록은 2개월 뒤 사라진다. 같은 기기의 앱 인스턴스 ID는 탈퇴 뒤에도 그대로다.
- **동의 화면은 두지 않는다.** 처리방침에 공개한다. 법적으로 이것으로 충분한지는 확인하지 못했다(아래 "확인하지 못한 것").

**개인정보처리방침에 더할 문구** (ADR 0001 §6의 `/privacy/` 페이지)

> **앱 이용 통계**: 앱을 개선하기 위해 Google Firebase Analytics로 앱 이용 기록(앱 실행, 하루 학습 시작·완료·중단, 문제별 채점 결과, 로그인 여부)과 기기 정보(기기 모델, OS·앱 버전, 앱 설치마다 무작위로 만든 식별자, IP 주소로 추정한 대략적인 지역)를 수집합니다. 이 기록은 Google 계정의 이름·이메일과 연결하지 않으며, 광고 ID는 수집하지 않습니다. 개별 기록은 2개월 뒤 삭제되고, 그 뒤에는 날짜별 이용자 수 같은 합계 통계만 남습니다.
>
> **개인정보의 국외 이전**: 이전받는 자 Google LLC(연락처: 작성할 때 Google 개인정보처리방침에서 확인해 적는다) / 이전 국가: 미국 등 Google 데이터센터 소재국 / 이전 항목: 위 앱 이용 통계 항목 / 이전 시기와 방법: 앱 사용 중 네트워크로 수시 전송 / 목적: 앱 이용 통계 / 보유 기간: 개별 기록 2개월 / 거부 방법과 효과: 앱을 삭제하면 수집이 멈춘다. 이미 모인 개별 기록은 2개월 뒤 삭제된다.

**Play 데이터 보안 양식에 더할 줄** (Analytics만. Crashlytics 줄은 ADR 0007 §8)

| 데이터 유형 | 수집 | 공유 | 목적 | 이유 |
| --- | --- | --- | --- | --- |
| 앱 활동 > 앱 상호작용 | 예 | 아니요 | 분석 | 1절 이벤트 |
| 기기 또는 기타 ID | 예 | 아니요 | 분석 | 앱 인스턴스 ID |
| 위치 > 대략적인 위치 | 예 | 아니요 | 분석 | IP 주소로 대략적인 위치를 추정한다 |

- 공유는 "아니요"다. Google은 우리 대신 처리하는 서비스 제공자이고, Play는 서비스 제공자에게 넘기는 것을 공유로 보지 않는다([데이터 보안 안내](https://support.google.com/googleplay/android-developer/answer/10787469)).
- 전송 중 암호화는 "예"다(TLS, [Analytics의 Play 공개 안내](https://support.google.com/analytics/answer/11582702)).
- Play Console의 광고 ID 선언은 "사용하지 않음"이다.

### 4. Firebase 프로젝트 준비 (사용자가 직접)
1. [Firebase 콘솔](https://console.firebase.google.com)에서 프로젝트를 만든다. Google Analytics 사용을 켠다. 보고 시간대는 대한민국으로 한다.
2. Firebase CLI를 설치하고 `firebase login` 한다. `dart pub global activate flutterfire_cli`로 FlutterFire CLI를 설치한다.
3. `app/`에서 `flutterfire configure`를 실행한다. 플랫폼은 Android만 고르고, 패키지 이름은 `com.hootbee.mannerfit`이다. Firebase에 Android 앱이 등록되고 `lib/firebase_options.dart`가 생긴다([Flutter 설정](https://firebase.google.com/docs/flutter/setup?platform=android)). `google-services.json`이나 Gradle 파일도 바뀌면, 바뀐 파일 목록을 PR 본문에 적는다.
4. **공개 리포에 올려도 되나**: Firebase 공식 문서는 Firebase용 API 키가 비밀이 아니고 코드나 커밋한 설정 파일에 넣어도 된다고 한다. 데이터 보호는 키를 숨기는 것이 아니라 보안 규칙과 App Check가 맡는다([API 키](https://firebase.google.com/docs/projects/api-keys)). `firebase_options.dart`도 "비밀이 아닌 식별자"라고 적혀 있다. 그래서 두 파일을 리포에 커밋한다(2026-10-27 사용자, 열린 질문 1).
   - Google Cloud 콘솔의 사용자 인증 정보에서, Firebase가 만든 키가 Firebase API로만 제한되어 있는지 확인한다. 같은 프로젝트에 다른 용도(예: Gemini)의 키를 만들지 않는다.
5. GA 속성 설정에서 데이터 보존을 3절대로 바꾼다.
6. GA 속성의 맞춤 측정기준(이벤트 범위)에 `day_id`, `scene`, `scenario_id`, `grade`, `retry`를 등록한다. 등록해야 보고서에서 파라미터 값으로 나눠 볼 수 있다.
7. 출시 전에 Play Console에서 광고 ID 선언과 데이터 보안 양식(3절)을 채운다.
8. 이벤트가 잘 가는지 볼 때는 `adb shell setprop debug.firebase.analytics.app com.hootbee.mannerfit`을 실행하고 콘솔의 DebugView를 연다. 끌 때는 `adb shell setprop debug.firebase.analytics.app .none.`이다. 평소에는 이벤트를 약 1시간씩 묶어서 보낸다([DebugView](https://firebase.google.com/docs/analytics/debugview)).

### 5. 다른 문서에 미치는 영향 (채택하면서 2026-10-27 함께 고쳤다)
- `docs/decisions.md` 운영 줄: 행동 분석을 Firebase Analytics로 한다는 한 줄을 이번에 더했다(2026-10-27 사용자 승인).
- ADR 0001 §6 `/privacy/`에 적을 것: 제3자에 Firebase Analytics를 더하고, 3절의 문구를 넣는다.
- ADR 0002 §1 표
  - `live/`는 `firebase_analytics`를 import할 수 있다.
  - `main.dart`는 `firebase_core`와 `firebase_options.dart`를 import할 수 있다.
  - 나머지 폴더는 `package:firebase_`를 import할 수 없다.
- 루트 `CLAUDE.md`·`README.md`의 공개 리포 규칙: 막는 대상을 비밀 키(서비스 키, DB 비밀번호, Claude API 키)로 좁히고, Firebase 설정 파일은 커밋한다고 적었다.

## 고려한 대안
- **화면에서 직접 보내거나 `backend.dart`에 `log()` 메서드를 두기**: 화면이 이벤트 이름과 시점을 알아야 하고, 가짜 구현에도 메서드가 생긴다. 이벤트 시점이 이미 `Backend` 메서드와 같으므로 필요 없다.
- **Supabase에 이벤트 테이블 두기**: 테이블, RLS, 동기화, 탈퇴 삭제, 보고 화면을 모두 우리가 만들어야 한다. 게스트는 로그인 전이라 올릴 수도 없다(RLS는 `authenticated`만 받는다).
- **`answer` 없이 4개만 두기**: 게스트의 풀이는 서버에 없으므로, 문제별 정답률을 로그인한 사용자 것만으로 보게 된다.

## 결과
- **쉬워지는 것**: 화면, 가짜 구현, `backend.dart`는 그대로다. 보고서는 Firebase 콘솔에서 바로 본다.
- **어려워지는 것**: 처리방침과 데이터 보안 양식에 적을 것이 는다. 한 사람이 기기 두 대를 쓰면 두 명으로 센다. 이벤트는 최대 약 1시간 늦게 보인다.
- **확인할 점**
  - 네트워크 없음: `logEvent`는 기다리지 않고, 학습은 로컬 기록만으로 돈다. 오프라인 이벤트를 기기에 얼마나 두었다가 보내는지는 확인하지 못했다. 일부가 빠져도 통계용이므로 받아들인다.
  - 같은 요청 두 번: 이벤트는 받아들여진 호출에서만 보낸다. `answer`는 `Asking`일 때만 받고, `next`는 `Finished`에서 무시하므로(ADR 0002 결과 절) 두 번 탭해도 한 번만 간다.
  - 기기 두 대: 앱 인스턴스마다 따로 센다. 로그인 전환율도 기기 기준이다.
  - 탈퇴: 할 일이 없다. 분석 데이터는 계정과 연결되지 않는다.
  - 콘텐츠 업데이트: id는 지우거나 다른 뜻으로 다시 쓰지 않으므로(ADR 0003 §1) 버전이 바뀌어도 같은 문제끼리 모인다.
- **넣지 않은 것과 넣을 시점**
  - 화면 이동 기록(`NavigatorObserver`로 `screen_view`): 이벤트 5개로 답하지 못하는 화면 이동 질문이 생기면.
  - 사용자 속성(user property): 사용자를 나눠 볼 기준(예: 로그인 여부별 재방문)이 필요해지면.
  - 디버그 빌드 수집 끄기: 개발 중 이벤트가 보고서를 흐리면.
  - BigQuery 내보내기: 문제 수천 개의 `scenario_id`가 표준 보고서에서 "(other)"로 묶여 안 보이면.
- **다시 볼 조건**: iOS 출시 때(광고 식별자 설정이 다르다), 법률 확인 결과 동의나 거부 수단이 필요할 때, 사용자 ID가 필요해질 때, 앱에 광고를 넣을 때.

## 작업 목록
4절 1~3이 끝나야 2·4를 시작할 수 있다. 2·3·4는 ADR 0002 작업 11(`live/`)과 같은 시기에 한다.

| # | 담당 | 작업 | 먼저 쓸 실패하는 테스트 |
| --- | --- | --- | --- |
| 1 | 사용자 | 4절 1~3: Firebase 프로젝트, `flutterfire configure`, `firebase_core`, `main.dart`에서 `Firebase.initializeApp` | 설정이라 테스트를 먼저 쓰지 않는다. 기기에서 DebugView에 `first_open`이 보이는지 손으로 확인한다 |
| 2 | 사용자 | 경계 검사 | `boundaries_test`: `live/` 밖의 `lib/` 파일이 `package:firebase_analytics`를 import하면 실패한다 |
| 3 | 사용자 | 광고 ID 끄기(3절 manifest) | `app/test/manifest_test.dart`: `AndroidManifest.xml`에 `google_analytics_adid_collection_enabled`가 `false`인 `meta-data`와 AD_ID 권한의 `tools:node="remove"`가 없으면 실패한다 |
| 4 | 사용자 | `live/`에서 이벤트 5개 보내기 | 기록용 `log`를 넣은 `LiveBackend`에서 첫 문제에 `best`를 두 번 탭하면 `logged`가 `[('answer', {scenario_id: <그 문제 id>, grade: 'best', retry: 0})]` 하나뿐이다. 이어서: `startDaily()` → `daily_start` 하나, 둘째 장면에서 `quit()` → `daily_quit`의 `scene`이 2, 세트를 끝까지 풀면 `daily_complete` 하나, `signIn()`이 `cancelled`면 `login`이 없다. 모든 파라미터 값은 `String`이나 `int`다 |
| 5 | 사용자 | 4절 5~7: 보존 기간, 맞춤 측정기준, Play Console 선언. 처리방침에 3절 문구 넣기(ADR 0001 §6 페이지 작업) | 콘솔 설정과 문서라 테스트를 먼저 쓰지 않는다. 출시 점검표에서 확인한다 |
| 6 | 사용자 | AdServices 광고 권한 빼기(3절 manifest) | `manifest_test`: `ACCESS_ADSERVICES_AD_ID`와 `ACCESS_ADSERVICES_ATTRIBUTION` 각각에 `tools:node="remove"`인 `uses-permission`이 하나씩 없으면 실패한다. 작업 4 머지 뒤 `processReleaseMainManifest`의 병합 manifest에 두 권한이 없는지 손으로 확인한다 |

## 열린 질문 (사용자 결정 필요)
없음.

정해진 것(2026-10-27 사용자): 1은 (A) 설정 파일을 커밋한다. 2는 (A) 처리방침에 "거부하려면 앱을 삭제한다"고 적는다. 3은 계정 정보에 대한 규칙으로 읽고 `docs/decisions.md`의 그 줄은 그대로 둔다. 분석이 무엇을 모으는지는 이 ADR과 처리방침에 적는다. 아래는 결정할 때 비교한 내용이다.

1. **Firebase 설정 파일을 공개 리포에 커밋할지**: 루트 `CLAUDE.md`와 `README.md`는 "API 키를 코드, 설정, 문서 어디에도 넣지 않는다"고 한다. 하지만 `firebase_options.dart`와 `google-services.json`에는 Firebase API 키가 들어 있다.
   - (A) 커밋한다. `CLAUDE.md` 규칙을 "비밀 키(서비스 키, DB 비밀번호, Claude API 키)"로 좁히고, Firebase 설정 키는 공개 식별자라고 적는다. 근거는 Firebase 공식 문서(4절 4번)다. 팀원과 CI가 따로 준비할 것이 없다. GitHub 비밀 검사 경고가 뜰 수 있다.
   - (B) `.gitignore`에 넣는다. 팀원은 파일을 따로 받고, CI에서 빌드하게 되면 GitHub 시크릿으로 넣는다. 설정 단계가 늘고, 파일이 없어 빌드가 깨지는 일이 생긴다.
   - 추천: (A). `CLAUDE.md` 수정은 사람이 한다.
2. **분석을 거부하는 방법**: 처리방침에 거부 방법과 그 효과를 적어야 한다.
   - (A) 처리방침에 "거부하려면 앱을 삭제한다"고만 적는다. 코드 변경이 없다. 이것으로 법적으로 충분한지는 확인하지 못했다.
   - (B) 설정 화면에 "이용 통계 보내기" 스위치를 둔다(`setAnalyticsCollectionEnabled`). `backend.dart`에 값 하나와 메서드 하나, 가짜 구현, 화면이 바뀐다.
   - 추천: (A)로 시작한다. 출시 전 법률 확인(아래 1번)에서 앱 안 거부 수단이 필요하다고 나오면 (B)로 간다.
3. **`docs/decisions.md` 개인정보 줄의 뜻**: "Google 계정의 이름과 이메일만 받는다"를 계정 정보에 대한 규칙으로 읽었다. 분석은 기기 식별자와 대략적인 위치를 모으지만 계정과 연결하지 않으므로, 그 줄과 어긋나지 않는다고 봤다. 이렇게 읽어도 되는지 확인이 필요하다. 다르게 읽는다면 그 줄을 고쳐야 한다.

## 확인하지 못한 것
- 한국 개인정보 보호법에 관한 것
  - 분석 목적 처리가 동의 없이 되는지(제15조 제1항의 계약 이행 범위에 들어가는지).
  - 국외 이전을 제28조의8에 따라 처리방침 공개만으로 할 수 있는지. 조문상 공개 항목(이전받는 자, 국가, 항목, 시기·방법, 목적·보유 기간, 거부 방법·효과)은 확인했다.
  - 자동 수집 장치의 운영과 거부 방법을 처리방침에 적어야 한다는 조항의 원문.
  - 앱 인스턴스 ID가 개인정보에 해당하는지.
- GA 속성 데이터 보존의 기본값(공식 문서에 기본값이 적혀 있지 않았다).
- 오프라인일 때 이벤트를 기기에 얼마나 두는지, 얼마나 늦게 도착한 이벤트까지 받는지.
- `flutterfire configure`가 Android에서 `google-services.json`과 Gradle 파일을 어떻게 바꾸는지. 설정 문서에는 `firebase_options.dart`만 나온다.
- Play 데이터 보안 양식의 Analytics 항목에 대한 Google 공식 대응표. 3절 표는 Play의 데이터 유형 정의에 맞춰 고른 것이다.
- Analytics 데이터가 처리되는 정확한 국가 목록. Google 신호의 기본값.
- 표준 보고서에서 `scenario_id` 값 수천 개를 모두 볼 수 있는지.
- GitHub 비밀 검사가 Firebase API 키에 경고를 띄우는지.

## 참고 (2026-10-27 확인)
- Firebase: [자동 수집 이벤트](https://support.google.com/firebase/answer/9234069), [Event 이름 규칙과 예약 이름](https://firebase.google.com/docs/reference/android/com/google/firebase/analytics/FirebaseAnalytics.Event), [Flutter 이벤트](https://firebase.google.com/docs/analytics/flutter/events), [Android 데이터 수집 설정](https://firebase.google.com/docs/analytics/android/configure-data-collection), [API 키](https://firebase.google.com/docs/projects/api-keys), [Flutter 설정](https://firebase.google.com/docs/flutter/setup?platform=android), [DebugView](https://firebase.google.com/docs/analytics/debugview), [요금](https://firebase.google.com/pricing), [Play 공개 안내(Firebase)](https://firebase.google.com/docs/android/play-data-disclosure)
- Google Analytics: [이벤트 이름 규칙](https://support.google.com/analytics/answer/13316687), [수집 한도](https://support.google.com/analytics/answer/9267744), [데이터 보존](https://support.google.com/analytics/answer/7667196), [Play 공개 안내(Analytics)](https://support.google.com/analytics/answer/11582702), [사용자 삭제 API](https://developers.google.com/analytics/devguides/config/userdeletion/v3)
- Android·Play: [AD_ID 권한](https://developers.google.com/android/reference/com/google/android/gms/ads/identifier/AdvertisingIdClient.Info), [광고 ID](https://support.google.com/googleplay/android-developer/answer/6048248), [데이터 보안 양식](https://support.google.com/googleplay/android-developer/answer/10787469)
- 법령: [개인정보 보호법](https://www.law.go.kr/법령/개인정보보호법) 제15조, 제28조의8, 제30조
- 기준 문서: `docs/decisions.md`(운영, 개인정보), `docs/concept.md`(AI 활용 방식 6번, 화면), ADR 0001 §1·§5·§6, ADR 0002 §1·§2·결과 절, ADR 0003 §1, ADR 0004

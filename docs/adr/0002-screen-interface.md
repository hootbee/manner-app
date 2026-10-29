# 0002. 화면 경계: 모듈 의존 방향, 화면 인터페이스, 가짜 구현

상태: 채택
날짜: 2026-10-25

## 배경
팀은 두 명이다. 사용자는 백엔드(콘텐츠, 엔진, 동기화, 인증)를 맡고, 팀원은 화면과 디자인을 맡는다. 팀원은 개발 경험이 적다. 팀원이 백엔드가 끝나기 전에 가짜 데이터로 모든 화면을 만들 수 있어야 하고, DB·동기화·엔진 코드는 열어 보지 않아도 되어야 한다. 그래서 경계를 먼저 긋는다. `app/`은 아직 `flutter create`의 카운터 예제다(Flutter 3.41.2 stable).

화면 흐름의 기준은 견본(`docs/prototype/index.html`)이다. 와이어프레임(`docs/design/app-wireframe/`)의 장면 선택(B1), 레슨 완료(B5), 카카오·Apple 로그인(A5)은 `docs/decisions.md`(하루 3장면, 중간 저장 없음, Google만)와 맞지 않으므로 따르지 않는다.

## 결정
### 1. 모듈과 의존 방향
| 폴더 (`app/lib/`) | import 해도 되는 앱 코드 | 비고 |
| --- | --- | --- |
| `content/` | 없음 | 번들 JSON 로드, `vary` 펼치기. 형식은 ADR 0003 |
| `engine/` | `content/` | 순수 Dart. Flutter, Supabase 금지. 기록 타입(`Attempt`, `DayCompletion`)을 여기 둔다 |
| `sync/` | `engine/`의 기록 타입 | 로컬 기록 파일과 `sync(table)`(ADR 0001 §3, ADR 0005) |
| `auth/` | 없음 | Google 로그인, `delete-account` 호출, 전송 오류 판정 `isOffline`(`live/`도 쓴다, ADR 0007 §2) |
| `backend.dart` | 없음 (`package:flutter/foundation.dart`만) | 화면이 보는 인터페이스와 값 타입(2절) |
| `logged_backend.dart` | `backend.dart` | 화면 동작을 크래시 보고에 기록하는 감싸개. `log` 함수를 받고 Firebase를 import하지 않는다(ADR 0007 §4) |
| `live/` | `backend.dart`, `content/`, `engine/`, `sync/`, `auth/` | 인터페이스의 실제 구현. 펼친 문제를 화면 `Question`·`Explanation`으로 옮기고 채점과 세트 진행(다시 풀기)을 한다. 학습 계산은 `engine/`을 부른다. 분석 이벤트를 보낸다(ADR 0006) |
| `fake/` | `backend.dart` | 가짜 구현(3절) |
| `screens/` | `backend.dart` | Supabase, `google_sign_in`, 다른 앱 폴더 전부 금지 |
| `main.dart` | `backend.dart`, `logged_backend.dart`, `screens/`, `fake/`, `live/`, `firebase_options.dart` | 구현 하나를 골라 넣는다 |

패키지는 `firebase_analytics`를 `live/`만, `firebase_core`와 `firebase_crashlytics`를 `main.dart`만 import한다. 나머지 폴더는 `package:firebase_`를 import하지 않는다(ADR 0006, 0007).

Dart에는 폴더 단위 공개 범위가 없으므로 `app/test/boundaries_test.dart`가 `lib/` 아래 import 줄을 읽어 위 표를 검사한다. 패키지(`import_lint` 등)는 쓰지 않는다.

### 2. 화면 인터페이스 (`app/lib/backend.dart`)
화면은 아래 타입만 안다. 모든 값은 화면에 그대로 그릴 수 있는 모양이다. 풀이 기록, Leitner 단계, 동기화 상태는 드러내지 않는다.

```dart
late Backend backend; // main.dart와 테스트 setUp에서 넣는다

abstract interface class Backend {
  ValueListenable<Home> get home;
  ValueListenable<List<AreaStat>> get stats; // 영역 6개, 고정 순서
  ValueListenable<Account?> get account;     // null이면 게스트
  ValueListenable<bool> get online;
  Session startDaily();                       // home.value.today!.doneToday면 부르지 않는다
  Future<SignInResult> signIn();
  Future<SignOutResult> signOut({bool discardUnsynced = false});
  Future<DeleteResult> deleteAccount();
  // 카테고리 연습: 기준이 정해지면 `Session startPractice(String categoryId)` 하나를 더한다.
}

class Home { final DayCard? today; final int streak, reviewsDue, xp, level; final double levelProgress; } // today가 null이면 준비된 하루가 없다
class DayCard { final int number; final String title; final List<SceneCard> scenes; final bool doneToday; final String? nextTitle; }
class SceneCard { final String time, title, short; }
class AreaStat { final String area; final int value; } // 0~100. 공식은 엔진 ADR
class Account { final String name, email; }

enum SignInResult { ok, cancelled, offline, failed }
sealed class SignOutResult {} class SignedOut extends SignOutResult {}
class WouldLose extends SignOutResult { final int count; } // 확인받고 discardUnsynced: true로 다시 부른다
enum DeleteResult { ok, offline, failed }

abstract interface class Session {           // 세트 하나. Finished 뒤에는 버린다
  ValueListenable<Phase> get phase;
  void answer(Answer a); // Asking일 때만 받는다. 두 번째 탭은 무시한다
  void next();           // Intro → Asking, Answered → 다음 문제·장면·Finished. Finished로 갈 때 하루 완료를 기록한다
  void quit();           // 중간 저장 없음. 이미 답한 기록과 XP는 남는다
}
sealed class Phase { final double progress; }  // 0~1, 진행 바. 다시 풀기가 붙으면 줄 수 있다
class Intro extends Phase { final String dayTitle, intro; final SceneCard scene; }
class Asking extends Phase { final Question q; final bool retry; }       // retry: "다시 풀기" 칩
class Answered extends Phase { final Question q; final Explanation e; final SceneCard? nextScene; final bool last; } // 다시 풀기 문제의 nextScene은 null. last는 남은 문제가 없을 때만 참
class Finished extends Phase { final int xpGained, firstTry, total, bestCombo; final int? streak; final List<String> retryTomorrow; } // streak: 데일리만

sealed class Question { final String area, prompt, motto; }              // area: 영역 칩, motto: 원칙 문구
class PositionQuestion extends Question { final String template, me, other; final Map<String, Object> vars; final List<Spot> spots; } // vars: mirror, direction 등
class ChoiceQuestion extends Question { final List<Option> options; }   // 이미 섞인 표시 순서
class OxQuestion extends Question {}
class OrderQuestion extends Question { final List<Option> cards; }      // 이미 섞인 순서
class Spot { final String id, label; }  class Option { final String id, text; }

sealed class Answer {}
class PickSpot extends Answer { final String id; }  class PickOption extends Answer { final String id; }
class PickOx extends Answer { final bool o; }    class PlaceOrder extends Answer { final List<String> ids; }

enum Grade { best, ok, avoid }
class Explanation {
  final Grade grade; final int xp, combo; final String title, why; // xp는 10·5·0. combo는 연출용(보너스 XP 없음)
  final List<String> correct;               // position [spotId], choice [optionId], ox ['o'|'x'], order 카드 id 순서
  final Map<String, ({Grade grade, String? note})> options; // choice만. 나머지는 빈 맵
  final Evidence? evidence;                 // 출처가 없으면 null → "근거 보기" 숨김
}
class Evidence { final String summary; final List<Source> sources; }  class Source { final String title, publisher, date, locator, url; }
```

- 위는 필드만 보인 것이다(생성자는 구현할 때 붙인다). `Account`, `Phase`는 Supabase `User`, Material `Step`·`Card`와 이름이 겹치지 않게 골랐다.
- 화면이 쓰는 콘텐츠 모양은 `Question`, `Explanation`, `Evidence`까지다. JSON 변환 규칙, id, 버전, Storage는 ADR 0003에서 정한다.
- MVP에서 빼는 것: 원칙 스킬, 칭호, 옷장·옷차림 아이템, 약한 매너(2026-10-25 사용자 결정). 인터페이스에 자리도 만들지 않는다.

### 3. 가짜 구현 (`app/lib/fake/`)
- `fake_backend.dart`: `FakeBackend implements Backend`. 메모리에만 상태를 둔다. 채점은 `correct`와 비교, XP는 10·5·0, `best`가 아니면(`ok` 포함) 같은 문제를 세트 맨 뒤에 `retry: true`로 다시 내고(맞힐 때까지, ADR 0004 §4), 마지막 `next()`에서 `streak + 1`, `doneToday = true`가 된다. 비동기 메서드는 `delay`(기본 300ms)만큼 기다려 로딩 표시를 볼 수 있게 한다.
- `samples.dart`: `docs/prototype/content.json`에서 옮긴 고정 데이터. 하루는 `day-01`(3장면), 문제는 `A-sidewalk`(연인·오른쪽), `A-alley`(다시 풀기용), `A-stairs`(할머니·올라감), `A-umbrella-01`, `A-crosswalk-01`. 순서 형식은 견본에 예가 없으므로 가짜 문제 하나를 쓰고 `// 가짜` 주석을 단다.
- 경계 상태는 생성자 인자로 만든다: `FakeBackend({bool online = true, Account? account, bool doneToday = false, bool noDay = false, SignInResult signIn = ok, int unsynced = 0, DeleteResult delete = ok, Duration delay})`. 테스트에서는 `fake.setOnline(false)`로 바꿀 수 있다.
- 실행할 때는 이름 붙은 묶음을 고른다: `flutter run --dart-define=FAKE=<이름>`. 이름은 `guest`(기본, 첫 실행), `signedIn`, `doneToday`, `noDay`, `offline`, `signInFails`, `wouldLose`, `deleteFails`. 팀원이 버튼으로 고를 수 있게 `.vscode/launch.json`에 묶음마다 실행 설정을 둔다.

```dart
// app/lib/main.dart. 처리기, trimStack, 감싸개는 ADR 0007 §1·§4
const fake = String.fromEnvironment('FAKE');
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform); // ADR 0006 §2
  final crashlytics = FirebaseCrashlytics.instance;
  FlutterError.onError = (details) =>
      crashlytics.recordFlutterFatalError(details.copyWith(stack: trimStack(details.stack)));
  PlatformDispatcher.instance.onError = (error, stack) {
    crashlytics.recordError(error, trimStack(stack), fatal: true);
    return true;
  };
  final inner = (kReleaseMode || fake.isEmpty) // 릴리스는 항상 실제
      ? await LiveBackend.start(report: (e, s) => crashlytics.recordError(e, trimStack(s))) // 잡은 실패는 non-fatal(ADR 0007 §3)
      : FakeBackend.preset(fake);
  backend = LoggedBackend(inner, log: crashlytics.log);
  runApp(const MyApp());
}
```

### 4. 상태 관리: Flutter 내장 `ValueListenable` + `ValueListenableBuilder`
화면은 `ValueListenableBuilder(valueListenable: backend.home, builder: …)` 한 가지 패턴만 쓴다. 화면 안의 잠깐 상태(시트 열림, 애니메이션)는 `setState`로 한다. 구현 쪽은 `ValueNotifier`로 값을 바꾼다. 추가 패키지는 없다. 구현 객체는 전역 `backend` 하나로 넘긴다.

## 고려한 대안
- `provider`(6.1.5+1, Flutter Favorite): Flutter 아키텍처 권장안은 전역 객체 대신 `provider`로 의존성을 주입하라고 한다. 우리는 객체가 하나이고 시작할 때와 테스트 `setUp`에서만 바꾸므로 전역과 차이가 작다. 화면이 둘 이상의 구현 객체를 받아야 하거나 테스트끼리 상태가 섞이면 넣는다. `backend.x`를 `context.read<Backend>().x`로 바꾸는 기계적 수정이다.
- `flutter_riverpod`(3.4.3), `flutter_bloc`: 초보자가 배울 개념(Provider 종류, 코드 생성, 이벤트·상태 클래스)이 늘고, 이 앱의 상태는 `ValueNotifier` 몇 개로 충분하다.
- 화면이 엔진·동기화를 직접 호출: 팀원이 기록 구조와 오프라인 처리를 알아야 하고, 백엔드가 끝나기 전에는 화면을 만들 수 없다.

## 결과
- **쉬워지는 것**: 팀원은 `backend.dart`와 `fake/`만 보고 모든 화면을 만들고, 경계 상태를 실행 설정 하나로 재현한다. 백엔드는 화면 없이 테스트한다. **어려워지는 것**: 화면에 새 값이 필요하면 `backend.dart`, 가짜, 실제 구현, 감싸개(ADR 0007 §4) 네 곳을 함께 고친다. 인터페이스 변경은 사용자가 한다.
- **확인할 점**
  - 네트워크 없음: 풀이, 하루 완료, 홈 값은 모두 로컬에서 나온다. `online`은 로그인과 탈퇴 버튼에만 쓴다(ADR 0001 §5-1). 게스트는 항상 참이고(로그인 결과 `offline`이 알린다), 로그인한 사용자는 마지막 Supabase 요청이 서버에 닿았는가다(전송 오류인지는 `isOffline`이 판단한다, ADR 0007 §2). 앱이 앞으로 올 때마다 sync해서 연결이 돌아오면 다시 참이 된다. 연결 감지 패키지는 쓰지 않는다.
  - 같은 요청 두 번: `answer`는 `Asking`이 아니면 무시하고, `next`는 `Finished`에서 무시한다. 기록이 두 번 쓰이지 않는다. 실제 구현은 로컬 기록을 쓴 뒤에 `Answered`를 낸다.
  - 기기 두 대: pull 뒤 실제 구현이 `home`, `stats`를 다시 계산해 내보내면 화면은 저절로 다시 그려진다. 자정을 넘겨 켜 둔 앱도 앞으로 올 때 다시 계산한다.
  - 견본과 다른 점: 견본의 콤보 보너스 XP(+5)와 나가기 시트의 "XP는 하루를 마쳐야 받아요" 문구는 ADR 0001 §4와 어긋나므로 화면에 옮기지 않는다.
- **다시 볼 조건**: 카테고리 연습, 오류 신고(설정의 "해설 오류 신고"), 알림 설정을 넣을 때 메서드를 더한다. 오류 신고와 알림은 각자 ADR에서 정한다.

## 작업 목록 (1이 끝나면 2~6과 7~10을 동시에 한다. 11은 7~10 뒤)
| # | 담당 | 작업 | 먼저 쓸 실패하는 테스트 |
| --- | --- | --- | --- |
| 1 | 사용자 | `backend.dart`, `fake/`, 경계 검사, `main.dart` 가짜 연결, `launch.json` | `boundaries_test`: `screens/` 파일이 `backend.dart` 밖의 앱 파일이나 `supabase`를 import하면 실패한다. `fake_backend_test`: 첫 문제에 오답을 내면 같은 문제가 세트 맨 뒤에 `retry: true`인 `Asking`으로 다시 오고, 그것도 틀리면 또 온다. 마지막 `next()` 뒤 `home.value.streak`가 1 늘고 `doneToday`가 참이다 |
| 2 | 팀원 | 홈 | `FakeBackend(doneToday: true)`에서 "하루 시작하기" 버튼이 눌리지 않는다 |
| 3 | 팀원 | 장면 소개, 풀이 4형식, 해설 | `guest`로 세트를 끝까지 탭하면 완료 화면이 나온다(핵심 흐름 위젯 테스트) |
| 4 | 팀원 | 세트 완료, 로그인(설정의 "기록 백업하기") | `FakeBackend(signIn: failed)`에서 로그인을 누르면 실패 안내가 보이고 게스트로 남는다 |
| 5 | 팀원 | 스테이터스(영역 육각형) | 레이아웃이므로 테스트를 먼저 쓰지 않는다(`CLAUDE.md`) |
| 6 | 팀원 | 설정: 로그아웃, 탈퇴, 개인정보처리방침 링크 | `offline`에서 탈퇴 버튼이 막혀 있다. `FakeBackend(unsynced: 3)`에서 로그아웃하면 "3개" 확인 시트가 뜬다 |
| 7 | 사용자 | `content/`: 번들 JSON → 펼친 문제(`Json`) (ADR 0003 뒤). 화면 `Question`으로 옮기는 것은 `live/`(11) | `A-sidewalk`가 8문제로 펼쳐지고 펼친 문제의 `vars['mirror']`가 축 값과 같다 |
| 8 | 사용자 | `engine/`: XP, 레벨, 연속 학습일, Leitner, 영역 스탯, 출제 순서 | ADR 0001 §4 규칙 그대로: `best, ok, avoid` 세 기록의 XP는 15다 |
| 9 | 사용자 | `sync/`: 로컬 기록 파일과 `sync(table)`(ADR 0005) | 네트워크 없음, 같은 행 두 번 push, 기기 두 대 pull 뒤 같은 집합(ADR 0001 §3) |
| 10 | 사용자 | `auth/`: Google 로그인, 탈퇴 순서. Android는 nonce 없이 ID 토큰을 보낸다(iOS 출시 때 다시 본다) | `delete-account`가 401을 주고 세션 갱신도 거절되면 로컬 기록이 지워지고 결과는 실패다(ADR 0001 §5-4) |
| 11 | 사용자 | `live/`, `main.dart` 전환 | `answer()` 한 번에 로컬 `attempts`에 `synced=false` 행이 하나 생기고 `home.value.xp`가 10 는다 |

## 열린 질문 (사용자 결정 필요)
정해진 것(2026-10-25 사용자): 주간 보상은 뺀다. 레벨은 100 XP마다 1 오른다. 장면당 2문제(하루 약 6문제). 하루 돌아보기와 시간 제한 모드는 MVP에서 뺀다(`timeLimit` 필드 없음). 별도 체험 세트는 없고 게스트로 `day-01`부터 시작하며, 로그인은 사용자가 원할 때 한다. 영역 스탯은 0~100 육각형이다. 이 결정들로 인터페이스는 바뀌지 않는다.

1. **영역 목록**: `content.json`의 `친구·가족`(A-sidewalk)은 영역 6개에 없다(견본은 `친구`로 센다). 영역 목록은 ADR 0003에서 고정한다.

## 참고 (2026-10-25 확인)
Flutter [아키텍처 권장안](https://docs.flutter.dev/app-architecture/recommendations), [상태 관리 선택지](https://docs.flutter.dev/data-and-backend/state-mgmt/options), [ValueListenableBuilder](https://api.flutter.dev/flutter/widgets/ValueListenableBuilder-class.html), [빌드 모드](https://docs.flutter.dev/testing/build-modes), [Dart 클래스 수식어](https://dart.dev/language/class-modifiers) · [provider](https://pub.dev/packages/provider), [flutter_riverpod](https://pub.dev/packages/flutter_riverpod)

# 0005. 기기 안 기록 저장소와 `sync/` 구현

상태: 채택
날짜: 2026-10-27

## 배경
ADR 0001 §3이 동기화 규칙(`synced`, `sync(table)`, push 500·pull 1000, `(created_at, id)` 커서와 5분 겹침, 게스트·로그아웃, 기기 두 대)을 정했고, §5가 탈퇴 때 지우는 순서를 정했다. 그 규칙을 **기기 안 어디에 어떻게 저장하고, 어떤 함수로 내보내고, 어떻게 테스트할지**는 아직 정하지 않았다. ADR 0002 작업 9(`sync/`)와 11(`live/`)을 시작하려면 지금 정해야 한다. 여기서는 ADR 0001의 규칙을 다시 정하지 않고 가리키기만 한다.

규모: 하루 6~10행, 1년에 약 4,000행이다. 1행은 JSON으로 약 140바이트이므로 1년이면 약 560KB다. 필요한 동작은 넷이다: 반쯤 쓴 상태가 남지 않는 쓰기, 같은 id 무시(합집합), `synced` 바꾸기, 커서 저장.

원칙은 "언제나 단순한 시스템"(2026-10-25 사용자)이다. 규칙마다 한 문장으로 쓰고, 예외 규칙과 조정 손잡이를 두지 않고, 의존성을 최소로 한다.

## 결정
### 1. 저장소: JSON 파일 하나 (새 의존성 없음)
- 기록과 커서를 파일 `records.json` 하나에 둔다. 앱을 켤 때 한 번 읽어 메모리에 두고, 바뀔 때마다 파일 전체를 다시 쓴다.
- 쓰기는 `records.json.tmp`에 전부 쓰고(`flush: true`) `records.json`으로 `rename`한다. rename은 한 번에 바뀌므로 앱이 중간에 죽어도 옛 파일이나 새 파일 중 하나가 온전히 남는다(ADR 0003 §5 콘텐츠 받기와 같은 방법).
- 쓰기는 동기(`writeAsStringSync`)로 한다. 함수가 돌아오면 이미 디스크에 있으므로 "로컬 기록을 쓴 뒤에 `Answered`를 낸다"(ADR 0002 결과 절)가 그대로 지켜진다.
- 파일 위치는 `live/`가 `path_provider`의 `getApplicationSupportDirectory()` 아래로 정해서 `File`로 넘긴다. `sync/`는 경로를 모른다.
- 파일을 읽다가 실패하면 예외를 그대로 던진다. 지우고 새로 시작하지 않는다(기록이 사라지는 것보다 Crashlytics에 보이는 편이 낫다).

측정(2026-10-27, M 시리즈 Mac 호스트): 4,000행(564KB) 파일 전체 쓰기 평균 4.9ms, 읽기 3.9ms. Android 기기는 이보다 느리다. 실제 기기 값은 아직 재지 않았다.

### 2. 파일 형식
```json
{
  "attempts": [
    {"id": "…", "scenario_id": "A-sidewalk~partner.right", "grade": "best", "solved_on": "2026-10-27", "synced": false}
  ],
  "day_completions": [
    {"id": "…", "day_id": "day-01", "completed_on": "2026-10-27", "synced": true}
  ],
  "cursors": {
    "attempts": {"created_at": "2026-10-27T01:02:03.123456Z", "id": "…"}
  }
}
```
- **행** = 서버 insert 권한이 있는 컬럼(ADR 0001 §2의 `grant insert (…)`) + `synced`. `user_id`와 `created_at`은 두지 않는다. 게스트 행에는 `user_id`가 없고, `created_at`은 서버가 정하며, 둘 다 push로 보내면 권한 오류가 나기 때문이다. 이 규칙 하나로 앞으로 생길 같은 모양의 테이블(ADR 0001 §3)도 코드 수정 없이 들어간다.
- **커서**는 테이블 이름마다 하나다. 로그아웃·탈퇴 때 파일을 통째로 지우므로 한 파일에는 한 사용자의 기록만 있다. 그래서 ADR 0001 §3의 "사용자마다"는 따로 키를 두지 않아도 지켜진다.
- 키가 없으면 빈 것으로 읽는다. 버전 필드는 두지 않는다(형식을 호환되지 않게 바꿀 때 넣고, 없으면 1로 본다).
- 날짜는 `YYYY-MM-DD` 문자열이다. `Attempt.solvedOn`의 연월일로 만든다(시각과 시간대는 버린다, ADR 0004 §1).

### 3. Supabase 클라이언트
- `pubspec.yaml`에는 `supabase_flutter`만 넣는다. `auth/`가 세션 저장과 로그인 때문에 어차피 쓰고, `supabase_flutter`는 `package:supabase/supabase.dart`를 그대로 다시 내보낸다(2.18.3 소스에서 확인). `supabase`를 따로 넣으면 버전 두 개를 맞춰야 하므로 넣지 않는다.
- `sync/`는 생성자로 `SupabaseClient`를 받는다. 쓰는 것은 `from(table)`, `auth.currentUser`, `auth.signOut(scope: SignOutScope.local)` 셋뿐이다. `Supabase.initialize`와 `Supabase.instance`는 `live/`만 부른다. 그래야 테스트가 자기 클라이언트를 넣을 수 있다.
- 화면 경계(ADR 0002 §1)는 그대로다. `screens/`는 `sync/`도 Supabase도 모른다. `boundaries_test`에 `sync` 줄을 더한다: `engine/` 밖의 앱 폴더와 `package:flutter`, `dart:ui`를 막는다(`supabase_flutter`는 허용).

### 4. 공개 API (`app/lib/sync/store.dart` 한 파일)
```dart
import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../engine/engine.dart';

const tables = ['attempts', 'day_completions'];

/// 새 기록 id. UUID v4를 Random.secure()로 만든다(uuid 패키지 안 씀).
String newId();

class Store {
  /// 파일이 없으면 빈 저장소다. 읽지 못하면 예외를 던진다.
  Store(File file, SupabaseClient client);

  List<Attempt> get attempts;              // 엔진에 넘길 집합. 순서는 의미 없다
  List<DayCompletion> get dayCompletions;
  int get unsynced;                        // 모든 테이블의 synced=false 행 수. 로그아웃 확인의 N

  void addAttempt(Attempt a);              // synced=false로 파일에 쓰고 돌아온다. 이미 있는 id면 아무것도 안 한다
  void addDayCompletion(DayCompletion d);  // 위와 같다

  Future<void> sync(String table);         // ADR 0001 §3의 push 뒤 pull. 로그인 전이면 바로 끝난다. 오류는 그대로 던진다
  Future<void> clear();                    // 앞선 sync가 끝나면 파일과 메모리를 지우고 signOut(local)
}
```
규칙(한 줄씩)
- `sync`와 `clear`는 한 줄로 서서 차례로 돈다(`Future` 하나에 이어 붙인다). 그래서 sync가 겹쳐도, 지우는 도중에 받은 행이 다시 쓰이지 않는다.
- push: `synced=false` 행을 앞에서 500개씩 `upsert(rows, onConflict: 'id', ignoreDuplicates: true)`로 보내고, 성공하면 그 행을 `synced=true`로 바꿔 저장한다. 남은 행이 없을 때까지 반복한다.
- pull: ADR 0001 §3 그대로이고, **정렬은 `ascending: true`를 꼭 붙인다**(postgrest-dart의 `order` 기본값은 내림차순이다). 받은 행은 `user_id`, `created_at`을 빼고 `synced=true`로 넣는다. 이미 있는 id는 건드리지 않는다. 페이지마다 커서를 바꾸고 저장한다.
- 시각은 `DateTime.parse(...).toUtc().toIso8601String()`으로 `Z` 형식을 만든다. `+00:00`을 그대로 보내면 `+`가 공백이 되어 실패한다(로컬 PostgREST에서 확인).
- `clear`의 `signOut`은 기기의 세션을 먼저 지우고 서버에 알린다(gotrue 2.27.3 소스). 서버 알림이 실패한 오류는 무시한다.
- 변경 알림은 없다. `live/`는 `add…`나 `sync`가 끝난 뒤 엔진 값을 다시 계산한다.
- 오류 처리는 `live/`가 한다: 네트워크 오류는 무시하고 다음 호출에서 다시 한다. `PostgrestException.code == '23503'`(다른 기기에서 탈퇴함)이면 `clear()`를 부른다(ADR 0001 §5-5).

`live/`가 부르는 순서(ADR 0001 §3·§5를 이 API로 옮긴 것)
- 답할 때 `addAttempt`, 데일리 마지막 `next()`에서 `addDayCompletion`. 앱 시작, 세트 끝, 연결이 돌아왔을 때 `for (t in tables) sync(t)`.
- 로그아웃: `sync` → `unsynced > 0`이고 `discardUnsynced`가 아니면 `WouldLose(unsynced)` → 아니면 `clear()` → Google 로그아웃.
- 탈퇴: `delete-account`가 204 → `clear()` → Google `disconnect()` → 게스트 첫 화면. 세션이 거절되면 ADR 0001 §5-4.

### 5. 테스트: 로컬 Supabase에 직접 붙는다 (가짜 원격 없음)
가짜 원격을 만들려면 Supabase 앞에 인터페이스를 하나 더 둬야 하고, 그 가짜는 RLS, grant, `ignoreDuplicates`가 실제로 어떻게 도는지 알려 주지 못한다. 로컬 Supabase는 이미 있고(ADR 0001 테스트, `delete-account` 테스트) 무료다.

- `test/sync/store_test.dart`: Supabase 없이 늘 돈다. 클라이언트는 `SupabaseClient('http://127.0.0.1:1', 'x')`처럼 닿지 않는 주소로 만든다. 파일과 메모리 규칙, 로그인 전 `sync`를 본다.
- `test/sync/sync_test.dart`: 환경 변수 `SUPABASE_URL`, `SUPABASE_ANON_KEY`, `SUPABASE_SERVICE_ROLE_KEY`가 없으면 skip한다. 사용자는 `delete-account` 테스트처럼 admin으로 만들고 magic link의 `hashed_token`을 `verifyOTP(tokenHash:, type: OtpType.magiclink)`에 넣어 로그인한다. 클라이언트는 `autoRefreshToken: false`로 만든다(테스트가 끝나도 타이머가 남지 않게).
- 세 경우
  - **네트워크 없음**: 로그인한 세션을 `jsonEncode(session)`로 꺼내 `127.0.0.1:1`을 가리키는 클라이언트에 `recoverSession`으로 넣는다(만료 전 세션이면 네트워크를 쓰지 않는다, gotrue 2.27.3 소스). `sync`가 예외를 던지고, `unsynced`와 파일이 그대로이고, 그 뒤 `addAttempt`도 된다.
  - **같은 요청 두 번**(서버는 받았는데 응답이 끊긴 경우): `sync` 전에 파일을 복사해 둔다. 원본으로 `sync`한 뒤 복사본으로 새 `Store`를 열어 다시 `sync`한다. 오류가 없고, 서버 행은 1개, 복사본의 `unsynced`는 0이다.
  - **기기 두 대**: 같은 사용자로 magic link를 두 번 받아 클라이언트 둘, 파일 둘을 만든다. A와 B가 각자 기록을 쓰고 A·B·A 순서로 `sync`하면 두 저장소의 id 집합이 같다.
- 실행: 화면 담당 팀원은 Docker 없이 `flutter test`만 돌려도 된다(Supabase 테스트는 skip). 백엔드 작업 때는 아래처럼 돌린다.
  ```sh
  supabase start
  eval "$(supabase status -o env --override-name api.url=SUPABASE_URL --override-name auth.anon_key=SUPABASE_ANON_KEY --override-name auth.service_role_key=SUPABASE_SERVICE_ROLE_KEY)"
  export SUPABASE_URL SUPABASE_ANON_KEY SUPABASE_SERVICE_ROLE_KEY
  cd app && flutter test
  ```
  키는 로컬 스택의 값이고 매번 `supabase status`에서 읽으므로 리포에 들어가지 않는다.

### 6. 앱 CI (`.github/workflows/app.yml`, 새 파일)
`db.yml`과 같은 버전과 같은 `-x` 목록으로 Supabase를 띄우고, 위 환경 변수를 넣고 `flutter analyze && flutter test`를 돌린다. CI에서는 Supabase 테스트가 skip되지 않는다.
```yaml
name: app
on:
  pull_request:
    branches: [dev]
    paths: [app/**, supabase/**, .github/workflows/app.yml]
permissions:
  contents: read
jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v7
      - uses: subosito/flutter-action@v2
        with: { channel: stable, flutter-version: 3.41.2 }
      - uses: supabase/setup-cli@v3
        with: { version: 2.122.0 }
      - run: supabase start -x studio,imgproxy,mailpit,edge-runtime,logflare,vector,supavisor,realtime,postgres-meta
      - run: |
          env=$(supabase status -o env --override-name api.url=SUPABASE_URL --override-name auth.anon_key=SUPABASE_ANON_KEY --override-name auth.service_role_key=SUPABASE_SERVICE_ROLE_KEY)
          eval "$env"; export SUPABASE_URL SUPABASE_ANON_KEY SUPABASE_SERVICE_ROLE_KEY
          : "${SUPABASE_URL:?}" "${SUPABASE_ANON_KEY:?}" "${SUPABASE_SERVICE_ROLE_KEY:?}"
          cd app && flutter pub get && flutter analyze && flutter test
```
`env=$(…)`는 `supabase status`가 실패하면 그 줄에서 멈춘다(Actions의 bash는 `-e`). status가 성공해도 변수 이름이 빠지면 `:?` 줄에서 멈춘다. 그래서 환경 변수 없이 테스트가 skip된 채 통과하는 일이 없다.

## 고려한 대안
버전은 2026-10-27 pub.dev API 기준이다. 우리 Flutter는 3.41.2다.

| 후보 | 버전 | 고르지 않은 이유 |
| --- | --- | --- |
| `sqlite3` (FFI, 동기 API) | 최신 3.8.0(2026-10-23). Flutter 3.41.2에서는 **3.5.2(2026-08-19)까지만** 풀린다. 3.6.0부터 `hooks ^2.2.0` → `record_use` → `meta ^1.19.0`이 필요한데 Flutter SDK가 `meta 1.17.0`을 고정한다 | 가장 강한 후보다. 3.x는 build hooks로 빌드할 때 GitHub 릴리스의 미리 빌드한 SQLite를 받아(sha256 확인) 앱에 넣는다. `sqlite3_flutter_libs`는 필요 없다(3.0.0 changelog). 직접 확인한 것: 호스트 `flutter test`에서 `openInMemory`가 설정 없이 돈다(SQLite 3.53.4). arm64 디버그 APK에 `lib/arm64-v8a/libsqlite3.so` 1.7MB가 들어간다. 그래도 지금 규모에는 의존성 1개와 ABI당 1.7MB, 첫 빌드 때 네트워크, Flutter 버전과의 묶임, SQL 문자열과 스키마 이전(`user_version`)이 더해질 뿐 얻는 것이 없다 |
| `sqflite` + 테스트용 `sqflite_common_ffi` | 2.4.5(2026-10-21) / 2.4.5(2026-10-22). 2.4.5는 Flutter 3.44 이상이 필요하다 | 패키지 2개. API가 전부 비동기라 쓰기 순서를 따로 챙겨야 한다. 호스트 테스트용 `sqflite_common_ffi`는 내부에서 결국 `sqlite3`를 쓴다 |
| `drift` | 2.35.3(2026-10-23), `drift_flutter` 0.3.1 | `sqlite3` 위에 `build_runner` 코드 생성이 더해진다. 테이블 2개에 비해 배울 것이 많다 |
| `shared_preferences`에 JSON 문자열 | `supabase_flutter`가 이미 가져온다 | 작은 설정값용이다. 수백 KB 문자열을 넣을 곳이 아니고, 언제 디스크에 쓰이는지 보장이 약하다 |

## 결과
- **쉬워지는 것**: 새 의존성이 없다(`supabase_flutter`, `path_provider`는 `auth/`·`live/`에 어차피 필요하다). 저장소 코드는 `Map` 조작과 `save()` 하나다. 같은 모양의 새 테이블은 `tables`에 이름만 더하면 동기화된다. 테스트는 임시 파일 하나면 된다.
- **어려워지는 것**: 답할 때마다 파일 전체를 다시 쓰므로 기록이 늘수록 느려진다. 기록을 조건으로 찾는 쿼리는 없다(엔진은 어차피 전부 훑는다, ADR 0004 결과 절).
- **확인할 점**
  - 네트워크 없음: `add…`와 읽기는 네트워크를 쓰지 않는다. `sync`가 실패해도 행은 `synced=false`로 남아 다음에 다시 간다.
  - 같은 요청 두 번: 로컬은 같은 id를 무시하고, 서버는 `ignoreDuplicates`로 무시한다. sync가 겹쳐 불려도 차례로 돈다.
  - 기기 두 대: ADR 0001 §3 그대로 id 합집합이다. 커서는 서버 시각만 쓰므로 기기 시계가 틀려도 빠지는 행이 없다.
  - 탈퇴·로그아웃: `clear()`는 앞선 sync를 기다린 뒤 지우고 바로 세션을 끊는다. 그래서 지운 뒤 다른 sync가 그 사용자의 기록을 다시 받아 오지 못한다. 앱이 지우기와 세션 끊기 사이에 죽으면 다음 실행에서 같은 사용자로 다시 받아 올 뿐이고, 다른 계정과 섞이지 않는다.
  - 콘텐츠 업데이트: 저장소는 콘텐츠를 모른다. 지우거나 바꾸는 기록이 없다(ADR 0004 §5).
  - 요청이 오래 걸리면(응답 없는 네트워크) 뒤에 선 `clear()`도 기다린다. 시간 제한은 `http` 기본값에 맡긴다.
- **넣지 않은 것과 넣을 시점**
  - `sqlite3`: 실제 Android 기기에서 `addAttempt` 한 번이 16ms(한 프레임)를 넘는 것이 측정되거나 `records.json`이 1MB(약 7,000행, 매일 2년쯤)를 넘으면 옮긴다. 공개 API는 그대로이고, 옮기는 작업은 JSON을 한 번 읽어 넣는 것이다.
  - 쓰기를 백그라운드 isolate로: 위와 같은 조건일 때 `sqlite3`와 함께 본다.
  - 요청 시간 제한: 로그아웃이나 탈퇴가 멈춘 것 같다는 신고가 오면 `SupabaseClient(httpClient:)`에 제한 시간을 둔다.
  - 연결 감지 패키지(`connectivity_plus`): 넣지 않는다. "연결이 돌아왔을 때"는 앱이 앞으로 올 때의 sync로 대신한다(ADR 0002 결과).
- **다시 볼 조건**: 위 측정값, Flutter를 올려 `sqlite3` 3.6 이상이 풀릴 때(대안 비교가 바뀌지는 않는다), 기록 종류가 추가 전용이 아니게 될 때.

## 다른 문서에 미치는 영향
채택하면서(2026-10-27) 1~5를 함께 고쳤다. `boundaries_test`의 `sync` 줄은 작업 1에서 더한다.

1. **ADR 0001 §3 코드 조각의 정렬 방향(버그)**: `.order('created_at').order('id')`는 postgrest-dart에서 내림차순이다(`order({bool ascending = false})`, postgrest 2.9.1 소스). 그대로 옮기면 키셋 페이지가 거꾸로 가서 행이 빠진다. `ascending: true`로 고친다.
2. ADR 0001 §3 "서버와 같은 컬럼에 `synced bool`을 더한 로컬 테이블": 2절의 행 규칙(insert 컬럼 + `synced`)으로 바꾼다. "테이블과 사용자마다" 커서는 "테이블마다(로그아웃·탈퇴 때 파일째 지움)"로 바꾼다.
3. ADR 0002 §1 표 `sync/` 비고 "로컬 기록 테이블" → "로컬 기록 파일(ADR 0005)". `boundaries_test`의 `rules`에 `sync` 줄을 더한다.
4. ADR 0004 결과 절 "XP는 로컬 DB의 id 기본 키가 중복을 막는다" → "로컬 저장소가 같은 id를 무시한다(ADR 0005)".
5. `CLAUDE.md` 검증 명령의 앱 줄에 5절의 Supabase 테스트 실행 방법을 더한다(에이전트는 `docs/` 밖을 고치지 않으므로 사람이 고친다).

## 작업 목록
1~2는 Supabase 없이 한다. 3부터는 로컬 Supabase가 필요하다. 7은 3과 함께 넣어도 된다.

| # | 작업 | 먼저 쓸 실패하는 테스트 |
| --- | --- | --- |
| 1 | `boundaries_test` `sync` 규칙, `newId()` | `sync/` 파일이 `screens/`나 `package:flutter/material.dart`를 import하면 실패한다. `newId()` 1,000개가 모두 UUID v4 형식(`^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$`)이고 서로 다르다 |
| 2 | `Store` 파일 읽기·쓰기, `add…`, 읽기 getter, `unsynced` | 같은 id로 `addAttempt`를 두 번 하면 `attempts`가 1개, `unsynced`가 1이다. 같은 파일로 새 `Store`를 열면 같은 `Attempt`(id, scenarioId, grade, 연월일)가 나온다. `records.json.tmp`가 남아 있어도 `records.json`을 읽는다. 로그인 전 `sync('attempts')`는 예외 없이 끝나고 `unsynced`가 그대로다(닿지 않는 주소이므로 요청을 보냈다면 예외가 났을 것이다) |
| 3 | 테스트 도우미(사용자 만들기·로그인·정리), push | 로그인한 저장소에 501행을 쓰고 `sync('attempts')` 한 번 → 서버(admin으로 셈) 501행, `unsynced` 0. 같은 요청 두 번: 복사한 파일로 다시 `sync`해도 오류 없이 서버 1행 |
| 4 | pull, 커서 | admin으로 그 사용자 행 1,001개를 넣으면 `sync` 뒤 로컬 1,001개다. 커서가 생긴 뒤 admin이 `created_at = 커서 - 1분`인 행을 넣으면 다음 `sync`에서 받는다. 기기 두 대: A·B·A 순서로 sync하면 두 저장소의 id 집합이 같다(`attempts`, `day_completions` 모두) |
| 5 | 네트워크 없음 | `recoverSession`으로 세션만 옮긴 `127.0.0.1:1` 클라이언트에서 `sync`가 예외를 던지고, `unsynced`와 파일 내용이 그대로이고, 그 뒤 `addAttempt`가 된다 |
| 6 | `clear()`와 sync 줄 세우기 | `sync`를 기다리지 않고 바로 `clear()`를 부른 뒤 둘 다 기다리면: 파일이 없고, `attempts`가 비었고, `auth.currentUser`가 null이고, 그 뒤 `sync`해도 파일이 생기지 않는다. admin으로 사용자를 지운 뒤 남은 `synced=false` 행을 `sync`하면 `PostgrestException` 코드 `23503`이다 |
| 7 | `.github/workflows/app.yml` | 첫 PR의 Actions 로그에서 `sync_test`가 skip 없이 통과했는지 본다. 일부러 기대값 하나를 틀린 커밋으로 빨간불이 나는지 한 번 확인하고 되돌린다 |

## 열린 질문 (사용자 결정 필요)
없음.

정해진 것(2026-10-27 사용자): Android 자동 백업은 켜 둔다(`allowBackup`을 건드리지 않는다). 백업은 사용자 본인의 Google 계정에 들어가고 우리는 볼 수 없다. 아래는 결정할 때 비교한 내용이다.

1. **Android 자동 백업**: Flutter 기본 `AndroidManifest.xml`에는 `allowBackup`이 없어서 켜져 있다. 그러면 `records.json`과 로그인 세션이 사용자의 Google 백업에 함께 들어갈 수 있다.
   - 켜 둔다(아무것도 안 함): 폰을 바꾸거나 다시 설치해도 게스트 기록이 돌아온다. 복원된 세션이 만료됐으면 ADR 0001 §5-5 규칙(세션 없음 + `synced` 기록 → 로컬 삭제)대로 정리되므로 깨지는 것은 없다.
   - 끈다(`android:allowBackup="false"` 한 줄): 기록의 사본은 기기 파일과 Supabase 둘뿐이라 설명이 쉽다. 게스트는 폰을 바꾸면 기록을 잃는다.
   - 추천: 켜 둔다. 할 일이 없고 게스트에게 이득이다. Android 12 이상의 기기 간 전송 동작은 확인하지 못했다.

## 확인하지 못한 것
- 실제 Android 기기(특히 저가형)에서 4,000행 파일 쓰기 시간. 호스트 값만 쟀다.
- `ignoreDuplicates` upsert가 RLS·컬럼 grant와 함께 실제로 통과하는지(ADR 0001에서도 확인하지 못함). 작업 3이 처음 확인한다.
- `or` 필터에 `Z` 시각을 따옴표 없이 넣었을 때 PostgREST가 값으로 제대로 비교하는지. 로컬에서는 파싱 오류 없이 권한 검사까지 가는 것만 확인했다. 작업 4가 확인한다.
- Android 자동 백업과 기기 간 전송이 정확히 어떤 파일을 옮기는지.

## 참고
- 기준 문서: `docs/decisions.md`(동기화, 인증, 예산), ADR 0001 §1·§2·§3·§5, ADR 0002 §1·결과 절, ADR 0003 §5, ADR 0004 §1·§5·결과 절, `CLAUDE.md`(동기화 층 테스트 기준)
- 코드: `app/lib/engine/engine.dart`(`Attempt`, `DayCompletion`), `app/test/boundaries_test.dart`, `supabase/migrations/20261025000000_attempt_records.sql`, `supabase/functions/delete-account/index.test.ts`(로컬 사용자 만들기), `.github/workflows/db.yml`, `supabase/config.toml`(`max_rows = 1000`)
- 패키지(2026-10-27 확인): [sqlite3](https://pub.dev/packages/sqlite3), [sqlite3 changelog](https://pub.dev/packages/sqlite3/changelog), [sqlite3 build hook 설정](https://github.com/simolus3/sqlite3.dart/blob/main/sqlite3/doc/hook.md), [sqflite](https://pub.dev/packages/sqflite), [sqflite_common_ffi](https://pub.dev/packages/sqflite_common_ffi), [drift](https://pub.dev/packages/drift), [supabase_flutter](https://pub.dev/packages/supabase_flutter), [supabase](https://pub.dev/packages/supabase), [path_provider](https://pub.dev/packages/path_provider)
- API: [Dart upsert](https://pub.dev/documentation/postgrest/latest/postgrest/PostgrestQueryBuilder/upsert.html), [Dart order](https://supabase.com/docs/reference/dart/order), [PostgREST 수평 필터와 예약 문자](https://docs.postgrest.org/en/stable/references/api/tables_views.html), [Supabase CLI status](https://supabase.com/docs/reference/cli/supabase-status), [Android 자동 백업](https://developer.android.com/identity/data/autobackup)

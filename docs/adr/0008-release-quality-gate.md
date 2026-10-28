# 0008. 출시 품질 기준: `dev` → `main` 전에 통과할 네 가지

상태: 채택
날짜: 2026-10-28

## 배경
2026-10-28 사용자 요청: 출시 전에 통과해야 할 기준을 측정할 수 있게 정한다. 지금 있는 기준은 커밋·PR 단위의 검증 명령뿐이다(루트 `CLAUDE.md` "검증 명령", `.github/workflows/app.yml`·`db.yml`). 출시(`dev` → `main` PR, 루트 `CLAUDE.md` "브랜치와 PR") 단위의 기준은 없다. 크래시와 오류는 ADR 0007로 Crashlytics에 모인다. 사용자는 많아야 약 1,000명이다.

원칙은 "언제나 단순한 시스템"이다. 기준마다 통과·실패가 한 문장으로 갈린다.

## 결정
`dev` → `main` PR 본문에 아래 네 줄을 체크리스트로 적고, 넷 다 통과해야 머지한다.

| # | 기준 | 통과 조건 | 어디서 보나 |
| --- | --- | --- | --- |
| G1 | 검증 명령 | 출시할 커밋(`dev` 끝)에서 루트 `CLAUDE.md` "검증 명령"의 네 층(앱, `sync/` Supabase 테스트, DB, Edge Function)이 모두 통과한다. `flutter analyze`는 info·warning도 실패로 치므로(기본값) 통과가 곧 0건이다 | 명령 출력을 PR 본문에 붙인다 |
| G2 | 릴리스 빌드 기기 점검 | 아래 목록을 실기기 릴리스 빌드에서 모두 해 본다 | PR 본문에 결과 |
| G3 | 열린 크래시 | Crashlytics에 열린 fatal 이슈와 ANR 이슈가 0개다. 고쳤으면 닫고, 고칠 수 없다고 판단했으면(예: 기기 OS 버그) 이유를 이슈 메모에 적고 닫는다. 그리고 Play Console Android vitals의 사용자 체감 크래시율과 ANR율이 나쁜 동작 기준(1.09%, 0.47%) 아래다 | Crashlytics 콘솔, Play Console Android vitals |
| G4 | 크래시 없는 사용자 비율 | 직전 출시 버전의 최근 7일 크래시 없는 사용자 비율이 99% 이상이다 | Crashlytics 대시보드(기간·빌드 필터) |

**G2 기기 점검 목록** (ADR마다 "확인할 점"으로 적은 세 경우와 스토어 요건. 2026-10-28 추천안으로 정함, 바꿀 수 있다)
1. 게스트로 첫 실행 → 데일리 하나를 끝까지 푼다. 홈의 연속 학습일과 XP가 바뀐다.
2. 비행기 모드로 데일리를 시작해 끝낸다. 학습이 끊기지 않는다.
3. 한 문제에서 답을 빠르게 두 번 누른다. XP가 한 번만 오른다.
4. 로그인해 데일리를 하나 끝낸 뒤 `adb shell pm clear com.hootbee.mannerfit`로 앱 데이터를 지우고 다시 로그인한다. 기록이 서버에서 돌아온다(기기 두 대 대신). 앱을 지웠다 다시 까는 것은 Android 자동 백업(ADR 0005 열린 질문 1)이 로컬 파일을 되살릴 수 있어서 서버 pull을 증명하지 못한다. 에뮬레이터 두 대에 같은 계정으로 로그인해도 된다.
5. 로그아웃, 탈퇴(테스트 계정). 탈퇴 뒤 게스트 첫 화면이 나온다.
6. 설정의 개인정보처리방침 링크가 열린다.

- G3의 열린 이슈에는 ANR을 넣는다(2026-10-28 사용자).
- 비공개 테스트 12명으로 Android vitals 숫자가 나오지 않으면 G3의 vitals 조건은 통과로 본다(2026-10-28 사용자).
- fatal은 잡지 않은 오류뿐이다(ADR 0007 §1). Crashlytics의 크래시 없는 사용자 비율은 Flutter의 잡지 않은 오류를 fatal로 세고, non-fatal(ADR 0007 §3)과 ANR은 세지 않는다([크래시 없는 지표](https://firebase.google.com/docs/crashlytics/crash-free-metrics)). 그래서 ANR은 G4가 아니라 G3에서 본다. non-fatal 이슈는 출시 기준이 아니다.
- G3의 vitals 줄은 Crashlytics가 받지 않는 네이티브 크래시(ADR 0007 §1)와 ANR율을 Play 기준으로 본다. 넘으면 Play 노출이 줄어든다([Android vitals](https://developer.android.com/topic/performance/vitals)).
- G4는 첫 출시에는 직전 버전이 없어 해당 없다.
- **첫 출시**: 개발자 계정이 개인 계정이므로 Play가 요구하는 비공개 테스트(테스터 12명 이상, 14일 연속)를 거친다. 이 14일이 G3 관찰 기간이고, Crashlytics 대시보드는 Play 트랙 필터로 비공개 테스트 트랙만 본다. 14일 뒤 Play Console에서 프로덕션 액세스를 신청하고(테스트 경험, 앱 소개, 출시 준비를 묻는 양식), Google 검토는 보통 7일 이하다([Play 고객센터](https://support.google.com/googleplay/android-developer/answer/14151465)). 그래서 일정에 "2주 + 검토 약 1주"를 넣는다(2026-10-28 사용자).

## 고려한 대안
- **G1만 두기(지금 그대로)**: 단위 테스트가 볼 수 없는 것(릴리스 빌드 설정, 기기, 콘솔의 실제 크래시)이 빠진다.
- **테스트 커버리지 숫자(예: 80%)**: 숫자는 쉽게 재지만, 층별 기준(루트 `CLAUDE.md` "테스트 우선")이 이미 무엇을 테스트할지 정한다. 커버리지를 맞추려고 레이아웃 테스트를 쓰게 된다.
- **크래시 비율만 두고 G3 없애기**: 사용자가 적을 때는 한두 명이 비율을 크게 흔든다(12명 중 1명이면 92%). 이슈 개수는 사용자 수와 상관없이 판단된다.
- **G4를 못 맞췄을 때 "가장 큰 이슈 수정이 들어 있으면 통과"로 두기**: 예외 규칙이다. G4는 99% 한 문장으로 둔다(2026-10-28 사용자).

## 결과
- **쉬워지는 것**: 출시 PR을 머지해도 되는지 한 표로 판단한다. 리뷰어가 같은 표로 본다.
- **어려워지는 것**: 출시마다 기기 점검과 콘솔 확인에 시간이 든다(점검 6개, 약 20분). G4를 못 맞추면 크래시를 고쳐 다음 7일을 다시 봐야 출시할 수 있다.
- **찾은 것**: `.github/workflows/app.yml`과 `db.yml`은 `dev`로 가는 PR에서만 돈다(`branches: [dev]`). `dev` → `main` PR에서는 CI가 돌지 않고, Edge Function 테스트(`deno test`)는 어느 CI에도 없다. 그래서 G1은 지금 손으로 돌려 붙여야 한다.
- **넣지 않은 것과 넣을 시점**
  - CI를 `main` PR에도 돌리기: G1을 손으로 하다 빠뜨리는 일이 생기면. 워크플로의 `branches`에 `main`을 더하는 한 줄이다.
  - Edge Function 테스트 CI: 함수가 둘 이상이 되거나 `delete-account`를 고칠 때.
  - 출시 뒤 자동 알림(크래시 비율 경보): 사용자가 1,000명을 넘거나 G4를 두 번 넘게 놓치면.
- **다시 볼 조건**: iOS 출시(App Store 심사와 TestFlight가 G2에 들어간다), 팀원이 늘 때.

## 다른 문서에 미치는 영향
- `docs/decisions.md`: 고칠 것 없다. 사용자 규모(약 1,000명)를 적을지는 사람이 정한다(ADR 0007 "다른 문서에 미치는 영향").
- 루트 `CLAUDE.md` "브랜치와 PR"의 출시 줄: `docs/` 밖이라 고치지 않았다. 작업 1에서 사람이 고친다. `.github/pull_request_template.md`는 작업 PR용이라 그대로 둔다.

## 작업 목록
| # | 담당 | 작업 | 먼저 쓸 실패하는 테스트 | 확인 방법 |
| --- | --- | --- | --- | --- |
| 1 | 사용자 | `docs: 출시 PR 체크리스트 추가`: 루트 `CLAUDE.md` "브랜치와 PR"의 출시 줄에 "PR 본문에 ADR 0008의 G1~G4를 채운다"를 더한다 | 문서라 없다 | 다음 출시 PR에서 표가 채워져 있다 |
| 2 | 사용자 | 첫 출시 전: Play 비공개 테스트 트랙을 열고 테스터 12명 이상을 넣는다 → 14일 연속 참여 → 프로덕션 액세스 신청 → 검토 통과(PR 없음, 열린 질문 1) | 없다 | Play Console에서 12명 이상이 14일 연속 참여했는지, 프로덕션 액세스 승인 메일 |

## 열린 질문 (사용자 결정 필요)
1. **비공개 테스트의 테스터 12명을 어디서 모을지**: 첫 출시 일정이 이것에 달려 있다. 14일은 12명이 모두 참여한 날부터 센다. 테스터가 12명보다 적거나 참여가 부족하면 비공개 테스트를 더 하라는 답이 올 수 있다.

정해진 것(2026-10-28 사용자): G4 목표는 99%이고 단서 없이 한 문장이다. G3에 Android vitals 줄을 더하고, 열린 이슈에 ANR을 넣고, vitals 숫자가 나오지 않으면 그 조건은 통과로 본다. 개발자 계정은 개인 계정이고, 첫 출시 전 비공개 테스트 14일을 G3 관찰 기간으로 쓴다. G2 점검 목록은 사용자 답이 없어 추천안(6개)으로 정했다. 바꿀 수 있다. 아래는 결정할 때 비교한 내용이다.

- **G2 점검 목록**: (A) 위 6개(채택한 추천안). (B) 화면마다 점검 항목을 더한다. 화면별 흐름은 위젯 테스트(루트 `CLAUDE.md` 층별 기준)가 맡으므로 (A)로 했다.
- **G4 목표**: (A) 99%(채택). (B) 99.5%, 사용자가 적을 때 한 명이 기준을 흔든다. (C) G4 없이 G3만.
- **첫 출시 전 테스트 기간**: Play는 2023-11-13 뒤에 만든 개인 개발자 계정에 "테스터 12명 이상이 14일 연속 참여한 비공개 테스트"를 프로덕션 출시 전에 요구한다([Play 고객센터](https://support.google.com/googleplay/android-developer/answer/14151465)).

## 확인한 것 (2026-10-28)
- Crashlytics 크래시 없는 사용자 비율은 기간과 빌드로 거를 수 있고, Android는 Google Play 트랙으로도 거를 수 있다. Flutter의 잡지 않은 오류를 fatal로 세고, non-fatal과 ANR은 세지 않는다. 기간마다 합산한 값이라 다른 기간끼리 바로 비교하지 않는다([크래시 없는 지표](https://firebase.google.com/docs/crashlytics/crash-free-metrics)).
- ANR은 fatal·non-fatal과 나란한 별도 이벤트 유형이다. 콘솔에서 이벤트 유형을 non-fatal이나 ANR로만 거르면 크래시 없는 지표 차트가 비는 것으로 확인했다([크래시 없는 지표](https://firebase.google.com/docs/crashlytics/crash-free-metrics)). 새 fatal 이슈 알림은 새 ANR에도 울린다([Crashlytics 알림](https://firebase.google.com/docs/crashlytics/alerts)).

## 확인하지 못한 것
- 사용자가 아주 적을 때(비공개 테스트 12명 등) Play Console Android vitals가 크래시율·ANR율을 보여 주는지. 보여 주지 않으면 위 결정대로 통과로 본다.

## 참고 (2026-10-28 확인)
- [Android vitals 나쁜 동작 기준](https://developer.android.com/topic/performance/vitals), [Play 테스트 요건과 프로덕션 액세스 신청(개인 계정)](https://support.google.com/googleplay/android-developer/answer/14151465), [Crashlytics 크래시 없는 지표](https://firebase.google.com/docs/crashlytics/crash-free-metrics)
- 기준 문서: 루트 `CLAUDE.md`("검증 명령", "브랜치와 PR"), `.github/workflows/app.yml`·`db.yml`, ADR 0005 열린 질문 1(자동 백업), ADR 0007 §1·§3

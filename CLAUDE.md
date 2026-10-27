# 매너핏

리포 구조는 `README.md`, 기술 결정은 `docs/decisions.md`(원본), 설계 근거와 스키마는 `docs/adr/`에 있다. 작업 전에 관련된 것을 읽는다.

## 테스트 우선

기능 코드보다 테스트를 먼저 쓴다.

1. 원하는 동작을 실패하는 테스트로 쓴다. 실행해서 실패하는지, 실패 이유가 의도한 것인지 확인한다.
2. 테스트를 통과시키는 가장 작은 코드를 쓴다.
3. 전체 테스트가 통과하면 정리한다. 정리한 뒤 다시 돌린다.

- 버그는 재현하는 테스트부터 쓴다.
- 테스트를 고쳐서 통과시키지 않는다. 기대값을 바꿔야 하면 설계(ADR)가 바뀐 것이므로 먼저 알린다.
- 층별 기준
  - 학습 엔진(`app/lib/engine/`): 기록 집합을 받아 값을 돌려주는 순수 Dart 함수로 만든다. ADR 0001 §4의 규칙(XP, 연속 학습일, Leitner)이 곧 테스트 케이스다.
  - 동기화(`app/lib/sync/`): 네트워크 없음, 같은 요청 두 번, 기기 두 대 세 경우를 반드시 테스트한다.
  - DB(`supabase/tests/`): RLS 정책마다 허용되는 경우와 거부되는 경우를 함께 테스트한다.
  - 화면(`app/lib/screens/`): 핵심 흐름만 위젯 테스트를 쓴다. 레이아웃은 테스트를 먼저 쓰지 않아도 된다.

## 검증 명령

- 앱: `cd app && flutter analyze && flutter test`. `sync/`의 Supabase 테스트는 아래 환경 변수가 없으면 건너뛴다. 동기화를 바꿨으면 `supabase start` 뒤 환경 변수를 넣고 돌린다.
- DB: `supabase start` 뒤 `supabase test db` (pgTAP, `supabase/tests/*.sql`)
- Edge Function: `supabase start`(edge-runtime을 빼지 않는다)와 `supabase functions serve` 뒤, 환경 변수를 넣고 `deno test --allow-net --allow-env supabase/functions/`
- 환경 변수(앱 `sync/`와 Edge Function 테스트): `eval "$(supabase status -o env --override-name api.url=SUPABASE_URL --override-name auth.anon_key=SUPABASE_ANON_KEY --override-name auth.service_role_key=SUPABASE_SERVICE_ROLE_KEY | grep '^SUPABASE_' | sed 's/^/export /')"`. 로컬 키라도 파일에 적지 않는다.

작업을 끝냈다고 말하기 전에 해당 층의 명령을 돌리고 결과를 그대로 보고한다.

## 에이전트

`.claude/agents/`에 세 역할이 있다. 순서는 architect(ADR, 작업 목록) → implementer(테스트 우선 구현) → reviewer(검사와 검증, 고치지 않음)다. reviewer가 `수정 필요`를 내면 implementer로 돌아간다.

## 커밋

형식: `종류: 무엇을 했는지` (한글, 50자 안쪽)

| 종류 | 언제 | 예 |
| --- | --- | --- |
| `feat` | 사용자가 쓸 수 있는 기능이 생겼다 | `feat: 홈 화면에 연속 학습일 표시` |
| `fix` | 잘못 동작하던 것을 고쳤다 | `fix: 오프라인에서 탈퇴 버튼이 눌리던 문제` |
| `test` | 테스트만 더하거나 고쳤다 | `test: 같은 기록을 두 번 보내도 한 번만 저장되는지 확인` |
| `refactor` | 동작은 같고 코드 구조만 바꿨다 | `refactor: 풀이 화면 위젯을 형식별 파일로 나눔` |
| `docs` | 문서만 바꿨다 | `docs: ADR 0002 채택` |
| `chore` | 설정, 패키지, 빌드처럼 앱 동작과 무관한 것 | `chore: Supabase CLI 설정 추가` |

- 커밋 하나에는 바뀐 것 하나만 담는다. 두 가지를 했으면 두 번 커밋한다.
- 요약은 "무엇이 달라졌는지"를 쓴다. "수정", "작업함", "업데이트"처럼 내용이 없는 말은 쓰지 않는다.
- 이유가 코드만 봐서 알기 어려우면 한 줄 띄우고 본문에 "왜"를 적는다.
- 커밋하기 전에 해당 층의 검증 명령을 돌린다. 실패하는 상태로 커밋하지 않는다.

## 브랜치와 PR

| 브랜치 | 무엇이 있나 | 어디서 들어오나 |
| --- | --- | --- |
| `main` | 스토어에 나간 코드 | `dev`에서만 |
| `dev` | 다음 출시에 들어갈 코드 | 작업 브랜치 PR |
| `종류/짧은-영어-이름` (예: `feat/home-streak`) | 작업 하나 | `dev`에서 만든다 |

- `main`과 `dev`에는 직접 커밋하지 않는다. 작업 브랜치는 항상 최신 `dev`에서 만들고, PR도 `dev`로 연다. 급한 수정도 같은 길로 간다.
- PR 하나에는 작업 하나만 담는다. Notion 작업 DB의 한 줄이 PR 하나다.
- PR 제목은 커밋과 같은 형식이다(`feat: 홈 화면 만들기`). 작업 PR은 squash로 머지해서 PR 제목이 `dev`의 커밋 하나가 된다.
- 출시할 때는 `dev` → `main` PR을 열고 **merge commit**으로 머지한다(squash 아님. squash하면 두 브랜치 기록이 어긋나 다음 출시 때 충돌이 난다). 머지한 뒤 `main`에 `v0.1.0` 같은 태그를 붙인다.
- PR 본문은 `.github/pull_request_template.md` 칸을 채운다. 무엇을, 왜, 어떻게 확인했는지 세 가지가 핵심이다. 화면을 바꿨으면 스크린샷을 붙인다.
- 리뷰어는 Notion "역할과 리뷰" 표를 따른다. 리뷰 코멘트는 "무엇이 문제인지"와 "어떻게 바꾸면 되는지"를 함께 쓴다.

에이전트는 커밋과 PR을 하지 않는다. 메시지와 PR 본문 초안은 써도 된다.

## 규칙

- 리포는 공개다. 서비스 키, DB 비밀번호, API 키를 코드, 설정, 문서 어디에도 넣지 않는다.
- 새 테이블은 RLS를 켠 마이그레이션으로만 만든다.
- 구조가 바뀌는 변경(테이블, 동기화, 콘텐츠 형식, 모듈 경계)은 구현 전에 architect 에이전트로 ADR을 먼저 쓴다.
- 결정이 바뀌면 `docs/decisions.md`를 고친다. 다른 문서에 결정 내용을 다시 적지 않는다.

# 0003. 콘텐츠 형식: 깨지지 않는 id, 버전, 배포, 자동 검사

상태: 채택
날짜: 2026-10-25

## 배경
`attempts.scenario_id`와 `day_completions.day_id`는 콘텐츠 id를 가리킨다(ADR 0001 §1). 첫 출시 전에 id 규칙을 고정하지 않으면 콘텐츠를 고칠 때마다 지난 기록의 매너, 영역, 복습 일정이 바뀐다. 지금 견본(`docs/prototype/content.json`)의 펼친 문제 id는 순번이다(`index.html` 512행 `~${i}`). 축 보기 하나를 넣거나 빼면 뒤의 id가 모두 밀린다. 견본에는 MVP에서 뺀 `weekly`, 계산할 수 있는 `locked`·`focus`, 영역 6개에 없는 `친구·가족`도 남아 있다. 화면이 받을 모양(`Question`, `Explanation`, `Evidence`)은 ADR 0002 §2에 있다.

## 결정
### 1. id 규칙
| 대상 | 형식 | 예 |
| --- | --- | --- |
| 원칙 | `^[A-Z]$` | `A` |
| 매너 | 양의 정수 | `1` |
| 기본 시나리오 | `^[A-Za-z0-9]+(-[A-Za-z0-9]+)*$`, 40자 이하 | `A-sidewalk` |
| 축 보기 `key` | `^[a-z0-9]+(-[a-z0-9]+)*$`, 16자 이하, 축 안에서 고유 | `partner` |
| 펼친 문제 | `vary` 없음: 기본 id. 있음: `<기본 id>~<key>.<key>` (축 순서대로) | `A-sidewalk~partner.right` |
| 데일리 | `^[a-z0-9]+(-[a-z0-9]+)*$`, 40자 이하 | `day-01` |

- 축은 3개까지다. 가장 긴 펼친 문제 id는 40 + 1 + 16×3 + 2 = 91자로, ADR 0001의 100자 제한 안에 들어간다.
- `key`는 화면 문구와 따로 둔다. "연인"을 "애인"으로 고쳐도 id는 그대로다. ASCII로 둬서 PostgREST 필터와 로그에서 인코딩 문제가 없다.
- 매너 id는 정수로 둔다. 서버에 저장되지 않고(기록은 시나리오만 가리킨다) 콘텐츠 안에서만 참조되며, 기획서 표 번호(1~30)와 같다. 두 PR이 같은 번호를 쓰면 CI의 중복 검사가 막는다.
- id는 뜻을 담지 않는다. `A-` 접두는 쓸 때의 원칙일 뿐이고, 앱은 id를 쪼개서 원칙을 읽지 않는다. 예외는 하나다. 펼친 문제가 콘텐츠에 없으면 `~` 앞의 기본 id로 매너를 찾는다(5절).
- 첫 공개 버전부터 매너, 기본 시나리오, 축 보기, 데일리 id는 지우거나 다른 뜻으로 다시 쓰지 않는다. 축 순서를 바꾸거나 기존 시나리오에 축을 더하면 id가 모두 바뀌므로 금지한다. 그럴 때는 새 기본 시나리오를 만들고 옛것을 은퇴시킨다.

### 2. 은퇴 `retired: true`
매너, 시나리오, 축 보기, 데일리에 붙인다. 값은 `true`만 허용하고, 은퇴하지 않았으면 필드를 쓰지 않는다. 은퇴한 매너의 시나리오와 은퇴한 보기를 포함한 펼친 문제는 은퇴한 것으로 본다.
- 출제(데일리 장면, 카테고리 연습, 다시 풀기, 복습)에서 뺀다. 오늘의 복습 수에도 넣지 않는다. 은퇴한 데일리는 경로에서 건너뛴다.
- 조회는 그대로 된다. 지난 기록의 매너와 영역, 스테이터스의 영역 값, 오류 신고의 대상 문제는 은퇴한 항목으로도 찾는다.
- 은퇴를 되돌리는 것은 허용한다. 뜻이 같기 때문이다.

### 3. 형식 (schema 1)
전체 형식은 `app/assets/content.schema.json`(draft-07)이다. 견본에서 바뀌는 것:
- 최상위에 `schema: 1`을 더하고 `weekly`를 뺀다. 매너의 `candidate`, 데일리의 `locked`·`focus`, 시나리오의 `subjectLabel`(늘 "나", 앱 상수), `evidence.level`(화면에 안 쓰이고, 출처가 없는지는 `sources`가 비었는지로 안다)을 뺀다.
- `domain`은 `area`로 이름을 바꾼다(ADR 0002 `Question.area`). 값은 `연애, 친구, 어른·가족, 직장, 공공장소, 메시지`(가운뎃점 U+00B7)이고, 이 순서가 스테이터스 표시 순서다. A-sidewalk의 조카 보기는 `어른·가족`으로 옮긴다.
- 축 보기는 `{key, retired?, area?, feedback?, vars?}`이다. 문장 변수는 `vars`에 넣는다(`{"key": "partner", "area": "연애", "vars": {"other": "연인"}}`). 펼칠 때 보기의 `area`, `feedback`이 기본값을 덮어쓴다(얕은 병합). 그 밖의 필드(`answer`, `spots` 등)는 보기에서 바꿀 수 없다.
- 문장 자리 표시는 `{변수}`나 `{변수+조사}`(조사: 와 과 은 는 이 가 을 를)이다. 견본 `fill()`과 같다.
- 형식별 필드: `position`은 `template`, `spots[{id, label}]`, `answer`(spot id)를 쓰고 `vars.other`가 상대 이름이다. `choice`는 `options[{text, grade, note?}]`를 쓰고 `best`가 정확히 하나다. `ox`는 `answer: true|false`를 쓴다. `order`는 `cards`(맞는 순서의 문장 배열)를 쓴다.
- choice 보기 id와 order 카드 id는 배열 순번(`"0"`, `"1"`…)으로 앱이 붙인다. 기록에 남지 않으므로 고정할 필요가 없다.
- `evidence`는 선택이다. `sources`가 비어 있으면 앱은 `Evidence`를 null로 넘긴다(ADR 0002). 출처 없는 관례라는 메모는 검토자를 위해 남겨 둔다.
- `tags`: 시나리오에 붙는 선택 배열(`key`와 같은 형식)이다. 카테고리 기준이 정해지면 쓴다. 지금은 뜻을 정하지 않고, 앱도 읽지 않는다.
- 데일리는 `{id, title, scenes[3], retired?}`이고 장면은 `{time, title, short, intro, manner}`이다. 배열 순서가 경로 순서다. 다음 하루는 `day_completions`와 배열 순서로 계산하므로 `locked`가 필요 없다. 장면당 2문제(2026-10-25 결정)는 엔진 상수로 두고 콘텐츠에 적지 않는다.

### 4. 버전
- `schema`(정수): 형식 번호다. 앱은 자기가 읽는 `schema`와 다른 파일은 버리고 지금 쓰는 콘텐츠(없으면 번들)를 쓴다.
- `version`(정수): 콘텐츠 번호다. schema와 상관없이 하나로 계속 오른다. 앱은 가진 것보다 큰 `version`만 받아들인다. 내용이 한 글자라도 바뀌면 올린다.

| `version`만 올린다 | `schema`도 올린다 |
| --- | --- |
| 문구 수정, 매너·시나리오·보기·데일리 추가, `retired` 표시, `area` 변경, 선택 필드 추가(옛 앱이 무시해도 문제·채점이 같을 때) | 새 `format`·`template`·`area` 값, 필드 이름 변경·삭제·뜻 변경, 새 필수 필드, 보기에서 덮어쓸 수 있는 필드 추가, 자리 표시 문법 변경 |

판단 기준은 하나다. schema N용 앱이 모르는 필드를 무시하고 읽었을 때 문제를 잘못 보여 주거나, 잘못 채점하거나, 죽으면 schema를 올린다. 앱은 같은 schema 안에서 모르는 필드를 무시한다. 모르는 enum 값이 있으면 파일 전체를 버린다.

**첫 출시 전에는 이 표를 적용하지 않는다.** 사용자 폰에 옛 앱이 없으므로 `schema: 1` 안에서 형식, 위치 템플릿(`sidewalk` 등), 문제 형식을 자유롭게 바꾼다. 문제 템플릿과 카테고리가 아직 정해지지 않았기 때문이다(2026-10-25). 첫 출시 PR(`dev` → `main`)에서 schema 1을 확정하고, 그때부터 위 표를 따른다.

### 5. 배포
- Storage 버킷 `content`(public)를 마이그레이션으로 만든다: `insert into storage.buckets (id, name, public) values ('content', 'content', true);`. `storage.objects`에는 정책을 더하지 않는다. public 버킷은 읽기 권한 검사를 건너뛰고, 쓰기는 RLS를 우회하는 service role만 할 수 있다.
- 경로: `s<schema>/<version>.json`(예: `s1/12.json`, 한 번 쓰면 다시 쓰지 않음, `cache-control: max-age=31536000`)과 `s<schema>/manifest.json`(`{"version": 12}`만, 덮어씀, `max-age=60`). Supabase는 덮어쓰기에 CDN 전파 지연이 있다며 새 경로에 올리기를 권하므로 본문은 버전마다 새 파일로 둔다. 옛 앱은 자기 schema 폴더만 보므로 읽지 못할 파일을 받지 않는다. ETag와 304 지원은 공식 문서에서 확인하지 못해서 쓰지 않는다.
- 앱 시작 순서(`content/`는 파싱만, 파일 입출력은 `live/`):
  1. 앱 저장소의 `content.json`이 있고, 읽히고, `schema`가 맞고, `version`이 번들보다 크면 그것을 쓴다. 아니면 번들을 쓰고 저장소 파일은 지운다.
  2. 시작할 때 한 번 `manifest.json`을 받는다(제한 시간 5초). `version`이 지금 것보다 크면 본문을 받는다.
  3. 본문을 끝까지 파싱해서 검증한다: `schema`가 맞는지, `version`이 manifest와 같은지, 6절의 파일 하나 검사(참조, 펼치기, 자리 표시)를 통과하는지. 통과하면 임시 파일에 쓰고 `rename`으로 바꾼다. 실패하면 아무것도 바꾸지 않고 다음 시작 때 다시 한다.
  4. 새 콘텐츠는 다음 시작부터 쓴다. 세트 중간에 문제 풀이 바뀌지 않게 하기 위해서다.
- 올리기: `main`에 `content/`가 바뀌어 들어오면 GitHub Actions가 service role 키(저장소 secret, environment `content-publish`)로 Storage REST에 올린다. 순서는 본문(`x-upsert: false`) 다음 manifest(`x-upsert: true`)다. manifest가 없는 파일을 가리키는 일이 없다. 다시 실행해도 안전하다. manifest의 `version`이 같으면 아무것도 하지 않고, 크면 실패시키고, 본문이 이미 있다는 400이 오면 manifest만 올린다.
- 번들: 원본은 `app/assets/content.json` 하나다. Flutter는 패키지 밖 경로를 `flutter_assets`에 넣지 않으므로(2026-10-25 `flutter build bundle`로 확인) 처음부터 앱 안에 둔다. 사본을 두지 않는다. 스키마는 옆에 `app/assets/content.schema.json`으로 두고, `pubspec.yaml`에는 `assets/content.json`만 올린다.

### 6. 자동 검사 (`app/tool/validate_content.dart`)
Dart로 쓰고 `lib/content/`의 파서와 `expand()`를 그대로 import한다. 앱이 펼치는 id와 검사기가 보는 id가 같은 코드에서 나온다. 같은 파서가 앱에서는 받은 파일을 바꾸기 전 검증에 쓰인다. 새 패키지는 없다. 형식 검사만 ajv-cli를 쓴다(`npx --yes ajv-cli@5.0.0`, 러너에 Node가 있고 리포에 `package.json`은 두지 않는다).

```sh
npx --yes ajv-cli@5.0.0 validate -s app/assets/content.schema.json -d app/assets/content.json
cd app && flutter pub get && dart run tool/validate_content.dart assets/content.json --previous=/tmp/prev.json
```

| 검사 | 수준 |
| --- | --- |
| JSON Schema 통과 | 오류 |
| 매너·기본 시나리오·데일리·원칙 id 중복, 축 안 `key` 중복, 펼친 문제 id 중복 | 오류 |
| 시나리오의 `manner`, 매너의 `principle`, 장면의 `manner`가 있는 id를 가리킴 | 오류 |
| 은퇴하지 않은 데일리의 장면이 은퇴한 매너를 가리킴 | 오류 |
| 펼친 뒤 `area`, `feedback`이 있고 `{…}` 자리 표시가 남지 않음. position은 `vars.other`가 있고 `answer`가 `spots` 안에 있으며, spot id가 템플릿이 아는 자리(`lib/content/templates.dart` 상수)임 | 오류 |
| choice의 `best`가 정확히 하나 | 오류 |
| `--previous`에 있던 매너·기본 시나리오·펼친 문제·데일리 id가 사라짐 | 오류 |
| `--previous`와 같은 id인 시나리오의 `manner`가 바뀜(지난 기록의 복습 일정이 바뀐다) | 오류 |
| `--previous`와 내용이 다른데 `version`이 크지 않음 | 오류 |
| 은퇴하지 않은 매너의 출제 가능한 펼친 문제가 3개 미만(장면 2문제와 다시 풀기 1문제가 안 됨) | 오류 |
| 은퇴하지 않은 매너의 출제 가능한 기본 시나리오가 3개 미만(기획서: 다시 풀기·복습은 다른 상황으로) | 경고 |
| choice의 `best` 보기가 가장 김(기획서 콘텐츠 원칙) | 경고 |

경고는 출력만 하고 종료 코드는 0이다. 2026-10-25 현재 콘텐츠로 돌리면 경고 두 개가 나온다(매너 3의 기본 시나리오 1개, `A-umbrella-01`의 best 보기가 가장 김). 경고는 콘텐츠가 바뀌면 달라지므로 현재 파일 테스트는 오류가 없는지만 확인하고, 경고 검사는 작은 예시 데이터로 테스트한다. `--previous`는 PR 기준 브랜치의 파일이다(`git show origin/$BASE:app/assets/content.json`). 처음 만드는 PR이라 없으면 비교 검사를 건너뛴다.

## 고려한 대안
- 축 보기의 화면 문구를 key로 쓰기(`A-sidewalk~연인.오른쪽`): 문구를 고치면 id가 바뀐다.
- 검사기를 Node나 Deno로 쓰기: 앱의 펼치기 코드를 다시 짜야 하고, 둘이 어긋나면 CI는 통과하는데 앱에서 id가 다를 수 있다.
- manifest 없이 ETag로 확인하기: Supabase 문서에서 ETag와 304 동작을 확인하지 못했고, 무료 플랜에는 덮어쓸 때 캐시를 비우는 Smart CDN이 없다.

## 결과
- **쉬워지는 것**: 콘텐츠를 고쳐도 지난 기록이 같은 문제를 가리킨다. 지운 id는 CI가 막는다. 옛 앱은 자기 schema의 마지막 콘텐츠를 계속 쓴다.
- **어려워지는 것**: 콘텐츠 파일이 은퇴한 항목만큼 계속 커진다. 축 구성을 바꾸려면 새 시나리오를 만들어야 한다. schema를 올리면 옛 앱은 콘텐츠 업데이트가 멈춘다.
- **확인할 점**
  - 네트워크 없음: 번들이나 저장된 파일로 시작한다. manifest를 못 받아도 학습은 그대로다. 무료 프로젝트가 1주 비활성으로 멈춰도 같다.
  - 같은 요청 두 번: 다운로드는 진행 중인 Future 하나로 묶는다. 임시 파일을 `rename`하므로 반쯤 쓴 파일이 남지 않는다. 올리기 재실행은 5절 규칙대로 같은 결과가 된다.
  - 기기 두 대: 두 기기의 콘텐츠 버전이 다를 수 있다. pull로 받은 기록의 `scenario_id`가 없으면 `~` 앞의 기본 id로 매너를 찾는다. 그래도 없으면 기록은 지우지 않고 XP에만 넣으며, 복습과 영역 값에서는 콘텐츠를 받을 때까지 뺀다. 모르는 `day_id`도 연속 학습일(날짜만 씀)에는 들어가고, 경로 위치에서는 뺀다. 확정은 엔진 ADR에서 한다.
  - 탈퇴: 콘텐츠는 사용자 데이터가 아니므로 영향이 없다.
- **넣지 않은 것과 넣을 시점**: 금지 표현 검사(파이프라인 ADR에서 목록을 정할 때), 콘텐츠 분할·gzip(본문 크기 × 월 활성 사용자 × 월 업데이트 횟수가 2.5GB를 넘을 때. 무료 플랜 egress는 비캐시 5GB와 캐시 5GB다. 견본은 최소화하면 시나리오당 약 0.6KB여서 3,000개면 약 1.9MB다), 실행 중 콘텐츠 교체(다음 시작까지 기다리는 것이 불편하다는 의견이 나올 때).
- **다시 볼 조건**: `schema` 2가 필요할 때, 위치 템플릿을 더할 때(schema가 오른다).

## 작업 목록
| # | 작업 | 먼저 쓸 실패하는 테스트 |
| --- | --- | --- |
| 1 | 견본을 새 형식으로 옮겨 `app/assets/content.json`(`schema: 1`, `version: 1`)으로, 스키마를 `app/assets/content.schema.json`으로 둔다. 빈 `day-03`은 장면이 3개가 아니므로 뺀다(첫 공개 전이라 지워도 된다). 후보 매너 31과 그 시나리오 3개(`A-subway-01`, `A-bus-01`, `A-elevator-01`), 매너 31을 쓰는 `day-02`도 옮기지 않는다. 견본에는 그대로 남긴다 | ajv 명령이 옮긴 파일에 `valid`를 내고, `weekly`를 다시 넣은 파일은 거절한다 |
| 2 | `lib/content/`: `parseContent(String)`와 `expand()`. Flutter import 금지(`boundaries_test`에 추가) | `A-sidewalk`가 8개로 펼쳐지고 id가 `A-sidewalk~partner.right` 꼴로 모두 다르다. `A-stairs~grandma.up`의 `feedback.title`이 "오를 땐 한 칸 아래, 뒤에서"다 |
| 3 | 은퇴와 조회 | 은퇴한 보기를 포함한 펼친 문제는 출제 목록에 없지만 `lookup(id)`로는 찾힌다. 콘텐츠에 없는 `A-sidewalk~new.right`는 `~` 앞으로 매너 1을 찾는다 |
| 4 | 파일 하나 검사(참조, 자리 표시, choice `best` 하나, 매너당 3문제) | 장면이 콘텐츠에 없는 매너 99를 가리키면 오류다. 현재 `app/assets/content.json`은 오류가 없고 종료 코드 0이다 |
| 5 | 비교 검사(`--previous`) | 이전 파일에 있던 `A-alley~child`를 지우면 오류 이름과 id를 출력하고 종료 코드 1. 내용만 바꾸고 `version`을 그대로 두면 오류 |
| 6 | CI `.github/workflows/content.yml`: `dev`로 가는 PR에서 `content/**`, `app/lib/content/**`, `app/tool/**`가 바뀌면 6절 두 명령 실행 | `day-01`의 `id`를 바꾼 PR에서 워크플로가 실패한다(초안 PR로 확인) |
| 7 | Storage 버킷 마이그레이션 | pgTAP: `authenticated` 역할로 `storage.objects`에 `bucket_id='content'` insert가 거부된다 |
| 8 | `live/`의 받기와 바꾸기(5절 1~4) | 가짜 HTTP가 깨진 JSON을 주면 저장된 파일이 그대로다. 같은 `version`이면 본문을 요청하지 않는다. 저장된 파일의 `schema`가 2면 번들을 쓴다 |
| 9 | 올리기 워크플로(`main`, environment `content-publish`) | 셸 함수를 가짜 응답으로 돌려 manifest `version`이 같으면 업로드 요청이 0번이다 |

## 열린 질문 (사용자 결정 필요)
없음.

정해진 것(2026-10-25 사용자): 콘텐츠는 `main` 머지 때 Storage에 올린다. 정답 보기가 가장 긴 경우는 경고로 둔다. 콘텐츠 원본은 `app/assets/content.json` 하나다. 순서 형식은 모두 맞으면 `best`, 하나라도 틀리면 `avoid`다(`ok` 없음). 후보 매너 31을 낼지는 콘텐츠를 채울 때 정하고, 그때까지 새 형식 파일에 넣지 않는다.

## 확인하지 못한 것
ETag·`If-None-Match` 지원, 무료 플랜 기본 CDN이 `cache-control`을 얼마나 따르는지(manifest가 몇 분 늦게 보일 수 있다), REST 업로드에서 `cache-control` 헤더 이름, 새 `sb_secret_` 키로 Storage REST를 부를 때 쓰는 헤더, Storage가 gzip으로 응답하는지.

## 참고 (2026-10-25 확인)
Supabase: [버킷(public)](https://supabase.com/docs/guides/storage/buckets/fundamentals), [다운로드와 public URL](https://supabase.com/docs/guides/storage/serving/downloads), [업로드와 덮어쓰기](https://supabase.com/docs/guides/storage/uploads/standard-uploads), [CDN 기본](https://supabase.com/docs/guides/storage/cdn/fundamentals), [Smart CDN(Pro 이상)](https://supabase.com/docs/guides/storage/cdn/smart-cdn), [요금](https://supabase.com/pricing) · [ajv-cli](https://github.com/ajv-validator/ajv-cli)

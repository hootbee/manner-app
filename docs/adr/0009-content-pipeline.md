# 0009. 문제 생성·검토 파이프라인: 매너 하나 → 기본 시나리오 3개 → `dev` PR

상태: 채택
날짜: 2026-10-29 (2026-10-30 열린 질문의 사용자 답 반영)

## 배경
`docs/decisions.md` "AI"에서 정한 것은 셋이다. 앱 실행 중에는 AI를 쓰지 않고, Claude는 문제 생성·검토 파이프라인에서만 쓴다. 파이프라인은 GitHub Actions에서 돌고 사람이 PR로 승인하면 Storage에 올라간다. 비용은 Claude Max의 월간 API 크레딧으로 내고, 급하지 않은 일은 Batch API로 돌린다. 기획서 `docs/concept.md` "AI 활용 방식"에는 원안 1~6단계(기획 에이전트, 생성, 코드 검사, 검토 에이전트의 블라인드 풀이·논란 검사·근거 검사(`pgvector`), 사람 승인, 출시 후 정답률로 재검토)가 있다.

뒷부분은 이미 있다. 콘텐츠 형식과 검사는 ADR 0003과 `.github/workflows/content.yml`(PR에서 ajv + `app/tool/validate_content.dart`)에 있다. 게시는 `.github/workflows/content-publish.yml`(`main`에 `app/assets/content.json`이 들어오면 Storage `content/s1/`에 올림)에 있다. 그래서 파이프라인은 **`dev`로 가는 콘텐츠 PR을 만드는 데까지만** 한다. 사람이 그 PR을 머지하고, 출시 때 `dev` → `main`이 되면 기존 워크플로가 올린다.

아직 정해지지 않은 것이 셋 있다. 문제 템플릿(이슈 #26: 형식별 화면 틀, 위치 문제 장소·자리 목록), 카테고리 기준(#28), 근거 문서다. 근거 문서는 하나도 없다. 기획서 할 일 "의전 근거 문서 후보를 찾고 공공누리 유형을 확인한다"가 아직 끝나지 않았다. 2026-10-29 사용자 요구는 이 셋 없이도 파이프라인이 돌고, 정해지면 고칠 곳이 정해진 몇 곳뿐이어야 한다는 것이다. 2026-10-30 사용자는 "완전 자동화가 목표"라고 했다. 지금 콘텐츠는 매너 3개, 기본 시나리오 8개, 13KB다.

## 결정
### 1. 원안과 비교: 무엇을 넣고 뺐나
| 기획서 단계 | 원안 | 이 ADR | 이유 |
| --- | --- | --- | --- |
| 1 | 기획 에이전트가 겹치지 않는 상황 후보를 고른다 | 뺀다. 생성 호출이 같은 매너의 기존 시나리오를 보고 겹치지 않게 쓴다 | 호출 하나로 된다 |
| 2 | 생성 에이전트가 문제 JSON을 쓴다 | 호출 1 | |
| 3 | 코드 검사(형식, 템플릿·자리 id, 정답 보기 길이, 매너당 3문제, 금지 표현) | 기존 검사 그대로 + 금지 표현(§7) + 출처 대조(§6) | 금지 표현과 출처 대조 말고는 `validate.dart`에 이미 있다 |
| 4 | 블라인드 풀이를 여러 번, "정답 애매"·"너무 쉬움" | 한 번(호출 2), "정답 애매"만 | 한 번 풀어서는 쉬움을 잴 수 없다 |
| 4 | 논란 검사 | 호출 3 | |
| 4 | 근거 검사, 의전 문서를 `pgvector`로 검색 | 호출 3에 그 매너의 근거 요약(팀이 공공기관 문서를 읽고 쓴 것)을 넣는다 | §6. 요약이 짧고 적어 검색이 필요 없다 |
| (없음) | | 호출 3의 `형식` 표시: 상황이 지금 형식과 잘 맞지 않으면 맞는 형식을 제안한다 | 2026-10-30 사용자 추가. 템플릿(#26)을 정할 때 쓸 자료가 된다 |
| 5 | 사람이 표시된 문제와 무작위 일부를 PR에서 승인 | 사람이 새 문제를 모두 본다 | 한 PR에 기본 시나리오 3개라 다 읽을 수 있다. 표본 규칙이 필요 없다 |
| 6 | 출시 후 오류 신고와 정답률로 재검토 | 넣지 않는다 | 정답률 데이터는 ADR 0006 `answer` 이벤트로 이미 모인다 |

### 2. 입력과 출력
- **입력은 매너 id 하나다**(workflow_dispatch 입력 `manner`, number). 다른 입력은 없다.
- **출력은 `app/assets/content.json` 한 파일을 바꾸는 `dev` PR 하나다.** 새 기본 시나리오 3개를 `scenarios` 끝에 붙이고 `version`을 1 올린다. 3은 `validate.dart`의 "기본 시나리오 3개 미만" 경고와 같은 수다. 새 매너도 한 번 실행으로 출제할 수 있게 된다.
- 매너가 파일에 없으면 기획서 표에서 같은 번호의 줄을 보고 `manners`에 매너 항목(`id`, `name`, `principle`, `places`)도 붙인다. 매너 id는 기획서 표 번호와 같다(ADR 0003 §1). 사람은 그 줄을 diff로 확인한다.
- 기존 항목은 고치지 않고 붙이기만 한다. 데일리(`days`)는 쓰지 않는다. 고치기와 경로 짜기는 사람이 PR로 한다.
- `tags`는 스키마에 값 목록(`enum`)이 있을 때만 쓴다. 지금은 목록이 없으므로 쓰지 않는다(#28).
- 파일은 `JsonEncoder.withIndent('  ')`에 줄바꿈 하나를 붙여 쓴다. 지금 파일이 `jq .` 출력과 같은 모양이라 diff에는 붙인 줄만 나온다(2026-10-29 확인).

### 3. 단계: 한 번 실행에 Claude를 세 번 부른다
1. **열린 PR 확인**: PR용 토큰(§10)으로 열린 PR 목록을 읽는다. head 브랜치가 `content/`로 시작하는 PR이 있으면 실패한다. 이렇게 막는 이유는 두 PR이 같은 `version`과 같은 시나리오 id를 들고 따로 머지되는 일 때문이다. `dev`에 보호 규칙이 없어서 낡은 CI 결과로도 머지할 수 있다. 토큰이 만료되었으면 이 단계에서 실패하므로 돈을 쓰기 전에 알 수 있다.
2. **생성(호출 1)**: 기본 시나리오 3개를 JSON으로 받는다.
3. **코드 검사**: `content.yml`과 같은 스크립트(`.github/scripts/check_content.sh`)로 ajv와 `validate_content --previous=<dev 파일> --sources=<색인>`을 돌린다. 출처 대조(§6)도 이 안에 들어 있다. 오류가 있으면 모델 응답을 로그에 남기고 실패한다. 다시 생성하지 않는다.
4. **블라인드 풀이(호출 2)**: 새 펼친 문제에서 `blindHidden` 키를 지우고 `blindShuffled` 배열을 섞어서 보낸다(§4). 모델은 감춘 필드를 채운 JSON을 돌려준다.
5. **판정(호출 3)**: 원래 문제, 블라인드 답, 근거 요약을 주고 표시 목록을 받는다: `[{"id": "<펼친 문제 id>", "kind": "정답|논란|근거|형식", "note": "…"}]`.
   - `정답`: 블라인드 답이 다르거나, 둘 다 답이 될 수 있다.
   - `논란`: 성별 고정관념, 세대 갈등, 조종 기술, 의견이 갈리는 주제가 있다.
   - `근거`: 해설이나 `evidence`가 근거 요약과 다르다.
   - `형식`: 이 매너·상황이 지금 쓴 형식과 잘 맞지 않는다. 스키마에 있는 다른 형식이나 아직 없는 형식 가운데 무엇이 맞을지를 한두 문장으로 제안한다.
6. **PR**: 브랜치 `content/manner-<id>-<run id>`에 커밋 하나를 만들고, PR용 토큰으로 push한 뒤 `gh pr create --base dev --body-file`로 연다(본문은 §11). 사람이 연 것과 같아서 `content.yml`이 바로 돈다.

규칙은 한 문장이다. **막는 것은 코드 검사뿐이고, Claude 검토는 표시만 하며, 판정은 사람이 한다.** `형식` 표시도 막지 않는다. 생성과 검토를 같은 모델이 하므로 맹점도 같다. 그래서 사람 단계를 없애지 않는다(기획서). 머지는 사람이 한다.

### 4. 템플릿에 의존하는 것은 이미 있는 정의 두 곳에만 둔다
파이프라인 코드, 워크플로, 프롬프트 파일, 검토 단계는 형식과 장소를 모른다. 형식에 따라 달라지는 것은 모두 아래 원본에서 읽는다. 사본은 만들지 않는다.

| 정의 | 원본 | 파이프라인이 쓰는 방법 |
| --- | --- | --- |
| 형식 목록, 형식별 필드, 위치 템플릿(장소) 목록, `tags` 값 | `app/assets/content.schema.json` | 시스템 프롬프트에 파일을 그대로 넣는다 |
| 형식 설명(모델이 읽는 한두 문장) | 같은 스키마의 형식 분기마다 `description`(작업 A5) | 위와 같다. `description`은 검사에 영향이 없다 |
| 장소별 자리 id | `app/lib/content/templates.dart`의 `templateSpots` | import해서 JSON으로 시스템 프롬프트에 넣는다 |
| 블라인드 풀이에서 감출 키와 섞을 배열 | 같은 파일에 두 상수를 더한다(아래) | `blind()`가 이 두 상수만 본다 |
| 예시 | `content.json`의 같은 매너 기존 시나리오 | 생성 호출의 사용자 메시지에 넣는다 |

```dart
// app/lib/content/templates.dart에 더한다 (ADR 0009 §4). 형식이 늘어 답이 담긴 필드가 생기면 여기만 고친다.
const blindHidden = {'answer', 'grade', 'note', 'feedback', 'evidence'}; // 어느 깊이에 있든 지운다
const blindShuffled = {'options', 'cards'}; // 순서가 답이거나 답을 흘리는 배열은 섞는다
```

- 프롬프트 파일(`pipeline/prompts/`)과 `app/tool/pipeline.dart`에는 형식 이름과 장소 이름을 쓰지 않는다. 스키마의 `format`·`template` enum 값이 이 파일들에 나오면 테스트가 실패하게 한다(작업 A6).
- `형식` 표시 지시문도 이름 없이 쓴다. `judge.md`의 문장은 "이 상황이 쓴 형식과 맞지 않으면, 스키마의 다른 형식이나 아직 없는 형식 가운데 무엇이 맞을지 한두 문장으로 제안한다"이다. 모델은 형식 이름을 스키마에서 읽고 답의 `note`에만 쓴다. 테스트는 프롬프트 파일만 보므로 답에 형식 이름이 나와도 충돌하지 않는다. PR 본문은 `note`를 그대로 옮긴다.
- 스키마의 `template` enum과 `templateSpots` 키는 지금 두 곳에 같은 목록으로 있다. 하나로 합치지 않고 둘이 같은지 테스트로 확인한다(작업 A5). ajv와 Dart가 같은 파일을 읽게 하려면 생성 단계가 필요하다. 테스트 한 줄이 더 단순하다.

### 5. 실행 방식: `workflow_dispatch`, Messages API 직접 호출
**규칙: 세 호출을 Messages API로 차례로 부르고, 하나라도 실패하면 실행이 실패한다.** 실행은 보통 10~15분이다(설치·검사 몇 분 + 호출당 몇 분). 다시 부르지 않고 사람이 다시 돌린다. `stop_reason`이 `end_turn`이 아니어도 실패다. 실행 상태는 Actions 실행 화면 하나에서 끝까지 보인다.

```yaml
# .github/workflows/content-pipeline.yml (초안)
on:
  workflow_dispatch:
    inputs:
      manner: { description: 매너 id (기획서 표 번호), required: true, type: number }
permissions: { contents: read }
concurrency: content-pipeline
jobs:
  run:
    runs-on: ubuntu-latest
    environment: content-pipeline # secret ANTHROPIC_API_KEY, CONTENT_PR_TOKEN. 배포 브랜치는 dev만
    timeout-minutes: 30 # 보통 10~15분
    steps:
      - uses: actions/checkout@v7
        with: { fetch-depth: 0, persist-credentials: false }
      - name: 열린 파이프라인 PR 확인 (1단계)
        env: { GH_TOKEN: "${{ secrets.CONTENT_PR_TOKEN }}" }
        run: gh pr list --base dev --state open --json headRefName > "$RUNNER_TEMP/open.json"
      - uses: subosito/flutter-action@v2 # content.yml과 같은 버전
      - run: cd app && flutter pub get
      - name: 생성·검사·검토 (1~5단계)
        env: { ANTHROPIC_API_KEY: "${{ secrets.ANTHROPIC_API_KEY }}", MANNER: "${{ inputs.manner }}" }
        run: cd app && dart run tool/pipeline.dart "$MANNER" "$RUNNER_TEMP/open.json" "$RUNNER_TEMP/pr.md"
      - name: PR (6단계)
        env: { GH_TOKEN: "${{ secrets.CONTENT_PR_TOKEN }}", MANNER: "${{ inputs.manner }}" }
        run: | # gh auth setup-git → git switch -c content/manner-$MANNER-$GITHUB_RUN_ID → commit → push → gh pr create --body-file
```
- **트리거는 `workflow_dispatch` 하나다.** 쓰기 권한이 있는 사람만 돌릴 수 있다. 이슈 라벨 트리거는 쓰지 않는다. 공개 리포에서는 누구나 이슈 본문을 쓸 수 있어서 그 본문이 프롬프트 입력이 되기 때문이다.
- `environment: content-pipeline`의 배포 브랜치를 `dev` 하나로 둔다. 그러면 다른 브랜치에서 워크플로를 고쳐 돌려도 비밀을 읽지 못하고, 머지된 프롬프트와 코드만 비밀을 쓴다. ADR 0003 §5의 `content-publish`(배포 브랜치 `main`)와 같은 방식이다.
- PR용 토큰은 1단계와 6단계에만 넘긴다. Claude 키는 생성·검사·검토 단계에만 넘긴다. 체크아웃은 자격 증명을 남기지 않는다(`persist-credentials: false`).
- 모델 출력과 입력은 셸 명령에 끼워 넣지 않는다. 입력은 `env`로 받고, PR 본문은 `--body-file`로 넘긴다.
- 저장소 설정 "Allow GitHub Actions to create and approve pull requests"는 켜지 않는다. 기본 `GITHUB_TOKEN`은 이 워크플로에서 읽기만 한다.

### 6. 근거: 팀이 쓴 요약 + 원문 링크, 색인 한 파일, 검색 없음
**규칙: `pipeline/sources/sources.json`에는 팀이 공공기관 문서를 읽고 직접 쓴 요약과 원문의 기관명·문서명·연도·URL만 둔다. 파이프라인은 그 요약을 근거로 쓰고, 앱 "근거 보기"는 이 색인에 있는 URL만 가리킨다(2026-10-30 사용자).**
```json
[{ "publisher": "외교부", "title": "자동차 속에 숨겨진 의전", "date": "…", "url": "https://…",
   "manners": [5], "summary": "팀이 자기 문장으로 쓴 요약. 원문 문장을 옮기지 않는다. 1,000자 이하" }]
```
- 파일은 이것 하나다(문서가 없으면 `[]`). 문서를 더할 때 고치는 곳은 이 파일의 항목 하나뿐이다. 매너와의 연결은 `manners`에, 근거 내용은 `summary`에 있다. 원문 본문은 리포에 두지 않는다.
- **요약을 쓰는 이유**: 리포가 공개라 원문을 복사하면 재배포가 되고, 그러려면 공공누리 1유형이 필요하다. 사용자 조사(2026-10-30)에서는 매너 내용과 1유형을 함께 갖춘 공공 문서가 없었다. 팀이 사실을 자기 문장으로 쓴 요약과 링크는 원문 복사가 아니다. 그래서 공공누리 유형은 따지지 않고, 공공누리 출처표시 문구도 필수로 두지 않는다. 1유형 문서를 쓰는 경우에만 해당하는 문구다. 원문 문장을 그대로 옮기거나 길게 인용하지 않았는지는 색인을 더하는 PR에서 사람이 본다.
- **숫자 규칙은 하나다: `summary`는 1,000자 이하다.** 긴 옮겨 적기를 막고, 한 매너의 근거가 프롬프트에서 커지지 않게 한다.
- **공공기관 문서만 쓴다.** 뉴스, 블로그, 책은 넣지 않는다. 기관이 공공기관인지는 색인 PR에서 사람이 본다. 코드는 판단하지 않고, `publisher`가 비어 있지 않은지만 검사한다.
- **출처 대조는 전체 콘텐츠에 건다.**
  - 모든 시나리오의 `evidence.sources[]`는 그 시나리오의 매너에 묶인 색인 항목과 `url`·`publisher`·`title`·`date`가 같아야 한다.
  - 색인 항목에는 `publisher`, `title`, `date`, `url`, `manners`, `summary`가 모두 있어야 하고 `summary`는 1,000자 이하다.
  - 검사하는 함수는 `checkSources`(`app/lib/content/validate.dart`)다. `validate_content --sources=`로 CI와 파이프라인 3단계가 같이 부르고, 앱은 색인이 없으므로 부르지 않는다.
  - 지금 세 시나리오의 출처를 먼저 공공기관 문서로 바꾸거나 비운 뒤에 켠다(작업 A4).
- **앱 "근거 보기"는 기관명(`publisher`), 문서명(`title`), 링크(`url`)만 보여 준다.** 근거 설명은 시나리오의 `evidence.summary`(팀 문장)다. 묶인 항목이 없으면 `sources`는 빈 배열만 될 수 있다. 앱은 이때 `Evidence`를 null로 넘긴다(ADR 0003 §3).
- **ADR 0003을 고친다(작업 A3).** `source.locator`(문서 안 위치)를 선택 필드로 바꾼다. 요약만 보고는 모델이 원문 안 위치를 정확히 쓸 수 없고, 화면에도 쓰지 않기 때문이다. 첫 출시 전이라 schema 1 안에서 바꾼다(ADR 0003 §4). 파이프라인은 `locator`를 쓰지 않는다. `date`는 색인과 맞춰 보는 데 쓰므로 필수로 둔다. ADR 0002의 `Source.locator`는 null이 될 수 있게 바꾼다.
- 그 매너에 묶인 항목의 `summary`를 시스템 프롬프트 끝에 넣는다. 없으면 넣지 않고 그대로 돈다.
- **규칙: 매너에 묶인 색인 항목이 없으면 PR 본문 첫 줄에 "근거 문서 없음"을 쓰고 실행과 머지를 막지 않는다. 그 매너가 의전 매너(4, 5, 6, 30)이면 머지 전에 아래 "근거가 불명확한 매너" 표에 올린다(2026-10-30 사용자).** 의전이 아닌 매너는 출처 없는 관례 문제로 보고 표에 올리지 않는다.
**근거가 불명확한 매너** (이 표가 원본이다. 다른 곳에 복사하지 않는다)

| 매너 | 내용 | 2026-10-30 조사(찾아본 곳 → 결과) | 근거가 생기면 |
| --- | --- | --- | --- |
| 4 | 식당에서는 출입문에서 먼 안쪽 자리를 상대에게 | 행안부 「정부의전편람」 2021·2024 게시글(PDF 본문은 열지 않음), 서울시 「의전업무 길라잡이」, 전남 사회복지포털 「어린이예절」 → 같은 내용의 공공 문서 없음. 전남 자료는 "웨이터가 먼저 빼 주는 의자가 상석"으로 기준이 다르다 | `sources.json`에 요약 항목을 더하고, 기존 시나리오의 `evidence.sources`를 사람이 PR로 채운 뒤 이 줄을 지운다 |
| 6 | 엘리베이터 상석은 조작 버튼 대각선 안쪽 | 행안부 「정부의전편람」 2021·2024 게시글(PDF 본문은 열지 않음), 서울시 「의전업무 길라잡이」, 국민재난안전포털·연수구·김해시 승강기 안내 → 상석을 다룬 공공 문서 없음 | 위와 같다 |

- 4·6번은 근거 없이 관례 문제로 낸다(2026-10-30 사용자). 앱 콘텐츠에는 따로 표시하지 않는다. `evidence.sources`가 비어 있으면 앱은 이미 "출처 없음"으로 알고 `Evidence`를 null로 넘긴다(ADR 0003 §3). 그래서 콘텐츠 형식은 바꾸지 않는다.
- 조사는 웹 페이지 본문만 읽었다. 「정부의전편람」 PDF 본문(2024판 24.6MB)은 열지 않았으므로, 두 매너의 근거를 다시 찾을 때 가장 먼저 본다. 편람은 게시글에 공공누리 표시가 없지만 팀 요약 + 링크 규칙(위)으로는 쓸 수 있다.

- **`pgvector`를 쓰지 않는 이유**: Anthropic에는 임베딩 모델이 없어서 외부 임베딩 서비스(Voyage AI 등)의 키가 하나 더 필요하다. 조각내기 코드, DB 테이블과 RLS, 파이프라인 워크플로의 DB 쓰기 권한도 늘어난다. 요약을 그대로 넣으면 그런 것이 하나도 없다. 세 호출이 같은 시스템 프롬프트를 쓰므로 프롬프트 캐시도 먹는다(§8).
- **다시 볼 시점**: 한 매너에 묶인 요약의 합이 100KB를 넘으면 다시 본다. 요약은 하나에 1,000자(약 3KB) 이하이므로 한 매너에 문서가 30개를 넘을 때다. 그때 실행당 추가 비용은 캐시 쓰기 1번(5만 토큰 × $5/M)과 읽기 2번(0.05배)으로 약 $0.27이다.

### 7. 금지 표현: `validate.dart`의 목록 하나, 오류
- `app/lib/content/validate.dart`에 `bannedWords` 상수를 둔다. 펼친 문제의 문자열에 목록의 낱말이 들어 있으면 오류다. `evidence`는 출처 제목이라 보지 않는다.
- 첫 목록: `여자친구, 남자친구, 여친, 남친, 여자, 남자, 여성, 남성, 밀당, 꼬시`(2026-10-30 사용자). 기획서의 성별 중립·조종 기술 원칙에서 가장 흔히 새는 표면 낱말이다. 가족 호칭(오빠, 누나, 할머니)은 `어른·가족` 문제에 필요해서 넣지 않았다. 지금 `content.json`과 견본에는 이 낱말이 없다(2026-10-29 확인).
- `validate.dart`에 두는 이유는 같은 함수를 CI(`content.yml`), 파이프라인(3단계), 앱(받은 콘텐츠를 바꾸기 전 검증, ADR 0003 §5)이 함께 쓰기 때문이다. 사람이 쓴 콘텐츠에도 같은 규칙이 걸린다.
- 예외 표시는 없다. 목록의 낱말이 꼭 필요한 문제가 생기면 그 낱말을 목록에서 뺀다.
- 목록은 표면 낱말만 잡는다. 뜻으로 판단할 것(조종 기술처럼 보이는 내용, 세대 갈등)은 판정 호출의 `논란`과 사람이 본다. ADR 0003 "넣지 않은 것"의 금지 표현 검사가 이것이다.

### 8. 프롬프트, 버전, 모델
- 파일: `pipeline/prompts/common.md`, `generate.md`, `blind.md`, `judge.md`. `common.md`에는 역할, 출력은 JSON만, id 규칙은 스키마를 따른다, 기존 항목은 고치지 않는다, `evidence` 규칙을 쓴다.
- 시스템 프롬프트는 세 호출이 같다: `common.md` + `docs/concept.md` 전문 + `content.schema.json` + `templateSpots` + 그 매너의 근거 요약(`summary`). 기획서의 콘텐츠 원칙(성별 중립, 의견이 갈리는 주제 제외, 조종 기술 제외, 3단계 채점, 정답 보기 길이)은 프롬프트에 옮겨 적지 않고 기획서를 그대로 넣는다. 기획서를 고치면 다음 실행부터 반영된다. 호출마다 다른 지시는 사용자 메시지에 넣는다.
- 프롬프트 캐시를 쓴다. 요청 최상위에 `cache_control: {"type": "ephemeral"}` 한 줄을 넣어 자동 캐시를 켠다. 세 호출이 몇 분 안에 같은 시스템 프롬프트로 차례로 가므로 2·3번째 호출이 읽기(입력 가격의 0.05배)로 처리된다. 기본 수명은 5분이라 검사가 길어지면 놓칠 수 있고, 놓쳐도 실행당 약 $0.08이 더 들 뿐이다.
- 버전은 git으로 관리하고 따로 번호를 두지 않는다. PR 본문에 실행한 커밋 SHA와 모델 id를 적는다. 워크플로가 `dev`에서만 비밀을 쓰므로 실제로 쓰이는 것은 머지된 프롬프트뿐이다. 프롬프트를 바꿔 볼 때는 개인 키로 로컬에서 돌린다.
- 모델은 `claude-opus-5-5`(2026-10-29 공식 문서의 현재 모델) 상수 하나로 세 호출에 쓴다. 더 싼 `claude-sonnet-5-5`로는 §12의 조건에서 바꾼다. `effort`는 기본값이고 `max_tokens`는 16,000이다. 생각 토큰도 이 안에 들어가고 출력으로 과금된다.
- 구조화 출력(`output_config.format`)은 쓰지 않는다. 우리 스키마의 `if/then`, `minLength`, `maxItems`, `minItems: 2`, 객체형 `additionalProperties`를 지원하지 않아서, 쓰려면 두 번째 스키마를 따로 만들어야 한다. 대신 응답 텍스트를 JSON으로 읽고(첫 `{`·`[`부터 마지막 `}`·`]`까지) ajv와 `validate.dart`가 검사한다.
- 요청 본문이 200KB를 넘으면 제출하지 않고 실패한다. 비용 상한(§12)이 이 값으로 정해진다.

### 9. 언어: Dart CLI `app/tool/pipeline.dart`
| 안 | 좋은 점 | 나쁜 점 |
| --- | --- | --- |
| **Dart, `app/tool/`(채택)** | `parseContent`, `expand`, `validate`, `templateSpots`를 import한다. 앱·검사기·파이프라인이 같은 id와 같은 검사를 본다. `package:http`가 이미 있고, `package:http/testing.dart`의 `MockClient`로 네트워크 없이 테스트한다. 새 패키지가 없다 | 공식 Dart SDK가 없어 Messages API POST 하나를 직접 짠다(약 30줄). 재시도가 없다 |
| Python 또는 TypeScript + 공식 SDK | SDK의 재시도, 타입 | 펼치기와 블라인드용 펼친 문제를 다시 짜거나 Dart를 따로 불러야 한다. ADR 0003 대안에서 같은 이유로 뺐다. 언어와 의존성이 하나 늘어난다 |

- 코드는 `app/tool/pipeline.dart` 한 파일에 둔다. `lib/` 밖이라 앱 번들에 들어가지 않는다. 순수 함수(`addScenarios`, `blind`, `prBody`, `openPipelinePr`)는 `app/test/pipeline_test.dart`에서 테스트한다. `checkSources`는 CI도 쓰므로 `validate.dart`에 둔다(§6).
- 요청: `POST /v1/messages` 하나. 헤더 `x-api-key`, `anthropic-version: 2023-06-01`. 응답의 `text` 블록을 이어 붙여 JSON으로 읽고, `usage`를 PR 본문에 옮긴다.
- 프롬프트와 근거 요약은 리포 루트 `pipeline/`에 둔다. 콘텐츠 담당이 앱 코드를 건드리지 않고 고친다.
- API 오류(429, 529, 5xx 포함)가 나면 실행이 실패하고, 사람이 다시 돌린다.

### 10. 비밀
- GitHub environment `content-pipeline`에 secret 둘을 둔다. 배포 브랜치는 `dev`만이다. 저장소 secret에 두지 않는다. 그러면 아무 브랜치의 워크플로가 읽을 수 있다(ADR 0003 §5와 같은 이유). 공개 리포의 포크 PR 워크플로에는 `GITHUB_TOKEN` 말고는 secret이 넘어가지 않는다. 이 워크플로는 `pull_request`로 돌지도 않는다.
  - `ANTHROPIC_API_KEY`: Claude 키.
  - `CONTENT_PR_TOKEN`: fine-grained PAT. 저장소 접근은 "Only select repositories"로 이 리포 하나만 고르고, 권한은 Contents 쓰기와 Pull requests 쓰기만 준다. 만료는 1년으로 둔다. 만료 없이 만들 수도 있지만 새면 계속 쓰이므로 두지 않는다.
- PAT는 브랜치를 가리지 못해서 `dev`에도 push할 수 있다. 워크플로 코드는 `content/` 브랜치에만 push한다. `dev` 보호 규칙이 생기면 그것도 막는다.
- PAT로 연 PR의 작성자는 토큰을 만든 사람의 계정이다. 그 사람은 자기 PR을 리뷰 승인할 수 없으므로 리뷰어는 다른 팀원이다(Notion "역할과 리뷰").
- Anthropic Console: Max 플랜과 연결한 조직에 파이프라인 전용 workspace를 만들고, 그 workspace에 묶인 키를 쓴다. 조직에 크레딧을 사서 넣지 않고 auto-reload도 켜지 않는다. 그러면 월간 크레딧($100, Max 5x)을 다 쓴 순간 요청이 멈추고 플랜에 청구되지 않는다. 같은 조직을 다른 일에도 쓰면 이 workspace에 월 지출 한도를 건다.
- 키 값은 코드, 설정, 문서, 로그 어디에도 적지 않는다. 로컬 실행은 셸 환경 변수로만 넘긴다.
- Claude에 보내는 것은 콘텐츠, 기획서, 근거 요약뿐이다. 사용자 데이터는 보내지 않는다.

### 11. PR 본문: 사람이 보고 승인하는 것
```markdown
근거 문서 없음                      ← 묶인 문서가 없을 때만, 첫 줄

## 무엇을
매너 4 "…"에 기본 시나리오 3개(펼친 문제 N개)를 더한다. content version 7 → 8. (새 매너면: 매너 항목도 더한다)

## 왜
ADR 0009 파이프라인 실행 <run 링크>

## 검토 표시 (Claude. 막지 않는다)
| 문제 | 종류 | 메모 |
| --- | --- | --- |
| `B-door-01` | 정답 | 블라인드 답 "…" |   ← 표시가 없으면 "없음"
| `B-door-02` | 형식 | 순서를 고르는 편이 상황에 맞다 |

## 새 문제 (자리 표시를 채운 지문)
- `B-door-01`: …

## 어떻게 확인했나
- 코드 검사: 오류 0, 경고 …(validate_content 출력 그대로)
- 모델 claude-opus-5-5 · 커밋 abc1234 · 호출별 토큰(입력/캐시 쓰기/캐시 읽기/출력)

## 사람이 확인할 것
- [ ] 새 문제를 모두 읽었다(지문, 정답, 해설). 매너 항목이 붙었으면 기획서 표와 같다
- [ ] 검토 표시를 하나씩 처리했다(고쳤거나, 괜찮은 이유를 댓글로 남겼다). `형식` 표시는 #26에 옮겼다
- [ ] 첫 줄이 "근거 문서 없음"이고 의전 매너(4·5·6·30)이면, ADR 0009 "근거가 불명확한 매너" 표에 그 매너가 있다
- [ ] content CI가 통과했다
```
- 새 문제 목록은 모든 형식에 있는 `prompt`만 쓴다. 형식별로 그리는 코드는 없다. 정답과 해설은 diff에서 본다.
- 사람이 고칠 것이 있으면 같은 브랜치에 커밋한다. 그러면 `content.yml`이 다시 돈다.

### 12. 비용
가격(2026-10-29): Opus 5.5는 입력 $4/MTok, 출력 $20/MTok, 5분 캐시 쓰기 $5/MTok, 캐시 읽기 $0.20/MTok(0.05배)다. Sonnet 5.5는 그 절반이다. 한국어 JSON은 바이트 2개에 토큰 1개로 어림했다. 새 토크나이저는 같은 글에서 토큰이 약 30% 더 나온다. 이 비율은 첫 실행의 `usage`로 확인한다.

| 항목 | 보통(지금 크기) | 상한 |
| --- | --- | --- |
| 시스템 프롬프트(공통 지시 3KB + 기획서 20KB + 스키마 9KB) | 약 1.6만 토큰. 호출 1에서 캐시 쓰기, 2·3에서 읽기 | 요청마다 200KB(약 10만 토큰)에서 막는다 |
| 사용자 메시지 3개 | 합 약 2.8만 토큰 | 위에 포함 |
| 입력 비용 | 약 $0.20 | 3 × 10만 × $4/M ≈ $1.2(캐시 없이) |
| 출력(생각 포함) | 약 1.9만 토큰, $0.38 | 3 × 16,000 × $20/M ≈ $0.96 |
| **실행당** | **약 $0.6** | **약 $2.2** |

- 매너 30개를 한 번씩 돌리면 보통 약 $18, 상한 약 $66이다. 월 크레딧 $100 안에 들어간다.
- 매달 쓴 돈이 크레딧의 70%($70)를 넘으면 먼저 모델 상수를 `claude-sonnet-5-5`로 바꾼다(절반). 그래도 넘으면 Batch로 옮긴다("넣지 않은 것").
- 크레딧은 이월되지 않는다. 콘텐츠 작업을 달마다 나눠 한다는 기획서 문장이 그대로 맞다. GitHub Actions의 `ubuntu-latest` 시간은 공개 리포라 따로 계산하지 않았다.

## 템플릿이 확정되면 바꿀 곳 (#26, #28)
파이프라인 코드, 워크플로, 프롬프트 파일은 바꾸지 않는다. 바꾸는 곳은 아래뿐이다.

| 바뀌는 것 | 고칠 곳 |
| --- | --- |
| 형식을 더하거나 빼거나 필드를 바꿈 | `content.schema.json`의 `format` enum과 형식 분기(`description` 포함). 형식만의 검사가 있으면 `validate.dart`(예: choice의 `best` 하나). 답이 담긴 새 필드가 있으면 `templates.dart`의 `blindHidden`·`blindShuffled` |
| 위치 장소를 더함(택시, 식당, 엘리베이터 등) | `content.schema.json`의 `template` enum, `templates.dart`의 `templateSpots`(두 곳이 같은지 테스트가 본다) |
| 카테고리를 영역 6개로 정함(#28 후보 1) | 없음. `area`가 이미 있다 |
| 카테고리를 다른 기준으로 정함 | `content.schema.json`의 `tags` 항목에 `enum`. 생성이 그때부터 `tags`를 쓴다(§2). 기존 시나리오 태그는 사람이 붙인다 |
| 근거 문서를 더함 | `pipeline/sources/sources.json`의 항목 하나(팀 요약 + 원문 링크) |

앱 화면(ADR 0002 작업 3)과 기존 콘텐츠의 옮기기는 이 ADR 밖이다. 첫 출시 전에는 schema 1 안에서 자유롭게 바꾼다(ADR 0003 §4). 파이프라인 PR에 쌓인 `형식` 표시는 #26을 정할 때 참고 자료가 된다.

## 고려한 대안
- **Batch API로 세 호출 돌리기**: 비용이 절반이다(실행당 약 $0.35, 매너 30개면 약 $8 차이). 대신 세 호출이 앞 결과를 기다리므로 Batch 셋을 차례로 제출하고 1분마다 상태를 확인해야 한다. 실행이 보통 1~3시간이 되고, Batch가 몰리면 job 6시간 한도에 걸린다. 마감 때 취소하는 처리와 수동 취소 뒤 남는 Batch까지 지켜봐야 한다. 사용자가 실행 상태를 지켜보기 어렵다고 해서 뺐다(2026-10-30).
- **예약 워크플로가 대기 중인 Batch를 이어받기**: 6시간 한도는 피하지만, Batch id와 단계를 다음 실행에 넘길 저장소와 예약 트리거가 생긴다. Batch로 옮길 때도 한 job 안 폴링부터 본다.
- **`GITHUB_TOKEN`으로 PR 열기**: 비밀이 하나 줄어든다. 대신 저장소 설정 "Allow GitHub Actions to create and approve pull requests"를 켜야 하고, 그 PR의 CI는 승인 대기 상태로 만들어져 사람이 매번 "Approve workflows to run"을 눌러야 한다. 완전 자동화 목표와 맞지 않는다.
- **GitHub App 토큰**: PAT처럼 CI가 바로 돌고 만료 갱신이 없다. 대신 App 생성, 설치, App id와 개인 키 두 비밀, 토큰 발급 단계가 생긴다.
- **브랜치만 올리고 사람이 PR을 연다**: 비밀과 설정이 늘지 않는다. 대신 사람이 매번 PR을 연다.
- **`pgvector` 검색(원안)**: §6. 문서 0개에서 시작하는데 임베딩 서비스, 키, 테이블, 조각내기가 먼저 생긴다.
- **기획 에이전트를 따로 부르기(원안 1단계)**: 생성 호출이 기존 시나리오를 이미 보므로 호출만 하나 는다.
- **블라인드 여러 번(원안)**: 표본이 커지면 "너무 쉬움"도 잴 수 있다. 대신 호출이 횟수만큼 는다. 한 번으로 시작하고, Claude가 놓친 애매한 문제를 사람이 PR에서 두 번 넘게 찾으면 늘린다.
- **검사 실패 때 오류를 붙여 한 번 더 생성**: 실패율을 모른다. 세 번 중 한 번 넘게 검사에서 실패하면 넣는다.
- **Claude Agent SDK, `claude-code-action`**: 파일을 고치는 에이전트가 필요한 일이 아니다. JSON 하나를 받으면 된다. Claude Code는 월간 API 크레딧 대상도 아니다.
- **형식별 프롬프트 파일, 형식별 블라인드 함수**: 템플릿이 바뀔 때마다 파이프라인을 고쳐야 한다. 사용자 요구(§4)와 반대다.

## 결과
- **쉬워지는 것**: 매너 id 하나를 넣고 버튼을 누르면, 사람 손 없이 검사를 통과하고 CI가 돈 PR이 15분쯤 안에 열린다. 템플릿·카테고리·근거 문서가 정해지면 정의 파일만 고치고 같은 버튼을 다시 누른다. 앱·CI·파이프라인이 같은 검사 함수를 쓴다.
- **어려워지는 것**
  - 사람이 모든 새 문제를 읽어야 한다(PR 하나에 기본 시나리오 3개).
  - 파이프라인 PR은 한 번에 하나만 열린다.
  - PAT를 1년마다 갱신해야 한다. 만료일을 팀 캘린더에 적고, 만료 2주 전에 새로 만들어 secret을 바꾼다. 놓치면 1단계에서 실패하고 돈은 쓰지 않는다.
- **확인할 점**
  - 네트워크·API 실패: 실행이 실패하고 아무것도 push하지 않는다. 다시 돌린다. 앱은 영향이 없다(앱 실행 중 AI 없음).
  - 같은 요청 두 번(같은 매너로 두 번 실행): `concurrency`가 차례로 돌린다. 앞 실행이 PR을 열었으면 뒤 실행은 1단계에서 실패한다. 앞 실행이 PR 전에 실패했으면 뒤 실행이 정상으로 돈다.
  - 기기 두 대에 해당하는 것(두 사람이 동시에 실행, 사람 콘텐츠 PR과 겹침): 파이프라인끼리는 위와 같다. 사람 PR과 `version`·id가 겹치면 뒤에 머지하는 PR의 `content.yml`이 `--previous` 비교로 잡는다. 단, CI는 기준 브랜치가 바뀌어도 다시 돌지 않는다. `dev`에 "브랜치 최신 상태 요구" 보호 규칙이 없으면 사람이 머지 직전에 PR을 갱신해야 한다.
  - 콘텐츠 업데이트: 붙이기만 하고 `version`을 올리므로 ADR 0003의 id·버전 규칙을 지킨다. 지운 id는 기존 검사가 막는다.
  - 탈퇴: 사용자 데이터를 다루지 않는다.
- **넣지 않은 것과 넣을 시점**
  - 사람이 매번 누르지 않는 실행(예약 실행이 아직 콘텐츠에 없는 가장 작은 매너 id를 골라 돌린다): 템플릿(#26)이 확정되고, 파이프라인 PR 다섯 개가 연달아 큰 수정 없이 머지될 때. 입력이 매너 id 하나라 예약 트리거와 고르는 함수 하나만 더하면 된다.
  - Batch API: `claude-sonnet-5-5`로 바꾼 뒤에도 월 사용액이 크레딧의 70%($70)를 넘을 때. `docs/decisions.md`의 "급하지 않은 일은 Batch"가 그때 이 실행에도 적용된다. 한 job 안에서 제출하고 폴링하는 구조부터 본다(고려한 대안).
  - 재시도(API 오류, 검사 실패 재생성): 같은 이유로 세 번 중 한 번 넘게 실패할 때.
  - 블라인드 여러 번과 "너무 쉬움": 사람이 애매한 문제를 두 번 넘게 따로 찾을 때.
  - 출시 후 재검토 입력(정답률, 오류 신고): 출시 뒤 `answer` 이벤트에 정답률이 극단(예: 95% 오답)인 문제가 보일 때. 오류 신고는 그 기능의 ADR에서 정한다. 출시 뒤 정답률과 오류 신고를 볼 때는 "근거가 불명확한 매너" 표의 매너(지금 4, 6)를 먼저 본다.
  - 실행 입력 늘리기(시나리오 수, 방향 메모): 같은 매너를 원하는 방향으로 다시 돌리는 일이 반복될 때.
  - 데일리 생성: 매너가 데일리를 다 채우지 못할 만큼 늘 때.
  - 근거 검색(`pgvector` 등): §6의 100KB 조건.
- **다시 볼 조건**: 모델 은퇴(Opus 5.5는 2027-09-22 이전에는 은퇴하지 않는다), 가격·크레딧 정책 변경, 기여자가 늘어 파이프라인 PR이 동시에 여러 개 필요할 때.

## 찾은 것 (코드·기획서와 어긋남)
1. **지금 콘텐츠의 출처가 "공공기관 문서만" 규칙과 맞지 않는다.** `app/assets/content.json`에서 `A-sidewalk`·`A-alley`는 뉴스 기사(메디컬데일리, 쿠키뉴스)를, `A-stairs`는 미국 병원 안내문(UW Medicine)을 출처로 든다. 작업 A4에서 공공기관 문서로 바꾸거나 비운다.
2. 저장소 설정 "Actions가 PR을 만들고 승인"이 꺼져 있다(`can_approve_pull_request_reviews: false`). 이 ADR에서도 켜지 않는다. `dev`에는 보호 규칙이 없다(`GET branches/dev/protection` → 404). 그래서 지금은 CI가 실패한 PR도 머지할 수 있다.
3. 스키마 `template` enum과 `templateSpots` 키가 같은 목록을 두 곳에 갖고 있다(§4, 테스트로 묶는다).
4. `README.md`는 `pipeline/`을 "Claude 문제 생성·검토 스크립트"라고 쓴다. 이 ADR에서는 코드가 `app/tool/pipeline.dart`에 있고, `pipeline/`에는 프롬프트와 근거 문서가 있다.
5. 기획서 "AI 활용 방식"은 원안이다. 이 ADR이 채택되면 §1 표의 차이(기획 에이전트 없음, 블라인드 1번, `pgvector` 없음, `형식` 표시, 사람이 전부 봄)를 기획서에 반영할지 사람이 정한다.
6. 기획서 "AI 활용 방식"의 "라이선스" 문단(공공누리 1유형만 쓴다)은 §6과 다르다. 기획서를 고칠지는 사람이 정한다.

## 다른 문서에 미치는 영향 (채택할 때 사람이 고친다)
- `docs/decisions.md`: 고칠 것 없다. "급하지 않은 일은 Batch API로 돌린다"에서 이 실행은 사람이 결과 PR을 기다리는 작업이라 "급하지 않은 일"로 보지 않고 직접 호출한다. 지금 Batch를 쓰는 곳은 없다. 이 해석을 `decisions.md`에 적을지(예: "파이프라인 실행은 직접 호출, ADR 0009")는 사람이 정한다.
- ADR 0003 "넣지 않은 것"의 금지 표현 줄: "ADR 0009 §7에서 정함"으로 바꾼다.
- `README.md`의 `pipeline/` 줄: "프롬프트와 근거 요약(코드는 `app/tool/pipeline.dart`, ADR 0009)". `docs/` 밖이라 작업 A1에서 고친다.
- `docs/concept.md` "AI 활용 방식": 찾은 것 5, 6.
- `docs/concept.md` "콘텐츠"의 "상석·의전 항목(4, 5, 6, 30번)은 공신력 있는 근거를 확인한 뒤에 문제로 만든다"와 어긋난다. 4·6번은 근거 없이 낸다(2026-10-30 사용자). 기획서는 고치지 않았다. 고칠지는 사람이 정한다.
- ADR 0003 §3과 `app/assets/content.schema.json`: `source.locator`를 선택으로 바꾼다(작업 A3). ADR 0002 §2 `Source.locator`는 null이 될 수 있게 바꾼다.

## 작업 목록
**A. 지금 할 것(템플릿·카테고리·근거 문서 없이).** A3 → A4는 순서를 지킨다. 출처 대조를 CI에 켜기 전에 출처를 비운다.
| # | 담당 | 작업 | 먼저 쓸 실패하는 테스트 | 확인 방법 |
| --- | --- | --- | --- | --- |
| A1 | 사용자 | `README.md` `pipeline/` 줄, ADR 0003 금지 표현 줄 고치기 | 문서라 없다 | PR diff |
| A2 | 사용자 | `content.yml`의 검사 두 명령을 `.github/scripts/check_content.sh <파일> [이전 파일]`로 옮기고, `content.yml`이 그것을 부른다(동작 변화 없음) | `check_content_test.sh`: 이전 파일에 있던 `A-alley~child`를 지운 파일로 돌리면 종료 코드 1이고 출력에 그 id가 있다 | 초안 PR에서 `content.yml` 통과. 같은 테스트가 CI에서 돈다 |
| A3 | 사용자 | `validate.dart`에 `checkSources(Content, 색인)`, `validate_content`에 `--sources=` 플래그(아직 CI에 켜지 않는다). 스키마 `source.locator`를 선택으로 바꾸고, `backend.dart`의 `Source.locator`를 `String?`로 바꾼다 | 색인에 없는 `url`을 가진 출처는 오류다. 색인 항목에 `publisher`나 `summary`가 없으면 오류다. `summary`가 1,001자면 오류다. 매너 4에만 묶인 문서를 매너 1 시나리오가 들면 오류다. `publisher`나 `title`이 색인과 다르면 오류다. 빈 `sources`는 통과한다. ajv가 `locator` 없는 출처를 `valid`로 본다 | `cd app && flutter analyze && flutter test` |
| A4 | 콘텐츠 담당 + 사용자 | `A-sidewalk`, `A-alley`, `A-stairs`의 출처를 공공기관 문서로 바꾸거나 비운다(`summary`는 남긴다). 바꿀 문서는 `sources.json`에 요약 항목으로 먼저 더한다. 예: 매너 3은 사용자가 조사한 연수구 장애인 에티켓 문서. 매너 1은 원래 기사가 인용한 기관(질병관리본부, 경찰) 문서를 찾으면 쓰고, 못 찾으면 비운다. 그 뒤 `version`을 올리고 `check_content.sh`에 `--sources`를 켠다 | `check_content_test.sh`: 실제 `content.json`과 실제 색인으로 출처 대조를 돌리면 종료 코드 0이다. 지금은 세 시나리오 때문에 1이다 | 초안 PR에서 `content.yml` 통과 |
| A5 | 사용자 | `templates.dart`에 `blindHidden`·`blindShuffled`, 스키마 형식 분기마다 `description` | `pipeline_test`: 스키마 `template` enum과 `templateSpots` 키가 같다. `description`이 없는 형식 분기가 있으면 실패한다 | `flutter test`. ajv가 지금 파일에 `valid` |
| A6 | 사용자 | `app/tool/pipeline.dart` 순수 함수 `blind`, `addScenarios`, `openPipelinePr`, `prBody`. 프롬프트 검사 테스트 | `blind`: `A-umbrella-01`을 펼친 문제 어디에도 `grade`·`feedback`이 없고, `options`의 문장 집합은 같다. `addScenarios`: 지금 파일에 시나리오 하나를 붙이면 `version`이 하나 오르고 나머지 바이트는 그대로다. 매너 99가 없으면 매너 항목이 함께 붙는다. `openPipelinePr`: head가 `content/manner-2-1`인 PR이 목록에 있으면 참이다. `prBody`: 묶인 문서가 없으면 첫 줄이 "근거 문서 없음"이고, `kind: "형식"` 표시가 표의 한 줄이 된다. 프롬프트 파일에 스키마 `format`·`template` enum 값이 있으면 실패한다 | `cd app && flutter analyze && flutter test` |
| A7 | 사용자 | Messages API 호출(`package:http`, `MockClient`) | 요청 본문에 `model: "claude-opus-5-5"`, `max_tokens: 16000`, 최상위 `cache_control`이 있고 헤더에 `anthropic-version`이 있다. `MockClient`가 `stop_reason: "max_tokens"`를 주면 예외가 난다. 429나 529를 주면 다시 보내지 않고 예외가 난다. 본문이 200KB를 넘으면 요청을 보내지 않는다 | 같은 명령 |
| A8 | 콘텐츠 담당 | `pipeline/prompts/` 네 파일. `judge.md`에는 `정답`·`논란`·`근거`·`형식` 네 표시를 형식 이름 없이 쓴다(§4) | A6의 프롬프트 검사 테스트가 이 파일들로 돈다 | 개인 키로 로컬 실행: `cd app && ANTHROPIC_API_KEY=… dart run tool/pipeline.dart 2 /tmp/open.json /tmp/pr.md`. 키는 셸에만 둔다 |
| A9 | 사용자 | `validate.dart`의 `bannedWords`(§7 목록) | 선택지 문장에 "여자친구"가 있으면 오류다. 같은 낱말이 `evidence.sources[].title`에만 있으면 오류가 아니다. 지금 `content.json`은 오류가 없다 | `flutter test`. `validate_content` 종료 코드 0 |
| A10 | 사용자 | `.github/workflows/content-pipeline.yml`(§5) | 워크플로라 테스트를 먼저 쓰지 않는다. 판단 로직은 A6·A7에 있다 | `dev` 머지 뒤 매너 2로 수동 실행 → 사람 손 없이 PR이 열리고 §11 본문이 채워지며, `content.yml`이 승인 클릭 없이 돌아 통과한다 |
| A11 | 사용자(저장소 소유자) | Console 전용 workspace와 키. fine-grained PAT(이 리포만, Contents·Pull requests 쓰기, 만료 1년, 만료일을 팀 캘린더에). environment `content-pipeline`(secret 둘, 배포 브랜치 `dev`) | 설정이라 없다 | `dev`가 아닌 브랜치에서 실행하면 environment 단계에서 거절된다. 저장소 설정 "Actions가 PR을 만들고 승인"은 꺼진 그대로다 |

**B. 템플릿(#26)·카테고리(#28)가 정해진 뒤**
| # | 담당 | 작업 | 먼저 쓸 실패하는 테스트 | 확인 방법 |
| --- | --- | --- | --- | --- |
| B1 | 사용자 | 위 "템플릿이 확정되면 바꿀 곳" 표대로 스키마·`templates.dart`(·`validate.dart`)를 고친다. 파이프라인 파일은 고치지 않는다 | 새 장소의 자리 id를 쓴 위치 문제가 `templateSpots`에 없으면 오류다(기존 테스트에 장소 하나를 더한다). A5의 enum 일치 테스트 | 새 장소를 쓰는 매너로 파이프라인 실행 |
| B2 | 콘텐츠 담당 | 매너 4~30을 하나씩 실행해 PR로 머지한다(한 번에 하나) | 없다(콘텐츠) | PR마다 §11 체크리스트 |

**C. 근거 요약을 더할 때**
| # | 담당 | 작업 | 먼저 쓸 실패하는 테스트 | 확인 방법 |
| --- | --- | --- | --- | --- |
| C1 | 콘텐츠 담당 | 조사한 공공기관 문서(매너 5, 30, 10, 3, 9, 7·22)마다 원문을 읽고 `sources.json`에 요약 항목 하나를 더한다. 원문 문장은 옮기지 않는다 | A3 테스트가 실제 색인으로도 돈다(필수 칸, 1,000자) | 묶인 매너로 실행한 PR의 첫 줄에 "근거 문서 없음"이 없고, `evidence.sources`가 색인과 같다. 색인 PR에서 리뷰어가 원문과 요약을 대조해 옮겨 적은 문장이 없는지 본다 |

## 열린 질문 (사용자 결정 필요)
없음.

정해진 것(2026-10-30 사용자):
1. **Messages API를 직접 호출한다.** Batch는 고려했다가 실행 상태를 지켜보기 어려워 뺐다(2026-10-30 사용자). 한때 Batch로 정했다가(같은 날) 되돌렸다. Batch로 옮길 시점은 "넣지 않은 것"에 적었다.
2. **앱 출처는 공공기관 문서만 쓰고, 팀 요약 + 원문 링크로 둔다**(§6). 같은 날 처음에는 "공공누리 1유형만"으로 정했다가 바꿨다. 매너 내용과 1유형을 함께 갖춘 공공 문서가 없었고, 원문을 복사하지 않으면 1유형이 필요 없기 때문이다. 출처 대조는 CI에서 전체 콘텐츠에 건다. 지금 세 시나리오의 출처는 먼저 공공기관 문서로 바꾸거나 비운다(작업 A4).
3. **PR은 완전 자동으로 연다.** 이 리포만 쓸 수 있는 fine-grained PAT(`CONTENT_PR_TOKEN`)로 push하고 PR을 열어 CI가 바로 돈다. 저장소 설정 "Allow GitHub Actions to create and approve pull requests"는 켜지 않는다. 머지는 사람이 한다(`docs/decisions.md`). 실행 트리거 자동화는 지금 넣지 않는다. 넣을 시점은 "넣지 않은 것"에 적었다.
4. **금지 표현 첫 목록은 추천 목록 그대로다**(§7).
5. **근거 문서가 없으면 PR 첫 줄에 표시만 하고 막지 않는다.** 의전 매너(4, 5, 6, 30)이면 머지 전에 "근거가 불명확한 매너" 표에 올린다(§6). 근거 필수 매너 목록을 코드 상수로 두고 실행을 거절하는 안은 제품 결정이 코드에 하나 더 생겨서 뺐다.
6. **판정에 `형식` 표시를 더한다**(§3, §4). 표시만 하고 막지 않는다.
7. **매너 4(식당 상석)·6(엘리베이터 상석)은 근거 없이 관례 문제로 낸다.** 공공 문서가 없었기 때문이다. 근거가 불명확하다는 사실은 §6의 "근거가 불명확한 매너" 표 한 곳에 남긴다. 공공 문서가 생길 때까지 내지 않는 안(매너 28개로 시작)은 고르지 않았다.

## 확인한 것 (2026-10-29, 2026-10-30)
- 현재 모델 id는 `claude-opus-5-5`, `claude-sonnet-5-5`, `claude-haiku-5-5`, `claude-fable-5-1`이다. 컨텍스트 1M, 동기 최대 출력 128K다. Opus 5.5는 생각이 늘 켜져 있고 기본 effort는 `medium`이며, 2027-09-22 이전에는 은퇴하지 않는다([모델 개요](https://platform.claude.com/docs/en/about-claude/models/overview)).
- 가격: Opus 5.5는 $4·$20, 5분 캐시 쓰기 $5, 캐시 읽기 $0.20(0.05배)이고, Batch에서는 $2·$10이다. Sonnet 5.5는 $2·$10이다. 4.7 이후 토크나이저는 같은 글에 토큰이 약 30% 더 나온다([가격](https://platform.claude.com/docs/en/about-claude/pricing)).
- Batch: 대부분 1시간 안에 끝나고, 24시간 안에 끝나지 않으면 만료된다. 결과는 29일 보관한다. 상태는 `processing_status`가 `ended`가 될 때까지 확인하고, 결과는 `results_url`에서 받는다. 결과 종류는 `succeeded`·`errored`·`canceled`·`expired`이고, 취소·만료된 요청은 과금되지 않는다. 비동기라 캐시 적중이 보장되지 않는다([Batch](https://platform.claude.com/docs/en/build-with-claude/batch-processing)).
- 캐시: 5.5 모델의 최소 길이는 512토큰이고 기본 수명은 5분이다. 요청 최상위 `cache_control`로 자동 캐시를 쓴다. 캐시는 workspace별로 나뉜다([프롬프트 캐시](https://platform.claude.com/docs/en/build-with-claude/prompt-caching)).
- 생각 토큰은 출력으로 과금되고 `max_tokens`에 들어간다([생각](https://platform.claude.com/docs/en/build-with-claude/thinking)).
- 구조화 출력은 GA이고 `output_config.format`으로 쓴다. 숫자·문자열 길이 제약, 0·1이 아닌 `minItems`, `false`가 아닌 `additionalProperties`를 지원하지 않는다([구조화 출력](https://platform.claude.com/docs/en/build-with-claude/structured-outputs)).
- Max 5x는 월 $100, Max 20x는 월 $200의 API 크레딧을 받는다. 연결한 Console 조직에서 Claude API와 Agent SDK에 쓰이고, Claude Code에는 쓰이지 않는다. 다음 달로 넘어가지 않는다. 다 쓰면 산 크레딧이 없는 한 요청이 멈추고 플랜에는 청구되지 않는다. 가입 7일 뒤부터 받는다. workspace별로 월 지출 한도를 걸 수 있다([구독자 API 크레딧](https://platform.claude.com/docs/en/about-claude/api-credits-for-subscribers), [workspace](https://platform.claude.com/docs/en/manage-claude/workspaces)).
- Anthropic에는 자체 임베딩 모델이 없다([임베딩](https://platform.claude.com/docs/en/build-with-claude/embeddings)).
- GitHub 호스트 러너의 job은 6시간에서 끊기고 실패한다. Batch 대안을 판단할 때 썼다([Actions 한도](https://docs.github.com/en/actions/reference/limits)).
- `GITHUB_TOKEN`으로 열거나 갱신한 PR의 `pull_request` 실행은 승인 대기 상태로 만들어진다. GitHub App 토큰이나 PAT로 열면 그런 실행이 승인 없이 바로 돈다([트리거](https://docs.github.com/en/actions/how-tos/write-workflows/choose-when-workflows-run/trigger-a-workflow)).
- 수동 실행에는 쓰기 권한이 필요하다([수동 실행](https://docs.github.com/en/actions/how-tos/manage-workflow-runs/manually-run-a-workflow)). 포크에서 시작한 실행에는 `GITHUB_TOKEN` 말고는 secret이 넘어가지 않는다([secret](https://docs.github.com/en/actions/how-tos/write-workflows/choose-what-workflows-do/use-secrets)). environment secret은 그 environment를 쓰는 job에만 열리고, 배포 브랜치를 제한할 수 있다([environment](https://docs.github.com/en/actions/how-tos/deploy/configure-and-manage-deployments/manage-environments)). 개인 계정 리포는 기본으로 워크플로가 PR을 만들 수 없다([리포 Actions 설정](https://docs.github.com/en/repositories/managing-your-repositorys-settings-and-features/enabling-features-for-your-repository/managing-github-actions-settings-for-a-repository)).
- fine-grained PAT는 "Only select repositories"로 리포를 고르고, 권한은 Contents와 Pull requests를 읽기·쓰기로 준다. 만료는 고를 수 있고, 조직 정책이 없으면 만료 없음도 된다([PAT 관리](https://docs.github.com/en/authentication/keeping-your-account-and-data-secure/managing-your-personal-access-tokens)).
- 이 리포: Actions 기본 권한은 `read`, `can_approve_pull_request_reviews`는 `false`이고, `dev`에는 보호 규칙이 없다. environment는 `gh api`로 조회되지 않았다(빈 목록).
- 사용자 조사(2026-10-30, 아키텍트가 문서를 직접 열어 보지는 않았다): 매너 내용과 공공누리 1유형을 함께 갖춘 공공 문서는 없었다. 내용이 맞는 공공 문서는 외교부 「자동차 속에 숨겨진 의전」(매너 5, All rights reserved), 국립특수교육원 직장 예절(30, 유형 표시 없음), 국가유산청 한식 식사 예절(10), 연수구 장애인 에티켓(3, 2유형), 연수구 승강기사고(9, 3유형), 서울시 지하철 10대 에티켓(7·22, 4유형)이다. 매너 4·6은 공공 문서가 없었다.

## 확인하지 못한 것
- 한 호출이 실제로 걸리는 시간(실행 10~15분은 추정). 첫 실행에서 확인한다.
- 한국어 콘텐츠의 실제 바이트당 토큰 수. §12는 2바이트당 1토큰으로 어림했다. 첫 실행 PR 본문의 `usage`로 확인한다.
- 팀 요약 + 원문 링크가 저작권상 문제없다는 것은 사용자 판단이다("사실을 팀이 직접 쓴 요약과 링크는 본문 복사가 아니다"). 법률 검토는 하지 않았다.
- 외국 공공기관 문서(예: 지금 `A-stairs`의 UW Medicine)를 "공공기관 문서"로 볼지는 정하지 않았다. 작업 A4에서 국내 문서로 바꾸므로 지금은 쓰는 곳이 없다.
- `content-publish` environment가 실제로 있는지. `gh api repos/…/environments`가 빈 목록을 돌려줬는데, 권한 문제인지 정말 없는지 모른다.
- GitHub Free 개인 리포에서 environment 배포 브랜치 제한이 `workflow_dispatch` 실행(실행할 브랜치를 사람이 고름)에도 걸리는지. 문서는 배포 브랜치 제한만 말하고 트리거 종류는 말하지 않는다. 작업 A11의 확인 방법으로 확인한다.
- GitHub가 fine-grained PAT 만료 전에 알림 메일을 보내는지. 보내지 않는다고 보고 팀 캘린더로 관리한다.
- Opus 5.5가 생성 1회에 실제로 생각 토큰을 얼마나 쓰는지(보통 6,000으로 추정).

## 참고 (2026-10-29, 2026-10-30 확인)
- Anthropic: [모델 개요](https://platform.claude.com/docs/en/about-claude/models/overview), [가격](https://platform.claude.com/docs/en/about-claude/pricing), [프롬프트 캐시](https://platform.claude.com/docs/en/build-with-claude/prompt-caching), [Batch](https://platform.claude.com/docs/en/build-with-claude/batch-processing), [생각](https://platform.claude.com/docs/en/build-with-claude/thinking), [구조화 출력](https://platform.claude.com/docs/en/build-with-claude/structured-outputs), [구독자 API 크레딧](https://platform.claude.com/docs/en/about-claude/api-credits-for-subscribers), [workspace와 지출 한도](https://platform.claude.com/docs/en/manage-claude/workspaces), [임베딩](https://platform.claude.com/docs/en/build-with-claude/embeddings)
- GitHub: [Actions 한도](https://docs.github.com/en/actions/reference/limits), [워크플로 트리거와 `GITHUB_TOKEN`](https://docs.github.com/en/actions/how-tos/write-workflows/choose-when-workflows-run/trigger-a-workflow), [수동 실행](https://docs.github.com/en/actions/how-tos/manage-workflow-runs/manually-run-a-workflow), [secret](https://docs.github.com/en/actions/how-tos/write-workflows/choose-what-workflows-do/use-secrets), [environment](https://docs.github.com/en/actions/how-tos/deploy/configure-and-manage-deployments/manage-environments), [리포 Actions 설정](https://docs.github.com/en/repositories/managing-your-repositorys-settings-and-features/enabling-features-for-your-repository/managing-github-actions-settings-for-a-repository), [PAT 관리](https://docs.github.com/en/authentication/keeping-your-account-and-data-secure/managing-your-personal-access-tokens)
- 기준 문서: `docs/decisions.md` "AI", `docs/concept.md` "콘텐츠"·"AI 활용 방식", ADR 0002 §2(`Evidence`), ADR 0003 §1~6, ADR 0006 §1(`answer`), `app/lib/content/{content,validate,templates}.dart`, `app/tool/validate_content.dart`, `.github/workflows/content.yml`·`content-publish.yml`, 이슈 #26·#28

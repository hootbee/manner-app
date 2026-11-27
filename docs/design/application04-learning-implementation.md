# 대중교통 04번 응용 — 승인된 학습 기능 완성

사용자가 확정한 6개 정답 순서·힌트·교육 문구를 반영했다. 이전 B안 UI 연동 보고서의 승인 대기 상태를 대체한다.

## 구현

- 판정 데이터 `acceptedOrders`를 공통 순서형 상태에 추가했다. 기존 문제는 종전 `correctOrder` 한 개를 그대로 사용한다. 04번 응용은 A·B·D의 모든 순열 뒤에 C가 있는 6개를 인정한다. 중복·누락·미등록 ID가 있는 판정 데이터는 거절한다.
- 초기 순서 A→B→C→D, 드래그 중 제출 금지, 드래그 자체 판정 없음, 제출 후 O/X·선택 캐릭터 공통 팝업·효과음·기존 진동 규칙을 유지한다. 총 4회 제한 및 남은 횟수를 표시한다.
- 확정 힌트 2개를 기존 `MannersHintBubble`에 전달한다. 선택 캐릭터의 기존 생각 프로필, 좌우 16dp 패딩을 유지한다. 이번 화면만 가장 긴 문구에 맞춰 두 단계의 높이를 같게 계산한다. 다른 문제의 기존 높이 기본값은 유지했다. 힌트는 카드 순서·시도 횟수를 변경하지 않는다.
- 네 번째 실패 후 기존 정답 확인 버튼으로 B→D→A→C를 공개한다. A·B·D의 다른 순서도 정답이라는 설명, 성공 기록 및 XP 미지급 안내를 표시한다. 공개 상태의 `success`는 false이다.
- 기존 해설 컴포넌트의 선택적 간단 카드 표시를 사용한다. 핵심 매너 → 왜 중요한가요? → 실전 팁 → 학습 핵심 및 작은 캐릭터 프로필 순서이다. 펼치기 버튼·Q&A·법적 의무 문구·별도 대제목은 추가하지 않았다. 다른 해설은 기존 표시 기본값을 유지한다.
- 문제 다시 풀기는 현재 응용 풀이만 초기화한다. 저장된 보상은 초기화하지 않는다.
- 실제 기본 문제의 직접 정답/정답 공개 결과를 응용 진입 시 전달한다. 응용 해설의 학습 완료 버튼에서 기존 `TopicCompletionScreen`을 사용하고, 완료 후 기존 다음 문제 콜백으로 05번에 연결한다.

## 보상

기존 `TopicCompletionBinding` / `TopicCompletionGateway`를 사용하며 화면이 직접 XP·레벨을 계산하지 않는다. 완료 화면은 서비스의 실제 before/after 프로필로 XP 및 게이지를 표시한다. 캐릭터·꽃가루·상단 버튼·완료 화면 디자인은 수정하지 않았다.

- 주제 키: `transit_04`. 다른 주제와 구분하여 사용자별 최초 완료 키를 재사용한다.
- 현재 최초 직접 정답 설정은 기존 공통 체험용 보상과 같은 **20 XP**이며 `content/reward_policy.json`에서 변경 가능하다.
- 기본 또는 응용에서 정답 공개를 사용하면 **0 XP**이다. 이번 요청의 최종 실패 미지급 규칙을 적용했다.
- 최초 완료 기록이 이미 있으면 복습은 **0 XP**이다. 최종 실패로 처음 완료한 뒤 다시 풀어도 추가 보상을 지급하지 않는다.
- 기본 해설까지 완료한 결과가 없는 단독 진입에서는 세트 완료 보상을 만들지 않는다.
- 현재 체험 앱은 기존의 영속 저장·중복 방지 어댑터를 사용한다. 운영 서버용 Gateway 구현·연결은 기존 별도 작업이며 이번 변경에서 새 서버 API를 만들지 않았다.

## 변경 파일

| 파일 | 변경 |
| --- | --- |
| `app/lib/screens/application04_screen.dart` | 승인 데이터 로드, 짧은 해설, 완료 서비스 연결 |
| `app/lib/screens/sequence_lesson_state.dart` | 복수 정답·데이터 검증·제출 상한 |
| `app/lib/screens/sequence_lesson_screen.dart` | 선택적 해설·완료 콜백, 권장 순서 설명·남은 횟수 |
| `app/lib/screens/transit04_screen.dart` | 기본 결과·사운드 전달, 응용 완료 후 다음 문제 연결 |
| `app/lib/screens/manners_hint_bubble.dart` | 선택적으로 긴 힌트 기준 동일 높이 계산 |
| `app/lib/screens/lesson_explanation_screen.dart` | 선택적으로 간단 해설 카드를 펼침 없이 표시 |
| `app/assets/application04/spec/problem_sequence_transit04.json` | 승인 정답 6개·힌트·피드백 |
| `app/assets/application04/spec/state_asset_mapping.json` | 승인 상태 및 콘텐츠 경로 동기화 |
| `app/assets/application04/content/explanation.json` | 사용자 최종 교육 문구 |
| `app/assets/application04/content/reward_policy.json` | 주제별 보상 및 정답 공개 0 XP 설정 |
| `app/pubspec.yaml` | 교육 데이터 경로 등록 |
| `app/test/application04_test.dart` | 승인 후 버튼·판정·기본→응용 기대값 갱신 |
| `app/test/application04_learning_test.dart` | 24순열, 힌트, 실패·완료·보상·반응형·이동 검사 |
| `app/test/transit05_screen_test.dart` | 04번 기본·응용·완료를 거쳐 실제 05번 화면으로 이동하는 검사 갱신 |

## 검증

승인 PNG 7개는 원본과 SHA-256이 일치한다. 장면 3개, 카드 4개, 제목·상황 설명·976×397 비율·BoxFit.contain을 유지했다. QA 이미지는 런타임에 사용하지 않는다. 명세 JSON은 이번 사용자 승인에 맞춰 수정했으며, 원본 추출 패키지는 별도로 그대로 보관했다.

- 카드 24순열 전수 검사: 승인 6개 정답, 나머지 18개 오답.
- 모든 카드 1회 포함 검증, 드래그 중 제출 차단, 제출 전 판정 없음.
- 캐릭터 3종 힌트 1→2, 동일 높이·프로필, 카드 순서·횟수 유지.
- 4회 실패·재도전 제한·권장 순서 공개·성공 false·완료 0 XP.
- 최초 직접 정답 보상, 레벨 경계, 동시에 완료/재진입/서비스 재생성/복습의 중복 지급 방지.
- 기본 정답 공개 상태도 0 XP, 미완료 세트는 보상 차단.
- 기본→응용→해설→완료→다음 문제 콜백.
- 320·360·390dp 캐릭터별 화면, 320dp 2배 글자에서 힌트·해설·다시 풀기.

새 학습 기능·전수 검사 31개가 통과했다. 관련 회귀 검사 16개 파일에서 나머지 176개가 통과했고, 종전 기본→05번 직행을 가정하던 이동 검사를 새 기본→응용→완료→05번 흐름으로 갱신한 뒤 05번의 7개 검사도 모두 통과했다. 현재 확인된 미해결 기능 오류는 없다. 코드 분석(`flutter analyze --no-pub`)은 문제 없음이며, 웹 빌드(`main_prototype.dart`)도 성공했다.

실제 Android/iOS 기기 검수 및 실서버 보상 검수는 미실시했다. 커밋·푸시는 하지 않았다.

## 실행 자료

`C:/Users/gjo49/Documents/Codex/application04-review/`:

- `learning-captures/`: 실제 Flutter 힌트·해설·완료·최종 실패 캡처.
- `learning04-completion-characters.png`: 캐릭터 3종 실제 완료 화면.
- `learning-asset-verification.json`: PNG 원본 유지 및 승인 상태.
- `learning-capture.log`, `learning-regression.log`, `learning-navigation.log`, `learning-analyze-final.log`, `learning-web-build.log`: 검사 근거.

# 03번 임산부 배려석 기본 문제 구현

2026-11-21 사용자 검수 결과와 새 PNG 10장을 최종 기준으로 반영했다. 기본 선택형 문제만 구현했으며, 응용 문제를 추가하지 않았다. 문제 ID는 `subway_03_basic`, 기존 학습 목록·저장 세션 ID는 `transport-3`이다.

## 자료 비교 및 적용 기준

| 구분 | 실제 사용한 자료 |
| --- | --- |
| 문제·선택지·힌트·선택별 피드백·판정 횟수 | 기본 ZIP의 `problem_choice_subway03.json`, 원문 그대로 |
| 교육 해설 | 기본 ZIP의 `education_content_subway_03_basic.md`, 이유 3개·Q&A 3개·출처 3개 전체 |
| 배경 | 마지막 검수 메시지의 주인공 없는 1536×1024 PNG |
| 주인공 | 마지막 메시지의 독립 PNG 9장, 각 1254×1254 RGBA |
| 원형 힌트·해설 프로필 | 기본 ZIP의 댕댕이·냥냥이·몽몽이 thinking 아바타 |
| 실패 전후 구분 | 보완 ZIP의 `final_failure_before_reveal` / `solution_revealed` 전이 반영 |

기존 고정 장면에는 댕댕이가 합쳐져 있고, 이전 보완 배경에는 빈 일반석이 있어 처음에는 적용을 보류했다. 사용자 검수 후 받은 새 배경으로 이를 대체했다. `REVIEW_REQUIRED` 배경·추출 캐릭터와 댕댕이 고정 합성 장면은 현재 런타임에 사용하지 않는다. 기존 ZIP·검수 이미지는 저장소 밖에서 보존하고 앱 번들에 넣지 않았다.

기본 문항의 피드백 키 `A`/`C`와 보완 매핑의 `wrong_A`/`wrong_C`는 같은 선택의 다른 이름이다. 실제 문구는 기본 JSON의 해당 선택 ID로 읽는다. 법제처 출처는 요청서의 `CnpClsMainBtr` 주소와 콘텐츠 Markdown의 `CnpClsMain` 주소가 달라, 명시된 우선순위에 따라 콘텐츠 주소를 유지했다.

## 기능과 재사용

- 최초 미선택·제출 비활성, 단일 선택 및 변경만으로는 채점하지 않음.
- 명시적인 제출에서 한 번만 유효 횟수 증가. 정답은 코드의 `B` 상수가 아니라 문항의 `correct_choice_id`에서 읽음.
- A/C 전용 피드백, 선택 카드에만 약 200ms 흔들림, O/X 약 250ms, 중복 입력 잠금, 지원 환경의 약한 진동 처리.
- 힌트 1→2는 횟수 차감 없이 열고, 힌트 중 선택·제출 가능. 기존 `MannersHintBubble`의 고정 높이와 선택 캐릭터 프로필을 재사용.
- 재도전은 선택·현재 오답 상태를 초기화하고 누적 제출·힌트 이력은 유지.
- 4번째 오답 후에도 마지막 오답 설명과 `정답 확인`을 먼저 표시. 클릭 후에만 B를 권장 행동으로 공개하며 `success`는 false 유지.
- 기존 `MannersLearningHeader`, `LessonExplanationScreen`, `playLessonFeedbackSound` 재사용. 진행도는 기존 승인 레이아웃의 03/20 컴포넌트이며 01/02 화면 자체는 수정하지 않음.
- 02번의 다음 콜백에 실제 03번을 연결. 03번 다음 단계는 이번에 구현한 연결 대상이 없으므로 비활성.
- 2단계 해설은 처음 접힘, 펼치면 이유·Q&A·출처 링크 전체 표시. 선택한 캐릭터 한마디와 프로필 연동.
- 재풀기는 현재 선택·힌트·제출 횟수·공개 상태만 초기화. 기존 완료 기록과 XP를 수정하지 않음.

01/02 프로토타입과 마찬가지로 화면의 로컬 상호작용 상태는 새 완료·XP 저장 경로를 만들지 않는다. 기존 저장 세션 및 최초 완료 기록 보존과 중복 보상 방지를 테스트했으며, 실제 학습 API·보상 저장 연결은 기존 백엔드 연결 작업 범위다. 효과음은 이전 합의대로 실제 음원 연결을 미루고 공통 재생 콜백을 재사용한다.

## 캐릭터 상태와 임시 배치 값

`app/assets/subway03/scene_layout.json` 한 곳에서 배경, 프로필, 9개 포즈 경로와 배치 보정값을 관리한다.

| 상태 | 포즈 |
| --- | --- |
| 처음 진입·재풀이 | `tired` |
| 힌트 열람·고민·오답·최종 실패 전 | `thinking` |
| 정답 제출 후·실패 후 정답 시범 | `positive` |
| 제출 전 단순 선택 변경 | 기존 포즈 유지, 정오답 표시 없음 |

- 공통 장면: 1536×1024, 모든 캐릭터에서 같은 배경 유지.
- 임시 발 기준점: **(320, 960)**.
- 초기 몸 높이 기준: **520px**.
- PNG마다 알파 60 이상인 맨 아래 13행에서 신발 중심과 폭을 측정해 `sourceFoot`, `sourceFeetWidth`로 기록했다. 표정별 크기 차이는 초기 신발 폭을 기준으로 정규화한다.
- 각 캐릭터/포즈는 같은 발 기준점에 놓고 약 200ms 페이드 전환한다. 배경은 전환하지 않는다.
- 위치·몸 높이·포즈 보정은 JSON 수정으로 재검수 가능하다. 화면 크기에 따른 배치는 공통 캔버스의 `BoxFit.contain` 역비율을 사용하며 PNG를 임의 크롭하거나 늘리지 않는다.
- 9개 포즈 모두 발 기준선 일치 및 실제 불투명 영역이 장면 안에 있음을 검사했다. 앞에 선 주인공이 뒤쪽 일반석 승객 일부를 가리는 전경 구도를 사용하며, 오른쪽 빈 분홍 배려석은 가리지 않는다.

## 변경 파일

| 파일 | 내용 |
| --- | --- |
| `app/lib/screens/choice_lesson_state.dart` | 문항 JSON 모델과 재사용 가능한 제출형 상태 머신 |
| `app/lib/screens/subway03_screen.dart` | 네이티브 선택 카드·피드백·힌트·제출·재풀이·해설 연결 |
| `app/lib/screens/subway03_scene.dart` | 선택 캐릭터와 표정, 공통 좌표·발 정렬·페이드 렌더러 |
| `app/lib/screens/manners_lesson_progress.dart` | 승인된 진행도 레이아웃으로 03/20 표시 |
| `app/lib/screens/subway02_screen.dart` | 기존 다음 문제 콜백 전달만 추가 |
| `app/lib/screens/transport_lesson_screen.dart` | 03번 진입과 02→03 이동, 기존 저장 세션 초기화 방지 |
| `app/lib/screens/transport_questions.dart`, `learning_catalog.dart` | 세 번째 항목을 임산부 배려석 문제로 연결 |
| `app/assets/subway03/`, `app/pubspec.yaml` | 배경 1장·주인공 9장·프로필 3장·설정 JSON 3개 등록. 총 16개 파일, 11,414,078바이트 |
| `docs/design/education_content_subway_03_basic.md` | 전달받은 교육 원문 보존 |
| `app/test/subway03_choice_test.dart` | 무채점 선택·명시 제출·중복 잠금·4회·힌트·재도전 검사 |
| `app/test/subway03_screen_test.dart` | 3종 장면·포즈·양쪽 오답·정답·실패 공개·본문 전체·배치·기록 보존·반응형·실제 경로 검사와 캡처 |
| `app/test/transport_lesson_test.dart`, `lesson_retry_rules_test.dart` | 예전 즉시 판정 선택형 검사는 기존 04번에서 유지 |
| `app/test/learning_screens_test.dart` | 새 세 번째 항목의 검색·번호 검사 |

## 캡처

`subway03_screen_test.dart`에 `CAPTURE_DIR`를 지정하면 실제 렌더링 PNG를 만든다. Pretendard는 앱 번들에서 직접 로드한다.

- `subway03-{dog,cat,monkey}-initial.png`
- `selection-changed`, `hint1`, `hint2`
- `wrong-A`, `wrong-C`, `correct`
- `failure-before-reveal`, `solution-revealed`
- `explanation`, `explanation-expanded`

## 검증 및 남은 확인

- 관련 13개 파일 테스트 **97개 통과**. 01/02 드래그·힌트·해설·재풀이 회귀 검사 포함.
- 마지막 효과 애니메이션 조정 후 03번 상태·화면 검사 **13개 재확인 통과**.
- `flutter analyze --no-pub`: 문제 없음.
- `flutter build web --no-pub --no-wasm-dry-run --target lib/main_prototype.dart`: 성공.
- 전체 `flutter test --no-pub`: **569개 통과, 9개 건너뜀, 20개 실패**. 직전 전체 검사와 실패 20개 항목이 동일함을 대조했다. Windows 경로·줄바꿈·CLI 검사 17개, 기존 fake 모듈 참조 1개, 기존 01번 진입 시간 초과 2개로, 새 기능 검사와 구분한다.
- 새 문항의 A→C→B 변경 시 미채점, 제출 후에만 판정, 중복 제출 잠금, A/C 문구 구분, 4회 실패 후 자동 정답 방지 확인.
- 세 캐릭터의 초기·고민·긍정 포즈 및 힌트 프로필 경로 확인. 9개 포즈의 공통 발 기준선·잘림 검사 통과.
- 320×640, 852×393 가로 화면, 글자 크기 2배, 모션 감소·음소거에서 오류 없이 선택지·본문·하단 버튼 확인.
- 기존 기록/XP 보존, 정답 시범이 성공으로 기록되지 않음, 02→03 실제 이동 확인.
- 실기기 검수는 사용자가 **나중에 진행**하기로 선택했다. 연결된 Android 기기가 없었으며, 실제 단말·진동·음향 결과를 검증 완료로 보고하지 않는다.

### 남은 아트 보완

1. 제공 배경의 분홍 좌석에 **‘임산부 배려석’ 글자가 빠져 있음**. 임의 텍스트 합성 없이 그대로 사용하고 최종 아트 보완으로 구분했다.
2. 냥냥이·몽몽이 thinking PNG의 생각 구름은 일반 교통약자석 아이콘이며, 댕댕이 thinking PNG는 분홍 임산부 아이콘이다. 제공한 그림을 변경하지 않았으며 표지 통일 여부를 아트 검수에서 확인해야 한다.
3. 배치 좌표는 위 임시 값이다. 주인공 크기와 전경 겹침은 실제 기기 검수 후 `scene_layout.json`에서 조정할 수 있다.
4. 콘텐츠의 법제처 URL은 접속 검사에서 HTTP 503으로 확인을 마치지 못했다. 임의 대체 주소를 넣지 않았다. 서울시 자료 두 페이지는 응답을 확인했다.

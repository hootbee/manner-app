# 대중교통 04번 기본 문제 구현

## 구현 범위

- `transit_04_basic`, 기본 문제 04/20. 03번 해설의 다음 버튼 및 학습 목록에서 진입한다. 04번 해설의 05번 이동은 비활성이다.
- 최초 진입·재풀이 시 카드 ID를 무작위로 섞고 정답 배열은 제외한다. 제출 버튼은 실제 순서 변경 후 활성화하며 드래그 중에는 잠근다.
- 드래그·힌트는 배열만 바꾸거나 힌트 단계만 올린다. **제출 시에만 네 ID 전체를 비교**하고 유효 시도를 한 번 올린다.
- 오답 1~3회 재도전은 마지막 배열·힌트 이력·횟수를 유지한다. 4번째 오답에도 배열을 유지하고, `정답 확인`을 눌렀을 때만 정답 순서로 바꾼다. 정답 시범의 성공 값은 false다.
- 두 단계 힌트는 카드 아래 같은 크기의 공통 말풍선에 표시한다. 힌트·해설 프로필은 선택한 파트너를 따른다.
- 해설은 기존 2단계 위젯을 재사용한다. 원문 이유 3개, Q&A 3개, 출처 2개 및 추가 `권장 흐름의 의미` 전체를 보존한다. 원문에 없는 세 번째 출처를 만들지 않았다.
- 한 개의 스크롤 영역에서 핸들로 정렬하고 본문 드래그로 스크롤한다. 카드 최소 높이 88dp, 간격 12dp, 그림 프레임 60dp, 핸들 44×44dp이며 큰 글씨에서 높이가 늘어난다.

## 공통 컴포넌트와 변경 파일

### 신규

- `app/lib/screens/sequence_lesson_state.dart`: SequenceQuestion/SequenceCard 데이터, 순열 검증, 무작위 초기화, 제출/힌트/재시도/정답 공개 상태.
- `app/lib/screens/sequence_card_list.dart`: ValueKey(ID) 기반 공통 SliverReorderableList. oldIndex/newIndex 보정, 카드 이동·들림, 묶음 흔들림.
- `app/lib/screens/sequence_lesson_screen.dart`: 데이터·그림·진행도를 받는 공통 화면. 기존 헤더/힌트/해설/효과음 연결 지점 재사용.
- `app/lib/screens/transit04_screen.dart`: 04번 데이터·에셋과 공통 화면을 연결하는 얇은 래퍼.
- `app/assets/transit04/problem_sequence_transit04.json`: 제공된 문제 JSON 원문.
- `app/assets/transit04/explanation.json`: 교육 MD 원문의 표시용 데이터.
- `app/assets/transit04/assets/scene/bus_scene_approved_flat.png`
- `app/assets/transit04/assets/cards/{hold,observe,wait,exit}.png`
- `app/test/sequence_lesson_state_test.dart`, `app/test/transit04_screen_test.dart`
- `docs/design/education_content_transit04.md`: 교육 원문 보관.

### 수정

- `app/pubspec.yaml`: 런타임 폴더 3개 등록. 목업·미리보기·제작 스크립트는 앱에 넣지 않음.
- `app/lib/screens/transport_lesson_screen.dart`: 04번 라우팅 및 03→04 연결. 전용 01~04 진입에서 기존 저장된 기록을 초기화하지 않음.
- `app/lib/screens/subway03_screen.dart`: 호출자가 제공할 때만 다음 문제 이동 허용.
- `app/lib/screens/transport_questions.dart`, `learning_catalog.dart`: 04번 문구·목록 정보 일치.
- `app/lib/screens/lesson_explanation_content.dart`, `lesson_explanation_screen.dart`: 선택적 추가 교육 섹션 지원 및 이유 본문의 강조 문구 처리. 기존 문제의 기본 값은 빈 목록.
- `app/test/lesson_retry_rules_test.dart`, `transport_lesson_test.dart`: 종전 일반 문제 UI 검사는 실제 일반 문제를 대상으로 유지. 새 전용 문제는 전용 테스트로 검사.

다음 순서형 문제는 공통 화면에 문제 JSON·교육 JSON·에셋 경로·상황 그림 비율·진행 번호를 전달하면 된다. 카드 개수·문구·ID 정답·힌트·최대 제출 횟수는 데이터에서 읽으며, 특정 카드 ID를 위젯에 고정하지 않는다. 다음 화면 이동은 선택적 콜백으로 주입한다.

## 승인 아트의 제한

- ZIP 38개 파일과 manifest의 런타임 에셋 11개 SHA-256을 확인했다. 앱에는 실제 필요한 PNG 5개만 복사했다.
- 버스 장면은 **몽몽이·어르신·승객이 합쳐진 960×384 고정 그림**이다. 모든 파트너에서 동일하며, 주인공 교체·표정 변경은 구현 범위가 아니다.
- 1536×1024 투명 레터박스 가이드 대신 960×384 원본을 같은 비율과 BoxFit.contain으로 표시한다.
- 카드 그림은 내부 회색 배경을 포함하는 크롭 원본이며, 투명 캐릭터 레이어로 취급하지 않는다.

## 기록·효과음·실기기

01~03 전용 프로토타입과 동일하게 이번 화면은 기존 완료 기록·XP 저장을 직접 변경하지 않는다. 성공 판정과 정답 시범을 구분하고 기존 기록을 보존한다. 실제 최초 완료 보상 지급은 기존에 보류한 backend/startPractice 연결 범위이며, 새 로컬 보상 저장소를 만들지 않았다. 정답 시범·재풀이로 보상이 중복 지급되지 않는다.

효과음은 기존 선택적 재생 함수를 재사용한다. 사용자가 미룬 새 효과음 파일은 추가하지 않았다. 지원되는 모바일 환경에는 약한 오답 햅틱을 연결했고 음소거/모션 감소도 고려했다. 실제 소리·진동은 단말에서 검수하지 않았다.

실제 Android 기기 검수는 이전에 사용자가 나중에 진행하기로 했다. 이번 검수는 Flutter 위젯 실행 및 웹 빌드이며, 실제 휴대폰 검증 완료로 표현하지 않는다.

## 검수 자료

영상과 캡처는 저장소 밖 `C:/Users/gjo49/Documents/Codex/transit04-review/`에 보관한다. 영상은 **Flutter 위젯 테스트 실행 중의 실제 렌더링 프레임**을 이어 붙인 검수 영상이며 휴대폰 녹화가 아니다. 첫 재정렬과 아래→위 이동은 실제 핸들 제스처로 검사하고, 이후 시나리오용 배열 설정은 상태 API로 준비한 다음 실제 제출·재시도·힌트·해설 버튼을 누른다. 요약 해설 캡처는 경로 전환 시 테스트 렌더러의 헤더 레이어 누락을 피하기 위해 동일 위젯을 별도 마운트해 촬영했다. 최종 캡처 전용 실행은 6개 통과(`transit04-capture.log`)이며 기본 자동 검사 개수에는 이 선택적 촬영 1개를 포함하지 않는다.

출처 1의 공식 페이지 응답은 확인했다. 출처 2의 제공 URL은 웹 조회 도구에서 접근 오류가 나 최종 접속 확인을 마치지 못했다. 임의로 원문의 URL을 대체하지 않았다.

## 검사 결과

- Windows, Flutter 3.47.8 / Dart 3.13.7.
- `flutter analyze --no-pub`: 문제 없음 (`transit04-analyze.log`).
- `flutter build web --no-pub --no-wasm-dry-run --target lib/main_prototype.dart`: 성공 (`transit04-web-build.log`).
- 04번 상태 및 화면 검사 **10개 통과** (`transit04-widget-tests.log`). 전체 실행에서도 모두 통과했다.
- 01~03·해설·기존 일반 문제 UI 및 재시도 규칙 검사 **107개 통과**. 별도 실행 로그 `transit04-regression.log`는 최초 캡처 테스트의 컴파일 오류를 포함하므로 성공 로그로 오인하지 않는다. 수정 후 04번 검사 및 전체 검사에서 이 파일들을 다시 검증했다.
- 전체 `flutter test --no-pub`: **580개 통과, 9개 건너뜀, 19개 실패** (`transit04-full-tests.log`). 이전 03번 전체 결과의 실패 목록과 대조했다. 새로운 실패는 없고, 일반 드래그 테스트가 전용 01번 UI를 잘못 대상으로 삼던 1개는 실제 일반 문제를 검사하도록 정리되어 통과했다.
- 남은 기존 실패: `content_update_test.dart` 10개(Windows 경로), `pipeline_test.dart` 4개(경로·줄바꿈), `validate_test.dart` 3개(하위 CLI 오류), `boundaries_test.dart` 1개(기존 fake→screens 참조), `home_growth_test.dart` 1개(기존 01번 자료의 비동기 로딩을 기다리지 않는 검사).
- 네 카드의 삽입 인덱스 16가지, 80개 무작위 시드, 실제 핸들 위→아래 및 아래→위 드래그, 제출 전 미채점, 중복 제출 잠금, 힌트 크기·선택 프로필, 4회 실패 후 수동 정답 공개, 성공 제출, 해설 원문·재풀이·기존 기록 보존을 확인했다.
- 320×640 및 852×393에서 글자 2배·모션 감소·음소거 상태로 제출→해설→출처까지 확인했다.
- 영상: `C:/Users/gjo49/Documents/Codex/transit04-review/transit04-demo.mp4`.
- 캡처: 같은 폴더의 `captures/01-initial.png`~`15-correct-complete.png`.

## 2026-11-21 카드·판정 효과 수정

`MANNERS_04_sequence_flutter_UI_feedback_revision.md`를 반영했다. 문제 문구·정답 순서·버스 배경·제출/4회 실패/힌트/해설/기록 정책은 그대로다. 01~03 화면의 UI/로직은 이번 수정에서 변경하지 않았다.

### 카드와 새 에셋 교체

| 화면 | 현재 가로 원본용 임시 프레임 | 그림의 실제 최대 표시 폭 | 향후 정사각형 프레임 |
|---|---|---|---|
| 393dp 이상 | 96×72dp | 내부 여백 4dp씩 제외한 88dp (기존 60dp 대비 약 47% 증가) | 72×72dp |
| 320dp 등 360dp 미만 | 80×64dp | 72dp | 64×64dp |

카드 높이는 그림·패딩 기준 기본 96dp(좁은 화면 88dp)이고 문구/큰 글씨에 맞춰 늘어난다. 간격 12dp와 핸들 44×44dp는 유지했다. BoxFit.contain으로 그림 전체를 보여 주므로 찌그러뜨림·강제 크롭은 없다.

현재 그림은 가로 크롭 원본이므로 프레임을 키워도 내용 자체가 정사각형 구도로 바뀌지는 않는다. 임시로 넓은 그림 칸을 사용한 이유다. 첨부된 그림 참고 자료나 `*_square_preview.png`를 최종 아트로 대체하지 않았다.

새 아트 수령 시 `app/assets/transit04/assets/cards/`에 아래 파일을 넣고 문제 JSON 각 카드의 `thumbnail` 및 `thumbnailAspectRatio`만 수정하면 된다. 폴더는 이미 pubspec에 등록되어 있다.

```json
{"id":"hold", "thumbnail":"assets/cards/hold_square_final.png", "thumbnailAspectRatio":1}
```

나머지는 `observe_square_final.png`, `wait_square_final.png`, `exit_square_final.png`에 각각 같은 방식으로 적용한다. 최종 그림의 내부 여백과 행동 구도 검수는 새 파일 수령 후 필요하다.

### O/X 표시와 입력 잠금

- 신규 공통 `app/lib/screens/result_feedback_overlay.dart`: 카드 묶음의 보이는 영역에만 표시하며 배경 장면·버튼 위로 확장하지 않는다. 카드 앵커 좌표를 사용해 스크롤 및 화면 회전 후 위치를 다시 측정한다.
- 초록 O `#2E7D32`, 빨간 X `#C62828`, **96×96dp 표시 영역**, 굵은 선과 흰색 외곽·바탕. O 링 약 89dp, X 외곽 폭 약 88dp다. 형태·텍스트·접근성 이름을 함께 사용한다.
- **250ms 확대/등장 → 1200ms 유지 → 300ms 사라짐 = 1750ms**. 모션 감소에서는 이동·확대·페이드 없이 같은 시간 정적으로 표시한다.
- 1750ms 동안 드래그·중복 제출·힌트·이동 버튼을 잠근다. 오답 흔들림은 첫 200ms에만 카드 묶음에 적용한다.
- 효과 후 하단의 44dp O/X와 결과 문구는 유지한다. 오답 상태에서 힌트를 열어도 결과는 사라지지 않는다. 재시도·정답 확인·해설 이동 버튼은 기존 상태 규칙을 따른다.
- 기존 효과음 호출과 모바일의 약한 햅틱은 제출당 한 번만 실행한다. 음소거·모션 감소 설정과 기존 보상 분리를 유지했다.

### 이번 변경 파일

- 신규: `app/lib/screens/result_feedback_overlay.dart`, `app/test/sequence_feedback_revision_test.dart`.
- 수정: `sequence_card_list.dart`, `sequence_lesson_screen.dart`, `sequence_lesson_state.dart`(그림 비율 메타데이터만), `app/assets/transit04/problem_sequence_transit04.json`(그림 비율만), `app/test/transit04_screen_test.dart`(새 판정 시간에 맞춘 검사), 이 보고서.
- PNG 원본 5개는 변경하지 않았다.

### 검수와 산출물

- 수정 검사 5개 + 기존 04번 상태/화면 검사 10개 **총 15개 통과**. 모션 감소·음소거·회전, 효과 1.7초 시점의 입력 잠금 및 종료, 지속 결과·오답 힌트 병행, 실제 드래그·4회 실패·재풀이를 확인했다.
- `flutter analyze --no-pub`: 문제 없음 (`transit04-revision-analyze.log`).
- 웹 빌드 성공 (`transit04-revision-build.log`). 실제 휴대폰 검수는 진행하지 않았다.
- 전체 검사 **585개 통과, 9개 건너뜀, 19개 실패** (`transit04-revision-full-tests.log`). 직전 전체 검사와 실패 19개 항목이 동일하며 신규 실패는 없다. 기존 실패 분류는 앞 절과 같다.
- 최종 그림 크기 미세 조정 후에도 캡처 검사 5개 재통과 (`transit04-revision-capture.log`).

자료 위치: `C:/Users/gjo49/Documents/Codex/transit04-feedback-review/`

- `before/cards-393.png`: 수정 전 실제 실행 캡처(이전 작업에서 보관한 자료).
- `after/cards-393.png`, `after/cards-320.png`: 수정 후 일반·작은 화면 캡처.
- `after/correct-08.png`, `after/wrong-08.png`: 표시 중 큰 O/X.
- `after/correct-persistent.png`, `after/wrong-persistent.png`: 효과 종료 후 결과 유지.
- `correct-feedback.mp4`, `wrong-feedback.mp4`, `feedback-demo.mp4`: 각각 정답·오답 및 합친 동작 영상. Flutter 실제 위젯 실행에서 100ms 간격으로 얻은 프레임을 시간에 맞춰 연결했다. 기기 녹화는 아니며 효과음은 포함하지 않는다.

남은 아트: 4종 `*_square_final.png` 및 최종 경로 매핑·미리보기 검수. 현재 가로 그림의 구도 한계는 새 정사각형 그림 수령 후 해소할 항목이다.

## 정사각형 카드 그림 최종 적용 (후속 수정)

사용자가 후속 전달한 정사각형 PNG 4장을 적용했다. 앞 절의 '남은 정사각형 아트' 항목은 이번 적용으로 해소했다.

| 카드 ID | 전달 이미지 | 적용 파일 (`app/assets/transit04/assets/cards/`) |
|---|---|---|
| hold | 271828c6… (손잡이 잡기) | hold_square_final.webp |
| observe | 62cc4a1c… (열린 문과 앞 승객 살피기) | observe_square_final.webp |
| wait | 551e5d9e… (거리 두고 기다리기) | wait_square_final.webp |
| exit | 867b8016… (내 차례에 하차하기) | exit_square_final.webp |

- 모두 1254×1254 RGBA. 원본을 lossless WebP로 인코딩했으며 디코딩 후 RGBA 픽셀이 원본과 완전히 일치함을 확인했다. 총 약 4.06MB. 자르기·그림 수정·강제 비율 변경은 하지 않았다.
- 문제 JSON의 그림 경로와 `thumbnailAspectRatio: 1`을 연결했다. 그림 칸은 72×72dp, 360dp 미만에서는 64×64dp다. 그림의 자체 둥근 테두리를 그대로 사용하고 추가 클립·내부 여백을 제거해 칸을 채운다. BoxFit.contain을 유지한다.
- 기본 카드 높이 96dp(좁은 화면 88dp), 카드 간격 12dp, 핸들 44×44dp는 유지한다. 글씨 확대에서는 콘텐츠 높이에 맞춰 확장한다.
- 문구와 그림/핸들 사이 간격을 8dp/4dp로 조정했다. 기본 16sp를 사용하되, 15sp로 조정하면 한 줄이 되는 경우에만 15sp를 사용한다. 393dp 실제 캡처에서 4문구 모두 한 줄을 확인했다. 작은 화면은 두 줄을 허용하고 말줄임은 넣지 않았다. 시스템 글씨 확대를 다시 축소하지 않는다.
- 이번 변경: PNG를 인코딩한 WebP 4개 추가, 문제 JSON, `sequence_card_list.dart`, 기존 프레임 규격 검사 및 이 문서 수정. 판정·보상·재시도·힌트·해설 코드는 변경하지 않았다.
- 상태/화면/판정 효과 검사 15개 통과 (`transit04-square-tests.log`). 별도 캡처 검사 5개 통과 (`transit04-square-capture.log`). 분석 결과는 `transit04-square-analyze.log`에 기록한다. 이번에는 전체 검사를 반복하지 않았으며 앞 절의 전체 검사 수치는 이전 수정의 결과다.
- 캡처: `C:/Users/gjo49/Documents/Codex/transit04-square-review/cards-393.png`, `cards-320.png`. 실제 단말 검수는 아직 진행하지 않았다.

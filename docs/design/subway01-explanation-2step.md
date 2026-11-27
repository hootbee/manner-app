# 대중교통 01번 교육 해설 2단계 UX 구현 결과

## 1. 변경 파일

| 파일 | 내용 |
|---|---|
| `app/lib/screens/lesson_explanation_content.dart` (신규) | 문제 ID별 교육 콘텐츠와 실천 문구, 이유·Q&A·출처의 읽기 전용 데이터 모델 |
| `app/lib/screens/lesson_explanation_screen.dart` (신규) | 기본 카드, 상세 펼침, 개별 Q&A, 출처 링크, 선택 프로필, SafeArea 하단 버튼 |
| `app/lib/screens/subway01_screen.dart` | 기존 해설 메서드를 새 화면에 연결하고 다시 풀기 의도를 현재 시도 초기화로 처리 |
| `app/lib/screens/action_drag_state.dart` | 현재 시도만 초기화하는 `resetAttempt()` 추가. 기존 판정 및 재도전 규칙은 유지 |
| `app/pubspec.yaml`, `app/pubspec.lock` | 기존 전이 의존성이던 `url_launcher 6.3.3`을 직접 의존성으로 명시. 새 오디오/이미지 패키지는 추가하지 않음 |
| `app/test/lesson_explanation_test.dart` (신규) | 원문 대조, 기본 접힘, 펼침·Q&A·출처, 프로필 3종, 큰 글씨·작은 화면, 링크 실패 처리 |
| `app/test/subway01_replay_test.dart` (신규) | 해설 재진입, 일반 뒤로 가기와 다시 풀기의 차이, 저장된 기록·XP 보존, 다음 이동 의도 |
| `app/test/subway01_test.dart`, `subway01_screen_test.dart` | 초기화 및 기존 드래그→정답→해설 흐름 회귀 검사 |
| `docs/design/education_content_subway_01.md` (신규) | 제공 ZIP 교육 원문을 그대로 보관. 개인 컴퓨터 경로 없이 내용 대조 테스트에 사용 |

ZIP의 디자인 PNG는 저장소/앱에 추가하지 않았다. 실행 캡처와 참고 시안은 저장소 밖 `Documents/Codex/explanation-2step-review/`에 보관한다.

## 2. 기본·상세 UI

해설 처음 진입 시 상세는 항상 접힌 상태다. 핵심 매너와 학습 핵심의 전문을 자동 높이 카드로 보여주고, 학습 핵심 구분선 아래 캐릭터 한마디를 배치한다. 별도 '교육 해설' 제목이나 큰 말풍선은 없다.

자세한 해설 버튼을 누르면 현재 페이지에서 약 250ms AnimatedSize로 아래 내용만 확장한다. 기본 카드 위치는 유지하며, 움직임 감소 설정에서는 펼침 애니메이션을 생략한다. 상세 이유 3개, Q&A 3개, 출처 3개를 순서대로 표시한다. Q&A는 처음 모두 펼치고 각각 접을 수 있다. 상단에 학습 핵심을 한 번만 표시한다.

본문 좌우 여백 20dp, 카드 패딩 16dp, 모서리 16dp, 주요 간격 28dp를 사용한다. 본문을 자르거나 말줄임하지 않고 전체 페이지를 스크롤한다. 하단 두 버튼은 같은 너비, 12dp 간격, 최소 높이 48dp이며 Scaffold의 별도 SafeArea 영역에 있어 본문을 덮지 않는다. 큰 글씨에서는 두 버튼의 높이가 함께 늘어난다. 본문 및 버튼은 기존 앱 글꼴을 상속한다. Pretendard 원본 파일은 프로젝트에 없어 새로 추가하지 않았다.

## 3. 선택 캐릭터와 콘텐츠

기존에 전달받던 `MannerPartner`를 해설에도 그대로 전달한다. 이미 확정된 `dog_thinking.png`, `cat_thinking.png`, `monkey_thinking.png`를 48×48dp 원형으로 재사용한다. 새 캐릭터 선택 상태나 프로필 그림을 만들지 않았다.

`lessonExplanations['transport-1']`에서 문제별 콘텐츠를 선택한다. 실천 문구는 세 캐릭터 모두 동일한 '가방은 몸 가까이! 다른 사람이 지나갈 공간도 살펴봐요!'이다. 다른 문제는 다른 데이터 객체를 전달하도록 분리했으며, 화면에 01번 문구를 고정하지 않았다.

제공 원문에서 핵심 매너·학습 핵심·실천 문구·상세 이유·Q&A·출처·안내 문구를 전문 그대로 옮겼다. 원문의 강조 표시는 TextSpan으로 표현한다. 원본 Markdown의 각 교육 문단을 데이터에 대조하는 테스트가 통과했다. 출처의 기관·자료명·날짜·원래 URL을 보존하고, 캠페인 보도/방송 자료/시민기자 칼럼의 성격과 법적 의무로 해석하지 않는다는 원문 안내도 표시한다.

## 4. 문제 다시 풀기와 기록 보존

해설 화면은 저장을 직접 처리하지 않고 replay/next 의도만 반환한다. replay는 문제 화면의 타이머·효과를 정리하고 ActionDragState만 초기화한다. 가방/어깨끈/표정은 initial 레이어로 돌아가며 포인터·드래그 이동량·힌트·시도 횟수·결과 표시를 초기화한다.

TransportProgress의 세션, 최초 완료 시각, XP, 보상 계산 및 저장 메서드는 수정하거나 호출하지 않았다. 저장된 완료 기록이 있는 상태에서 다시 풀기를 반복해도 기록 JSON과 XP가 동일함을 테스트했다. 기존 프로토타입에서 제공하지 않던 새로운 학습 기록 저장이나 보상 지급도 추가하지 않았다.

일반 뒤로 가기는 현재 정답·힌트·시도 상태를 유지한다. 다음에 해설을 다시 열면 상세 펼침 상태는 새로 접힌 상태로 시작한다.

다음 응용 문제는 현재 없어서 다음 문제로 이동 버튼을 비활성화한다. 실제 다음 문제가 연결되면 기존 onNextProblem 흐름을 사용한다. 관련 없는 탑승 질서 문제나 가짜 화면으로 연결하지 않았다.

## 5. 출처 링크

원문 URL 3개를 url_launcher로 연결했다. 카드 선택 시 해당 정확한 URI를 전달하며 열기에 실패하거나 플랫폼 오류가 발생하면 해설을 유지하고 안내한다. 테스트에서는 세 카드가 각각 정확한 URI를 전달하는지와 실패 안내를 검사했다. 외부 브라우저의 실제 앱 전환 동작은 실기기에서 별도로 확인해야 한다.

- 연합뉴스: https://www.yna.co.kr/view/AKR20170405051400051
- KTV 국민방송: https://m.ktv.go.kr/program/again/view?content_id=510725&program_id=PG2150012D
- 서울시 내 손안에 서울: https://mediahub.seoul.go.kr/archives/1068157

## 6. 검증

- `flutter analyze --no-pub`: 문제 없음.
- 관련 7개 테스트 파일: 39개 모두 통과.
  - lesson_explanation_test.dart
  - subway01_replay_test.dart
  - subway01_test.dart
  - subway01_ux_test.dart
  - subway01_screen_test.dart
  - transport_lesson_test.dart
  - learning_screens_test.dart
- 기본/상세 카드, 상단 위치 유지, Q&A 전문 및 접기, 출처 URI, 프로필 3종, 320dp·2배 글씨, 다시 풀기, 기존 완료 기록/XP 보존, 기존 드래그·힌트·정답/오답 흐름을 검사했다.
- 전체 앱 테스트를 모두 통과했다고 기재하지 않는다. 이번 작업에서는 관련 테스트와 전체 정적 분석을 수행했다.

## 7. 캡처와 남은 사항

실제 문제에서 진입한 기본/상세 화면: `subway01-430.0-explanation.png`, `subway01-430.0-explanation-expanded.png` (320dp 버전도 있음).

캐릭터 비교: `basic-0.png`(고양이), `basic-1.png`(강아지), `basic-2.png`(원숭이). 전문 확인: `qa.png`, `sources.png`. 비교용 단독 위젯 캡처의 진행도는 테스트용 텍스트이며, 실제 문제 흐름 캡처에는 기존 진행 캡슐을 사용한다.

필수 추가 이미지 에셋은 없다. 외부 링크의 기기별 동작, iOS/Android 실제 기기에서의 최종 시각 검수는 남아 있다. 기존 효과음 음원 미제공 및 다음 응용 문제 미구현 상태는 이번 작업에서도 바뀌지 않았다.

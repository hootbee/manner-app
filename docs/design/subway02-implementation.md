# 대중교통 02번 기본 문제 구현

> 후속 히트박스·글꼴 변경은 [최종 히트박스 수정](subway02-hitbox-update.md)을 따른다. 아래 검증 결과와 에셋 설명은 최초 구현 당시 기록이다.

문항 콘텐츠 ID는 `subway_02_basic`이다. 기존 목록·저장소의 `transport-2` 진입점을 새 문제로 연결했다. 프로토타입 진입점의 대중교통 두 번째 항목에서 열며, 01번 해설의 다음 버튼으로도 이동한다. `main.dart`와 백엔드 학습 규칙은 변경하지 않았다.

## 변경 파일과 재사용 범위

| 파일 | 역할 |
| --- | --- |
| `app/lib/screens/subway02_screen.dart` | 02번 진입 화면, 선택 파트너·음소거·재생 콜백 전달 |
| `app/lib/screens/subway01_screen.dart` | 기존 공통 학습 화면을 재사용. 문제 구분에 따른 이미지 로딩·합성, 02/20 진행도, 250ms 효과, 900ms 판정 잠금, 해설 연결 |
| `app/lib/screens/action_drag_state.dart` | 01번 가방 중심 판정을 유지하면서 02번 발 중심·직사각 영역·26px 임계값·알파 마스크 지원 |
| `app/lib/screens/manners_hint_bubble.dart` | 기존 고정 높이 UI에 문제별 문구와 프로필 경로를 선택적으로 주입 |
| `app/lib/screens/subway02_content.dart` | 전달받은 Markdown의 문제·힌트·해설 전체 문구 |
| `app/lib/screens/lesson_explanation_content.dart` | 공통 해설 모델에 02번 콘텐츠와 출처 안내 추가 |
| `app/lib/screens/lesson_explanation_screen.dart` | 기존 2단계 해설 재사용, Q&A 강조 문구 보존, 모션 감소 시 애니메이션 생략 |
| `app/lib/screens/transport_lesson_screen.dart` | 목록 및 01→02 실제 이동, 기존 저장 기록 수정 방지 |
| `app/lib/screens/transport_questions.dart`, `learning_catalog.dart` | 두 번째 항목을 제공된 행동형 문제로 변경 |
| `app/assets/subway02/`, `app/pubspec.yaml` | 런타임 PNG 19개와 JSON 2개 등록, 총 1,311,721바이트 |
| `app/test/subway02_test.dart` | 발 중심, 이동 임계값, 영역, 취소, 4회 실패, 알파 마스크 검사 |
| `app/test/subway02_screen_test.dart` | 실제 포인터·경로·힌트·효과 타이밍·해설·재풀이·기록 유지·반응형 검사와 캡처 |
| `app/test/transport_lesson_test.dart` | 기존 순서형 UI 검사는 새 02번 대신 순서형 06번에서 유지 |
| `docs/design/education_content_subway_02.md` | 전달받은 교육 원문을 그대로 보관 |

공통 헤더 `MannersLearningHeader`, `MannersHintBubble`, `ActionDragState`, `LessonExplanationScreen`, `playLessonFeedbackSound`를 사용한다. 전체 화면을 이미지로 표시하지 않는다. ZIP의 참고 합성 이미지·시안·생성 스크립트는 저장소와 앱 번들에 추가하지 않았다.

## 좌표와 상태 처리

- 장면은 1536×1024, `BoxFit.contain`으로 전체 표시한다. `FittedBox` 내부 Listener의 변환된 로컬 좌표를 사용하며 장면 밖 드롭은 취소한다.
- 시작 마스크는 원본 RGBA의 알파 60 이상만 허용한다. 01번의 흰색 마스크·터치 여유 범위는 그대로 유지한다.
- 02번은 `(830,902) + 실제 포인터 변위`를 발 중심으로 사용한다. 26px 미만·판정 영역 사이·이동 범위 밖·취소는 시도 수를 쓰지 않는다.
- 초기 가시 범위·발 중심·판정 영역·이동 범위는 원본 JSON을 읽는다. 원본 좌표와 캐릭터 이미지 수정은 없다.
- 오답은 전체 캔버스 `monkey_wrong.png`에 같은 변위를 적용한다. X는 원본 위치에서 `delta + (-40,-20)`만큼 이동하며 장면 가장자리에서만 표시 범위를 제한한다. 판정 좌표에는 이 효과 보정을 적용하지 않는다.
- 정답은 이미 배치된 `monkey_correct.png`를 원점 그대로 표시한다. O/X는 250ms 후 사라지고 결과 안내는 유지된다. 오답 흔들림은 그림에만 200ms 적용한다.
- 유효 오답 4회 후에도 오답 그림을 유지한다. `정답 확인`을 누른 뒤에만 시범으로 바꾸며 `success`는 false이다. 01번 정책처럼 실패 후 해설 열람도 허용한다.
- 힌트는 2개, 시도 수와 독립적이다. 고정된 프로필·말풍선 영역을 유지하고 선택한 파트너에 맞는 제공 프로필을 사용한다.
- 02번 응용 라우트는 없으므로 해설의 다음 버튼은 비활성이다. 임의로 기존 다른 문제로 연결하지 않았다.
- 재풀기는 현재 위치·제스처·힌트·오답 수·시범·효과만 초기화한다. 기존 저장 세션과 XP는 수정하지 않는다. 01번과 동일한 임시 상호작용 상태를 사용하며 새로운 완료·보상 저장 경로를 만들지 않았다.

## 검증 결과

Windows, Flutter 3.47.8 / Dart 3.13.7 환경에서 실행했다.

- ZIP의 파일 52개 SHA-256 일치, 런타임 PNG 19개 확인.
- `flutter analyze --no-pub`: 문제 없음.
- 01/02번·해설·학습 목록 등 관련 9개 테스트 파일: **52개 통과**.
- 추가한 01번 해설 → 02번 실제 경로 검사: **1개 통과**.
- 마지막 반응형·해설 보완 후 02번 및 공통 해설 3개 파일: **19개 통과**.
- `flutter build web --no-pub --target lib/main_prototype.dart`: 성공. 마지막 빌드에서는 선택적인 Wasm 사전 검사만 생략했다.
- 전체 `flutter test --no-pub`: **524개 통과, 9개 건너뜀, 20개 실패**. 전체 통과 상태는 아니다.

전체 검사에서 남은 실패는 이번에 수정하지 않은 범위다. `content_update_test.dart` 10개(Windows 경로), `pipeline_test.dart` 4개(경로·줄바꿈), `validate_test.dart` 3개(CLI 종료), `boundaries_test.dart` 1개(기존 fake→screens 참조), `home_growth_test.dart`와 `lesson_retry_rules_test.dart` 각 1개(기존 01번 진입의 비동기 로딩을 `pumpAndSettle`로 기다리다가 시간 초과). 해당 실패를 새 기능 테스트 통과로 숨기지 않았다.

## 실제 렌더링 캡처

`subway02_screen_test.dart`에 `CAPTURE_DIR`를 지정하면 320·393·430dp 너비에서 다음 PNG를 생성한다. 예: `subway02-393.0-initial.png`.

- `initial`, `dragging`, `wrong`, `correct`
- `hint1`, `hint2`
- `failure`(정답 확인 전), `reveal`(실패 후 시범)
- `explanation`, `explanation-expanded`

시스템 글자 크기 2배·모션 감소는 320×640과 가로 852×393에서도 확인했다. 테스트 글꼴은 `PREVIEW_FONT`, `PREVIEW_ICONS_FONT`로 주입한다. 개인 컴퓨터 경로는 테스트에 고정하지 않는다.

## 원본 에셋 및 남은 확인 사항

1. **하차 의도의 시각적 모호함**: 두 승객이 열린 문 뒤에 있어 승강장에서 기다리는 사람처럼 보일 수 있다. 상황 문구는 객실 안에서 내리는 승객임을 명시한다. 그림만으로 더 명확하게 전달하려면 배경·승객 대체 레이어가 필요하다. 임의로 그리지 않았다.
2. **정답 위치 겹침**: 몽몽이와 고양이의 가장자리 일부가 겹친다. 실제 캡처에서는 두 얼굴·발과 중앙 통로가 구분되지만, 캐릭터 간 완전한 간격이 필요하면 디자이너가 정답 스냅 이미지와 범위를 함께 재제공해야 한다. 원본의 약 524 알파 픽셀 겹침을 그대로 유지했다.
3. `waiting`/`stuck` 승객 PNG와 `dog_observer`/`dog_positive` PNG는 각각 동일하다. 따라서 오답 승객·정답 강아지에 새 표정이 생기는 것으로 보고하지 않는다.
4. **효과음 파일 없음**: 01번도 실제 소리 파일 없이 주입 가능한 재생 콜백만 있다. 이를 재사용했고 중복·음소거·실패 처리를 검증했지만 앱 진입점에 실제 음원은 연결하지 않았다. 정답·오답 음원 파일이 필요하다.
5. **Pretendard 원본 없음**: 기존 앱의 글꼴 테마를 유지했다. 테스트 캡처는 외부에서 주입한 한국어 글꼴을 사용하며 Pretendard 적용 완료로 주장하지 않는다.
6. **공식 출처**: 대전교통공사와 안전한TV 페이지는 응답을 확인했다. 광주교통공사 URL은 두 차례 시간 초과로 접속 확인을 마치지 못했다. 전달받은 URL은 변경하지 않았다. 세 링크 모두 공통 출처 UI에서 열 수 있다.
7. Android 실제 기기·실제 진동·실제 소리·기기 성능은 확인하지 못했다. 웹 빌드 및 위젯 테스트 결과와 구분한다.

# 대중교통 04번 응용 B안 — 아트 및 UI 연동

> 이후 사용자 승인으로 판정·힌트·해설·완료 연결을 구현했다. 현재 상태는 [학습 기능 완성 보고서](application04-learning-implementation.md)를 따른다. 아래는 승인 전 UI 연동 시점의 기록이다.

## 구현 범위

`MANNERS_transit04_application_final_handoff_B.zip`을 사용했다. 첨부 경로의 파일명에는 `(1)`이 없으며, 내부 B안 규격과 Manifest를 확인했다.

- 기존 `SequenceLessonScreen`과 `SequenceCardList`를 재사용했다. 기본 문제의 카드·드래그·O/X·효과음·재도전 처리 기본값은 유지했다.
- 선택된 `MannerPartner`를 dangdang/nyangnyang/mongmong에 매핑하고, JSON의 장면 경로와 이름 템플릿을 함께 사용한다.
- 상황 그림은 캐릭터별 완성 PNG 하나만 사용한다. 976×397 비율과 `BoxFit.contain`을 유지한다. 추가 테두리·모서리 클리핑·독립 캐릭터 합성을 적용하지 않는다.
- 진행도는 `응용 04/20 · 2/2`이다.
- 초기 카드는 A→B→C→D이며 임의로 섞지 않는다. 공통 카드 컴포넌트에서 원본 PNG 네 개와 문구를 표시하고 기존 핸들 드래그를 사용한다. 긴 문구는 잘라내지 않고 줄바꿈한다.
- 04번 기본 해설의 다음 버튼에서 같은 선택 캐릭터의 응용 화면으로 진입한다. 기본 문제 자체의 판정·해설 내용은 유지한다.

## 판정 및 교육 승인 대기

원본 `grading.status = NOT_APPROVED`, `accepted_orders = null`, `education_content_status = DRAFT_NOT_APPROVED`를 유지했다. 권장 B-D-A-C를 정답으로 채택하지 않았다. 응용의 정답 목록은 비어 있으며, 화면의 버튼뿐 아니라 상태 객체의 `submit()`과 `reveal()`에도 승인 차단을 적용했다.

| 상태 | 동작 |
| --- | --- |
| 최초 진입 | A→B→C→D, 제출 비활성 |
| 드래그 중 | 판정 없음, 제출 비활성 |
| 유효한 순서 변경 완료 | 제출 활성 |
| 제출 누름 | 승인 대기 안내만 표시, 순서 유지, 시도 횟수 0 유지 |
| O/X·오디오·정답 공개·보상 | 승인 전 실행하지 않음 |
| 힌트·해설 | 승인 대기 표시, 힌트 비활성, 미승인 교육 문구 비노출 |

최대 유효 제출 설정 4회는 JSON에서 읽지만 현재 유효 판정 자체가 없으므로 횟수를 차감하지 않는다. 기존 공통 O/X·힌트·해설 코드는 그대로 남아 있다. 승인된 복수 정답 목록 및 교육 문구를 받으면 인정 순서 전체를 지원하는 어댑터와 콘텐츠를 연결해야 한다. JSON 상태값만 변경해도 채점이 자동 활성화되지 않도록 했다.

교육 초안은 원본 추출 자료에 보존하고 앱 런타임에는 등록하지 않았다. 아직 응용 해설·학습 완료·05번으로 자동 진행하지 않는다. 이 화면은 현재 아트 및 UI 검수 범위이다.

## 파일

| 파일 | 변경 내용 |
| --- | --- |
| `app/lib/screens/application04_screen.dart` | B안 JSON 어댑터, 선택 캐릭터 장면·이름, 승인 차단 |
| `app/lib/screens/sequence_lesson_state.dart` | 선택적 고정 초기 순서 및 미승인 판정 차단, 기존 기본값 유지 |
| `app/lib/screens/sequence_lesson_screen.dart` | 선택적 응용 데이터·진행도·무클리핑 장면·응용 진입, 승인 대기 안내 |
| `app/lib/screens/transit04_screen.dart` | 기본 해설에서 응용 화면 진입 연결 |
| `app/assets/application04/` | 원본 장면 3개·카드 4개·명세 JSON 3개 |
| `app/pubspec.yaml` | 런타임 에셋 경로 등록 |
| `app/test/application04_test.dart` | 데이터·차단·3종×3너비·실제 드래그·기본→응용 검사 |
| `app/test/transit04_screen_test.dart` | 응용 진입이 가능해진 해설 버튼 기대값 갱신 |

## 에셋 검증 및 화면 확인

원본 Manifest의 15개 파일 크기·SHA-256이 모두 일치했다. 앱에 복사한 10개 파일도 원본과 바이트가 일치했다. 런타임 PNG는 7개이며 QA 비교 이미지는 포함하지 않았다.

제공된 `qa/approved_vs_runtime.png`와 Flutter 실행 화면을 비교해 캐릭터별 장면과 포함된 테두리·비율을 확인했다. 제공 QA 이미지는 정적 비교 자료이며 Flutter 실행 캡처가 아니다. 실제 Flutter 캡처는 아래 별도 경로에 저장했다. 승인 전체 화면의 UI 픽셀 일치를 주장하지 않으며, UI는 기존 Flutter 공통 컴포넌트를 유지했다.

## 테스트

관련 회귀 검사 5개 파일의 41개 테스트가 통과했다.

`flutter analyze --no-pub`: 문제 없음.

`flutter build web --no-pub -t lib/main_prototype.dart`: 성공. Wasm 사전 컴파일 검사도 성공했다.

- 320·360·390dp 각각 댕댕이·냥냥이·몽몽이 장면 및 이름, 비율, `BoxFit.contain`, 추가 클리핑 없음.
- 초기 제출 비활성, 순서 변경 후 활성, 실제 핸들 드래그, 제출 시 승인 안내 및 시도 0·편집 상태 유지.
- 정답 후보를 임의로 인정하지 않음, 직접 상태 메서드를 호출해도 판정·정답 공개 없음.
- 기본 04번 정답/오답·4회 실패·힌트·정답 공개·해설·다시 풀기 회귀 검사.
- 기본 04번 해설→선택 캐릭터 응용 진입, 기존 03번 기본·응용→04번 이동 회귀 검사.

실제 Android/iOS 기기, 운영체제 제스처·성능은 이번 검사에 포함하지 않았다. 전체 테스트 모음은 이번 작업에서 다시 실행하지 않았다. 커밋·푸시는 보류했다.

## 실행 자료

`C:/Users/gjo49/Documents/Codex/application04-review/`:

- `three-characters-flutter.png`: 실제 Flutter 390dp 초기 화면 3종.
- `captures/application04-dragged.png`: 실제 드래그로 순서가 변경되고 제출이 활성화된 화면.
- `package/qa/approved_vs_runtime.png`: 제공된 정적 승인 비교 자료.
- `asset-verification.json`, `regression-final.log`, `analyze-final.log`, `web-build.log`: 검사 근거.

추가로 필요한 것은 승인된 복수 정답 목록과 최종 힌트·해설 문구다. 현재 UI 검수에 필수인 누락 PNG는 없다.

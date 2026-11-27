# 02번 최종 히트박스·글꼴 수정

2026-11-20 후속 변경. `subway02-implementation.md`의 최초 단방향 정답·글꼴 미적용 설명은 이 문서의 내용으로 대체한다. 효과음 작업은 사용자의 요청대로 이후로 미룬다.

## 적용한 좌표

실제 설정은 `app/assets/subway02/asset_rules.json`이다. 캔버스는 1536×1024이며 모든 사각형의 네 경계를 포함한다.

| 용도 | 좌표 (left, top, right, bottom) |
| --- | --- |
| 전체 이동 | (0, 0, 1536, 1024) |
| 왼쪽 정답 | (0, 810, 430, 960) |
| 오른쪽 정답 | (1105, 810, 1355, 960) |
| 중앙 오답 | (500, 810, 1035, 963) |

판정은 처음 발 중심 `(830,902)`에 포인터 변위를 더한 점으로 한다. 손가락 좌표 자체나 몸 중심은 쓰지 않는다. 최소 이동량 26px, 알파 60 시작 마스크, 최대 4회 유효 오답, 무효 드롭의 무료 복귀 정책을 유지한다.

두 정답 영역 중 적중한 ID를 `correctZoneId`에 기록하고 해당 방향의 원본 PNG와 O 효과를 선택한다. 왼쪽 정렬 후 발 중심은 `(420,902)`, 오른쪽은 `(1125,902)`이다. 원본 캐릭터를 새로 그리지 않았다.

## 끝점 판정과 잘림 방지

최종 요청서는 x=0 부근도 원래 좌표로 먼저 판정하도록 명시하지만 ZIP의 일부 설명은 캐릭터를 화면 안으로 제한한 뒤 판정하도록 적혀 있다. 최종 요청서를 우선하여 **정렬 전 발 중심으로 판정**한다. 따라서 x=0, x=30 모두 왼쪽 정답으로 인정한다. 드래그 중 캐릭터 일부가 가장자리 밖으로 나갈 수 있지만 판정 좌표는 바꾸지 않는다.

정답이 된 뒤 220ms 동안 방향별 정답 위치로 정렬한다. 정렬 시작 위치를 정답 이미지의 실제 bbox에 맞춰 제한하여 애니메이션 시작·중간·끝에서 머리·몸·발·꼬리가 장면 안에 있다. 모션 감소 설정에서는 즉시 정렬한다. 오답은 실제 드롭 변위를 유지한다.

화면 변환에서 생기는 부동소수점 오차만 처리하도록 포함 판정에 `1e-7` 캔버스 픽셀 허용치를 사용한다. 게임 영역을 눈에 띄게 넓히는 보정이 아니다. 영역 사이의 x=470, x=1070 및 경계 바깥 점은 계속 무효다.

배치는 최신 `state_asset_mapping.json`의 순서를 따른다. 좌측 몽몽이는 강아지 뒤에 그리며 제공된 일부 겹침을 유지한다. 우측 정답 이미지 bbox `(990,578)~(1260,902)`와 고양이 bbox는 겹치지 않는다.

## 글꼴과 문구

- 제공 폴더의 Pretendard Regular(400), SemiBold(600), Bold(700) OTF를 그대로 복사했다. 세 파일 모두 원본 해시와 일치한다.
- `app/assets/fonts/pretendard/`에 글꼴과 원본 SIL OFL 라이선스를 보관하고 `pubspec.yaml`에 등록했다.
- `main.dart`, `main_prototype.dart`의 테마에 `fontFamily: Pretendard`를 적용했다.
- 해설 첫 번째 이유에서 “이는 사람의 이동에 관한 매너로, 01번 백팩 관리 문제와 구분됩니다.” 문장만 삭제했다. 앱 콘텐츠와 프로젝트의 교육 Markdown을 함께 맞췄다.

## 수정·추가 파일

- `app/assets/subway02/asset_rules.json`, `state_asset_mapping.json`: 새 좌표·좌우 정답 매핑. 최종 요청서에 맞춰 충돌하는 판정·정렬 설명도 수정.
- `app/assets/subway02/assets/`: 전달받은 PNG 갱신. 좌우 정답 캐릭터·O 효과 각 2개 추가. 참고 시안·원본 ZIP·생성 스크립트는 번들에 넣지 않음.
- `app/lib/screens/action_drag_state.dart`: 좌우 적중 ID와 일관된 경계 포함 판정. 01번의 기존 다각형 판정은 유지.
- `app/lib/screens/subway01_screen.dart`: 공통 화면에서 좌우 에셋 선택·사전 로드·정렬 애니메이션·선택적 디버그 표시.
- `app/lib/screens/subway02_screen.dart`, `subway02_hitbox_overlay.dart`: 디버그 옵션과 동일 설정을 읽는 히트박스 그림.
- `app/lib/screens/subway02_content.dart`, `docs/design/education_content_subway_02.md`: 요청한 문장 삭제.
- `app/assets/fonts/pretendard/`, `app/pubspec.yaml`, `app/lib/main.dart`, `main_prototype.dart`: 글꼴 등록·적용.
- `app/test/subway02_hitbox_test.dart`, `subway02_hitbox_screen_test.dart`: 좌/중/우와 모서리·무효·취소·정렬 가시성·문장 삭제·실제 글꼴 캡처 검사.
- `app/test/subway02_test.dart`: 정답으로 바뀐 예전 좌측 지점 대신 새 영역 사이 빈 공간을 무효 검사에 사용.

## 디버그 검수

일반 화면에는 표시하지 않는다. 디버그 실행 시 `--dart-define=SUBWAY02_DEBUG_HITBOXES=true`를 주면 전체 이동 영역(파랑), 정답(초록), 오답(빨강), 발 기준점이 나온다. `kDebugMode` 조건이 있어 배포 빌드에는 나오지 않는다. 판정과 그림은 같은 규칙 객체를 참조하며 영역 좌표를 그림 코드에 중복하지 않는다.

`subway02_hitbox_screen_test.dart`에 `CAPTURE_DIR`를 주면 320·393dp의 좌측 끝/우측 드래그, 정답 정렬, 기본·펼친 해설 캡처를 만든다. 이 검사는 번들 Pretendard 원본을 실제로 로드한다. 아이콘 글꼴은 `PREVIEW_ICONS_FONT`로 선택 주입하며 개인 컴퓨터 경로를 테스트에 고정하지 않는다.

## 검증

- 전달받은 ZIP의 manifest 파일 65개 해시 일치.
- 관련 11개 테스트 파일 **84개 통과**. 01번 드래그·힌트·해설·재풀이와 저장 기록 보존 회귀 검사를 포함한다.
- `flutter analyze --no-pub`: 문제 없음.
- `flutter build web --no-pub --no-wasm-dry-run --target lib/main_prototype.dart`: 성공. 브라우저를 자동 실행하지 않았다.
- 전체 `flutter test --no-pub`: **556개 통과, 9개 건너뜀, 20개 실패**. 이전 전체 검사와 실패 항목이 동일하다. Windows 경로·줄바꿈·CLI 검사 17개, 기존 fake 모듈 참조 1개, 기존 01번 화면 진입 테스트 시간 초과 2개이며 이번 수정의 통과 결과와 구분한다.
- 경계 단위 검사와 실제 화면 포인터로 `(0,900)`, `(30,900)`, `(1200,900)` 판정을 확인했다. 정렬 중 3개 시점의 실제 이미지 범위도 검사했다.
- 실제 Android 기기, 진동 및 소리 재생은 이번 검증에 포함하지 않았다. 효과음 파일·재생 연결 작업은 이후 진행한다.

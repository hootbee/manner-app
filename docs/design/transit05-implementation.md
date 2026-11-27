# 대중교통 05번 기본 문제

## 적용 자료와 검증

`MANNERS_transit05_art_revision_20261121 (1).zip` 한 개만 사용했다. 이전 ZIP을 병합하지 않았다. manifest 33개 항목의 경로·SHA-256이 모두 일치했다. 원본 ZIP과 검수 그림은 저장소 밖 `C:/Users/gjo49/Documents/Codex/transit05-review/MANNERS_transit05_art_revision/`에 보관한다.

실제 런타임은 배경 1개와 캐릭터 3개만 lossless WebP로 변환해 사용한다(합계 약 1.60MB). 목업, 비교 그림, 독립 소품은 앱 화면으로 사용하지 않는다.

## 구현

- 기존 03번 화면을 `choice_lesson_screen.dart` 공통 컴포넌트로 추출했다. `subway03_screen.dart`는 기본 설정을 전달하는 래퍼이며, 기존 키·문구·250ms 판정 시간·레이아웃을 유지한다. 03번 검사 13개를 통과했다.
- `transit05_screen.dart`는 05번 JSON·아트 경로, 진행 번호, 강화된 결과 표시 설정을 전달한다. 원본 문제 JSON의 선택지·정답 B·A/C별 피드백·2개 힌트·4회 제한을 직접 읽는다. 기존 03번 JSON 형식도 호환한다.
- 상황 문구는 `situationByCharacter`의 mongmong/dangdang/nyangnyang을 선택 파트너에 맞춰 가져온다. 그림과 문구를 별도로 고정하지 않는다.
- `scene_layout.json`은 asset_rules의 전체 캔버스 좌표를 공통 장면 렌더러에 전달하는 어댑터다. 배경·캐릭터 모두 1536×1024, 원점 (0,0), 배율 1이며 같은 FittedBox 안에서만 함께 축소한다. 개별 캐릭터 중앙 정렬·추가 배율·미리보기 크롭을 적용하지 않았다.
- 05번 아트에는 캐릭터마다 포즈 1개만 제공된다. 상태별 몸 그림을 새로 만들지 않으며, 동일 캐릭터의 상태 변경 시 중복 이미지 전환도 하지 않는다. 힌트/해설 아바타는 기존 확정 고민 프로필을 파트너별로 재사용한다.
- 05번만 공통 ResultFeedbackOverlay를 사용해 큰 초록 O/빨간 X를 1.75초 표시한다. 제출 전 선택 변경은 미채점이다. 판정 중 선택·추가 제출은 잠근다. 결과 영역의 O/X와 피드백은 다음 동작까지 표시한다.
- 4번째 오답은 정답을 숨기고 `정답 확인`만 제공한다. 수동 정답 시범은 성공이 아니며 XP/완료 기록을 변경하지 않는다. 재풀이에서 선택·힌트·횟수·효과를 초기화하고 저장된 기록을 유지한다.
- 04번 해설에서 05번으로 이동하며 파트너를 유지한다. 05번의 다음 문제는 연결하지 않아 비활성이다. 학습 목록/transportQuestions의 05번도 새 문제 문구로 맞췄다.

## 교육 콘텐츠

`education_content_transit05.md` 원문을 보관하고 표시용 `explanation.json`으로 분리했다. 핵심 매너, 학습 핵심, 실천 한마디, 이유 3개, Q&A 3개, 출처 2개, 법적 주의 문구, 마지막 '학습 후 실천'까지 유지한다. 기본은 접힌 상태이고 상세 내용은 현재 페이지에서 펼친다.

출처 링크는 제공된 URL 그대로 연결했으며 공식 페이지 접근을 확인했다.

- [서울시 공식 안내](https://news.seoul.go.kr/traffic/archives/36023)
- [국가법령정보센터의 제공 조례 페이지](https://www.law.go.kr/LSW/ordinInfoP.do?ordinSeq=2009399)

서울시 사례와 전국 공통 금지를 구분하는 원문을 유지했다. 제공 원문에 첫 출처의 날짜가 없으므로 임의 날짜를 만들지 않았다. 조례 날짜는 제공된 페이지의 시행일로 구분한다.

## 주요 변경 파일

- 신규: `choice_lesson_screen.dart`, `transit05_screen.dart`, `assets/transit05/`의 문제/교육/장면 데이터와 WebP 4개, `test/transit05_screen_test.dart`, 교육 원문 및 이 문서.
- 수정: `subway03_screen.dart`(래퍼), `choice_lesson_state.dart`(05 스키마/캐릭터 문구 호환), `subway03_scene.dart`(루트·정적 전체 캔버스 설정), `transit04_screen.dart`, `transport_lesson_screen.dart`, `transport_questions.dart`, `learning_catalog.dart`, `lesson_explanation_screen.dart`(핵심 문구 강조 처리), `pubspec.yaml`.
- 검사 정리: 더 이상 존재하지 않는 '구 05번 드래그' 검사는 새 선택형 진입 검사로 교체했다. 구형 일반 드래그가 없는 카테고리에서는 일반 UI 검사를 만들지 않으며, 01/02 전용 드래그 검사는 유지한다.

## 검수 자료

`C:/Users/gjo49/Documents/Codex/transit05-review/captures/`에 실제 Flutter 위젯 실행 캡처를 보관했다. 각 파트너별 initial, selected, wrong, correct, hint-1/2, failure, revealed, summary, details, sources 파일이 있다. 기기 녹화나 실기기 검수로 표현하지 않는다.

- 05번 신규 검사 7개: 원문·스키마, 파트너 3종 전체 풀이, 04→05 이동, 320×640/852×393 글씨 2배·모션 감소 검증.
- 05번과 일반 재시도 검사 합계 22개 통과(`transit05-final-tests.log`).
- `flutter analyze --no-pub`: 문제 없음(`transit05-analyze.log`).
- 웹 빌드 성공(`transit05-build.log`).
- 전체 검사 결과는 `transit05-full-final.log`에 기록한다. 이 실행 환경에는 앞서 확인한 Dart CLI 비정상 종료 문제가 있어, 해당 실패를 숨기거나 기대값을 바꾸지 않는다.
- 최종 전체 결과: **610개 통과, 9개 건너뜀, 기존 CLI 검사 3개 환경 실패**. 앞서 사용자 VS Code에서 확인했던 종료 코드 문제와 구분해 기록하며, 이번 화면의 실패로 분류하지 않는다. 01~04 전용 검사와 새 05번 검사는 모두 통과했다.

## 최종 아트 승인 대기 및 한계

1. 재구성된 배경과 최초 승인 시안의 구도 차이. `verification/background_comparison.png`로 최종 아트 담당 확인 필요.
2. 몽몽이 꼬리는 이번 보완본의 화면 오른쪽 방향을 그대로 사용한다. 04번 성체 대비 머리·몸 비율은 여전히 승인 대기이며 `mongmong_04_vs_05_comparison.png`로 확인해야 한다.
3. 최종 아트가 오면 같은 1536×1024 전체 캔버스 인터페이스의 배경/캐릭터 파일과 scene_layout 경로만 교체하면 된다. 재배치가 필요하면 원본 asset_rules와 함께 검수한다.
4. 실제 모바일 기기의 터치·음향·진동은 미검수다. 효과음 파일 및 실제 보상 지급은 기존에 보류한 공통 연결 범위이며 새로운 로컬 보상 저장 로직을 추가하지 않았다.

기능 검증 완료와 최종 아트 승인은 별개다. 요청대로 커밋·푸시는 하지 않았다.

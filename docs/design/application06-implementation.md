# 대중교통 06번 응용 — 통합 구현

`MANNERS_transit06_application_final_handoff_B_v1.zip`과 사용자 최종 요청서를 적용했다. 원본 ZIP은 수정하지 않았고, 프로젝트의 06번 응용 힌트·교육 상태만 APPROVED로 갱신했다.

## 구현 기능

- 기존 `ChoiceLessonScreen`·상태·말풍선·팝업·간단 해설·완료 화면을 재사용한다. 새로운 UI나 캐릭터를 제작하지 않았다. 이번 작업에서 다른 문제의 공통 컴포넌트는 수정하지 않았다.
- 선택 캐릭터 이름과 완성 장면 3종을 함께 전환한다. 장면은 935×410 비율, BoxFit.contain, 이미지 한 장으로 표시한다. 추가 테두리·클리핑·독립 배경 합성을 사용하지 않는다.
- 초기 미선택·제출 비활성, B만 정답, A·C별 확정 피드백, 선택 변경만으로 무판정, 제출 후 기존 O/X·사운드·반응을 사용한다.
- 총 4회 유효 제출과 중복 제출 차단·재도전, 선택 캐릭터 생각 프로필을 적용한 힌트 1→2를 연결했다. 힌트는 긴 문구 기준 동일 높이·좌우 16dp 패딩을 사용하고 선택·횟수를 유지한다.
- 최종 실패에서는 B와 확정 설명을 학습용으로 공개한다. success는 false이며 정답 소리·O 연출·성공 XP를 실행하지 않는다.
- 해설은 핵심 매너 → 왜 중요한가요? → 실전 팁 → 출처 두 건 및 권장 행동 안내 → 학습 핵심·작은 캐릭터 프로필 순서이다. Q&A·펼침·별도 대제목은 추가하지 않았다.
- 승무원에게 도움을 요청하는 행위 자체는 잘못이 아니라는 설명과 정답 B가 법적 의무·모든 열차의 강제 규정이 아닌 권장 소통이라는 안내를 유지했다.
- 06번 기본 해설의 버튼은 응용으로 이동한다. 기본 문제를 직접 맞혔는지, 최종 정답 공개를 이용했는지 전달한다. 응용 해설에서 문제 다시 풀기·학습 완료를 사용할 수 있다.
- 07번 이동을 새로 만들지 않았다. 기존 06번 기본 화면에 다음 문제 콜백이 없으므로 완료 화면의 다음 문제 버튼은 비활성이다. 뒤로가기·알림 등 기존 완료 화면 구성은 그대로다.

## 완료 및 보상

기존 `TopicCompletionBinding` / `TopicCompletionGateway`와 완료 화면을 사용한다. 화면이 XP·레벨을 직접 계산하지 않으며 서비스의 before/after 프로필을 표시한다. 완료 캐릭터·꽃가루·게이지·상단 버튼은 수정하지 않았다.

- 주제 키는 `transit_06`. 사용자·주제 최초 완료 키로 중복을 막는다.
- 현재 공통 체험용 정책과 같은 최초 직접 정답 20 XP를 `content/reward_policy.json`에 분리했다.
- 기본 또는 응용에서 정답 공개를 사용했으면 0 XP, 복습도 0 XP이다.
- 최종 실패 후 최초 완료 기록도 유지하여 다시 맞혀도 중복 보상이 생기지 않는다.
- 기본 해설 완료 결과가 없는 단독 응용 진입에서는 세트 완료 보상을 만들지 않는다.
- 기존 체험 앱의 영속 보상 서비스를 사용한다. 운영 서버용 Gateway 구현·연결은 기존 별도 작업이며, 이번에 새 서버 API를 만들지는 않았다.

## 출처 확인 및 날짜 정정

두 기사 링크의 접근을 확인했다. URL에 포함된 숫자와 기사에 실제 표시된 발행일이 달라, 출처 날짜만 아래처럼 정정했다. 요청서 날짜는 JSON의 `requestedDate`와 원문 요청서에 추적 가능하게 남겼다. 교육 본문은 유지했다.

| 자료 | 요청서 날짜 | 기사 표시 발행일 및 앱 표시 |
| --- | --- | --- |
| [뉴시스 리클라이닝 갈등 보도](https://www.newsis.com/view/NISX20260908_0003780835) | 2026-09-08 | 2026-09-27 |
| [뉴시스 등받이 논란·항공사 대응 보도](https://www.newsis.com/view/NISX20231020_0002491155) | 2023-10-20 | 2023-10-22 |

출처는 참고 보도로 표시한다. 자동 UI 검사는 두 카드를 눌렀을 때 정확한 URI가 기존 링크 열기 방식에 전달되는지 확인했다. 실제 휴대폰 브라우저 전환은 검사하지 않았다.

## 변경 파일

| 파일 | 내용 |
| --- | --- |
| `app/lib/screens/application06_screen.dart` | B안 데이터 어댑터, 응용 화면·해설·완료 서비스 연결 |
| `app/lib/screens/transit06_screen.dart` | 기본 해설→응용 및 기본 결과 전달 |
| `app/assets/application06/assets/scenes/` | 원본 PNG 3종, 바이트 유지 |
| `app/assets/application06/spec/problem_choice_transit06.json` | 확정 힌트·피드백·정답 공개·승인 상태 |
| `app/assets/application06/spec/state_asset_mapping.json` | 해당 문제 교육 승인 상태 |
| `app/assets/application06/spec/asset_rules.json` | 원본 B안 표시 규격 |
| `app/assets/application06/content/education_content_transit06.md` | 확정 교육 원문·출처 날짜 정정 기록 |
| `app/assets/application06/content/explanation.json` | 해설 카드·출처·한마디 |
| `app/assets/application06/content/reward_policy.json` | 06번 주제 보상·정답 공개 0 XP 설정 |
| `app/pubspec.yaml` | 새 자료 등록 |
| `app/test/application06_test.dart` | 신규 기능·3종·반응형·보상·기본→응용 검사 |
| `app/test/transit06_screen_test.dart` | 기본 해설의 응용 진입 버튼 기대값 갱신 |

다른 문제의 판정 데이터·교육 승인 상태·디자인은 변경하지 않았다.

## 검수 항목 및 한계

신규 15개 검사를 포함해 기존 01~05번 기본·응용, 06번 기본, 공통 해설·팝업 등 관련 15개 테스트 파일의 **193개 검사가 모두 통과**했다(종료 코드 0). `flutter analyze --no-pub`도 문제 없음이다.

`flutter build web --no-pub -t lib/main_prototype.dart`와 Wasm 사전 컴파일 검사가 성공했다. 현재 확인된 미해결 기능 오류는 없다.

- 원본 Manifest 11개 파일의 크기·SHA-256 일치. PNG 3개도 원본 바이트 그대로이다. QA 이미지는 런타임에 포함하지 않았다.
- A/B/C 제출 판정·오답별 피드백·중복 차감 차단·최대 4회·선택 단계 무판정.
- 320·360·390dp × 캐릭터 3종의 장면·이름·비율·힌트·판정·해설·완료.
- 힌트 두 단계 동일 크기·선택 유지·횟수 유지·2단계 이후 다음 버튼 숨김.
- 두 출처 URI·해설 전체 문구·권장 소통 및 승무원 중재 안내.
- 4회 실패→B 공개→해설→완료 0 XP, 정답 소리 미사용.
- 최초 직접 정답·레벨 경계·동시 완료 요청·재진입·서비스 재생성·복습 보상 중복 방지.
- 320dp 2배 글자, 긴 해설 스크롤, 문제 다시 풀기 후 현재 풀이 초기화·기존 보상 유지.
- 실제 기본 화면에서 직접 정답 및 최종 정답 공개 경로를 각각 응용·완료까지 진행하고 기본 공개 시 0 XP임을 확인.

실제 Android/iOS 기기·OS 브라우저 전환·진동·스피커 청취·운영 서버 보상 검수는 미실시했다. 자동 검사에서는 화면·이벤트·데이터 상태를 확인했다. 커밋·푸시는 하지 않았다.

## 실행 자료

`C:/Users/gjo49/Documents/Codex/application06-review/`:

- `three-characters-initial.png`, `three-characters-completion.png`: 실제 Flutter 위젯 실행 캡처 3종.
- `captures/`: 초기·힌트·출처·학습 핵심·완료·정답 공개·0 XP 화면.
- `regression.log`, `navigation-tests.log`, `analyze.log`, `web-build.log`, `asset-verification.json`: 최종 검사 근거.

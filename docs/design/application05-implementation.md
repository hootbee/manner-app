# 대중교통 05번 응용 — 전체 기능 통합

사용자 최종 요청서를 우선하여 B안 패키지의 예전 미승인 힌트·해설을 교체했다. ZIP 원본은 수정하지 않았다. 실제 파일명은 `MANNERS_transit05_application_final_handoff_B_v1 (1).zip`이다.

## 동작

- 기존 선택형 화면과 상태를 재사용한다. 초기 미선택·제출 비활성, 선택 후 제출 활성, 선택 변경만으로 판정하지 않는 규칙을 유지한다.
- B만 정답이며 A·C에 서로 다른 확정 피드백을 적용했다. 기존 O/X, 선택 캐릭터 팝업·효과음·진동 규칙을 재사용하고 판정 중 중복 제출을 차단한다.
- 최초 1회와 재도전 3회, 총 4회 유효 제출 제한이다. 최종 실패 후 정답 B와 확정 학습 설명을 공개하되 성공 상태·정답 효과음·O 연출로 전환하지 않는다.
- 힌트 1·2는 기존 말풍선과 생각 프로필을 사용한다. 긴 문구 기준으로 두 단계의 크기를 같게 계산하고 좌우 16dp 패딩을 유지한다. 힌트를 확인해도 선택과 횟수가 유지되며, 2단계 이후 다음 힌트 버튼은 숨긴다.
- 완성 장면은 캐릭터별 PNG 한 장만 표시한다. 900×400·9:4·BoxFit.contain을 유지하고 별도 테두리·클리핑·재합성을 추가하지 않는다. 같은 캐릭터 이름을 상황 설명에도 적용한다.
- 응용 해설은 기존 카드로 핵심 매너 → 왜 중요한가요? → 실전 팁 → 근거 및 출처 → 법·기준과 권장 매너의 구분 → 학습 핵심 및 작은 캐릭터 프로필을 표시한다. Q&A·펼치기·별도 대제목은 없다.
- 출처 카드는 기존 링크 여는 방식을 그대로 사용한다. [서울시 공식 페이지](https://news.seoul.go.kr/traffic/archives/36023)의 접근을 확인했다. 자동 UI 검사는 카드 클릭이 정확한 URI를 전달하는지 확인했으며 실제 휴대폰 브라우저 전환은 미실시했다.
- 05번 기본 해설 → 응용 → 응용 해설 → 기존 학습 완료 화면 → 06번 기본 문제로 연결한다. 기본 풀이 결과를 응용에 전달한다.
- 문제 다시 풀기는 응용의 현재 선택·시도·힌트를 초기화하며 저장된 보상을 지우지 않는다.

## 완료 및 XP

기존 `TopicCompletionGateway`, 체험용 영속 보상 저장, `TopicCompletionScreen`을 그대로 사용한다. XP·레벨·게이지는 서비스가 반환한 프로필을 사용한다. 완료 캐릭터·꽃가루·버튼 디자인은 변경하지 않았다.

- 사용자/주제 최초 완료 키는 `transit_05`로 분리한다. 01·04번 보상과 충돌하지 않는다.
- 최초 직접 정답은 현재 공통 체험용 정책과 같은 20 XP이며 `content/reward_policy.json`에서 변경 가능하다.
- 기본 또는 응용에서 정답을 공개한 경우에는 0 XP, 복습도 0 XP이다.
- 완료 중복 요청·재진입·서비스 재생성 시에도 최초 보상을 중복 지급하지 않는다. 실패 후 처음 학습 완료한 기록도 유지한다.
- 기본 해설 완료 결과가 없는 단독 응용 진입에서는 세트 완료 보상을 만들지 않는다.
- 기존 운영 서버용 완료 Gateway 구현·연결은 별도 작업이다. 이번에는 기존 체험 앱 서비스에 연결했으며 다른 문제의 보상 정책이나 서버 API는 변경하지 않았다.

## 변경 파일

| 파일 | 변경 |
| --- | --- |
| `app/lib/screens/application05_screen.dart` | 승인 데이터 어댑터, 응용 화면 및 주제 완료 연결 |
| `app/lib/screens/choice_lesson_screen.dart` | 선택적 간단 해설·긴 힌트·정답 공개 문구·완료 콜백 |
| `app/lib/screens/subway03_scene.dart` | 선택적인 완성 장면 PNG 표시 경로; 기존 분리 합성 기본값 유지 |
| `app/lib/screens/lesson_explanation_screen.dart` | 간단 해설에서 기존 출처 링크 카드를 접기 없이 표시 |
| `app/lib/screens/transit05_screen.dart` | 기본 결과 전달 및 응용 진입 |
| `app/assets/application05/assets/scenes/` | 승인된 장면 3종, 원본 바이트 유지 |
| `app/assets/application05/spec/problem_choice_transit05.json` | 승인 힌트·A/B/C 피드백·정답 공개 문구 |
| `app/assets/application05/spec/state_asset_mapping.json` | 해당 문제 힌트·해설 승인 상태 동기화 |
| `app/assets/application05/spec/asset_rules.json` | 원본 B안 표시 규격 |
| `app/assets/application05/content/education_content_transit05.md` | 사용자 최종 교육 원문 및 APPROVED 표시 |
| `app/assets/application05/content/explanation.json` | 해설 표시 데이터와 공식 출처 |
| `app/assets/application05/content/reward_policy.json` | 05번 주제별 보상 설정 |
| `app/pubspec.yaml` | 새 런타임 자료 등록 |
| `app/test/application05_test.dart` | 데이터·판정·힌트·출처·완료·반응형·보상 검사 |
| `app/test/transit05_screen_test.dart` | 기본 해설의 응용 이동 버튼 기대값 갱신 |
| `app/test/transit06_screen_test.dart` | 실제 05번 기본·응용·완료 → 06번 이동 검사 |

다른 문제의 교육 데이터·판정 규칙·미승인 표시는 변경하지 않았다. 공통 컴포넌트는 선택적인 속성만 추가하여 기존 화면의 표시 기본값을 유지했다.

## QA와 한계

신규 자동 검사 13개가 통과했다. 실제 Flutter 위젯 실행으로 캡처했다.

01~06번 기본 문제, 기존 01~04번 응용, 공통 팝업·해설을 포함한 관련 14개 테스트 파일의 **178개 검사가 모두 통과**했다(종료 코드 0). 코드 분석(`flutter analyze --no-pub`)도 문제 없음이다. `flutter build web --no-pub -t lib/main_prototype.dart` 및 Wasm 사전 컴파일 검사가 성공했다.

- A/B/C 제출 판정, 선택 단계 무판정, 중복 제출 방지, 4회 제한, A·C별 피드백.
- 320·360·390dp × 캐릭터 3종의 장면·이름·비율·선택·힌트·오답→재도전→정답→해설→완료.
- 두 힌트 동일 크기·선택 유지·횟수 유지·2단계 이후 다음 버튼 숨김.
- 공식 URI 전달, 해설 원문 보존, 접기 없음, 작은 프로필 연동.
- 최종 실패 공개 시 성공 false·정답 소리 없음·완료 0 XP.
- 최초 보상·레벨 경계·동시 요청·재진입·복습 중복 방지, 미완료 기본 결과의 보상 차단.
- 320dp에서 2배 글자, 긴 해설의 스크롤, 문제 다시 풀기 후 기존 보상 유지.

원본 Manifest의 11개 파일 크기·SHA-256을 확인했고 런타임 PNG 3개는 원본과 바이트가 일치한다. QA 이미지는 앱에 넣지 않았다. 냥냥이·몽몽이 원본 PNG의 오른쪽/아래 외곽이 댕댕이와 다르게 끝나는 모습은 원본에 포함된 아트이다. Flutter 추가 자르기는 없으며 승인 PNG 수정 금지에 따라 그대로 유지했다.

실제 Android/iOS 기기, OS 브라우저 전환·진동·스피커 청취는 미실시했다. 자동 검사에서는 이벤트와 레이아웃을 검증했다. 운영 서버 보상 검수도 미실시했다. 커밋·푸시는 보류했다.

## 실행 자료

`C:/Users/gjo49/Documents/Codex/application05-review/`:

- `three-characters-initial.png`, `three-characters-completion.png`: 실제 Flutter 실행 화면 3종.
- `captures/`: 초기·힌트·출처·학습 핵심·완료·정답 공개·0 XP 캡처.
- `capture-tests-final.log`, `regression.log`, `analyze-final.log`, `web-build.log`, `asset-verification.json`: 검증 근거.

# 매너핏 (가칭)

매너 트레이닝 앱. Flutter(Android 먼저) + Supabase. 설계 결정은 [`docs/adr/`](docs/adr/)에 있다.

```
app/                      Flutter 앱 (Android 전용, applicationId com.hootbee.mannerfit)
  lib/content/            번들 JSON + Storage 새 버전 로드
  lib/engine/             XP, 연속 학습일, Leitner 계산 (기록 집합만 입력)
  lib/sync/               sync(table) 하나로 attempts, day_completions 동기화
  lib/auth/               Google 로그인, 탈퇴
  lib/screens/            화면
supabase/
  migrations/             DB 스키마와 RLS (ADR 0001)
  functions/delete-account/  탈퇴 Edge Function (ADR 0001)
content/                  콘텐츠 JSON 원본 (아직 없음. 지금은 docs/prototype/content.json)
pipeline/                 Claude 문제 생성·검토 스크립트 (아직 없음)
.github/workflows/        콘텐츠 파이프라인 (아직 없음)
docs/                     기획서, ADR, 견본, 디자인. GitHub Pages 소스
  privacy/                개인정보처리방침 (아직 없음)
  delete-account/         앱 밖 삭제 요청 안내 (아직 없음)
```

DB 백업 워크플로는 이 리포가 아니라 별도 비공개 리포에 둔다(ADR 0001 §7).

서비스 키, DB 비밀번호, API 키는 이 리포에 넣지 않는다. 리포는 공개다.

# 매너핏 (가칭)

매너 트레이닝 앱. Flutter(Android 먼저) + Supabase. 설계 결정은 [`docs/adr/`](docs/adr/)에 있다.

```
app/                      Flutter 앱 (Android 전용, applicationId com.hootbee.mannerfit)
  assets/content.json     콘텐츠 원본 (ADR 0003)
  lib/content/            번들 JSON + Storage 새 버전 로드
  lib/engine/             XP, 연속 학습일, Leitner 계산 (기록 집합만 입력)
  lib/sync/               sync(table) 하나로 attempts, day_completions 동기화
  lib/auth/               Google 로그인, 탈퇴
  lib/screens/            화면
supabase/
  migrations/             DB 스키마와 RLS (ADR 0001)
  functions/delete-account/  탈퇴 Edge Function (ADR 0001)
pipeline/                 문제 생성 프롬프트와 근거 요약 (코드는 app/tool/pipeline.dart, ADR 0009. 아직 없음)
.github/workflows/        PR 검사: content(콘텐츠 JSON 검증), db(pgTAP), app(analyze, 로컬 Supabase 붙인 flutter test)
docs/                     기획서, ADR, 견본, 디자인. GitHub Pages 소스
  privacy/                개인정보처리방침
  delete-account/         앱 밖 삭제 요청 안내
```

DB 백업 워크플로는 이 리포가 아니라 별도 비공개 리포에 둔다(ADR 0001 §7).

비밀 키(서비스 키, DB 비밀번호, Claude API 키)는 이 리포에 넣지 않는다. 리포는 공개다. Firebase 설정 파일의 API 키는 공개 식별자라 커밋한다(ADR 0006).

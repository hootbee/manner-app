# 0001. 풀이 기록과 완료 기록, RLS, 동기화, 탈퇴, 백업

상태: 채택
날짜: 2026-10-25

## 배경
서버 데이터의 모양과 권한이 동기화, 오프라인, 탈퇴, 백업을 결정하므로 앱 코드보다 먼저 정한다. 지금 견본(`docs/prototype/index.html`)은 기록에 `{manner, domain, grade}`만 남긴다(686행). XP와 연속 학습일은 기록에서 계산하지 않고 숫자를 따로 올린다(740행). 문제 id는 순번 기반(`~${i}`, 513행)이다.

2026-10-25에 사용자가 정한 것: 지금은 Android만 출시한다. 고정 결정의 "정답 여부"는 3단계 `grade` 값을 뜻한다. 서버에 `day_completions`를 추가한다. 웹은 GitHub Pages 정적 안내 페이지 두 개만 둔다.

## 결정
### 1. 테이블
```sql
create table public.attempts (
  id          uuid primary key,                                   -- 앱에서 만든 UUID. 멱등 키
  user_id     uuid not null default auth.uid() references auth.users (id) on delete cascade,
  scenario_id text not null check (char_length(scenario_id) between 1 and 100),
  grade       text not null check (grade in ('best', 'ok', 'avoid')),
  solved_on   date not null,                                      -- 답한 순간의 기기 날짜
  created_at  timestamptz not null default now()                    -- pull 커서로만 쓴다
);
create index attempts_user_created_idx on public.attempts (user_id, created_at, id);

create table public.day_completions (
  id           uuid primary key,
  user_id      uuid not null default auth.uid() references auth.users (id) on delete cascade,
  day_id       text not null check (char_length(day_id) between 1 and 100),  -- content.json days[].id
  completed_on date not null,                                               -- 마친 순간의 기기 날짜
  created_at   timestamptz not null default now()
);
create index day_completions_user_created_idx on public.day_completions (user_id, created_at, id);
```

- `grade` 값은 `content.json`의 `best | ok | avoid` 문자열과 같다. 정답 여부만 필요하면 `grade = 'best'`로 계산한다.
- `scenario_id`는 `<기본 시나리오 id>~<변형 키>` 형식이다. 매너는 콘텐츠에서 찾는다.
- 콘텐츠 ADR이 보장해야 할 것이 두 가지다. 기본 시나리오 id와 `day_id`는 지우거나 다른 데 다시 쓰지 않는다(빼야 할 때는 `retired`로 표시한다). 변형 키는 순번이 아니라 축 값으로 만든다.
- 시간대는 저장하지 않는다. CHECK 제약에는 상수만 쓴다. `current_date` 같은 값을 넣으면 dump를 복원할 때 깨진다.
- 날짜에는 범위 검사를 두지 않는다. 기기 시계가 틀려 서버가 거절하는 행이 생기면 그 테이블의 동기화가 계속 멈추기 때문이다(2026-10-27 사용자, 마이그레이션 `20261028000000_drop_record_date_checks.sql`).
- `day_completions`에는 `(user_id, completed_on)` 고유 제약을 두지 않는다. 기기 두 대가 같은 날 마치면 행이 둘 생기지만, 계산은 날짜 집합으로 하므로 하루로 센다.
- 이름과 이메일은 세션의 user 객체에서 읽으므로 `profiles` 테이블은 두지 않는다.
- 익명 로그인도 쓰지 않는다. 게스트 기록은 기기에만 둔다.

### 2. 권한과 RLS
```sql
alter table public.attempts enable row level security;
revoke all on public.attempts from anon, authenticated;   -- 기본 grant가 프로젝트마다 다르다
grant select on public.attempts to authenticated;
grant insert (id, scenario_id, grade, solved_on) on public.attempts to authenticated;  -- user_id는 못 보낸다
create policy attempts_select_own on public.attempts
  for select to authenticated using ((select auth.uid()) = user_id);
create policy attempts_insert_own on public.attempts
  for insert to authenticated with check ((select auth.uid()) = user_id);

alter table public.day_completions enable row level security;
revoke all on public.day_completions from anon, authenticated;
grant select on public.day_completions to authenticated;
grant insert (id, day_id, completed_on) on public.day_completions to authenticated;
create policy day_completions_select_own on public.day_completions
  for select to authenticated using ((select auth.uid()) = user_id);
create policy day_completions_insert_own on public.day_completions
  for insert to authenticated with check ((select auth.uid()) = user_id);
-- update와 delete는 정책도 grant도 없다. 행은 auth.users의 cascade로만 지워진다.
```

- 정책은 Supabase 지침을 따른다. `(select auth.uid())`로 감싸고, `to authenticated`로 대상을 좁히고, `user_id`가 인덱스 맨 앞에 오게 한다.
- 멱등 insert는 `upsert(rows, onConflict: 'id', ignoreDuplicates: true)`로 하고 `.select()`는 붙이지 않는다. 그러면 `on conflict (id) do nothing`이 되어 INSERT와 SELECT 정책만 거치고, UPDATE 정책은 필요 없다. `ignoreDuplicates`를 빠뜨리면 `DO UPDATE`가 되어 권한 오류가 나므로 실수가 바로 드러난다.

### 3. 동기화
두 테이블은 테이블 이름만 인자로 받는 같은 함수를 쓴다. 앞으로 생길 추가 전용 기록(예: 콘텐츠 오류 신고)도 같은 모양으로 만들고 같은 함수를 쓴다. 같은 모양이란 `id uuid pk`(앱에서 생성), `user_id default auth.uid() … on delete cascade`, `created_at default now()`, `(user_id, created_at, id)` 인덱스, 2절과 같은 grant와 정책을 갖추는 것이다.

```dart
/// table: 'attempts' | 'day_completions' | 같은 모양의 추가 전용 테이블
Future<void> sync(String table) async {
  await _push(table); // synced=false 행을 500개씩 upsert(onConflict: 'id', ignoreDuplicates: true) → 2xx면 synced=true
  await _pull(table); // (created_at, id) 키셋으로 1000행씩 받아 id 합집합으로 로컬에 추가
}
// _pull의 한 페이지: supabase.from(table).select().eq('user_id', uid)
//   .or('created_at.gt.$c,and(created_at.eq.$c,id.gt.$i)').order('created_at', ascending: true).order('id', ascending: true).limit(1000); // 기본값은 내림차순
```

- **로컬 원본**: 서버 insert 권한이 있는 컬럼에 `synced`를 더한 행을 기기 안 저장소에 둔다(형식은 ADR 0005). 답할 때 `attempts`에 쓰고(`id`는 uuid v4, `solved_on`은 기기의 오늘 날짜), 데일리 마지막 장면을 마칠 때 `day_completions`에 쓴다. 둘 다 네트워크가 필요 없다.
- **호출 시점**: 앱 시작, 세트 종료, 연결이 돌아왔을 때. 실패하면 다음 호출에서 다시 한다. 같은 행을 다시 보내도 결과는 같다.
- **pull 커서**: 테이블마다 `(created_at, id)` 하나를 저장하고(로그아웃·탈퇴 때 기록과 함께 지우므로 한 기기에는 한 사용자의 커서만 있다), 페이지를 받을 때마다 마지막 행 값으로 갱신한다. 시각은 마이크로초까지 UTC `Z` 형식으로 보낸다.
  - 첫 페이지: 커서가 없으면 처음부터 받는다. 커서 `(c, i)`가 있으면 시작 키는 `(c - 5분, '00000000-0000-0000-0000-000000000000')`이고, 이는 `created_at >= c - 5분`과 같다. 5분을 겹치는 이유는 `now()`가 트랜잭션 시작 시각이라 커밋 순서와 어긋날 수 있기 때문이다.
  - 다음 페이지는 직전 페이지 마지막 행부터 받는다. 받은 행이 1000개보다 적으면 멈춘다.
- **게스트와 로그아웃**: 게스트 기록도 `synced=false`로 쌓아 두었다가 로그인하면 그대로 올린다. `user_id`는 서버가 채운다. 로그아웃할 때는 먼저 `sync`를 해 본다. 그래도 못 올린 행이 있으면 "N개가 사라진다"는 확인을 받고, 로컬 기록과 커서를 지운다.
- **기기 두 대**: UUID가 서로 달라 둘 다 저장된다. pull을 마치면 두 기기가 같은 집합을 갖는다. 충돌을 해소할 로직은 필요 없다.

### 4. 학습 엔진 계산 규칙
모든 값은 기록 집합만으로 계산한다. 같은 날 안의 기록 순서에는 의존하지 않는다.

- **XP**: 모든 `attempts`의 점수 합이다(`best` 10, `ok` 5, `avoid` 0). 재도전과 중간에 나간 데일리도 포함한다. 견본의 "하루를 마쳐야 XP를 준다" 규칙(1244행)은 버린다. 콤보는 세트 안 연출로만 쓰고, 저장하지 않으며 XP에도 넣지 않는다.
- **연속 학습일**: `D`는 `day_completions.completed_on`의 집합, `T`는 기기의 오늘 날짜다. `T ∈ D`이면 `T`에서 끝나는 연속 일수, 아니고 `T-1일 ∈ D`이면 `T-1일`에서 끝나는 연속 일수, 둘 다 아니면 0이다. 카테고리 연습은 `day_completions`에 쓰지 않으므로 들어가지 않는다.
- **진행 위치와 주간 보상**: 견본의 `state.day`와 `daysDone` 대신 `day_completions`에서 계산한다.
- **Leitner**: (매너, 날짜) 단위로 판정한다. 예를 들어 그날 기록이 모두 `best`면 승급하고, 아니면 1단계로 돌린다. 확정은 학습 엔진 ADR에서 한다.

### 5. 탈퇴
탈퇴는 Edge Function `delete-account`가 처리한다. 앱에서만 호출하고, service role이 필요한 곳은 이 함수 하나다.

```ts
import { createClient } from 'npm:@supabase/supabase-js@2'

const admin = createClient(Deno.env.get('SUPABASE_URL')!, Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,
  { auth: { persistSession: false } })

Deno.serve(async (req) => {
  if (req.method !== 'POST') return new Response(null, { status: 405 })
  const jwt = req.headers.get('Authorization')?.replace(/^Bearer /, '') ?? ''
  const { data, error } = await admin.auth.getClaims(jwt)
  const uid = data?.claims?.sub
  if (error || !uid) return new Response(null, { status: 401 })
  const { error: delErr } = await admin.auth.admin.deleteUser(uid)   // 토큰의 sub만 지운다. 하드 삭제
  if (delErr && delErr.status !== 404) return new Response(null, { status: 500 })
  return new Response(null, { status: 204 })                         // 이미 없어도 성공(멱등)
})
```

- 토큰의 `sub` 한 명만 지우므로 role은 보지 않는다. `sub`가 없는 anon·service role 키는 `!uid`에서 401이다(2026-10-27, 쓸모없는 role 검사를 뺐다).
- `verify_jwt`는 기본값(켜짐) 그대로 둔다. 키는 함수 환경 변수에만 둔다. 새 키 체계를 쓰면 `SUPABASE_SECRET_KEYS`를 쓴다. 기록은 cascade로 함께 지워진다. 사용자가 소유한 Storage 객체가 생기면 `deleteUser`가 실패하므로, 그때는 이 함수에서 객체를 먼저 지운다. 앱에서의 순서는 아래와 같다.
1. 오프라인이면 탈퇴 버튼을 막는다. 탈퇴 요청은 큐에 넣지 않는다.
2. 사용자 확인을 받으면 `sync`를 멈추고 함수를 호출한다. 로컬 데이터는 서버가 성공했거나 세션이 거절된 뒤에만 지운다(4).
3. 204를 받으면 차례로 한다: `Store.clear()`(로컬 기록·커서 삭제와 `auth.signOut(scope: local)`) → Google Sign-In `disconnect()` → 게스트 첫 화면.
4. 응답이 없으면 `offline`을 돌려주고 사용자가 다시 누른다(함수가 멱등). 401이면 `refreshSession()` 뒤 한 번 더 부른다. 갱신이 거절되면(요청 전 만료 토큰의 갱신 거절 포함) 3의 정리를 하되 결과는 실패다(다시 로그인해 탈퇴하라고 안내). 계정이 서버에 남았을 수 있기 때문이다.
5. 다른 기기는 기존 토큰이 만료될 때까지 남아 있다. 그 기기에서 올리면 FK 위반(`23503`)으로 거절된다. 앱은 `23503`을 받거나, 세션이 없는데(갱신 실패, 켤 때 이미 없음) 서버에 올라간(`synced`) 기록이 있으면 로컬을 지우고 로그아웃한다. 그런 기록이 없으면 게스트로 돌아가고 남은 기록은 게스트 기록이다(게스트 기록은 `synced`가 될 수 없다).

### 6. 웹 페이지 (GitHub Pages, 정적 안내만)
- Pages 소스는 메인 리포 `main` 브랜치의 `/docs` 폴더다. 페이지는 `docs/privacy/index.html`과 `docs/delete-account/index.html` 두 개다.
- `/privacy/`에 적을 것: 수집 항목(Google 이름과 이메일, 풀이 기록, 완료 기록, 계정과 연결하지 않는 앱 이용 통계), 제3자(Supabase 서울 리전, Firebase Crashlytics, Firebase Analytics), 앱 이용 통계와 국외 이전 문구(ADR 0006 §3), 탈퇴 방법(앱 설정, 운영 이메일), 백업 보관("탈퇴 후 최대 30일 동안 백업에 남은 뒤 자동 파기").
- `/privacy/`에 함께 적을 것(2026-10-27 사용자 확정, 법적으로 충분한지는 출시 전에 확인한다)
  - 처리 목적: 이름·이메일은 로그인과 기록 백업, 풀이·완료 기록은 학습 진도 계산과 기기 간 동기화, 앱 이용 통계는 앱 개선, 크래시 보고는 오류 수정.
  - 보유 기간: 탈퇴할 때까지. 탈퇴 뒤 백업에 최대 30일, 앱 이용 통계의 개별 기록은 2개월.
  - 파기: 탈퇴하면 서버에서 바로 지운다. 백업은 30일이 지나면 자동으로 지워진다.
  - 이용자 권리: 열람은 앱 화면, 삭제는 탈퇴, 그 밖의 요청은 운영 이메일.
  - 안전 조치: 전송 암호화(TLS), 본인 기록만 읽고 쓰는 권한 제어(2절 RLS).
  - 위탁과 제공: Supabase와 Google은 처리를 맡긴 수탁자다. 제3자 제공은 없다.
  - 만 14세 미만: 만 14세 미만의 개인정보를 알면서 수집하지 않는다.
  - 변경 고지: 이 페이지에 시행일과 함께 게시한다.
  - 탈퇴로 지우는 범위: 계정과 서버의 풀이·완료 기록. 앱 이용 통계는 2개월, 백업은 30일 뒤 사라진다.
  - 게스트 기록: 로그인하면 그동안 기기에 쌓인 기록도 서버로 올라간다(3절).
  - 운영 주체는 매너핏 팀, 보호책임자는 이준형이다.
  - Crashlytics가 모으는 항목과 국외 이전: Crashlytics를 넣을 때 ADR로 정하고 더한다.
- `/delete-account/`: "탈퇴는 앱 설정 > 회원 탈퇴에서 한다"와 "앱 밖에서 요청하려면 hootbee0327@gmail.com으로 Google 계정 이메일을 보낸다. 받은 날부터 7일 안에 삭제하고 회신한다"만 적는다. 로그인이나 스크립트는 넣지 않는다.
- 운영자는 요청 메일을 받으면 Supabase 대시보드 Authentication에서 해당 이메일의 사용자를 삭제한다. 기록은 cascade로 함께 지워진다. 처리 기한은 받은 날부터 7일이다. 개인정보 보호법 시행령 제43조의 법정 기한 10일 안에서 주말·시험 기간을 버틸 여유를 둔 값이다. 삭제했으면 "삭제 완료"로 회신한다.
- 운영 이메일은 공개 페이지와 공개 리포에 그대로 드러난다.

### 7. 백업 (비공개 리포, 2026-10-25 사용자 확정)
메인 리포는 공개라서 아티팩트를 누구나 받을 수 있다. 그래서 비공개 리포를 하나 따로 둔다. 필요한 것은 워크플로 파일 하나와 시크릿 `SUPABASE_DB_URL`(Session pooler 연결 문자열) 하나다. 협업자는 운영자로만 둔다.

```yaml
name: db-backup
on:
  schedule: [{ cron: '17 18 * * *' }]   # 매일 03:17 KST. 정시는 지연·누락이 잦다
  workflow_dispatch:
permissions: {}
jobs:
  dump:
    runs-on: ubuntu-latest
    timeout-minutes: 15
    steps:
      - uses: supabase/setup-cli@v3
        with: { version: 2.122.0 } # 메인 리포 db.yml과 같은 버전. 이 CLI의 pg_dump는 17
      - env: { DB_URL: '${{ secrets.SUPABASE_DB_URL }}' }
        run: |
          supabase db dump --db-url "$DB_URL" -f roles.sql --role-only
          supabase db dump --db-url "$DB_URL" -f schema.sql
          supabase db dump --db-url "$DB_URL" -f data.sql --use-copy --data-only
          tar czf backup.tgz roles.sql schema.sql data.sql
      - uses: actions/upload-artifact@v4
        with: { name: 'backup-${{ github.run_id }}', path: backup.tgz, retention-days: 30 }
```

- 개인정보처리방침 문구: "탈퇴 후 최대 30일 동안 백업에 남은 뒤 자동 파기"
- GitHub Free의 비공개 리포 한도는 Actions 월 2,000분, 아티팩트 저장 500MB다. 덤프를 30개 보관하므로 `backup.tgz`가 15MB를 넘으면 다시 본다.
- CLI 버전은 고정한다. CLI가 올라가면 `pg_dump` 버전도 같이 바뀌기 때문이다. `pg_dump`는 자기보다 새 메이저 버전 서버를 덤프하지 못하므로, Supabase 프로젝트의 Postgres가 18 이상이 되면 `version`을 함께 올린다.
- 워크플로에 `--debug`나 `--dry-run`을 붙이지 않는다. 디코딩된 DB 비밀번호가 로그에 평문으로 나온다(로컬에서 확인).

### 검증 (로컬 `supabase start`)
```sql
begin;
set local role authenticated;
set local request.jwt.claims = '{"sub":"<A uuid>","role":"authenticated"}';
insert into public.attempts (id, scenario_id, grade, solved_on)
  values ('00000000-0000-4000-8000-000000000001', 'A-sidewalk~partner.right', 'best', '2026-10-25')
  on conflict (id) do nothing;                 -- 두 번 실행해도 오류 없음
select count(*) from public.attempts;          -- 1
rollback;
-- 아래 셋은 오류가 나면 트랜잭션이 중단되므로 한 줄씩 따로 실행한다.
-- update: 권한 오류 / delete: 권한 오류 / B의 claims로 select: 0행. day_completions도 같은 방식으로 확인한다.
```

## 고려한 대안
- `is_correct boolean`: `ok`와 `avoid`를 구분할 수 없어 XP를 계산하지 못한다.
- `attempts`에 `track`과 `day_id`를 넣어 연속 학습일을 추론: 콘텐츠 경로가 바뀌면 지난 판정도 바뀐다.
- 매번 전체를 받기: 무료 플랜 egress(월 5GB)를 사용자 수에 비례해 쓴다.
- 고유 키 `(user_id, scenario_id, solved_on)`: 같은 날 같은 문제를 다시 풀면 그 기록이 사라진다.
- 공개 리포에 암호화한 덤프를 올리기: 키 관리가 늘고, 공개 리포는 60일 동안 활동이 없으면 예약 실행이 꺼진다.

## 결과
- **쉬워지는 것**: 서버 코드도 동기화 코드도 함수 하나씩이다. 재시도는 언제 해도 안전하다. XP, 연속 학습일, 진행 위치를 모두 기록에서 계산한다.
- **어려워지는 것**: 사용자는 기록을 고칠 수 없다(고쳐야 하면 운영자가 service role로 한다). 계산은 기록 순서에 의존하면 안 된다. 리포가 두 개가 된다.
- **넣지 않은 것과 넣을 시점**
  - 시간대 컬럼(해외 이동 때문에 연속 학습일 오류가 신고되면), 사용자별 행 수 제한(비정상적인 대량 insert가 보이면), 백업 암호화(백업 리포 협업자가 운영자 밖으로 늘어나면).
  - 탈퇴 사용자 tombstone: 백업 복원 절차를 정할 때. 복원하면 그 뒤에 탈퇴한 사용자가 되살아나기 때문이다.
  - 웹 로그인 삭제 흐름: 수동 처리가 7일 기한을 한 번이라도 넘기거나, 수동 처리가 한 달에 10건을 넘을 때. 건당 처리 시간은 약 2분으로 본다.
- **다시 볼 조건**: iOS를 출시할 때(App Review 4.8에 따라 Google 로그인과 동등한 로그인이 필요하다), DB가 400MB에 가까워질 때.

## 열린 질문
없음. 운영 이메일, 처리 기한 7일, 웹 로그인 삭제 흐름을 넣을 기준은 2026-10-25에 정했다.

## 확인하지 못한 것
`ignore-duplicates`가 실제로 만드는 SQL, JWT 서명 키 종류에 따른 `getClaims` 동작, GitHub 호스티드 러너가 IPv4 전용인지(Session pooler를 고른 근거), data dump에 `auth` 데이터가 포함되는지, 결제 수단이 없을 때 아티팩트 한도를 넘기면 어떻게 되는지.

## 참고
- Supabase: [RLS](https://supabase.com/docs/guides/database/postgres/row-level-security), [cascade와 삭제 뒤 JWT](https://supabase.com/docs/guides/auth/managing-user-data), [deleteUser](https://supabase.com/docs/reference/javascript/auth-admin-deleteuser), [getClaims](https://supabase.com/docs/reference/javascript/auth-getclaims), [함수 인증](https://supabase.com/docs/guides/functions/auth), [함수 환경 변수](https://supabase.com/docs/guides/functions/secrets), [연결 방식](https://supabase.com/docs/guides/database/connecting-to-postgres), [백업 명령](https://supabase.com/docs/guides/platform/migrating-within-supabase/backup-restore), [요금](https://supabase.com/pricing)
- Postgres와 클라이언트: [ON CONFLICT와 RLS](https://www.postgresql.org/docs/current/sql-createpolicy.html), [Dart upsert](https://pub.dev/documentation/postgrest/latest/postgrest/PostgrestQueryBuilder/upsert.html)
- 법령: [개인정보 보호법 시행령](https://www.law.go.kr/법령/개인정보보호법시행령) 제43조 제3항(정정·삭제 요구는 10일 안에 처리)
- 스토어: [Google Play 계정 삭제](https://support.google.com/googleplay/android-developer/answer/13327111), [App Review 4.8](https://developer.apple.com/app-store/review/guidelines/)
- GitHub: [Actions 무료 한도](https://docs.github.com/en/billing/concepts/product-billing/github-actions), [아티팩트 권한](https://docs.github.com/en/actions/how-tos/manage-workflow-runs/download-workflow-artifacts), [예약 워크플로](https://docs.github.com/en/actions/reference/workflows-and-actions/events-that-trigger-workflows)

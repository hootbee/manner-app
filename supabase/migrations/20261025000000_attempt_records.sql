-- ADR 0001: append-only records, merged across devices by app-generated UUID.

create table public.attempts (
  id          uuid primary key,                                   -- app-generated UUID, idempotency key
  user_id     uuid not null default auth.uid() references auth.users (id) on delete cascade,
  scenario_id text not null check (char_length(scenario_id) between 1 and 100),
  grade       text not null check (grade in ('best', 'ok', 'avoid')),
  solved_on   date not null check (solved_on >= date '2026-01-01'), -- device date when answered
  created_at  timestamptz not null default now()                    -- pull cursor only
);
create index attempts_user_created_idx on public.attempts (user_id, created_at, id);

create table public.day_completions (
  id           uuid primary key,
  user_id      uuid not null default auth.uid() references auth.users (id) on delete cascade,
  day_id       text not null check (char_length(day_id) between 1 and 100),  -- content.json days[].id
  completed_on date not null check (completed_on >= date '2026-01-01'),     -- device date when finished
  created_at   timestamptz not null default now()
);
create index day_completions_user_created_idx on public.day_completions (user_id, created_at, id);

alter table public.attempts enable row level security;
revoke all on public.attempts from anon, authenticated;   -- default grants differ per project
grant select on public.attempts to authenticated;
grant insert (id, scenario_id, grade, solved_on) on public.attempts to authenticated;  -- user_id comes from the default
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
-- No update/delete policy or grant. Rows go away only via the auth.users cascade.

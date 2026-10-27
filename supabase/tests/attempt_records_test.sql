-- ADR 0001 §1·§2: append-only records, own rows only, cascade on user delete.
begin;
select plan(34);

insert into auth.users (id) values
  ('aaaaaaaa-0000-4000-8000-000000000000'),  -- A
  ('bbbbbbbb-0000-4000-8000-000000000000');  -- B

select ok((select relrowsecurity from pg_class where oid = 'public.attempts'::regclass), 'attempts: RLS on');
select ok((select relrowsecurity from pg_class where oid = 'public.day_completions'::regclass), 'day_completions: RLS on');

-- A
set local role authenticated;
set local request.jwt.claims = '{"sub":"aaaaaaaa-0000-4000-8000-000000000000","role":"authenticated"}';

select lives_ok($$ insert into public.attempts (id, scenario_id, grade, solved_on)
  values ('00000000-0000-4000-8000-000000000001', 'A-sidewalk~partner.right', 'best', '2026-10-25')
  on conflict (id) do nothing $$, 'attempts: A inserts own row');
select lives_ok($$ insert into public.attempts (id, scenario_id, grade, solved_on)
  values ('00000000-0000-4000-8000-000000000001', 'A-sidewalk~partner.right', 'best', '2026-10-25')
  on conflict (id) do nothing $$, 'attempts: same id again is no error');
select is((select count(*) from public.attempts), 1::bigint, 'attempts: one row');
select throws_ok($$ insert into public.attempts (id, user_id, scenario_id, grade, solved_on)
  values (gen_random_uuid(), 'bbbbbbbb-0000-4000-8000-000000000000', 's~k', 'best', '2026-10-25') $$,
  '42501', 'permission denied for table attempts', 'attempts: cannot set user_id');
select throws_ok($$ insert into public.attempts (id, scenario_id, grade, solved_on, created_at)
  values (gen_random_uuid(), 's~k', 'best', '2026-10-25', now()) $$, '42501', null, 'attempts: cannot set created_at');
select throws_ok($$ update public.attempts set grade = 'ok' $$, '42501', null, 'attempts: no update');
select throws_ok($$ delete from public.attempts $$, '42501', null, 'attempts: no delete');
select throws_ok($$ insert into public.attempts (id, scenario_id, grade, solved_on)
  values (gen_random_uuid(), 's~k', 'great', '2026-10-25') $$, '23514', null, 'attempts: bad grade');
-- ADR 0001 §1: no date range check. A wrong device clock must not block sync.
select lives_ok($$ insert into public.attempts (id, scenario_id, grade, solved_on)
  values (gen_random_uuid(), 's~k', 'best', '1970-01-01') $$, 'attempts: any device date is accepted');
select throws_ok($$ insert into public.attempts (id, scenario_id, grade, solved_on)
  values (gen_random_uuid(), '', 'best', '2026-10-25') $$, '23514', null, 'attempts: empty scenario_id');

select lives_ok($$ insert into public.day_completions (id, day_id, completed_on)
  values ('00000000-0000-4000-8000-000000000002', 'day-01', '2026-10-25')
  on conflict (id) do nothing $$, 'day_completions: A inserts own row');
select lives_ok($$ insert into public.day_completions (id, day_id, completed_on)
  values ('00000000-0000-4000-8000-000000000002', 'day-01', '2026-10-25')
  on conflict (id) do nothing $$, 'day_completions: same id again is no error');
select is((select count(*) from public.day_completions), 1::bigint, 'day_completions: one row');
select throws_ok($$ insert into public.day_completions (id, user_id, day_id, completed_on)
  values (gen_random_uuid(), 'bbbbbbbb-0000-4000-8000-000000000000', 'day-01', '2026-10-25') $$,
  '42501', 'permission denied for table day_completions', 'day_completions: cannot set user_id');
select throws_ok($$ insert into public.day_completions (id, day_id, completed_on, created_at)
  values (gen_random_uuid(), 'day-01', '2026-10-25', now()) $$, '42501', null, 'day_completions: cannot set created_at');
select throws_ok($$ update public.day_completions set day_id = 'day-02' $$, '42501', null, 'day_completions: no update');
select throws_ok($$ delete from public.day_completions $$, '42501', null, 'day_completions: no delete');
select lives_ok($$ insert into public.day_completions (id, day_id, completed_on)
  values (gen_random_uuid(), 'day-01', '1970-01-01') $$, 'day_completions: any device date is accepted');
select throws_ok($$ insert into public.day_completions (id, day_id, completed_on)
  values (gen_random_uuid(), '', '2026-10-25') $$, '23514', null, 'day_completions: empty day_id');

-- no sub: the insert policy rejects a null user_id
set local request.jwt.claims = '{"role":"authenticated"}';
select throws_ok($$ insert into public.attempts (id, scenario_id, grade, solved_on)
  values (gen_random_uuid(), 's~k', 'best', '2026-10-25') $$,
  '42501', 'new row violates row-level security policy for table "attempts"', 'attempts: insert policy needs uid');
select throws_ok($$ insert into public.day_completions (id, day_id, completed_on)
  values (gen_random_uuid(), 'day-01', '2026-10-25') $$,
  '42501', 'new row violates row-level security policy for table "day_completions"', 'day_completions: insert policy needs uid');

-- B
set local request.jwt.claims = '{"sub":"bbbbbbbb-0000-4000-8000-000000000000","role":"authenticated"}';
select lives_ok($$ insert into public.attempts (id, scenario_id, grade, solved_on)
  values ('00000000-0000-4000-8000-000000000001', 's~k', 'avoid', '2026-10-25')
  on conflict (id) do nothing $$, 'attempts: B reusing A''s id is ignored');
select throws_ok($$ insert into public.attempts (id, scenario_id, grade, solved_on)
  values ('00000000-0000-4000-8000-000000000001', 's~k', 'avoid', '2026-10-25')
  on conflict (id) do update set grade = 'avoid' $$, '42501', null, 'attempts: no do update');
select is((select count(*) from public.attempts), 0::bigint, 'attempts: B sees none of A');
select is((select count(*) from public.day_completions), 0::bigint, 'day_completions: B sees none of A');

-- anon
set local role anon;
select throws_ok($$ select * from public.attempts $$, '42501', null, 'attempts: anon cannot select');
select throws_ok($$ insert into public.attempts (id, scenario_id, grade, solved_on)
  values (gen_random_uuid(), 's~k', 'best', '2026-10-25') $$, '42501', null, 'attempts: anon cannot insert');
select throws_ok($$ select * from public.day_completions $$, '42501', null, 'day_completions: anon cannot select');
select throws_ok($$ insert into public.day_completions (id, day_id, completed_on)
  values (gen_random_uuid(), 'day-01', '2026-10-25') $$, '42501', null, 'day_completions: anon cannot insert');

-- delete A
reset role;
select is((select grade from public.attempts where id = '00000000-0000-4000-8000-000000000001'), 'best', 'attempts: A''s row unchanged by B');
delete from auth.users where id = 'aaaaaaaa-0000-4000-8000-000000000000';
select is((select count(*) from public.attempts), 0::bigint, 'attempts: cascade with user');
select is((select count(*) from public.day_completions), 0::bigint, 'day_completions: cascade with user');

select * from finish();
rollback;

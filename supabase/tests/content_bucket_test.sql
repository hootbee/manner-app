-- ADR 0003 §5: public `content` bucket, writes only via service role.
begin;
select plan(7);

select is((select public from storage.buckets where id = 'content'), true, 'content bucket exists and is public');
insert into storage.objects (bucket_id, name) values ('content', 's1/manifest.json');
set local storage.allow_delete_query = 'true';  -- skip storage.protect_delete so only RLS decides

set local role authenticated;
set local request.jwt.claims = '{"sub":"aaaaaaaa-0000-4000-8000-000000000000","role":"authenticated"}';
select throws_ok($$ insert into storage.objects (bucket_id, name) values ('content', 's1/12.json') $$,
  '42501', null, 'authenticated cannot upload');
select is_empty($$ update storage.objects set name = 'x' where bucket_id = 'content' returning 1 $$, 'authenticated cannot update');
select is_empty($$ delete from storage.objects where bucket_id = 'content' returning 1 $$, 'authenticated cannot delete');

set local role anon;
select throws_ok($$ insert into storage.objects (bucket_id, name) values ('content', 's1/12.json') $$,
  '42501', null, 'anon cannot upload');
select is_empty($$ update storage.objects set name = 'x' where bucket_id = 'content' returning 1 $$, 'anon cannot update');
select is_empty($$ delete from storage.objects where bucket_id = 'content' returning 1 $$, 'anon cannot delete');

select * from finish();
rollback;

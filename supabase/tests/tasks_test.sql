-- Tasks (#375): a title, note, day and optional done date. Each one is about
-- nothing specific: a task has no person, no event. Kept after done.
-- Run with `supabase test db`.
begin;
create extension if not exists pgtap with schema extensions;
select plan(8);

insert into auth.users (id, email) values
  ('00000000-0000-0000-0000-00000000000a', 'a@example.com'),
  ('00000000-0000-0000-0000-00000000000b', 'b@example.com');

set local role authenticated;
set local request.jwt.claims =
  '{"sub": "00000000-0000-0000-0000-00000000000a", "role": "authenticated"}';

select lives_ok(
  $$ insert into public.task (id, title, due_on) values
     ('00000000-0000-0000-0000-0000000000d1', 'Order flyers', '2026-10-20') $$,
  'a task saves'
);
select is(
  (select owner_id from public.task
    where id = '00000000-0000-0000-0000-0000000000d1'),
  '00000000-0000-0000-0000-00000000000a'::uuid,
  'owner defaults to the user'
);
select throws_ok(
  $$ insert into public.task (title, due_on) values ('  ', '2026-10-20') $$,
  '23514', null,
  'a blank title is refused'
);

select lives_ok(
  $$ update public.task set title = 'Restock lavender', note = 'Check stock first',
     due_on = '2026-10-21', done_on = '2026-10-09'
     where id = '00000000-0000-0000-0000-0000000000d1' $$,
  'update (title, note, due_on, done_on) allowed'
);
select throws_ok(
  $$ update public.task set owner_id = '00000000-0000-0000-0000-00000000000b'
     where id = '00000000-0000-0000-0000-0000000000d1' $$,
  '42501', null,
  'update owner_id refused'
);

set local request.jwt.claims =
  '{"sub": "00000000-0000-0000-0000-00000000000b", "role": "authenticated"}';
select is(
  (select count(*)::int from public.task), 0,
  'user B selects none of A''s'
);
update public.task set title = 'Mine now'
  where id = '00000000-0000-0000-0000-0000000000d1';
delete from public.task
  where id = '00000000-0000-0000-0000-0000000000d1';

set local role anon;
select throws_ok(
  $$ select * from public.task $$,
  '42501', null,
  'anon selects nothing'
);

set local role authenticated;
set local request.jwt.claims =
  '{"sub": "00000000-0000-0000-0000-00000000000a", "role": "authenticated"}';
select is(
  (select title from public.task
    where id = '00000000-0000-0000-0000-0000000000d1'),
  'Restock lavender'::text,
  'A''s update persisted'
);

select * from finish();
rollback;

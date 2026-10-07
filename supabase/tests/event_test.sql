-- Events (#151): the calendar's table, scoped to its owner. Run with
-- `supabase test db`.
begin;
create extension if not exists pgtap with schema extensions;
select plan(8);

insert into auth.users (id, email) values
  ('00000000-0000-0000-0000-00000000000a', 'a@example.com'),
  ('00000000-0000-0000-0000-00000000000b', 'b@example.com');

set local role authenticated;
set local request.jwt.claims =
  '{"sub": "00000000-0000-0000-0000-00000000000a", "role": "authenticated"}';

-- 1-2: a full event saves, owned by whoever wrote it.
select lives_ok(
  $$ insert into public.event
       (id, title, starts_at, ends_at, place, link, notes)
     values ('00000000-0000-0000-0000-0000000000e1', 'Workshop',
       '2026-10-08 17:00+00', '2026-10-08 19:00+00', 'Studio Lumière',
       'https://meet.google.com/abc', 'Bring the diffuser') $$,
  'an event saves'
);
select is(
  (select owner_id from public.event
    where id = '00000000-0000-0000-0000-0000000000e1'),
  '00000000-0000-0000-0000-00000000000a'::uuid,
  'owner_id defaults to the author'
);

-- 3-5: constraints.
select throws_ok(
  $$ insert into public.event (title, starts_at) values ('  ', now()) $$,
  '23514', null,
  'a title is not blank'
);
select throws_ok(
  $$ insert into public.event (title, starts_at, ends_at)
     values ('Call', '2026-10-08 17:00+00', '2026-10-08 16:00+00') $$,
  '23514', null,
  'an event ends after it starts'
);
select throws_ok(
  $$ insert into public.event (title, starts_at, link)
     values ('Call', now(), 'javascript:alert(1)') $$,
  '23514', null,
  'a link is a web address'
);

-- 6-7: as B.
set local request.jwt.claims =
  '{"sub": "00000000-0000-0000-0000-00000000000b", "role": "authenticated"}';
select is(
  (select count(*)::int from public.event), 0,
  'another user sees none of them'
);
update public.event set title = 'Taken';
delete from public.event;
select throws_ok(
  $$ insert into public.event (owner_id, title, starts_at)
     values ('00000000-0000-0000-0000-00000000000a', 'Planted', now()) $$,
  '42501', null,
  'another user cannot add an event for the owner'
);

-- 8: back as A, nothing moved.
set local request.jwt.claims =
  '{"sub": "00000000-0000-0000-0000-00000000000a", "role": "authenticated"}';
select is(
  (select title from public.event), 'Workshop',
  'another user can neither update nor delete it'
);

select * from finish();
rollback;

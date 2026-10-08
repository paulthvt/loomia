-- Reminders (#217): a line of text for one person, due on a day, outside any
-- workflow. Ticking one leaves a history entry and deletes it.
-- Run with `supabase test db`.
begin;
create extension if not exists pgtap with schema extensions;
select plan(10);

insert into auth.users (id, email) values
  ('00000000-0000-0000-0000-00000000000a', 'a@example.com'),
  ('00000000-0000-0000-0000-00000000000b', 'b@example.com');

set local role authenticated;
set local request.jwt.claims =
  '{"sub": "00000000-0000-0000-0000-00000000000a", "role": "authenticated"}';

insert into public.person (id, name, stage) values
  ('00000000-0000-0000-0000-0000000000a1', 'Claire', 'prospect');

select lives_ok(
  $$ insert into public.reminder (id, person_id, text, due_on) values
     ('00000000-0000-0000-0000-0000000000c1',
      '00000000-0000-0000-0000-0000000000a1', 'Call back', '2026-10-15') $$,
  'a reminder saves'
);
select throws_ok(
  $$ insert into public.reminder (person_id, text, due_on) values
     ('00000000-0000-0000-0000-0000000000a1', '  ', '2026-10-15') $$,
  '23514', null,
  'a blank reminder is refused'
);
select is(
  (select due_on from public.reminder
    where id = '00000000-0000-0000-0000-0000000000c1'),
  '2026-10-15'::date,
  'its day reads back'
);

select public.complete_reminder(
  '00000000-0000-0000-0000-0000000000c1', '2026-10-09');
select results_eq(
  $$ select kind::text, text, happened_on from public.activity
     where person_id = '00000000-0000-0000-0000-0000000000a1' $$,
  $$ values ('reminder'::text, 'Call back'::text, '2026-10-09'::date) $$,
  'ticking writes one reminder entry with its text, on the day ticked'
);
select is(
  (select count(*)::int from public.reminder), 0,
  'and deletes the reminder'
);
select is(
  (select public.last_contact_on(p) from public.person p
    where id = '00000000-0000-0000-0000-0000000000a1'),
  '2026-10-09'::date,
  'it counts as contact'
);
select throws_ok(
  $$ select public.complete_reminder(
     '00000000-0000-0000-0000-0000000000c1', '2026-10-09') $$,
  'P0002', null,
  'a reminder already ticked (another device) is refused'
);

insert into public.reminder (id, person_id, text, due_on) values
  ('00000000-0000-0000-0000-0000000000c2',
   '00000000-0000-0000-0000-0000000000a1', 'Price list', '2026-10-20');

set local request.jwt.claims =
  '{"sub": "00000000-0000-0000-0000-00000000000b", "role": "authenticated"}';
select is(
  (select count(*)::int from public.reminder), 0,
  'another owner sees none'
);
select throws_ok(
  $$ insert into public.reminder (person_id, text, due_on) values
     ('00000000-0000-0000-0000-0000000000a1', 'Mine now', '2026-10-15') $$,
  '23503', null,
  'nor adds one on someone else''s person'
);
select throws_ok(
  $$ select public.complete_reminder(
     '00000000-0000-0000-0000-0000000000c2', '2026-10-09') $$,
  'P0002', null,
  'nor ticks theirs'
);

select * from finish();
rollback;

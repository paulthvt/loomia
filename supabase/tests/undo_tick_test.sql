-- Undo a tick (#372): each reverse leaves the person, the reminder and the
-- history as before the tick, and refuses once the person changed since.
-- One transaction, so every now() here is the same: the tests pass the
-- person's updated_at as read after each tick, and a stale one by hand.
-- Run with `supabase test db`.
begin;
create extension if not exists pgtap with schema extensions;
select plan(17);

insert into auth.users (id, email) values
  ('00000000-0000-0000-0000-00000000000a', 'a@example.com'),
  ('00000000-0000-0000-0000-00000000000b', 'b@example.com');

set local role authenticated;
set local request.jwt.claims =
  '{"sub": "00000000-0000-0000-0000-00000000000a", "role": "authenticated"}';

insert into public.workflow (id, stage, name) values
  ('00000000-0000-0000-0000-0000000000f1', 'customer', 'New customer');
insert into public.workflow_step (id, workflow_id, position, label, days, loyalty_setup) values
  ('00000000-0000-0000-0000-0000000000e1',
   '00000000-0000-0000-0000-0000000000f1', 1, 'Welcome call', 0, false),
  ('00000000-0000-0000-0000-0000000000e2',
   '00000000-0000-0000-0000-0000000000f1', 2, 'Set up their LRP', 7, true);
insert into public.person (id, name, stage, workflow_id, at_position, last_tick) values
  ('00000000-0000-0000-0000-0000000000a1', 'Claire', 'customer',
   '00000000-0000-0000-0000-0000000000f1', 1, '2026-10-01'),
  ('00000000-0000-0000-0000-0000000000a2', 'Julie', 'customer',
   '00000000-0000-0000-0000-0000000000f1', 2, '2026-10-01');
insert into public.person (id, name, stage, loyalty_since, loyalty_day) values
  ('00000000-0000-0000-0000-0000000000a3', 'Sarah', 'customer', '2026-01-15', 15),
  ('00000000-0000-0000-0000-0000000000a4', 'Léa', 'prospect', null, null);
insert into public.reminder (id, person_id, text, due_on, created_at) values
  ('00000000-0000-0000-0000-0000000000d1', '00000000-0000-0000-0000-0000000000a4',
   'Call back about the diffuser', '2026-10-20', '2026-10-10 09:00:00.123456+00');

-- A plain step.
select public.complete_step(
  '00000000-0000-0000-0000-0000000000a1',
  '00000000-0000-0000-0000-0000000000e1', '2026-10-24');
select throws_ok(
  $$ select public.undo_step(
       '00000000-0000-0000-0000-0000000000a1',
       '00000000-0000-0000-0000-0000000000e1', '2026-10-24', '2026-10-01',
       '2000-01-01') $$,
  'P0002', null,
  'a step undo is refused once the person changed'
);
select is(
  (select count(*)::int from public.activity
    where person_id = '00000000-0000-0000-0000-0000000000a1'),
  1,
  'a refused undo changes nothing'
);
select lives_ok(
  $$ select public.undo_step(
       '00000000-0000-0000-0000-0000000000a1',
       '00000000-0000-0000-0000-0000000000e1', '2026-10-24', '2026-10-01',
       (select updated_at from public.person
         where id = '00000000-0000-0000-0000-0000000000a1')) $$,
  'a step tick undoes'
);
select is(
  (select (at_position, last_tick)::text from public.person
    where id = '00000000-0000-0000-0000-0000000000a1'),
  '(1,2026-10-01)',
  'the step and its due day are back'
);
select is(
  (select count(*)::int from public.activity
    where person_id = '00000000-0000-0000-0000-0000000000a1'),
  0,
  'the step entry is gone'
);
select throws_ok(
  $$ select public.undo_step(
       '00000000-0000-0000-0000-0000000000a1',
       '00000000-0000-0000-0000-0000000000e1', '2026-10-24', '2026-10-01',
       (select updated_at from public.person
         where id = '00000000-0000-0000-0000-0000000000a1')) $$,
  'P0002', null,
  'the same undo twice is refused'
);

-- A loyalty step starts the LRP; its undo stops it.
select public.complete_step(
  '00000000-0000-0000-0000-0000000000a2',
  '00000000-0000-0000-0000-0000000000e2', '2026-10-24');
select public.undo_step(
  '00000000-0000-0000-0000-0000000000a2',
  '00000000-0000-0000-0000-0000000000e2', '2026-10-24', '2026-10-01',
  (select updated_at from public.person
    where id = '00000000-0000-0000-0000-0000000000a2'));
select is(
  (select (loyalty_since, loyalty_day, loyalty_checked_for)::text
    from public.person where id = '00000000-0000-0000-0000-0000000000a2'),
  '(,,)',
  'the LRP the step started is stopped'
);
select is(
  (select count(*)::int from public.activity
    where person_id = '00000000-0000-0000-0000-0000000000a2'),
  0,
  'its LRP started entry is gone with the step entry'
);

-- Another owner.
select public.complete_step(
  '00000000-0000-0000-0000-0000000000a1',
  '00000000-0000-0000-0000-0000000000e1', '2026-10-24');
set local request.jwt.claims =
  '{"sub": "00000000-0000-0000-0000-00000000000b", "role": "authenticated"}';
select throws_ok(
  $$ select public.undo_step(
       '00000000-0000-0000-0000-0000000000a1',
       '00000000-0000-0000-0000-0000000000e1', '2026-10-24', '2026-10-01',
       now()) $$,
  'P0002', null,
  'another owner cannot undo the tick'
);
set local request.jwt.claims =
  '{"sub": "00000000-0000-0000-0000-00000000000a", "role": "authenticated"}';

-- A reminder.
select public.complete_reminder('00000000-0000-0000-0000-0000000000d1', '2026-10-24');
select lives_ok(
  $$ select public.undo_reminder(
       '00000000-0000-0000-0000-0000000000d1',
       '00000000-0000-0000-0000-0000000000a4',
       'Call back about the diffuser', '2026-10-20',
       '2026-10-10 09:00:00.123456+00', '2026-10-24',
       (select updated_at from public.person
         where id = '00000000-0000-0000-0000-0000000000a4')) $$,
  'a reminder tick undoes'
);
select is(
  (select (text, due_on, created_at = '2026-10-10 09:00:00.123456+00')::text
    from public.reminder where id = '00000000-0000-0000-0000-0000000000d1'),
  '("Call back about the diffuser",2026-10-20,t)',
  'the reminder is back as it was'
);
select is(
  (select count(*)::int from public.activity
    where person_id = '00000000-0000-0000-0000-0000000000a4'),
  0,
  'the reminder entry is gone'
);
select throws_ok(
  $$ select public.undo_reminder(
       '00000000-0000-0000-0000-0000000000d1',
       '00000000-0000-0000-0000-0000000000a4',
       'Call back about the diffuser', '2026-10-20',
       '2026-10-10 09:00:00.123456+00', '2026-10-24',
       (select updated_at from public.person
         where id = '00000000-0000-0000-0000-0000000000a4')) $$,
  'P0002', null,
  'a reminder that is back already is refused'
);

-- An LRP renewal check.
select public.check_loyalty(
  '00000000-0000-0000-0000-0000000000a3', '2026-10-15', '2026-10-24',
  'Checked in about the LRP');
select throws_ok(
  $$ select public.undo_loyalty_check(
       '00000000-0000-0000-0000-0000000000a3', '2026-10-15', null, '2000-01-01') $$,
  'P0002', null,
  'an LRP check undo is refused once the person changed'
);
select public.undo_loyalty_check(
  '00000000-0000-0000-0000-0000000000a3', '2026-10-15', null,
  (select updated_at from public.person
    where id = '00000000-0000-0000-0000-0000000000a3'));
select is(
  (select loyalty_checked_for from public.person
    where id = '00000000-0000-0000-0000-0000000000a3'),
  null,
  'the renewal is unchecked again'
);
select is(
  (select count(*)::int from public.activity
    where person_id = '00000000-0000-0000-0000-0000000000a3'),
  0,
  'the check entry is gone'
);

-- A deleted person: stale, not a foreign-key error.
select public.complete_reminder('00000000-0000-0000-0000-0000000000d1', '2026-10-24');
delete from public.person where id = '00000000-0000-0000-0000-0000000000a4';
select throws_ok(
  $$ select public.undo_reminder(
       '00000000-0000-0000-0000-0000000000d1',
       '00000000-0000-0000-0000-0000000000a4',
       'Call back about the diffuser', '2026-10-20',
       '2026-10-10 09:00:00.123456+00', '2026-10-24', now()) $$,
  'P0002', null,
  'undo for a deleted person is refused as stale'
);

select * from finish();
rollback;

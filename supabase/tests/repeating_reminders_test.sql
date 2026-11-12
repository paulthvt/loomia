-- Repeating reminders (#486): complete_reminder writes the entry and moves
-- a repeating reminder to its next day, skip_reminder moves it without an
-- entry, undo_repeating_reminder puts it back as it was. Run with
-- `supabase test db`.
begin;
create extension if not exists pgtap with schema extensions;
select plan(28);

insert into auth.users (id, email) values
  ('00000000-0000-0000-0000-00000000000a', 'a@example.com'),
  ('00000000-0000-0000-0000-00000000000b', 'b@example.com');

set local role authenticated;
set local request.jwt.claims =
  '{"sub": "00000000-0000-0000-0000-00000000000a", "role": "authenticated"}';

insert into public.person (id, name, stage) values
  ('00000000-0000-0000-0000-0000000000a1', 'Claire', 'prospect');

-- The reminder [p_id], or null.
create function pg_temp.r(p_id uuid) returns public.reminder
language sql as $$ select * from public.reminder where id = p_id $$;

-- How many reminder entries Claire's history has.
create function pg_temp.entries() returns int
language sql as $$
  select count(*)::int from public.activity
    where person_id = '00000000-0000-0000-0000-0000000000a1'
      and kind = 'reminder'
$$;

-- Month end: counted from repeat_from, so Feb clamps and Mar goes back.
insert into public.reminder
  (id, person_id, text, due_on, repeat_every, repeat_unit, repeat_from, scheduled_on)
values
  ('00000000-0000-0000-0000-0000000000d1', '00000000-0000-0000-0000-0000000000a1',
   'Call about the order', '2027-01-31', 1, 'month', '2027-01-31', '2027-01-31');
select public.complete_reminder('00000000-0000-0000-0000-0000000000d1', '2027-01-31');
select is(
  (select (due_on, scheduled_on)::text
    from pg_temp.r('00000000-0000-0000-0000-0000000000d1')),
  '(2027-02-28,2027-02-28)',
  'Jan 31 monthly: the same reminder moves to Feb 28'
);
select is(
  (select happened_on from public.activity
    where person_id = '00000000-0000-0000-0000-0000000000a1'
      and text = 'Call about the order'),
  '2027-01-31'::date,
  'the tick writes the entry on the day it is ticked'
);
select public.complete_reminder('00000000-0000-0000-0000-0000000000d1', '2027-02-28');
select is(
  (pg_temp.r('00000000-0000-0000-0000-0000000000d1')).due_on,
  '2027-03-31'::date,
  'after Feb 28, back to the 31st'
);

-- Postponed: due the 5th, scheduled the 3rd; the next is still the 3rd.
insert into public.reminder
  (id, person_id, text, due_on, repeat_every, repeat_unit, repeat_from, scheduled_on)
values
  ('00000000-0000-0000-0000-0000000000d2', '00000000-0000-0000-0000-0000000000a1',
   'Ask how the oils go', '2027-02-05', 1, 'month', '2027-01-03', '2027-02-03');
select public.complete_reminder('00000000-0000-0000-0000-0000000000d2', '2027-02-05');
select is(
  (pg_temp.r('00000000-0000-0000-0000-0000000000d2')).due_on,
  '2027-03-03'::date,
  'a postponed reminder keeps the schedule'
);

-- Late: March's, ticked April 10, skips April.
insert into public.reminder
  (id, person_id, text, due_on, repeat_every, repeat_unit, repeat_from, scheduled_on)
values
  ('00000000-0000-0000-0000-0000000000d3', '00000000-0000-0000-0000-0000000000a1',
   'Send the catalogue', '2027-03-03', 1, 'month', '2027-03-03', '2027-03-03');
select public.complete_reminder('00000000-0000-0000-0000-0000000000d3', '2027-04-10');
select is(
  (pg_temp.r('00000000-0000-0000-0000-0000000000d3')).due_on,
  '2027-05-03'::date,
  'a late tick skips the dates it missed'
);
select is(
  (pg_temp.r('00000000-0000-0000-0000-0000000000d3')).repeat_from,
  '2027-03-03'::date,
  'the rule is kept'
);

-- The end: weekly until Feb 15, ticked on Feb 10: the next is past it.
insert into public.reminder
  (id, person_id, text, due_on, created_at, repeat_every, repeat_unit,
   repeat_from, repeat_until, scheduled_on)
values
  ('00000000-0000-0000-0000-0000000000d4', '00000000-0000-0000-0000-0000000000a1',
   'Check the trial', '2027-02-10', '2027-02-01 09:00:00.123456+00', 1, 'week',
   '2027-02-10', '2027-02-15', '2027-02-10');
select public.complete_reminder('00000000-0000-0000-0000-0000000000d4', '2027-02-10');
select ok(
  (pg_temp.r('00000000-0000-0000-0000-0000000000d4')).id is null,
  'past the end, the tick deletes the reminder'
);
select is(
  (select count(*)::int from public.activity where text = 'Check the trial'),
  1,
  'and still writes the entry'
);

-- Undo of the tick that ended it: back with its id and rule.
select lives_ok(
  $$ select public.undo_repeating_reminder(
       '00000000-0000-0000-0000-0000000000d4',
       '00000000-0000-0000-0000-0000000000a1',
       'Check the trial', '2027-02-10', '2027-02-01 09:00:00.123456+00',
       1, 'week', '2027-02-10', '2027-02-15', '2027-02-10', '2027-02-10',
       (select updated_at from public.person
         where id = '00000000-0000-0000-0000-0000000000a1')) $$,
  'the last tick undoes'
);
select is(
  (select (due_on, scheduled_on, repeat_every, repeat_unit, repeat_from,
           repeat_until, created_at = '2027-02-01 09:00:00.123456+00')::text
    from pg_temp.r('00000000-0000-0000-0000-0000000000d4')),
  '(2027-02-10,2027-02-10,1,week,2027-02-10,2027-02-15,t)',
  'the reminder is back with its rule'
);
select is(
  (select count(*)::int from public.activity where text = 'Check the trial'),
  0,
  'its entry is gone'
);

-- Plain reminder: the tick deletes it, as before.
insert into public.reminder (id, person_id, text, due_on) values
  ('00000000-0000-0000-0000-0000000000d5', '00000000-0000-0000-0000-0000000000a1',
   'Price list', '2027-02-10');
select public.complete_reminder('00000000-0000-0000-0000-0000000000d5', '2027-02-10');
select ok(
  (pg_temp.r('00000000-0000-0000-0000-0000000000d5')).id is null,
  'a plain reminder goes once ticked'
);

-- Undo after a roll: back on its day and schedule.
insert into public.reminder
  (id, person_id, text, due_on, created_at, repeat_every, repeat_unit,
   repeat_from, scheduled_on)
values
  ('00000000-0000-0000-0000-0000000000d6', '00000000-0000-0000-0000-0000000000a1',
   'Water the samples', '2027-02-12', '2027-02-01 09:00:00+00', 2, 'week',
   '2027-01-01', '2027-02-12');
select public.complete_reminder('00000000-0000-0000-0000-0000000000d6', '2027-02-14');
select is(
  (pg_temp.r('00000000-0000-0000-0000-0000000000d6')).due_on,
  '2027-02-26'::date,
  'every 2 weeks: the next on the schedule'
);
select lives_ok(
  $$ select public.undo_repeating_reminder(
       '00000000-0000-0000-0000-0000000000d6',
       '00000000-0000-0000-0000-0000000000a1',
       'Water the samples', '2027-02-12', '2027-02-01 09:00:00+00',
       2, 'week', '2027-01-01', null, '2027-02-12', '2027-02-14',
       (select updated_at from public.person
         where id = '00000000-0000-0000-0000-0000000000a1')) $$,
  'a rolled tick undoes'
);
select is(
  (select (due_on, scheduled_on)::text
    from pg_temp.r('00000000-0000-0000-0000-0000000000d6')),
  '(2027-02-12,2027-02-12)',
  'back on its day'
);
select is(
  (select count(*)::int from public.activity where text = 'Water the samples'),
  0,
  'the rolled tick''s entry is gone'
);

-- Edited after the tick: the undo is refused, the entry stays.
select public.complete_reminder('00000000-0000-0000-0000-0000000000d6', '2027-02-14');
update public.reminder set text = 'Water the samples twice'
  where id = '00000000-0000-0000-0000-0000000000d6';
select throws_ok(
  $$ select public.undo_repeating_reminder(
       '00000000-0000-0000-0000-0000000000d6',
       '00000000-0000-0000-0000-0000000000a1',
       'Water the samples', '2027-02-12', '2027-02-01 09:00:00+00',
       2, 'week', '2027-01-01', null, '2027-02-12', '2027-02-14',
       (select updated_at from public.person
         where id = '00000000-0000-0000-0000-0000000000a1')) $$,
  'P0002', null,
  'an edit since the tick refuses the undo'
);
select is(
  (select count(*)::int from public.activity where text = 'Water the samples'),
  1,
  'the entry is kept'
);

-- Postponed since the tick (an old build's edit): refused too.
update public.reminder set text = 'Water the samples', due_on = '2027-02-27'
  where id = '00000000-0000-0000-0000-0000000000d6';
select throws_ok(
  $$ select public.undo_repeating_reminder(
       '00000000-0000-0000-0000-0000000000d6',
       '00000000-0000-0000-0000-0000000000a1',
       'Water the samples', '2027-02-12', '2027-02-01 09:00:00+00',
       2, 'week', '2027-01-01', null, '2027-02-12', '2027-02-14',
       (select updated_at from public.person
         where id = '00000000-0000-0000-0000-0000000000a1')) $$,
  'P0002', null,
  'a postpone since the tick refuses the undo'
);
select is(
  (select (scheduled_on, repeat_unit)::text
    from pg_temp.r('00000000-0000-0000-0000-0000000000d6')),
  '(2027-02-26,week)',
  'an edit of the text and day keeps the rule'
);

-- Skip: the next day, no entry.
select public.skip_reminder('00000000-0000-0000-0000-0000000000d2', '2027-03-01');
select is(
  (pg_temp.r('00000000-0000-0000-0000-0000000000d2')).due_on,
  '2027-04-03'::date,
  'skipping moves it to the next day'
);
select is(
  (select count(*)::int from public.activity where text = 'Ask how the oils go'),
  1,
  'skipping writes no entry'
);
insert into public.reminder
  (id, person_id, text, due_on, repeat_every, repeat_unit, repeat_from,
   repeat_until, scheduled_on)
values
  ('00000000-0000-0000-0000-0000000000d7', '00000000-0000-0000-0000-0000000000a1',
   'Last one', '2027-02-10', 1, 'week', '2027-02-10', '2027-02-10', '2027-02-10');
select public.skip_reminder('00000000-0000-0000-0000-0000000000d7', '2027-02-10');
select ok(
  (pg_temp.r('00000000-0000-0000-0000-0000000000d7')).id is null,
  'skipping the last one deletes it'
);
insert into public.reminder (id, person_id, text, due_on) values
  ('00000000-0000-0000-0000-0000000000d8', '00000000-0000-0000-0000-0000000000a1',
   'Plain', '2027-02-10');
select throws_ok(
  $$ select public.skip_reminder('00000000-0000-0000-0000-0000000000d8', '2027-02-10') $$,
  'P0002', null,
  'a plain reminder cannot be skipped'
);

-- The rule is whole.
select throws_ok(
  $$ insert into public.reminder (person_id, text, due_on, repeat_every)
     values ('00000000-0000-0000-0000-0000000000a1', 'Half', '2027-02-10', 1) $$,
  '23514', null,
  'a repeat without its unit is refused'
);

-- Another owner's.
set local request.jwt.claims =
  '{"sub": "00000000-0000-0000-0000-00000000000b", "role": "authenticated"}';
select throws_ok(
  $$ select public.complete_reminder('00000000-0000-0000-0000-0000000000d2', '2027-03-01') $$,
  'P0002', null,
  'another owner cannot tick it'
);
select throws_ok(
  $$ select public.skip_reminder('00000000-0000-0000-0000-0000000000d2', '2027-03-01') $$,
  'P0002', null,
  'another owner cannot skip it'
);
select throws_ok(
  $$ select public.undo_repeating_reminder(
       '00000000-0000-0000-0000-0000000000d4',
       '00000000-0000-0000-0000-0000000000a1',
       'Check the trial', '2027-02-10', '2027-02-01 09:00:00.123456+00',
       1, 'week', '2027-02-10', '2027-02-15', '2027-02-10', '2027-02-10',
       now()) $$,
  'P0002', null,
  'another owner cannot undo it'
);

select * from finish();
rollback;

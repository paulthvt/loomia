-- A time on a task (#377): claim_task_alerts claims an open task's push in
-- [time, time + 1 h) of its owner's wall clock, once per day and time; a new
-- time re-arms it. The summary counts tasks too. Run with `supabase test db`.
begin;
create extension if not exists pgtap with schema extensions;
select plan(26);

insert into auth.users (id, email) values
  ('00000000-0000-0000-0000-00000000000a', 'a@example.com'),
  ('00000000-0000-0000-0000-00000000000b', 'b@example.com'),
  ('00000000-0000-0000-0000-00000000000c', 'c@example.com');

-- A in Paris, B in New York, C with no settings row.
insert into public.notification_settings (owner_id, time_zone) values
  ('00000000-0000-0000-0000-00000000000a', 'Europe/Paris'),
  ('00000000-0000-0000-0000-00000000000b', 'America/New_York');

insert into public.task (id, owner_id, title, note, due_on, due_time) values
  ('00000000-0000-0000-0000-0000000000e1',
   '00000000-0000-0000-0000-00000000000a', 'Call the supplier',
   'Ask about the 10 ml bottles', '2026-10-27', '14:00'),
  ('00000000-0000-0000-0000-0000000000e2',
   '00000000-0000-0000-0000-00000000000b', 'New York call', null,
   '2026-10-27', '14:00'),
  ('00000000-0000-0000-0000-0000000000e3',
   '00000000-0000-0000-0000-00000000000c', 'No zone', null,
   '2026-10-27', '14:00'),
  ('00000000-0000-0000-0000-0000000000e4',
   '00000000-0000-0000-0000-00000000000a', 'No time', null,
   '2026-10-27', null),
  ('00000000-0000-0000-0000-0000000000e5',
   '00000000-0000-0000-0000-00000000000a', 'Done', null,
   '2026-10-27', '14:00');
update public.task set done_on = '2026-10-27'
  where id = '00000000-0000-0000-0000-0000000000e5';

-- Paris is UTC+1 on Oct 27 2026 (after the switch back), New York UTC-4.
create function pg_temp.claimed(p_now timestamptz) returns setof uuid
language sql as $$ select task_id from public.claim_task_alerts(p_now) $$;

select is(
  (select count(*)::int from pg_temp.claimed('2026-10-27 12:59:59+00')), 0,
  '13:59:59 in Paris: not yet'
);
select results_eq(
  $$ select title, note, alerted_for
     from public.claim_task_alerts('2026-10-27 13:00:30+00') $$,
  $$ values ('Call the supplier', 'Ask about the 10 ml bottles',
             '2026-10-27 14:00'::timestamp) $$,
  '14:00:30 in Paris: claimed, with its title, note and time'
);
select is(
  (select count(*)::int from pg_temp.claimed('2026-10-27 13:01:00+00')), 0,
  'claimed once'
);
select is(
  (select alerted_for from public.task
    where id = '00000000-0000-0000-0000-0000000000e1'),
  '2026-10-27 14:00'::timestamp,
  'alerted_for set'
);

-- New York's 14:00 is 18:00 UTC; the task without a zone never goes. Its
-- timestamps aged first (not an edit: set_updated_at skips them), so a
-- claim that counted as an edit would show.
update public.task
  set created_at = created_at - interval '1 minute',
      updated_at = updated_at - interval '1 minute'
  where id = '00000000-0000-0000-0000-0000000000e2';
select is(
  (select count(*)::int from pg_temp.claimed('2026-10-27 17:59:00+00')), 0,
  'New York, 13:59: not yet'
);
select results_eq(
  $$ select * from pg_temp.claimed('2026-10-27 18:00:00+00') $$,
  $$ values ('00000000-0000-0000-0000-0000000000e2'::uuid) $$,
  'New York, 14:00: its own zone; no settings row, no push; done and untimed never'
);
select is(
  (select updated_at = created_at from public.task
    where id = '00000000-0000-0000-0000-0000000000e2'),
  true,
  'a claim is not an edit: updated_at stays'
);

-- The window's other edge: 14:59 yes, 15:00 never.
update public.task set alerted_for = null
  where id = '00000000-0000-0000-0000-0000000000e1';
select is(
  (select count(*)::int from pg_temp.claimed('2026-10-27 14:00:00+00')), 0,
  '15:00: an hour late, never sent'
);
select results_eq(
  $$ select * from pg_temp.claimed('2026-10-27 13:59:59+00') $$,
  $$ values ('00000000-0000-0000-0000-0000000000e1'::uuid) $$,
  '14:59: still sent'
);

-- Release: only the claim it was given.
select lives_ok(
  $$ select public.release_task_alert(
       '00000000-0000-0000-0000-0000000000e1', '2026-10-27 13:00') $$,
  'release with another time'
);
select isnt(
  (select alerted_for from public.task
    where id = '00000000-0000-0000-0000-0000000000e1'),
  null,
  'a release for another time clears nothing'
);
select public.release_task_alert(
  '00000000-0000-0000-0000-0000000000e1', '2026-10-27 14:00');
select is(
  (select alerted_for from public.task
    where id = '00000000-0000-0000-0000-0000000000e1'),
  null,
  'its own release clears it, so the next minute retries'
);

-- A new time re-arms; an edit to the title doesn't.
select pg_temp.claimed('2026-10-27 13:10:00+00');
update public.task set title = 'Call the supplier back'
  where id = '00000000-0000-0000-0000-0000000000e1';
select isnt(
  (select alerted_for from public.task
    where id = '00000000-0000-0000-0000-0000000000e1'),
  null,
  'a new title keeps the claim'
);
update public.task set due_time = '14:15'
  where id = '00000000-0000-0000-0000-0000000000e1';
select is(
  (select alerted_for from public.task
    where id = '00000000-0000-0000-0000-0000000000e1'),
  null,
  'a new time clears it'
);
select results_eq(
  $$ select * from pg_temp.claimed('2026-10-27 13:15:00+00') $$,
  $$ values ('00000000-0000-0000-0000-0000000000e1'::uuid) $$,
  'and pushes at the new time'
);

-- Spring forward: 02:30 doesn't exist on Mar 28 2027 in Paris; sent at 03:00.
insert into public.task (id, owner_id, title, due_on, due_time) values
  ('00000000-0000-0000-0000-0000000000e6',
   '00000000-0000-0000-0000-00000000000a', 'Night', '2027-03-28', '02:30');
select results_eq(
  $$ select * from pg_temp.claimed('2027-03-28 01:00:00+00') $$,
  $$ values ('00000000-0000-0000-0000-0000000000e6'::uuid) $$,
  'a time skipped by DST goes at 03:00'
);

-- A repeating task's next one keeps the time.
insert into public.task
  (id, owner_id, title, due_on, due_time, repeat_every, repeat_unit,
   repeat_from, scheduled_on)
values
  ('00000000-0000-0000-0000-0000000000e7',
   '00000000-0000-0000-0000-00000000000a', 'Weekly call', '2026-10-27',
   '09:00', 1, 'week', '2026-10-27', '2026-10-27');
set local role authenticated;
set local request.jwt.claims =
  '{"sub": "00000000-0000-0000-0000-00000000000a", "role": "authenticated"}';
select public.complete_task('00000000-0000-0000-0000-0000000000e7', '2026-10-27');
select results_eq(
  $$ select due_on, due_time from public.task
     where follows_id = '00000000-0000-0000-0000-0000000000e7' $$,
  $$ values ('2026-11-03'::date, '09:00'::time) $$,
  'complete_task keeps the time'
);
select public.delete_task(
  (select id from public.task
    where follows_id = '00000000-0000-0000-0000-0000000000e7'),
  '2026-10-28', false
);
select results_eq(
  $$ select due_time from public.task where title = 'Weekly call'
     and done_on is null $$,
  $$ values ('09:00'::time) $$,
  'delete_task, this one: the next keeps the time'
);

-- Grants: the user sets the time, never the claim, and can't claim.
select lives_ok(
  $$ update public.task set due_time = '10:00'
     where id = '00000000-0000-0000-0000-0000000000e4' $$,
  'due_time is the user''s'
);
select throws_ok(
  $$ update public.task set alerted_for = null
     where id = '00000000-0000-0000-0000-0000000000e4' $$,
  '42501', null,
  'alerted_for is the sender''s'
);
select throws_ok(
  $$ select public.claim_task_alerts() $$,
  '42501', null,
  'a user cannot claim'
);
select throws_ok(
  $$ select public.claim_daily_summaries_with_tasks() $$,
  '42501', null,
  'nor claim summaries'
);
reset role;

-- The summary with tasks: A's open tasks due on or before Oct 27 count.
update public.notification_settings
  set summary_enabled = true, summary_time = '19:00',
      summary_days = '{1,2,3,4,5,6,7}'
  where owner_id = '00000000-0000-0000-0000-00000000000a';
select is(
  public.due_tasks_count('00000000-0000-0000-0000-00000000000a', '2026-10-27'),
  2,
  'open tasks due on or before the day (the done one not)'
);
select results_eq(
  $$ select people, tasks from public.claim_daily_summaries_with_tasks(
       '2026-10-27 18:05:00+00')
     where owner_id = '00000000-0000-0000-0000-00000000000a' $$,
  $$ values (0, 2) $$,
  'tasks alone are enough for a summary'
);
select is(
  (select count(*)::int from public.claim_daily_summaries(
     '2026-10-27 18:10:00+00')),
  0,
  'the old claim shares the day: nothing twice'
);
-- Another day, only tasks: the old claim (the sender before this one)
-- still sends nothing, so an old app never reads "0 people".
select is(
  (select count(*)::int from public.claim_daily_summaries(
     '2026-10-28 18:05:00+00')
   where owner_id = '00000000-0000-0000-0000-00000000000a'),
  0,
  'the old claim ignores tasks'
);

select * from finish();
rollback;

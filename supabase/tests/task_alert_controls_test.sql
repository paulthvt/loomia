-- Task notification controls (#389): a task pushes only when its owner's
-- Tasks switch (notification_settings.task_enabled) and its bell (task.alert)
-- are both on. Both default on. Run with `supabase test db`.
begin;
create extension if not exists pgtap with schema extensions;
select plan(14);

insert into auth.users (id, email) values
  ('00000000-0000-0000-0000-00000000000a', 'a@example.com'),
  ('00000000-0000-0000-0000-00000000000b', 'b@example.com');

-- Both in Paris (UTC+1 on Oct 27 2026): 14:00 local is 13:00 UTC.
insert into public.notification_settings (owner_id, time_zone) values
  ('00000000-0000-0000-0000-00000000000a', 'Europe/Paris'),
  ('00000000-0000-0000-0000-00000000000b', 'Europe/Paris');

insert into public.task (id, owner_id, title, due_on, due_time) values
  ('00000000-0000-0000-0000-0000000000f1',
   '00000000-0000-0000-0000-00000000000a', 'Bell on', '2026-10-27', '14:00'),
  ('00000000-0000-0000-0000-0000000000f2',
   '00000000-0000-0000-0000-00000000000a', 'Bell off', '2026-10-27', '14:00'),
  ('00000000-0000-0000-0000-0000000000f3',
   '00000000-0000-0000-0000-00000000000b', 'Switch off', '2026-10-27',
   '14:00');

select is(
  (select alert from public.task
    where id = '00000000-0000-0000-0000-0000000000f1'),
  true,
  'a task''s bell defaults on'
);
select is(
  (select task_enabled from public.notification_settings
    where owner_id = '00000000-0000-0000-0000-00000000000a'),
  true,
  'the Tasks switch defaults on'
);

update public.task set alert = false
  where id = '00000000-0000-0000-0000-0000000000f2';
update public.notification_settings set task_enabled = false
  where owner_id = '00000000-0000-0000-0000-00000000000b';

select results_eq(
  $$ select task_id from public.claim_task_alerts('2026-10-27 13:00:30+00') $$,
  $$ values ('00000000-0000-0000-0000-0000000000f1'::uuid) $$,
  'only the task whose bell and switch are both on is claimed'
);

-- The bell is not a time: toggling it neither re-arms nor clears a claim.
update public.task set alert = false
  where id = '00000000-0000-0000-0000-0000000000f1';
update public.task set alert = true
  where id = '00000000-0000-0000-0000-0000000000f1';
select is(
  (select alerted_for from public.task
    where id = '00000000-0000-0000-0000-0000000000f1'),
  '2026-10-27 14:00'::timestamp,
  'off and on again keeps the claim: no second push for that time'
);

-- Turning the bell on is an edit (#376's undo then keeps the task).
update public.task
  set created_at = created_at - interval '1 minute',
      updated_at = updated_at - interval '1 minute'
  where id = '00000000-0000-0000-0000-0000000000f2';
update public.task set alert = true
  where id = '00000000-0000-0000-0000-0000000000f2';
select is(
  (select updated_at > created_at from public.task
    where id = '00000000-0000-0000-0000-0000000000f2'),
  true,
  'the bell counts as an edit: updated_at moves'
);

-- A repeating task's next one keeps the bell.
insert into public.task
  (id, owner_id, title, due_on, due_time, alert, repeat_every, repeat_unit,
   repeat_from, scheduled_on)
values
  ('00000000-0000-0000-0000-0000000000f4',
   '00000000-0000-0000-0000-00000000000a', 'Weekly call', '2026-10-27',
   '09:00', false, 1, 'week', '2026-10-27', '2026-10-27');

set local role authenticated;
set local request.jwt.claims =
  '{"sub": "00000000-0000-0000-0000-00000000000a", "role": "authenticated"}';

select public.complete_task('00000000-0000-0000-0000-0000000000f4', '2026-10-27');
select results_eq(
  $$ select alert from public.task
     where follows_id = '00000000-0000-0000-0000-0000000000f4' $$,
  $$ values (false) $$,
  'complete_task keeps the bell off'
);
select public.delete_task(
  (select id from public.task
    where follows_id = '00000000-0000-0000-0000-0000000000f4'),
  '2026-10-28', false
);
select results_eq(
  $$ select alert from public.task where title = 'Weekly call'
     and done_on is null $$,
  $$ values (false) $$,
  'delete_task, this one: the next keeps the bell off'
);

-- Grants: the owner sets both; the claim stays the sender's.
select lives_ok(
  $$ update public.task set alert = false
     where id = '00000000-0000-0000-0000-0000000000f1' $$,
  'alert is the user''s'
);
select lives_ok(
  $$ update public.notification_settings set task_enabled = false
     where owner_id = '00000000-0000-0000-0000-00000000000a' $$,
  'task_enabled is the user''s'
);
select throws_ok(
  $$ update public.task set alerted_for = null
     where id = '00000000-0000-0000-0000-0000000000f1' $$,
  '42501', null,
  'alerted_for is still the sender''s'
);
select is(
  (select count(*)::int from public.task
    where id = '00000000-0000-0000-0000-0000000000f3'),
  0,
  'another owner''s task stays out of reach'
);

-- The released app upserts its settings without task_enabled: the switch
-- keeps what it was.
insert into public.notification_settings
  (summary_enabled, ritual_enabled, summary_time, summary_days, time_zone)
values (true, false, '19:00', '{1,2,3,4,5}', 'Europe/Paris')
on conflict (owner_id) do update set
  summary_enabled = excluded.summary_enabled,
  ritual_enabled = excluded.ritual_enabled,
  summary_time = excluded.summary_time,
  summary_days = excluded.summary_days,
  time_zone = excluded.time_zone;
select is(
  (select task_enabled from public.notification_settings),
  false,
  'an upsert without task_enabled keeps the switch off'
);
select is(
  (select summary_enabled from public.notification_settings),
  true,
  'and saves what it sent'
);

reset role;
select is(
  (select alert from public.task
    where id = '00000000-0000-0000-0000-0000000000f1'),
  false,
  'the bell saved by its owner'
);

select * from finish();
rollback;

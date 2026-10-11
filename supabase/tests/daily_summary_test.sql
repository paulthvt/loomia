-- The daily summary (#269): who is due a push now, in their own time zone,
-- claimed once per local day. Run with `supabase test db`.
begin;
create extension if not exists pgtap with schema extensions;
select plan(39);

insert into auth.users (id, email) values
  ('00000000-0000-0000-0000-00000000000a', 'a@example.com'),
  ('00000000-0000-0000-0000-00000000000b', 'b@example.com'),
  ('00000000-0000-0000-0000-00000000000c', 'c@example.com'),
  ('00000000-0000-0000-0000-00000000000d', 'd@example.com');

-- A, Paris: a reminder due Monday 12th (Claire), one due Tuesday (Marc), a
-- paused person whose step was due on the 10th and a reminder on the 11th
-- (Léa), a step due on the 12th plus an old reminder (Tom), a step only
-- (Ana). B, New York: one old reminder. C: nobody. D: one old reminder.
insert into public.workflow (id, owner_id, stage, name) values
  ('00000000-0000-0000-0000-0000000000f1',
   '00000000-0000-0000-0000-00000000000a', 'prospect', 'Samples');
insert into public.workflow_step (owner_id, workflow_id, position, label, days)
  values ('00000000-0000-0000-0000-00000000000a',
          '00000000-0000-0000-0000-0000000000f1', 1, 'Check in', 3);
insert into public.person
  (id, owner_id, name, stage, workflow_id, at_position, last_tick, paused_at)
  values
  ('00000000-0000-0000-0000-0000000000a1',
   '00000000-0000-0000-0000-00000000000a', 'Claire', 'prospect',
   null, null, null, null),
  ('00000000-0000-0000-0000-0000000000a2',
   '00000000-0000-0000-0000-00000000000a', 'Marc', 'prospect',
   null, null, null, null),
  ('00000000-0000-0000-0000-0000000000a3',
   '00000000-0000-0000-0000-00000000000a', 'Léa', 'prospect',
   '00000000-0000-0000-0000-0000000000f1', 1, '2026-10-07', now()),
  ('00000000-0000-0000-0000-0000000000a4',
   '00000000-0000-0000-0000-00000000000a', 'Tom', 'prospect',
   '00000000-0000-0000-0000-0000000000f1', 1, '2026-10-09', null),
  ('00000000-0000-0000-0000-0000000000a5',
   '00000000-0000-0000-0000-00000000000a', 'Ana', 'prospect',
   '00000000-0000-0000-0000-0000000000f1', 1, '2026-10-09', null),
  ('00000000-0000-0000-0000-0000000000b1',
   '00000000-0000-0000-0000-00000000000b', 'Ben', 'customer',
   null, null, null, null),
  ('00000000-0000-0000-0000-0000000000d1',
   '00000000-0000-0000-0000-00000000000d', 'Dan', 'customer',
   null, null, null, null);
insert into public.reminder (owner_id, person_id, text, due_on) values
  ('00000000-0000-0000-0000-00000000000a',
   '00000000-0000-0000-0000-0000000000a1', 'Call', '2026-10-12'),
  ('00000000-0000-0000-0000-00000000000a',
   '00000000-0000-0000-0000-0000000000a2', 'Call', '2026-10-13'),
  ('00000000-0000-0000-0000-00000000000a',
   '00000000-0000-0000-0000-0000000000a3', 'Call', '2026-10-11'),
  ('00000000-0000-0000-0000-00000000000a',
   '00000000-0000-0000-0000-0000000000a4', 'Call', '2026-10-01'),
  ('00000000-0000-0000-0000-00000000000b',
   '00000000-0000-0000-0000-0000000000b1', 'Call', '2026-10-01'),
  ('00000000-0000-0000-0000-00000000000d',
   '00000000-0000-0000-0000-0000000000d1', 'Call', '2026-01-01');

insert into public.notification_settings
  (owner_id, summary_enabled, summary_time, time_zone) values
  ('00000000-0000-0000-0000-00000000000b', true, '19:00', 'America/New_York'),
  ('00000000-0000-0000-0000-00000000000c', true, '19:00', 'Europe/Paris');
insert into public.notification_settings
  (owner_id, summary_enabled, summary_time, summary_days, time_zone) values
  ('00000000-0000-0000-0000-00000000000d', true, '02:30', '{1,2,3,4,5,6,7}',
   'Europe/Paris');

-- Settings, as A.
set local role authenticated;
set local request.jwt.claims =
  '{"sub": "00000000-0000-0000-0000-00000000000a", "role": "authenticated"}';

select throws_ok(
  $$ insert into public.notification_settings (summary_days, time_zone)
     values ('{}', 'Europe/Paris') $$,
  '23514', null,
  'no day at all is refused'
);
select throws_ok(
  $$ insert into public.notification_settings (summary_days, time_zone)
     values ('{1,8}', 'Europe/Paris') $$,
  '23514', null,
  'a day past Sunday is refused'
);
select throws_ok(
  $$ insert into public.notification_settings (time_zone)
     values ('Mars/Olympus') $$,
  '23514', null,
  'an unknown time zone is refused'
);
select lives_ok(
  $$ insert into public.notification_settings (summary_enabled, time_zone)
     values (true, 'Europe/Paris') $$,
  'A saves their settings'
);
select results_eq(
  $$ select summary_time, summary_days from public.notification_settings $$,
  $$ values ('19:00'::time, '{1,2,3,4,5}'::smallint[]) $$,
  'A sees only their row, 19:00 on weekdays by default'
);
select throws_ok(
  $$ delete from public.notification_settings $$,
  '42501', null,
  'settings are not deleted by the app'
);
select throws_ok(
  $$ select * from public.notification_sent $$,
  '42501', null,
  'the app cannot read what was sent'
);
select throws_ok(
  $$ select * from public.claim_daily_summaries() $$,
  '42501', null,
  'the app cannot claim'
);
select throws_ok(
  $$ select public.release_daily_summary(
       '00000000-0000-0000-0000-00000000000a', '2026-10-12') $$,
  '42501', null,
  'the app cannot release'
);
select throws_ok(
  $$ select public.drop_device_tokens(array['x']) $$,
  '42501', null,
  'the app cannot drop tokens'
);

-- The count, as the sender.
reset role;
set local role service_role;

select is(
  public.due_people_count('00000000-0000-0000-0000-00000000000a', '2026-10-10'),
  1,
  'a pause hides the step: on the 10th only Tom''s old reminder'
);
select is(
  public.due_people_count('00000000-0000-0000-0000-00000000000a', '2026-10-11'),
  2,
  'a paused person''s reminder still counts'
);
select is(
  public.due_people_count('00000000-0000-0000-0000-00000000000a', '2026-10-12'),
  4,
  'steps and reminders due today or late, each person once'
);
select is(
  public.due_people_count('00000000-0000-0000-0000-00000000000a', '2026-10-13'),
  5,
  'a reminder due tomorrow counts tomorrow'
);

-- Who is claimed, and when. Monday 12 October: Paris is UTC+2, New York UTC-4.
select is_empty(
  $$ select * from public.claim_daily_summaries('2026-10-12 16:55Z') $$,
  '18:55 in Paris: not yet'
);
select results_eq(
  $$ select owner_id, local_date, people
     from public.claim_daily_summaries('2026-10-12 17:00Z') $$,
  $$ values ('00000000-0000-0000-0000-00000000000a'::uuid, '2026-10-12'::date,
             4) $$,
  '19:00 in Paris: A, with their count; not B (13:00 in New York), not C (nobody due)'
);
select is_empty(
  $$ select * from public.claim_daily_summaries('2026-10-12 17:15Z') $$,
  'the next run claims nothing: already claimed today'
);
select results_eq(
  $$ select owner_id, local_date, people
     from public.claim_daily_summaries('2026-10-12 23:00Z') $$,
  $$ values ('00000000-0000-0000-0000-00000000000b'::uuid, '2026-10-12'::date,
             1) $$,
  '19:00 in New York: B, on their own date'
);
select is_empty(
  $$ select * from public.claim_daily_summaries('2026-10-17 17:00Z') $$,
  'Saturday is not selected'
);
select is_empty(
  $$ select * from public.claim_daily_summaries('2026-10-13 20:01Z') $$,
  'Tuesday 22:01 in Paris: past the 3-hour window'
);
select results_eq(
  $$ select owner_id, local_date, people
     from public.claim_daily_summaries('2026-10-13 19:30Z') $$,
  $$ values ('00000000-0000-0000-0000-00000000000a'::uuid, '2026-10-13'::date,
             5) $$,
  'Tuesday 21:30 in Paris: still inside the window'
);

reset role;
update public.notification_settings set summary_enabled = false
  where owner_id = '00000000-0000-0000-0000-00000000000a';
set local role service_role;
select is_empty(
  $$ select * from public.claim_daily_summaries('2026-10-14 17:00Z') $$,
  'turned off: nothing'
);
reset role;
update public.notification_settings set summary_enabled = true
  where owner_id = '00000000-0000-0000-0000-00000000000a';
set local role service_role;

-- A failed send hands the day back, three attempts at most.
select public.release_daily_summary(
  '00000000-0000-0000-0000-00000000000a', '2026-10-12');
select results_eq(
  $$ select owner_id from public.claim_daily_summaries('2026-10-12 17:30Z') $$,
  $$ values ('00000000-0000-0000-0000-00000000000a'::uuid) $$,
  'released: the next run claims it again'
);
select public.release_daily_summary(
  '00000000-0000-0000-0000-00000000000a', '2026-10-12');
select results_eq(
  $$ select owner_id from public.claim_daily_summaries('2026-10-12 17:45Z') $$,
  $$ values ('00000000-0000-0000-0000-00000000000a'::uuid) $$,
  'a third attempt'
);
select public.release_daily_summary(
  '00000000-0000-0000-0000-00000000000a', '2026-10-12');
select is_empty(
  $$ select * from public.claim_daily_summaries('2026-10-12 18:00Z') $$,
  'no fourth attempt'
);
reset role;
select is(
  (select attempts::int from public.notification_sent
    where owner_id = '00000000-0000-0000-0000-00000000000a'
      and local_date = '2026-10-12'),
  3,
  'three attempts recorded'
);
set local role service_role;

-- Daylight saving, D at 02:30 every day in Paris.
select is_empty(
  $$ select * from public.claim_daily_summaries('2026-03-29 00:45Z')
     where owner_id = '00000000-0000-0000-0000-00000000000d' $$,
  '29 March, 01:45 CET: not yet'
);
select results_eq(
  $$ select owner_id, local_date from public.claim_daily_summaries('2026-03-29 01:00Z')
     where owner_id = '00000000-0000-0000-0000-00000000000d' $$,
  $$ values ('00000000-0000-0000-0000-00000000000d'::uuid, '2026-03-29'::date) $$,
  '02:30 never happens that night: the 03:00 CEST run sends it'
);
select results_eq(
  $$ select owner_id, local_date from public.claim_daily_summaries('2026-10-25 00:30Z')
     where owner_id = '00000000-0000-0000-0000-00000000000d' $$,
  $$ values ('00000000-0000-0000-0000-00000000000d'::uuid, '2026-10-25'::date) $$,
  '25 October, the first 02:30 (CEST)'
);
select is_empty(
  $$ select * from public.claim_daily_summaries('2026-10-25 01:30Z')
     where owner_id = '00000000-0000-0000-0000-00000000000d' $$,
  'the second 02:30 (CET) sends nothing more'
);

-- B flies to Honolulu (UTC-10) after their New York summary.
reset role;
update public.notification_settings set time_zone = 'Pacific/Honolulu'
  where owner_id = '00000000-0000-0000-0000-00000000000b';
set local role service_role;
select is_empty(
  $$ select * from public.claim_daily_summaries('2026-10-13 05:00Z')
     where owner_id = '00000000-0000-0000-0000-00000000000b' $$,
  '19:00 on the 12th again in Honolulu: that day was claimed'
);
select results_eq(
  $$ select owner_id, local_date from public.claim_daily_summaries('2026-10-14 05:00Z')
     where owner_id = '00000000-0000-0000-0000-00000000000b' $$,
  $$ values ('00000000-0000-0000-0000-00000000000b'::uuid, '2026-10-13'::date) $$,
  'the next day follows the new zone'
);

-- Dead tokens.
reset role;
insert into public.device_token (token, owner_id, platform, locale) values
  ('t1', '00000000-0000-0000-0000-00000000000a', 'android', 'en'),
  ('t2', '00000000-0000-0000-0000-00000000000a', 'android', 'fr');
set local role service_role;
select lives_ok(
  $$ select public.drop_device_tokens(array['t1']) $$,
  'the sender drops a token'
);
select results_eq(
  $$ select token from public.device_token $$,
  $$ values ('t2'::text) $$,
  'only that one'
);

-- Cron housekeeping (run_daily_summary).
reset role;
insert into public.notification_sent (owner_id, kind, local_date) values
  ('00000000-0000-0000-0000-00000000000c', 'daily_summary', current_date - 31),
  ('00000000-0000-0000-0000-00000000000c', 'daily_summary', current_date - 29);
select lives_ok(
  $$ select public.run_daily_summary() $$,
  'without its Vault secrets the job runs and posts nothing'
);
select is(
  (select count(*)::int from net.http_request_queue), 0,
  'nothing was posted'
);
select results_eq(
  $$ select local_date from public.notification_sent
     where owner_id = '00000000-0000-0000-0000-00000000000c' $$,
  $$ values (current_date - 29) $$,
  'claims older than 30 days are gone'
);
select is(
  (select schedule from cron.job where jobname = 'send-daily-summary'),
  '*/15 * * * *',
  'scheduled every 15 minutes'
);

set local role authenticated;
set local request.jwt.claims =
  '{"sub": "00000000-0000-0000-0000-00000000000a", "role": "authenticated"}';
select throws_ok(
  $$ select public.run_daily_summary() $$,
  '42501', null,
  'the app cannot run the job'
);

select * from finish();
rollback;

-- The month-end push (#148, #354): what the close-and-plan window still asks,
-- and who is claimed, once per half of it, at their summary time. The pending_ritual
-- cases mirror pendingRitual in test/features/goals/domain/goal_rules_test.dart.
-- Run with `supabase test db`.
begin;
create extension if not exists pgtap with schema extensions;
select plan(32);

-- September 2026 has 30 days: the window is Mon 28 Sep – Mon 5 Oct, drafting
-- October until the 30th, closing September from the 1st. Paris is
-- UTC+2. A: September planned, open. B: no plan at all. C: September closed,
-- October not planned. D: September closed, October planned. E: like A, the
-- push off. F: like A, Sundays only.
insert into auth.users (id, email) values
  ('00000000-0000-0000-0000-00000000000a', 'a@example.com'),
  ('00000000-0000-0000-0000-00000000000b', 'b@example.com'),
  ('00000000-0000-0000-0000-00000000000c', 'c@example.com'),
  ('00000000-0000-0000-0000-00000000000d', 'd@example.com'),
  ('00000000-0000-0000-0000-00000000000e', 'e@example.com'),
  ('00000000-0000-0000-0000-00000000000f', 'f@example.com');

insert into public.month_plan (owner_id, month, own_volume_target, closed_at)
  values
  ('00000000-0000-0000-0000-00000000000a', '2026-09-01', 100, null),
  ('00000000-0000-0000-0000-00000000000c', '2026-09-01', 100, now()),
  ('00000000-0000-0000-0000-00000000000d', '2026-09-01', 100, now()),
  ('00000000-0000-0000-0000-00000000000d', '2026-10-01', 100, null),
  ('00000000-0000-0000-0000-00000000000e', '2026-09-01', 100, null),
  ('00000000-0000-0000-0000-00000000000f', '2026-09-01', 100, null);

insert into public.notification_settings
  (owner_id, ritual_enabled, summary_days, time_zone) values
  ('00000000-0000-0000-0000-00000000000a', false, '{1,2,3,4,5}', 'Europe/Paris'),
  ('00000000-0000-0000-0000-00000000000b', true, '{1,2,3,4,5}', 'Europe/Paris'),
  ('00000000-0000-0000-0000-00000000000c', true, '{1,2,3,4,5}', 'Europe/Paris'),
  ('00000000-0000-0000-0000-00000000000d', true, '{1,2,3,4,5}', 'Europe/Paris'),
  ('00000000-0000-0000-0000-00000000000e', false, '{1,2,3,4,5}', 'Europe/Paris'),
  ('00000000-0000-0000-0000-00000000000f', true, '{7}', 'Europe/Paris');

-- The daily summary's claim for A on the 1st is another kind: it doesn't
-- block the month-end one dated the 1st.
insert into public.notification_sent (owner_id, kind, local_date) values
  ('00000000-0000-0000-0000-00000000000a', 'daily_summary', '2026-10-01');

-- As the app.
set local role authenticated;
set local request.jwt.claims =
  '{"sub": "00000000-0000-0000-0000-00000000000a", "role": "authenticated"}';

select lives_ok(
  $$ update public.notification_settings set ritual_enabled = true $$,
  'A turns the month-end push on'
);
select throws_ok(
  $$ select * from public.pending_ritual(
       '00000000-0000-0000-0000-00000000000a', '2026-09-28') $$,
  '42501', null,
  'the app cannot read the rule'
);
select throws_ok(
  $$ select * from public.claim_month_rituals() $$,
  '42501', null,
  'the app cannot claim'
);
select throws_ok(
  $$ select public.release_month_ritual(
       '00000000-0000-0000-0000-00000000000a', '2026-10-01') $$,
  '42501', null,
  'the app cannot release'
);

reset role;
select is(
  (select ritual_enabled from public.notification_settings
    where owner_id = '00000000-0000-0000-0000-00000000000a'),
  true,
  'saved'
);
set local role service_role;

-- The rule.
select is_empty(
  $$ select * from public.pending_ritual(
       '00000000-0000-0000-0000-00000000000a', '2026-09-15') $$,
  'outside the window: nothing'
);
select is_empty(
  $$ select * from public.pending_ritual(
       '00000000-0000-0000-0000-00000000000a', '2026-09-27') $$,
  'the 27th of a 30-day month: not yet'
);
select results_eq(
  $$ select * from public.pending_ritual(
       '00000000-0000-0000-0000-00000000000a', '2026-09-28') $$,
  $$ values ('2026-09-01'::date, '2026-10-01'::date, false) $$,
  'the 28th: only the plan, a month is never closed before it ends'
);
select results_eq(
  $$ select * from public.pending_ritual(
       '00000000-0000-0000-0000-00000000000a', '2026-10-01') $$,
  $$ values ('2026-09-01'::date, '2026-10-01'::date, true) $$,
  'the 1st: a planned month to close, then the next to plan'
);
select is_empty(
  $$ select * from public.pending_ritual(
       '00000000-0000-0000-0000-00000000000d', '2026-09-28') $$,
  'the 28th, next already drafted: nothing to send'
);
select results_eq(
  $$ select * from public.pending_ritual(
       '00000000-0000-0000-0000-00000000000a', '2026-10-05') $$,
  $$ values ('2026-09-01'::date, '2026-10-01'::date, true) $$,
  'the 5th: still the month before'
);
select is_empty(
  $$ select * from public.pending_ritual(
       '00000000-0000-0000-0000-00000000000a', '2026-10-06') $$,
  'the 6th: closed window'
);
select results_eq(
  $$ select * from public.pending_ritual(
       '00000000-0000-0000-0000-00000000000a', '2026-12-29') $$,
  $$ values ('2026-12-01'::date, '2027-01-01'::date, false) $$,
  'December: the plan is for January, next year'
);
select results_eq(
  $$ select * from public.pending_ritual(
       '00000000-0000-0000-0000-00000000000a', '2027-02-26') $$,
  $$ values ('2027-02-01'::date, '2027-03-01'::date, false) $$,
  'February 2027 opens on the 26th'
);
select is_empty(
  $$ select * from public.pending_ritual(
       '00000000-0000-0000-0000-00000000000a', '2027-02-25') $$,
  'and not on the 25th'
);
select results_eq(
  $$ select * from public.pending_ritual(
       '00000000-0000-0000-0000-00000000000b', '2026-10-02') $$,
  $$ values ('2026-09-01'::date, '2026-10-01'::date, false) $$,
  'never planned: nothing to close, only the plan; A''s plan is not B''s'
);
select results_eq(
  $$ select * from public.pending_ritual(
       '00000000-0000-0000-0000-00000000000c', '2026-09-30') $$,
  $$ values ('2026-09-01'::date, '2026-10-01'::date, false) $$,
  'closed, next not planned: only the plan'
);
select is_empty(
  $$ select * from public.pending_ritual(
       '00000000-0000-0000-0000-00000000000d', '2026-10-03') $$,
  'closed and the next planned: nothing left'
);

-- Who is claimed, and when: once while drafting, once from the 1st.
select is_empty(
  $$ select * from public.claim_month_rituals('2026-09-28 16:55Z') $$,
  'Monday 28th, 18:55 in Paris: not yet'
);
select results_eq(
  $$ select owner_id, to_close, to_plan, closes, claim_date
     from public.claim_month_rituals('2026-09-28 17:00Z') order by owner_id $$,
  $$ values
     ('00000000-0000-0000-0000-00000000000a'::uuid, '2026-09-01'::date,
      '2026-10-01'::date, false, '2026-09-30'::date),
     ('00000000-0000-0000-0000-00000000000b'::uuid, '2026-09-01'::date,
      '2026-10-01'::date, false, '2026-09-30'::date),
     ('00000000-0000-0000-0000-00000000000c'::uuid, '2026-09-01'::date,
      '2026-10-01'::date, false, '2026-09-30'::date) $$,
  '19:00: A, B, C to plan October; not D (drafted), E (off), F (Sundays only)'
);
select is_empty(
  $$ select * from public.claim_month_rituals('2026-09-28 17:15Z') $$,
  'the next run claims nothing'
);
select is_empty(
  $$ select * from public.claim_month_rituals('2026-09-29 17:00Z') $$,
  'nor the next day of the drafting half'
);

-- A failed send hands the drafting half back, not the closing one.
select public.release_month_ritual(
  '00000000-0000-0000-0000-00000000000a', '2026-09-30');
select results_eq(
  $$ select owner_id, claim_date
     from public.claim_month_rituals('2026-09-29 17:15Z') $$,
  $$ values ('00000000-0000-0000-0000-00000000000a'::uuid, '2026-09-30'::date) $$,
  'released while drafting: claimed again'
);

-- A drafts October after the push.
reset role;
insert into public.month_plan (owner_id, month, own_volume_target) values
  ('00000000-0000-0000-0000-00000000000a', '2026-10-01', 100);
set local role service_role;
select is_empty(
  $$ select * from public.claim_month_rituals('2026-09-30 17:00Z') $$,
  'the 30th: nothing new'
);
select results_eq(
  $$ select owner_id, closes, claim_date
     from public.claim_month_rituals('2026-10-01 17:00Z') order by owner_id $$,
  $$ values
     ('00000000-0000-0000-0000-00000000000a'::uuid, true, '2026-10-01'::date),
     ('00000000-0000-0000-0000-00000000000b'::uuid, false, '2026-10-01'::date),
     ('00000000-0000-0000-0000-00000000000c'::uuid, false, '2026-10-01'::date) $$,
  'the 1st: A drafted but still asked to close; B, C still to plan'
);
select is_empty(
  $$ select * from public.claim_month_rituals('2026-10-02 17:00Z') $$,
  'nor the next day of the closing half'
);
select results_eq(
  $$ select owner_id from public.claim_month_rituals('2026-10-04 17:00Z') $$,
  $$ values ('00000000-0000-0000-0000-00000000000f'::uuid) $$,
  'Sunday 4th: F, on the first of their days in the closing half'
);

-- A failed send hands the half back, three attempts at most.
select public.release_month_ritual(
  '00000000-0000-0000-0000-00000000000a', '2026-10-01');
select results_eq(
  $$ select owner_id from public.claim_month_rituals('2026-10-02 17:15Z') $$,
  $$ values ('00000000-0000-0000-0000-00000000000a'::uuid) $$,
  'released: claimed again'
);
select public.release_month_ritual(
  '00000000-0000-0000-0000-00000000000a', '2026-10-01');
select results_eq(
  $$ select owner_id from public.claim_month_rituals('2026-10-02 17:30Z') $$,
  $$ values ('00000000-0000-0000-0000-00000000000a'::uuid) $$,
  'a third attempt'
);
select public.release_month_ritual(
  '00000000-0000-0000-0000-00000000000a', '2026-10-01');
select is_empty(
  $$ select * from public.claim_month_rituals('2026-10-02 17:45Z') $$,
  'no fourth attempt'
);
reset role;
select results_eq(
  $$ select kind::text, attempts::int, claimed_at is not null
     from public.notification_sent
     where owner_id = '00000000-0000-0000-0000-00000000000a'
       and local_date = '2026-10-01'
     order by kind $$,
  $$ values ('daily_summary'::text, 1, true), ('month_ritual'::text, 3, false) $$,
  'the summary''s claim on the same date is untouched'
);

-- Turned off: nothing, even in a new window.
update public.notification_settings set ritual_enabled = false
  where owner_id = '00000000-0000-0000-0000-00000000000b';
set local role service_role;
select is_empty(
  $$ select * from public.claim_month_rituals('2026-10-29 18:00Z')
     where owner_id = '00000000-0000-0000-0000-00000000000b' $$,
  'B turned it off'
);

select * from finish();
rollback;

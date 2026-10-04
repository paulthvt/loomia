-- Goals (#141): month plans, live progress, the loyalty forecast and the
-- frozen close. Run with `supabase test db`.
begin;
create extension if not exists pgtap with schema extensions;
select plan(15);

insert into auth.users (id, email) values
  ('00000000-0000-0000-0000-00000000000a', 'a@example.com'),
  ('00000000-0000-0000-0000-00000000000b', 'b@example.com');

set local role authenticated;
set local request.jwt.claims =
  '{"sub": "00000000-0000-0000-0000-00000000000a", "role": "authenticated"}';

-- 1-2: first stage.
insert into public.person (id, name, stage, first_stage) values
  ('00000000-0000-0000-0000-0000000000a1', 'Sarah', 'prospect', 'team');
select is(
  (select first_stage::text from public.person
    where id = '00000000-0000-0000-0000-0000000000a1'),
  'prospect',
  'first_stage is the stage at insert, whatever the app sends'
);
update public.person set stage = 'customer'
  where id = '00000000-0000-0000-0000-0000000000a1';
select is(
  (select first_stage::text from public.person
    where id = '00000000-0000-0000-0000-0000000000a1'),
  'prospect',
  'a stage change keeps first_stage'
);

-- 3-6: month_plan constraints.
select lives_ok(
  $$ insert into public.month_plan (month, own_volume_target, prospects_target)
     values ('2026-10-01', 500, 4) $$,
  'a plan for a month saves'
);
select throws_ok(
  $$ insert into public.month_plan (month) values ('2026-10-01') $$,
  '23505', null,
  'one plan per month'
);
select throws_ok(
  $$ insert into public.month_plan (month) values ('2026-11-02') $$,
  '23514', null,
  'a month is its first day'
);
select throws_ok(
  $$ insert into public.month_plan (month, prospects_target)
     values ('2026-12-01', -1) $$,
  '23514', null,
  'a count target is not negative'
);

-- 7-8: as B.
set local request.jwt.claims =
  '{"sub": "00000000-0000-0000-0000-00000000000b", "role": "authenticated"}';
select is(
  (select count(*)::int from public.month_plan), 0,
  'another user sees no plan'
);
select lives_ok(
  $$ insert into public.month_plan (month) values ('2026-10-01') $$,
  'another user has their own October'
);

-- Back as A for the tasks below.
set local request.jwt.claims =
  '{"sub": "00000000-0000-0000-0000-00000000000a", "role": "authenticated"}';

-- 9-11: progress. Dates (orders, steps) against the month; instants
-- (people added, stage entries) against the device's bounds, here now ± 1h.
insert into public.person (id, name, stage) values
  ('00000000-0000-0000-0000-0000000000a2', 'Léa', 'team'),
  ('00000000-0000-0000-0000-0000000000a3', 'Marc', 'customer');
-- Sarah (a1) went prospect -> customer in Task 1; back and forth once more.
update public.person set stage = 'prospect'
  where id = '00000000-0000-0000-0000-0000000000a1';
update public.person set stage = 'customer'
  where id = '00000000-0000-0000-0000-0000000000a1';
insert into public.activity (person_id, kind, amount, happened_on) values
  ('00000000-0000-0000-0000-0000000000a1', 'order', 100.50, '2026-10-02'),
  ('00000000-0000-0000-0000-0000000000a1', 'order', 50, '2026-09-30');
insert into public.activity (kind, amount, happened_on) values
  ('order', 80, '2026-10-03');
insert into public.activity (person_id, kind, text, happened_on, loyalty_setup) values
  ('00000000-0000-0000-0000-0000000000a3', 'step', 'Set up a refill routine', '2026-10-05', true),
  ('00000000-0000-0000-0000-0000000000a3', 'step', 'Set up a refill routine', '2026-09-29', true),
  ('00000000-0000-0000-0000-0000000000a3', 'step', 'Order arrived', '2026-10-05', false);

select results_eq(
  $$ select * from public.month_progress('2026-10-01',
       now() - interval '1 hour', now() + interval '1 hour') $$,
  $$ values (180.50::numeric, 1, 2, 1, 1) $$,
  'progress: own orders count, a customer counts once, added as customer counts'
);

-- Paris, March 2027: local midnight is 23:00 UTC on Feb 28.
insert into public.person (name, stage, created_at) values
  ('Nina', 'prospect', '2027-02-28 23:30+00'),
  ('Paul', 'prospect', '2027-02-28 22:30+00');
select is(
  (select prospects from public.month_progress('2027-03-01',
     '2027-02-28 23:00+00', '2027-03-31 22:00+00')),
  1,
  'someone added at 00:30 local on the 1st counts in the new month'
);

set local request.jwt.claims =
  '{"sub": "00000000-0000-0000-0000-00000000000b", "role": "authenticated"}';
select results_eq(
  $$ select * from public.month_progress('2026-10-01',
       now() - interval '1 hour', now() + interval '1 hour') $$,
  $$ values (0::numeric, 0, 0, 0, 0) $$,
  'another user''s progress is their own'
);
set local request.jwt.claims =
  '{"sub": "00000000-0000-0000-0000-00000000000a", "role": "authenticated"}';

-- 12-15: closing.
select results_eq(
  $$ select own_volume_target, own_volume_actual, prospects_actual,
            customers_actual, team_members_actual, loyalty_actual,
            team_volume_actual, level_actual, closed_at is not null
     from public.close_month('2026-10-01',
       now() - interval '1 hour', now() + interval '1 hour', 1200, ' Elite ') $$,
  $$ values (500::numeric, 180.50::numeric, 1, 2, 1, 1, 1200::numeric,
             'Elite'::text, true) $$,
  'closing freezes the progress, keeps the targets, takes the typed actuals'
);
insert into public.activity (kind, amount, happened_on) values
  ('order', 20, '2026-10-20');
select is(
  (select own_volume_actual from public.month_plan where month = '2026-10-01'),
  180.50::numeric,
  'a later order does not move a closed month'
);
select throws_ok(
  $$ select public.close_month('2026-10-01',
       now() - interval '1 hour', now() + interval '1 hour', null, null) $$,
  'P0001', null,
  'a month closes once'
);
select is(
  (select prospects_actual from public.close_month('2026-08-01',
     '2026-07-31 22:00+00', '2026-08-31 22:00+00', null, '')),
  0,
  'a month with no plan closes into a new record'
);

select * from finish();
rollback;

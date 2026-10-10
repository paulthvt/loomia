-- LRP on the contact (#255): loyalty_since is a fact on the person, set by
-- hand through set_loyalty or by the first loyalty step, and what Goals count.
-- Run with `supabase test db`.
begin;
create extension if not exists pgtap with schema extensions;
select plan(21);

insert into auth.users (id, email) values
  ('00000000-0000-0000-0000-00000000000a', 'a@example.com'),
  ('00000000-0000-0000-0000-00000000000b', 'b@example.com');

set local role authenticated;
set local request.jwt.claims =
  '{"sub": "00000000-0000-0000-0000-00000000000a", "role": "authenticated"}';

select has_column('public', 'person', 'loyalty_since', 'person has loyalty_since');

-- A workflow with two loyalty steps, and one that starts on one.
insert into public.workflow (id, stage, name) values
  ('00000000-0000-0000-0000-0000000000f1', 'customer', 'Two setups'),
  ('00000000-0000-0000-0000-0000000000f2', 'customer', 'Straight in');
insert into public.workflow_step (id, workflow_id, position, label, days, loyalty_setup) values
  ('00000000-0000-0000-0000-0000000000e1',
   '00000000-0000-0000-0000-0000000000f1', 1, 'Set up their LRP', 0, true),
  ('00000000-0000-0000-0000-0000000000e2',
   '00000000-0000-0000-0000-0000000000f1', 2, 'Check the LRP', 7, true),
  ('00000000-0000-0000-0000-0000000000e3',
   '00000000-0000-0000-0000-0000000000f2', 1, 'Set up their LRP', 0, true);
insert into public.person (id, name, stage, workflow_id, at_position, last_tick) values
  ('00000000-0000-0000-0000-0000000000a1', 'Claire', 'customer',
   '00000000-0000-0000-0000-0000000000f1', 1, '2026-10-02'),
  ('00000000-0000-0000-0000-0000000000a4', 'Diane', 'customer',
   '00000000-0000-0000-0000-0000000000f2', 1, '2026-10-01');
insert into public.person (id, name, stage) values
  ('00000000-0000-0000-0000-0000000000a2', 'Amélie', 'customer'),
  ('00000000-0000-0000-0000-0000000000a3', 'Bruno', 'customer'),
  ('00000000-0000-0000-0000-0000000000a6', 'Élise', 'customer'),
  ('00000000-0000-0000-0000-0000000000a7', 'Fanny', 'customer');

-- By hand: start, the same again, move, stop.
select public.set_loyalty(
  '00000000-0000-0000-0000-0000000000a2', '2026-10-02', '2026-10-10');
select is(
  (select loyalty_since from public.person
    where id = '00000000-0000-0000-0000-0000000000a2'),
  '2026-10-02'::date, 'set_loyalty starts it on the day given');
select results_eq(
  $$ select happened_on, text from public.activity
     where person_id = '00000000-0000-0000-0000-0000000000a2'
       and kind = 'loyalty_start' $$,
  $$ values ('2026-10-02'::date, null::text) $$,
  'and writes one start entry, without text');

select public.set_loyalty(
  '00000000-0000-0000-0000-0000000000a2', '2026-10-02', '2026-10-10');
select is(
  (select count(*)::int from public.activity
    where person_id = '00000000-0000-0000-0000-0000000000a2'),
  1, 'the same day again changes nothing');

select public.set_loyalty(
  '00000000-0000-0000-0000-0000000000a2', '2026-09-20', '2026-10-10');
select is(
  (select loyalty_since from public.person
    where id = '00000000-0000-0000-0000-0000000000a2'),
  '2026-09-20'::date, 'another day moves it');
select results_eq(
  $$ select happened_on from public.activity
     where person_id = '00000000-0000-0000-0000-0000000000a2' $$,
  $$ values ('2026-09-20'::date) $$,
  'and the start entry moves with it');

select public.set_loyalty(
  '00000000-0000-0000-0000-0000000000a2', null, '2026-10-10');
select is(
  (select loyalty_since from public.person
    where id = '00000000-0000-0000-0000-0000000000a2'),
  null::date, 'null stops it');
select results_eq(
  $$ select happened_on from public.activity
     where person_id = '00000000-0000-0000-0000-0000000000a2'
       and kind = 'loyalty_stop' $$,
  $$ values ('2026-10-10'::date) $$,
  'and writes a stop entry on today');

-- The app cannot write those entries itself.
select throws_ok(
  $$ insert into public.activity (person_id, kind) values
     ('00000000-0000-0000-0000-0000000000a2', 'loyalty_start') $$,
  '42501', null, 'the app cannot insert a loyalty entry');
update public.activity set happened_on = '2026-10-01'
  where kind = 'loyalty_start';
select is(
  (select happened_on from public.activity where kind = 'loyalty_start'),
  '2026-09-20'::date, 'nor edit one');
delete from public.activity where kind = 'loyalty_stop';
select is(
  (select count(*)::int from public.activity where kind = 'loyalty_stop'),
  1, 'nor delete one');

-- From the workflow: the first loyalty step starts it, the second leaves it.
select public.complete_step(
  '00000000-0000-0000-0000-0000000000a1',
  '00000000-0000-0000-0000-0000000000e1', '2026-10-02');
select is(
  (select loyalty_since from public.person
    where id = '00000000-0000-0000-0000-0000000000a1'),
  '2026-10-02'::date, 'a loyalty step starts it on the step''s day');
select public.complete_step(
  '00000000-0000-0000-0000-0000000000a1',
  '00000000-0000-0000-0000-0000000000e2', '2026-10-09');
select is(
  (select loyalty_since from public.person
    where id = '00000000-0000-0000-0000-0000000000a1'),
  '2026-10-02'::date, 'a second loyalty step leaves it');
select is(
  (select count(*)::int from public.activity
    where person_id = '00000000-0000-0000-0000-0000000000a1'
      and kind = 'loyalty_start'),
  1, 'and writes no second start entry');
select is(
  (select count(*)::int from public.activity
    where person_id = '00000000-0000-0000-0000-0000000000a1'
      and kind = 'step'),
  2, 'both steps keep their own entries');

-- Goals count people, in the month their LRP started.
select public.set_loyalty(
  '00000000-0000-0000-0000-0000000000a3', '2025-06-01', '2026-10-10');
select public.set_loyalty(
  '00000000-0000-0000-0000-0000000000a6', '2026-10-05', '2026-10-05');
select public.set_loyalty(
  '00000000-0000-0000-0000-0000000000a6', null, '2026-10-08');
select is(
  (select loyalty from public.month_progress(
     '2026-10-01', '2026-10-01', '2026-11-01')),
  1, 'October counts Claire once: not a backdated start, not one stopped');

-- The forecast skips someone who already has one.
select is(
  public.loyalty_forecast('2026-10-01'), 1,
  'Diane is likely to start one in October');
select public.set_loyalty(
  '00000000-0000-0000-0000-0000000000a4', '2026-10-03', '2026-10-03');
select is(
  public.loyalty_forecast('2026-10-01'), 0,
  'not once she has one');

-- A closed month does not move.
select public.close_month(
  '2026-08-01', '2026-08-01', '2026-09-01', null, null);
select public.set_loyalty(
  '00000000-0000-0000-0000-0000000000a3', '2026-08-10', '2026-10-10');
select is(
  (select loyalty_actual from public.month_plan where month = '2026-08-01'),
  0, 'an LRP backdated into a closed month leaves its record');

-- The backfill shape: someone with only a loyalty step entry and no start
-- entry gets one when the day moves.
update public.person set loyalty_since = '2026-10-04'
  where id = '00000000-0000-0000-0000-0000000000a7';
select public.set_loyalty(
  '00000000-0000-0000-0000-0000000000a7', '2026-10-06', '2026-10-10');
select is(
  (select count(*)::int from public.activity
    where person_id = '00000000-0000-0000-0000-0000000000a7'
      and kind = 'loyalty_start' and happened_on = '2026-10-06'),
  1, 'moving a start with no entry writes one');

-- Another owner's person is refused.
set local request.jwt.claims =
  '{"sub": "00000000-0000-0000-0000-00000000000b", "role": "authenticated"}';
select throws_ok(
  $$ select public.set_loyalty(
       '00000000-0000-0000-0000-0000000000a2', '2026-10-02', '2026-10-10') $$,
  'P0002', null, 'set_loyalty refuses another owner''s person');

select * from finish();
rollback;

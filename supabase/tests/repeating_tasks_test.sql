-- Repeating tasks (#376): complete_task makes the next one on the schedule,
-- undo_task takes it back unless it was touched, delete_task one or
-- following. Run with `supabase test db`.
begin;
create extension if not exists pgtap with schema extensions;
select plan(26);

insert into auth.users (id, email) values
  ('00000000-0000-0000-0000-00000000000a', 'a@example.com'),
  ('00000000-0000-0000-0000-00000000000b', 'b@example.com');

-- A whole test runs in one transaction, so now() never moves: this ages a
-- task's timestamps by a minute, as if made in an earlier transaction.
create function pg_temp.age(p_id uuid) returns void
language sql security definer as $$
  update public.task
    set created_at = created_at - interval '1 minute'
    where id = p_id;
  -- set_updated_at fires on the update above; age updated_at to match.
  alter table public.task disable trigger task_set_updated_at;
  update public.task set updated_at = created_at where id = p_id;
  alter table public.task enable trigger task_set_updated_at;
$$;

-- The task made from [p_id]'s tick.
create function pg_temp.next_of(p_id uuid) returns public.task
language sql security definer as $$
  select * from public.task where follows_id = p_id
$$;

set local role authenticated;
set local request.jwt.claims =
  '{"sub": "00000000-0000-0000-0000-00000000000a", "role": "authenticated"}';

-- Month end: counted from repeat_from, so Feb clamps and Mar goes back to 31.
insert into public.task
  (id, title, due_on, repeat_every, repeat_unit, repeat_from, scheduled_on)
values
  ('00000000-0000-0000-0000-0000000000e1', 'Pay the stand', '2026-01-31',
   1, 'month', '2026-01-31', '2026-01-31');
select complete_task('00000000-0000-0000-0000-0000000000e1', '2026-01-31');
select is(
  (pg_temp.next_of('00000000-0000-0000-0000-0000000000e1')).due_on,
  '2026-02-28'::date,
  'Jan 31 monthly: next is Feb 28'
);
select is(
  (pg_temp.next_of('00000000-0000-0000-0000-0000000000e1')).scheduled_on,
  '2026-02-28'::date,
  'the next one is scheduled on its due day'
);
select complete_task(
  (pg_temp.next_of('00000000-0000-0000-0000-0000000000e1')).id, '2026-02-28'
);
select is(
  (pg_temp.next_of(
    (pg_temp.next_of('00000000-0000-0000-0000-0000000000e1')).id
  )).due_on,
  '2026-03-31'::date,
  'after Feb 28, back to the 31st'
);

-- Postponed: due the 5th, scheduled the 3rd; the next is still the 3rd.
insert into public.task
  (id, title, note, due_on, repeat_every, repeat_unit, repeat_from, scheduled_on)
values
  ('00000000-0000-0000-0000-0000000000e2', 'Restock lavender', 'Two bottles',
   '2026-11-05', 1, 'month', '2026-10-03', '2026-11-03');
select is(
  (complete_task('00000000-0000-0000-0000-0000000000e2', '2026-11-05')).done_on,
  '2026-11-05'::date,
  'complete_task returns the ticked task'
);
select is(
  (pg_temp.next_of('00000000-0000-0000-0000-0000000000e2')).due_on,
  '2026-12-03'::date,
  'a postponed task keeps the schedule'
);
select results_eq(
  $$ select title, note, repeat_every, repeat_unit, repeat_from, repeat_until
     from pg_temp.next_of('00000000-0000-0000-0000-0000000000e2') $$,
  $$ values ('Restock lavender', 'Two bottles', 1, 'month', '2026-10-03'::date,
     null::date) $$,
  'the next one copies the title, note and rule'
);
select is(
  (select repeat_unit from public.task
    where id = '00000000-0000-0000-0000-0000000000e2'),
  'month',
  'the ticked task keeps its rule'
);

-- Late: March ticked on April 10 skips April.
insert into public.task
  (id, title, due_on, repeat_every, repeat_unit, repeat_from, scheduled_on)
values
  ('00000000-0000-0000-0000-0000000000e3', 'Late', '2026-03-03',
   1, 'month', '2026-01-03', '2026-03-03');
select complete_task('00000000-0000-0000-0000-0000000000e3', '2026-04-10');
select is(
  (pg_temp.next_of('00000000-0000-0000-0000-0000000000e3')).due_on,
  '2026-05-03'::date,
  'a late tick skips the dates it missed'
);

-- Early: ticked before its day, the next is the one after.
insert into public.task
  (id, title, due_on, repeat_every, repeat_unit, repeat_from, scheduled_on)
values
  ('00000000-0000-0000-0000-0000000000e4', 'Early', '2026-11-03',
   2, 'week', '2026-11-03', '2026-11-03');
select complete_task('00000000-0000-0000-0000-0000000000e4', '2026-10-30');
select is(
  (pg_temp.next_of('00000000-0000-0000-0000-0000000000e4')).due_on,
  '2026-11-17'::date,
  'an early tick: the next date after its day'
);

-- Leap day, yearly: Feb 28 in other years, Feb 29 again in 2032.
insert into public.task
  (id, title, due_on, repeat_every, repeat_unit, repeat_from, scheduled_on)
values
  ('00000000-0000-0000-0000-0000000000e5', 'Leap', '2031-02-28',
   1, 'year', '2028-02-29', '2031-02-28');
select complete_task('00000000-0000-0000-0000-0000000000e5', '2031-02-28');
select is(
  (pg_temp.next_of('00000000-0000-0000-0000-0000000000e5')).due_on,
  '2032-02-29'::date,
  'yearly from Feb 29 comes back to Feb 29'
);

-- Daily, from long ago: still ends, on the day after the tick.
insert into public.task
  (id, title, due_on, repeat_every, repeat_unit, repeat_from, scheduled_on)
values
  ('00000000-0000-0000-0000-0000000000e6', 'Daily', '2026-10-26',
   1, 'day', '2000-01-01', '2026-10-26');
select complete_task('00000000-0000-0000-0000-0000000000e6', '2026-10-26');
select is(
  (pg_temp.next_of('00000000-0000-0000-0000-0000000000e6')).due_on,
  '2026-10-27'::date,
  'daily: the next day'
);

-- Ends: the next date is past repeat_until, so nothing is made.
insert into public.task
  (id, title, due_on, repeat_every, repeat_unit, repeat_from, repeat_until,
   scheduled_on)
values
  ('00000000-0000-0000-0000-0000000000e7', 'Ends', '2026-11-03',
   1, 'month', '2026-10-03', '2026-11-30', '2026-11-03');
select complete_task('00000000-0000-0000-0000-0000000000e7', '2026-11-03');
select is(
  (select count(*)::int from public.task
    where follows_id = '00000000-0000-0000-0000-0000000000e7'),
  0,
  'past the end date, ticking makes nothing'
);

-- A plain task: complete_task only ticks.
insert into public.task (id, title, due_on) values
  ('00000000-0000-0000-0000-0000000000e8', 'Order flyers', '2026-11-03');
select complete_task('00000000-0000-0000-0000-0000000000e8', '2026-11-03');
select is(
  (select count(*)::int from public.task
    where follows_id = '00000000-0000-0000-0000-0000000000e8'),
  0,
  'a plain task makes nothing'
);
select throws_ok(
  $$ select complete_task('00000000-0000-0000-0000-0000000000e8', '2026-11-04') $$,
  'P0002', null,
  'a done task cannot be completed again'
);

-- Undo, next untouched: it goes, the old one is back with its rule.
select undo_task('00000000-0000-0000-0000-0000000000e2');
select results_eq(
  $$ select done_on, repeat_unit from public.task
     where id = '00000000-0000-0000-0000-0000000000e2' $$,
  $$ values (null::date, 'month') $$,
  'undo reopens the task with its rule'
);
select is(
  (select count(*)::int from public.task
    where follows_id = '00000000-0000-0000-0000-0000000000e2'),
  0,
  'undo deletes the untouched next one'
);

-- Undo, next edited later: it stays, the old one comes back plain.
select complete_task('00000000-0000-0000-0000-0000000000e2', '2026-11-05');
reset role;
select pg_temp.age((pg_temp.next_of('00000000-0000-0000-0000-0000000000e2')).id);
set local role authenticated;
update public.task set note = 'Three bottles'
  where follows_id = '00000000-0000-0000-0000-0000000000e2';
select undo_task('00000000-0000-0000-0000-0000000000e2');
select is(
  (pg_temp.next_of('00000000-0000-0000-0000-0000000000e2')).note,
  'Three bottles',
  'undo keeps an edited next one'
);
select results_eq(
  $$ select done_on, repeat_unit from public.task
     where id = '00000000-0000-0000-0000-0000000000e2' $$,
  $$ values (null::date, null::text) $$,
  'and the old one comes back without a rule'
);

-- Undo, next ticked: it stays.
select undo_task('00000000-0000-0000-0000-0000000000e4');
select ok(
  (pg_temp.next_of('00000000-0000-0000-0000-0000000000e4')) is null,
  'undo deletes an untouched weekly next one'
);
select complete_task('00000000-0000-0000-0000-0000000000e4', '2026-11-03');
select complete_task(
  (pg_temp.next_of('00000000-0000-0000-0000-0000000000e4')).id, '2026-11-17'
);
select undo_task('00000000-0000-0000-0000-0000000000e4');
select isnt(
  (pg_temp.next_of('00000000-0000-0000-0000-0000000000e4')).done_on,
  null,
  'undo keeps a ticked next one'
);

-- Delete this one: the next is made. Delete following: nothing is.
insert into public.task
  (id, title, due_on, repeat_every, repeat_unit, repeat_from, scheduled_on)
values
  ('00000000-0000-0000-0000-0000000000e9', 'Delete one', '2026-11-03',
   1, 'month', '2026-11-03', '2026-11-03'),
  ('00000000-0000-0000-0000-0000000000ea', 'Delete following', '2026-11-03',
   1, 'month', '2026-11-03', '2026-11-03');
select delete_task('00000000-0000-0000-0000-0000000000e9', '2026-11-01', false);
select results_eq(
  $$ select due_on from public.task where title = 'Delete one' $$,
  $$ values ('2026-12-03'::date) $$,
  'delete this task: it goes, the next one is made'
);
select delete_task('00000000-0000-0000-0000-0000000000ea', '2026-11-01', true);
select is(
  (select count(*)::int from public.task where title = 'Delete following'),
  0,
  'delete this and following: the repeat ends'
);

-- The rule is whole or absent; follows_id is the functions' alone.
select throws_ok(
  $$ insert into public.task (title, due_on, repeat_every) values
     ('Half', '2026-11-03', 1) $$,
  '23514', null,
  'a partial rule is refused'
);
select throws_ok(
  $$ update public.task set follows_id = null
     where id = '00000000-0000-0000-0000-0000000000e1' $$,
  '42501', null,
  'follows_id is not updatable'
);

-- Another owner's task is invisible to these functions.
set local request.jwt.claims =
  '{"sub": "00000000-0000-0000-0000-00000000000b", "role": "authenticated"}';
select throws_ok(
  $$ select complete_task('00000000-0000-0000-0000-0000000000e2', '2026-11-03') $$,
  'P0002', null,
  'another user''s task cannot be completed'
);
select throws_ok(
  $$ select undo_task('00000000-0000-0000-0000-0000000000e1') $$,
  'P0002', null,
  'another user''s task cannot be undone'
);

select * from finish();
rollback;

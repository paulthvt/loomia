-- Event steps (#315): a step planned as an event waits while the person
-- attends an open event of its type, moves on when that event is done with
-- them there, is due again when they missed it, and can be put off.
-- Run with `supabase test db`.
begin;
create extension if not exists pgtap with schema extensions;
select plan(17);

insert into auth.users (id, email) values
  ('00000000-0000-0000-0000-00000000000a', 'a@example.com');

set local role authenticated;
set local request.jwt.claims =
  '{"sub": "00000000-0000-0000-0000-00000000000a", "role": "authenticated"}';

insert into public.event_workflow (id, name, is_group) values
  ('00000000-0000-0000-0000-0000000000c1', 'Unboxing call', false),
  ('00000000-0000-0000-0000-0000000000c2', 'Workshop', true);
insert into public.workflow (id, stage, name) values
  ('00000000-0000-0000-0000-0000000000f1', 'customer', 'New customer');
insert into public.workflow_step
  (id, workflow_id, position, label, days, event_workflow_id) values
  ('00000000-0000-0000-0000-0000000000d1', '00000000-0000-0000-0000-0000000000f1',
   1, 'Book the unboxing call', 0, '00000000-0000-0000-0000-0000000000c1'),
  ('00000000-0000-0000-0000-0000000000d2', '00000000-0000-0000-0000-0000000000f1',
   2, 'Give access', 0, null),
  ('00000000-0000-0000-0000-0000000000d3', '00000000-0000-0000-0000-0000000000f1',
   3, 'Propose a consultation', 15, null);
insert into public.person
  (id, name, stage, workflow_id, at_position, last_tick) values
  ('00000000-0000-0000-0000-0000000000a1', 'Julie', 'customer',
   '00000000-0000-0000-0000-0000000000f1', 1, '2026-10-01'),
  ('00000000-0000-0000-0000-0000000000a2', 'Inès', 'customer',
   '00000000-0000-0000-0000-0000000000f1', 1, '2026-10-01'),
  ('00000000-0000-0000-0000-0000000000a3', 'Léa', 'customer',
   '00000000-0000-0000-0000-0000000000f1', 2, '2026-10-01'),
  ('00000000-0000-0000-0000-0000000000a4', 'Nora', 'customer',
   '00000000-0000-0000-0000-0000000000f1', 1, '2026-10-01');

-- 1-2: not planned yet.
select is(
  (select p.due_on from public.person p
    where id = '00000000-0000-0000-0000-0000000000a1'),
  '2026-10-01'::date, 'an event step is due like any step'
);
select is(
  (select p.planned_event_id from public.person p
    where id = '00000000-0000-0000-0000-0000000000a1'),
  null, 'nothing planned'
);

insert into public.event (id, title, starts_at, event_workflow_id) values
  ('00000000-0000-0000-0000-0000000000e1', 'Unboxing call — Julie',
   '2026-10-08 17:00+00', '00000000-0000-0000-0000-0000000000c1'),
  ('00000000-0000-0000-0000-0000000000e2', 'Huiles et sommeil',
   '2026-10-09 17:00+00', '00000000-0000-0000-0000-0000000000c2');
insert into public.event_attendee (event_id, person_id) values
  ('00000000-0000-0000-0000-0000000000e1', '00000000-0000-0000-0000-0000000000a1'),
  ('00000000-0000-0000-0000-0000000000e1', '00000000-0000-0000-0000-0000000000a3'),
  ('00000000-0000-0000-0000-0000000000e1', '00000000-0000-0000-0000-0000000000a4'),
  ('00000000-0000-0000-0000-0000000000e2', '00000000-0000-0000-0000-0000000000a2');

-- 3-7: planned.
select is(
  (select p.planned_event_id from public.person p
    where id = '00000000-0000-0000-0000-0000000000a1'),
  '00000000-0000-0000-0000-0000000000e1'::uuid, 'the event planned for the step'
);
select is(
  (select p.due_on from public.person p
    where id = '00000000-0000-0000-0000-0000000000a1'),
  null, 'planned: the step waits'
);
select is(
  (select p.due_on from public.person p
    where id = '00000000-0000-0000-0000-0000000000a2'),
  '2026-10-01'::date, 'an event of another type plans nothing'
);
select is(
  (select p.planned_event_id from public.person p
    where id = '00000000-0000-0000-0000-0000000000a3'),
  null, 'a plain step is never planned'
);
reset role;
set local role service_role;
select is(
  public.due_people_count('00000000-0000-0000-0000-00000000000a', '2026-10-05'),
  2, 'the push leaves the planned out: Inès and Léa'
);
reset role;
set local role authenticated;
set local request.jwt.claims =
  '{"sub": "00000000-0000-0000-0000-00000000000a", "role": "authenticated"}';

-- 8-12: done with Julie there, without Nora.
select public.mark_event_done('00000000-0000-0000-0000-0000000000e1',
  array['00000000-0000-0000-0000-0000000000a1',
        '00000000-0000-0000-0000-0000000000a3']::uuid[], '2026-10-08');
select results_eq(
  $$ select p.current_step_id, p.last_tick from public.person p
     where id = '00000000-0000-0000-0000-0000000000a1' $$,
  $$ values ('00000000-0000-0000-0000-0000000000d2'::uuid, '2026-10-08'::date) $$,
  'there: past the event step, from the event''s day'
);
select results_eq(
  $$ select kind::text from public.activity
     where person_id = '00000000-0000-0000-0000-0000000000a1' $$,
  $$ values ('event') $$,
  'one Event entry, no Step entry'
);
select is(
  (select p.current_step_id from public.person p
    where id = '00000000-0000-0000-0000-0000000000a3'),
  '00000000-0000-0000-0000-0000000000d2'::uuid,
  'there on a plain step: it stays'
);
select results_eq(
  $$ select p.current_step_id, p.due_on from public.person p
     where id = '00000000-0000-0000-0000-0000000000a4' $$,
  $$ values ('00000000-0000-0000-0000-0000000000d1'::uuid, '2026-10-01'::date) $$,
  'missed it: the step is due again'
);
select is(
  (select p.planned_event_id from public.person p
    where id = '00000000-0000-0000-0000-0000000000a4'),
  null, 'a done event plans nothing'
);

-- 13-16: Later.
select is(
  (select p.due_on from public.postpone_step(
     '00000000-0000-0000-0000-0000000000a4',
     '00000000-0000-0000-0000-0000000000d1', '2026-10-20') p),
  '2026-10-20'::date, 'put off to the day picked'
);
select throws_ok(
  $$ select public.postpone_step('00000000-0000-0000-0000-0000000000a4',
       '00000000-0000-0000-0000-0000000000d3', '2026-10-20') $$,
  'P0002', null, 'only the current step'
);
select throws_ok(
  $$ select public.postpone_step('00000000-0000-0000-0000-0000000000a3',
       '00000000-0000-0000-0000-0000000000d2', '2026-10-20') $$,
  'P0001', null, 'only an event step'
);
select is(
  public.position_after('00000000-0000-0000-0000-0000000000d3'),
  1e9, 'past the last step of a workflow that ends'
);

-- 17: ticking still moves on by the same rule.
select is(
  (select p.current_step_id from public.complete_step(
     '00000000-0000-0000-0000-0000000000a3',
     '00000000-0000-0000-0000-0000000000d2', '2026-10-09') p),
  '00000000-0000-0000-0000-0000000000d3'::uuid, 'complete_step moves to the next'
);

select * from finish();
rollback;

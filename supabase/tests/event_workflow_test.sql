-- Event workflows (#153): an event's checklist and the workflows people who
-- were there start (mark_event_done, for builds before #318). Run with `supabase test db`.
begin;
create extension if not exists pgtap with schema extensions;
select plan(11);

insert into auth.users (id, email) values
  ('00000000-0000-0000-0000-00000000000a', 'a@example.com'),
  ('00000000-0000-0000-0000-00000000000b', 'b@example.com');

set local role authenticated;
set local request.jwt.claims =
  '{"sub": "00000000-0000-0000-0000-00000000000a", "role": "authenticated"}';

-- The workflows and Workshop as seeded before #319: what the stage mapping
-- (kept for builds before #318) acts on.
insert into public.workflow (id, stage, name, is_default) values
  ('00000000-0000-0000-0000-0000000000f1', 'prospect', 'Samples', true),
  ('00000000-0000-0000-0000-0000000000f2', 'prospect', 'Health professionals', false),
  ('00000000-0000-0000-0000-0000000000f3', 'customer', 'New customer', true),
  ('00000000-0000-0000-0000-0000000000f4', 'team', 'Getting started', true);
insert into public.workflow_step (workflow_id, position, label, days)
  select w.id, p.position, w.name || ' ' || p.position, 1
  from public.workflow w cross join (values (1), (2), (3)) as p(position);
insert into public.event_workflow
  (name, prospect_workflow_id, customer_workflow_id) values
  ('Workshop', '00000000-0000-0000-0000-0000000000f1',
   '00000000-0000-0000-0000-0000000000f3');
insert into public.event_workflow_step (event_workflow_id, label, days)
  select id, v.label, v.days from public.event_workflow,
    (values ('Remind everyone it''s tomorrow', -1),
            ('Send a thank-you and the notes', 1)) as v(label, days);

-- 6-7: constraints.
select throws_ok(
  $$ insert into public.event_workflow (name) values ('  ') $$,
  '23514', null,
  'an event workflow has a name'
);
select throws_ok(
  $$ insert into public.event_workflow_step (event_workflow_id, label, days)
     select id, 'Too far', 400 from public.event_workflow $$,
  '23514', null,
  'a step is within a year of the event'
);

-- 8-11: who was there starts the workflow for their stage.
insert into public.person (id, name, stage, workflow_id, at_position, last_tick, paused_at)
select '00000000-0000-0000-0000-0000000000a1', 'Claire', 'prospect', id, 3,
       '2026-09-01', now()
  from public.workflow where name = 'Health professionals';
insert into public.person (id, name, stage) values
  ('00000000-0000-0000-0000-0000000000a2', 'Marie', 'customer'),
  ('00000000-0000-0000-0000-0000000000a4', 'Léa', 'prospect');
insert into public.person (id, name, stage, workflow_id, at_position, last_tick)
select '00000000-0000-0000-0000-0000000000a3', 'Bruno', 'team', id, 2, '2026-09-01'
  from public.workflow where stage = 'team';

insert into public.event (id, title, starts_at, event_workflow_id,
                          prospect_workflow_id, customer_workflow_id)
select '00000000-0000-0000-0000-0000000000e1', 'Workshop', '2026-10-08 17:00+00',
       w.id, w.prospect_workflow_id, w.customer_workflow_id
  from public.event_workflow w;
insert into public.event_attendee (event_id, person_id)
select '00000000-0000-0000-0000-0000000000e1', id from public.person;
select public.mark_event_done(
  '00000000-0000-0000-0000-0000000000e1',
  array['00000000-0000-0000-0000-0000000000a1',
        '00000000-0000-0000-0000-0000000000a2',
        '00000000-0000-0000-0000-0000000000a3']::uuid[],
  '2026-10-09'
);

select results_eq(
  $$ select w.name, p.at_position, p.last_tick, p.paused_at is null
     from public.person p join public.workflow w on w.id = p.workflow_id
     where p.name = 'Claire' $$,
  $$ values ('Samples', 1::numeric, '2026-10-09'::date, true) $$,
  'a prospect who was there starts Samples at its first step, today, unpaused'
);
select is(
  (select w.name from public.person p join public.workflow w on w.id = p.workflow_id
   where p.name = 'Marie'),
  'New customer',
  'a customer who was there starts New customer'
);
select results_eq(
  $$ select w.name, p.at_position from public.person p
     join public.workflow w on w.id = p.workflow_id where p.name = 'Bruno' $$,
  $$ values ('Getting started', 2::numeric) $$,
  'no mapping for the team: Bruno keeps his workflow and his place'
);
select ok(
  (select workflow_id is null from public.person where name = 'Léa'),
  'someone who missed it is untouched'
);

-- 12-13: a deleted workflow reads as "keep their workflow".
delete from public.workflow where name = 'Samples';
select ok(
  (select prospect_workflow_id is null from public.event_workflow),
  'the event workflow forgets a deleted workflow'
);
select ok(
  (select prospect_workflow_id is null from public.event),
  'so does the event'
);

-- 14-15: ticking a checklist step.
select lives_ok(
  $$ insert into public.event_step_done (event_id, step_id, done_on)
     select '00000000-0000-0000-0000-0000000000e1', id, '2026-10-07'
     from public.event_workflow_step where days = -1 $$,
  'a step is ticked'
);
select throws_ok(
  $$ insert into public.event_step_done (event_id, step_id, done_on)
     select '00000000-0000-0000-0000-0000000000e1', id, '2026-10-07'
     from public.event_workflow_step where days = -1 $$,
  '23505', null,
  'a step is ticked once'
);

-- 16: as B.
set local request.jwt.claims =
  '{"sub": "00000000-0000-0000-0000-00000000000b", "role": "authenticated"}';
select is(
  (select count(*)::int from public.event_workflow)
  + (select count(*)::int from public.event_workflow_step)
  + (select count(*)::int from public.event_step_done),
  0,
  'another user sees none of it'
);

select * from finish();
rollback;

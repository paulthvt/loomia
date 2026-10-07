-- Event workflows (#153): an event's checklist, the workflows people who
-- were there start, and the seeded Workshop. Run with `supabase test db`.
begin;
create extension if not exists pgtap with schema extensions;
select plan(16);

insert into auth.users (id, email) values
  ('00000000-0000-0000-0000-00000000000a', 'a@example.com'),
  ('00000000-0000-0000-0000-00000000000b', 'b@example.com');

set local role authenticated;
set local request.jwt.claims =
  '{"sub": "00000000-0000-0000-0000-00000000000a", "role": "authenticated"}';

select public.seed_workflows('en', '2026-10-01');

-- 1-4: the seeded Workshop.
select is(
  (select count(*)::int from public.event_workflow where name = 'Workshop'), 1,
  'the seed creates Workshop'
);
select results_eq(
  $$ select s.label, s.days from public.event_workflow_step s
     join public.event_workflow w on w.id = s.event_workflow_id
     order by s.days $$,
  $$ values ('Remind everyone it''s tomorrow', -1),
            ('Send a thank-you and the notes', 1) $$,
  'with a reminder the day before and a thank-you the day after'
);
select is(
  (select prospect_workflow_id from public.event_workflow),
  (select id from public.workflow where stage = 'prospect' and is_default),
  'prospects who were there start the default prospect workflow'
);
select ok(
  (select team_workflow_id is null from public.event_workflow),
  'the team keeps their workflow'
);

-- 5: once.
select public.seed_workflows('en', '2026-10-02');
select is(
  (select count(*)::int from public.event_workflow), 1,
  'seeding again creates no second Workshop'
);

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
  (select count(*)::int
   from public.event_workflow, public.event_workflow_step, public.event_step_done),
  0,
  'another user sees none of it'
);

select * from finish();
rollback;

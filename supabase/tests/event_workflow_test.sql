-- Event workflows (#153): an event's checklist; the stage mapping is gone
-- (#329). Run with `supabase test db`.
begin;
create extension if not exists pgtap with schema extensions;
select plan(9);

insert into auth.users (id, email) values
  ('00000000-0000-0000-0000-00000000000a', 'a@example.com'),
  ('00000000-0000-0000-0000-00000000000b', 'b@example.com');

set local role authenticated;
set local request.jwt.claims =
  '{"sub": "00000000-0000-0000-0000-00000000000a", "role": "authenticated"}';

insert into public.event_workflow (name) values ('Workshop');
insert into public.event_workflow_step (event_workflow_id, label, days)
  select id, v.label, v.days from public.event_workflow,
    (values ('Remind everyone it''s tomorrow', -1),
            ('Send a thank-you and the notes', 1)) as v(label, days);
insert into public.event (id, title, starts_at, event_workflow_id)
  select '00000000-0000-0000-0000-0000000000e1', 'Workshop',
         '2026-10-08 17:00+00', id
  from public.event_workflow;

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

-- The stage → workflow mapping is gone (#329).
select hasnt_column('public', 'event_workflow', 'prospect_workflow_id',
  'event types map no workflow');
select hasnt_column('public', 'event', 'customer_workflow_id',
  'nor do events');
select hasnt_column('public', 'event_series', 'team_workflow_id',
  'nor do series');
select hasnt_function('public', 'mark_event_done', array['uuid', 'uuid[]', 'date'],
  'mark_event_done is gone: close_event marks events done');

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

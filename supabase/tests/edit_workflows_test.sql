-- Editing workflows (#59): seeded once per account, ever; set_default moves a
-- stage's default; edits reach people through current_step_id.
-- Run with `supabase test db`.
begin;
create extension if not exists pgtap with schema extensions;
select plan(22);

insert into auth.users (id, email) values
  ('00000000-0000-0000-0000-00000000000a', 'a@example.com'),
  ('00000000-0000-0000-0000-00000000000b', 'b@example.com');

-- As A.
set local role authenticated;
set local request.jwt.claims =
  '{"sub": "00000000-0000-0000-0000-00000000000a", "role": "authenticated"}';

insert into public.person (id, name, stage) values
  ('00000000-0000-0000-0000-0000000000a1', 'Sarah', 'prospect');

-- 1-3: the marker.
select lives_ok(
  $$ select public.seed_workflows('en', '2026-09-29') $$,
  'the first seed runs'
);
select is(
  (select count(*)::int from public.workflow_seeded), 1,
  'the seed writes the marker'
);
select public.seed_workflows('en', '2026-09-29');
select is(
  (select count(*)::int from public.workflow), 8,
  'a second seed no-ops'
);
-- The seed places nobody (#319): Sarah starts Samples here.
update public.person
  set workflow_id = (select id from public.workflow where name = 'Samples'),
      at_position = 1, last_tick = '2026-09-29'
  where id = '00000000-0000-0000-0000-0000000000a1';

-- 4-8: set_default.
select lives_ok(
  $$ select public.set_default(
       (select id from public.workflow where name = 'Wellness check'),
       true) $$,
  'set_default on runs'
);
select results_eq(
  $$ select name from public.workflow
     where stage = 'prospect' and is_default $$,
  $$ values ('Wellness check'::text) $$,
  'on moves the stage''s default'
);
select is(
  (select count(*)::int from public.workflow where is_default), 3,
  'the other stages keep their default'
);
select lives_ok(
  $$ select public.set_default(
       (select id from public.workflow where name = 'Wellness check'),
       false) $$,
  'set_default off runs'
);
select is(
  (select count(*)::int from public.workflow
    where stage = 'prospect' and is_default), 0,
  'off leaves the stage without a default'
);

-- 9: Sarah is on Samples at position 1. Moving that step after the next
-- one leaves her on what now sits at her place.
update public.workflow_step set position = 2.5
  where label = 'First contact (offer)';
select is(
  (select s.label from public.person p
     join public.workflow_step s on s.id = public.current_step_id(p)
    where p.id = '00000000-0000-0000-0000-0000000000a1'),
  'Prepare and send',
  'moving the current step moves the person on'
);

-- 10: unknown id.
select throws_ok(
  $$ select public.set_default('00000000-0000-0000-0000-0000000000ff', true) $$,
  'P0002', null,
  'an unknown workflow raises P0002'
);

-- A workflow with a known id, for B.
insert into public.workflow (id, stage, name) values
  ('00000000-0000-0000-0000-0000000000f1', 'team', 'Own');

-- As B.
set local request.jwt.claims =
  '{"sub": "00000000-0000-0000-0000-00000000000b", "role": "authenticated"}';

-- 11-13.
select throws_ok(
  $$ select public.set_default('00000000-0000-0000-0000-0000000000f1', true) $$,
  'P0002', null,
  'another user''s workflow raises P0002'
);
select is(
  (select count(*)::int from public.workflow_seeded), 0,
  'another user''s marker is hidden'
);
select throws_ok(
  $$ insert into public.workflow_seeded (owner_id)
     values ('00000000-0000-0000-0000-00000000000a') $$,
  '42501', null,
  'a marker cannot be written for another user'
);

-- Back as A.
set local request.jwt.claims =
  '{"sub": "00000000-0000-0000-0000-00000000000a", "role": "authenticated"}';

-- 14.
select is(
  (select is_default from public.workflow
    where id = '00000000-0000-0000-0000-0000000000f1'), false,
  'the refused call changed nothing'
);

-- 15-16: finishing is for good. Tom ticks both steps of Own, then a step is
-- added at the end, then an earlier one is moved there.
insert into public.workflow_step (id, workflow_id, position, label, days) values
  ('00000000-0000-0000-0000-0000000000e1',
   '00000000-0000-0000-0000-0000000000f1', 1, 'One', 0),
  ('00000000-0000-0000-0000-0000000000e2',
   '00000000-0000-0000-0000-0000000000f1', 2, 'Two', 0);
insert into public.person (id, name, stage, workflow_id, at_position, last_tick)
  values ('00000000-0000-0000-0000-0000000000a2', 'Tom', 'team',
          '00000000-0000-0000-0000-0000000000f1', 1, '2026-09-29');
select public.complete_step('00000000-0000-0000-0000-0000000000a2',
  '00000000-0000-0000-0000-0000000000e1', '2026-09-29');
select public.complete_step('00000000-0000-0000-0000-0000000000a2',
  '00000000-0000-0000-0000-0000000000e2', '2026-09-29');

insert into public.workflow_step (workflow_id, position, label, days) values
  ('00000000-0000-0000-0000-0000000000f1', 3, 'Three', 0);
select is(
  (select public.current_step_id(p) from public.person p
    where p.id = '00000000-0000-0000-0000-0000000000a2'),
  null,
  'a step added at the end does not bring back someone who finished'
);

update public.workflow_step set position = 4
  where id = '00000000-0000-0000-0000-0000000000e1';
select is(
  (select public.current_step_id(p) from public.person p
    where p.id = '00000000-0000-0000-0000-0000000000a2'),
  null,
  'a step moved to the end does not bring back someone who finished'
);

-- 17: deleting a workflow.
delete from public.workflow where name = 'Samples';
select is(
  (select count(*)::int from public.person
    where id = '00000000-0000-0000-0000-0000000000a1'
      and workflow_id is null), 1,
  'deleting a workflow clears its people''s workflow_id'
);

-- 18: the #57 carry-over.
delete from public.workflow;
select public.seed_workflows('en', '2026-09-29');
select is(
  (select count(*)::int from public.workflow), 0,
  'after deleting every workflow, seed still no-ops'
);

-- 19.
select throws_ok(
  'delete from public.workflow_seeded', '42501', null,
  'the marker cannot be deleted'
);

-- 20-21: as anon.
reset role;
set local role anon;
set local request.jwt.claims = '{"role": "anon"}';

select throws_ok(
  $$ select public.set_default('00000000-0000-0000-0000-0000000000f1', true) $$,
  '42501', null,
  'anon cannot call set_default'
);
select throws_ok(
  'select * from public.workflow_seeded', '42501', null,
  'anon cannot read the marker'
);

reset role;

-- 22.
select table_privs_are(
  'public', 'workflow_seeded', 'authenticated',
  ARRAY['SELECT', 'INSERT'],
  'authenticated has only SELECT, INSERT on workflow_seeded'
);

select * from finish();
rollback;

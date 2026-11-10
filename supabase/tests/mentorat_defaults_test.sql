-- Mentorat for accounts seeded before #483: backfill_mentorat adds the type,
-- plans it as onboarding's step 4 and removes the seeded check-in workflows.
-- The old seed is gone, so its rows are inserted by hand.
-- Run with `supabase test db`.
begin;
create extension if not exists pgtap with schema extensions;
select plan(16);

insert into auth.users (id, email) values
  ('00000000-0000-0000-0000-00000000000a', 'a@example.com'),
  ('00000000-0000-0000-0000-00000000000b', 'b@example.com'),
  ('00000000-0000-0000-0000-00000000000c', 'c@example.com');

-- A: French, seeded before.
insert into public.event_workflow (owner_id, name, is_group) values
  ('00000000-0000-0000-0000-00000000000a', 'Atelier', true),
  ('00000000-0000-0000-0000-00000000000a', 'Appel mentorat', false);
insert into public.workflow (id, owner_id, stage, name, is_default, repeats) values
  ('00000000-0000-0000-0000-0000000000f1', '00000000-0000-0000-0000-00000000000a',
   'team', 'Onboarding', true, false),
  ('00000000-0000-0000-0000-0000000000f2', '00000000-0000-0000-0000-00000000000a',
   'team', 'Suivi équipe — hebdo', false, true);
insert into public.workflow_step (owner_id, workflow_id, position, label, days) values
  ('00000000-0000-0000-0000-00000000000a', '00000000-0000-0000-0000-0000000000f1',
   1, 'Caler l''appel d''unboxing', 0),
  ('00000000-0000-0000-0000-00000000000a', '00000000-0000-0000-0000-0000000000f1',
   2, 'Donner l''accès à la formation', 0),
  ('00000000-0000-0000-0000-00000000000a', '00000000-0000-0000-0000-0000000000f1',
   3, 'Proposer une consultation bien-être', 7),
  ('00000000-0000-0000-0000-00000000000a', '00000000-0000-0000-0000-0000000000f2',
   1, 'Point', 7);
insert into public.workflow_next (owner_id, workflow_id, next_workflow_id) values
  ('00000000-0000-0000-0000-00000000000a', '00000000-0000-0000-0000-0000000000f1',
   '00000000-0000-0000-0000-0000000000f2');
insert into public.person
  (id, owner_id, name, stage, workflow_id, at_position, last_tick, paused_at) values
  ('00000000-0000-0000-0000-0000000000a1', '00000000-0000-0000-0000-00000000000a',
   'Julie', 'team', '00000000-0000-0000-0000-0000000000f2', 1, '2026-11-01', now()),
  ('00000000-0000-0000-0000-0000000000a2', '00000000-0000-0000-0000-00000000000a',
   'Léa', 'team', '00000000-0000-0000-0000-0000000000f1', 1e9, '2026-11-01', null);
insert into public.activity (owner_id, person_id, kind, text) values
  ('00000000-0000-0000-0000-00000000000a', '00000000-0000-0000-0000-0000000000a1',
   'step', 'Point');

-- B: English, seeded before.
insert into public.workflow (id, owner_id, stage, name, is_default, repeats) values
  ('00000000-0000-0000-0000-0000000000f3', '00000000-0000-0000-0000-00000000000b',
   'team', 'Onboarding', true, false),
  ('00000000-0000-0000-0000-0000000000f4', '00000000-0000-0000-0000-00000000000b',
   'team', 'Team check-in — weekly', false, true);
insert into public.workflow_step (owner_id, workflow_id, position, label, days) values
  ('00000000-0000-0000-0000-00000000000b', '00000000-0000-0000-0000-0000000000f3',
   1, 'Book the unboxing call', 0),
  ('00000000-0000-0000-0000-00000000000b', '00000000-0000-0000-0000-0000000000f3',
   2.5, 'Give access to the training', 0);

-- C: renamed everything, no Onboarding.
insert into public.workflow (owner_id, stage, name) values
  ('00000000-0000-0000-0000-00000000000c', 'prospect', 'Mes prospects');

select public.backfill_mentorat('00000000-0000-0000-0000-00000000000a');
select public.backfill_mentorat('00000000-0000-0000-0000-00000000000a');
select public.backfill_mentorat('00000000-0000-0000-0000-00000000000b');
select public.backfill_mentorat('00000000-0000-0000-0000-00000000000c');

-- 1-2: A gets Mentorat once, French fields, no checklist.
select results_eq(
  $$ select name, is_group, report_fields from public.event_workflow
     where owner_id = '00000000-0000-0000-0000-00000000000a'
       and name in ('Mentorat', 'Mentoring') $$,
  $$ values ('Mentorat', false, array['Sujets abordés',
       'Actions faites / en cours et prévues', 'Problématiques rencontrées',
       'À faire', 'Divers']) $$,
  'A: one Mentorat with the French fields, even run twice'
);
select is(
  (select count(*)::int from public.event_workflow_step s
     join public.event_workflow w on w.id = s.event_workflow_id
     where w.name = 'Mentorat'), 0,
  'Mentorat has no checklist'
);

-- 3: onboarding plans it as step 4.
select results_eq(
  $$ select s.position, s.label, s.days, e.name from public.workflow_step s
     left join public.event_workflow e on e.id = s.event_workflow_id
     where s.workflow_id = '00000000-0000-0000-0000-0000000000f1'
     order by s.position $$,
  $$ values (1::numeric, 'Caler l''appel d''unboxing', 0, null::text),
            (2::numeric, 'Donner l''accès à la formation', 0, null),
            (3::numeric, 'Proposer une consultation bien-être', 7, null),
            (4::numeric, 'Planifier le mentorat', 0, 'Mentorat') $$,
  'A: step 4 appended once, planned as a Mentorat'
);

-- 4: someone done with onboarding stays done.
select is(
  (select public.current_step_id(p) from public.person p
     where id = '00000000-0000-0000-0000-0000000000a2'), null,
  'Léa, done with onboarding, is not pulled back to step 4'
);

-- 5-8: the check-in is gone; Julie is on nothing; her history stays.
select is_empty(
  $$ select 1 from public.workflow
     where owner_id = '00000000-0000-0000-0000-00000000000a'
       and name = 'Suivi équipe — hebdo' $$,
  'A: the check-in workflow is removed'
);
select results_eq(
  $$ select workflow_id, at_position, last_tick, paused_at from public.person
     where id = '00000000-0000-0000-0000-0000000000a1' $$,
  $$ values (null::uuid, null::numeric, null::date, null::timestamptz) $$,
  'Julie is on no workflow, nor paused on one'
);
select is(
  (select count(*)::int from public.activity
     where person_id = '00000000-0000-0000-0000-0000000000a1'), 1,
  'Julie keeps her history'
);
select is_empty(
  $$ select 1 from public.workflow_next
     where owner_id = '00000000-0000-0000-0000-00000000000a' $$,
  'A: Onboarding no longer leads to a check-in'
);

-- 9: the user's own type is untouched.
select results_eq(
  $$ select is_group, report_fields from public.event_workflow
     where name = 'Appel mentorat' $$,
  $$ values (false, '{}'::text[]) $$,
  'Appel mentorat untouched'
);

-- 10-12: B in English.
select results_eq(
  $$ select name, report_fields from public.event_workflow
     where owner_id = '00000000-0000-0000-0000-00000000000b' $$,
  $$ values ('Mentoring', array['Topics covered',
       'Actions done, in progress and planned', 'Issues encountered',
       'To do', 'Other']) $$,
  'B: Mentoring with the English fields'
);
select results_eq(
  $$ select s.position, s.label, e.name from public.workflow_step s
     left join public.event_workflow e on e.id = s.event_workflow_id
     where s.workflow_id = '00000000-0000-0000-0000-0000000000f3'
     order by s.position $$,
  $$ values (1::numeric, 'Book the unboxing call', null::text),
            (2.5, 'Give access to the training', null),
            (3.5, 'Plan the mentoring', 'Mentoring') $$,
  'B: step appended after the last one'
);
select is_empty(
  $$ select 1 from public.workflow
     where owner_id = '00000000-0000-0000-0000-00000000000b'
       and name = 'Team check-in — weekly' $$,
  'B: the check-in workflow is removed'
);

-- 13-14: C, no seeded names: English, nothing else touched.
select results_eq(
  $$ select name from public.event_workflow
     where owner_id = '00000000-0000-0000-0000-00000000000c' $$,
  $$ values ('Mentoring') $$,
  'C: no seeded names, English'
);
select results_eq(
  $$ select name from public.workflow
     where owner_id = '00000000-0000-0000-0000-00000000000c' $$,
  $$ values ('Mes prospects') $$,
  'C: own workflow kept, no onboarding added'
);

-- 15-16: migration-only.
select ok(
  not has_function_privilege('authenticated',
    'public.backfill_mentorat(uuid)', 'execute'),
  'authenticated cannot run the backfill'
);
select ok(
  not has_function_privilege('anon',
    'public.backfill_mentorat(uuid)', 'execute'),
  'anon cannot run the backfill'
);

select * from finish();
rollback;

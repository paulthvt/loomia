-- Workflows: each user's own, seeded once, a person's place moved by
-- complete_step, and cleaned up by deletes and stage changes.
-- Run with `supabase test db`.
begin;
create extension if not exists pgtap with schema extensions;
select plan(24);

insert into auth.users (id, email) values
  ('00000000-0000-0000-0000-00000000000a', 'a@example.com'),
  ('00000000-0000-0000-0000-00000000000b', 'b@example.com');

-- As A.
set local role authenticated;
set local request.jwt.claims =
  '{"sub": "00000000-0000-0000-0000-00000000000a", "role": "authenticated"}';

insert into public.person (id, name, stage) values
  ('00000000-0000-0000-0000-0000000000a1', 'Sarah', 'prospect'),
  ('00000000-0000-0000-0000-0000000000a2', 'Claire', 'customer');

select lives_ok(
  $$ select public.seed_workflows('en', '2026-09-29') $$,
  'the first seed runs'
);
select lives_ok(
  $$ select public.seed_workflows('en', '2026-09-29') $$,
  'a second seed runs'
);
select is(
  (select count(*)::int from public.workflow), 8,
  'seeding twice inserts the eight workflows once'
);
select is(
  (select count(*)::int from public.workflow where is_default), 3,
  'one default per stage'
);
select is(
  (select count(*)::int from public.workflow_step), 16,
  'the steps come along'
);
select is(
  (select count(*)::int from public.person where workflow_id is not null), 0,
  'the seed places nobody (#319)'
);
update public.person
  set workflow_id = (select id from public.workflow where name = 'Samples'),
      at_position = 1, last_tick = '2026-09-29'
  where id = '00000000-0000-0000-0000-0000000000a1';
update public.person
  set workflow_id = (select id from public.workflow where name = 'New customer'),
      at_position = 1, last_tick = '2026-09-29'
  where id = '00000000-0000-0000-0000-0000000000a2';
select throws_ok(
  $$ insert into public.workflow (stage, name, is_default)
     values ('prospect', 'Another', true) $$,
  '23505', null,
  'a stage has at most one default'
);

-- A workflow with a known id, for the foreign key tests as B.
insert into public.workflow (id, stage, name) values
  ('00000000-0000-0000-0000-0000000000f1', 'team', 'Own');

select lives_ok(
  $$ select public.complete_step(
       '00000000-0000-0000-0000-0000000000a1',
       (select s.id from public.workflow_step s
          join public.workflow w on w.id = s.workflow_id
          where w.name = 'Samples' and s.position = 1),
       '2026-09-30') $$,
  'complete_step runs'
);
select is(
  (select text from public.activity where kind = 'step'),
  'First contact (offer)',
  'complete_step writes one step entry with the label'
);
select results_eq(
  $$ select at_position, last_tick from public.person
     where id = '00000000-0000-0000-0000-0000000000a1' $$,
  $$ values (2::numeric, '2026-09-30'::date) $$,
  'complete_step moves the person'
);
select throws_ok(
  $$ select public.complete_step(
       '00000000-0000-0000-0000-0000000000a1',
       (select s.id from public.workflow_step s
          join public.workflow w on w.id = s.workflow_id
          where w.name = 'Health professionals' and s.position = 1),
       '2026-09-30') $$,
  'P0002', null,
  'complete_step refuses a step of another workflow'
);

update public.person set paused_at = now()
  where id = '00000000-0000-0000-0000-0000000000a1';
update public.person set stage = 'customer'
  where id = '00000000-0000-0000-0000-0000000000a1';

select is(
  (select paused_at from public.person
    where id = '00000000-0000-0000-0000-0000000000a1'), null,
  'a stage change clears paused_at'
);

-- As B.
set local request.jwt.claims =
  '{"sub": "00000000-0000-0000-0000-00000000000b", "role": "authenticated"}';

select is(
  (select count(*)::int from public.workflow), 0,
  'another user sees none of the workflows'
);
select is(
  (select count(*)::int from public.workflow_step), 0,
  'another user sees none of the steps'
);
update public.workflow set name = 'Stolen';
delete from public.workflow;
select throws_ok(
  $$ insert into public.workflow_step (workflow_id, position, label, days)
     values ('00000000-0000-0000-0000-0000000000f1', 1, 'Mine', 0) $$,
  '23503', null,
  'a step cannot point at another user''s workflow'
);
select throws_ok(
  $$ insert into public.person (name, stage, workflow_id)
     values ('Bea', 'team', '00000000-0000-0000-0000-0000000000f1') $$,
  '23503', null,
  'a person cannot point at another user''s workflow'
);
select public.seed_workflows('fr', '2026-09-29');
select is(
  (select count(*)::int from public.workflow where name = 'Échantillons'), 1,
  'the seed speaks French when asked'
);

-- Back as A.
set local request.jwt.claims =
  '{"sub": "00000000-0000-0000-0000-00000000000a", "role": "authenticated"}';

select is(
  (select count(*)::int from public.workflow where name <> 'Stolen'), 9,
  'another user cannot update or delete the workflows'
);

delete from public.workflow where name = 'New customer';

select is(
  (select count(*)::int from public.person
    where id = '00000000-0000-0000-0000-0000000000a2'
      and workflow_id is null), 1,
  'deleting a workflow sets its people''s workflow_id to null'
);

-- As anon.
set local role anon;
set local request.jwt.claims = '{"role": "anon"}';

select throws_ok(
  'select * from public.workflow', '42501', null,
  'anon cannot read workflows'
);
select throws_ok(
  'select * from public.workflow_step', '42501', null,
  'anon cannot read steps'
);
select throws_ok(
  $$ select public.seed_workflows('en', '2026-09-29') $$, '42501', null,
  'anon cannot seed'
);

reset role;

select table_privs_are(
  'public', 'workflow', 'authenticated',
  ARRAY['SELECT', 'INSERT', 'UPDATE', 'DELETE'],
  'authenticated has only SELECT, INSERT, UPDATE, DELETE on workflow'
);
select table_privs_are(
  'public', 'workflow_step', 'authenticated',
  ARRAY['SELECT', 'INSERT', 'UPDATE', 'DELETE'],
  'authenticated has only SELECT, INSERT, UPDATE, DELETE on workflow_step'
);

select * from finish();
rollback;

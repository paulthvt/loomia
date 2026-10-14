-- What's next (#316): next workflows of the same stage, and who is to be
-- asked. Run with `supabase test db`.
begin;
create extension if not exists pgtap with schema extensions;
select plan(13);

insert into auth.users (id, email) values
  ('00000000-0000-0000-0000-00000000000a', 'a@example.com'),
  ('00000000-0000-0000-0000-00000000000b', 'b@example.com');

set local role authenticated;
set local request.jwt.claims =
  '{"sub": "00000000-0000-0000-0000-00000000000a", "role": "authenticated"}';

insert into public.workflow (id, stage, name, repeats) values
  ('00000000-0000-0000-0000-0000000000f1', 'prospect', 'Samples', false),
  ('00000000-0000-0000-0000-0000000000f2', 'prospect', 'Wellness check', false),
  ('00000000-0000-0000-0000-0000000000f3', 'customer', 'New customer', false),
  ('00000000-0000-0000-0000-0000000000f4', 'team', 'Weekly', true);
insert into public.workflow_step (workflow_id, position, label, days) values
  ('00000000-0000-0000-0000-0000000000f1', 1, 'Send', 0),
  ('00000000-0000-0000-0000-0000000000f2', 1, 'Book', 0),
  ('00000000-0000-0000-0000-0000000000f3', 1, 'Thank', 0),
  ('00000000-0000-0000-0000-0000000000f4', 1, 'Check in', 7);

-- 1-3: next workflows.
select lives_ok(
  $$ insert into public.workflow_next (workflow_id, next_workflow_id) values
       ('00000000-0000-0000-0000-0000000000f1',
        '00000000-0000-0000-0000-0000000000f2') $$,
  'Samples can lead to Wellness check'
);
select throws_ok(
  $$ insert into public.workflow_next (workflow_id, next_workflow_id) values
       ('00000000-0000-0000-0000-0000000000f1',
        '00000000-0000-0000-0000-0000000000f3') $$,
  '23514', null,
  'not to a workflow of another stage'
);
select throws_ok(
  $$ insert into public.workflow_next (workflow_id, next_workflow_id) values
       ('00000000-0000-0000-0000-0000000000f1',
        '00000000-0000-0000-0000-0000000000f1') $$,
  '23514', null,
  'not to itself'
);

-- Done: at 1e9. On a step: at 1.
insert into public.person
  (id, name, stage, workflow_id, at_position, last_tick, paused_at, loyalty_since)
  values
  ('00000000-0000-0000-0000-0000000000a1', 'Sophie', 'prospect',
   '00000000-0000-0000-0000-0000000000f1', 1e9, '2026-10-10', null, null),
  ('00000000-0000-0000-0000-0000000000a2', 'Inès', 'prospect',
   '00000000-0000-0000-0000-0000000000f2', 1e9, '2026-10-10', null, null),
  ('00000000-0000-0000-0000-0000000000a3', 'Julie', 'customer',
   '00000000-0000-0000-0000-0000000000f3', 1e9, '2026-10-10', null, null),
  ('00000000-0000-0000-0000-0000000000a4', 'Claire', 'customer',
   '00000000-0000-0000-0000-0000000000f3', 1e9, '2026-10-10', null, '2026-09-01'),
  ('00000000-0000-0000-0000-0000000000a5', 'Léa', 'prospect',
   '00000000-0000-0000-0000-0000000000f1', 1e9, '2026-10-10', now(), null),
  ('00000000-0000-0000-0000-0000000000a6', 'Marc', 'prospect',
   '00000000-0000-0000-0000-0000000000f1', 1, '2026-10-10', null, null),
  ('00000000-0000-0000-0000-0000000000a7', 'Bruno', 'team',
   '00000000-0000-0000-0000-0000000000f4', 1, '2026-10-10', null, null),
  ('00000000-0000-0000-0000-0000000000a8', 'Nora', 'customer',
   null, null, null, null, null);

-- 4-11: who is asked.
select results_eq(
  $$ select p.name, p.needs_next from public.person p order by p.name $$,
  $$ values ('Bruno', false), ('Claire', false), ('Inès', false),
            ('Julie', true), ('Léa', false), ('Marc', false),
            ('Nora', false), ('Sophie', true) $$,
  'done with next options, or a customer done without an LRP'
);
update public.person set loyalty_since = '2026-10-12'
  where id = '00000000-0000-0000-0000-0000000000a3';
select is(
  (select p.needs_next from public.person p
    where id = '00000000-0000-0000-0000-0000000000a3'),
  false, 'once the LRP is on, nothing to ask'
);
update public.person set workflow_id = null, at_position = null, last_tick = null
  where id = '00000000-0000-0000-0000-0000000000a1';
select is(
  (select p.needs_next from public.person p
    where id = '00000000-0000-0000-0000-0000000000a1'),
  false, 'Nothing for now: answered'
);
update public.person set workflow_id = '00000000-0000-0000-0000-0000000000f1',
  at_position = 1e9, last_tick = '2026-10-10'
  where id = '00000000-0000-0000-0000-0000000000a1';

-- 7: the push counts them.
reset role;
set local role service_role;
select is(
  public.due_people_count('00000000-0000-0000-0000-00000000000a', '2026-10-12'),
  2, 'Sophie to ask, and Marc''s step (Bruno''s is next week)'
);
reset role;
set local role authenticated;

-- 8-10: as B.
set local request.jwt.claims =
  '{"sub": "00000000-0000-0000-0000-00000000000b", "role": "authenticated"}';
select is(
  (select count(*)::int from public.workflow_next), 0,
  'another user sees none'
);
select throws_ok(
  $$ insert into public.workflow_next (owner_id, workflow_id, next_workflow_id)
     values ('00000000-0000-0000-0000-00000000000a',
             '00000000-0000-0000-0000-0000000000f2',
             '00000000-0000-0000-0000-0000000000f1') $$,
  '42501', null,
  'nor adds to theirs'
);
select throws_ok(
  $$ update public.workflow_next set next_workflow_id = next_workflow_id $$,
  '42501', null,
  'rows are not updated: delete and insert'
);

-- 11-13: deleting a workflow takes its links.
set local request.jwt.claims =
  '{"sub": "00000000-0000-0000-0000-00000000000a", "role": "authenticated"}';
delete from public.workflow where id = '00000000-0000-0000-0000-0000000000f2';
select is(
  (select count(*)::int from public.workflow_next), 0,
  'the link goes with the workflow'
);
select is(
  (select p.needs_next from public.person p
    where id = '00000000-0000-0000-0000-0000000000a1'),
  false, 'and nobody is asked about it'
);
select ok(
  not has_function_privilege('anon', 'public.needs_next(public.person)', 'execute'),
  'anon cannot call needs_next'
);

select * from finish();
rollback;

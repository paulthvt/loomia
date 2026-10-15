-- Loyalty setups (#140): a step can count as one, and ticking it copies the
-- flag onto the step entry, so renaming or deleting the step keeps the count.
-- Run with `supabase test db`.
begin;
create extension if not exists pgtap with schema extensions;
select plan(7);

insert into auth.users (id, email) values
  ('00000000-0000-0000-0000-00000000000a', 'a@example.com');

set local role authenticated;
set local request.jwt.claims =
  '{"sub": "00000000-0000-0000-0000-00000000000a", "role": "authenticated"}';

insert into public.workflow (id, stage, name) values
  ('00000000-0000-0000-0000-0000000000f1', 'customer', 'New customer');
insert into public.workflow_step (id, workflow_id, position, label, days, loyalty_setup) values
  ('00000000-0000-0000-0000-0000000000e1',
   '00000000-0000-0000-0000-0000000000f1', 1, 'Welcome call', 0, false),
  ('00000000-0000-0000-0000-0000000000e2',
   '00000000-0000-0000-0000-0000000000f1', 2, 'Set up their LRP', 7, true);
insert into public.person (id, name, stage, workflow_id, at_position, last_tick) values
  ('00000000-0000-0000-0000-0000000000a1', 'Claire', 'customer',
   '00000000-0000-0000-0000-0000000000f1', 1, '2026-10-01');

select public.complete_step(
  '00000000-0000-0000-0000-0000000000a1',
  '00000000-0000-0000-0000-0000000000e1', '2026-10-02');
select is(
  (select loyalty_setup from public.activity where text = 'Welcome call'),
  false,
  'an ordinary step leaves an ordinary entry'
);

select public.complete_step(
  '00000000-0000-0000-0000-0000000000a1',
  '00000000-0000-0000-0000-0000000000e2', '2026-10-09');
select is(
  (select loyalty_setup from public.activity where text = 'Set up their LRP'),
  true,
  'a loyalty step leaves a loyalty entry'
);

update public.workflow_step set label = 'LRP', loyalty_setup = false
  where id = '00000000-0000-0000-0000-0000000000e2';
delete from public.workflow_step
  where id = '00000000-0000-0000-0000-0000000000e2';
select is(
  (select count(*)::int from public.activity where loyalty_setup), 1,
  'the entry keeps the flag after the step changes and goes'
);

select is(
  (select loyalty_setup from public.workflow_step
    where id = '00000000-0000-0000-0000-0000000000e1'),
  false,
  'a step is not a loyalty setup unless marked'
);
select throws_ok(
  $$ insert into public.activity (person_id, kind, text, loyalty_setup) values
     ('00000000-0000-0000-0000-0000000000a1', 'note', 'Hi', true) $$,
  '23514', null,
  'only a step entry is a loyalty setup'
);
select lives_ok(
  $$ insert into public.activity (person_id, kind, text) values
     ('00000000-0000-0000-0000-0000000000a1', 'note', 'Hi') $$,
  'other entries still save'
);

-- The seed marks no loyalty step (#319): finishing New customer asks about
-- the LRP instead (#316).
select public.seed_workflows('en', '2026-10-04');
select is(
  (select count(*)::int from public.workflow_step where loyalty_setup), 0,
  'the seed marks no loyalty step'
);

select * from finish();
rollback;

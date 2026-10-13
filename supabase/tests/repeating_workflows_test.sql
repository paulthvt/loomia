-- Repeating workflows (#296): after the last step of a workflow that
-- repeats, complete_step goes back to the first. Run with `supabase test db`.
begin;
create extension if not exists pgtap with schema extensions;
select plan(8);

insert into auth.users (id, email) values
  ('00000000-0000-0000-0000-00000000000a', 'a@example.com');

set local role authenticated;
set local request.jwt.claims =
  '{"sub": "00000000-0000-0000-0000-00000000000a", "role": "authenticated"}';

insert into public.workflow (id, stage, name, repeats) values
  ('00000000-0000-0000-0000-0000000000f1', 'customer', 'Refill', true),
  ('00000000-0000-0000-0000-0000000000f2', 'customer', 'Once', false);
insert into public.workflow_step
  (id, workflow_id, position, label, days, loyalty_setup) values
  ('00000000-0000-0000-0000-0000000000c1', '00000000-0000-0000-0000-0000000000f1', 1, 'Ask about supplies', 25, false),
  ('00000000-0000-0000-0000-0000000000c2', '00000000-0000-0000-0000-0000000000f1', 2, 'Help with the order', 3, true),
  ('00000000-0000-0000-0000-0000000000c3', '00000000-0000-0000-0000-0000000000f2', 1, 'Thank them', 0, false);

insert into public.person
  (id, name, stage, workflow_id, at_position, last_tick, loyalty_since) values
  ('00000000-0000-0000-0000-0000000000a1', 'Looping', 'customer', '00000000-0000-0000-0000-0000000000f1', 2, '2026-10-01', '2026-09-01'),
  ('00000000-0000-0000-0000-0000000000a2', 'Once', 'customer', '00000000-0000-0000-0000-0000000000f2', 1, '2026-10-01', null),
  ('00000000-0000-0000-0000-0000000000a3', 'Done before', 'customer', '00000000-0000-0000-0000-0000000000f1', 1e9, '2026-08-01', null),
  ('00000000-0000-0000-0000-0000000000a4', 'Switched off', 'customer', '00000000-0000-0000-0000-0000000000f1', 1, '2026-10-01', null);

select public.complete_step('00000000-0000-0000-0000-0000000000a1',
  '00000000-0000-0000-0000-0000000000c2', '2026-10-12');
select results_eq(
  $$ select p.at_position, p.current_step_id, p.due_on from public.person p
     where p.id = '00000000-0000-0000-0000-0000000000a1' $$,
  $$ values (1::numeric, '00000000-0000-0000-0000-0000000000c1'::uuid,
             '2026-11-06'::date) $$,
  'the last step of a repeating workflow brings the first back, due its days after the tick'
);
select is(
  (select count(*)::int from public.activity
    where person_id = '00000000-0000-0000-0000-0000000000a1' and kind = 'step'),
  1, 'the tick is one history entry');
select is(
  (select p.loyalty_since from public.person p
    where p.id = '00000000-0000-0000-0000-0000000000a1'),
  '2026-09-01'::date, 'a loyalty step ticked again keeps loyalty_since');

select public.complete_step('00000000-0000-0000-0000-0000000000a2',
  '00000000-0000-0000-0000-0000000000c3', '2026-10-12');
select results_eq(
  $$ select p.at_position, p.current_step_id from public.person p
     where p.id = '00000000-0000-0000-0000-0000000000a2' $$,
  $$ values (1e9::numeric, null::uuid) $$,
  'a workflow that does not repeat still ends'
);

select is(
  (select p.current_step_id from public.person p
    where p.id = '00000000-0000-0000-0000-0000000000a3'),
  null::uuid, 'someone done before Repeat was switched on stays done');

update public.workflow set repeats = false
  where id = '00000000-0000-0000-0000-0000000000f1';
select public.complete_step('00000000-0000-0000-0000-0000000000a4',
  '00000000-0000-0000-0000-0000000000c1', '2026-10-12');
select is(
  (select p.current_step_id from public.person p
    where p.id = '00000000-0000-0000-0000-0000000000a4'),
  '00000000-0000-0000-0000-0000000000c2'::uuid,
  'switched off mid-round: the round goes on');
select public.complete_step('00000000-0000-0000-0000-0000000000a4',
  '00000000-0000-0000-0000-0000000000c2', '2026-10-15');
select is(
  (select p.current_step_id from public.person p
    where p.id = '00000000-0000-0000-0000-0000000000a4'),
  null::uuid, 'switched off: done after the last step');

select is(
  (select repeats from public.workflow
    where id = '00000000-0000-0000-0000-0000000000f2'),
  false, 'a workflow does not repeat unless asked');

select * from finish();
rollback;

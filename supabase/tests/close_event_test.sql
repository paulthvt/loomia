-- Who was there records what changed (#318): close_event. Run with
-- `supabase test db`.
begin;
create extension if not exists pgtap with schema extensions;
select plan(15);

insert into auth.users (id, email) values
  ('00000000-0000-0000-0000-00000000000a', 'a@example.com'),
  ('00000000-0000-0000-0000-00000000000b', 'b@example.com');

set local role authenticated;
set local request.jwt.claims =
  '{"sub": "00000000-0000-0000-0000-00000000000a", "role": "authenticated"}';

insert into public.event_workflow (id, name, is_group) values
  ('00000000-0000-0000-0000-0000000000c1', 'Workshop', true);
insert into public.workflow (id, stage, name, is_default) values
  ('00000000-0000-0000-0000-0000000000f1', 'prospect', 'Workshop invite', false),
  ('00000000-0000-0000-0000-0000000000f2', 'customer', 'New customer', true);
insert into public.workflow_step
  (id, workflow_id, position, label, days, event_workflow_id) values
  ('00000000-0000-0000-0000-0000000000d1', '00000000-0000-0000-0000-0000000000f1',
   1, 'Invite to a workshop', 0, '00000000-0000-0000-0000-0000000000c1'),
  ('00000000-0000-0000-0000-0000000000d2', '00000000-0000-0000-0000-0000000000f2',
   1, 'Book the unboxing call', 0, null);
insert into public.person
  (id, name, stage, workflow_id, at_position, last_tick) values
  ('00000000-0000-0000-0000-0000000000a1', 'Sophie', 'prospect',
   '00000000-0000-0000-0000-0000000000f1', 1, '2026-10-01'),
  ('00000000-0000-0000-0000-0000000000a2', 'Marc', 'prospect', null, null, null),
  ('00000000-0000-0000-0000-0000000000a3', 'Claire', 'customer', null, null, null),
  ('00000000-0000-0000-0000-0000000000a4', 'Léa', 'prospect', null, null, null),
  ('00000000-0000-0000-0000-0000000000a5', 'Nora', 'customer', null, null, null);
insert into public.event (id, title, starts_at, event_workflow_id) values
  ('00000000-0000-0000-0000-0000000000e1', 'Huiles et sommeil',
   '2026-10-08 17:00+00', '00000000-0000-0000-0000-0000000000c1'),
  ('00000000-0000-0000-0000-0000000000e2', 'Essential oils for kids',
   '2026-11-03 17:00+00', '00000000-0000-0000-0000-0000000000c1');
insert into public.event_attendee (event_id, person_id) values
  ('00000000-0000-0000-0000-0000000000e1', '00000000-0000-0000-0000-0000000000a1'),
  ('00000000-0000-0000-0000-0000000000e1', '00000000-0000-0000-0000-0000000000a2'),
  ('00000000-0000-0000-0000-0000000000e1', '00000000-0000-0000-0000-0000000000a3'),
  ('00000000-0000-0000-0000-0000000000e1', '00000000-0000-0000-0000-0000000000a4'),
  ('00000000-0000-0000-0000-0000000000e1', '00000000-0000-0000-0000-0000000000a5');

-- 1-3: refusals, nothing written.
select throws_ok(
  $$ select public.close_event('00000000-0000-0000-0000-0000000000e1',
       '[{"person": "00000000-0000-0000-0000-0000000000ff"}]', '{}', '2026-10-08') $$,
  'P0001', null, 'someone not invited cannot be there'
);
select throws_ok(
  $$ select public.close_event('00000000-0000-0000-0000-0000000000e1',
       '[{"person": "00000000-0000-0000-0000-0000000000a4"}]',
       array['00000000-0000-0000-0000-0000000000a4']::uuid[], '2026-10-08') $$,
  'P0001', null, 'someone who came is not invited to the next one'
);
select ok(
  (select done_at is null from public.event
    where id = '00000000-0000-0000-0000-0000000000e1'),
  'a refused call leaves the event open'
);

select public.close_event('00000000-0000-0000-0000-0000000000e1',
  '[{"person": "00000000-0000-0000-0000-0000000000a1", "customer": true,
     "amount": 120},
    {"person": "00000000-0000-0000-0000-0000000000a2", "customer": true,
     "text": "Registration order"},
    {"person": "00000000-0000-0000-0000-0000000000a3", "amount": 40},
    {"person": "00000000-0000-0000-0000-0000000000a5", "customer": true}]',
  array['00000000-0000-0000-0000-0000000000a4']::uuid[], '2026-10-08');

-- 4-6: Sophie, who came from Workshop invite and ordered.
select results_eq(
  $$ select stage::text, workflow_id, at_position, last_tick from public.person
     where id = '00000000-0000-0000-0000-0000000000a1' $$,
  $$ values ('customer', '00000000-0000-0000-0000-0000000000f2'::uuid, 1::numeric,
             '2026-10-08'::date) $$,
  'a customer on the default customer workflow, from its first step'
);
select results_eq(
  $$ select kind::text, amount from public.activity
     where person_id = '00000000-0000-0000-0000-0000000000a1'
       and kind in ('event', 'order', 'stage')
     order by kind::text $$,
  $$ values ('event', null::numeric), ('order', 120::numeric),
            ('stage', null::numeric) $$,
  'the event, the registration order, the stage change'
);
select is(
  (select current_step_id(p) from public.person p
    where id = '00000000-0000-0000-0000-0000000000a1'),
  '00000000-0000-0000-0000-0000000000d2'::uuid,
  'on the customer workflow''s first step'
);

-- 7-8: Marc, with no amount: the device's text.
select results_eq(
  $$ select stage::text from public.person
     where id = '00000000-0000-0000-0000-0000000000a2' $$,
  $$ values ('customer') $$,
  'Marc is a customer'
);
select results_eq(
  $$ select text, amount from public.activity
     where person_id = '00000000-0000-0000-0000-0000000000a2' and kind = 'order' $$,
  $$ values ('Registration order', null::numeric) $$,
  'his order without an amount'
);

-- 9-11: Claire's order; Nora, already a customer, unchanged.
select results_eq(
  $$ select amount from public.activity
     where person_id = '00000000-0000-0000-0000-0000000000a3' and kind = 'order' $$,
  $$ values (40::numeric) $$,
  'a customer''s order'
);
select is(
  (select count(*)::int from public.activity
    where person_id = '00000000-0000-0000-0000-0000000000a5'
      and kind in ('order', 'stage')),
  0, 'customer: true means nothing for someone already a customer'
);
select results_eq(
  $$ select person_id, came from public.event_attendee
     where event_id = '00000000-0000-0000-0000-0000000000e1' and not came $$,
  $$ values ('00000000-0000-0000-0000-0000000000a4'::uuid, false) $$,
  'Léa missed it'
);

-- 12-13: Léa, invited to the next workshop.
select results_eq(
  $$ select going, invited_on from public.event_attendee
     where event_id = '00000000-0000-0000-0000-0000000000e2' $$,
  $$ values (false, '2026-10-08'::date) $$,
  'invited to the next one, not going yet'
);
select ok(
  (select done_at is not null from public.event
    where id = '00000000-0000-0000-0000-0000000000e1'),
  'the event is done'
);

-- 14: once.
select throws_ok(
  $$ select public.close_event('00000000-0000-0000-0000-0000000000e1',
       '[]', '{}', '2026-10-08') $$,
  'P0001', null, 'an event is closed once'
);

-- 15: as B.
set local request.jwt.claims =
  '{"sub": "00000000-0000-0000-0000-00000000000b", "role": "authenticated"}';
select throws_ok(
  $$ select public.close_event('00000000-0000-0000-0000-0000000000e2',
       '[]', '{}', '2026-10-08') $$,
  'P0002', null, 'another user cannot close it'
);

select * from finish();
rollback;

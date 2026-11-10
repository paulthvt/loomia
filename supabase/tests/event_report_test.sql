-- Event reports (#483): report template on event types, report on events,
-- history linked to its event. Run with `supabase test db`.
begin;
create extension if not exists pgtap with schema extensions;
select plan(7);

insert into auth.users (id, email) values
  ('00000000-0000-0000-0000-00000000000a', 'a@example.com'),
  ('00000000-0000-0000-0000-00000000000b', 'b@example.com');

set local role authenticated;
set local request.jwt.claims =
  '{"sub": "00000000-0000-0000-0000-00000000000a", "role": "authenticated"}';

insert into public.event_workflow (id, name, is_group, report_fields) values
  ('00000000-0000-0000-0000-0000000000c1', 'Coffee', false, '{"A","B"}');
insert into public.person (id, name, stage) values
  ('00000000-0000-0000-0000-0000000000a1', 'Sophie', 'prospect');
insert into public.event (id, title, starts_at, event_workflow_id, report) values
  ('00000000-0000-0000-0000-0000000000e1', 'Coffee with Sophie',
   '2026-11-08 15:00+00', '00000000-0000-0000-0000-0000000000c1',
   '[{"label":"A","text":"x"}]');
insert into public.event_attendee (event_id, person_id) values
  ('00000000-0000-0000-0000-0000000000e1', '00000000-0000-0000-0000-0000000000a1');

-- 1: report_fields round-trips, default '{}' on a new type.
select results_eq(
  $$ select report_fields from public.event_workflow
     where id = '00000000-0000-0000-0000-0000000000c1' $$,
  $$ values ('{"A","B"}'::text[]) $$,
  'report_fields round-trips'
);
insert into public.event_workflow (id, name, is_group) values
  ('00000000-0000-0000-0000-0000000000c2', 'Workshop', true);
select results_eq(
  $$ select report_fields from public.event_workflow
     where id = '00000000-0000-0000-0000-0000000000c2' $$,
  $$ values ('{}'::text[]) $$,
  'default report_fields is empty array'
);

-- 2: report = '"oops"'::jsonb is rejected (check constraint).
select throws_ok(
  $$ update public.event set report = '"oops"'::jsonb
     where id = '00000000-0000-0000-0000-0000000000e1' $$,
  '23514', null, 'report must be a jsonb array, not a string'
);

-- 3: the event activity has event_id = the event.
select public.close_event('00000000-0000-0000-0000-0000000000e1',
  '[{"person": "00000000-0000-0000-0000-0000000000a1"}]', '{}', '2026-11-08');
select results_eq(
  $$ select event_id from public.activity
     where person_id = '00000000-0000-0000-0000-0000000000a1' and kind = 'event' $$,
  $$ values ('00000000-0000-0000-0000-0000000000e1'::uuid) $$,
  'event activity has event_id'
);

-- 4: updating report after done_at is set succeeds (event update RLS has no done guard).
update public.event set report = '[{"label":"B","text":"y"}]'
  where id = '00000000-0000-0000-0000-0000000000e1';
select results_eq(
  $$ select report from public.event
     where id = '00000000-0000-0000-0000-0000000000e1' $$,
  $$ values ('[{"label":"B","text":"y"}]'::jsonb) $$,
  'report can be updated after done_at'
);

-- 5: deleting the event leaves the activity with event_id null.
delete from public.event where id = '00000000-0000-0000-0000-0000000000e1';
select results_eq(
  $$ select event_id from public.activity
     where person_id = '00000000-0000-0000-0000-0000000000a1' and kind = 'event' $$,
  $$ values (null::uuid) $$,
  'deleting event nulls activity.event_id'
);

-- 6: user B cannot read A's report (RLS unchanged).
set local request.jwt.claims =
  '{"sub": "00000000-0000-0000-0000-00000000000b", "role": "authenticated"}';
select is(
  (select count(*)::int from public.event),
  0, 'user B cannot see user A''s events'
);

select * from finish();
rollback;

-- Event attendees (#152): who is invited, who was there, and marking an
-- event done. Run with `supabase test db`.
begin;
create extension if not exists pgtap with schema extensions;
select plan(14);

insert into auth.users (id, email) values
  ('00000000-0000-0000-0000-00000000000a', 'a@example.com'),
  ('00000000-0000-0000-0000-00000000000b', 'b@example.com');

set local role authenticated;
set local request.jwt.claims =
  '{"sub": "00000000-0000-0000-0000-00000000000a", "role": "authenticated"}';

insert into public.person (id, name, stage) values
  ('00000000-0000-0000-0000-0000000000a1', 'Claire', 'prospect'),
  ('00000000-0000-0000-0000-0000000000a2', 'Sarah', 'prospect'),
  ('00000000-0000-0000-0000-0000000000a3', 'Marie', 'customer'),
  ('00000000-0000-0000-0000-0000000000a4', 'Léa', 'prospect');
insert into public.event (id, title, starts_at) values
  ('00000000-0000-0000-0000-0000000000e1', 'Workshop', '2026-10-08 17:00+00');

-- 1-2: inviting.
select lives_ok(
  $$ insert into public.event_attendee (event_id, person_id) values
       ('00000000-0000-0000-0000-0000000000e1', '00000000-0000-0000-0000-0000000000a1'),
       ('00000000-0000-0000-0000-0000000000e1', '00000000-0000-0000-0000-0000000000a2'),
       ('00000000-0000-0000-0000-0000000000e1', '00000000-0000-0000-0000-0000000000a3') $$,
  'people are invited'
);
select throws_ok(
  $$ insert into public.event_attendee (event_id, person_id) values
       ('00000000-0000-0000-0000-0000000000e1', '00000000-0000-0000-0000-0000000000a1') $$,
  '23505', null,
  'someone is invited once'
);

-- 3: a deleted contact leaves the event.
delete from public.person where id = '00000000-0000-0000-0000-0000000000a3';
select is(
  (select count(*)::int from public.event_attendee), 2,
  'deleting a person removes them from the event'
);

-- 4-5: refusals, nothing written.
select throws_ok(
  $$ select public.mark_event_done('00000000-0000-0000-0000-0000000000e1',
       array['00000000-0000-0000-0000-0000000000ff']::uuid[], '2026-10-08') $$,
  'P0001', null,
  'someone not invited cannot be marked as there'
);
select ok((select done_at is null from public.event), 'a refused call leaves the event open');

-- 6-10: marking done.
select lives_ok(
  $$ select public.mark_event_done('00000000-0000-0000-0000-0000000000e1',
       array['00000000-0000-0000-0000-0000000000a1']::uuid[], '2026-10-09') $$,
  'the event is marked done'
);
select ok(
  (select done_at is not null from public.event),
  'done_at is set'
);
select results_eq(
  $$ select person_id::text, came from public.event_attendee order by person_id $$,
  $$ values ('00000000-0000-0000-0000-0000000000a1', true),
            ('00000000-0000-0000-0000-0000000000a2', false) $$,
  'who was there, and who missed it'
);
select results_eq(
  $$ select person_id::text, kind::text, text, happened_on
     from public.activity where kind = 'event' $$,
  $$ values ('00000000-0000-0000-0000-0000000000a1', 'event', 'Workshop',
             '2026-10-09'::date) $$,
  'only who was there gets an Event entry, on the device''s day'
);
select throws_ok(
  $$ select public.mark_event_done('00000000-0000-0000-0000-0000000000e1',
       array[]::uuid[], '2026-10-09') $$,
  'P0001', null,
  'an event is marked done once'
);

-- 11-12: a done event's attendance is read-only.
select throws_ok(
  $$ insert into public.event_attendee (event_id, person_id) values
       ('00000000-0000-0000-0000-0000000000e1', '00000000-0000-0000-0000-0000000000a4') $$,
  '42501', null,
  'nobody joins a done event'
);
delete from public.event_attendee;
update public.event_attendee set came = false;
select is(
  (select count(*)::int from public.event_attendee where came), 1,
  'a done event''s attendance neither changes nor goes'
);

-- 13-14: as B.
set local request.jwt.claims =
  '{"sub": "00000000-0000-0000-0000-00000000000b", "role": "authenticated"}';
select is(
  (select count(*)::int from public.event_attendee), 0,
  'another user sees nobody'
);
select throws_ok(
  $$ select public.mark_event_done('00000000-0000-0000-0000-0000000000e1',
       array[]::uuid[], '2026-10-09') $$,
  'P0002', null,
  'another user cannot mark it done'
);

select * from finish();
rollback;

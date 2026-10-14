-- Invitations (#314): on a group event people start invited, and the day to
-- follow them up is 3 days after the invite or the last follow-up, until
-- they are going or the event is done. The daily push counts them while the
-- event's day has not passed. Run with `supabase test db`.
begin;
create extension if not exists pgtap with schema extensions;
select plan(17);

insert into auth.users (id, email) values
  ('00000000-0000-0000-0000-00000000000a', 'a@example.com');
insert into public.notification_settings (owner_id, time_zone) values
  ('00000000-0000-0000-0000-00000000000a', 'Europe/Paris');

set local role authenticated;
set local request.jwt.claims =
  '{"sub": "00000000-0000-0000-0000-00000000000a", "role": "authenticated"}';

insert into public.person (id, name, stage) values
  ('00000000-0000-0000-0000-0000000000a1', 'Marc', 'prospect'),
  ('00000000-0000-0000-0000-0000000000a2', 'Sarah', 'prospect'),
  ('00000000-0000-0000-0000-0000000000a3', 'Claire', 'customer'),
  ('00000000-0000-0000-0000-0000000000a4', 'Bruno', 'team');
insert into public.event_workflow (id, name, is_group) values
  ('00000000-0000-0000-0000-0000000000c1', 'Workshop', true),
  ('00000000-0000-0000-0000-0000000000c2', 'Wellness check', false);
-- Wednesday October 21, 00:30 in Paris: still the 20th in UTC (22:30), so
-- only the owner's zone puts it on the 21st. The wellness check and the
-- plain event are on the 22nd.
insert into public.event (id, title, starts_at, event_workflow_id) values
  ('00000000-0000-0000-0000-0000000000e1', 'Huiles et sommeil',
   '2026-10-20 22:30+00', '00000000-0000-0000-0000-0000000000c1'),
  ('00000000-0000-0000-0000-0000000000e2', 'Wellness check — Sarah',
   '2026-10-22 17:00+00', '00000000-0000-0000-0000-0000000000c2'),
  ('00000000-0000-0000-0000-0000000000e3', 'Coffee',
   '2026-10-22 08:00+00', null);

-- 1-5: who starts going.
insert into public.event_attendee (event_id, person_id, invited_on) values
  ('00000000-0000-0000-0000-0000000000e1',
   '00000000-0000-0000-0000-0000000000a1', '2026-10-10'),
  ('00000000-0000-0000-0000-0000000000e2',
   '00000000-0000-0000-0000-0000000000a2', '2026-10-10'),
  ('00000000-0000-0000-0000-0000000000e3',
   '00000000-0000-0000-0000-0000000000a2', '2026-10-10');
insert into public.event_attendee (event_id, person_id, going) values
  ('00000000-0000-0000-0000-0000000000e1',
   '00000000-0000-0000-0000-0000000000a3', true);

select is(
  (select going from public.event_attendee
    where event_id = '00000000-0000-0000-0000-0000000000e1'
      and person_id = '00000000-0000-0000-0000-0000000000a1'),
  false, 'on a group type, someone added is invited'
);
select is(
  (select going from public.event_attendee
    where event_id = '00000000-0000-0000-0000-0000000000e2'),
  true, 'on an individual type, going'
);
select is(
  (select going from public.event_attendee
    where event_id = '00000000-0000-0000-0000-0000000000e3'),
  true, 'on a plain event, going'
);
select is(
  (select going from public.event_attendee
    where person_id = '00000000-0000-0000-0000-0000000000a3'),
  true, 'an insert that says going keeps it'
);
select is(
  (select invited_on from public.event_attendee
    where event_id = '00000000-0000-0000-0000-0000000000e1'
      and person_id = '00000000-0000-0000-0000-0000000000a1'),
  '2026-10-10'::date, 'the device''s day is the invite''s'
);

-- 6-8: when to follow up.
select is(
  (select public.follow_up_on(a) from public.event_attendee a
    where event_id = '00000000-0000-0000-0000-0000000000e1'
      and person_id = '00000000-0000-0000-0000-0000000000a1'),
  '2026-10-13'::date, '3 days after the invite'
);
update public.event_attendee set followed_up_on = '2026-10-14'
  where person_id = '00000000-0000-0000-0000-0000000000a1';
select is(
  (select public.follow_up_on(a) from public.event_attendee a
    where person_id = '00000000-0000-0000-0000-0000000000a1'),
  '2026-10-17'::date, '3 days after the last follow-up'
);
select is(
  (select public.follow_up_on(a) from public.event_attendee a
    where person_id = '00000000-0000-0000-0000-0000000000a3'),
  null, 'nothing for someone going'
);

-- 9-12: the push counts them while the event's day has not passed.
reset role;
set local role service_role;
select is(
  public.due_people_count('00000000-0000-0000-0000-00000000000a', '2026-10-16'),
  0, 'before the follow-up day: nobody'
);
select is(
  public.due_people_count('00000000-0000-0000-0000-00000000000a', '2026-10-17'),
  1, 'on the follow-up day: Marc'
);
select is(
  public.due_people_count('00000000-0000-0000-0000-00000000000a', '2026-10-21'),
  1, 'still on the event''s day in Paris, though it is the 20th in UTC'
);
select is(
  public.due_people_count('00000000-0000-0000-0000-00000000000a', '2026-10-22'),
  0, 'the day after the event: gone'
);
reset role;
set local role authenticated;
set local request.jwt.claims =
  '{"sub": "00000000-0000-0000-0000-00000000000a", "role": "authenticated"}';

-- 13: done, nothing to follow up.
select public.mark_event_done('00000000-0000-0000-0000-0000000000e1',
  array[]::uuid[], '2026-10-22');
select is(
  (select public.follow_up_on(a) from public.event_attendee a
    where person_id = '00000000-0000-0000-0000-0000000000a1'),
  null, 'nothing once the event is done'
);

-- 14-17: a series' people are going, in generated and added occurrences.
insert into public.event_series
  (id, title, first_on, starts_time, time_zone, every_weeks,
   event_workflow_id) values
  ('00000000-0000-0000-0000-0000000000f1', 'Team call', '2026-10-13',
   '19:00', 'Europe/Paris', 1, '00000000-0000-0000-0000-0000000000c1');
insert into public.event_series_attendee (series_id, person_id) values
  ('00000000-0000-0000-0000-0000000000f1', '00000000-0000-0000-0000-0000000000a4');
select public.extend_event_series('2026-10-13');
select is(
  (select bool_and(a.going) from public.event_attendee a
    join public.event e on e.id = a.event_id
    where e.series_id = '00000000-0000-0000-0000-0000000000f1'),
  true, 'generated occurrences: going, even on a group type'
);
select is(
  (select min(a.invited_on) from public.event_attendee a
    join public.event e on e.id = a.event_id
    where e.series_id = '00000000-0000-0000-0000-0000000000f1'),
  '2026-10-13'::date, 'invited on the device''s day'
);
select public.set_series_attendees(
  (select id from public.event
    where series_id = '00000000-0000-0000-0000-0000000000f1'
      and series_on = '2026-10-20'),
  array['00000000-0000-0000-0000-0000000000a1']::uuid[], array[]::uuid[]);
select is(
  (select count(*)::int from public.event_attendee a
    join public.event e on e.id = a.event_id
    where e.series_id = '00000000-0000-0000-0000-0000000000f1'
      and a.person_id = '00000000-0000-0000-0000-0000000000a1'
      and not a.going),
  0, 'added to the series: going'
);
select ok(
  (select count(*) > 0 from public.event_attendee a
    join public.event e on e.id = a.event_id
    where e.series_id = '00000000-0000-0000-0000-0000000000f1'
      and a.person_id = '00000000-0000-0000-0000-0000000000a1'),
  'and added to the occurrences from that one on'
);

select * from finish();
rollback;

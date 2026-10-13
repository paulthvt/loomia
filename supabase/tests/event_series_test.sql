-- Repeating events (#298): a series' occurrences are real events, generated
-- a year ahead by extend_event_series, and its people reach every not done
-- occurrence from the one they were added on. Run with `supabase test db`.
begin;
create extension if not exists pgtap with schema extensions;
select plan(17);

insert into auth.users (id, email) values
  ('00000000-0000-0000-0000-00000000000a', 'a@example.com'),
  ('00000000-0000-0000-0000-00000000000b', 'b@example.com');

set local role authenticated;
set local request.jwt.claims =
  '{"sub": "00000000-0000-0000-0000-00000000000a", "role": "authenticated"}';

insert into public.person (id, name, stage) values
  ('00000000-0000-0000-0000-0000000000a1', 'Bruno', 'team'),
  ('00000000-0000-0000-0000-0000000000a2', 'Lucas', 'team');

-- Weekly from Tuesday October 13, 19:00 in Paris, for an hour, forever.
insert into public.event_series
  (id, title, first_on, starts_time, minutes, time_zone, every_weeks) values
  ('00000000-0000-0000-0000-0000000000f1', 'Team call', '2026-10-13',
   '19:00', 60, 'Europe/Paris', 1);
-- Every 2 weeks from Wednesday October 14 until November 11.
insert into public.event_series
  (id, title, first_on, starts_time, time_zone, every_weeks, until_on) values
  ('00000000-0000-0000-0000-0000000000f2', 'Training', '2026-10-14',
   '10:00', 'Europe/Paris', 2, '2026-11-11');
insert into public.event_series_attendee (series_id, person_id) values
  ('00000000-0000-0000-0000-0000000000f1', '00000000-0000-0000-0000-0000000000a1');

-- 1-3: generating.
select lives_ok(
  $$ select public.extend_event_series('2026-10-12') $$,
  'extend_event_series runs'
);
select is(
  (select count(*)::int from public.event
    where series_id = '00000000-0000-0000-0000-0000000000f1'),
  53, 'weekly: every Tuesday up to a year after today');
select results_eq(
  $$ select series_on from public.event
     where series_id = '00000000-0000-0000-0000-0000000000f2'
     order by series_on $$,
  $$ values ('2026-10-14'::date), ('2026-10-28'::date), ('2026-11-11'::date) $$,
  'every 2 weeks, up to the end day'
);

-- 4-5: the local time holds across the clock change (October 25).
select results_eq(
  $$ select starts_at, ends_at from public.event
     where series_id = '00000000-0000-0000-0000-0000000000f1'
       and series_on in ('2026-10-20', '2026-10-27')
     order by series_on $$,
  $$ values ('2026-10-20 17:00+00'::timestamptz, '2026-10-20 18:00+00'::timestamptz),
            ('2026-10-27 18:00+00'::timestamptz, '2026-10-27 19:00+00'::timestamptz) $$,
  '19:00 in Paris on both sides of the clock change'
);
select is(
  (select ends_at from public.event
    where series_id = '00000000-0000-0000-0000-0000000000f2' limit 1),
  null, 'no minutes: no end time');

-- 6: the series' people are invited.
select is(
  (select count(*)::int from public.event_attendee a
    join public.event e on e.id = a.event_id
    where e.series_id = '00000000-0000-0000-0000-0000000000f1'
      and a.person_id = '00000000-0000-0000-0000-0000000000a1'),
  53, 'every occurrence invites the series people');

-- 7-9: running again adds nothing; a deleted occurrence stays deleted.
select public.extend_event_series('2026-10-12');
select is(
  (select count(*)::int from public.event
    where series_id = '00000000-0000-0000-0000-0000000000f1'),
  53, 'a second run adds nothing');
delete from public.event
  where series_id = '00000000-0000-0000-0000-0000000000f1'
    and series_on = '2026-10-20';
select public.extend_event_series('2026-10-19');
select is(
  (select count(*)::int from public.event
    where series_id = '00000000-0000-0000-0000-0000000000f1'
      and series_on = '2026-10-20'),
  0, 'a deleted occurrence does not come back');
select is(
  (select max(series_on) from public.event
    where series_id = '00000000-0000-0000-0000-0000000000f1'),
  '2027-10-19'::date, 'a later today reaches a week further');

-- 10-13: people added on an occurrence reach the following ones.
update public.event set done_at = now()
  where series_id = '00000000-0000-0000-0000-0000000000f1'
    and series_on = '2026-11-03';
select public.set_series_attendees(
  (select id from public.event
    where series_id = '00000000-0000-0000-0000-0000000000f1'
      and series_on = '2026-10-27'),
  array['00000000-0000-0000-0000-0000000000a2'::uuid], '{}');
select results_eq(
  $$ select e.series_on from public.event_attendee a
     join public.event e on e.id = a.event_id
     where e.series_id = '00000000-0000-0000-0000-0000000000f1'
       and a.person_id = '00000000-0000-0000-0000-0000000000a2'
       and e.series_on <= '2026-11-10'
     order by e.series_on $$,
  $$ values ('2026-10-27'::date), ('2026-11-10'::date) $$,
  'added from October 27: not before, not on a done one'
);
select is(
  (select count(*)::int from public.event_series_attendee
    where person_id = '00000000-0000-0000-0000-0000000000a2'),
  1, 'and on the series, for occurrences still to come');
select public.set_series_attendees(
  (select id from public.event
    where series_id = '00000000-0000-0000-0000-0000000000f1'
      and series_on = '2026-11-10'),
  '{}', array['00000000-0000-0000-0000-0000000000a1'::uuid]);
select results_eq(
  $$ select e.series_on from public.event_attendee a
     join public.event e on e.id = a.event_id
     where e.series_id = '00000000-0000-0000-0000-0000000000f1'
       and a.person_id = '00000000-0000-0000-0000-0000000000a1'
       and e.series_on between '2026-10-27' and '2026-11-17'
     order by e.series_on $$,
  $$ values ('2026-10-27'::date), ('2026-11-03'::date) $$,
  'removed from November 10: kept before and on a done one'
);
select is(
  (select count(*)::int from public.event_series_attendee
    where person_id = '00000000-0000-0000-0000-0000000000a1'),
  0, 'and off the series');

-- 14-15: refusals.
insert into public.event (id, title, starts_at) values
  ('00000000-0000-0000-0000-0000000000e1', 'Coffee', '2026-10-15 08:00+00');
select throws_ok(
  $$ select public.set_series_attendees(
       '00000000-0000-0000-0000-0000000000e1', '{}', '{}') $$,
  'P0002', null,
  'an event outside a series is refused'
);
select throws_ok(
  $$ insert into public.event_series
       (title, first_on, starts_time, time_zone, every_weeks) values
       ('Call', '2026-10-13', '19:00', 'Mars/Olympus', 1) $$,
  '23514', null,
  'an unknown time zone is refused'
);

-- 16-17: another owner sees and extends none of it.
set local request.jwt.claims =
  '{"sub": "00000000-0000-0000-0000-00000000000b", "role": "authenticated"}';
select is(
  (select count(*)::int from public.event_series), 0,
  'B sees none of A''s series');
select public.extend_event_series('2027-06-01');
reset role;
select is(
  (select max(series_on) from public.event
    where series_id = '00000000-0000-0000-0000-0000000000f1'),
  '2027-10-19'::date, 'B extending touches none of A''s series');

select * from finish();
rollback;

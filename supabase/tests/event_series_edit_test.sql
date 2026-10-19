-- Changing a repeating event (#299): "This and following events" on edit
-- and delete, and making a single event repeat. Done occurrences are never
-- touched. Run with `supabase test db`.
begin;
create extension if not exists pgtap with schema extensions;
select plan(22);

insert into auth.users (id, email) values
  ('00000000-0000-0000-0000-00000000000a', 'a@example.com'),
  ('00000000-0000-0000-0000-00000000000b', 'b@example.com');

-- The occurrence of the team call on day d.
create function pg_temp.on_day(d date) returns uuid language sql as $$
  select id from public.event
  where series_id = '00000000-0000-0000-0000-0000000000f1' and series_on = d
$$;

set local role authenticated;
set local request.jwt.claims =
  '{"sub": "00000000-0000-0000-0000-00000000000a", "role": "authenticated"}';

insert into public.person (id, name, stage) values
  ('00000000-0000-0000-0000-0000000000a1', 'Bruno', 'team'),
  ('00000000-0000-0000-0000-0000000000a2', 'Lucas', 'team');

-- Weekly from Tuesday October 13, 19:00 in Paris, for an hour, with Bruno.
insert into public.event_series
  (id, title, first_on, starts_time, minutes, time_zone, every_weeks) values
  ('00000000-0000-0000-0000-0000000000f1', 'Team call', '2026-10-13',
   '19:00', 60, 'Europe/Paris', 1);
insert into public.event_series_attendee (series_id, person_id) values
  ('00000000-0000-0000-0000-0000000000f1', '00000000-0000-0000-0000-0000000000a1');
select public.extend_event_series('2026-10-12');

update public.event set done_at = now() where id = pg_temp.on_day('2026-10-27');
-- Lucas was asked to November 3 alone.
insert into public.event_attendee (event_id, person_id) values
  (pg_temp.on_day('2026-11-03'), '00000000-0000-0000-0000-0000000000a2');

-- 1-5: same rule, in place from October 20: renamed, 20:00 to 21:00.
select is(
  public.update_event_series(
    pg_temp.on_day('2026-10-20'), 'Weekly call',
    '2026-10-20 18:00+00', '2026-10-20 19:00+00', null, null, null, null,
    1::smallint, null, '2026-10-12'),
  pg_temp.on_day('2026-10-20'), 'in place, the same event comes back');
select results_eq(
  $$ select series_on, title from public.event
     where series_id = '00000000-0000-0000-0000-0000000000f1'
       and series_on <= '2026-11-03' order by series_on $$,
  $$ values ('2026-10-13'::date, 'Team call'), ('2026-10-20', 'Weekly call'),
            ('2026-10-27', 'Team call'), ('2026-11-03', 'Weekly call') $$,
  'from this one on, not before, not a done one'
);
select results_eq(
  $$ select starts_at, ends_at from public.event
     where id = pg_temp.on_day('2026-11-03') $$,
  $$ values ('2026-11-03 19:00+00'::timestamptz,
             '2026-11-03 20:00+00'::timestamptz) $$,
  '20:00 in Paris after the clock change too'
);
select ok(
  exists (select 1 from public.event_attendee
    where event_id = pg_temp.on_day('2026-11-03')
      and person_id = '00000000-0000-0000-0000-0000000000a2'),
  'people on an occurrence are kept');
select results_eq(
  $$ select title, starts_time from public.event_series
     where id = '00000000-0000-0000-0000-0000000000f1' $$,
  $$ values ('Weekly call', '20:00'::time) $$,
  'the series takes the change, for occurrences to come'
);

-- 6-9: a new rule from November 10: every 2 weeks. November 17, done,
-- stays.
update public.event set done_at = now() where id = pg_temp.on_day('2026-11-17');
select isnt(
  public.update_event_series(
    pg_temp.on_day('2026-11-10'), 'Weekly call',
    '2026-11-10 19:00+00', '2026-11-10 20:00+00', null, null, null, null,
    2::smallint, null, '2026-10-12'),
  null, 'a new rule returns the regenerated event');
select results_eq(
  $$ select series_on from public.event
     where series_id = '00000000-0000-0000-0000-0000000000f1'
       and series_on between '2026-11-03' and '2026-12-08'
     order by series_on $$,
  $$ values ('2026-11-03'::date), ('2026-11-10'), ('2026-11-17'),
            ('2026-11-24'), ('2026-12-08') $$,
  'every 2 weeks from November 10, the done November 17 kept'
);
select ok(
  not exists (select 1 from public.event_attendee
    where event_id = pg_temp.on_day('2026-11-24')
      and person_id = '00000000-0000-0000-0000-0000000000a2'),
  'regenerated occurrences invite the series people only');
select ok(
  exists (select 1 from public.event_attendee
    where event_id = pg_temp.on_day('2026-11-24')
      and person_id = '00000000-0000-0000-0000-0000000000a1'),
  'and the series people are there');

-- 10-11: a new day: November 24 moved to Wednesday 25.
select public.update_event_series(
  pg_temp.on_day('2026-11-24'), 'Weekly call',
  '2026-11-25 19:00+00', '2026-11-25 20:00+00', null, null, null, null,
  2::smallint, null, '2026-10-12');
select results_eq(
  $$ select series_on from public.event
     where series_id = '00000000-0000-0000-0000-0000000000f1'
       and series_on between '2026-11-24' and '2026-12-09'
     order by series_on $$,
  $$ values ('2026-11-25'::date), ('2026-12-09') $$,
  'a new day regenerates from it'
);
select is(
  (select count(*)::int from public.event
    where series_id = '00000000-0000-0000-0000-0000000000f1'
      and series_on = '2026-12-08'),
  0, 'the old days go');

-- 12-14: ending from the middle.
select public.end_event_series(pg_temp.on_day('2026-12-09'));
select is(
  (select until_on from public.event_series
    where id = '00000000-0000-0000-0000-0000000000f1'),
  '2026-12-08'::date, 'the series ends the day before');
select is(
  (select max(series_on) from public.event
    where series_id = '00000000-0000-0000-0000-0000000000f1'),
  '2026-11-25'::date, 'nothing from it on');
select public.extend_event_series('2026-12-01');
select is(
  (select max(series_on) from public.event
    where series_id = '00000000-0000-0000-0000-0000000000f1'),
  '2026-11-25'::date, 'and nothing comes back');

-- 15-16: ending from the first, with a done occurrence after it.
insert into public.event_series
  (id, title, first_on, starts_time, time_zone, every_weeks) values
  ('00000000-0000-0000-0000-0000000000f2', 'Training', '2026-10-14',
   '10:00', 'Europe/Paris', 1);
select public.extend_event_series('2026-10-12');
update public.event set done_at = now()
  where series_id = '00000000-0000-0000-0000-0000000000f2'
    and series_on = '2026-10-21';
select public.end_event_series((select id from public.event
  where series_id = '00000000-0000-0000-0000-0000000000f2'
    and series_on = '2026-10-14'));
select is(
  (select count(*)::int from public.event_series
    where id = '00000000-0000-0000-0000-0000000000f2'),
  0, 'from the first, the series goes');
select results_eq(
  $$ select series_id, done_at is not null from public.event
     where title = 'Training' $$,
  $$ values (null::uuid, true) $$,
  'only the done one stays, without a series'
);

-- 17-19: a single event starts repeating.
insert into public.event (id, title, starts_at, done_at) values
  ('00000000-0000-0000-0000-0000000000e1', 'Coffee', '2026-10-15 08:00+00', null),
  ('00000000-0000-0000-0000-0000000000e2', 'Lunch', '2026-10-15 10:00+00', now());
insert into public.event_attendee (event_id, person_id) values
  ('00000000-0000-0000-0000-0000000000e1', '00000000-0000-0000-0000-0000000000a2');
select public.repeat_event(
  '00000000-0000-0000-0000-0000000000e1', 1::smallint, '2026-10-29',
  'Europe/Paris');
select results_eq(
  $$ select s.first_on, s.starts_time, e.series_on from public.event e
     join public.event_series s on s.id = e.series_id
     where e.id = '00000000-0000-0000-0000-0000000000e1' $$,
  $$ values ('2026-10-15'::date, '10:00'::time, '2026-10-15'::date) $$,
  'it is the first occurrence, at its local time'
);
select public.extend_event_series('2026-10-12');
select results_eq(
  $$ select e.series_on from public.event e
     join public.event_attendee a on a.event_id = e.id
     where e.title = 'Coffee'
       and a.person_id = '00000000-0000-0000-0000-0000000000a2'
     order by e.series_on $$,
  $$ values ('2026-10-15'::date), ('2026-10-22'), ('2026-10-29') $$,
  'the following ones come, with its people'
);
select throws_ok(
  $$ select public.repeat_event('00000000-0000-0000-0000-0000000000e1',
       1::smallint, null, 'Europe/Paris') $$,
  'P0001', null, 'an event already repeating is refused');

-- 20-22: refusals.
select throws_ok(
  $$ select public.repeat_event('00000000-0000-0000-0000-0000000000e2',
       1::smallint, null, 'Europe/Paris') $$,
  'P0001', null, 'a done event is refused');
select throws_ok(
  $$ select public.end_event_series('00000000-0000-0000-0000-0000000000e2') $$,
  'P0002', null, 'ending outside a series is refused');
set local request.jwt.claims =
  '{"sub": "00000000-0000-0000-0000-00000000000b", "role": "authenticated"}';
select throws_ok(
  $$ select public.end_event_series('00000000-0000-0000-0000-0000000000e1') $$,
  'P0002', null, 'another owner''s event is not found');

select * from finish();
rollback;

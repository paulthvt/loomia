-- Changing a repeating event (#299): "This and following events" on edit,
-- delete and people, and making a single event repeat. "This event" needs
-- nothing here: it changes the row, which stays in its series. Done
-- occurrences are history: nothing here changes or deletes one.
-- Additive: three new functions, nothing the released app reads changes.

-- Makes p_event, a single event not done, the first occurrence of a new
-- series every p_every_weeks weeks until p_until (or forever), at its local
-- time in p_time_zone (the device's). Its people become the series'. The
-- next extend_event_series generates the following ones. Returns the series.
create function public.repeat_event(
  p_event uuid, p_every_weeks smallint, p_until date, p_time_zone text
) returns uuid
language plpgsql security invoker set search_path = '' as $$
declare
  target public.event;
  v_local timestamp;
  new_id uuid;
begin
  select * into target from public.event where id = p_event for update;
  if not found then
    raise exception 'event % not found', p_event using errcode = 'P0002';
  end if;
  if target.series_id is not null or target.done_at is not null then
    raise exception 'event % is done or already repeats', p_event
      using errcode = 'P0001';
  end if;

  v_local := target.starts_at at time zone p_time_zone;
  insert into public.event_series (
    title, first_on, starts_time, minutes, time_zone, every_weeks, until_on,
    generated_until, place, link, notes, event_workflow_id)
  values (
    target.title, v_local::date, v_local::time,
    (extract(epoch from target.ends_at - target.starts_at) / 60)::int,
    p_time_zone, p_every_weeks, p_until, v_local::date,
    target.place, target.link, target.notes, target.event_workflow_id)
  returning id into new_id;

  insert into public.event_series_attendee (series_id, person_id)
    select new_id, a.person_id from public.event_attendee a
    where a.event_id = p_event;
  update public.event set series_id = new_id, series_on = v_local::date
    where id = p_event;
  return new_id;
end $$;

-- "This and following events" on Save: p_event's series takes the form's
-- fields, p_starts_at / p_ends_at read in the series' zone for its time.
-- Same rule (weeks, end day and day as before): every not done occurrence
-- from p_event on is updated in place, keeping its ticks and people.
-- A new rule or day: they are deleted and generated again from the new
-- day, up to a year after p_today. Returns the event now in p_event's
-- place: p_event, or the first regenerated one.
create function public.update_event_series(
  p_event uuid,
  p_title text,
  p_starts_at timestamptz,
  p_ends_at timestamptz,
  p_place text,
  p_link text,
  p_notes text,
  p_event_workflow_id uuid,
  p_every_weeks smallint,
  p_until date,
  p_today date
) returns uuid
language plpgsql security invoker set search_path = '' as $$
declare
  target public.event;
  s public.event_series;
  v_local timestamp;
  v_minutes int;
begin
  select * into target from public.event where id = p_event;
  if target.series_id is null then
    raise exception 'event % is not in a series', p_event
      using errcode = 'P0002';
  end if;
  select * into s from public.event_series where id = target.series_id
    for update;

  v_local := p_starts_at at time zone s.time_zone;
  v_minutes := (extract(epoch from p_ends_at - p_starts_at) / 60)::int;

  if p_every_weeks = s.every_weeks
     and p_until is not distinct from s.until_on
     and v_local::date = (target.starts_at at time zone s.time_zone)::date then
    update public.event_series set
      title = p_title, starts_time = v_local::time, minutes = v_minutes,
      place = p_place, link = p_link, notes = p_notes,
      event_workflow_id = p_event_workflow_id
      where id = s.id;
    -- The target keeps the day it is on, even if it was moved alone.
    update public.event o set
      title = p_title,
      starts_at = case when o.id = p_event then p_starts_at
        else (o.series_on + v_local::time) at time zone s.time_zone end,
      ends_at = case when o.id = p_event then p_ends_at
        else ((o.series_on + v_local::time) at time zone s.time_zone)
          + make_interval(mins => v_minutes) end,
      place = p_place, link = p_link, notes = p_notes,
      event_workflow_id = p_event_workflow_id
      where o.series_id = s.id and o.series_on >= target.series_on
        and o.done_at is null;
    return p_event;
  end if;

  delete from public.event
    where series_id = s.id and series_on >= target.series_on
      and done_at is null;
  update public.event_series set
    title = p_title, first_on = v_local::date, starts_time = v_local::time,
    minutes = v_minutes, every_weeks = p_every_weeks, until_on = p_until,
    generated_until = v_local::date - 1,
    place = p_place, link = p_link, notes = p_notes,
    event_workflow_id = p_event_workflow_id
    where id = s.id;
  perform public.extend_event_series(p_today);
  return (select id from public.event
    where series_id = s.id and series_on = v_local::date);
end $$;

-- "This and following events" on Delete: the series ends the day before
-- p_event, and its not done occurrences from there go. From the first
-- occurrence the series goes too; done ones stay, without a series.
create function public.end_event_series(p_event uuid) returns void
language plpgsql security invoker set search_path = '' as $$
declare
  target public.event;
  s public.event_series;
begin
  select * into target from public.event where id = p_event;
  if target.series_id is null then
    raise exception 'event % is not in a series', p_event
      using errcode = 'P0002';
  end if;
  select * into s from public.event_series where id = target.series_id
    for update;

  delete from public.event
    where series_id = s.id and series_on >= target.series_on
      and done_at is null;
  if target.series_on <= s.first_on then
    delete from public.event_series where id = s.id;
  else
    update public.event_series set until_on = target.series_on - 1
      where id = s.id;
  end if;
end $$;

revoke execute on function public.repeat_event(uuid, smallint, date, text)
  from public, anon;
revoke execute on function public.update_event_series(
  uuid, text, timestamptz, timestamptz, text, text, text, uuid, smallint,
  date, date) from public, anon;
revoke execute on function public.end_event_series(uuid) from public, anon;
grant execute on function public.repeat_event(uuid, smallint, date, text)
  to authenticated;
grant execute on function public.update_event_series(
  uuid, text, timestamptz, timestamptz, text, text, text, uuid, smallint,
  date, date) to authenticated;
grant execute on function public.end_event_series(uuid) to authenticated;

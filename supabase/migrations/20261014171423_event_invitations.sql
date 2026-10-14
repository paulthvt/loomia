-- Invitations on group events (#314). An event type gathers several people
-- or one (is_group). Someone added to a group event starts invited; anywhere
-- else, and through a series, going. follow_up_on is the day to follow up
-- someone not yet going: 3 days after the invite or the last follow-up. The
-- daily push counts them while the event's local day has not passed.

alter table public.event_workflow
  add column is_group boolean not null default true;

-- Existing attendees were all going: there was no other state. The default
-- goes once they are filled, so a new row's null reaches the trigger.
alter table public.event_attendee
  add column going boolean not null default true,
  add column invited_on date not null default current_date,
  add column followed_up_on date;
alter table public.event_attendee alter column going drop default;

-- A new attendee on a group type is invited; on another type or a plain
-- event, going. An insert that says which keeps it.
create function public.event_attendee_going() returns trigger
language plpgsql security invoker set search_path = '' as $$
begin
  if new.going is null then
    new.going := coalesce(
      (select not w.is_group
       from public.event e
       join public.event_workflow w on w.id = e.event_workflow_id
       where e.id = new.event_id),
      true);
  end if;
  return new;
end $$;

create trigger event_attendee_going before insert on public.event_attendee
  for each row execute function public.event_attendee_going();

-- When to follow up someone not yet going; null once going or once the event
-- is done. Selected by PostgREST as a computed field of the embed.
-- ponytail: 3 days for every type; a column on event_workflow if one needs
-- another delay.
create function public.follow_up_on(a public.event_attendee) returns date
language sql stable security invoker set search_path = '' as $$
  select coalesce(a.followed_up_on, a.invited_on) + 3
  where not a.going and public.event_open(a.event_id)
$$;

-- As in 20261013053701_repeating_events.sql; a series' people are regulars,
-- going on every occurrence, invited on the device's day.
create or replace function public.extend_event_series(p_today date) returns void
language plpgsql security invoker set search_path = '' as $$
declare
  s public.event_series;
  horizon date;
  step int;
  d date;
  new_id uuid;
begin
  for s in
    select * from public.event_series
    order by id
    for update
  loop
    horizon := least(p_today + 365, coalesce(s.until_on, 'infinity'::date));
    continue when coalesce(s.generated_until, s.first_on - 1) >= horizon;
    step := 7 * s.every_weeks;
    d := s.first_on;
    if s.generated_until >= s.first_on then
      d := s.first_on + ((s.generated_until - s.first_on) / step + 1) * step;
    end if;
    while d <= horizon loop
      new_id := null;
      insert into public.event (
        title, starts_at, ends_at, place, link, notes, event_workflow_id,
        prospect_workflow_id, customer_workflow_id, team_workflow_id,
        series_id, series_on)
      values (
        s.title,
        (d + s.starts_time) at time zone s.time_zone,
        ((d + s.starts_time) at time zone s.time_zone)
          + make_interval(mins => s.minutes),
        s.place, s.link, s.notes, s.event_workflow_id,
        s.prospect_workflow_id, s.customer_workflow_id, s.team_workflow_id,
        s.id, d)
      on conflict (series_id, series_on) where series_id is not null
        do nothing
      returning id into new_id;
      if new_id is not null then
        insert into public.event_attendee (event_id, person_id, going, invited_on)
          select new_id, a.person_id, true, p_today
          from public.event_series_attendee a
          where a.series_id = s.id;
      end if;
      d := d + step;
    end loop;
    update public.event_series set generated_until = horizon where id = s.id;
  end loop;
end $$;

-- As in 20261013053701_repeating_events.sql, people added going.
create or replace function public.set_series_attendees(
  p_event uuid, p_add uuid[], p_remove uuid[]
) returns void
language plpgsql security invoker set search_path = '' as $$
declare
  target public.event;
begin
  select * into target from public.event where id = p_event;
  if target.series_id is null then
    raise exception 'event % is not in a series', p_event
      using errcode = 'P0002';
  end if;

  insert into public.event_series_attendee (series_id, person_id)
    select target.series_id, p from unnest(p_add) as p
    on conflict do nothing;
  delete from public.event_series_attendee
    where series_id = target.series_id and person_id = any(p_remove);

  insert into public.event_attendee (event_id, person_id, going)
    select o.id, p, true from public.event o cross join unnest(p_add) as p
    where o.series_id = target.series_id
      and o.series_on >= target.series_on and o.done_at is null
    on conflict do nothing;
  delete from public.event_attendee a
    using public.event o
    where a.event_id = o.id and o.series_id = target.series_id
      and o.series_on >= target.series_on and o.done_at is null
      and a.person_id = any(p_remove);
end $$;

-- People with a step, a reminder or an invitation follow-up due on or before
-- p_on: Today's headline (dueToday in lib/features/today/domain/due.dart). A
-- pause hides the step, not the rest. A follow-up counts while the event's
-- day, in the owner's zone, has not passed.
create or replace function public.due_people_count(p_owner uuid, p_on date)
returns int
language sql stable security invoker set search_path = '' as $$
  select count(*)::int from public.person p
  where p.owner_id = p_owner
    and (public.due_on(p) <= p_on
         or exists (
           select 1 from public.reminder r
           where r.person_id = p.id and r.owner_id = p_owner
             and r.due_on <= p_on)
         or exists (
           select 1 from public.event_attendee a
           join public.event e on e.id = a.event_id
           where a.person_id = p.id and a.owner_id = p_owner
             and public.follow_up_on(a) <= p_on
             and (e.starts_at at time zone coalesce(
                   (select s.time_zone from public.notification_settings s
                    where s.owner_id = p_owner),
                   'UTC'))::date >= p_on))
$$;

revoke execute on function public.event_attendee_going() from public, anon;
revoke execute on function public.follow_up_on(public.event_attendee)
  from public, anon;
grant execute on function public.follow_up_on(public.event_attendee)
  to authenticated;

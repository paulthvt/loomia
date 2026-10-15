-- Drop the stage → workflow mapping (#329), the second half of #318's split.
-- #318 added close_event and stopped the app from reading or writing the
-- mapping; this removes what only builds before it used: mark_event_done
-- and the prospect/customer/team workflow columns on event types, events
-- and series. Breaking for builds before #318, by design: push only once
-- every device runs it.

drop function public.mark_event_done(uuid, uuid[], date);

-- As in 20261014171423_event_invitations.sql, without the mapping.
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
        series_id, series_on)
      values (
        s.title,
        (d + s.starts_time) at time zone s.time_zone,
        ((d + s.starts_time) at time zone s.time_zone)
          + make_interval(mins => s.minutes),
        s.place, s.link, s.notes, s.event_workflow_id,
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

-- Their foreign keys and indexes go with them.
alter table public.event_workflow
  drop column prospect_workflow_id,
  drop column customer_workflow_id,
  drop column team_workflow_id;
alter table public.event
  drop column prospect_workflow_id,
  drop column customer_workflow_id,
  drop column team_workflow_id;
alter table public.event_series
  drop column prospect_workflow_id,
  drop column customer_workflow_id,
  drop column team_workflow_id;

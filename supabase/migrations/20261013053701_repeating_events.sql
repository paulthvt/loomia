-- Repeating events (#298): a series is a rule (every 1, 2 or 4 weeks on its
-- first day's weekday, at a local time in an IANA zone, forever or until a
-- day) and a template. Its occurrences are real events, so people, Join,
-- the checklist and Mark who was there work on them unchanged.
-- extend_event_series generates them a year ahead, from where it stopped
-- (generated_until), so a deleted occurrence never comes back. Each start
-- is (day + local time) at time zone: 19:00 stays 19:00 across a clock
-- change.

create table public.event_series (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null default auth.uid()
    references auth.users on delete cascade,
  title text not null check (length(trim(title)) > 0),
  -- Its weekday is the rule's.
  first_on date not null,
  starts_time time not null,
  -- Null: no end time.
  minutes int check (minutes > 0),
  -- IANA name, checked by check_time_zone.
  time_zone text not null,
  every_weeks smallint not null check (every_weeks in (1, 2, 4)),
  until_on date check (until_on >= first_on),
  -- The last day generated; null: none yet.
  generated_until date,
  place text,
  link text check (link ~* '^https?://'),
  notes text,
  event_workflow_id uuid,
  prospect_workflow_id uuid,
  customer_workflow_id uuid,
  team_workflow_id uuid,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (id, owner_id),
  foreign key (event_workflow_id, owner_id)
    references public.event_workflow (id, owner_id) on delete set null (event_workflow_id),
  foreign key (prospect_workflow_id, owner_id)
    references public.workflow (id, owner_id) on delete set null (prospect_workflow_id),
  foreign key (customer_workflow_id, owner_id)
    references public.workflow (id, owner_id) on delete set null (customer_workflow_id),
  foreign key (team_workflow_id, owner_id)
    references public.workflow (id, owner_id) on delete set null (team_workflow_id)
);

create index event_series_event_workflow_id_owner_id_idx
  on public.event_series (event_workflow_id, owner_id);
create index event_series_prospect_workflow_id_owner_id_idx
  on public.event_series (prospect_workflow_id, owner_id);
create index event_series_customer_workflow_id_owner_id_idx
  on public.event_series (customer_workflow_id, owner_id);
create index event_series_team_workflow_id_owner_id_idx
  on public.event_series (team_workflow_id, owner_id);

create trigger event_series_set_updated_at before update on public.event_series
  for each row execute function public.set_updated_at();
create trigger event_series_check_time_zone
  before insert or update of time_zone on public.event_series
  for each row execute function public.check_time_zone();

-- Who new occurrences invite.
create table public.event_series_attendee (
  series_id uuid not null,
  person_id uuid not null,
  owner_id uuid not null default auth.uid()
    references auth.users on delete cascade,
  created_at timestamptz not null default now(),
  primary key (series_id, person_id),
  foreign key (series_id, owner_id)
    references public.event_series (id, owner_id) on delete cascade,
  foreign key (person_id, owner_id)
    references public.person (id, owner_id) on delete cascade
);

create index event_series_attendee_person_id_owner_id_idx
  on public.event_series_attendee (person_id, owner_id);

-- series_on: the day the rule gave it, kept when the occurrence is moved.
alter table public.event
  add column series_id uuid,
  add column series_on date,
  add foreign key (series_id, owner_id)
    references public.event_series (id, owner_id) on delete set null (series_id);

create unique index event_series_id_series_on_key
  on public.event (series_id, series_on) where series_id is not null;
create index event_series_id_owner_id_idx
  on public.event (series_id, owner_id);

alter table public.event_series enable row level security;
alter table public.event_series_attendee enable row level security;

create policy event_series_select_own on public.event_series
  for select to authenticated using (owner_id = (select auth.uid()));
create policy event_series_insert_own on public.event_series
  for insert to authenticated with check (owner_id = (select auth.uid()));
create policy event_series_update_own on public.event_series
  for update to authenticated
  using (owner_id = (select auth.uid()))
  with check (owner_id = (select auth.uid()));
create policy event_series_delete_own on public.event_series
  for delete to authenticated using (owner_id = (select auth.uid()));

create policy event_series_attendee_select_own on public.event_series_attendee
  for select to authenticated using (owner_id = (select auth.uid()));
create policy event_series_attendee_insert_own on public.event_series_attendee
  for insert to authenticated with check (owner_id = (select auth.uid()));
create policy event_series_attendee_delete_own on public.event_series_attendee
  for delete to authenticated using (owner_id = (select auth.uid()));

revoke all on public.event_series, public.event_series_attendee
  from anon, authenticated;
grant select, insert, update, delete on public.event_series to authenticated;
grant select, insert, delete on public.event_series_attendee to authenticated;

-- Generates every series' occurrences up to a year after p_today (the
-- device's today) or its end day, from the day after generated_until. RLS
-- scopes the series to the caller; the rows are locked so two devices
-- don't both generate, and the unique index makes a retry harmless.
-- ponytail: "forever" is a rolling year; the calendar shows nothing past
-- it. Extend to the month shown if someone browses that far.
create function public.extend_event_series(p_today date) returns void
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
        insert into public.event_attendee (event_id, person_id)
          select new_id, a.person_id from public.event_series_attendee a
          where a.series_id = s.id;
      end if;
      d := d + step;
    end loop;
    update public.event_series set generated_until = horizon where id = s.id;
  end loop;
end $$;

-- Adds and removes people on p_event's series and on every not done
-- occurrence from p_event on. Done occurrences are history; earlier ones
-- keep who they had.
create function public.set_series_attendees(
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

  insert into public.event_attendee (event_id, person_id)
    select o.id, p from public.event o cross join unnest(p_add) as p
    where o.series_id = target.series_id
      and o.series_on >= target.series_on and o.done_at is null
    on conflict do nothing;
  delete from public.event_attendee a
    using public.event o
    where a.event_id = o.id and o.series_id = target.series_id
      and o.series_on >= target.series_on and o.done_at is null
      and a.person_id = any(p_remove);
end $$;

revoke execute on function public.extend_event_series(date) from public, anon;
revoke execute on function public.set_series_attendees(uuid, uuid[], uuid[])
  from public, anon;
grant execute on function public.extend_event_series(date) to authenticated;
grant execute on function public.set_series_attendees(uuid, uuid[], uuid[])
  to authenticated;

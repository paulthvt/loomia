-- LRP renewal (#317). An LRP renews on a day of the month (loyalty_day,
-- 1 to 28 so every month has it). From 3 days before each renewal Today
-- asks to check in with the person; ticking it records that renewal as
-- checked (loyalty_checked_for) with a reminder entry, a kind every app
-- version reads. Not a workflow: it takes nobody off theirs.

alter table public.person
  add column loyalty_day smallint check (loyalty_day between 1 and 28),
  add column loyalty_checked_for date;

-- Every LRP so far renews on the day it started, the 29th to 31st on the 28th.
update public.person
  set loyalty_day = least(extract(day from loyalty_since)::int, 28)
  where loyalty_since is not null;

-- As in 20261010130800_loyalty_on_person.sql; a start fills the renewal day
-- from its own day when there is none, a move keeps it, a stop clears both.
create or replace function public.set_loyalty(p_person uuid, p_since date, p_today date)
returns public.person
language plpgsql security definer set search_path = '' as $$
declare
  target public.person;
  latest uuid;
  saved public.person;
begin
  select * into target from public.person
    where id = p_person and owner_id = (select auth.uid())
    for update;
  if target.id is null then
    raise exception 'no person %', p_person using errcode = 'P0002';
  end if;
  if target.loyalty_since is not distinct from p_since then
    return target;
  end if;

  if p_since is null then
    insert into public.activity (owner_id, person_id, kind, happened_on)
      values (target.owner_id, p_person, 'loyalty_stop', p_today);
  else
    if target.loyalty_since is not null then
      select a.id into latest from public.activity a
        where a.person_id = p_person and a.kind = 'loyalty_start'
        order by a.happened_on desc, a.created_at desc
        limit 1;
    end if;
    if latest is null then
      insert into public.activity (owner_id, person_id, kind, happened_on)
        values (target.owner_id, p_person, 'loyalty_start', p_since);
    else
      update public.activity set happened_on = p_since where id = latest;
    end if;
  end if;

  update public.person
    set loyalty_since = p_since,
        loyalty_day = case
          when p_since is null then null
          else coalesce(target.loyalty_day, least(extract(day from p_since)::int, 28))
        end,
        loyalty_checked_for = case
          when p_since is null then null else target.loyalty_checked_for
        end
    where id = p_person
    returning * into saved;
  return saved;
end $$;

-- The renewal to check in about on p_on (the device's day): this month's,
-- or next month's once this month's has passed; due from 3 days before
-- until the day itself, unless already checked. Null otherwise.
create function public.loyalty_renewal_on(p public.person, p_on date) returns date
language sql stable security invoker set search_path = '' as $$
  select r.renewal
  from (
    select case
      when extract(day from p_on) <= p.loyalty_day
        then make_date(extract(year from p_on)::int,
                       extract(month from p_on)::int, p.loyalty_day)
      else (make_date(extract(year from p_on)::int,
                      extract(month from p_on)::int, p.loyalty_day)
            + interval '1 month')::date
    end as renewal
  ) r
  where p.loyalty_since is not null and p.loyalty_day is not null
    and p_on >= r.renewal - 3
    and p.loyalty_checked_for is distinct from r.renewal
$$;

-- Ticks p_renewal: a reminder entry with the device's text on p_on, and the
-- renewal checked. The same renewal again adds nothing (a second device).
create function public.check_loyalty(
  p_person uuid, p_renewal date, p_on date, p_text text
) returns public.person
language plpgsql security invoker set search_path = '' as $$
declare
  target public.person;
  saved public.person;
begin
  select * into target from public.person where id = p_person for update;
  if target.id is null then
    raise exception 'no person %', p_person using errcode = 'P0002';
  end if;
  if target.loyalty_since is null then
    raise exception 'person % has no LRP', p_person using errcode = 'P0001';
  end if;
  if target.loyalty_checked_for is not distinct from p_renewal then
    return target;
  end if;
  insert into public.activity (person_id, kind, text, happened_on)
    values (p_person, 'reminder', p_text, p_on);
  update public.person set loyalty_checked_for = p_renewal
    where id = p_person
    returning * into saved;
  return saved;
end $$;

-- As in 20261014191609_whats_next.sql, with LRP renewals.
create or replace function public.due_people_count(p_owner uuid, p_on date)
returns int
language sql stable security invoker set search_path = '' as $$
  select count(*)::int from public.person p
  where p.owner_id = p_owner
    and (public.due_on(p) <= p_on
         or public.needs_next(p)
         or public.loyalty_renewal_on(p, p_on) is not null
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

revoke execute on function public.loyalty_renewal_on(public.person, date)
  from public, anon;
revoke execute on function public.check_loyalty(uuid, date, date, text)
  from public, anon;
grant execute on function public.loyalty_renewal_on(public.person, date)
  to authenticated, service_role;
grant execute on function public.check_loyalty(uuid, date, date, text)
  to authenticated;

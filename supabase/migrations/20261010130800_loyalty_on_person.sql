-- LRP on the contact (#255), part 2. The LRP is a fact about the person, the
-- day it started; null without one. Only set_loyalty writes it, by hand or
-- through complete_step, and it writes the history entry in the same
-- transaction. Goals count people whose LRP started in the month, so a
-- workflow with two loyalty steps no longer counts someone twice. Months
-- already closed keep their frozen record.
alter table public.person add column loyalty_since date;

-- Loyalty entries read from their kind: no text.
alter table public.activity drop constraint entry_shape;
alter table public.activity add constraint entry_shape check (
  (kind = 'stage' and stage is not null and text is null)
  or (kind <> 'stage' and stage is null
      and (text is null or length(trim(text)) > 0)
      and (text is not null
           or (kind = 'order' and amount is not null)
           or kind in ('loyalty_start', 'loyalty_stop')))
);

-- Like stage entries, loyalty entries come from the server only and are
-- never edited or deleted by the app: the person's loyalty_since is the
-- truth, and the history follows it.
drop policy activity_insert_own on public.activity;
create policy activity_insert_own on public.activity
  for insert to authenticated
  with check (owner_id = (select auth.uid())
    and kind not in ('stage', 'loyalty_start', 'loyalty_stop'));

drop policy activity_update_own on public.activity;
create policy activity_update_own on public.activity
  for update to authenticated
  using (owner_id = (select auth.uid())
    and kind not in ('stage', 'loyalty_start', 'loyalty_stop'))
  with check (owner_id = (select auth.uid())
    and kind not in ('stage', 'loyalty_start', 'loyalty_stop'));

drop policy activity_delete_own on public.activity;
create policy activity_delete_own on public.activity
  for delete to authenticated
  using (owner_id = (select auth.uid())
    and kind not in ('stage', 'loyalty_start', 'loyalty_stop'));

-- Starts (from null), moves (another day) or stops (p_since null) the LRP.
-- A stop is dated p_today, the device's day. Moving the day moves the latest
-- start entry; someone backfilled from a step has none, and gets one.
-- security definer: it writes entries the app cannot, so it checks the
-- owner itself.
create function public.set_loyalty(p_person uuid, p_since date, p_today date)
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

  update public.person set loyalty_since = p_since
    where id = p_person
    returning * into saved;
  return saved;
end $$;

revoke execute on function public.set_loyalty(uuid, date, date) from public, anon;
grant execute on function public.set_loyalty(uuid, date, date) to authenticated;

-- The first loyalty step starts the LRP on its day; one already started
-- stays as it is, and a second loyalty step does not count again.
create or replace function public.complete_step(p_person uuid, p_step uuid, p_on date)
returns public.person
language plpgsql security invoker set search_path = '' as $$
declare
  target public.person;
  step public.workflow_step;
  next_position numeric;
  moved public.person;
begin
  select * into target from public.person where id = p_person for update;
  if target.id is null
    or public.current_step_id(target) is distinct from p_step then
    raise exception 'step % is not the current step of person %', p_step, p_person
      using errcode = 'P0002';
  end if;

  select * into step from public.workflow_step where id = p_step;
  select coalesce(min(s.position), 1e9) into next_position
    from public.workflow_step s
    where s.workflow_id = step.workflow_id and s.position > step.position;

  insert into public.activity (person_id, kind, text, happened_on, loyalty_setup)
    values (p_person, 'step', step.label, p_on, step.loyalty_setup);
  if step.loyalty_setup and target.loyalty_since is null then
    perform public.set_loyalty(p_person, p_on, p_on);
  end if;
  update public.person
    set at_position = next_position, last_tick = p_on
    where id = p_person
    returning * into moved;
  return moved;
end $$;

revoke execute on function public.complete_step(uuid, uuid, date) from public, anon;
grant execute on function public.complete_step(uuid, uuid, date) to authenticated;

create or replace function public.month_progress(
  p_month date, p_starts timestamptz, p_ends timestamptz
) returns table (
  own_volume numeric, prospects int, customers int, team_members int,
  loyalty int
)
language sql stable security invoker set search_path = '' as $$
  with bounds as (
    select p_month as first_day, (p_month + interval '1 month')::date as next_month
  ),
  added as (
    select p.id, p.first_stage from public.person p
      where least(p.created_at, p.stage_since) >= p_starts
        and least(p.created_at, p.stage_since) < p_ends
  ),
  joined as (
    select a.person_id, a.stage from public.activity a
      where a.kind = 'stage'
        and a.created_at >= p_starts and a.created_at < p_ends
    union
    select id, first_stage from added
  )
  select
    (select coalesce(sum(a.amount), 0) from public.activity a, bounds b
      where a.kind = 'order'
        and a.happened_on >= b.first_day and a.happened_on < b.next_month),
    (select count(*)::int from added where first_stage = 'prospect'),
    (select count(distinct j.person_id)::int from joined j
      where j.stage = 'customer'),
    (select count(distinct j.person_id)::int from joined j
      where j.stage = 'team'),
    (select count(*)::int from public.person p, bounds b
      where p.loyalty_since >= b.first_day and p.loyalty_since < b.next_month)
$$;

-- Someone with an LRP already is not likely to start one.
create or replace function public.loyalty_forecast(p_month date) returns int
language sql stable security invoker set search_path = '' as $$
  select count(*)::int from public.person p
  where p.stage = 'customer' and p.paused_at is null
    and p.loyalty_since is null
    and exists (
      select 1 from (
        select s.loyalty_setup,
               p.last_tick + (sum(s.days) over (order by s.position))::int as due
        from public.workflow_step s
        where s.workflow_id = p.workflow_id and s.position >= p.at_position
      ) walk
      where walk.loyalty_setup
        and walk.due < (p_month + interval '1 month')::date
    )
$$;

-- Everyone who already ticked a loyalty step started then. Their step
-- entries already tell it: no start entry is written.
update public.person p set loyalty_since = f.first_on
  from (
    select a.person_id, min(a.happened_on) as first_on from public.activity a
    where a.kind = 'step' and a.loyalty_setup
    group by a.person_id
  ) f
  where f.person_id = p.id;

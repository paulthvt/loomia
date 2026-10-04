-- Goals (#141): what a month aimed for, what it did, and closing it.
-- Counting rules live here once; the device sends its own month bounds
-- because "today" and the time zone are the device's (#48).

-- "Added as a prospect" apart from "moved to prospect".
alter table public.person add column first_stage public.person_stage;
update public.person set first_stage = stage;
alter table public.person alter column first_stage set not null;

create function public.person_first_stage() returns trigger
language plpgsql security invoker set search_path = '' as $$
begin
  new.first_stage = new.stage;
  return new;
end $$;

create trigger person_first_stage before insert on public.person
  for each row execute function public.person_first_stage();

create table public.month_plan (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null default auth.uid()
    references auth.users on delete cascade,
  month date not null check (extract(day from month) = 1),
  own_volume_target numeric(12,2) check (own_volume_target >= 0),
  team_volume_target numeric(12,2) check (team_volume_target >= 0),
  level_target text,
  prospects_target int check (prospects_target >= 0),
  customers_target int check (customers_target >= 0),
  team_members_target int check (team_members_target >= 0),
  loyalty_target int check (loyalty_target >= 0),
  -- What was suggested when planning, to compare with what happened.
  loyalty_forecast int check (loyalty_forecast >= 0),
  -- Frozen by close_month.
  own_volume_actual numeric(12,2),
  prospects_actual int,
  customers_actual int,
  team_members_actual int,
  loyalty_actual int,
  -- Typed at close: the company computes them, not the book.
  team_volume_actual numeric(12,2) check (team_volume_actual >= 0),
  level_actual text,
  closed_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (owner_id, month)
);

create trigger month_plan_set_updated_at before update on public.month_plan
  for each row execute function public.set_updated_at();

alter table public.month_plan enable row level security;

create policy month_plan_select_own on public.month_plan
  for select to authenticated using (owner_id = (select auth.uid()));
create policy month_plan_insert_own on public.month_plan
  for insert to authenticated with check (owner_id = (select auth.uid()));
create policy month_plan_update_own on public.month_plan
  for update to authenticated
  using (owner_id = (select auth.uid()))
  with check (owner_id = (select auth.uid()));
create policy month_plan_delete_own on public.month_plan
  for delete to authenticated using (owner_id = (select auth.uid()));

revoke all on public.month_plan from anon, authenticated;
grant select, insert, update, delete on public.month_plan to authenticated;

-- One row: what the month did so far. Dates the user picked (orders, steps)
-- are read against p_month; instants (people added, stage entries) against
-- the device's local month, [p_starts, p_ends).
create function public.month_progress(
  p_month date, p_starts timestamptz, p_ends timestamptz
) returns table (
  own_volume numeric, prospects int, customers int, team_members int,
  loyalty int
)
language sql stable security invoker set search_path = '' as $$
  with bounds as (
    select p_month as first_day, (p_month + interval '1 month')::date as next_month
  ),
  joined as (
    select a.person_id, a.stage from public.activity a
      where a.kind = 'stage'
        and a.created_at >= p_starts and a.created_at < p_ends
    union
    select p.id, p.first_stage from public.person p
      where p.created_at >= p_starts and p.created_at < p_ends
  )
  select
    (select coalesce(sum(a.amount), 0) from public.activity a, bounds b
      where a.kind = 'order'
        and a.happened_on >= b.first_day and a.happened_on < b.next_month),
    (select count(*)::int from public.person p
      where p.first_stage = 'prospect'
        and p.created_at >= p_starts and p.created_at < p_ends),
    (select count(distinct j.person_id)::int from joined j
      where j.stage = 'customer'),
    (select count(distinct j.person_id)::int from joined j
      where j.stage = 'team'),
    (select count(*)::int from public.activity a, bounds b
      where a.kind = 'step' and a.loyalty_setup
        and a.happened_on >= b.first_day and a.happened_on < b.next_month)
$$;

revoke execute on function public.month_progress(date, timestamptz, timestamptz)
  from public, anon;
grant execute on function public.month_progress(date, timestamptz, timestamptz)
  to authenticated;

-- Freezes the month's progress with the two actuals only the company knows.
-- A month closes once; one with no plan gets a record of actuals only.
create function public.close_month(
  p_month date, p_starts timestamptz, p_ends timestamptz,
  p_team_volume_actual numeric, p_level_actual text
) returns public.month_plan
language plpgsql security invoker set search_path = '' as $$
declare
  done record;
  closed public.month_plan;
begin
  select * into done from public.month_progress(p_month, p_starts, p_ends);
  insert into public.month_plan as m (
    month, own_volume_actual, prospects_actual, customers_actual,
    team_members_actual, loyalty_actual, team_volume_actual, level_actual,
    closed_at
  ) values (
    p_month, done.own_volume, done.prospects, done.customers,
    done.team_members, done.loyalty, p_team_volume_actual,
    nullif(trim(p_level_actual), ''), now()
  )
  on conflict (owner_id, month) do update set
    own_volume_actual = excluded.own_volume_actual,
    prospects_actual = excluded.prospects_actual,
    customers_actual = excluded.customers_actual,
    team_members_actual = excluded.team_members_actual,
    loyalty_actual = excluded.loyalty_actual,
    team_volume_actual = excluded.team_volume_actual,
    level_actual = excluded.level_actual,
    closed_at = excluded.closed_at
  where m.closed_at is null
  returning * into closed;
  if closed.id is null then
    raise exception 'month % already closed', p_month using errcode = 'P0001';
  end if;
  return closed;
end $$;

revoke execute on function
  public.close_month(date, timestamptz, timestamptz, numeric, text)
  from public, anon;
grant execute on function
  public.close_month(date, timestamptz, timestamptz, numeric, text)
  to authenticated;

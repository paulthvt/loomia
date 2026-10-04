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

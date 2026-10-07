-- Events (#151): what is on the calendar. Attendees (#152) and event
-- workflows (#153) come later.

create table public.event (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null default auth.uid()
    references auth.users on delete cascade,
  title text not null check (length(trim(title)) > 0),
  starts_at timestamptz not null,
  ends_at timestamptz check (ends_at > starts_at),
  place text,
  -- A meeting link. The app adds https:// to a bare address.
  link text check (link ~* '^https?://'),
  notes text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- The calendar reads by date. Today it loads everything; this is for when
-- it reads a month at a time.
create index event_owner_id_starts_at_idx
  on public.event (owner_id, starts_at);

create trigger event_set_updated_at before update on public.event
  for each row execute function public.set_updated_at();

alter table public.event enable row level security;

create policy event_select_own on public.event
  for select to authenticated using (owner_id = (select auth.uid()));
create policy event_insert_own on public.event
  for insert to authenticated with check (owner_id = (select auth.uid()));
create policy event_update_own on public.event
  for update to authenticated
  using (owner_id = (select auth.uid()))
  with check (owner_id = (select auth.uid()));
create policy event_delete_own on public.event
  for delete to authenticated using (owner_id = (select auth.uid()));

revoke all on public.event from anon, authenticated;
grant select, insert, update, delete on public.event to authenticated;

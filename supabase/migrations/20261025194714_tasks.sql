-- Tasks (#375): a title, a day, an optional note, and an optional done date.
-- Each one is about nothing specific: no person, no event. Kept after done.
create table public.task (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null default auth.uid()
    references auth.users on delete cascade,
  title text not null check (length(trim(title)) > 0),
  note text,
  due_on date not null,
  done_on date,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index task_owner_id_due_on_idx
  on public.task (owner_id, due_on);

create trigger task_set_updated_at before update on public.task
  for each row execute function public.set_updated_at();

alter table public.task enable row level security;

create policy task_select_own on public.task
  for select to authenticated using (owner_id = (select auth.uid()));
create policy task_insert_own on public.task
  for insert to authenticated with check (owner_id = (select auth.uid()));
create policy task_update_own on public.task
  for update to authenticated
  using (owner_id = (select auth.uid()))
  with check (owner_id = (select auth.uid()));
create policy task_delete_own on public.task
  for delete to authenticated using (owner_id = (select auth.uid()));

revoke all on public.task from anon, authenticated;
grant select, insert, delete on public.task to authenticated;
grant update (title, note, due_on, done_on) on public.task to authenticated;

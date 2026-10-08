-- Reminders (#217): a line of text for one person, due on a day, outside any
-- workflow. Ticked once: the history keeps what was done, the row goes.
alter type public.activity_kind add value 'reminder';

create table public.reminder (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null default auth.uid()
    references auth.users on delete cascade,
  person_id uuid not null,
  text text not null check (length(trim(text)) > 0),
  due_on date not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  foreign key (person_id, owner_id)
    references public.person (id, owner_id) on delete cascade
);

create index reminder_person_id_owner_id_idx
  on public.reminder (person_id, owner_id);

create trigger reminder_set_updated_at before update on public.reminder
  for each row execute function public.set_updated_at();

alter table public.reminder enable row level security;

create policy reminder_select_own on public.reminder
  for select to authenticated using (owner_id = (select auth.uid()));
create policy reminder_insert_own on public.reminder
  for insert to authenticated with check (owner_id = (select auth.uid()));
create policy reminder_update_own on public.reminder
  for update to authenticated
  using (owner_id = (select auth.uid()))
  with check (owner_id = (select auth.uid()));
create policy reminder_delete_own on public.reminder
  for delete to authenticated using (owner_id = (select auth.uid()));

revoke all on public.reminder from anon, authenticated;
grant select, insert, delete on public.reminder to authenticated;
grant update (text, due_on) on public.reminder to authenticated;

-- Ticks a reminder: the history entry, with its text, and the delete, in one
-- transaction. Gone already (ticked on another device) or another owner's:
-- refused, so a stale tick adds nothing.
create function public.complete_reminder(p_reminder uuid, p_on date)
returns public.person
language plpgsql security invoker set search_path = '' as $$
declare
  target public.reminder;
  done public.person;
begin
  select * into target from public.reminder where id = p_reminder for update;
  if not found then
    raise exception 'reminder % not found', p_reminder using errcode = 'P0002';
  end if;
  insert into public.activity (person_id, kind, text, happened_on)
    values (target.person_id, 'reminder', target.text, p_on);
  delete from public.reminder where id = p_reminder;
  select * into done from public.person where id = target.person_id;
  return done;
end $$;

revoke execute on function public.complete_reminder(uuid, date) from public, anon;
grant execute on function public.complete_reminder(uuid, date) to authenticated;

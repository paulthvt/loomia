-- What's next (#316). A workflow lists the workflows of its stage that can
-- follow it. needs_next is the one rule for "ask what's next": someone done
-- with a workflow that has next options, or a customer done with one who
-- has no LRP yet. Today shows it until answered; the push counts it.

create table public.workflow_next (
  workflow_id uuid not null,
  next_workflow_id uuid not null,
  owner_id uuid not null default auth.uid()
    references auth.users on delete cascade,
  created_at timestamptz not null default now(),
  primary key (workflow_id, next_workflow_id),
  constraint workflow_next_from_fkey foreign key (workflow_id, owner_id)
    references public.workflow (id, owner_id) on delete cascade,
  constraint workflow_next_to_fkey foreign key (next_workflow_id, owner_id)
    references public.workflow (id, owner_id) on delete cascade,
  check (workflow_id <> next_workflow_id)
);

create index workflow_next_next_workflow_id_owner_id_idx
  on public.workflow_next (next_workflow_id, owner_id);

-- Becoming a customer is a stage change, not a next workflow.
create function public.workflow_next_same_stage() returns trigger
language plpgsql security invoker set search_path = '' as $$
begin
  if (select stage from public.workflow where id = new.workflow_id)
     is distinct from
     (select stage from public.workflow where id = new.next_workflow_id) then
    raise exception 'a next workflow is for the same stage'
      using errcode = '23514';
  end if;
  return new;
end $$;

create trigger workflow_next_same_stage
  before insert or update on public.workflow_next
  for each row execute function public.workflow_next_same_stage();

alter table public.workflow_next enable row level security;

create policy workflow_next_select_own on public.workflow_next
  for select to authenticated using (owner_id = (select auth.uid()));
create policy workflow_next_insert_own on public.workflow_next
  for insert to authenticated with check (owner_id = (select auth.uid()));
create policy workflow_next_delete_own on public.workflow_next
  for delete to authenticated using (owner_id = (select auth.uid()));

revoke all on public.workflow_next from anon, authenticated;
grant select, insert, delete on public.workflow_next to authenticated;

-- Done with a workflow (not paused) that has next options, or a customer
-- done with one who has no LRP. A repeating workflow is never done.
create function public.needs_next(p public.person) returns boolean
language sql stable security invoker set search_path = '' as $$
  select p.workflow_id is not null
    and p.paused_at is null
    and public.current_step_id(p) is null
    and (exists (
           select 1 from public.workflow_next n
           where n.workflow_id = p.workflow_id)
         or (p.stage = 'customer' and p.loyalty_since is null))
$$;

-- As in 20261014171423_event_invitations.sql, with what's next.
create or replace function public.due_people_count(p_owner uuid, p_on date)
returns int
language sql stable security invoker set search_path = '' as $$
  select count(*)::int from public.person p
  where p.owner_id = p_owner
    and (public.due_on(p) <= p_on
         or public.needs_next(p)
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

revoke execute on function public.workflow_next_same_stage() from public, anon;
revoke execute on function public.needs_next(public.person) from public, anon;
grant execute on function public.needs_next(public.person)
  to authenticated, service_role;

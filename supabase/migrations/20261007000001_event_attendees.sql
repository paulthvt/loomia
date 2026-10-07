-- Event attendees (#152): who is invited to an event, who was there, and
-- marking it done. Event workflows (#153) build on mark_event_done.

alter type public.activity_kind add value 'event';

alter table public.event
  add column done_at timestamptz,
  -- Target of event_attendee's composite foreign key.
  add constraint event_id_owner_key unique (id, owner_id);

create table public.event_attendee (
  event_id uuid not null,
  person_id uuid not null,
  owner_id uuid not null default auth.uid()
    references auth.users on delete cascade,
  came boolean not null default false,
  created_at timestamptz not null default now(),
  primary key (event_id, person_id),
  foreign key (event_id, owner_id)
    references public.event (id, owner_id) on delete cascade,
  foreign key (person_id, owner_id)
    references public.person (id, owner_id) on delete cascade
);

create index event_attendee_person_id_owner_id_idx
  on public.event_attendee (person_id, owner_id);

alter table public.event_attendee enable row level security;

-- Once an event is done its attendance is history: no one joins, leaves or
-- changes. mark_event_done writes `came` before it sets done_at.
create function public.event_open(p_event uuid) returns boolean
language sql stable security invoker set search_path = '' as $$
  select exists (
    select 1 from public.event where id = p_event and done_at is null
  )
$$;

create policy event_attendee_select_own on public.event_attendee
  for select to authenticated using (owner_id = (select auth.uid()));
create policy event_attendee_insert_own on public.event_attendee
  for insert to authenticated
  with check (owner_id = (select auth.uid()) and public.event_open(event_id));
create policy event_attendee_update_own on public.event_attendee
  for update to authenticated
  using (owner_id = (select auth.uid()) and public.event_open(event_id))
  with check (owner_id = (select auth.uid()));
create policy event_attendee_delete_own on public.event_attendee
  for delete to authenticated
  using (owner_id = (select auth.uid()) and public.event_open(event_id));

revoke all on public.event_attendee from anon, authenticated;
grant select, insert, update, delete on public.event_attendee to authenticated;

-- Marks who was there, in one transaction: their flags, an Event entry in
-- each of their histories on the device's p_today, then done_at. plpgsql, so
-- the new 'event' value is not resolved while this migration is still open.
create function public.mark_event_done(
  p_event uuid, p_came uuid[], p_today date
) returns public.event
language plpgsql security invoker set search_path = '' as $$
declare
  marked public.event;
begin
  select * into marked from public.event where id = p_event for update;
  if not found then
    raise exception 'event % not found', p_event using errcode = 'P0002';
  end if;
  if marked.done_at is not null then
    raise exception 'event % is already done', p_event using errcode = 'P0001';
  end if;
  if exists (
    select 1 from unnest(p_came) as c(person_id)
    where not exists (
      select 1 from public.event_attendee a
      where a.event_id = p_event and a.person_id = c.person_id
    )
  ) then
    raise exception 'someone marked as there is not invited to event %', p_event
      using errcode = 'P0001';
  end if;

  update public.event_attendee
    set came = (person_id = any(p_came))
    where event_id = p_event;
  insert into public.activity (person_id, kind, text, happened_on)
    select a.person_id, 'event', marked.title, p_today
    from public.event_attendee a
    where a.event_id = p_event and a.came;
  update public.event set done_at = now()
    where id = p_event
    returning * into marked;
  return marked;
end $$;

revoke execute on function public.event_open(uuid) from public, anon;
revoke execute on function public.mark_event_done(uuid, uuid[], date)
  from public, anon;
grant execute on function public.event_open(uuid) to authenticated;
grant execute on function public.mark_event_done(uuid, uuid[], date)
  to authenticated;

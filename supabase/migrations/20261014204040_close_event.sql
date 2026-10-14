-- Who was there records what changed (#318). close_event marks an event done
-- with, for each person who came, whether a prospect became a customer
-- (their registration order, the default customer workflow) or an order;
-- people on an event step of its type move past it; absent guests of a group
-- event can be invited to the next one. It sits beside mark_event_done,
-- which builds before this one still call; a later migration drops that and
-- the stage → workflow mapping columns once every device runs this build.

create function public.close_event(
  p_event uuid, p_there jsonb, p_invite_next uuid[], p_today date
) returns public.event
language plpgsql security invoker set search_path = '' as $$
declare
  marked public.event;
  there uuid[];
  t record;
  first_customer public.workflow;
  next_event uuid;
begin
  select * into marked from public.event where id = p_event for update;
  if not found then
    raise exception 'event % not found', p_event using errcode = 'P0002';
  end if;
  if marked.done_at is not null then
    raise exception 'event % is already done', p_event using errcode = 'P0001';
  end if;

  select coalesce(array_agg(x.person), '{}') into there
    from jsonb_to_recordset(coalesce(p_there, '[]')) as x(person uuid);
  if exists (
    select 1 from unnest(there || coalesce(p_invite_next, '{}')) as c(person_id)
    where not exists (
      select 1 from public.event_attendee a
      where a.event_id = p_event and a.person_id = c.person_id)
  ) then
    raise exception 'someone listed is not invited to event %', p_event
      using errcode = 'P0001';
  end if;
  if there && coalesce(p_invite_next, '{}') then
    raise exception 'someone who came cannot be invited to the next one'
      using errcode = 'P0001';
  end if;

  update public.event_attendee
    set came = (person_id = any(there))
    where event_id = p_event;
  insert into public.activity (person_id, kind, text, happened_on)
    select a.person_id, 'event', marked.title, p_today
    from public.event_attendee a
    where a.event_id = p_event and a.came;

  -- Past the event step of this type first: someone on Workshop invite who
  -- becomes a customer finishes it, then starts the customer workflow.
  update public.person p
    set at_position = public.position_after(s.id), last_tick = p_today
    from public.workflow_step s
    where p.id = any(there)
      and s.id = public.current_step_id(p)
      and s.event_workflow_id = marked.event_workflow_id;

  select * into first_customer from public.workflow
    where stage = 'customer' and is_default;

  for t in
    select * from jsonb_to_recordset(coalesce(p_there, '[]'))
      as x(person uuid, customer boolean, amount numeric, text text)
  loop
    if coalesce(t.customer, false)
       and (select stage from public.person where id = t.person) = 'prospect'
    then
      update public.person
        set stage = 'customer',
            workflow_id = first_customer.id,
            at_position = case when first_customer.id is null then null
              else (select min(s.position) from public.workflow_step s
                    where s.workflow_id = first_customer.id) end,
            last_tick = case when first_customer.id is null then null
              else p_today end,
            paused_at = null
        where id = t.person;
      insert into public.activity (person_id, kind, text, amount, happened_on)
        values (t.person, 'order', nullif(trim(t.text), ''), t.amount, p_today);
    elsif t.amount is not null then
      insert into public.activity (person_id, kind, text, amount, happened_on)
        values (t.person, 'order', nullif(trim(t.text), ''), t.amount, p_today);
    end if;
  end loop;

  -- Absent guests of a group event: the next open one of its type.
  if coalesce(cardinality(p_invite_next), 0) > 0 then
    select e.id into next_event
      from public.event e
      join public.event_workflow w on w.id = e.event_workflow_id
      where e.event_workflow_id = marked.event_workflow_id
        and w.is_group and e.done_at is null and e.id <> p_event
        and e.starts_at > marked.starts_at
      order by e.starts_at
      limit 1;
    if next_event is not null then
      insert into public.event_attendee (event_id, person_id, invited_on)
        select next_event, p, p_today from unnest(p_invite_next) as p
        on conflict do nothing;
    end if;
  end if;

  update public.event set done_at = now()
    where id = p_event
    returning * into marked;
  return marked;
end $$;

revoke execute on function public.close_event(uuid, jsonb, uuid[], date)
  from public, anon;
grant execute on function public.close_event(uuid, jsonb, uuid[], date)
  to authenticated;

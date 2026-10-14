-- Event steps (#315). A workflow step can be an event step: planned as an
-- event of its type (event_workflow_id). While the person attends an open
-- event of that type, invited or going, the step waits (due_on null). When
-- the event is marked done with them there, they move past it; without
-- them, it is due again. postpone_step puts it off to a day.
-- Same signatures throughout: the released app keeps reading due_on.

alter table public.workflow_step
  add column event_workflow_id uuid,
  add foreign key (event_workflow_id, owner_id)
    references public.event_workflow (id, owner_id)
    on delete set null (event_workflow_id);

create index workflow_step_event_workflow_id_owner_id_idx
  on public.workflow_step (event_workflow_id, owner_id);

-- The open event of the current step's type that the person attends; the
-- earliest. Null on a plain step. Selected by PostgREST as a computed field.
create function public.planned_event_id(p public.person) returns uuid
language sql stable security invoker set search_path = '' as $$
  select e.id
  from public.workflow_step s
  join public.event e on e.event_workflow_id = s.event_workflow_id
  join public.event_attendee a on a.event_id = e.id and a.person_id = p.id
  where s.id = public.current_step_id(p) and e.done_at is null
  order by e.starts_at
  limit 1
$$;

-- When the current step is due: its days after the last tick. Null while
-- paused, with no workflow, done, or planned as an event.
create or replace function public.due_on(p public.person) returns date
language sql stable security invoker set search_path = '' as $$
  select p.last_tick + s.days from public.workflow_step s
  where p.paused_at is null and s.id = public.current_step_id(p)
    and public.planned_event_id(p) is null
$$;

-- Where ticking p_step leads: the next step's position; past the last, the
-- first step's when the workflow repeats, else 1e9 (done, far past any step
-- added later). complete_step and mark_event_done both move by it.
create function public.position_after(p_step uuid) returns numeric
language sql stable security invoker set search_path = '' as $$
  select coalesce(
           min(s.position),
           case when w.repeats
             then (select min(f.position) from public.workflow_step f
                   where f.workflow_id = w.id)
             else 1e9
           end)
  from public.workflow_step step
  join public.workflow w on w.id = step.workflow_id
  left join public.workflow_step s
    on s.workflow_id = w.id and s.position > step.position
  where step.id = p_step
  group by w.id, w.repeats
$$;

-- As in 20261012210500_repeating_workflows.sql, moving by position_after.
create or replace function public.complete_step(p_person uuid, p_step uuid, p_on date)
returns public.person
language plpgsql security invoker set search_path = '' as $$
declare
  target public.person;
  step public.workflow_step;
  moved public.person;
begin
  select * into target from public.person where id = p_person for update;
  if target.id is null
    or public.current_step_id(target) is distinct from p_step then
    raise exception 'step % is not the current step of person %', p_step, p_person
      using errcode = 'P0002';
  end if;

  select * into step from public.workflow_step where id = p_step;
  insert into public.activity (person_id, kind, text, happened_on, loyalty_setup)
    values (p_person, 'step', step.label, p_on, step.loyalty_setup);
  if step.loyalty_setup and target.loyalty_since is null then
    perform public.set_loyalty(p_person, p_on, p_on);
  end if;
  update public.person
    set at_position = public.position_after(p_step), last_tick = p_on
    where id = p_person
    returning * into moved;
  return moved;
end $$;

-- As in 20261007000002_event_workflows.sql; who was there on an event step
-- of this event's type moves past it first, from p_today. A stage mapping,
-- where the event has one, still replaces their workflow after that.
create or replace function public.mark_event_done(
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
  update public.person p
    set at_position = public.position_after(s.id), last_tick = p_today
    from public.event_attendee a, public.workflow_step s
    where a.event_id = p_event and a.came and a.person_id = p.id
      and s.id = public.current_step_id(p)
      and s.event_workflow_id = marked.event_workflow_id;
  -- Who was there starts the workflow for their stage, in place of the one
  -- they are on, from today; no mapping for their stage keeps theirs.
  update public.person p
    set workflow_id = mapped.workflow_id,
        at_position = coalesce(
          (select min(s.position) from public.workflow_step s
           where s.workflow_id = mapped.workflow_id),
          0),
        last_tick = p_today,
        paused_at = null
    from (
      select a.person_id,
             case pe.stage
               when 'prospect' then marked.prospect_workflow_id
               when 'customer' then marked.customer_workflow_id
               else marked.team_workflow_id
             end as workflow_id
      from public.event_attendee a
      join public.person pe on pe.id = a.person_id
      where a.event_id = p_event and a.came
    ) mapped
    where p.id = mapped.person_id and mapped.workflow_id is not null;
  update public.event set done_at = now()
    where id = p_event
    returning * into marked;
  return marked;
end $$;

-- Puts the current event step off to p_until: due that day, waiting as
-- before once planned. Refuses another step (a stale device) and a plain
-- step, which is ticked instead.
create function public.postpone_step(p_person uuid, p_step uuid, p_until date)
returns public.person
language plpgsql security invoker set search_path = '' as $$
declare
  target public.person;
  step public.workflow_step;
  moved public.person;
begin
  select * into target from public.person where id = p_person for update;
  if target.id is null
    or public.current_step_id(target) is distinct from p_step then
    raise exception 'step % is not the current step of person %', p_step, p_person
      using errcode = 'P0002';
  end if;
  select * into step from public.workflow_step where id = p_step;
  if step.event_workflow_id is null then
    raise exception 'step % is not an event step', p_step using errcode = 'P0001';
  end if;
  update public.person
    set last_tick = p_until - step.days
    where id = p_person
    returning * into moved;
  return moved;
end $$;

revoke execute on function public.planned_event_id(public.person) from public, anon;
revoke execute on function public.position_after(uuid) from public, anon;
revoke execute on function public.postpone_step(uuid, uuid, date) from public, anon;
grant execute on function public.planned_event_id(public.person)
  to authenticated, service_role;
grant execute on function public.position_after(uuid) to authenticated;
grant execute on function public.postpone_step(uuid, uuid, date) to authenticated;

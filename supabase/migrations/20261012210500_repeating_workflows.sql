-- Repeating workflows (#296): a workflow can start over after its last step.
-- complete_step, on the last step of a workflow that repeats, moves to the
-- first step's position instead of past the end; current_step_id and due_on
-- are unchanged, so the first step is due its days after that tick. A person
-- already past the end (done before Repeat was switched on) stays done.

alter table public.workflow
  add column repeats boolean not null default false;

-- As in 20261010130800_loyalty_on_person.sql, but for the next position.
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
  select coalesce(
           min(s.position),
           case when w.repeats
             then (select min(f.position) from public.workflow_step f
                   where f.workflow_id = w.id)
             else 1e9
           end)
    into next_position
    from public.workflow w
    left join public.workflow_step s
      on s.workflow_id = w.id and s.position > step.position
    where w.id = step.workflow_id
    group by w.id, w.repeats;

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

-- ponytail: loyalty_forecast walks to the end of the round only; a loyalty
-- step reached by starting over within the month is not counted. Walk the
-- wrap too if a repeating workflow's forecast ever matters.

-- Undo a tick (#372). Each tick's reverse, in one transaction like the tick,
-- refused (P0002, nothing changed) once the person changed since: the app
-- hands back the person's updated_at as it read it after the tick. A step
-- tick and an LRP check update the person in the tick's transaction, so
-- their history entry has created_at = that updated_at (both now()). Additive:
-- the released app never calls these.

-- Definer: the "LRP started" entry a loyalty step wrote is not deletable
-- under RLS (20261010130800_loyalty_on_person.sql). The owner check stands
-- in for it, as in set_loyalty.
create function public.undo_step(
  p_person uuid, p_step uuid, p_on date, p_last_tick date, p_updated_at timestamptz
) returns public.person
language plpgsql security definer set search_path = '' as $$
declare
  target public.person;
  step public.workflow_step;
  entry uuid;
  saved public.person;
begin
  select * into target from public.person
    where id = p_person and owner_id = (select auth.uid())
    for update;
  select * into step from public.workflow_step
    where id = p_step and owner_id = (select auth.uid());
  select a.id into entry from public.activity a
    where a.person_id = p_person and a.kind = 'step'
      and a.happened_on = p_on and a.created_at = p_updated_at;
  if target.id is null or step.id is null or entry is null
    or target.updated_at is distinct from p_updated_at
    or target.workflow_id is distinct from step.workflow_id
    or target.at_position is distinct from public.position_after(p_step)
    or target.last_tick is distinct from p_on then
    raise exception 'the tick of step % on person % cannot be undone', p_step, p_person
      using errcode = 'P0002';
  end if;

  delete from public.activity where id = entry;
  -- The same transaction started their LRP: stop it, as if never started.
  if exists (
    select 1 from public.activity a
    where a.person_id = p_person and a.kind = 'loyalty_start'
      and a.created_at = p_updated_at
  ) then
    delete from public.activity a
      where a.person_id = p_person and a.kind = 'loyalty_start'
        and a.created_at = p_updated_at;
    update public.person
      set loyalty_since = null, loyalty_day = null, loyalty_checked_for = null
      where id = p_person;
  end if;
  update public.person
    set at_position = step.position, last_tick = p_last_tick
    where id = p_person
    returning * into saved;
  return saved;
end $$;

create function public.undo_reminder(
  p_reminder uuid, p_person uuid, p_text text, p_due_on date,
  p_created_at timestamptz, p_on date, p_updated_at timestamptz
) returns void
language plpgsql security invoker set search_path = '' as $$
declare
  target public.person;
  entry uuid;
begin
  select * into target from public.person where id = p_person for update;
  select a.id into entry from public.activity a
    where a.person_id = p_person and a.kind = 'reminder'
      and a.happened_on = p_on and a.text = p_text
    order by a.created_at desc
    limit 1;
  if target.id is null or entry is null
    or target.updated_at is distinct from p_updated_at
    or exists (select 1 from public.reminder where id = p_reminder) then
    raise exception 'the tick of reminder % cannot be undone', p_reminder
      using errcode = 'P0002';
  end if;

  delete from public.activity where id = entry;
  insert into public.reminder (id, person_id, text, due_on, created_at)
    values (p_reminder, p_person, p_text, p_due_on, p_created_at);
end $$;

create function public.undo_loyalty_check(
  p_person uuid, p_renewal date, p_previous date, p_updated_at timestamptz
) returns public.person
language plpgsql security invoker set search_path = '' as $$
declare
  target public.person;
  entry uuid;
  saved public.person;
begin
  select * into target from public.person where id = p_person for update;
  select a.id into entry from public.activity a
    where a.person_id = p_person and a.kind = 'reminder'
      and a.created_at = p_updated_at;
  if target.id is null or entry is null
    or target.updated_at is distinct from p_updated_at
    or target.loyalty_checked_for is distinct from p_renewal then
    raise exception 'the LRP check of person % cannot be undone', p_person
      using errcode = 'P0002';
  end if;

  delete from public.activity where id = entry;
  update public.person set loyalty_checked_for = p_previous
    where id = p_person
    returning * into saved;
  return saved;
end $$;

revoke execute on function public.undo_step(uuid, uuid, date, date, timestamptz)
  from public, anon;
revoke execute on function
  public.undo_reminder(uuid, uuid, text, date, timestamptz, date, timestamptz)
  from public, anon;
revoke execute on function public.undo_loyalty_check(uuid, date, date, timestamptz)
  from public, anon;
grant execute on function public.undo_step(uuid, uuid, date, date, timestamptz)
  to authenticated;
grant execute on function
  public.undo_reminder(uuid, uuid, text, date, timestamptz, date, timestamptz)
  to authenticated;
grant execute on function public.undo_loyalty_check(uuid, date, date, timestamptz)
  to authenticated;

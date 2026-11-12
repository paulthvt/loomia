-- Repeating reminders (#486), the rule of repeating tasks (#376): every n
-- days, weeks, months or years from repeat_from, until repeat_until (null:
-- never). One row per repeat, kept with its id: a tick writes the history
-- entry and moves the row to the first day of the schedule after both its
-- scheduled day and the tick; past the end, the row goes as a plain one.
-- Additive: complete_reminder keeps its signature, so a build without this
-- ticks a repeating reminder forward too; its Undo then finds the row still
-- there and refuses, until the app updates.

alter table public.reminder
  add column repeat_every int check (repeat_every between 1 and 99),
  add column repeat_unit text
    check (repeat_unit in ('day', 'week', 'month', 'year')),
  add column repeat_from date,
  add column repeat_until date,
  add column scheduled_on date,
  add constraint reminder_repeat_whole check (
    (repeat_every is null) = (repeat_unit is null)
    and (repeat_every is null) = (repeat_from is null)
    and (repeat_every is null) = (scheduled_on is null)
    and (repeat_every is not null or repeat_until is null)
    and (repeat_until is null or repeat_until >= repeat_from)
  );

grant update (repeat_every, repeat_unit, repeat_from, repeat_until, scheduled_on)
  on public.reminder to authenticated;

-- task_next_on's schedule on plain values: the first day of the rule after
-- both [p_scheduled] and [p_on]; null when it doesn't repeat or has ended.
create function public.repeat_next_on(
  p_every int, p_unit text, p_from date, p_until date,
  p_scheduled date, p_on date
) returns date
language plpgsql stable security invoker set search_path = '' as $$
declare
  after date := greatest(p_scheduled, p_on);
  -- The longest a unit can be, so the first k tried is never past the answer.
  longest int := case p_unit
    when 'day' then 1 when 'week' then 7 when 'month' then 31 else 366 end;
  k int;
  upcoming date;
begin
  if p_every is null then
    return null;
  end if;
  k := greatest(0, (after - p_from) / (p_every * longest)) + 1;
  loop
    upcoming := (p_from + case p_unit
      when 'day' then make_interval(days => k * p_every)
      when 'week' then make_interval(weeks => k * p_every)
      when 'month' then make_interval(months => k * p_every)
      else make_interval(years => k * p_every)
    end)::date;
    exit when upcoming > after;
    k := k + 1;
  end loop;
  if p_until is not null and upcoming > p_until then
    return null;
  end if;
  return upcoming;
end $$;

-- [p_reminder]'s next day after [p_on], as repeat_next_on.
create function public.reminder_next_on(p_reminder public.reminder, p_on date)
returns date
language sql stable security invoker set search_path = '' as $$
  select public.repeat_next_on(
    p_reminder.repeat_every, p_reminder.repeat_unit, p_reminder.repeat_from,
    p_reminder.repeat_until, p_reminder.scheduled_on, p_on)
$$;

-- Ticks a reminder: the history entry with its text, then the row moves to
-- its next day, or goes when it doesn't repeat or the schedule has ended.
-- Gone already or another owner's: refused, so a stale tick adds nothing.
create or replace function public.complete_reminder(p_reminder uuid, p_on date)
returns public.person
language plpgsql security invoker set search_path = '' as $$
declare
  target public.reminder;
  upcoming date;
  done public.person;
begin
  select * into target from public.reminder where id = p_reminder for update;
  if not found then
    raise exception 'reminder % not found', p_reminder using errcode = 'P0002';
  end if;
  insert into public.activity (person_id, kind, text, happened_on)
    values (target.person_id, 'reminder', target.text, p_on);
  upcoming := public.reminder_next_on(target, p_on);
  if upcoming is null then
    delete from public.reminder where id = p_reminder;
  else
    update public.reminder set due_on = upcoming, scheduled_on = upcoming
      where id = p_reminder;
  end if;
  select * into done from public.person where id = target.person_id;
  return done;
end $$;

-- Delete, This reminder: the row moves to its next day with no entry, or
-- goes past the end. P0002 when gone, another owner's or not repeating.
create function public.skip_reminder(p_reminder uuid, p_on date)
returns void
language plpgsql security invoker set search_path = '' as $$
declare
  target public.reminder;
  upcoming date;
begin
  select * into target from public.reminder where id = p_reminder for update;
  if target.id is null or target.repeat_every is null then
    raise exception 'reminder % cannot be skipped', p_reminder
      using errcode = 'P0002';
  end if;
  upcoming := public.reminder_next_on(target, p_on);
  if upcoming is null then
    delete from public.reminder where id = p_reminder;
  else
    update public.reminder set due_on = upcoming, scheduled_on = upcoming
      where id = p_reminder;
  end if;
end $$;

-- Takes back the tick of a repeating reminder on [p_on]: the entry goes and
-- the reminder is as the device had it before (the p_ values), rule
-- included. The row must be where the tick left it, untouched: on the next
-- day with the same text and rule, or gone because the schedule ended.
-- Anything else (edited, ticked again, deleted), or the person changed
-- since [p_updated_at]: P0002, as undo_reminder.
create function public.undo_repeating_reminder(
  p_reminder uuid, p_person uuid, p_text text, p_due_on date,
  p_created_at timestamptz, p_repeat_every int, p_repeat_unit text,
  p_repeat_from date, p_repeat_until date, p_scheduled_on date, p_on date,
  p_updated_at timestamptz
) returns void
language plpgsql security invoker set search_path = '' as $$
declare
  target public.person;
  entry uuid;
  current public.reminder;
  upcoming date := public.repeat_next_on(
    p_repeat_every, p_repeat_unit, p_repeat_from, p_repeat_until,
    p_scheduled_on, p_on);
begin
  select * into target from public.person where id = p_person for update;
  select a.id into entry from public.activity a
    where a.person_id = p_person and a.kind = 'reminder'
      and a.happened_on = p_on and a.text = p_text
    order by a.created_at desc
    limit 1;
  select * into current from public.reminder where id = p_reminder for update;
  if target.id is null or entry is null
    or target.updated_at is distinct from p_updated_at
    or (current.id is null and upcoming is not null)
    or (current.id is not null and (
      upcoming is null
      or current.person_id is distinct from p_person
      or current.text is distinct from p_text
      or current.due_on is distinct from upcoming
      or current.scheduled_on is distinct from upcoming
      or current.repeat_every is distinct from p_repeat_every
      or current.repeat_unit is distinct from p_repeat_unit
      or current.repeat_from is distinct from p_repeat_from
      or current.repeat_until is distinct from p_repeat_until)) then
    raise exception 'the tick of reminder % cannot be undone', p_reminder
      using errcode = 'P0002';
  end if;

  delete from public.activity where id = entry;
  if current.id is null then
    insert into public.reminder (
      id, person_id, text, due_on, created_at, repeat_every, repeat_unit,
      repeat_from, repeat_until, scheduled_on
    ) values (
      p_reminder, p_person, p_text, p_due_on, p_created_at, p_repeat_every,
      p_repeat_unit, p_repeat_from, p_repeat_until, p_scheduled_on
    );
  else
    update public.reminder set due_on = p_due_on, scheduled_on = p_scheduled_on
      where id = p_reminder;
  end if;
end $$;

revoke execute on function
  public.repeat_next_on(int, text, date, date, date, date) from public, anon;
revoke execute on function public.reminder_next_on(public.reminder, date)
  from public, anon;
revoke execute on function public.skip_reminder(uuid, date) from public, anon;
revoke execute on function public.undo_repeating_reminder(
  uuid, uuid, text, date, timestamptz, int, text, date, date, date, date,
  timestamptz) from public, anon;
grant execute on function
  public.repeat_next_on(int, text, date, date, date, date) to authenticated;
grant execute on function public.reminder_next_on(public.reminder, date)
  to authenticated;
grant execute on function public.skip_reminder(uuid, date) to authenticated;
grant execute on function public.undo_repeating_reminder(
  uuid, uuid, text, date, timestamptz, int, text, date, date, date, date,
  timestamptz) to authenticated;

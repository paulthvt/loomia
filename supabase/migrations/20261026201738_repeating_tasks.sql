-- Repeating tasks (#376). A task can repeat every n days, weeks, months or
-- years, from repeat_from, until repeat_until (null: never). Ticking it
-- makes the next one, Google Tasks style: one open task per repeat. Its day
-- is the first of the schedule after both the day the rule gave this task
-- (scheduled_on; due_on may have been postponed) and the day it is ticked,
-- so a postponed task keeps the schedule and a late tick skips missed dates.
-- Every date is counted from repeat_from, so Jan 31 -> Feb 28 -> Mar 31.
-- Additive: a build without this ignores the columns and ticks plainly.

alter table public.task
  add column repeat_every int check (repeat_every between 1 and 99),
  add column repeat_unit text
    check (repeat_unit in ('day', 'week', 'month', 'year')),
  add column repeat_from date,
  add column repeat_until date,
  add column scheduled_on date,
  -- The ticked task this one was made from, so Undo finds it.
  add column follows_id uuid references public.task on delete set null,
  add constraint task_repeat_whole check (
    (repeat_every is null) = (repeat_unit is null)
    and (repeat_every is null) = (repeat_from is null)
    and (repeat_every is null) = (scheduled_on is null)
    and (repeat_every is not null or repeat_until is null)
    and (repeat_until is null or repeat_until >= repeat_from)
  );

create index task_follows_id_idx on public.task (follows_id);

grant update (repeat_every, repeat_unit, repeat_from, repeat_until, scheduled_on)
  on public.task to authenticated;

-- The next day of [p_task]'s schedule after both its scheduled day and
-- [p_on]; null when it doesn't repeat or the schedule has ended by then.
create function public.task_next_on(p_task public.task, p_on date)
returns date
language plpgsql stable security invoker set search_path = '' as $$
declare
  after date := greatest(p_task.scheduled_on, p_on);
  -- The longest a unit can be, so the first k tried is never past the answer.
  longest int := case p_task.repeat_unit
    when 'day' then 1 when 'week' then 7 when 'month' then 31 else 366 end;
  k int;
  upcoming date;
begin
  if p_task.repeat_every is null then
    return null;
  end if;
  k := greatest(0, (after - p_task.repeat_from) / (p_task.repeat_every * longest)) + 1;
  loop
    upcoming := (p_task.repeat_from + case p_task.repeat_unit
      when 'day' then make_interval(days => k * p_task.repeat_every)
      when 'week' then make_interval(weeks => k * p_task.repeat_every)
      when 'month' then make_interval(months => k * p_task.repeat_every)
      else make_interval(years => k * p_task.repeat_every)
    end)::date;
    exit when upcoming > after;
    k := k + 1;
  end loop;
  if p_task.repeat_until is not null and upcoming > p_task.repeat_until then
    return null;
  end if;
  return upcoming;
end $$;

-- Ticks [p_id] on [p_on] (the device's today) and, when it repeats, makes
-- the next one. The ticked task keeps its rule, so Undo only deletes the
-- next. P0002 when the task is gone or already done.
create function public.complete_task(p_id uuid, p_on date)
returns public.task
language plpgsql security invoker set search_path = '' as $$
declare
  target public.task;
  upcoming date;
  saved public.task;
begin
  select * into target from public.task where id = p_id for update;
  if target.id is null or target.done_on is not null then
    raise exception 'task % cannot be completed', p_id using errcode = 'P0002';
  end if;
  update public.task set done_on = p_on where id = p_id returning * into saved;
  upcoming := public.task_next_on(target, p_on);
  if upcoming is not null then
    insert into public.task (
      title, note, due_on, repeat_every, repeat_unit, repeat_from,
      repeat_until, scheduled_on, follows_id
    ) values (
      target.title, target.note, upcoming, target.repeat_every,
      target.repeat_unit, target.repeat_from, target.repeat_until, upcoming, p_id
    );
  end if;
  return saved;
end $$;

-- Reopens [p_id]. The task its tick made goes too while it is open and was
-- never edited (insert sets created_at = updated_at; set_updated_at moves
-- the latter on any later edit). If it was ticked or edited it stays, and
-- [p_id] loses its rule, so there is still one open task per repeat.
create function public.undo_task(p_id uuid)
returns void
language plpgsql security invoker set search_path = '' as $$
begin
  update public.task set done_on = null where id = p_id;
  if not found then
    raise exception 'task % cannot be undone', p_id using errcode = 'P0002';
  end if;
  delete from public.task
    where follows_id = p_id and done_on is null and updated_at = created_at;
  if exists (select 1 from public.task where follows_id = p_id) then
    update public.task
      set repeat_every = null, repeat_unit = null, repeat_from = null,
          repeat_until = null, scheduled_on = null
      where id = p_id;
  end if;
end $$;

-- Deletes [p_id]. An open repeating task deleted alone ([p_following]
-- false) makes the next one first, as a tick would, with nothing to undo.
create function public.delete_task(p_id uuid, p_on date, p_following boolean)
returns void
language plpgsql security invoker set search_path = '' as $$
declare
  target public.task;
  upcoming date;
begin
  select * into target from public.task where id = p_id for update;
  if target.id is null then
    raise exception 'task % not found', p_id using errcode = 'P0002';
  end if;
  if target.done_on is null and not p_following then
    upcoming := public.task_next_on(target, p_on);
    if upcoming is not null then
      insert into public.task (
        title, note, due_on, repeat_every, repeat_unit, repeat_from,
        repeat_until, scheduled_on
      ) values (
        target.title, target.note, upcoming, target.repeat_every,
        target.repeat_unit, target.repeat_from, target.repeat_until, upcoming
      );
    end if;
  end if;
  delete from public.task where id = p_id;
end $$;

revoke execute on function public.task_next_on(public.task, date) from public, anon;
revoke execute on function public.complete_task(uuid, date) from public, anon;
revoke execute on function public.undo_task(uuid) from public, anon;
revoke execute on function public.delete_task(uuid, date, boolean) from public, anon;
grant execute on function public.task_next_on(public.task, date) to authenticated;
grant execute on function public.complete_task(uuid, date) to authenticated;
grant execute on function public.undo_task(uuid) to authenticated;
grant execute on function public.delete_task(uuid, date, boolean) to authenticated;

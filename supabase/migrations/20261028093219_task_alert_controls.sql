-- Task notification controls (#389): a Tasks switch for all task pushes and
-- a bell per task. A task pushes only when both are on; both default on, so
-- nothing changes until she turns one off
-- (docs/superpowers/specs/2026-10-28-task-notification-controls-design.md).
-- Additive: the released app doesn't send either column, so they keep their
-- values, and its new tasks get the bell on.

alter table public.notification_settings
  add column task_enabled boolean not null default true;
grant update (task_enabled) on public.notification_settings to authenticated;

alter table public.task
  add column alert boolean not null default true;
grant update (alert) on public.task to authenticated;

-- The bell is an edit, so #376's undo keeps a ticked task's next one once it
-- was changed. It stays out of task_rearm_alert: it says whether, not when,
-- so toggling it never sends a second push for the same time.
drop trigger task_set_updated_at on public.task;
create trigger task_set_updated_at
  before update of title, note, due_on, due_time, alert, done_on,
    repeat_every, repeat_unit, repeat_from, repeat_until, scheduled_on
  on public.task
  for each row execute function public.set_updated_at();

-- #377's functions, now carrying the bell to the next task too.
create or replace function public.complete_task(p_id uuid, p_on date)
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
      title, note, due_on, due_time, alert, repeat_every, repeat_unit,
      repeat_from, repeat_until, scheduled_on, follows_id
    ) values (
      target.title, target.note, upcoming, target.due_time, target.alert,
      target.repeat_every, target.repeat_unit, target.repeat_from,
      target.repeat_until, upcoming, p_id
    );
  end if;
  return saved;
end $$;

create or replace function public.delete_task(
  p_id uuid, p_on date, p_following boolean
) returns void
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
        title, note, due_on, due_time, alert, repeat_every, repeat_unit,
        repeat_from, repeat_until, scheduled_on
      ) values (
        target.title, target.note, upcoming, target.due_time, target.alert,
        target.repeat_every, target.repeat_unit, target.repeat_from,
        target.repeat_until, upcoming
      );
    end if;
  end if;
  delete from public.task where id = p_id;
end $$;

-- #377's claim, now skipping a task whose bell or owner's switch is off.
create or replace function public.claim_task_alerts(
  p_now timestamptz default now()
) returns table (
  owner_id uuid, task_id uuid, title text, note text, alerted_for timestamp
)
language sql volatile security invoker set search_path = '' as $$
  with due as (
    select t.id, t.due_on + t.due_time as at
    from public.task t
    join public.notification_settings s on s.owner_id = t.owner_id
    cross join lateral (
      select date_trunc('minute', p_now at time zone s.time_zone) as local
    ) l
    where t.done_on is null and t.due_time is not null
      and s.task_enabled and t.alert
      and l.local >= t.due_on + t.due_time
      and l.local < t.due_on + t.due_time + interval '1 hour'
      and t.alerted_for is distinct from t.due_on + t.due_time
  )
  update public.task t set alerted_for = d.at
  from due d
  where t.id = d.id and t.alerted_for is distinct from d.at
  returning t.owner_id, t.id, t.title, t.note, t.alerted_for
$$;

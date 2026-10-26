-- A time on a task (#377): a push at that time, from the sender pg_cron now
-- calls every minute. The time is a wall clock in the user's
-- notification_settings.time_zone, never a UTC instant, as the summary's
-- (docs/superpowers/specs/2026-10-26-task-time-design.md). Additive: a build
-- without it ignores the column, and gets no task push (push_kinds).

alter table public.task
  add column due_time time,
  -- The local day and time the push was claimed for; null: not sent.
  add column alerted_for timestamp;

grant update (due_time) on public.task to authenticated;

-- A new day or time is a new push: every writer re-arms it, an old app
-- moving the day included.
create function public.task_rearm_alert() returns trigger
language plpgsql set search_path = '' as $$
begin
  if new.due_on is distinct from old.due_on
    or new.due_time is distinct from old.due_time then
    new.alerted_for = null;
  end if;
  return new;
end $$;
revoke execute on function public.task_rearm_alert() from public, anon;

create trigger task_rearm_alert before update on public.task
  for each row execute function public.task_rearm_alert();

-- Claiming a push is not an edit: updated_at stays, so #376's undo still
-- sees the task its tick made as untouched (updated_at = created_at).
drop trigger task_set_updated_at on public.task;
create trigger task_set_updated_at
  before update of title, note, due_on, due_time, done_on, repeat_every,
    repeat_unit, repeat_from, repeat_until, scheduled_on
  on public.task
  for each row execute function public.set_updated_at();

-- task_alert: the push. daily_summary_tasks: not a push, the marker of an
-- app whose summary strings count tasks too.
alter type public.notification_kind add value 'task_alert';
alter type public.notification_kind add value 'daily_summary_tasks';

-- #376's functions, now carrying the time to the next task.
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
      title, note, due_on, due_time, repeat_every, repeat_unit, repeat_from,
      repeat_until, scheduled_on, follows_id
    ) values (
      target.title, target.note, upcoming, target.due_time,
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
        title, note, due_on, due_time, repeat_every, repeat_unit,
        repeat_from, repeat_until, scheduled_on
      ) values (
        target.title, target.note, upcoming, target.due_time,
        target.repeat_every, target.repeat_unit, target.repeat_from,
        target.repeat_until, upcoming
      );
    end if;
  end if;
  delete from public.task where id = p_id;
end $$;

-- Open tasks due on or before p_on: Today's Tasks section (todayTasks).
create function public.due_tasks_count(p_owner uuid, p_on date) returns int
language sql stable security invoker set search_path = '' as $$
  select count(*)::int from public.task t
  where t.owner_id = p_owner and t.done_on is null and t.due_on <= p_on
$$;

-- claim_daily_summaries with the tasks counted: claimed when anyone or
-- anything is due. The same claim rows, so the two never both send. The old
-- one stays for the sender deployed before this one (db push comes first).
create function public.claim_daily_summaries_with_tasks(
  p_now timestamptz default now()
) returns table (owner_id uuid, local_date date, people int, tasks int)
language sql volatile security invoker set search_path = '' as $$
  with candidates as (
    select s.owner_id, l.local::date as local_date,
           public.due_people_count(s.owner_id, l.local::date) as people,
           public.due_tasks_count(s.owner_id, l.local::date) as tasks
    from public.notification_settings s
    cross join lateral (select p_now at time zone s.time_zone as local) l
    where s.summary_enabled
      and extract(isodow from l.local)::smallint = any (s.summary_days)
      and l.local::time >= s.summary_time
      and l.local::time - s.summary_time < interval '3 hours'
  ),
  claimed as (
    insert into public.notification_sent as n
      (owner_id, kind, local_date, claimed_at)
    select c.owner_id, 'daily_summary', c.local_date, p_now
    from candidates c where c.people + c.tasks > 0
    on conflict (owner_id, kind, local_date) do update
      set attempts = n.attempts + 1, claimed_at = excluded.claimed_at
      where n.claimed_at is null and n.attempts < 3
    returning n.owner_id, n.local_date
  )
  select c.owner_id, c.local_date, c.people, c.tasks
  from claimed k join candidates c
    on c.owner_id = k.owner_id and c.local_date = k.local_date
$$;

-- Every open task whose time has come in its owner's zone, claimed: the run
-- whose local minute is in [due, due + 1 h), once per day and time. A run at
-- 14:00:30 claims a 14:00 task; after 15:00 it is noise, never sent. p_now
-- is for tests; the sender passes nothing.
create function public.claim_task_alerts(p_now timestamptz default now())
returns table (
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
      and l.local >= t.due_on + t.due_time
      and l.local < t.due_on + t.due_time + interval '1 hour'
      and t.alerted_for is distinct from t.due_on + t.due_time
  )
  update public.task t set alerted_for = d.at
  from due d
  where t.id = d.id and t.alerted_for is distinct from d.at
  returning t.owner_id, t.id, t.title, t.note, t.alerted_for
$$;

-- Every send failed for a reason worth retrying: the next minute may claim
-- it again, unless the task moved since (a newer claim is never cleared).
create function public.release_task_alert(p_task uuid, p_for timestamp)
returns void
language sql volatile security invoker set search_path = '' as $$
  update public.task set alerted_for = null
  where id = p_task and alerted_for = p_for
$$;

revoke execute on function public.due_tasks_count(uuid, date)
  from public, anon, authenticated;
revoke execute on function public.claim_daily_summaries_with_tasks(timestamptz)
  from public, anon, authenticated;
revoke execute on function public.claim_task_alerts(timestamptz)
  from public, anon, authenticated;
revoke execute on function public.release_task_alert(uuid, timestamp)
  from public, anon, authenticated;
grant execute on function public.due_tasks_count(uuid, date) to service_role;
grant execute on function public.claim_daily_summaries_with_tasks(timestamptz)
  to service_role;
grant execute on function public.claim_task_alerts(timestamptz)
  to service_role;
grant execute on function public.release_task_alert(uuid, timestamp)
  to service_role;

-- Every minute, so a task's push lands within one. The summary and month-end
-- claims are per date: the extra runs send nothing twice.
do $$
begin
  perform cron.alter_job(jobid, schedule := '* * * * *')
  from cron.job where jobname = 'send-daily-summary';
end $$;

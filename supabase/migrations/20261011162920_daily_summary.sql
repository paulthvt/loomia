-- The daily summary (#269): when each user wants it, and who is due one now.
-- The local wall clock decides, in the user's IANA zone, on every run: no
-- local time is ever turned into a stored UTC instant, so DST needs no
-- conversion. A claim per (owner, kind, local date) makes it at most once a
-- day (docs/superpowers/specs/2026-10-11-notifications-design.md §1, §2).

-- One row per user; no row means off, and Today's card asks (#270).
create table public.notification_settings (
  owner_id uuid primary key default auth.uid()
    references auth.users on delete cascade,
  summary_enabled boolean not null default false,
  -- Local wall clock, in time_zone.
  summary_time time not null default '19:00',
  -- ISO 8601 weekdays, 1 = Monday … 7 = Sunday: Dart's DateTime.weekday and
  -- Postgres isodow, so nothing maps between them.
  summary_days smallint[] not null default '{1,2,3,4,5}'
    check (cardinality(summary_days) between 1 and 7
           and summary_days <@ '{1,2,3,4,5,6,7}'),
  -- IANA name ("Europe/Paris"), never an offset; checked by the trigger.
  time_zone text not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create trigger notification_settings_set_updated_at
  before update on public.notification_settings
  for each row execute function public.set_updated_at();

-- A check constraint can't query pg_timezone_names.
create function public.check_time_zone() returns trigger
language plpgsql set search_path = '' as $$
begin
  if not exists (
    select 1 from pg_catalog.pg_timezone_names where name = new.time_zone
  ) then
    raise exception 'unknown time zone %', new.time_zone
      using errcode = '23514';
  end if;
  return new;
end $$;
revoke execute on function public.check_time_zone() from public, anon;

create trigger notification_settings_check_time_zone
  before insert or update of time_zone on public.notification_settings
  for each row execute function public.check_time_zone();

alter table public.notification_settings enable row level security;

create policy notification_settings_select_own on public.notification_settings
  for select to authenticated using (owner_id = (select auth.uid()));
create policy notification_settings_insert_own on public.notification_settings
  for insert to authenticated with check (owner_id = (select auth.uid()));
create policy notification_settings_update_own on public.notification_settings
  for update to authenticated
  using (owner_id = (select auth.uid()))
  with check (owner_id = (select auth.uid()));

-- No delete: the account's cascade removes it.
revoke all on public.notification_settings from anon, authenticated;
grant select, insert on public.notification_settings to authenticated;
grant update (summary_enabled, summary_time, summary_days, time_zone)
  on public.notification_settings to authenticated;

-- A kind per push; the next one is a value, not a table.
create type public.notification_kind as enum ('daily_summary');

-- Claimed before sending, so no run sends a day twice. claimed_at null: a
-- failed send handed the day back for the next run.
create table public.notification_sent (
  owner_id uuid not null references auth.users on delete cascade,
  kind public.notification_kind not null,
  local_date date not null,
  attempts smallint not null default 1,
  claimed_at timestamptz default now(),
  primary key (owner_id, kind, local_date)
);

alter table public.notification_sent enable row level security;

-- Only the sender (service role) touches it; the policy keeps the schema
-- test's rule that every table has one.
create policy notification_sent_select_own on public.notification_sent
  for select to authenticated using (owner_id = (select auth.uid()));

revoke all on public.notification_sent from anon, authenticated;

-- The sender reads the workflow rule too (#58: one rule, every reader).
grant execute on function public.current_step_id(public.person) to service_role;
grant execute on function public.due_on(public.person) to service_role;

-- People with a step or a reminder due on or before p_on: Today's headline
-- (dueToday in lib/features/today/domain/due.dart). A pause hides the step,
-- not the reminders.
create function public.due_people_count(p_owner uuid, p_on date) returns int
language sql stable security invoker set search_path = '' as $$
  select count(*)::int from public.person p
  where p.owner_id = p_owner
    and (public.due_on(p) <= p_on
         or exists (
           select 1 from public.reminder r
           where r.person_id = p.id and r.owner_id = p_owner
             and r.due_on <= p_on))
$$;

-- Everyone due a summary at p_now, claimed. Due: enabled, today's ISO
-- weekday selected, the local time in [summary_time, summary_time + 3 h)
-- (cut at midnight: the next day is another date), someone due. A day
-- already claimed, or released three times, is not claimed again. p_now is
-- for tests; the sender passes nothing.
create function public.claim_daily_summaries(p_now timestamptz default now())
returns table (owner_id uuid, local_date date, people int)
language sql volatile security invoker set search_path = '' as $$
  with candidates as (
    select s.owner_id, l.local::date as local_date,
           public.due_people_count(s.owner_id, l.local::date) as people
    from public.notification_settings s
    cross join lateral (select p_now at time zone s.time_zone as local) l
    where s.summary_enabled
      and extract(isodow from l.local)::smallint = any (s.summary_days)
      and l.local::time >= s.summary_time
      -- Not summary_time + 3 h, which wraps past midnight.
      and l.local::time - s.summary_time < interval '3 hours'
  ),
  claimed as (
    insert into public.notification_sent as n
      (owner_id, kind, local_date, claimed_at)
    select c.owner_id, 'daily_summary', c.local_date, p_now
    from candidates c where c.people > 0
    on conflict (owner_id, kind, local_date) do update
      set attempts = n.attempts + 1, claimed_at = excluded.claimed_at
      where n.claimed_at is null and n.attempts < 3
    returning n.owner_id, n.local_date
  )
  select c.owner_id, c.local_date, c.people
  from claimed k join candidates c
    on c.owner_id = k.owner_id and c.local_date = k.local_date
$$;

-- Every send failed for a reason worth retrying: the next run may claim it.
create function public.release_daily_summary(p_owner uuid, p_date date)
returns void
language sql volatile security invoker set search_path = '' as $$
  update public.notification_sent set claimed_at = null
  where owner_id = p_owner and kind = 'daily_summary' and local_date = p_date
$$;

-- Tokens FCM no longer knows (an uninstall, a sign-out on that phone).
create function public.drop_device_tokens(p_tokens text[]) returns void
language sql volatile security invoker set search_path = '' as $$
  delete from public.device_token where token = any (p_tokens)
$$;

revoke execute on function public.due_people_count(uuid, date)
  from public, anon, authenticated;
revoke execute on function public.claim_daily_summaries(timestamptz)
  from public, anon, authenticated;
revoke execute on function public.release_daily_summary(uuid, date)
  from public, anon, authenticated;
revoke execute on function public.drop_device_tokens(text[])
  from public, anon, authenticated;
grant execute on function public.due_people_count(uuid, date) to service_role;
grant execute on function public.claim_daily_summaries(timestamptz)
  to service_role;
grant execute on function public.release_daily_summary(uuid, date)
  to service_role;
grant execute on function public.drop_device_tokens(text[]) to service_role;

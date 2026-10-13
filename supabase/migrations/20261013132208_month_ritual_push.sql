-- The month-end push (#148): once per close-and-plan window, at the user's
-- summary time, what Today's card says
-- (docs/superpowers/specs/2026-10-13-month-end-push-design.md).

-- Its own switch, off: turning on the daily summary was not a yes to this.
alter table public.notification_settings
  add column ritual_enabled boolean not null default false;
grant update (ritual_enabled) on public.notification_settings to authenticated;

-- The kinds the installed app has strings for. An app built before a kind
-- would show a raw key, or nothing: it leaves the default and isn't sent it.
alter table public.device_token
  add column push_kinds public.notification_kind[] not null
    default '{daily_summary}';

drop function public.register_device(text, public.device_platform, text);

-- As before, plus the kinds; an older app calling with three arguments gets
-- the default.
create function public.register_device(
  p_token text, p_platform public.device_platform, p_locale text,
  p_kinds public.notification_kind[] default '{daily_summary}'
) returns void
language plpgsql security definer set search_path = '' as $$
begin
  if auth.uid() is null then
    raise exception 'not signed in' using errcode = '42501';
  end if;
  insert into public.device_token (token, owner_id, platform, locale, push_kinds)
    values (p_token, auth.uid(), p_platform, p_locale, p_kinds)
  on conflict (token) do update
    set owner_id = excluded.owner_id,
        platform = excluded.platform,
        locale = excluded.locale,
        push_kinds = excluded.push_kinds,
        last_seen_at = now();
end $$;

revoke execute on function public.register_device(
  text, public.device_platform, text, public.notification_kind[])
  from public, anon;
grant execute on function public.register_device(
  text, public.device_platform, text, public.notification_kind[])
  to authenticated;

-- What the close-and-plan window still asks on p_on, as pendingRitual in
-- lib/features/goals/domain/goal_rules.dart (the app keeps that copy over the
-- plans it has loaded; month_ritual_test.sql mirrors its cases). Open the
-- last 3 days of a month (closing it) and the first 5 of the next (closing
-- the one before). to_close is asked when it was planned and isn't closed;
-- no row when nothing is left to close and to_plan has a plan.
create function public.pending_ritual(p_owner uuid, p_on date)
returns table (to_close date, to_plan date, closes boolean)
language sql stable security invoker set search_path = '' as $$
  with w as (
    select case
      when p_on >= (date_trunc('month', p_on) + interval '1 month'
                    - interval '3 days')::date
        then date_trunc('month', p_on)::date
      when extract(day from p_on) <= 5
        then (date_trunc('month', p_on) - interval '1 month')::date
    end as to_close
  ), c as (
    select w.to_close, (w.to_close + interval '1 month')::date as to_plan,
      exists (
        select 1 from public.month_plan m
        where m.owner_id = p_owner and m.month = w.to_close
          and m.closed_at is null) as closes
    from w where w.to_close is not null
  )
  select c.to_close, c.to_plan, c.closes from c
  where c.closes or not exists (
    select 1 from public.month_plan m
    where m.owner_id = p_owner and m.month = c.to_plan)
$$;

-- Everyone due the month-end push at p_now, claimed: as
-- claim_daily_summaries, with ritual_enabled and something pending instead
-- of someone due. The claim's date is the month to plan, so both halves of a
-- window (Sep 28–30, Oct 1–5) share one row: once per window.
create function public.claim_month_rituals(p_now timestamptz default now())
returns table (owner_id uuid, to_close date, to_plan date, closes boolean)
language sql volatile security invoker set search_path = '' as $$
  with candidates as (
    select s.owner_id, r.to_close, r.to_plan, r.closes
    from public.notification_settings s
    cross join lateral (select p_now at time zone s.time_zone as local) l
    cross join lateral public.pending_ritual(s.owner_id, l.local::date) r
    where s.ritual_enabled
      and extract(isodow from l.local)::smallint = any (s.summary_days)
      and l.local::time >= s.summary_time
      and l.local::time - s.summary_time < interval '3 hours'
  ),
  claimed as (
    insert into public.notification_sent as n
      (owner_id, kind, local_date, claimed_at)
    select c.owner_id, 'month_ritual', c.to_plan, p_now from candidates c
    on conflict (owner_id, kind, local_date) do update
      set attempts = n.attempts + 1, claimed_at = excluded.claimed_at
      where n.claimed_at is null and n.attempts < 3
    returning n.owner_id, n.local_date
  )
  select c.owner_id, c.to_close, c.to_plan, c.closes
  from claimed k join candidates c
    on c.owner_id = k.owner_id and c.to_plan = k.local_date
$$;

-- Every send failed for a reason worth retrying: the next run may claim it.
create function public.release_month_ritual(p_owner uuid, p_plan date)
returns void
language sql volatile security invoker set search_path = '' as $$
  update public.notification_sent set claimed_at = null
  where owner_id = p_owner and kind = 'month_ritual' and local_date = p_plan
$$;

revoke execute on function public.pending_ritual(uuid, date)
  from public, anon, authenticated;
revoke execute on function public.claim_month_rituals(timestamptz)
  from public, anon, authenticated;
revoke execute on function public.release_month_ritual(uuid, date)
  from public, anon, authenticated;
grant execute on function public.pending_ritual(uuid, date) to service_role;
grant execute on function public.claim_month_rituals(timestamptz)
  to service_role;
grant execute on function public.release_month_ritual(uuid, date)
  to service_role;

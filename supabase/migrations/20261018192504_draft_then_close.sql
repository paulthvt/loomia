-- Draft, then close (#354): the last 3 days of a month only plan the next,
-- the 1st–5th close it (docs/superpowers/specs/2026-10-18-draft-then-close-design.md).
-- Same parameters and return: the sender keeps calling it unchanged.

-- As pendingRitual in lib/features/goals/domain/goal_rules.dart, without its
-- `drafted`: a saved draft gets no push. Last 3 days: to_plan when it has no
-- plan, never closes. Day 1–5: to_close when it was planned and isn't closed,
-- else to_plan when it has no plan. month_ritual_test.sql mirrors its cases.
create or replace function public.pending_ritual(p_owner uuid, p_on date)
returns table (to_close date, to_plan date, closes boolean)
language sql stable security invoker set search_path = '' as $$
  with w as (
    select case
      when p_on >= (date_trunc('month', p_on) + interval '1 month'
                    - interval '3 days')::date
        then date_trunc('month', p_on)::date
      when extract(day from p_on) <= 5
        then (date_trunc('month', p_on) - interval '1 month')::date
    end as to_close,
    extract(day from p_on) <= 5 as closing
  ), c as (
    select w.to_close, (w.to_close + interval '1 month')::date as to_plan,
      w.closing and exists (
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

-- Once per half: claim_date, the claim's local_date, is the last day of the
-- month while drafting and the 1st (to_plan) while closing. The sender hands
-- it back to release_month_ritual, whose p_plan now means that date.
drop function public.claim_month_rituals(timestamptz);

create function public.claim_month_rituals(p_now timestamptz default now())
returns table (
  owner_id uuid, to_close date, to_plan date, closes boolean, claim_date date
)
language sql volatile security invoker set search_path = '' as $$
  with candidates as (
    select s.owner_id, r.to_close, r.to_plan, r.closes,
      case when extract(day from l.local) <= 5 then r.to_plan
        else r.to_plan - 1 end as claim_date
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
    select c.owner_id, 'month_ritual', c.claim_date, p_now from candidates c
    on conflict (owner_id, kind, local_date) do update
      set attempts = n.attempts + 1, claimed_at = excluded.claimed_at
      where n.claimed_at is null and n.attempts < 3
    returning n.owner_id, n.local_date
  )
  select c.owner_id, c.to_close, c.to_plan, c.closes, c.claim_date
  from claimed k join candidates c
    on c.owner_id = k.owner_id and c.claim_date = k.local_date
$$;

revoke execute on function public.claim_month_rituals(timestamptz)
  from public, anon, authenticated;
grant execute on function public.claim_month_rituals(timestamptz)
  to service_role;

-- Stage since (#179): an import, or an edit, may set stage_since in the past.
-- Someone who was already a customer a year ago is not one this month, so
-- people added count from the earlier of created_at and stage_since. Without
-- a backdate the two are the same instant, and nothing changes.
create or replace function public.month_progress(
  p_month date, p_starts timestamptz, p_ends timestamptz
) returns table (
  own_volume numeric, prospects int, customers int, team_members int,
  loyalty int
)
language sql stable security invoker set search_path = '' as $$
  with bounds as (
    select p_month as first_day, (p_month + interval '1 month')::date as next_month
  ),
  added as (
    select p.id, p.first_stage from public.person p
      where least(p.created_at, p.stage_since) >= p_starts
        and least(p.created_at, p.stage_since) < p_ends
  ),
  joined as (
    select a.person_id, a.stage from public.activity a
      where a.kind = 'stage'
        and a.created_at >= p_starts and a.created_at < p_ends
    union
    select id, first_stage from added
  )
  select
    (select coalesce(sum(a.amount), 0) from public.activity a, bounds b
      where a.kind = 'order'
        and a.happened_on >= b.first_day and a.happened_on < b.next_month),
    (select count(*)::int from added where first_stage = 'prospect'),
    (select count(distinct j.person_id)::int from joined j
      where j.stage = 'customer'),
    (select count(distinct j.person_id)::int from joined j
      where j.stage = 'team'),
    (select count(*)::int from public.activity a, bounds b
      where a.kind = 'step' and a.loyalty_setup
        and a.happened_on >= b.first_day and a.happened_on < b.next_month)
$$;

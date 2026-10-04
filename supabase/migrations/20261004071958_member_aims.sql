-- A team member's rank and volume (#139): facts the user writes on the
-- member's contact page, in conversation. Never computed, never compared.
-- The existing person RLS covers them.
alter table public.person
  add column current_level text,
  add column target_level text,
  add column target_level_by date,
  add column monthly_volume_target numeric(12,2),
  add constraint person_target_level_by_month
    check (extract(day from target_level_by) = 1),
  add constraint person_target_level_by_needs_target
    check (target_level_by is null or target_level is not null),
  add constraint person_monthly_volume_target_positive
    check (monthly_volume_target > 0);

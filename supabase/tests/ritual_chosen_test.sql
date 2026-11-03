-- The month-end review's "chosen" flag (#412): off until the user saves the
-- switch, theirs to set, kept by the released app's upsert. Run with
-- `supabase test db`.
begin;
create extension if not exists pgtap with schema extensions;
select plan(4);

insert into auth.users (id, email) values
  ('00000000-0000-0000-0000-00000000000a', 'a@example.com');
insert into public.notification_settings (owner_id, time_zone) values
  ('00000000-0000-0000-0000-00000000000a', 'Europe/Paris');

select is(
  (select ritual_chosen from public.notification_settings),
  false,
  'never chosen by default'
);

set local role authenticated;
set local request.jwt.claims =
  '{"sub": "00000000-0000-0000-0000-00000000000a", "role": "authenticated"}';

select lives_ok(
  $$ update public.notification_settings set ritual_chosen = true $$,
  'ritual_chosen is the user''s'
);

-- The released app upserts its settings without ritual_chosen: the choice
-- stays.
insert into public.notification_settings
  (summary_enabled, ritual_enabled, summary_time, summary_days, time_zone)
values (false, false, '19:00', '{1,2,3,4,5}', 'Europe/Paris')
on conflict (owner_id) do update set
  summary_enabled = excluded.summary_enabled,
  ritual_enabled = excluded.ritual_enabled,
  summary_time = excluded.summary_time,
  summary_days = excluded.summary_days,
  time_zone = excluded.time_zone;
select is(
  (select ritual_chosen from public.notification_settings),
  true,
  'an upsert without ritual_chosen keeps it'
);
select is(
  (select ritual_enabled from public.notification_settings),
  false,
  'and saves what it sent'
);

select * from finish();
rollback;

-- The month-end review switch on the plan step is on by default until the
-- user has chosen (#412): ritual_enabled alone can't tell "never chosen"
-- from "turned off". Set by the app whenever the switch is saved, here or
-- in Settings. Additive: the released app's upsert leaves it as it was.
alter table public.notification_settings
  add column ritual_chosen boolean not null default false;
grant update (ritual_chosen) on public.notification_settings to authenticated;

-- Whoever has it on chose it.
update public.notification_settings set ritual_chosen = true
  where ritual_enabled;

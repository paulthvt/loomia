-- Device tokens (#268): where a push goes. One row per FCM token, owned by
-- the account that registered it last, so a phone signed into another
-- account stops getting the first one's summary. Only register_device writes
-- them: the move to another owner is a write RLS would refuse. Sign-out
-- deletes the token on the device; the sender drops rows FCM no longer knows
-- (docs/superpowers/specs/2026-10-11-notifications-design.md §1).
create type public.device_platform as enum ('android', 'ios');

create table public.device_token (
  token text primary key
    check (length(trim(token)) > 0 and length(token) <= 4096),
  owner_id uuid not null default auth.uid()
    references auth.users on delete cascade,
  platform public.device_platform not null,
  -- The app's language on that device, which the push is written in.
  locale text not null check (locale ~ '^[a-z]{2,3}$'),
  last_seen_at timestamptz not null default now(),
  created_at timestamptz not null default now()
);

create index device_token_owner_id_idx on public.device_token (owner_id);

alter table public.device_token enable row level security;

create policy device_token_select_own on public.device_token
  for select to authenticated using (owner_id = (select auth.uid()));

-- No grant: the device only registers, through the function below.
revoke all on public.device_token from anon, authenticated;

-- On every launch and token refresh: refreshes last_seen_at and the
-- language, and takes the token over from whoever had it.
create function public.register_device(
  p_token text, p_platform public.device_platform, p_locale text
) returns void
language plpgsql security definer set search_path = '' as $$
begin
  if auth.uid() is null then
    raise exception 'not signed in' using errcode = '42501';
  end if;
  insert into public.device_token (token, owner_id, platform, locale)
    values (p_token, auth.uid(), p_platform, p_locale)
  on conflict (token) do update
    set owner_id = excluded.owner_id,
        platform = excluded.platform,
        locale = excluded.locale,
        last_seen_at = now();
end $$;

revoke execute on function
  public.register_device(text, public.device_platform, text) from public, anon;
grant execute on function
  public.register_device(text, public.device_platform, text) to authenticated;

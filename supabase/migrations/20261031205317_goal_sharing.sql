-- Goal sharing (#147): a member shares their month's goals with the mentor
-- who has them on their team. The first data that crosses accounts. Tables
-- stay owner-only; a link records who shares what with whom, and the only
-- crossing is through security definer functions that check that link
-- (docs/superpowers/specs/2026-10-31-goal-sharing-design.md).

create type public.share_item as enum ('activity_targets', 'progress', 'about_me');

-- One open invite per contact. Written only by create_share_invite, read
-- and cancelled by the mentor; the member only ever sends the code.
create table public.share_invite (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null default auth.uid()
    references auth.users on delete cascade,
  person_id uuid not null unique,
  code text not null unique,
  expires_at timestamptz not null default now() + interval '14 days',
  created_at timestamptz not null default now(),
  foreign key (person_id, owner_id)
    references public.person (id, owner_id) on delete cascade
);

alter table public.share_invite enable row level security;

create policy share_invite_select_own on public.share_invite
  for select to authenticated using (owner_id = (select auth.uid()));
create policy share_invite_delete_own on public.share_invite
  for delete to authenticated using (owner_id = (select auth.uid()));

revoke all on public.share_invite from anon, authenticated;
grant select, delete on public.share_invite to authenticated;

-- One mentor per member, one member per contact. Created only by
-- accept_share_invite; either side can read it and stop it, only the member
-- chooses what is shared.
create table public.share_link (
  id uuid primary key default gen_random_uuid(),
  mentor_id uuid not null,
  member_id uuid not null unique references auth.users on delete cascade,
  person_id uuid not null unique,
  items public.share_item[] not null default '{activity_targets}',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  foreign key (person_id, mentor_id)
    references public.person (id, owner_id) on delete cascade,
  check (mentor_id <> member_id)
);

create trigger share_link_set_updated_at before update on public.share_link
  for each row execute function public.set_updated_at();

alter table public.share_link enable row level security;

create policy share_link_select_own on public.share_link
  for select to authenticated using (
    mentor_id = (select auth.uid()) or member_id = (select auth.uid()));
create policy share_link_delete_own on public.share_link
  for delete to authenticated using (
    mentor_id = (select auth.uid()) or member_id = (select auth.uid()));
create policy share_link_update_member on public.share_link
  for update to authenticated
  using (member_id = (select auth.uid()))
  with check (member_id = (select auth.uid()));

revoke all on public.share_link from anon, authenticated;
grant select, delete on public.share_link to authenticated;
grant update (items) on public.share_link to authenticated;

-- The member's own why and goal, theirs whether or not they share them.
create table public.about_me (
  owner_id uuid primary key default auth.uid()
    references auth.users on delete cascade,
  why text,
  own_goal text,
  updated_at timestamptz not null default now()
);

create trigger about_me_set_updated_at before update on public.about_me
  for each row execute function public.set_updated_at();

alter table public.about_me enable row level security;

create policy about_me_select_own on public.about_me
  for select to authenticated using (owner_id = (select auth.uid()));
create policy about_me_insert_own on public.about_me
  for insert to authenticated with check (owner_id = (select auth.uid()));
create policy about_me_update_own on public.about_me
  for update to authenticated
  using (owner_id = (select auth.uid()))
  with check (owner_id = (select auth.uid()));
create policy about_me_delete_own on public.about_me
  for delete to authenticated using (owner_id = (select auth.uid()));

revoke all on public.about_me from anon, authenticated;
grant select, insert, update, delete on public.about_me to authenticated;

-- A new 8-character code for one of the caller's team members, replacing
-- any open one. security definer so the app cannot write a code or an
-- expiry of its own; the contact is checked against the caller instead.
-- The alphabet has no look-alikes (0/O, 1/I/L).
create function public.create_share_invite(p_person_id uuid)
returns public.share_invite
language plpgsql security definer set search_path = '' as $$
declare
  alphabet constant text := 'ABCDEFGHJKMNPQRSTUVWXYZ23456789';
  bytes bytea;
  new_code text;
  invite public.share_invite;
begin
  if not exists (
    select 1 from public.person p
    where p.id = p_person_id and p.owner_id = (select auth.uid())
      and p.stage = 'team'
  ) then
    raise exception 'not_team' using errcode = 'P0001';
  end if;
  loop
    bytes := extensions.gen_random_bytes(8);
    select string_agg(substr(alphabet, get_byte(bytes, i) % 31 + 1, 1), '')
      into new_code from generate_series(0, 7) i;
    begin
      insert into public.share_invite as s (owner_id, person_id, code)
        values ((select auth.uid()), p_person_id, new_code)
      on conflict (person_id) do update
        set code = excluded.code, expires_at = excluded.expires_at
      returning * into invite;
      return invite;
    exception when unique_violation then
      -- Another invite holds this code: draw again.
    end;
  end loop;
end $$;

-- The mentor's first name for an open invite, so the member knows whom they
-- would share with. Refuses as accept_share_invite does, without using it.
create function public.share_invite_preview(p_code text) returns text
language plpgsql stable security definer set search_path = '' as $$
declare
  invite public.share_invite;
begin
  select * into invite from public.share_invite s
  where s.code = upper(regexp_replace(p_code, '[^A-Za-z0-9]', '', 'g'))
    and s.expires_at > now();
  if invite.id is null then
    raise exception 'invite_invalid' using errcode = 'P0001';
  end if;
  if invite.owner_id = (select auth.uid()) then
    raise exception 'invite_own' using errcode = 'P0001';
  end if;
  if exists (
    select 1 from public.share_link l where l.member_id = (select auth.uid())
  ) then
    raise exception 'already_sharing' using errcode = 'P0001';
  end if;
  -- An account may have no first name yet: empty, never null.
  return coalesce((select u.raw_user_meta_data->>'first_name' from auth.users u
                   where u.id = invite.owner_id), '');
end $$;

-- Uses the invite up and links the caller to its mentor's contact.
create function public.accept_share_invite(
  p_code text, p_items public.share_item[]
) returns void
language plpgsql security definer set search_path = '' as $$
declare
  invite public.share_invite;
begin
  perform public.share_invite_preview(p_code);
  delete from public.share_invite s
  where s.code = upper(regexp_replace(p_code, '[^A-Za-z0-9]', '', 'g'))
  returning * into invite;
  -- Accepted by someone else in the meantime.
  if invite.id is null then
    raise exception 'invite_invalid' using errcode = 'P0001';
  end if;
  insert into public.share_link (mentor_id, member_id, person_id, items)
    values (invite.owner_id, (select auth.uid()), invite.person_id, p_items);
end $$;

-- The caller's link as a member, with the mentor's first name.
create function public.my_share()
returns table (mentor_first_name text, items public.share_item[])
language sql stable security definer set search_path = '' as $$
  select coalesce(u.raw_user_meta_data->>'first_name', ''), l.items
  from public.share_link l join auth.users u on u.id = l.mentor_id
  where l.member_id = (select auth.uid())
$$;

-- month_progress's counting for any owner. It passes RLS, so every read
-- filters on p_owner, and no user may call it: month_progress passes the
-- caller, shared_goals a member who shares progress.
create function public.month_progress_for(
  p_owner uuid, p_month date, p_starts timestamptz, p_ends timestamptz
) returns table (
  own_volume numeric, prospects int, customers int, team_members int,
  loyalty int
)
language sql stable security definer set search_path = '' as $$
  with bounds as (
    select p_month as first_day, (p_month + interval '1 month')::date as next_month
  ),
  added as (
    select p.id, p.first_stage from public.person p
      where p.owner_id = p_owner
        and least(p.created_at, p.stage_since) >= p_starts
        and least(p.created_at, p.stage_since) < p_ends
  ),
  joined as (
    select a.person_id, a.stage from public.activity a
      where a.owner_id = p_owner and a.kind = 'stage'
        and a.created_at >= p_starts and a.created_at < p_ends
    union
    select id, first_stage from added
  )
  select
    (select coalesce(sum(a.amount), 0) from public.activity a, bounds b
      where a.owner_id = p_owner and a.kind = 'order'
        and a.happened_on >= b.first_day and a.happened_on < b.next_month),
    (select count(*)::int from added where first_stage = 'prospect'),
    (select count(distinct j.person_id)::int from joined j
      where j.stage = 'customer'),
    (select count(distinct j.person_id)::int from joined j
      where j.stage = 'team'),
    (select count(*)::int from public.person p, bounds b
      where p.owner_id = p_owner
        and p.loyalty_since >= b.first_day and p.loyalty_since < b.next_month)
$$;

revoke execute on function
  public.month_progress_for(uuid, date, timestamptz, timestamptz)
  from public, anon, authenticated;

-- Same signature as before. security definer now, to call
-- month_progress_for; it only ever passes the caller.
create or replace function public.month_progress(
  p_month date, p_starts timestamptz, p_ends timestamptz
) returns table (
  own_volume numeric, prospects int, customers int, team_members int,
  loyalty int
)
language sql stable security definer set search_path = '' as $$
  select * from public.month_progress_for(
    (select auth.uid()), p_month, p_starts, p_ends)
$$;

-- What a member shares with the caller about the given contact: zero rows
-- unless it is the caller's linked contact and still on the team. Volume
-- and level come with any link; the rest only when its item is shared. A
-- null plan, level or about-me field is shared but not set yet.
create function public.shared_goals(
  p_person_id uuid, p_month date, p_starts timestamptz, p_ends timestamptz
) returns table (
  member_first_name text, items public.share_item[], plan jsonb,
  level_now text, progress jsonb, why text, own_goal text
)
language sql stable security definer set search_path = '' as $$
  select
    coalesce(u.raw_user_meta_data->>'first_name', ''),
    l.items,
    (select jsonb_build_object(
              'own_volume_target', m.own_volume_target,
              'team_volume_target', m.team_volume_target,
              'level_target', m.level_target)
            || case when 'activity_targets' = any(l.items) then
                 jsonb_build_object(
                   'prospects_target', m.prospects_target,
                   'customers_target', m.customers_target,
                   'team_members_target', m.team_members_target,
                   'loyalty_target', m.loyalty_target)
               else '{}'::jsonb end
      from public.month_plan m
      where m.owner_id = l.member_id and m.month = p_month),
    (select m.level_actual from public.month_plan m
      where m.owner_id = l.member_id and m.closed_at is not null
      order by m.month desc limit 1),
    -- The counts only with activity targets: progress is for what is shared.
    case when 'progress' = any(l.items) then
      (select jsonb_build_object('own_volume', f.own_volume)
              || case when 'activity_targets' = any(l.items) then
                   jsonb_build_object(
                     'prospects', f.prospects,
                     'customers', f.customers,
                     'team_members', f.team_members,
                     'loyalty', f.loyalty)
                 else '{}'::jsonb end
         from public.month_progress_for(
           l.member_id, p_month, p_starts, p_ends) f)
    end,
    case when 'about_me' = any(l.items) then a.why end,
    case when 'about_me' = any(l.items) then a.own_goal end
  from public.share_link l
  join public.person p on p.id = l.person_id and p.owner_id = l.mentor_id
  join auth.users u on u.id = l.member_id
  left join public.about_me a on a.owner_id = l.member_id
  where l.person_id = p_person_id and l.mentor_id = (select auth.uid())
    and p.stage = 'team'
    -- The current month only, as the member's app counts it: the UTC month
    -- or the one beside it, within 14 hours of its UTC bounds for the time
    -- zone. Nothing for another month or a narrower window.
    and p_month in (
      select (date_trunc('month', now() at time zone 'utc')
              + n * interval '1 month')::date
      from generate_series(-1, 1) n)
    and p_starts between (p_month::timestamp at time zone 'utc') - interval '14 hours'
                     and (p_month::timestamp at time zone 'utc') + interval '14 hours'
    and p_ends between ((p_month + interval '1 month') at time zone 'utc') - interval '14 hours'
                   and ((p_month + interval '1 month') at time zone 'utc') + interval '14 hours'
$$;

revoke execute on function public.create_share_invite(uuid) from public, anon;
revoke execute on function public.share_invite_preview(text) from public, anon;
revoke execute on function
  public.accept_share_invite(text, public.share_item[]) from public, anon;
revoke execute on function public.my_share() from public, anon;
revoke execute on function
  public.shared_goals(uuid, date, timestamptz, timestamptz) from public, anon;
grant execute on function public.create_share_invite(uuid) to authenticated;
grant execute on function public.share_invite_preview(text) to authenticated;
grant execute on function
  public.accept_share_invite(text, public.share_item[]) to authenticated;
grant execute on function public.my_share() to authenticated;
grant execute on function
  public.shared_goals(uuid, date, timestamptz, timestamptz) to authenticated;

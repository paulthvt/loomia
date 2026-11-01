-- The invite-accepted push (#423): the person who sent an invite hears when
-- it is accepted, once, if their Sharing switch is on (off by default, design
-- principle 4). Never when sharing stops: only a new link is ever claimed.
-- send-daily-summary claims every minute, like task times (#377).

-- When the push for this link went out, or was given up on.
alter table public.share_link add column notified_at timestamptz;

-- Links accepted before this shipped are old news.
update public.share_link set notified_at = created_at;

alter table public.notification_settings
  add column sharing_enabled boolean not null default false;
grant update (sharing_enabled) on public.notification_settings to authenticated;

-- Stamps every unsent link of a sender whose switch is on, and returns those
-- worth a push: accepted within a day, contact still on the team. A stale one
-- is stamped and dropped, so turning the switch on later sends no old news.
create function public.claim_share_accepted(p_now timestamptz default now())
returns table (
  owner_id uuid, link_id uuid, person_id uuid, name text,
  notified_at timestamptz
)
language sql volatile security invoker set search_path = '' as $$
  with due as (
    select l.id, l.mentor_id, l.person_id, p.name,
           l.created_at >= p_now - interval '24 hours'
             and p.stage = 'team' as fresh
    from public.share_link l
    join public.notification_settings s on s.owner_id = l.mentor_id
    join public.person p on p.id = l.person_id
    where l.notified_at is null and s.sharing_enabled
  ),
  stamped as (
    update public.share_link l set notified_at = p_now
    from due d
    where l.id = d.id and l.notified_at is null
    returning l.id
  )
  select d.mentor_id, d.id, d.person_id, d.name, p_now
  from due d join stamped s on s.id = d.id
  where d.fresh
$$;

-- Every send failed for a reason worth retrying: the next minute may claim it
-- again, unless it was claimed again since.
create function public.release_share_accepted(p_link uuid, p_at timestamptz)
returns void
language sql volatile security invoker set search_path = '' as $$
  update public.share_link set notified_at = null
  where id = p_link and notified_at = p_at
$$;

revoke execute on function public.claim_share_accepted(timestamptz)
  from public, anon, authenticated;
revoke execute on function public.release_share_accepted(uuid, timestamptz)
  from public, anon, authenticated;
grant execute on function public.claim_share_accepted(timestamptz)
  to service_role;
grant execute on function public.release_share_accepted(uuid, timestamptz)
  to service_role;

-- Plain events (#300): being at a group event is not a conversation, so it
-- no longer moves last_contact_on; Worth a check-in still flags someone only
-- seen on a call. The event entry stays in their history.
create or replace function public.last_contact_on(p public.person) returns date
language sql stable security invoker set search_path = '' as $$
  select max(a.happened_on) from public.activity a
  where a.person_id = p.id and a.kind not in ('stage', 'event')
$$;

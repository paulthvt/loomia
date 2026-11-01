-- The invite-accepted push (#423): claim_share_accepted hands the sender out
-- once per new link, only when they turned the Sharing switch on, never for
-- old news. Run with `supabase test db`.
begin;
create extension if not exists pgtap with schema extensions;
select plan(11);

insert into auth.users (id, email, raw_user_meta_data) values
  ('00000000-0000-0000-0000-00000000000a', 'a@example.com', '{}'),
  ('00000000-0000-0000-0000-00000000000b', 'b@example.com',
   '{"first_name": "Account"}'),
  ('00000000-0000-0000-0000-00000000000c', 'c@example.com', '{}'),
  ('00000000-0000-0000-0000-00000000000d', 'd@example.com', '{}'),
  ('00000000-0000-0000-0000-00000000000e', 'e@example.com', '{}');

insert into public.notification_settings (owner_id, time_zone) values
  ('00000000-0000-0000-0000-00000000000a', 'Europe/Paris');

insert into public.person (id, owner_id, name, stage) values
  ('00000000-0000-0000-0000-0000000000a1',
   '00000000-0000-0000-0000-00000000000a', 'Julie', 'team'),
  ('00000000-0000-0000-0000-0000000000a2',
   '00000000-0000-0000-0000-00000000000a', 'Old', 'team'),
  ('00000000-0000-0000-0000-0000000000a3',
   '00000000-0000-0000-0000-00000000000a', 'Cust', 'customer'),
  ('00000000-0000-0000-0000-0000000000a4',
   '00000000-0000-0000-0000-00000000000a', 'Backfilled', 'team');

-- Accepted before the push shipped: the migration stamps these.
insert into public.share_link (id, mentor_id, member_id, person_id, notified_at)
values ('00000000-0000-0000-0000-0000000000d4',
        '00000000-0000-0000-0000-00000000000a',
        '00000000-0000-0000-0000-00000000000e',
        '00000000-0000-0000-0000-0000000000a4', now() - interval '1 hour');

insert into public.share_link (id, mentor_id, member_id, person_id) values
  ('00000000-0000-0000-0000-0000000000d1',
   '00000000-0000-0000-0000-00000000000a',
   '00000000-0000-0000-0000-00000000000b',
   '00000000-0000-0000-0000-0000000000a1');

-- 1-2: Sharing switch off by default: nothing claimed, nothing stamped.
select is_empty(
  $$ select * from public.claim_share_accepted() $$,
  'nothing goes out while the Sharing switch is off'
);
select is(
  (select notified_at from public.share_link
    where id = '00000000-0000-0000-0000-0000000000d1'),
  null,
  'a link waits unstamped while the switch is off'
);

update public.notification_settings set sharing_enabled = true
  where owner_id = '00000000-0000-0000-0000-00000000000a';

-- 3-4: switch on: claimed once, with the sender's own name for the contact.
select results_eq(
  $$ select owner_id, link_id, person_id, name
     from public.claim_share_accepted() $$,
  $$ values ('00000000-0000-0000-0000-00000000000a'::uuid,
             '00000000-0000-0000-0000-0000000000d1'::uuid,
             '00000000-0000-0000-0000-0000000000a1'::uuid,
             'Julie'::text) $$,
  'a new link is claimed for its sender, named as on their card'
);
select is_empty(
  $$ select * from public.claim_share_accepted() $$,
  'a link is claimed once; the backfilled one never'
);

-- 5: release hands back only the claim it names.
select lives_ok(
  $$ select public.release_share_accepted(
       '00000000-0000-0000-0000-0000000000d1', now() - interval '1 day') $$,
  'a release with another time runs'
);
select is_empty(
  $$ select * from public.claim_share_accepted() $$,
  'and leaves the claim alone'
);
select public.release_share_accepted(
  '00000000-0000-0000-0000-0000000000d1',
  (select notified_at from public.share_link
    where id = '00000000-0000-0000-0000-0000000000d1'));
select is(
  (select count(*)::int from public.claim_share_accepted()),
  1,
  'a released claim is claimed again'
);

-- 8: older than a day: stamped, not sent.
insert into public.share_link (id, mentor_id, member_id, person_id, created_at)
values ('00000000-0000-0000-0000-0000000000d2',
        '00000000-0000-0000-0000-00000000000a',
        '00000000-0000-0000-0000-00000000000c',
        '00000000-0000-0000-0000-0000000000a2', now() - interval '25 hours');
select is_empty(
  $$ select * from public.claim_share_accepted() $$,
  'a link older than a day is stale news'
);
select isnt(
  (select notified_at from public.share_link
    where id = '00000000-0000-0000-0000-0000000000d2'),
  null,
  'and is stamped so it never goes out'
);

-- 10-11: the contact is no longer on the team; only the service claims.
insert into public.share_link (id, mentor_id, member_id, person_id) values
  ('00000000-0000-0000-0000-0000000000d3',
   '00000000-0000-0000-0000-00000000000a',
   '00000000-0000-0000-0000-00000000000d',
   '00000000-0000-0000-0000-0000000000a3');
select is_empty(
  $$ select * from public.claim_share_accepted() $$,
  'a contact off the team gets no push'
);
set local role authenticated;
set local request.jwt.claims =
  '{"sub": "00000000-0000-0000-0000-00000000000a", "role": "authenticated"}';
select throws_ok(
  $$ select * from public.claim_share_accepted() $$,
  '42501', null,
  'only the sender service claims'
);
reset role;

select * from finish();
rollback;

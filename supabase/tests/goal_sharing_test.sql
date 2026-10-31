-- Goal sharing (#147): invites, links, and what a mentor reads of a
-- member's goals. A mentors B; C is a stranger. Run with `supabase test db`.
begin;
create extension if not exists pgtap with schema extensions;
select plan(33);

insert into auth.users (id, email, raw_user_meta_data) values
  ('00000000-0000-0000-0000-00000000000a', 'a@example.com', '{"first_name": "Anna"}'),
  ('00000000-0000-0000-0000-00000000000b', 'b@example.com', '{"first_name": "Marie"}'),
  ('00000000-0000-0000-0000-00000000000c', 'c@example.com', '{"first_name": "Chris"}');

set local role authenticated;
set local request.jwt.claims =
  '{"sub": "00000000-0000-0000-0000-00000000000a", "role": "authenticated"}';

-- P is Marie on A's team, Q a prospect, P2 another team member.
insert into public.person (id, name, stage) values
  ('00000000-0000-0000-0000-0000000000a1', 'Marie', 'team'),
  ('00000000-0000-0000-0000-0000000000a2', 'Quentin', 'prospect'),
  ('00000000-0000-0000-0000-0000000000a3', 'Paul', 'team');

-- 1: a fresh invite.
select ok(
  (select code ~ '^[ABCDEFGHJKMNPQRSTUVWXYZ23456789]{8}$'
          and expires_at = now() + interval '14 days'
   from public.create_share_invite('00000000-0000-0000-0000-0000000000a1')),
  'an invite has an 8-character code and lasts 14 days'
);
select set_config('test.first_code', (select code from public.share_invite), true);

-- 2: inviting again replaces it.
select public.create_share_invite('00000000-0000-0000-0000-0000000000a1');
select results_eq(
  $$ select count(*)::int, bool_and(code <> current_setting('test.first_code'))
     from public.share_invite
     where person_id = '00000000-0000-0000-0000-0000000000a1' $$,
  $$ values (1, true) $$,
  'inviting again replaces the code'
);
select set_config('test.code', (select code from public.share_invite), true);

-- 3: only team members are invited.
select throws_ok(
  $$ select public.create_share_invite('00000000-0000-0000-0000-0000000000a2') $$,
  'P0001', 'not_team',
  'a prospect is not invited'
);

-- 4: invites are the mentor's only.
set local request.jwt.claims =
  '{"sub": "00000000-0000-0000-0000-00000000000c", "role": "authenticated"}';
select is_empty(
  $$ select 1 from public.share_invite $$,
  'a stranger reads no invite'
);
select throws_ok(
  $$ select public.create_share_invite('00000000-0000-0000-0000-0000000000a1') $$,
  'P0001', 'not_team',
  'a stranger does not invite on someone else''s contact'
);

-- 5: the member sees who invites them, whatever the code's case.
set local request.jwt.claims =
  '{"sub": "00000000-0000-0000-0000-00000000000b", "role": "authenticated"}';
select is(
  public.share_invite_preview(lower(current_setting('test.code'))),
  'Anna',
  'the preview names the mentor'
);

-- 6: not one's own invite.
set local request.jwt.claims =
  '{"sub": "00000000-0000-0000-0000-00000000000a", "role": "authenticated"}';
select throws_ok(
  $$ select public.accept_share_invite(current_setting('test.code'), '{}') $$,
  'P0001', 'invite_own',
  'the mentor does not accept their own invite'
);
select throws_ok(
  $$ select public.share_invite_preview(current_setting('test.code')) $$,
  'P0001', 'invite_own',
  'nor preview it'
);
select public.create_share_invite('00000000-0000-0000-0000-0000000000a3');

-- 7: unknown and expired codes.
reset role;
update public.share_invite set expires_at = now() - interval '1 second'
  where person_id = '00000000-0000-0000-0000-0000000000a3';
select set_config('test.expired_code', (select code from public.share_invite
  where person_id = '00000000-0000-0000-0000-0000000000a3'), true);
set local role authenticated;
set local request.jwt.claims =
  '{"sub": "00000000-0000-0000-0000-00000000000b", "role": "authenticated"}';
select throws_ok(
  $$ select public.accept_share_invite('ZZZZZZZZ', '{}') $$,
  'P0001', 'invite_invalid',
  'an unknown code is refused'
);
select throws_ok(
  $$ select public.accept_share_invite(current_setting('test.expired_code'), '{}') $$,
  'P0001', 'invite_invalid',
  'an expired code is refused'
);
select throws_ok(
  $$ select public.share_invite_preview(current_setting('test.expired_code')) $$,
  'P0001', 'invite_invalid',
  'an expired code has no preview'
);

-- 8: accepting, with a typed separator.
select lives_ok(
  $$ select public.accept_share_invite(
       substr(current_setting('test.code'), 1, 4) || '-'
         || substr(current_setting('test.code'), 5), '{activity_targets}') $$,
  'the member accepts'
);
reset role;
select is(
  (select count(*)::int from public.share_invite
    where person_id = '00000000-0000-0000-0000-0000000000a1'),
  0,
  'accepting uses up the invite'
);
set local role authenticated;
select throws_ok(
  $$ select public.accept_share_invite(current_setting('test.code'), '{}') $$,
  'P0001', 'invite_invalid',
  'a used code is refused'
);

-- 9: one mentor per member.
set local request.jwt.claims =
  '{"sub": "00000000-0000-0000-0000-00000000000c", "role": "authenticated"}';
insert into public.person (id, name, stage) values
  ('00000000-0000-0000-0000-0000000000c1', 'Marie', 'team');
select public.create_share_invite('00000000-0000-0000-0000-0000000000c1');
select set_config('test.c_code', (select code from public.share_invite), true);
set local request.jwt.claims =
  '{"sub": "00000000-0000-0000-0000-00000000000b", "role": "authenticated"}';
select throws_ok(
  $$ select public.accept_share_invite(current_setting('test.c_code'), '{}') $$,
  'P0001', 'already_sharing',
  'a member shares with one mentor'
);
select is(
  (select mentor_id from public.share_link),
  '00000000-0000-0000-0000-00000000000a'::uuid,
  'the first link stays'
);

-- 10: the member's own side.
select results_eq(
  $$ select * from public.my_share() $$,
  $$ values ('Anna'::text, '{activity_targets}'::public.share_item[]) $$,
  'the member sees whom they share with, and what'
);

-- 11: a stranger reads nothing.
set local request.jwt.claims =
  '{"sub": "00000000-0000-0000-0000-00000000000c", "role": "authenticated"}';
select is_empty(
  $$ select * from public.shared_goals('00000000-0000-0000-0000-0000000000a1',
       '2026-10-01', now() - interval '1 hour', now() + interval '1 hour') $$,
  'a stranger reads no shared goals'
);
select is_empty(
  $$ select 1 from public.share_link $$,
  'a stranger reads no link'
);
select is_empty(
  $$ select * from public.my_share() $$,
  'a stranger shares with no one'
);

-- 12: volume, level and activity targets.
set local request.jwt.claims =
  '{"sub": "00000000-0000-0000-0000-00000000000b", "role": "authenticated"}';
insert into public.month_plan (month, own_volume_target, team_volume_target,
  level_target, prospects_target, customers_target, team_members_target,
  loyalty_target)
  values ('2026-10-01', 500, 2000, 'Gold', 4, 2, 1, 3);
insert into public.month_plan (month, level_actual, closed_at)
  values ('2026-08-01', 'Bronze', now()), ('2026-09-01', 'Silver', now());
insert into public.person (name, stage) values ('Léo', 'prospect');

set local request.jwt.claims =
  '{"sub": "00000000-0000-0000-0000-00000000000a", "role": "authenticated"}';
select results_eq(
  $$ select member_first_name, plan->>'own_volume_target',
            plan->>'prospects_target', level_now, progress, why
     from public.shared_goals('00000000-0000-0000-0000-0000000000a1',
       '2026-10-01', now() - interval '1 hour', now() + interval '1 hour') $$,
  $$ values ('Marie'::text, '500.00'::text, '4'::text, 'Silver'::text,
             null::jsonb, null::text) $$,
  'the mentor reads the plan, the current level and the activity targets'
);
select is(
  (select plan from public.shared_goals('00000000-0000-0000-0000-0000000000a1',
     '2026-11-01', now() - interval '1 hour', now() + interval '1 hour')),
  null,
  'no plan for the month reads as null'
);

-- 13: activity targets off.
set local request.jwt.claims =
  '{"sub": "00000000-0000-0000-0000-00000000000b", "role": "authenticated"}';
update public.share_link set items = '{}';
set local request.jwt.claims =
  '{"sub": "00000000-0000-0000-0000-00000000000a", "role": "authenticated"}';
select results_eq(
  $$ select plan ? 'prospects_target', plan->>'level_target'
     from public.shared_goals('00000000-0000-0000-0000-0000000000a1',
       '2026-10-01', now() - interval '1 hour', now() + interval '1 hour') $$,
  $$ values (false, 'Gold'::text) $$,
  'without activity targets, volume and level only'
);

-- 14: progress, its counts only with activity targets, and About me.
set local request.jwt.claims =
  '{"sub": "00000000-0000-0000-0000-00000000000b", "role": "authenticated"}';
update public.share_link set items = '{progress}';
set local request.jwt.claims =
  '{"sub": "00000000-0000-0000-0000-00000000000a", "role": "authenticated"}';
select results_eq(
  $$ select progress ? 'own_volume', progress ? 'prospects'
     from public.shared_goals('00000000-0000-0000-0000-0000000000a1',
       '2026-10-01', now() - interval '1 hour', now() + interval '1 hour') $$,
  $$ values (true, false) $$,
  'progress without activity targets is the volume only'
);
set local request.jwt.claims =
  '{"sub": "00000000-0000-0000-0000-00000000000b", "role": "authenticated"}';
update public.share_link set items = '{progress,activity_targets,about_me}';
insert into public.about_me (why, own_goal) values ('My kids', 'Gold by June');
set local request.jwt.claims =
  '{"sub": "00000000-0000-0000-0000-00000000000a", "role": "authenticated"}';
select results_eq(
  $$ select progress->>'prospects', why, own_goal
     from public.shared_goals('00000000-0000-0000-0000-0000000000a1',
       '2026-10-01', now() - interval '1 hour', now() + interval '1 hour') $$,
  $$ values ('1'::text, 'My kids'::text, 'Gold by June'::text) $$,
  'the counts with activity targets, and About me, once shared'
);
select is_empty(
  $$ select 1 from public.about_me $$,
  'About me stays its owner''s table'
);

-- 15: the mentor does not change items; the contact must be on the team.
select is_empty(
  $$ update public.share_link set items = '{activity_targets}' returning 1 $$,
  'the mentor does not change what is shared'
);
update public.person set stage = 'customer'
  where id = '00000000-0000-0000-0000-0000000000a1';
select is_empty(
  $$ select * from public.shared_goals('00000000-0000-0000-0000-0000000000a1',
       '2026-10-01', now() - interval '1 hour', now() + interval '1 hour') $$,
  'off the team, nothing shows'
);
update public.person set stage = 'team'
  where id = '00000000-0000-0000-0000-0000000000a1';
select isnt_empty(
  $$ select * from public.shared_goals('00000000-0000-0000-0000-0000000000a1',
       '2026-10-01', now() - interval '1 hour', now() + interval '1 hour') $$,
  'back on the team, it shows again'
);

-- 16: deleting the contact ends the link.
delete from public.person where id = '00000000-0000-0000-0000-0000000000a1';
reset role;
select is(
  (select count(*)::int from public.share_link), 0,
  'deleting the contact removes the link'
);
set local role authenticated;

-- 17: progress is still one's own, and the owner-taking function is closed.
set local request.jwt.claims =
  '{"sub": "00000000-0000-0000-0000-00000000000b", "role": "authenticated"}';
select results_eq(
  $$ select * from public.month_progress('2026-10-01',
       now() - interval '1 hour', now() + interval '1 hour') $$,
  $$ values (0::numeric, 1, 0, 0, 0) $$,
  'month_progress counts only the caller''s book'
);
select throws_ok(
  $$ select * from public.month_progress_for(
       '00000000-0000-0000-0000-00000000000a', '2026-10-01',
       now() - interval '1 hour', now() + interval '1 hour') $$,
  '42501', null,
  'month_progress_for is not callable by users'
);
select is_empty(
  $$ select p.proname::text from pg_proc p
     where p.pronamespace = 'public'::regnamespace
       and p.proname in ('share_invite_preview', 'accept_share_invite',
         'my_share', 'shared_goals', 'create_share_invite', 'month_progress',
         'month_progress_for')
       and has_function_privilege('anon', p.oid, 'execute') $$,
  'anon calls none of the sharing functions'
);

select * from finish();
rollback;

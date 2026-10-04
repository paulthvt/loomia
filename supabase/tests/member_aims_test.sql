-- A team member's rank and volume: a month is the first of a month and needs
-- a target, a volume is above 0. Run with `supabase test db`.
begin;
create extension if not exists pgtap with schema extensions;
select plan(6);

insert into auth.users (id, email) values
  ('00000000-0000-0000-0000-00000000000a', 'a@example.com');

set local role authenticated;
set local request.jwt.claims =
  '{"sub": "00000000-0000-0000-0000-00000000000a", "role": "authenticated"}';

insert into public.person (id, name, stage) values
  ('00000000-0000-0000-0000-0000000000a1', 'Claire', 'team');

select lives_ok(
  $$ update public.person set current_level = 'Executive',
       target_level = 'Elite', target_level_by = '2027-03-01',
       monthly_volume_target = 100
     where id = '00000000-0000-0000-0000-0000000000a1' $$,
  'a rank, a target by a month and a volume save'
);
select is(
  (select monthly_volume_target from public.person
    where id = '00000000-0000-0000-0000-0000000000a1'), 100::numeric,
  'the volume is stored as given'
);
select throws_ok(
  $$ update public.person set target_level_by = '2027-03-15'
     where id = '00000000-0000-0000-0000-0000000000a1' $$,
  '23514', null,
  'a month that is not the first of a month is refused'
);
select throws_ok(
  $$ update public.person set target_level = null
     where id = '00000000-0000-0000-0000-0000000000a1' $$,
  '23514', null,
  'a month with no target is refused'
);
select throws_ok(
  $$ update public.person set monthly_volume_target = 0
     where id = '00000000-0000-0000-0000-0000000000a1' $$,
  '23514', null,
  'a volume of 0 is refused'
);
select lives_ok(
  $$ update public.person set current_level = null, target_level = null,
       target_level_by = null, monthly_volume_target = null
     where id = '00000000-0000-0000-0000-0000000000a1' $$,
  'all four can be cleared'
);

select * from finish();
rollback;

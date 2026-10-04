-- Goals (#141): month plans, live progress, the loyalty forecast and the
-- frozen close. Run with `supabase test db`.
begin;
create extension if not exists pgtap with schema extensions;
select plan(8);

insert into auth.users (id, email) values
  ('00000000-0000-0000-0000-00000000000a', 'a@example.com'),
  ('00000000-0000-0000-0000-00000000000b', 'b@example.com');

set local role authenticated;
set local request.jwt.claims =
  '{"sub": "00000000-0000-0000-0000-00000000000a", "role": "authenticated"}';

-- 1-2: first stage.
insert into public.person (id, name, stage, first_stage) values
  ('00000000-0000-0000-0000-0000000000a1', 'Sarah', 'prospect', 'team');
select is(
  (select first_stage::text from public.person
    where id = '00000000-0000-0000-0000-0000000000a1'),
  'prospect',
  'first_stage is the stage at insert, whatever the app sends'
);
update public.person set stage = 'customer'
  where id = '00000000-0000-0000-0000-0000000000a1';
select is(
  (select first_stage::text from public.person
    where id = '00000000-0000-0000-0000-0000000000a1'),
  'prospect',
  'a stage change keeps first_stage'
);

-- 3-6: month_plan constraints.
select lives_ok(
  $$ insert into public.month_plan (month, own_volume_target, prospects_target)
     values ('2026-10-01', 500, 4) $$,
  'a plan for a month saves'
);
select throws_ok(
  $$ insert into public.month_plan (month) values ('2026-10-01') $$,
  '23505', null,
  'one plan per month'
);
select throws_ok(
  $$ insert into public.month_plan (month) values ('2026-11-02') $$,
  '23514', null,
  'a month is its first day'
);
select throws_ok(
  $$ insert into public.month_plan (month, prospects_target)
     values ('2026-12-01', -1) $$,
  '23514', null,
  'a count target is not negative'
);

-- 7-8: as B.
set local request.jwt.claims =
  '{"sub": "00000000-0000-0000-0000-00000000000b", "role": "authenticated"}';
select is(
  (select count(*)::int from public.month_plan), 0,
  'another user sees no plan'
);
select lives_ok(
  $$ insert into public.month_plan (month) values ('2026-10-01') $$,
  'another user has their own October'
);

-- Back as A for the tasks below.
set local request.jwt.claims =
  '{"sub": "00000000-0000-0000-0000-00000000000a", "role": "authenticated"}';

select * from finish();
rollback;

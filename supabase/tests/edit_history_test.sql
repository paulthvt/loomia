-- Editing history (#187): the owner edits text, day and amount of their own
-- entries, nothing else; a stage entry follows the person's stage_since.
-- Run with `supabase test db`.
begin;
create extension if not exists pgtap with schema extensions;
select plan(12);

insert into auth.users (id, email) values
  ('00000000-0000-0000-0000-00000000000a', 'a@example.com'),
  ('00000000-0000-0000-0000-00000000000b', 'b@example.com');

set local role authenticated;
set local request.jwt.claims =
  '{"sub": "00000000-0000-0000-0000-00000000000a", "role": "authenticated"}';

insert into public.person (id, name, stage) values
  ('00000000-0000-0000-0000-0000000000a1', 'Sarah', 'prospect');
insert into public.activity (id, person_id, kind, text, amount, happened_on) values
  ('00000000-0000-0000-0000-0000000000c1',
   '00000000-0000-0000-0000-0000000000a1', 'order', 'Cream', 40, '2026-10-02');

-- 1-2: the owner edits text, day and amount.
select lives_ok(
  $$ update public.activity
       set text = 'Cream and soap', happened_on = '2026-10-01', amount = 55
       where id = '00000000-0000-0000-0000-0000000000c1' $$,
  'the owner edits text, day and amount'
);
select results_eq(
  $$ select text, happened_on, amount from public.activity
       where id = '00000000-0000-0000-0000-0000000000c1' $$,
  $$ values ('Cream and soap'::text, '2026-10-01'::date, 55::numeric) $$,
  'the edit is saved'
);

-- 3-4: kind and person are not editable.
select throws_ok(
  $$ update public.activity set kind = 'note'
       where id = '00000000-0000-0000-0000-0000000000c1' $$,
  '42501', null,
  'the kind cannot change'
);
select throws_ok(
  $$ update public.activity set person_id = null
       where id = '00000000-0000-0000-0000-0000000000c1' $$,
  '42501', null,
  'the person cannot change'
);

-- 5: an edit is held to the same shape as an insert.
select throws_ok(
  $$ update public.activity set text = ' '
       where id = '00000000-0000-0000-0000-0000000000c1' $$,
  '23514', null,
  'an edit is held to the same shape as an insert: no blank text'
);

-- Two stage changes; the first moved back as postgres, so they are apart.
update public.person set stage = 'customer'
  where id = '00000000-0000-0000-0000-0000000000a1';
reset role;
update public.activity set created_at = '2026-01-01 10:00+00'
  where kind = 'stage';
set local role authenticated;
update public.person set stage = 'team'
  where id = '00000000-0000-0000-0000-0000000000a1';

-- 6: stage entries are not edited directly (RLS filters them out).
update public.activity set happened_on = '2020-01-01' where kind = 'stage';
select is(
  (select count(*)::int from public.activity
     where kind = 'stage' and happened_on = '2020-01-01'),
  0,
  'a stage entry cannot be edited directly'
);

-- 7: another user edits nothing.
set local request.jwt.claims =
  '{"sub": "00000000-0000-0000-0000-00000000000b", "role": "authenticated"}';
update public.activity set text = 'Mine now'
  where id = '00000000-0000-0000-0000-0000000000c1';
set local request.jwt.claims =
  '{"sub": "00000000-0000-0000-0000-00000000000a", "role": "authenticated"}';
select is(
  (select text from public.activity
     where id = '00000000-0000-0000-0000-0000000000c1'),
  'Cream and soap',
  'another user cannot edit the entry'
);

-- 8: before the move, the team change counts this month.
select is(
  (select team_members from public.month_progress(current_date,
     now() - interval '1 hour', now() + interval '1 hour')),
  1,
  'joining the team today counts today'
);

-- 9-10: moving stage_since moves the latest stage entry only.
update public.person set stage_since = '2026-06-01 00:00+00'
  where id = '00000000-0000-0000-0000-0000000000a1';
select results_eq(
  $$ select stage::text, created_at from public.activity
       where kind = 'stage' order by created_at $$,
  $$ values ('customer'::text, '2026-01-01 10:00+00'::timestamptz),
            ('team'::text, '2026-06-01 00:00+00'::timestamptz) $$,
  'the latest stage entry follows stage_since; older ones stay'
);
select is(
  (select team_members from public.month_progress(current_date,
     now() - interval '1 hour', now() + interval '1 hour')),
  0,
  'goals follow the moved stage entry'
);

-- 11: moved before the stage before it, the entry stays just after it, so
-- the latest one is still the current stage's.
update public.person set stage_since = '2025-01-01 00:00+00'
  where id = '00000000-0000-0000-0000-0000000000a1';
select results_eq(
  $$ select stage::text, created_at from public.activity
       where kind = 'stage' order by created_at $$,
  $$ values ('customer'::text, '2026-01-01 10:00+00'::timestamptz),
            ('team'::text, '2026-01-01 10:00:00.000001+00'::timestamptz) $$,
  'a stage entry never moves before the one before it'
);

-- 12: a stage change still starts now.
update public.person set stage = 'customer'
  where id = '00000000-0000-0000-0000-0000000000a1';
select is(
  (select max(created_at) from public.activity where kind = 'stage'),
  now(),
  'a stage change writes its entry at now()'
);

select * from finish();
rollback;

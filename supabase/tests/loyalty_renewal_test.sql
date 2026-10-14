-- LRP renewal (#317): the renewal day, when it is due, and ticking it.
-- test/features/contacts/domain/loyalty_renewal_test.dart pins the same
-- cases on the Dart copy. Run with `supabase test db`.
begin;
create extension if not exists pgtap with schema extensions;
select plan(16);

insert into auth.users (id, email) values
  ('00000000-0000-0000-0000-00000000000a', 'a@example.com');

set local role authenticated;
set local request.jwt.claims =
  '{"sub": "00000000-0000-0000-0000-00000000000a", "role": "authenticated"}';

insert into public.person (id, name, stage) values
  ('00000000-0000-0000-0000-0000000000a1', 'Julie', 'customer'),
  ('00000000-0000-0000-0000-0000000000a2', 'Claire', 'customer'),
  ('00000000-0000-0000-0000-0000000000a3', 'Marie', 'customer');

-- 1-3: set_loyalty and the day.
select public.set_loyalty('00000000-0000-0000-0000-0000000000a1',
  '2026-09-15', '2026-09-15');
select is(
  (select loyalty_day from public.person
    where id = '00000000-0000-0000-0000-0000000000a1'),
  15::smallint, 'a start fills the day from its own'
);
select public.set_loyalty('00000000-0000-0000-0000-0000000000a1',
  '2026-09-10', '2026-09-15');
select is(
  (select loyalty_day from public.person
    where id = '00000000-0000-0000-0000-0000000000a1'),
  15::smallint, 'a move keeps it'
);
select public.set_loyalty('00000000-0000-0000-0000-0000000000a2',
  '2026-03-31', '2026-03-31');
select is(
  (select loyalty_day from public.person
    where id = '00000000-0000-0000-0000-0000000000a2'),
  28::smallint, 'the 31st renews on the 28th'
);

-- 4-9: when it is due, for Julie on the 15th.
select results_eq(
  $$ select d::date, public.loyalty_renewal_on(p, d::date)
     from public.person p,
          unnest(array['2026-10-11', '2026-10-12', '2026-10-15', '2026-10-16'])
            as d
     where p.id = '00000000-0000-0000-0000-0000000000a1'
     order by d $$,
  $$ values ('2026-10-11'::date, null::date),
            ('2026-10-12'::date, '2026-10-15'::date),
            ('2026-10-15'::date, '2026-10-15'::date),
            ('2026-10-16'::date, null::date) $$,
  '4 days before: not yet; 3 days before to the day: due; after: next month, not yet'
);
select is(
  (select public.loyalty_renewal_on(p, '2027-02-25') from public.person p
    where id = '00000000-0000-0000-0000-0000000000a2'),
  '2027-02-28'::date, 'the 28th in February'
);
select is(
  (select public.loyalty_renewal_on(p, '2026-11-14') from public.person p
    where id = '00000000-0000-0000-0000-0000000000a1'),
  '2026-11-15'::date, 'next month it comes back'
);
select is(
  (select public.loyalty_renewal_on(p, '2026-10-15') from public.person p
    where id = '00000000-0000-0000-0000-0000000000a3'),
  null, 'no LRP, nothing to check'
);

-- 8-12: ticking.
select public.check_loyalty('00000000-0000-0000-0000-0000000000a1',
  '2026-10-15', '2026-10-13', 'Julie''s LRP renews Oct 15');
select results_eq(
  $$ select kind::text, text, happened_on from public.activity
     where person_id = '00000000-0000-0000-0000-0000000000a1'
       and kind = 'reminder' $$,
  $$ values ('reminder', 'Julie''s LRP renews Oct 15', '2026-10-13'::date) $$,
  'a reminder entry with the device''s text, on its day'
);
select is(
  (select public.loyalty_renewal_on(p, '2026-10-14') from public.person p
    where id = '00000000-0000-0000-0000-0000000000a1'),
  null, 'checked: not due any more'
);
select public.check_loyalty('00000000-0000-0000-0000-0000000000a1',
  '2026-10-15', '2026-10-14', 'Julie''s LRP renews Oct 15');
select is(
  (select count(*)::int from public.activity
    where person_id = '00000000-0000-0000-0000-0000000000a1'
      and kind = 'reminder'),
  1, 'the same renewal again adds nothing'
);
select throws_ok(
  $$ select public.check_loyalty('00000000-0000-0000-0000-0000000000a3',
       '2026-10-15', '2026-10-13', 'x') $$,
  'P0001', null, 'no LRP: refused'
);

-- 13: the push.
reset role;
set local role service_role;
select is(
  public.due_people_count('00000000-0000-0000-0000-00000000000a', '2027-02-25'),
  1, 'Claire''s renewal on the 28th counts'
);
reset role;
set local role authenticated;
set local request.jwt.claims =
  '{"sub": "00000000-0000-0000-0000-00000000000a", "role": "authenticated"}';

-- Across a year: a renewal on January 2nd is asked on December 30th.
update public.person set loyalty_day = 2
  where id = '00000000-0000-0000-0000-0000000000a2';
select is(
  (select public.loyalty_renewal_on(p, '2026-12-30') from public.person p
    where id = '00000000-0000-0000-0000-0000000000a2'),
  '2027-01-02'::date, 'across a year'
);

-- 14-16: a stop clears it.
select public.set_loyalty('00000000-0000-0000-0000-0000000000a1', null,
  '2026-10-20');
select results_eq(
  $$ select loyalty_day, loyalty_checked_for from public.person
     where id = '00000000-0000-0000-0000-0000000000a1' $$,
  $$ values (null::smallint, null::date) $$,
  'a stop clears the day and the check'
);
select throws_ok(
  $$ update public.person set loyalty_day = 29
     where id = '00000000-0000-0000-0000-0000000000a2' $$,
  '23514', null, 'a day past the 28th is refused'
);
select lives_ok(
  $$ update public.person set loyalty_day = 20
     where id = '00000000-0000-0000-0000-0000000000a2' $$,
  'the app sets the day'
);

select * from finish();
rollback;

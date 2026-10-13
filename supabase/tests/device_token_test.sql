-- Device tokens (#268): one row per FCM token, owned by the account that
-- registered it last. Only register_device writes them. Run with
-- `supabase test db`.
begin;
create extension if not exists pgtap with schema extensions;
select plan(12);

insert into auth.users (id, email) values
  ('00000000-0000-0000-0000-00000000000a', 'a@example.com'),
  ('00000000-0000-0000-0000-00000000000b', 'b@example.com');

set local role authenticated;
set local request.jwt.claims =
  '{"sub": "00000000-0000-0000-0000-00000000000a", "role": "authenticated"}';

select lives_ok(
  $$ select public.register_device('t1', 'android', 'fr') $$,
  'a signed-in user registers a token'
);
reset role;
select results_eq(
  $$ select owner_id, platform::text, locale from public.device_token $$,
  $$ values ('00000000-0000-0000-0000-00000000000a'::uuid, 'android'::text,
             'fr'::text) $$,
  'it is theirs, with its platform and language'
);
set local role authenticated;
select throws_ok(
  $$ select public.register_device(' ', 'android', 'fr') $$,
  '23514', null,
  'a blank token is refused'
);
select throws_ok(
  $$ select public.register_device('t2', 'android', 'french') $$,
  '23514', null,
  'a language that is not a code is refused'
);
select throws_ok(
  $$ insert into public.device_token (token, platform, locale)
     values ('t3', 'ios', 'en') $$,
  '42501', null,
  'no direct insert'
);
select throws_ok(
  $$ delete from public.device_token $$,
  '42501', null,
  'no direct delete'
);

-- The same phone, signed into another account.
set local request.jwt.claims =
  '{"sub": "00000000-0000-0000-0000-00000000000b", "role": "authenticated"}';
select public.register_device('t1', 'ios', 'en');

reset role;
select results_eq(
  $$ select owner_id, platform::text, locale from public.device_token $$,
  $$ values ('00000000-0000-0000-0000-00000000000b'::uuid, 'ios'::text,
             'en'::text) $$,
  'registering again moves the token to the new account'
);
select is(
  (select count(*)::int from public.device_token), 1,
  'still one row'
);

-- The kinds the installed app can show (#148).
select is(
  (select push_kinds::text from public.device_token), '{daily_summary}',
  'an app that names no kinds only gets the daily summary'
);
set local role authenticated;
select public.register_device(
  't1', 'ios', 'en', '{daily_summary,month_ritual}');
reset role;
select is(
  (select push_kinds::text from public.device_token),
  '{daily_summary,month_ritual}',
  'a newer app names both'
);
set local role authenticated;
select public.register_device('t1', 'ios', 'en');
reset role;
select is(
  (select push_kinds::text from public.device_token), '{daily_summary}',
  'the same phone back on an older build: the default again'
);

set local role authenticated;
set local request.jwt.claims = '{"role": "authenticated"}';
select throws_ok(
  $$ select public.register_device('t4', 'android', 'en') $$,
  '42501', null,
  'without a user, refused'
);

select * from finish();
rollback;

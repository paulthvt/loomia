-- When the user last talked with someone: every activity but a stage
-- change, which the database writes itself, and being at an event (#300). Run with `supabase test db`.
begin;
create extension if not exists pgtap with schema extensions;
select plan(5);

insert into auth.users (id, email) values
  ('00000000-0000-0000-0000-00000000000a', 'a@example.com');

set local role authenticated;
set local request.jwt.claims =
  '{"sub": "00000000-0000-0000-0000-00000000000a", "role": "authenticated"}';

insert into public.person (id, name, stage) values
  ('00000000-0000-0000-0000-0000000000a1', 'Talked', 'prospect'),
  ('00000000-0000-0000-0000-0000000000a2', 'Only moved', 'prospect'),
  ('00000000-0000-0000-0000-0000000000a3', 'Ticked', 'prospect'),
  ('00000000-0000-0000-0000-0000000000a4', 'Nothing', 'team'),
  ('00000000-0000-0000-0000-0000000000a5', 'At a call', 'team');

insert into public.activity (person_id, kind, text, happened_on) values
  ('00000000-0000-0000-0000-0000000000a1', 'call', 'Catch-up', '2026-09-12'),
  ('00000000-0000-0000-0000-0000000000a1', 'note', 'Older', '2026-09-01'),
  ('00000000-0000-0000-0000-0000000000a3', 'step', 'Send a first message', '2026-09-20'),
  ('00000000-0000-0000-0000-0000000000a5', 'call', 'Catch-up', '2026-09-10'),
  ('00000000-0000-0000-0000-0000000000a5', 'event', 'Team call', '2026-09-25');

-- The trigger writes a stage entry dated today, later than the call.
update public.person set stage = 'team'
  where id in ('00000000-0000-0000-0000-0000000000a1',
               '00000000-0000-0000-0000-0000000000a2');

select is(
  (select public.last_contact_on(p) from public.person p
   where p.id = '00000000-0000-0000-0000-0000000000a1'),
  '2026-09-12'::date, 'the latest entry, not the stage change');
select is(
  (select public.last_contact_on(p) from public.person p
   where p.id = '00000000-0000-0000-0000-0000000000a2'),
  null::date, 'a stage change alone is no contact');
select is(
  (select public.last_contact_on(p) from public.person p
   where p.id = '00000000-0000-0000-0000-0000000000a3'),
  '2026-09-20'::date, 'a ticked step counts');
select is(
  (select public.last_contact_on(p) from public.person p
   where p.id = '00000000-0000-0000-0000-0000000000a4'),
  null::date, 'nothing logged');
select is(
  (select public.last_contact_on(p) from public.person p
   where p.id = '00000000-0000-0000-0000-0000000000a5'),
  '2026-09-10'::date, 'being at an event is no contact');

select * from finish();
rollback;

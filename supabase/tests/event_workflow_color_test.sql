-- Event type colours (#516): every type has a tag-palette colour; one
-- inserted without picks the first its owner doesn't use, all used → stone.
-- Run with `supabase test db`.
begin;
create extension if not exists pgtap with schema extensions;
select plan(6);

insert into auth.users (id, email) values
  ('00000000-0000-0000-0000-00000000000a', 'a@example.com'),
  ('00000000-0000-0000-0000-00000000000b', 'b@example.com'),
  ('00000000-0000-0000-0000-00000000000c', 'c@example.com');

select has_column('public', 'event_workflow', 'color', 'event types have a colour');

set local role authenticated;
set local request.jwt.claims =
  '{"sub": "00000000-0000-0000-0000-00000000000a", "role": "authenticated"}';

insert into public.event_workflow (name) values ('One');
select results_eq(
  $$ select color::text from public.event_workflow where name = 'One' $$,
  $$ values ('stone') $$,
  'the first type takes the first colour'
);

insert into public.event_workflow (name) values ('Two');
insert into public.event_workflow (name, color) values ('Three', 'violet');
select results_eq(
  $$ select name, color::text from public.event_workflow
     where name in ('Two', 'Three') order by name $$,
  $$ values ('Three', 'violet'), ('Two', 'sand') $$,
  'the next free colour, and a chosen one stays'
);

-- One at a time: each insert sees the colours before it.
insert into public.event_workflow (name) values ('Four');
insert into public.event_workflow (name) values ('Five');
insert into public.event_workflow (name) values ('Six');
insert into public.event_workflow (name) values ('Seven');
insert into public.event_workflow (name) values ('Eight');
insert into public.event_workflow (name) values ('Nine');
select results_eq(
  $$ select w.name, w.color::text from public.event_workflow w
     order by w.color, w.name $$,
  $$ values ('Nine', 'stone'), ('One', 'stone'), ('Two', 'sand'),
            ('Four', 'olive'), ('Five', 'sage'), ('Six', 'teal'),
            ('Seven', 'sky'), ('Eight', 'indigo'), ('Three', 'violet') $$,
  'colours in palette order; all used, stone'
);

set local request.jwt.claims =
  '{"sub": "00000000-0000-0000-0000-00000000000b", "role": "authenticated"}';
insert into public.event_workflow (name) values ('Other');
select results_eq(
  $$ select color::text from public.event_workflow where name = 'Other' $$,
  $$ values ('stone') $$,
  'the rule is per owner'
);

set local request.jwt.claims =
  '{"sub": "00000000-0000-0000-0000-00000000000c", "role": "authenticated"}';
select public.seed_workflows('en', current_date);
select results_eq(
  $$ select w.name, w.color::text from public.event_workflow w order by w.color $$,
  $$ values ('Workshop', 'stone'), ('Wellness check', 'sand'),
            ('Unboxing call', 'olive'), ('Wellness consultation', 'sage'),
            ('Mentoring', 'teal') $$,
  'the seeded types get colours in the order they are added'
);

select * from finish();
rollback;

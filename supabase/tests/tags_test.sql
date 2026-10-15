-- Tags on contacts (#332): a name and a colour per tag, any number per
-- person, written for many people at once by `set_person_tags`.
-- Run with `supabase test db`.
begin;
create extension if not exists pgtap with schema extensions;
select plan(17);

insert into auth.users (id, email) values
  ('00000000-0000-0000-0000-00000000000a', 'a@example.com'),
  ('00000000-0000-0000-0000-00000000000b', 'b@example.com');

set local role authenticated;
set local request.jwt.claims =
  '{"sub": "00000000-0000-0000-0000-00000000000a", "role": "authenticated"}';

insert into public.person (id, name, stage) values
  ('00000000-0000-0000-0000-0000000000a1', 'Claire', 'prospect'),
  ('00000000-0000-0000-0000-0000000000a2', 'Julie', 'customer');

select lives_ok(
  $$ insert into public.tag (id, name, color) values
     ('00000000-0000-0000-0000-0000000000f1', 'Lyon', 'sage'),
     ('00000000-0000-0000-0000-0000000000f2', 'Sleep', 'sky') $$,
  'a tag saves'
);
select throws_ok(
  $$ insert into public.tag (name, color) values ('  ', 'stone') $$,
  '23514', null,
  'a blank name is refused'
);
select throws_ok(
  $$ insert into public.tag (name, color) values (repeat('x', 33), 'stone') $$,
  '23514', null,
  'a name over 32 characters is refused'
);
select throws_ok(
  $$ insert into public.tag (name, color) values (' lyon ', 'teal') $$,
  '23505', null,
  'the same name, another case and spaces, is refused'
);

select lives_ok(
  $$ select public.set_person_tags(
       array['00000000-0000-0000-0000-0000000000a1',
             '00000000-0000-0000-0000-0000000000a2']::uuid[],
       array['00000000-0000-0000-0000-0000000000f1',
             '00000000-0000-0000-0000-0000000000f2']::uuid[],
       '{}') $$,
  'two people get two tags'
);
select is((select count(*) from public.person_tag), 4::bigint, 'four links');

select public.set_person_tags(
  array['00000000-0000-0000-0000-0000000000a1']::uuid[],
  array['00000000-0000-0000-0000-0000000000f1']::uuid[],
  '{}');
select is((select count(*) from public.person_tag), 4::bigint,
  'adding a tag someone has adds nothing');

select public.set_person_tags(
  array['00000000-0000-0000-0000-0000000000a1']::uuid[],
  '{}',
  array['00000000-0000-0000-0000-0000000000f1']::uuid[]);
select is(
  (select array_agg(person_id order by person_id) from public.person_tag
   where tag_id = '00000000-0000-0000-0000-0000000000f1'),
  array['00000000-0000-0000-0000-0000000000a2']::uuid[],
  'removing takes it from that person only'
);

select throws_ok(
  $$ select public.set_person_tags(
       array['00000000-0000-0000-0000-0000000000a1']::uuid[],
       array['00000000-0000-0000-0000-0000000000f1']::uuid[],
       array['00000000-0000-0000-0000-0000000000f1']::uuid[]) $$,
  'P0001', null,
  'a tag both added and removed is refused'
);

set local request.jwt.claims =
  '{"sub": "00000000-0000-0000-0000-00000000000b", "role": "authenticated"}';

insert into public.person (id, name, stage) values
  ('00000000-0000-0000-0000-0000000000b1', 'Marc', 'prospect');
insert into public.tag (id, name, color) values
  ('00000000-0000-0000-0000-0000000000f9', 'Lyon', 'stone');

select pass('another account may use the same name');
select is((select count(*) from public.tag), 1::bigint, 'b sees only its tag');
select is((select count(*) from public.person_tag), 0::bigint,
  'b sees none of a''s links');
select throws_ok(
  $$ select public.set_person_tags(
       array['00000000-0000-0000-0000-0000000000b1']::uuid[],
       array['00000000-0000-0000-0000-0000000000f1']::uuid[],
       '{}') $$,
  '23503', null,
  'another account''s tag is refused'
);
select throws_ok(
  $$ select public.set_person_tags(
       array['00000000-0000-0000-0000-0000000000a1']::uuid[],
       array['00000000-0000-0000-0000-0000000000f9']::uuid[],
       '{}') $$,
  '23503', null,
  'another account''s person is refused'
);

set local request.jwt.claims =
  '{"sub": "00000000-0000-0000-0000-00000000000a", "role": "authenticated"}';

delete from public.tag where id = '00000000-0000-0000-0000-0000000000f2';
select is(
  (select count(*) from public.person_tag
   where tag_id = '00000000-0000-0000-0000-0000000000f2'),
  0::bigint,
  'deleting a tag removes it from everyone'
);
delete from public.person where id = '00000000-0000-0000-0000-0000000000a2';
select is((select count(*) from public.person_tag), 0::bigint,
  'deleting a person removes their tags');

set local role anon;
select throws_ok(
  $$ select public.set_person_tags('{}', '{}', '{}') $$,
  '42501', null,
  'anon cannot tag'
);

select * from finish();
rollback;

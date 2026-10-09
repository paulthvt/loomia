-- Profile photos (#239): the avatars bucket is private, with its limits on
-- the row, and each user reads, writes and deletes only in their own folder.
-- Run with `supabase test db`.
begin;
create extension if not exists pgtap with schema extensions;
select plan(10);

insert into auth.users (id, email) values
  ('00000000-0000-0000-0000-00000000000a', 'a@example.com'),
  ('00000000-0000-0000-0000-00000000000b', 'b@example.com');

select results_eq(
  $$ select public, file_size_limit, allowed_mime_types
     from storage.buckets where id = 'avatars' $$,
  $$ values (false, 262144::bigint, '{image/jpeg,image/png,image/webp}'::text[]) $$,
  'the bucket is private, 256 KB, images only'
);
select has_column('public', 'person', 'photo_path', 'person has photo_path');

-- As A.
set local role authenticated;
set local request.jwt.claims =
  '{"sub": "00000000-0000-0000-0000-00000000000a", "role": "authenticated"}';

select lives_ok(
  $$ insert into storage.objects (bucket_id, name)
     values ('avatars', '00000000-0000-0000-0000-00000000000a/f1') $$,
  'the owner writes in their folder'
);
select throws_ok(
  $$ insert into storage.objects (bucket_id, name)
     values ('avatars', '00000000-0000-0000-0000-00000000000b/f2') $$,
  '42501', null,
  'nobody writes in another folder'
);
select throws_ok(
  $$ insert into storage.objects (bucket_id, name) values ('avatars', 'f3') $$,
  '42501', null,
  'nobody writes outside a folder'
);
select is(
  (select count(*)::int from storage.objects where bucket_id = 'avatars'), 1,
  'the owner reads their file'
);

-- As B: sees nothing, deletes nothing.
set local request.jwt.claims =
  '{"sub": "00000000-0000-0000-0000-00000000000b", "role": "authenticated"}';
select is(
  (select count(*)::int from storage.objects where bucket_id = 'avatars'), 0,
  'another user reads nothing'
);
-- Storage's protect_objects_delete trigger refuses direct deletes otherwise.
set local storage.allow_delete_query = 'true';
delete from storage.objects
  where name = '00000000-0000-0000-0000-00000000000a/f1';

set local request.jwt.claims =
  '{"sub": "00000000-0000-0000-0000-00000000000a", "role": "authenticated"}';
select is(
  (select count(*)::int from storage.objects where bucket_id = 'avatars'), 1,
  'another user cannot delete the file'
);
delete from storage.objects
  where name = '00000000-0000-0000-0000-00000000000a/f1';
select is(
  (select count(*)::int from storage.objects where bucket_id = 'avatars'), 0,
  'the owner deletes their file'
);

-- As anon.
set local role anon;
set local request.jwt.claims = '{"role": "anon"}';
select is(
  (select count(*)::int from storage.objects where bucket_id = 'avatars'), 0,
  'anon reads nothing'
);

select * from finish();
rollback;

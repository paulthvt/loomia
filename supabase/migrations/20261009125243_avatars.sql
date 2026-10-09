-- Profile photos (#239). A private bucket: contacts' photos are third
-- parties' personal data. One folder per user, `<uid>/<random>`. 256 px
-- JPEGs are ~20 KB; the limit refuses anything far off. Storage enforces the
-- size and types on upload, the policies below decide who reaches a file.
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('avatars', 'avatars', false, 262144,
        '{image/jpeg,image/png,image/webp}');

create policy avatars_select_own on storage.objects
  for select to authenticated
  using (bucket_id = 'avatars'
         and (storage.foldername(name))[1] = (select auth.uid())::text);
create policy avatars_insert_own on storage.objects
  for insert to authenticated
  with check (bucket_id = 'avatars'
              and (storage.foldername(name))[1] = (select auth.uid())::text);
create policy avatars_update_own on storage.objects
  for update to authenticated
  using (bucket_id = 'avatars'
         and (storage.foldername(name))[1] = (select auth.uid())::text)
  with check (bucket_id = 'avatars'
              and (storage.foldername(name))[1] = (select auth.uid())::text);
create policy avatars_delete_own on storage.objects
  for delete to authenticated
  using (bucket_id = 'avatars'
         and (storage.foldername(name))[1] = (select auth.uid())::text);

-- Null: initials. Written only on its own (PeopleRepository.setPhoto), never
-- by an edit, so a stale copy cannot bring a removed photo back.
alter table public.person add column photo_path text;

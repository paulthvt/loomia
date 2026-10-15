-- Tags on contacts (#332): a name and a palette colour per tag, any number
-- per person. A group is a tag. Additive: safe for the released app.

-- The palette keys, in the order new tags take them (`nextTagColor`).
create type public.tag_color as enum
  ('stone', 'sand', 'olive', 'sage', 'teal', 'sky', 'indigo', 'violet');

create table public.tag (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null default auth.uid()
    references auth.users on delete cascade,
  name text not null check (length(trim(name)) between 1 and 32),
  color public.tag_color not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (id, owner_id)
);

-- Backstop only: the app also ignores accents (`searchKey`), which Postgres
-- cannot without `unaccent`.
create unique index tag_owner_id_name_key
  on public.tag (owner_id, lower(trim(name)));

create trigger tag_set_updated_at before update on public.tag
  for each row execute function public.set_updated_at();

alter table public.tag enable row level security;

create policy tag_select_own on public.tag
  for select to authenticated using (owner_id = (select auth.uid()));
create policy tag_insert_own on public.tag
  for insert to authenticated with check (owner_id = (select auth.uid()));
create policy tag_update_own on public.tag
  for update to authenticated
  using (owner_id = (select auth.uid()))
  with check (owner_id = (select auth.uid()));
create policy tag_delete_own on public.tag
  for delete to authenticated using (owner_id = (select auth.uid()));

revoke all on public.tag from anon, authenticated;
grant select, insert, delete on public.tag to authenticated;
grant update (name, color) on public.tag to authenticated;

-- A row is there or not: no update.
create table public.person_tag (
  person_id uuid not null,
  tag_id uuid not null,
  owner_id uuid not null default auth.uid()
    references auth.users on delete cascade,
  primary key (person_id, tag_id),
  foreign key (person_id, owner_id)
    references public.person (id, owner_id) on delete cascade,
  foreign key (tag_id, owner_id)
    references public.tag (id, owner_id) on delete cascade
);

create index person_tag_tag_id_owner_id_idx
  on public.person_tag (tag_id, owner_id);

alter table public.person_tag enable row level security;

create policy person_tag_select_own on public.person_tag
  for select to authenticated using (owner_id = (select auth.uid()));
create policy person_tag_insert_own on public.person_tag
  for insert to authenticated with check (owner_id = (select auth.uid()));
create policy person_tag_delete_own on public.person_tag
  for delete to authenticated using (owner_id = (select auth.uid()));

revoke all on public.person_tag from anon, authenticated;
grant select, insert, delete on public.person_tag to authenticated;

-- Adds every person × add that is missing and removes every person × remove,
-- in one transaction. Another owner's person or tag fails the composite
-- foreign key, so the whole call is refused.
create function public.set_person_tags(
  p_people uuid[], p_add uuid[], p_remove uuid[]
) returns void
language plpgsql security invoker set search_path = '' as $$
begin
  if p_add && p_remove then
    raise exception 'a tag is both added and removed' using errcode = 'P0001';
  end if;
  insert into public.person_tag (person_id, tag_id)
    select person, tag from unnest(p_people) person, unnest(p_add) tag
    on conflict do nothing;
  delete from public.person_tag
    where person_id = any (p_people) and tag_id = any (p_remove);
end $$;

revoke execute on function public.set_person_tags(uuid[], uuid[], uuid[])
  from public, anon;
grant execute on function public.set_person_tags(uuid[], uuid[], uuid[])
  to authenticated;

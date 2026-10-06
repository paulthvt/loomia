-- Editing history (#187). The owner edits what they wrote: text, day and an
-- order's amount, never the kind, the person or the stage. The checks on
-- activity apply to an edit as to an insert.
create policy activity_update_own on public.activity
  for update to authenticated
  using (owner_id = (select auth.uid()) and kind <> 'stage')
  with check (owner_id = (select auth.uid()) and kind <> 'stage');

grant update (text, happened_on, amount) on public.activity to authenticated;

-- A stage entry is never edited directly: its day is the person's
-- stage_since. When stage_since moves without a stage change (an import
-- backdated, a correction), the latest stage entry moves with it. For a
-- stage entry, created_at is when the stage began: the history and goals
-- both read it. It stays after the stage entry before it, so the latest one
-- is always the current stage's; stage_since itself is kept as given.
-- security definer for the same reason as person_stage_changed: stage
-- entries are not writable by the app.
create function public.person_stage_since_moved() returns trigger
language plpgsql security definer set search_path = '' as $$
declare
  latest uuid;
  previous timestamptz;
begin
  select a.id into latest from public.activity a
    where a.person_id = new.id and a.owner_id = new.owner_id
      and a.kind = 'stage'
    order by a.created_at desc, a.id desc
    limit 1;
  if latest is null then
    return null;
  end if;
  select max(a.created_at) into previous from public.activity a
    where a.person_id = new.id and a.owner_id = new.owner_id
      and a.kind = 'stage' and a.id <> latest;
  update public.activity
    set created_at = greatest(new.stage_since, previous + interval '1 microsecond')
    where id = latest;
  return null;
end $$;

create trigger person_stage_since_moved
  after update of stage_since on public.person
  for each row
  when (old.stage_since is distinct from new.stage_since
        and old.stage is not distinct from new.stage)
  execute function public.person_stage_since_moved();

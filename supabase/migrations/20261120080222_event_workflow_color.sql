-- Event type colours (#516): each type takes a tag-palette colour, which its
-- events show in the calendar and on Today. Nullable so the migration stays
-- additive, but never null: existing types are coloured here, new ones by
-- the trigger, which also covers the released app and seed_workflows, both
-- inserting without a colour.

alter table public.event_workflow add column color public.tag_color;

-- Per owner, in creation order, the n-th type takes the n-th palette key;
-- past the eighth, stone. The same as the trigger's rule when none had one.
update public.event_workflow w
  set color = case when ranked.n <= 8
    then (enum_range(null::public.tag_color))[ranked.n]
    else 'stone' end
  from (
    select id, row_number() over (partition by owner_id
      order by created_at, id)::int as n
    from public.event_workflow
  ) ranked
  where w.id = ranked.id;

-- A type inserted without a colour takes the first its owner doesn't use;
-- all used, stone (nextTagColor's rule). Inserts by one owner take a lock
-- per owner (key 516, the issue) until commit, so two at once don't read
-- the same used colours.
create function public.event_workflow_default_color() returns trigger
language plpgsql set search_path = '' as $$
begin
  if new.color is null then
    perform pg_advisory_xact_lock(516, hashtext(new.owner_id::text));
    new.color := coalesce(
      (select key from unnest(enum_range(null::public.tag_color))
         with ordinality as palette(key, position)
       where key not in (
         select color from public.event_workflow
         where owner_id = new.owner_id and color is not null)
       order by position
       limit 1),
      'stone');
  end if;
  return new;
end;
$$;

create trigger event_workflow_default_color
  before insert on public.event_workflow
  for each row execute function public.event_workflow_default_color();

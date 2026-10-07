-- Event workflows (#153): an event's type and checklist (steps N days before
-- or after it), and per stage the person workflow that people who were
-- there start. mark_event_done starts them; seed_workflows adds Workshop.

create table public.event_workflow (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null default auth.uid()
    references auth.users on delete cascade,
  name text not null check (length(trim(name)) > 0),
  -- Null: people at that stage keep their workflow.
  prospect_workflow_id uuid,
  customer_workflow_id uuid,
  team_workflow_id uuid,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (id, owner_id),
  foreign key (prospect_workflow_id, owner_id)
    references public.workflow (id, owner_id) on delete set null (prospect_workflow_id),
  foreign key (customer_workflow_id, owner_id)
    references public.workflow (id, owner_id) on delete set null (customer_workflow_id),
  foreign key (team_workflow_id, owner_id)
    references public.workflow (id, owner_id) on delete set null (team_workflow_id)
);

-- Ordered by days: a checklist around a date is chronological.
create table public.event_workflow_step (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null default auth.uid()
    references auth.users on delete cascade,
  event_workflow_id uuid not null,
  label text not null check (length(trim(label)) > 0),
  -- From the event's day: -1 the day before, 0 the day of, 1 the day after.
  days int not null check (days between -365 and 365),
  note text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (id, owner_id),
  foreign key (event_workflow_id, owner_id)
    references public.event_workflow (id, owner_id) on delete cascade
);

create index event_workflow_step_event_workflow_id_owner_id_idx
  on public.event_workflow_step (event_workflow_id, owner_id);

-- The event's own copy: set from its event workflow when it is created,
-- changeable per event. Deleting the event workflow keeps the event and
-- its title, without a checklist.
alter table public.event
  add column event_workflow_id uuid,
  add column prospect_workflow_id uuid,
  add column customer_workflow_id uuid,
  add column team_workflow_id uuid,
  add foreign key (event_workflow_id, owner_id)
    references public.event_workflow (id, owner_id) on delete set null (event_workflow_id),
  add foreign key (prospect_workflow_id, owner_id)
    references public.workflow (id, owner_id) on delete set null (prospect_workflow_id),
  add foreign key (customer_workflow_id, owner_id)
    references public.workflow (id, owner_id) on delete set null (customer_workflow_id),
  add foreign key (team_workflow_id, owner_id)
    references public.workflow (id, owner_id) on delete set null (team_workflow_id);

create table public.event_step_done (
  event_id uuid not null,
  step_id uuid not null,
  owner_id uuid not null default auth.uid()
    references auth.users on delete cascade,
  done_on date not null,
  primary key (event_id, step_id),
  foreign key (event_id, owner_id)
    references public.event (id, owner_id) on delete cascade,
  foreign key (step_id, owner_id)
    references public.event_workflow_step (id, owner_id) on delete cascade
);

create trigger event_workflow_set_updated_at before update on public.event_workflow
  for each row execute function public.set_updated_at();
create trigger event_workflow_step_set_updated_at
  before update on public.event_workflow_step
  for each row execute function public.set_updated_at();

alter table public.event_workflow enable row level security;
alter table public.event_workflow_step enable row level security;
alter table public.event_step_done enable row level security;

create policy event_workflow_select_own on public.event_workflow
  for select to authenticated using (owner_id = (select auth.uid()));
create policy event_workflow_insert_own on public.event_workflow
  for insert to authenticated with check (owner_id = (select auth.uid()));
create policy event_workflow_update_own on public.event_workflow
  for update to authenticated
  using (owner_id = (select auth.uid()))
  with check (owner_id = (select auth.uid()));
create policy event_workflow_delete_own on public.event_workflow
  for delete to authenticated using (owner_id = (select auth.uid()));

create policy event_workflow_step_select_own on public.event_workflow_step
  for select to authenticated using (owner_id = (select auth.uid()));
create policy event_workflow_step_insert_own on public.event_workflow_step
  for insert to authenticated with check (owner_id = (select auth.uid()));
create policy event_workflow_step_update_own on public.event_workflow_step
  for update to authenticated
  using (owner_id = (select auth.uid()))
  with check (owner_id = (select auth.uid()));
create policy event_workflow_step_delete_own on public.event_workflow_step
  for delete to authenticated using (owner_id = (select auth.uid()));

create policy event_step_done_select_own on public.event_step_done
  for select to authenticated using (owner_id = (select auth.uid()));
create policy event_step_done_insert_own on public.event_step_done
  for insert to authenticated with check (owner_id = (select auth.uid()));
create policy event_step_done_update_own on public.event_step_done
  for update to authenticated
  using (owner_id = (select auth.uid()))
  with check (owner_id = (select auth.uid()));
create policy event_step_done_delete_own on public.event_step_done
  for delete to authenticated using (owner_id = (select auth.uid()));

revoke all on public.event_workflow, public.event_workflow_step,
  public.event_step_done from anon, authenticated;
grant select, insert, update, delete on public.event_workflow,
  public.event_workflow_step, public.event_step_done to authenticated;

create or replace function public.mark_event_done(
  p_event uuid, p_came uuid[], p_today date
) returns public.event
language plpgsql security invoker set search_path = '' as $$
declare
  marked public.event;
begin
  select * into marked from public.event where id = p_event for update;
  if not found then
    raise exception 'event % not found', p_event using errcode = 'P0002';
  end if;
  if marked.done_at is not null then
    raise exception 'event % is already done', p_event using errcode = 'P0001';
  end if;
  if exists (
    select 1 from unnest(p_came) as c(person_id)
    where not exists (
      select 1 from public.event_attendee a
      where a.event_id = p_event and a.person_id = c.person_id
    )
  ) then
    raise exception 'someone marked as there is not invited to event %', p_event
      using errcode = 'P0001';
  end if;

  update public.event_attendee
    set came = (person_id = any(p_came))
    where event_id = p_event;
  insert into public.activity (person_id, kind, text, happened_on)
    select a.person_id, 'event', marked.title, p_today
    from public.event_attendee a
    where a.event_id = p_event and a.came;
  -- Who was there starts the workflow for their stage, in place of the one
  -- they are on, from today; no mapping for their stage keeps theirs.
  update public.person p
    set workflow_id = mapped.workflow_id,
        at_position = coalesce(
          (select min(s.position) from public.workflow_step s
           where s.workflow_id = mapped.workflow_id),
          0),
        last_tick = p_today,
        paused_at = null
    from (
      select a.person_id,
             case pe.stage
               when 'prospect' then marked.prospect_workflow_id
               when 'customer' then marked.customer_workflow_id
               else marked.team_workflow_id
             end as workflow_id
      from public.event_attendee a
      join public.person pe on pe.id = a.person_id
      where a.event_id = p_event and a.came
    ) mapped
    where p.id = mapped.person_id and mapped.workflow_id is not null;
  update public.event set done_at = now()
    where id = p_event
    returning * into marked;
  return marked;
end $$;

revoke execute on function public.mark_event_done(uuid, uuid[], date)
  from public, anon;
grant execute on function public.mark_event_done(uuid, uuid[], date)
  to authenticated;

create or replace function public.seed_workflows(p_lang text, p_today date)
returns void
language plpgsql security invoker set search_path = '' as $$
declare
  fr constant boolean := p_lang = 'fr';
  w record;
  new_id uuid;
begin
  -- Two devices seeding at once: the second waits, then finds the marker.
  perform pg_advisory_xact_lock(hashtext((select auth.uid())::text));
  if exists (
    select 1 from public.workflow_seeded
    where owner_id = (select auth.uid())
  ) then
    return;
  end if;

  for w in
    select * from (values
      ('prospect'::public.person_stage, true,
       case when fr then 'Échantillons' else 'Samples' end,
       case when fr then
         '[["Envoyer un premier message",0],["Envoyer les échantillons",1],["Échantillons reçus",4],["Demander comment ça s''est passé",3],["Relancer",7]]'
       else
         '[["Send a first message",0],["Send the samples",1],["Samples arrived",4],["Ask how the samples went",3],["Follow up",7]]'
       end::jsonb),
      ('prospect', false,
       case when fr then 'Professionnels de santé' else 'Health professionals' end,
       case when fr then
         '[["Se présenter",0],["Partager une fiche produit",2],["Proposer un kit d''échantillons",5],["Relancer",7]]'
       else
         '[["Introduce yourself",0],["Share a product sheet",2],["Offer a sample kit",5],["Follow up",7]]'
       end::jsonb),
      ('customer', true,
       case when fr then 'Nouveau client' else 'New customer' end,
       case when fr then
         '[["Remercier pour la commande",0],["Commande reçue",5],["Prendre des nouvelles des produits",14],["Mettre en place un réassort régulier",21,true]]'
       else
         '[["Thank them for the order",0],["Order arrived",5],["Check in on the products",14],["Set up a refill routine",21,true]]'
       end::jsonb),
      ('customer', false,
       case when fr then 'Point réassort' else 'Refill check-in' end,
       case when fr then
         '[["Demander où en sont les réserves",25],["Aider pour la prochaine commande",3]]'
       else
         '[["Ask how supplies are going",25],["Help with the next order",3]]'
       end::jsonb),
      ('team', true,
       case when fr then 'Premiers pas' else 'Getting started' end,
       case when fr then
         '[["Appel de bienvenue",0],["Appel de déballage",5],["Première formation",3],["Premier objectif ensemble",7],["Point à deux semaines",14]]'
       else
         '[["Welcome call",0],["Unboxing call",5],["First training",3],["First goal together",7],["Two-week check-in",14]]'
       end::jsonb)
    ) as t(stage, is_default, name, steps)
  loop
    insert into public.workflow (stage, name, is_default)
      values (w.stage, w.name, w.is_default)
      returning id into new_id;
    insert into public.workflow_step (workflow_id, position, label, days, loyalty_setup)
      select new_id, s.ord, s.value ->> 0, (s.value ->> 1)::int,
             coalesce((s.value ->> 2)::boolean, false)
      from jsonb_array_elements(w.steps) with ordinality as s(value, ord);
  end loop;

  update public.person p
    set workflow_id = wf.id, at_position = 1, last_tick = p_today
    from public.workflow wf
    where wf.stage = p.stage and wf.is_default and p.workflow_id is null;

  -- Workshop: remind the day before, thank the day after; prospects and
  -- customers who were there start their stage's default.
  insert into public.event_workflow (name, prospect_workflow_id, customer_workflow_id)
    values (
      case when fr then 'Atelier' else 'Workshop' end,
      (select id from public.workflow where stage = 'prospect' and is_default),
      (select id from public.workflow where stage = 'customer' and is_default)
    )
    returning id into new_id;
  insert into public.event_workflow_step (event_workflow_id, label, days) values
    (new_id, case when fr then 'Rappeler à tout le monde que c''est demain'
                  else 'Remind everyone it''s tomorrow' end, -1),
    (new_id, case when fr then 'Envoyer un merci et les notes'
                  else 'Send a thank-you and the notes' end, 1);

  insert into public.workflow_seeded default values;
end $$;

revoke execute on function public.seed_workflows(text, date) from public, anon;
grant execute on function public.seed_workflows(text, date) to authenticated;

-- Accounts seeded before #153: Workshop once, in the language of their
-- seeded workflows, mapped to their current defaults (none: keep theirs).
with seeded as (
  select s.owner_id,
         exists (
           select 1 from public.workflow w
           where w.owner_id = s.owner_id
             and w.name in ('Échantillons', 'Nouveau client', 'Premiers pas')
         ) as fr
  from public.workflow_seeded s
  where not exists (
    select 1 from public.event_workflow e where e.owner_id = s.owner_id
  )
), created as (
  insert into public.event_workflow
    (owner_id, name, prospect_workflow_id, customer_workflow_id)
  select seeded.owner_id,
         case when seeded.fr then 'Atelier' else 'Workshop' end,
         (select w.id from public.workflow w
          where w.owner_id = seeded.owner_id and w.stage = 'prospect' and w.is_default),
         (select w.id from public.workflow w
          where w.owner_id = seeded.owner_id and w.stage = 'customer' and w.is_default)
  from seeded
  returning id, owner_id, name
)
insert into public.event_workflow_step (owner_id, event_workflow_id, label, days)
select c.owner_id, c.id, v.label, v.days
from created c
cross join lateral (values
  (case when c.name = 'Atelier' then 'Rappeler à tout le monde que c''est demain'
        else 'Remind everyone it''s tomorrow' end, -1),
  (case when c.name = 'Atelier' then 'Envoyer un merci et les notes'
        else 'Send a thank-you and the notes' end, 1)
) as v(label, days);

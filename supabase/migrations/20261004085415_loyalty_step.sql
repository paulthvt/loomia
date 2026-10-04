-- Loyalty setups (#140): a workflow step can count as one ("Counts as a
-- loyalty setup", an LRP for dōTERRA). Ticking it copies the flag onto the
-- step entry, so renaming or deleting the step keeps past counts. The
-- existing RLS and grants cover both columns.
alter table public.workflow_step
  add column loyalty_setup boolean not null default false;

alter table public.activity
  add column loyalty_setup boolean not null default false,
  add constraint loyalty_only_on_steps
    check (not loyalty_setup or kind = 'step');

create or replace function public.complete_step(p_person uuid, p_step uuid, p_on date)
returns public.person
language plpgsql security invoker set search_path = '' as $$
declare
  target public.person;
  step public.workflow_step;
  next_position numeric;
  moved public.person;
begin
  select * into target from public.person where id = p_person for update;
  if target.id is null
    or public.current_step_id(target) is distinct from p_step then
    raise exception 'step % is not the current step of person %', p_step, p_person
      using errcode = 'P0002';
  end if;

  select * into step from public.workflow_step where id = p_step;
  select coalesce(min(s.position), 1e9) into next_position
    from public.workflow_step s
    where s.workflow_id = step.workflow_id and s.position > step.position;

  insert into public.activity (person_id, kind, text, happened_on, loyalty_setup)
    values (p_person, 'step', step.label, p_on, step.loyalty_setup);
  update public.person
    set at_position = next_position, last_tick = p_on
    where id = p_person
    returning * into moved;
  return moved;
end $$;

revoke execute on function public.complete_step(uuid, uuid, date) from public, anon;
grant execute on function public.complete_step(uuid, uuid, date) to authenticated;

-- New customer ends on a loyalty step. "Suggest" became "Set up": ticking a
-- suggestion would count a setup that never happened. The third element of
-- a step marks it; absent is false.
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

  insert into public.workflow_seeded default values;
end $$;

revoke execute on function public.seed_workflows(text, date) from public, anon;
grant execute on function public.seed_workflows(text, date) to authenticated;

-- Accounts seeded before #140: their New customer workflow, if its last
-- step is still as seeded, gets the same loyalty step, renamed like the new
-- seed so a tick still means a setup. Past entries keep their text; steps
-- the user renamed or moved are left alone.
update public.workflow_step s
  set loyalty_setup = true,
      label = case s.label
        when 'Suggest a refill routine' then 'Set up a refill routine'
        else 'Mettre en place un réassort régulier'
      end
  from public.workflow w
  where w.id = s.workflow_id
    and w.stage = 'customer'
    and w.name in ('New customer', 'Nouveau client')
    and s.label in ('Suggest a refill routine', 'Proposer un réassort régulier')
    and s.position = (
      select max(last.position) from public.workflow_step last
      where last.workflow_id = s.workflow_id
    );

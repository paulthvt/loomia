-- Mentorat as a default event type (#483): its report fields, planned as
-- onboarding's step 4; the seeded team check-in workflows removed. New
-- accounts get it from seed_workflows, existing ones from backfill_mentorat.
-- Removing the check-ins deletes data (their steps and links, people's place
-- on them); the user accepted it. Their history stays. Task 8 of #483
-- verifies the released app tolerates it.

create or replace function public.seed_workflows(p_lang text, p_today date)
returns void
language plpgsql security invoker set search_path = '' as $$
declare
  fr constant boolean := p_lang = 'fr';
  workshop uuid;
  check_type uuid;
  unboxing uuid;
  consultation uuid;
  mentorat uuid;
  samples uuid;
  wellness uuid;
  invite uuid;
  w record;
  new_id uuid;
  ids jsonb := '{}';
begin
  -- Two devices seeding at once: the second waits, then finds the marker.
  perform pg_advisory_xact_lock(hashtext((select auth.uid())::text));
  if exists (
    select 1 from public.workflow_seeded
    where owner_id = (select auth.uid())
  ) then
    return;
  end if;

  -- Event types, each with its checklist around the event's day.
  insert into public.event_workflow (name, is_group)
    values (case when fr then 'Atelier' else 'Workshop' end, true)
    returning id into workshop;
  insert into public.event_workflow_step (event_workflow_id, label, days) values
    (workshop, case when fr then 'Rappel (J-3)' else 'Reminder (3 days before)' end, -3),
    (workshop, case when fr then 'Rappel (la veille)' else 'Reminder (the day before)' end, -1),
    (workshop, case when fr then 'Rappel (le matin)' else 'Reminder (the morning)' end, 0),
    (workshop, case when fr then 'Message de remerciement' else 'Thank-you message' end, 1);

  insert into public.event_workflow (name, is_group)
    values (case when fr then 'Bilan bien-être' else 'Wellness check' end, false)
    returning id into check_type;
  insert into public.event_workflow_step (event_workflow_id, label, days) values
    (check_type, case when fr then 'Rappel + préparer le rendez-vous'
                      else 'Reminder + prepare the appointment' end, -3),
    (check_type, case when fr then 'Rappel (la veille)' else 'Reminder (the day before)' end, -1),
    (check_type, case when fr then 'Rappel (le matin)' else 'Reminder (the morning)' end, 0);

  insert into public.event_workflow (name, is_group)
    values (case when fr then 'Appel d''unboxing' else 'Unboxing call' end, false)
    returning id into unboxing;
  insert into public.event_workflow (name, is_group)
    values (case when fr then 'Consultation bien-être' else 'Wellness consultation' end, false)
    returning id into consultation;
  insert into public.event_workflow (name, is_group, report_fields)
    values (case when fr then 'Mentorat' else 'Mentoring' end, false,
      case when fr then array['Sujets abordés',
        'Actions faites / en cours et prévues', 'Problématiques rencontrées',
        'À faire', 'Divers']
      else array['Topics covered', 'Actions done, in progress and planned',
        'Issues encountered', 'To do', 'Other'] end)
    returning id into mentorat;

  -- Workflows: [label, days, event type key or null, note or null].
  for w in
    select * from (values
      ('samples', 'prospect'::public.person_stage, true, false,
       case when fr then 'Échantillons' else 'Samples' end,
       case when fr then
         '[["Premier contact (proposition)",0],["Préparation et envoi",1],["Confirmation de réception",4],["Feedback",2],["Proposition de bilan bien-être ou atelier",0]]'
       else
         '[["First contact (offer)",0],["Prepare and send",1],["Check they arrived",4],["Ask for feedback",2],["Offer a wellness check or a workshop",0]]'
       end::jsonb),
      ('wellness', 'prospect', false, false,
       case when fr then 'Invitation bilan bien-être' else 'Wellness check invite' end,
       case when fr then
         '[["Proposer et caler le bilan",0,"check","Envoyer le questionnaire en même temps"]]'
       else
         '[["Offer and book the wellness check",0,"check","Send the questionnaire at the same time"]]'
       end::jsonb),
      ('invite', 'prospect', false, false,
       case when fr then 'Invitation atelier' else 'Workshop invite' end,
       case when fr then '[["Inviter à un atelier",0,"workshop"]]'
       else '[["Invite to a workshop",0,"workshop"]]' end::jsonb),
      ('customer', 'customer', true, false,
       case when fr then 'Nouveau client' else 'New customer' end,
       case when fr then
         '[["Caler l''appel d''unboxing",0,"unboxing"],["Donner l''accès aux groupes clients VIP",0],["Proposer une consultation bien-être",15,"consultation"]]'
       else
         '[["Book the unboxing call",0,"unboxing"],["Give access to the VIP customer groups",0],["Offer a wellness consultation",15,"consultation"]]'
       end::jsonb),
      ('onboarding', 'team', true, false,
       'Onboarding',
       case when fr then
         '[["Caler l''appel d''unboxing",0,"unboxing"],["Donner l''accès à la formation",0],["Proposer une consultation bien-être",7,"consultation"],["Planifier le mentorat",0,"mentorat"]]'
       else
         '[["Book the unboxing call",0,"unboxing"],["Give access to the training",0],["Offer a wellness consultation",7,"consultation"],["Plan the mentoring",0,"mentorat"]]'
       end::jsonb)
    ) as t(key, stage, is_default, repeats, name, steps)
  loop
    insert into public.workflow (stage, name, is_default, repeats)
      values (w.stage, w.name, w.is_default, w.repeats)
      returning id into new_id;
    ids := ids || jsonb_build_object(w.key, new_id);
    insert into public.workflow_step
      (workflow_id, position, label, days, event_workflow_id, note)
      select new_id, s.ord, s.value ->> 0, (s.value ->> 1)::int,
             case s.value ->> 2
               when 'workshop' then workshop
               when 'check' then check_type
               when 'unboxing' then unboxing
               when 'consultation' then consultation
               when 'mentorat' then mentorat
             end,
             s.value ->> 3
      from jsonb_array_elements(w.steps) with ordinality as s(value, ord);
  end loop;

  samples := (ids ->> 'samples')::uuid;
  wellness := (ids ->> 'wellness')::uuid;
  invite := (ids ->> 'invite')::uuid;
  insert into public.workflow_next (workflow_id, next_workflow_id) values
    (samples, wellness),
    (samples, invite),
    (invite, wellness);

  insert into public.workflow_seeded default values;
end $$;

revoke execute on function public.seed_workflows(text, date) from public, anon;
grant execute on function public.seed_workflows(text, date) to authenticated;

-- One already-seeded account. Workflows have no key: they are told by the
-- seeded names. Migration-only, so nobody can run it on another's account.
create function public.backfill_mentorat(p_owner uuid) returns void
language plpgsql security invoker set search_path = '' as $$
declare
  checkins constant text[] := array[
    'Suivi équipe — hebdo', 'Suivi équipe — toutes les 2 semaines',
    'Suivi équipe — mensuel', 'Team check-in — weekly',
    'Team check-in — every 2 weeks', 'Team check-in — monthly'];
  fr_names constant text[] := array[
    'Suivi équipe — hebdo', 'Suivi équipe — toutes les 2 semaines',
    'Suivi équipe — mensuel', 'Atelier', 'Bilan bien-être',
    'Appel d''unboxing', 'Consultation bien-être', 'Échantillons',
    'Nouveau client'];
  fr boolean;
  mentorat uuid;
begin
  fr := exists (
      select 1 from public.workflow
      where owner_id = p_owner and name = any(fr_names))
    or exists (
      select 1 from public.event_workflow
      where owner_id = p_owner and name = any(fr_names))
    or exists (
      select 1 from public.workflow_step
      where owner_id = p_owner and label = 'Caler l''appel d''unboxing');

  -- Nobody stays at a position, or paused, on nothing; the delete then sets
  -- their workflow_id to null and takes the steps and links.
  update public.person p
    set at_position = null, last_tick = null, paused_at = null
    from public.workflow w
    where w.id = p.workflow_id and w.owner_id = p_owner
      and w.stage = 'team' and w.repeats and w.name = any(checkins);
  delete from public.workflow
    where owner_id = p_owner and stage = 'team' and repeats
      and name = any(checkins);

  -- Already there (a second run, or the user's own): nothing more. A step
  -- pointing at a Mentorat type implies one, so onboarding is left too.
  if exists (
    select 1 from public.event_workflow
    where owner_id = p_owner and name in ('Mentorat', 'Mentoring')
  ) then
    return;
  end if;

  insert into public.event_workflow (owner_id, name, is_group, report_fields)
    values (p_owner, case when fr then 'Mentorat' else 'Mentoring' end, false,
      case when fr then array['Sujets abordés',
        'Actions faites / en cours et prévues', 'Problématiques rencontrées',
        'À faire', 'Divers']
      else array['Topics covered', 'Actions done, in progress and planned',
        'Issues encountered', 'To do', 'Other'] end)
    returning id into mentorat;

  -- After the last real step: someone done is parked at 1e9 and stays done.
  insert into public.workflow_step
    (owner_id, workflow_id, position, label, days, event_workflow_id)
    select p_owner, w.id,
           coalesce((select max(s.position) from public.workflow_step s
                     where s.workflow_id = w.id), 0) + 1,
           case when fr then 'Planifier le mentorat' else 'Plan the mentoring' end,
           0, mentorat
    from public.workflow w
    where w.owner_id = p_owner and w.stage = 'team' and w.name = 'Onboarding';
end $$;

revoke execute on function public.backfill_mentorat(uuid)
  from public, anon, authenticated;

select public.backfill_mentorat(owner_id) from public.workflow_seeded;

-- New defaults and account reset (#319, last of #313). seed_workflows now
-- seeds the workflows a dōTERRA wellness advocate wrote down (spec §2):
-- event types first, then workflows with their event steps, then what comes
-- next after each. It no longer places anyone on a workflow: it existed for
-- people created before #59. Then every account is reset: its workflows,
-- event types and seeded marker go, so the app seeds the new ones on its
-- next load, in the device's language. People, history, orders, LRPs and
-- events stay; nobody is left on a workflow; events lose their type.
-- Agreed for the two accounts that exist (spec Decisions → Existing
-- accounts). Same seed_workflows signature: every build calls it alike.

create or replace function public.seed_workflows(p_lang text, p_today date)
returns void
language plpgsql security invoker set search_path = '' as $$
declare
  fr constant boolean := p_lang = 'fr';
  workshop uuid;
  check_type uuid;
  unboxing uuid;
  consultation uuid;
  samples uuid;
  wellness uuid;
  invite uuid;
  onboarding uuid;
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
       case when fr then 'Bilan bien-être' else 'Wellness check' end,
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
         '[["Caler l''appel d''unboxing",0,"unboxing"],["Donner l''accès à la formation",0],["Proposer une consultation bien-être",7,"consultation"]]'
       else
         '[["Book the unboxing call",0,"unboxing"],["Give access to the training",0],["Offer a wellness consultation",7,"consultation"]]'
       end::jsonb),
      ('weekly', 'team', false, true,
       case when fr then 'Suivi équipe — hebdo' else 'Team check-in — weekly' end,
       case when fr then '[["Point",7]]' else '[["Check-in",7]]' end::jsonb),
      ('fortnightly', 'team', false, true,
       case when fr then 'Suivi équipe — toutes les 2 semaines'
            else 'Team check-in — every 2 weeks' end,
       case when fr then '[["Point",14]]' else '[["Check-in",14]]' end::jsonb),
      ('monthly', 'team', false, true,
       case when fr then 'Suivi équipe — mensuel' else 'Team check-in — monthly' end,
       case when fr then '[["Point",30]]' else '[["Check-in",30]]' end::jsonb)
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
             end,
             s.value ->> 3
      from jsonb_array_elements(w.steps) with ordinality as s(value, ord);
  end loop;

  samples := (ids ->> 'samples')::uuid;
  wellness := (ids ->> 'wellness')::uuid;
  invite := (ids ->> 'invite')::uuid;
  onboarding := (ids ->> 'onboarding')::uuid;
  insert into public.workflow_next (workflow_id, next_workflow_id) values
    (samples, wellness),
    (samples, invite),
    (invite, wellness),
    (onboarding, (ids ->> 'weekly')::uuid),
    (onboarding, (ids ->> 'fortnightly')::uuid),
    (onboarding, (ids ->> 'monthly')::uuid);

  insert into public.workflow_seeded default values;
end $$;

-- The reset. Deleting a workflow sets people's workflow_id to null and takes
-- its steps and links; deleting an event type takes its checklist and the
-- ticks, and leaves its events untyped. Nobody stays paused on nothing.
delete from public.workflow_seeded;
delete from public.event_workflow;
delete from public.workflow;
update public.person
  set at_position = null, last_tick = null, paused_at = null
  where workflow_id is null
    and (at_position is not null or last_tick is not null or paused_at is not null);

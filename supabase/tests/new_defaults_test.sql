-- New defaults (#319): what seed_workflows creates, as spec §2 lists it.
-- Run with `supabase test db`.
begin;
create extension if not exists pgtap with schema extensions;
select plan(10);

insert into auth.users (id, email) values
  ('00000000-0000-0000-0000-00000000000a', 'a@example.com'),
  ('00000000-0000-0000-0000-00000000000b', 'b@example.com');

set local role authenticated;
set local request.jwt.claims =
  '{"sub": "00000000-0000-0000-0000-00000000000a", "role": "authenticated"}';

select public.seed_workflows('en', '2026-10-15');

-- 1-2: event types and their checklists.
select results_eq(
  $$ select name, is_group,
            (select count(*)::int from public.event_workflow_step s
              where s.event_workflow_id = w.id)
     from public.event_workflow w order by name $$,
  $$ values ('Unboxing call', false, 0), ('Wellness check', false, 3),
            ('Wellness consultation', false, 0), ('Workshop', true, 4) $$,
  'four event types: one group, three for one person'
);
select results_eq(
  $$ select s.label, s.days from public.event_workflow_step s
     join public.event_workflow w on w.id = s.event_workflow_id
     where w.name = 'Workshop' order by s.days $$,
  $$ values ('Reminder (3 days before)', -3), ('Reminder (the day before)', -1),
            ('Reminder (the morning)', 0), ('Thank-you message', 1) $$,
  'Workshop: three reminders, then the thank-you the next morning'
);

-- 3-5: workflows.
select results_eq(
  $$ select stage::text, name, is_default, repeats from public.workflow
     order by array_position(array['prospect', 'customer', 'team'], stage::text),
              name $$,
  $$ values ('prospect', 'Samples', true, false),
            ('prospect', 'Wellness check', false, false),
            ('prospect', 'Workshop invite', false, false),
            ('customer', 'New customer', true, false),
            ('team', 'Onboarding', true, false),
            ('team', 'Team check-in — every 2 weeks', false, true),
            ('team', 'Team check-in — monthly', false, true),
            ('team', 'Team check-in — weekly', false, true) $$,
  'the eight workflows, one default per stage, the check-ins repeat'
);
select results_eq(
  $$ select s.position, s.label, s.days from public.workflow_step s
     join public.workflow w on w.id = s.workflow_id
     where w.name = 'Samples' order by s.position $$,
  $$ values (1::numeric, 'First contact (offer)', 0),
            (2::numeric, 'Prepare and send', 1),
            (3::numeric, 'Check they arrived', 4),
            (4::numeric, 'Ask for feedback', 2),
            (5::numeric, 'Offer a wellness check or a workshop', 0) $$,
  'Samples: feedback two days after they arrived'
);
select results_eq(
  $$ select s.label, s.days, e.name from public.workflow_step s
     join public.workflow w on w.id = s.workflow_id
     left join public.event_workflow e on e.id = s.event_workflow_id
     where w.name = 'New customer' order by s.position $$,
  $$ values ('Book the unboxing call', 0, 'Unboxing call'),
            ('Give access to the VIP customer groups', 0, null),
            ('Offer a wellness consultation', 15, 'Wellness consultation') $$,
  'New customer: two event steps around the access'
);

-- 6: the bilan's note.
select is(
  (select s.note from public.workflow_step s
     join public.workflow w on w.id = s.workflow_id
     where w.name = 'Wellness check'),
  'Send the questionnaire at the same time',
  'the questionnaire goes when the bilan is booked'
);

-- 7: what comes next.
select results_eq(
  $$ select f.name, t.name from public.workflow_next n
     join public.workflow f on f.id = n.workflow_id
     join public.workflow t on t.id = n.next_workflow_id
     order by f.name, t.name $$,
  $$ values ('Onboarding', 'Team check-in — every 2 weeks'),
            ('Onboarding', 'Team check-in — monthly'),
            ('Onboarding', 'Team check-in — weekly'),
            ('Samples', 'Wellness check'),
            ('Samples', 'Workshop invite'),
            ('Workshop invite', 'Wellness check') $$,
  'Samples and Workshop invite lead on; Onboarding to a check-in'
);

-- 8: no loyalty step: What's next asks.
select is(
  (select count(*)::int from public.workflow_step where loyalty_setup), 0,
  'no loyalty step'
);

-- 9-10: in French, for B.
set local request.jwt.claims =
  '{"sub": "00000000-0000-0000-0000-00000000000b", "role": "authenticated"}';
select public.seed_workflows('fr', '2026-10-15');
select results_eq(
  $$ select name from public.workflow order by name $$,
  $$ select unnest(array['Bilan bien-être', 'Échantillons', 'Invitation atelier',
            'Nouveau client', 'Onboarding', 'Suivi équipe — hebdo',
            'Suivi équipe — mensuel', 'Suivi équipe — toutes les 2 semaines'])
     order by 1 $$,
  'the French names'
);
select results_eq(
  $$ select s.label from public.event_workflow_step s
     join public.event_workflow w on w.id = s.event_workflow_id
     where w.name = 'Atelier' order by s.days $$,
  $$ values ('Rappel (J-3)'), ('Rappel (la veille)'), ('Rappel (le matin)'),
            ('Message de remerciement') $$,
  'the French checklist'
);

select * from finish();
rollback;

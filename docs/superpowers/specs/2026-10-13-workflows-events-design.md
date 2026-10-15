# Workflows and events, linked — design

Epic: #313 (sub-issues #314–#319, §7). Figma: section "Workflows & events — #313"
(node 358:8961) on page "04 — Screens (Light)". Builds on
`2026-09-29-workflows-design.md`, `2026-10-07-calendar-design.md` and
`2026-10-12-repeating-workflows-design.md`; their decisions hold unless a
row below replaces one.

## Intent

The seeded workflows came from guesses. A dōTERRA wellness advocate wrote
down how she actually works, and her follow-ups keep crossing the calendar:
samples end with a wellness check or a workshop, a new customer's first
weeks are an unboxing call and a consultation, a workshop's guests each
leave with a different next step. Today a workflow and an event only meet
in `mark_event_done`, which replaces the workflow of everyone who came.

This epic links them in three places and replaces the defaults with hers:

1. **A workflow step can be an event.** "Book the unboxing call" comes due,
   the user plans the event from it, the step waits, and the event being
   done with the person there ticks it.
2. **A workflow that ends asks what's next**, from options set on the
   workflow (and, for a customer, whether they started an LRP).
3. **After an event, each person who came records what changed**: became a
   customer (with the registration order) or placed an order. Their event
   step, if this event was it, moves on by itself. The stage → workflow
   mapping on event types goes: what a guest does next comes from the
   workflow that brought them (link 2), not from the event.

The rule that holds it together: **a person is on one workflow at a
time.** Everything that is about an event rather than about the person
(invitations, reminders, the thank-you) belongs to the event, so inviting a
customer to a workshop never takes them off their workflow.

The scenarios she validated (French, as shared with her) are summarised in
§6; her answers are folded into the decisions below.

## Decisions

| Question | Decision |
| --- | --- |
| One workflow per person | Kept. An event never replaces a workflow; only "Became a customer" starts one. Her "Invitation évènement" workflow (first contact, follow-up after 3 days) becomes the event's invitation status (#314), not a person workflow. |
| Event step | `workflow_step.event_workflow_id`, nullable. A step with an event type is an event step: its label is the to-do ("Book the unboxing call"), its type is what gets planned. |
| When an event step is due | Like any step: `last_tick + days`. It leaves Today once the person is attending an open event of that type (*planned*), and comes back when that event is done without them (*missed*: "Book again"). |
| Planned | Computed, not stored: an `event_attendee` row for the person on an event with `done_at is null` and the step's `event_workflow_id`. No link table. |
| Ticking an event step | Not by hand. `mark_event_done` with the person there moves them past it. One history entry, the event's; no extra step entry. |
| Proposed date | Today + 7 days at 19:00, editable. Her unboxing is "7 days after"; one default for every type until another number is needed. `ponytail:` in the plan sheet. |
| "Later" | On a due event step, "Later" picks a day (default +3); `postpone_step` sets `last_tick = day − days`. Only event steps for now (her consultation). |
| Group or individual | `event_workflow.is_group`. Group (Workshop): planning offers the upcoming events of that type or a new one, and attendees start *invited*. Individual (Wellness check, Unboxing, Consultation): planning always creates a new event with the person *going*. |
| Invitation | `event_attendee.going boolean`, `invited_on date`, `followed_up_on date`. Not going 3 days after `invited_on` (or after `followed_up_on`) and the event not started: Today shows "Follow up Marc about Workshop". `ponytail:` 3 days hard-coded. Reminders and the thank-you are group checklist steps, not per guest. |
| What's next | `workflow_next (workflow_id, next_workflow_id, position)`, same stage. A finished workflow with next options shows "What's next for Sophie?" on Today until answered; answering sets the next workflow or none. Without options nothing asks, as today (Bilan: "on s'arrête là"). Repeating workflows never finish. |
| LRP question | A customer whose workflow finishes with no `loyalty_since` is asked "Did Julie start an LRP?" in the same sheet. Yes: `set_loyalty` and the LRP day. Replaces the seeded `loyalty_setup` step; the flag stays for users' own workflows. |
| LRP follow-up | Not a workflow: it is anchored to a date and must not take the person's one workflow. `person.loyalty_day smallint` (1–28), defaulting to `loyalty_since`'s day. 3 days before each renewal, Today shows "Julie's LRP renews on the 15th"; ticking writes a `loyalty_check` activity and `loyalty_checked_for` = that renewal. Unticked, it drops off after the renewal day. |
| After an event | "Who was there?" records what changed for each person who came. Prospect: "Became a customer?"; yes takes the registration order (amount optional) and starts the customer default. Customer or team: an optional order with amount. Someone whose current step is an event step of this type moves past it, shown as "Continues New customer → Give VIP group access". Nobody else's workflow changes. One transaction. |
| Stage → workflow mapping on event types | Dropped (it was #153's "After the event"). Her only case, "not a customer after the workshop → wellness check", is Workshop invite's What's next. A prospect invited straight from the event page, outside that workflow, gets no suggestion; Change workflow on the contact does it. The six `*_workflow_id` columns on `event_workflow`, `event` and `event_series` go, with the editor section, the event form block, the event page's "After the event" and `thereSummary`. |
| Absent from a group event | "Invite to the next one" (on by default) when an upcoming open event of the same type exists; adds them as invited. Hidden otherwise. A person absent from their event step gets "Book again" through the step. |
| Became a customer elsewhere | The stage sheet's Customer path also asks for the registration order (optional amount): `became_customer` RPC, shared with `mark_event_done`. |
| Seeded defaults | Hers, §2. "Health professionals" and "Refill check-in" are removed. |
| Team check-in cadence | Three seeded repeating workflows, weekly / every 2 weeks / monthly; "custom" is a new workflow in Settings. No per-person cadence until those copies multiply. |
| Morning reminder | Day 0 checklist step, on Today from the morning. No timed push (later). |
| Existing accounts | One migration deletes every workflow, event workflow and `workflow_seeded` row; the app reseeds on next load in the device language. People, history, orders, LRP and events stay; nobody is placed on a workflow; events lose their type. Two accounts, agreed. |
| Seeding places people | No longer. `seed_workflows` stops moving people with no workflow onto the defaults; it existed for people created before #59. |
| Today's "to mark" | Events with a type and attendees (was: with a stage mapping, which is gone). |
| Push count | `due_people_count` counts a person with a due step, reminder, invitation follow-up, LRP renewal or What's next. Same rule as Today's people list. |

## 1. Data

All in migrations from `supabase migration new`, conventions as in
`docs/architecture.md` → Backend.

### Event types (#314)

- `event_workflow.is_group boolean not null default true`.
- `event_attendee`: `going boolean not null default false`, `invited_on date
  not null default current_date` (the client sends its today; the default
  only covers existing rows), `followed_up_on date`. Existing rows:
  `going = true`.
- RPCs `set_going(event, person, bool)`, `follow_up_invite(event, person,
  day)`. Insert sets `going = not is_group` for typed events, `true` for
  plain ones.

### Event steps (#315)

- `workflow_step.event_workflow_id uuid`, composite FK `on delete set null`
  (the step becomes a plain step).
- `planned_event_id(p person) returns uuid`: the open event of the current
  step's type that the person attends, earliest `starts_at`.
- `due_on(p)`: null also while `planned_event_id(p)` is not null.
- `postpone_step(p_person, p_step, p_until date)`: refuses a step that is not
  current or not an event step; `last_tick = p_until − days`.
- The Dart fake `test/features/workflows/server_rule.dart` follows both.

### What's next (#316)

- `workflow_next`: `workflow_id`, `next_workflow_id` (both composite FKs,
  cascade), `position int`, `owner_id`; primary key `(workflow_id,
  next_workflow_id)`. A trigger refuses a different stage. RLS, owner
  policies, revoke then grants, pgTAP.
- `needs_next(p person) returns boolean`: workflow set, not repeating,
  `current_step_id` null, and (`workflow_next` has a row or stage is
  customer with `loyalty_since` null).
- Answering: the existing person update (workflow, position, last tick),
  or `workflow_id = null` for "Nothing for now".

### LRP (#317)

- `person.loyalty_day smallint check (loyalty_day between 1 and 28)`,
  `loyalty_checked_for date`. `set_loyalty` fills `loyalty_day` from
  `p_since` (capped at 28) when it is null, clears it on stop.
- `activity_kind` gains `'loyalty_check'`, app-writable like `'step'`.
- `loyalty_renewal_on(p person, p_on date) returns date`: the next date on
  or after `p_on` with day `loyalty_day`; due when `p_on >= renewal − 3` and
  `loyalty_checked_for` is distinct from it.
- `check_loyalty(p_person, p_renewal, p_on)`: the activity and
  `loyalty_checked_for`, one transaction.

### Outcomes (#318)

- `became_customer(p_person, p_amount numeric, p_text text, p_today date)`:
  stage to customer (the existing trigger logs it), an `'order'` activity
  (amount or text, as the table already requires), the customer default
  workflow from its first step, today.
- `mark_event_done(p_event uuid, p_there jsonb, p_absent_invite uuid[],
  p_today date)` replaces the current one. `p_there`: one object per person
  who came, `{person, customer, amount, text}`; `customer` true only for a
  prospect, `amount`/`text` an optional order. Per person, in order:
  1. the `'event'` activity;
  2. if their current step is an event step of this event's type, they move
     past it (same position rule as `complete_step`, no second entry);
  3. `customer` → `became_customer`, which takes the order; otherwise the
     optional order alone.

  Step 2 runs before step 3, so someone on Workshop invite who becomes a
  customer finishes it and then starts New customer. `p_absent_invite`:
  absent attendees, added as invited to the next open event of the same
  type. Then `done_at`. The old signature is dropped.
- The same migration drops `prospect_workflow_id`, `customer_workflow_id`
  and `team_workflow_id` from `event_workflow`, `event` and `event_series`,
  and `extend_event_series` stops copying them.

### Seeding and reset (#319)

`seed_workflows` rewritten with §2, without placing people. The migration:

```sql
delete from public.workflow_seeded;
delete from public.event_workflow;  -- steps, step_done cascade; events keep, type null
delete from public.workflow;        -- steps, workflow_next cascade; person.workflow_id null
```

## 2. Seeded defaults

Days are each step's wait after the previous tick. ⟨T⟩ marks an event step
of type T.

**Prospect**

| Workflow | Steps (days) | Next |
| --- | --- | --- |
| Échantillons / Samples (default) | Premier contact (proposition) 0 · Préparation et envoi 1 · Confirmation de réception 4 · Feedback 2 · Proposition de bilan bien-être ou atelier 0 | Invitation bilan bien-être, Invitation atelier |
| Invitation bilan bien-être / Wellness check invite (#340) | Proposer et caler le bilan 0 ⟨Bilan⟩, note "Envoyer le questionnaire en même temps" | — |
| Invitation atelier / Workshop invite | Inviter à un atelier 0 ⟨Atelier⟩ | Invitation bilan bien-être |

**Customer**

| Workflow | Steps (days) | Next |
| --- | --- | --- |
| Nouveau client / New customer (default) | Caler l'appel d'unboxing 0 ⟨Unboxing⟩ · Donner l'accès aux groupes clients VIP 0 · Proposer une consultation bien-être 15 ⟨Consultation⟩ | LRP question |

**Team**

| Workflow | Steps (days) | Next |
| --- | --- | --- |
| Onboarding (default) | Caler l'appel d'unboxing 0 ⟨Unboxing⟩ · Donner l'accès à la formation 0 · Proposer une consultation bien-être 7 ⟨Consultation⟩ | the three below |
| Suivi équipe — hebdo / Team check-in — weekly | Point 7, repeats | — |
| Suivi équipe — toutes les 2 semaines / every 2 weeks | Point 14, repeats | — |
| Suivi équipe — mensuel / monthly | Point 30, repeats | — |

**Event types**

| Type | Group | Checklist (days from the event) |
| --- | --- | --- |
| Atelier / Workshop | yes | Rappel (J-3) −3 · Rappel (la veille) −1 · Rappel (le matin) 0 · Message de remerciement +1 |
| Bilan bien-être / Wellness check | no | Rappel + préparer le rendez-vous −3 · Rappel (la veille) −1 · Rappel (le matin) 0 |
| Appel d'unboxing / Unboxing call | no | — |
| Consultation bien-être / Wellness consultation | no | — |

English labels are translations of hers, for English accounts.

## 3. Domain (Dart)

- `lib/features/workflows/domain/progress.dart`: `progressOf` gains
  `ToPlan(step, due, missed)` and `Planned(step, event)` for event steps;
  `Done` gains `needsNext`.
- `lib/features/calendar/domain/`: `inviteFollowUps(events, today)`;
  `continues(person, event, workflows)`, the step a person moves to (or
  Done) when this event is their current event step, for the sheet's line;
  `nextOfType(events, event)` for the absent invite. `thereSummary` and
  `followUps` are deleted.
- `lib/features/contacts/domain/`: `loyaltyRenewal(person, today)`, the Dart
  side of `loyalty_renewal_on`, pinned by the same cases.
- `lib/features/today/domain/due.dart`: `Due` gains `DueToPlan`,
  `DueFollowUp`, `DueLoyalty`, `DueNext`, same ordering rules.

## 4. Behaviour by screen

### Today

People list, in the existing order by day then name:

- **To plan** — "Book the unboxing call · Julie", or "Book again" when
  missed. Plan opens the plan sheet; Later picks a day.
- **Follow up** — "Follow up Marc about Workshop · Thu 20". Going, Followed
  up, Remove.
- **LRP** — "Julie's LRP renews on the 15th". The ring ticks it.
- **What's next** — "What's next for Sophie?" opens the sheet.

Events section: unchanged, with the to-mark rule above.

### Plan sheet

From a to-plan row or the contact's next step. Individual type: the event
form, type set, title "Wellness check — Sophie", today + 7 at 19:00, the
person going. Group type: the upcoming open events of that type ("Huiles et
sommeil · Thu 20 · 6 invited") and New workshop; picking adds them invited.

### What's next sheet

Radio list of the workflow's next options and "Nothing for now". For a
customer without an LRP, first: "Did Julie start an LRP?" Yes shows the day
of the month (1–28, default today's day, capped).

### Who was there

Each attendee: there / not there. There, prospect: "Became a customer?"
and, if yes, the registration order amount and "Starts New customer". There, customer or team: an
optional order amount. Under anyone on an event step of this type:
"Continues New customer → Give VIP group access" (or "Finishes Workshop
invite"), read-only. No workflow picker. Not there, group type, next event
exists: "Invite to Huiles et sommeil · Thu 3" switch. One Done.

### Event page

Attendees show Invited / Going; the row menu sets Going and Followed up.
Done: Was there / Missed it, as today. The "After the event" block goes, on
the page and in the event form.

### Contact page

The NEXT STEP card: to plan (Plan, Later), planned ("Unboxing call · Tue
19:00", opens the event), missed. The LRP row shows the renewal day,
editable. The Customer path of Change stage asks for the registration
order.

### Settings

Workflow editor: a step's "Event" picker (none or a type); a "What's next"
section (same-stage workflows, reorderable). Event type editor: "Several
people" switch (`is_group`); its per-stage "After the event" pickers go.

## 5. Figma

New patterns to mock, mobile and desktop: the plan sheet (individual and
group), Today's four new row kinds, the What's next sheet with the LRP
question, the reworked Who was there, attendee statuses on the event page,
the NEXT STEP card's planned and to-plan states, and the two editor
additions. Copy from §6.

## 6. Scenarios (validated)

1. **Samples:** five steps (0, 1, 4, 2, 0 days); the last is in reply to
   her feedback. What's next: Wellness check, Workshop invite, nothing.
2. **Workshop:** created from the calendar or from Workshop invite; guests
   invited, 3-day follow-up, Going; J-3, day before and morning reminders,
   thank-you the next morning, all group tasks. Who was there: prospects
   "became a customer?" (registration order, New customer); the others
   finish Workshop invite, whose What's next offers Wellness check; customers
   an optional order; absent guests invited to the next workshop.
3. **Wellness check:** booked once the prospect replied with a slot, the
   questionnaire sent then. J-3 reminder and preparation, day before,
   morning. After: became a customer or stop. No thank-you step. Missed:
   book again.
4. **New customer:** starts with the registration order. Book the unboxing
   call (proposed +7); after it, give VIP group access by message; 15 days
   later propose a consultation (Later if they want to wait); after it, the
   LRP question.
5. **LRP:** a reminder 3 days before the monthly renewal, alongside any
   workflow.
6. **Team:** same shape as New customer with training access and 7 days;
   then weekly, every 2 weeks, monthly or a custom check-in.
7. **Update:** new defaults, nothing lost, nobody placed, events untyped.

## 7. Delivery

| PR | Scope |
| --- | --- |
| #314 | `is_group`, invitation status and follow-up on Today and the event page. |
| #315 | Event steps: column, planned / missed / due rules, plan sheet, Later, editor picker, NEXT STEP states. |
| #316 | `workflow_next`, What's next on Today and its sheet, the LRP question. |
| #317 | LRP day and the renewal reminder. |
| #318 | `became_customer`, the new `mark_event_done`, Who was there, and the stage mapping removed (columns, form, page, editor). |
| #319 | The new defaults and the reset migration, last, once the rest is live. |

`due_people_count` and the fake follow each PR that adds a due kind.

## 8. Testing

- SQL: `planned_event_id` and `due_on` (to plan, planned, missed, another
  type does not count); `postpone_step` refusals; `workflow_next` stage
  trigger and RLS; `needs_next`; `loyalty_renewal_on` (before, on, after the
  day, Feb with day 28, already checked); `became_customer`;
  `mark_event_done` (event step moves on, other workflows untouched, became
  a customer after finishing Workshop invite, order alone, absent invite,
  one transaction); the reset leaves people and events; `due_people_count`
  with each kind.
- Unit: `progressOf` new states, `continues`, `inviteFollowUps`,
  `loyaltyRenewal`, `dueToday` ordering with the new kinds.
- Widget: each Today row, the plan sheet both ways, What's next with and
  without the LRP question, Who was there per stage, the editor additions.
- Goldens: one per new `@Preview`, regenerated through CI.

## Out of scope

Timed pushes for morning reminders, several workflows per person, a
per-person check-in cadence, proposed dates per event type, undoing a done
event, per-guest reminders.

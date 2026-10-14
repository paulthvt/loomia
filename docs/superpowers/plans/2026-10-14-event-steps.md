# Event Steps Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A workflow step can be an event step (#315, part of #313).
- **Due:** it comes due like any step. On Today and on the NEXT STEP card it shows Plan and Later instead of the ring.
- **Plan:**
  - for an individual type, it opens the event form prefilled with the person going;
  - for a group type, it offers the upcoming events of that type or a new one, with the person invited.
- **Waiting:** while the person attends an open event of the step's type, the step waits. It is hidden from Today, and the card shows the event.
- **After the event:**
  - marked done with them there, they move past the step;
  - marked done without them, it is due again: "Book again".
- **Later:** pushes the step to a chosen day.

**Architecture:** One migration:
- adds `workflow_step.event_workflow_id`;
- adds the computed field `planned_event_id(person)`;
- replaces `due_on`, adding "null while planned";
- extracts the next-position rule into `position_after(step)`, which `complete_step` and `mark_event_done` both use;
- adds `postpone_step`.

`mark_event_done` keeps its signature. It gains one thing: people who came, whose current step is an event step of this event's type, move past it. That is the only part of #318's outcome work this issue needs, because without it an unboxing call done with the person there would come back as "Book the unboxing call".

Dart side:
- `Person` gains `plannedEventId`;
- `progressOf` gains `Planned`;
- `missedEvent` finds the event someone missed;
- a plan sheet in `calendar/presentation`, and `showEventForm` gains a prefill;
- the step sheet gets an Event picker;
- Today and the card use `ActionItem.actions` (#314) for Plan / Later.

**Tech Stack:** Flutter (`material_ui`), `flutter_riverpod` 3, Supabase (Postgres, pgTAP).

**Spec:** `docs/superpowers/specs/2026-10-13-workflows-events-design.md` (Decisions: Event step, When an event step is due, Planned, Ticking an event step, Proposed date, Later, Group or individual; §1 Event steps; §4 Today, Plan sheet, Contact page, Settings). Figma: [Workflows & events — #313](https://www.figma.com/design/spz2vsSK8gbt1Ok2rW1sdQ/Loomia?node-id=358-8961), frames:
- "Today — new rows" (to plan, missed);
- "Plan sheet — individual" and "Plan sheet — group";
- "NEXT STEP card — states";
- "Edit step sheet — event step".

## Global Constraints

- One migration, `supabase migration new event_steps`. Never edit an applied one.
- **Database:** `supabase db push` after merge, before the app release. The released app keeps working:
  - every change is additive or a same-signature `create or replace`;
  - a planned person's `due_on` is null, which the released app reads as "no step due".
- No new dependency. Stage only changed files by path.
- Rules live in Postgres (`due_on`, `planned_event_id`, `position_after`). `test/features/workflows/server_rule.dart` is the only Dart copy, for the fakes.
- Dart: `package:loomia/...` imports; Material from `package:material_ui/material_ui.dart`. Theme values only. `FilledButton.tonal` takes `style: AppTheme.tonal(context)`. Async handlers read `ref` / `context` / the `ScaffoldMessenger` before the first `await`.
- Copy: English only, in `lib/l10n/app_en.arb`, every key with a description; `flutter gen-l10n`.
- Quality gate: `dart format .`, `flutter analyze` ("No issues found!"), `flutter test`, `supabase test db`. Goldens through CI.
- Branch `feature/315-event-steps`; PR body `Closes #315`, with the template's Database section filled.

## Rulings made while planning

- **Moving past the event step lands here, not in #318.** It is a same-signature change to `mark_event_done`, and without it the feature reads wrong. #318 keeps became-a-customer, orders, the absent invite and dropping the mapping. In this PR the existing stage mapping still applies after the move, so a mapped workflow wins, as it does today.
- **`position_after(p_step uuid)`** is the next-position rule, extracted from `complete_step` so both callers agree. `complete_step` is replaced to call it, with no change in behaviour (`repeating_workflows_test.sql` pins it).
- **Planned is computed, not stored.** `planned_event_id(p)` is the earliest open event of the current step's type that the person attends. Invited counts as planned too: the invitation follow-up (#314) carries them from there.
- **Missed is display only.** `missedEvent(person, step, events)` in `calendar/domain` is the latest done event of that type that the person attended without coming, on or after their `last_tick`. It changes the copy ("Book again · missed Huiles et sommeil on Tue"), never the due day.
- **Later goes through `postpone_step(p_person, p_step, p_until)`**, which sets `last_tick = p_until − days` and refuses a step that isn't current or isn't an event step (P0002, P0001). The date picker defaults to today + 3, from tomorrow to a year out.
- **The proposed date is today + 7 at 19:00** for every type, the spec's ponytail. `showEventForm` gains `type`, `title` and `day` for a new event.
- **Planning a new event is two writes**: `add`, then `invite`. If the invite fails, the event stays, a SnackBar says so, and the step stays to plan. The user can add the person from the event page. Ponytail comment: make it one RPC if this ever loses someone.
- **After planning, people reload** (`ref.invalidate(peopleProvider(owner))`): `due_on` and `planned_event_id` come from the server.
- **The step sheet's Event picker** is a `DropdownButton<String?>` row, like `FollowUpPicker`: "None" plus the event types. Event types still loading show the row disabled.
- **`OnStep` gains `bool get isEvent`**, and `Planned` is a new `WorkflowProgress` holding the workflow, step, index, total and event id. `Planned` is exhaustive in the card. The timeline page's wildcard covers it. `change_stage_sheet` treats `Planned` like `OnStep` ("the workflow ends here").
- **Fakes:** `FakePeopleRepository.plannedEvents` (person id → event id) stands in for attendance. `withServerFields` takes `plannedEventId` and nulls `dueOn` when the current step is an event step and the person is planned.

## Review Focus

1. **Due rule:**
   - planned → `due_on` null;
   - another type's event, a done event, or a plain step → unchanged;
   - missed → due again.

   Pinned in Task 1, with the fake in Task 2.
2. `mark_event_done` moves people who came past their event step of that type, and nobody else. Pinned in Task 1.
3. Plan for an individual type creates the event with the person going. For a group type it adds them, invited, to the picked event. Either way people reload, and the row leaves Today. Pinned in Tasks 4 and 6.
4. Later moves the due day and the row leaves Today. Pinned in Tasks 1 and 6.

---

### Task 1: Migration and pgTAP

**Files:**
- Create: `supabase/migrations/<timestamp>_event_steps.sql`
- Create: `supabase/tests/event_steps_test.sql`

- [x] **Step 1: Failing pgTAP.**

  Fixtures, for one owner:
  - event types Unboxing (individual) and Workshop (group);
  - a customer workflow with steps:
    1. "Book the unboxing call", 0 days, Unboxing;
    2. "Give access", 0 days;
    3. "Propose a consultation", 15 days, plain;
  - people:
    - Julie on step 1, `last_tick` 10-01;
    - Inès on step 1, invited to an open Workshop only;
    - Léa on step 2.

  Cases:
  - Julie unplanned: `due_on` 10-01, `planned_event_id` null.
  - Julie attending an open Unboxing event:
    - `planned_event_id` = it, `due_on` null;
    - `due_people_count` leaves her out.
  - Inès: the Workshop doesn't plan an Unboxing step, so she is still due.
  - Léa attending the Unboxing event: not planned (her step is plain).
  - `mark_event_done` with Julie there:
    - her `current_step_id` is step 2, `last_tick` = p_today;
    - one `event` activity, no `step` activity.
  - With Julie missing it (a second Julie-like person): still on step 1, due again (`due_on` = old `last_tick` + 0).
  - `postpone_step` to 10-20 on step 1: `due_on` 10-20.
  - `postpone_step` refuses step 3 for Julie (not current: P0002) and Léa's step 2 (not an event step: P0001).
  - `position_after` on the last step of a non-repeating workflow → 1e9.
- [x] **Step 2: Migration.**

```sql
alter table public.workflow_step
  add column event_workflow_id uuid,
  add foreign key (event_workflow_id, owner_id)
    references public.event_workflow (id, owner_id)
    on delete set null (event_workflow_id);
create index workflow_step_event_workflow_id_owner_id_idx
  on public.workflow_step (event_workflow_id, owner_id);

-- The open event of the current step's type that the person attends,
-- invited or going; the earliest. Null on a plain step.
create function public.planned_event_id(p public.person) returns uuid
language sql stable security invoker set search_path = '' as $$
  select e.id
  from public.workflow_step s
  join public.event e on e.event_workflow_id = s.event_workflow_id
  join public.event_attendee a on a.event_id = e.id and a.person_id = p.id
  where s.id = public.current_step_id(p) and e.done_at is null
  order by e.starts_at limit 1
$$;

create or replace function public.due_on(p public.person) returns date
language sql stable security invoker set search_path = '' as $$
  select p.last_tick + s.days from public.workflow_step s
  where p.paused_at is null and s.id = public.current_step_id(p)
    and public.planned_event_id(p) is null
$$;

-- Where ticking p_step leads: the next step's position; past the last, the
-- first's when the workflow repeats, else 1e9 (done).
create function public.position_after(p_step uuid) returns numeric
language sql stable security invoker set search_path = '' as $$ … $$;
```

  - `complete_step` is copied from `20261012210500_repeating_workflows.sql` with `next_position := public.position_after(p_step)`.
  - `mark_event_done` is copied from `20261007000002_event_workflows.sql`. Before the mapping update, it runs `update public.person p set at_position = public.position_after(s.id), last_tick = p_today` for attendees who came, `where s.id = public.current_step_id(p) and s.event_workflow_id = marked.event_workflow_id`.
  - `postpone_step(p_person uuid, p_step uuid, p_until date) returns public.person` locks the person, refuses as ruled, then sets `last_tick = p_until - step.days`.
  - Grants:
    - revoke the new functions from `public, anon`;
    - grant `planned_event_id`, `position_after` and `postpone_step` to `authenticated`;
    - `planned_event_id` also to `service_role`, because `due_on` calls it in `due_people_count`.
  - `supabase test db` passes.

### Task 2: Models, repositories, fakes, progress

**Files:**
- Modify: `lib/features/workflows/domain/workflow.dart`, `lib/features/workflows/data/workflow_repository.dart`, `lib/features/workflows/domain/progress.dart`
- Modify: `lib/features/contacts/domain/person.dart`, `lib/features/contacts/data/people_repository.dart`, `lib/features/contacts/presentation/people_controller.dart`
- Create: `lib/features/calendar/domain/missed.dart`
- Modify: `test/features/workflows/server_rule.dart`, `fake_workflow_repository.dart`, `test/features/contacts/fake_people_repository.dart`
- Test: `test/features/workflows/domain/progress_test.dart`, `test/features/workflows/data/workflow_repository_test.dart`, `test/features/contacts/data/people_repository_test.dart`, `test/features/calendar/domain/missed_test.dart`, `test/features/contacts/presentation/people_controller_test.dart`

- [x] **Step 1: Failing tests.**
  - Row mapping reads `event_workflow_id` on a step and `planned_event_id` on a person.
  - `progressOf`:
    - an event step with `plannedEventId` → `Planned`;
    - without it, and with `dueOn` → `OnStep` with `isEvent`.
  - `missedEvent`:
    - the latest done event of the type where they didn't come, on or after `last_tick`;
    - none when they came, or for an older event or another type.
  - Controller: `postponeStep` replaces the person, and the fake records `postponeStep(p1:s1:2026-10-20)`.
- [x] **Step 2: Model.**
  - `WorkflowStep` gains `eventWorkflowId` (`String?`, doc: "An event step: planned as an event of this type, ticked when it is done with them there").
  - `Person` gains `plannedEventId` (read-only, carried through `_copy` and the server-rule copies).
  - `_columns` adds `planned_event_id`, and `personFromRow` reads it.
- [x] **Step 3: Repositories.**
  - `addStep` / `updateStep` take `eventWorkflowId`.
  - `workflowFromRow` reads it.
  - `PeopleRepository.postponeStep(personId, stepId, until)` calls RPC `postpone_step`, `.select(_columns).single()`, like `completeStep`.
  - `PeopleController.postponeStep(Person, OnStep, DateTime until)` uses `_replace`.
- [x] **Step 4: Progress.**
  - `Planned` and `OnStep.isEvent` as ruled.
  - `progressOf` checks `plannedEventId` before the `due == null` return.
- [x] **Step 5: Fakes.**
  - `withServerFields(person, workflows, {String? plannedEventId})`.
  - `FakePeopleRepository.plannedEvents`, plus `postponeStep` mirroring the refusals.
  - `FakeWorkflowRepository` carries `eventWorkflowId`.

### Task 3: Step sheet Event picker

**Files:**
- Modify: `lib/features/workflows/presentation/step_sheet.dart`, `workflows_preview.dart`
- Modify: `lib/l10n/app_en.arb`
- Test: `test/features/workflows/presentation/step_sheet_test.dart`

- [x] **Step 1: Failing widget test.** The Event row lists "None", "Unboxing call" and "Workshop". Picking one and saving passes `eventWorkflowId`. An existing event step opens with its type.
- [x] **Step 2: Copy.** `stepEvent` "Event" and `stepEventNone` "None", each with a description. The Figma helper text is left out: the label reads clearly without it.
- [x] **Step 3:**
  - `StepDraft` gains `eventWorkflowId`.
  - `StepForm` gains `eventTypes` (`List<EventWorkflow>?`).
  - `showStepSheet` watches `eventWorkflowsProvider(owner)` and passes the value to `addStep` / `updateStep`.
  - The row sits above the loyalty switch.

### Task 4: Plan sheet and the event form's prefill

**Files:**
- Modify: `lib/features/calendar/presentation/event_form.dart`
- Create: `lib/features/calendar/presentation/plan_sheet.dart`
- Modify: `lib/l10n/app_en.arb`
- Test: `test/features/calendar/presentation/plan_sheet_test.dart`, `event_form_test.dart`

- [x] **Step 1: Failing widget tests.**
  - `showEventForm(type: unboxing, title: 'Unboxing call — Julie', day: today + 7)` opens with the chip selected, that title, that day and 19:00.
  - `planEvent` on an individual type: saving creates the event, then calls `invite(<new id>, ['p1'], today)` and reloads people.
  - `planEvent` on a group type:
    - the sheet lists the type's upcoming open events, earliest first, as "Huiles et sommeil · Thu 20 · 6 invited", then "New Workshop";
    - Invite with one picked calls `invite(e1, ['p1'], today)`;
    - New opens the form prefilled, then invites.
  - A failed invite shows the SnackBar.
- [x] **Step 2: Copy.**
  - `planGroupTitle` ({name}, {type}) "Invite {name} to {type}";
  - `planGroupBody` ({name}) "{name} starts as invited. Today reminds you to follow up after 3 days.";
  - `planGroupNew` ({type}) "New {type}";
  - `planInvite` "Invite";
  - `planEventTitle` ({type}, {name}) "{type} — {name}".

  Each with a description.
- [x] **Step 3: Form.** `showEventForm` gains `EventWorkflow? type` and `String? title` for a new event. `initState` calls `_choose(type)`, then sets the title.
- [x] **Step 4: Sheet.** `Future<bool> planEvent(BuildContext context, WidgetRef ref, Person person, EventWorkflow type)`, true once planned. For a group type it shows `LoomiaDialog` with `RadioListTile`s and Cancel / Invite. Writes go through `EventsController.add` / `invite`, then `ref.invalidate(peopleProvider(owner))`.

### Task 5: NEXT STEP card

**Files:**
- Modify: `lib/features/contacts/presentation/next_step_section.dart`, `change_stage_sheet.dart`, `contacts_preview.dart`
- Modify: `lib/l10n/app_en.arb`
- Test: `test/features/contacts/presentation/next_step_card_test.dart`

- [x] **Step 1: Failing widget tests.**
  - An event step to plan shows Plan and Later, and no ring.
  - Missed reads "Book again · missed Huiles et sommeil on Tue".
  - Planned shows the event's title and when; tapping it opens the event; there are no buttons.
  - Plan and Later call their callbacks.
- [x] **Step 2: Copy.**
  - `nextStepPlan` "Plan";
  - `nextStepLater` "Later";
  - `nextStepMissed` ({event}, {day} `E`) "Book again · missed {event} on {day}";
  - `nextStepPlanned` "Planned".

  Each with a description.
- [x] **Step 3: Card.** `NextStepCard` gains:
  - `onPlan` and `onLater` (`ValueChanged<OnStep>?`);
  - `onOpenEvent`;
  - `events` (`List<CalendarEvent>`, for planned and missed).

  `_step` uses `actions` when `on.isEvent`; a new `_planned` builds the planned row. `NextStepSection`:
  - watches `eventsProvider` and `eventWorkflowsProvider`;
  - Plan → `planEvent`;
  - Later → `pickDay`, then `people.postponeStep`.
- [x] **Step 4:** `change_stage_sheet` counts `Planned` as on a step. The preview gains one card in the planned state on an existing frame only if a golden already covers that card; otherwise there is no new preview.

### Task 6: Today

**Files:**
- Modify: `lib/features/today/domain/due.dart`, `lib/features/today/presentation/today_page.dart`, `today_preview.dart`
- Test: `test/features/today/domain/due_test.dart`, `test/features/today/today_page_test.dart`

- [x] **Step 1: Failing tests.**
  - `dueToday` gives an event step a `DueStep` with `missed` set from the events.
  - Today:
    - an event step row shows Plan / Later and no ring;
    - Plan on an individual type opens the form; saving makes the row leave;
    - Later with a picked day calls `postponeStep`, and the row leaves.
- [x] **Step 2:** `DueStep` gains `CalendarEvent? missed`, filled in `dueToday` through `missedEvent`. `TodayView` gains `onPlan` and `onLater` (`void Function(DueStep)?`). `_row` builds `actions` for `step.step.isEvent`, reusing the card's copy.
- [x] **Step 3:**
  - `_TodayPageState` handles Plan through `planEvent`, with the event type found in `eventWorkflowsProvider`. With types still loading, Plan does nothing and stays disabled.
  - Later goes through `pickDay`, then `writePeople(... postponeStep)`.
  - The preview's `_book` gains one event step to plan.

### Task 7: Gate

- [x] `dart format .`, `flutter analyze`, `flutter test`, `supabase test db`; `graphify update .`.
- [x] Push, regenerate goldens through CI, open the PNGs, commit them.
- [x] PR `feat(workflows): event steps`, body `Closes #315`, with the Database section filled in: push needed, before the release, safe for the released app.

## Found while implementing

- **`planEvent` takes the context, not a `WidgetRef`.** It reads the `ProviderContainer` before its first await, so the Today row or the card can go away while the form is open.
- **`pickLater(context)` in `plan_sheet.dart`** is the Later picker that the card and Today share. `planButtons` in `next_step_section.dart` builds the Plan and Later buttons for both.
- **The step sheet's Event row shows None for a type that isn't in the list**, either still loading or deleted, because `DropdownButton` asserts on a value missing from its items. Saving keeps the step's type.
- **`pumpFormHarness` overrides the event types** with the fake's samples, so the step sheet's Event row loads in its tests.
- **Weekdays read `startsAt.toLocal()`** in the plan sheet, the missed line and #314's follow-up row. An event close to midnight UTC would otherwise show the wrong day.
- **The Today rows' "Plan → the row leaves" isn't pinned in the widget test.** The fake can't know the person now attends: `planned_event_id` is server-side, and it is pinned in `event_steps_test.sql`. The test checks the invite and the reload of people.
- **Goldens:** the Today previews (Julie's unboxing call to plan) and `workflow_step_light` (the Event row), regenerated through CI.

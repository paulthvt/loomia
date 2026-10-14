# Who Was There Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Marking an event done records what changed for each person (#318, part of #313).
- **Who came, by stage:**
  - a prospect who came: "Became a customer?", which logs the registration order (amount optional) and starts the default customer workflow;
  - a customer or team member who came: an optional order;
  - anyone on an event step of this type moves past it, as since #315.
- **Who didn't come:** for a group type, they can be invited to the next event of that type.
- **What goes:** the stage → workflow mapping is no longer offered anywhere in the app.
- **Change stage:** moving one person to Customer also takes the registration order.

**Architecture:** This is the "add the new beside the old" half of the split (AGENTS.md → migrations must not break the released app).
- **New:** `close_event(p_event, p_there jsonb, p_invite_next uuid[], p_today)` sits beside `mark_event_done`, which the released app still calls.
- **Old, kept for now:** `mark_event_done` and the six `*_workflow_id` columns stay in the database.
- **Dart:** the app stops reading and writing the mapping. It loses `followUps`, `FollowUpPicker`, `thereSummary`, the After the event blocks and `setFollowUps`. Today's "to mark" no longer depends on a mapping.
- **Cleanup (follow-up issue, once both phones run this build):**
  - drop `mark_event_done(uuid, uuid[], date)`;
  - drop the six columns;
  - drop their copy in `extend_event_series`.

**Tech Stack:** Flutter (`material_ui`), `flutter_riverpod` 3, Supabase (Postgres, pgTAP).

**Spec:** `docs/superpowers/specs/2026-10-13-workflows-events-design.md` (Decisions: After an event, Stage → workflow mapping, Absent from a group event, Became a customer elsewhere; §1 Outcomes; §4 Who was there, Event page, Settings). Figma: "Who was there — workshop, per person", "Who was there — unboxing call", "Who was there — dialog — desktop".

## Global Constraints

- One migration, `supabase migration new close_event`.
- **Database:** push after merge, before the release. Safe for the released app:
  - the migration only adds `close_event`;
  - `mark_event_done`, the mapping columns and `extend_event_series` are untouched.
- No new dependency. Copy in `app_en.arb` only, described. Gate: `dart format .`, `flutter analyze`, `flutter test`, `supabase test db`. Goldens through CI.
- Branch `feature/318-who-was-there`; PR `Closes #318`, Database section filled.

## Rulings made while planning

- **A new name, not an overload.** PostgREST picks an overload by argument names, which is fragile. `close_event` reads clearly beside `mark_event_done`, and the cleanup drops the old one.
- **Becoming a customer is inline in `close_event`, with no `became_customer` RPC.** The Change stage sheet writes the order through the existing history `add` after `moveTo`, so nothing else would call that RPC.
  - The sheet only offers the order when moving one person to Customer.
  - A failed order after a successful move says so, and the stage stays moved.
- **`p_there`:** one entry per person who came, `[{person, customer, amount, text}]`.
  - `customer` is honoured only for a prospect.
  - The order entry is written when `customer` is true, or when an amount is given.
  - `text` is the device's "Registration order" when there is no amount, since the order table needs a text or an amount.
- **The order of writes, per person who came:**
  1. the `'event'` entry;
  2. past the event step (`position_after`), when this event's type is their current step's;
  3. then, if `customer`: stage, the order, and the default customer workflow from its first step (none without a default). Stage last means someone on Workshop invite finishes it, then starts New customer;
  4. otherwise the optional order.
- **`p_invite_next`:**
  - **Who:** attendees who weren't there.
  - **Where:** the earliest open event of the same type starting after this one's start, for a group type only, `on conflict do nothing`. Inserted with `going` left to the trigger, so they start invited.
  - **Refused:** someone who came, or who isn't an attendee (P0001).
- **The sheet doesn't load the mapping**, so this is a pure deletion on the Dart side. `followUpColumn` and the columns' Dart readers go. Events created by this build write no mapping (the columns are null).
- **The continue line** ("Continues New customer → Give VIP access" / "Finishes Workshop invite") comes from `progressOf` and the person's workflow: their current step (`OnStep` or `Planned`), when its type is the event's.

## Review Focus

1. **`close_event`:**
   - prospect → customer: stage, order with amount or text, default workflow;
   - customer: order only with an amount;
   - event step advanced before the stage change;
   - absent invite only to the next open event of the type;
   - refusals;
   - one transaction.

   Pinned in Task 1.
2. Nothing in the app reads or writes the mapping. Pinned by `flutter analyze` after the deletions (Task 2) and the editor and form tests.
3. Who was there sends exactly what was picked. Pinned in Task 3.

---

### Task 1: Migration and pgTAP

**Files:** Create `supabase/migrations/<ts>_close_event.sql`, `supabase/tests/close_event_test.sql`.

- [x] **Step 1: Failing pgTAP.**
  - **Fixtures:**
    - two Workshop events, the second later;
    - a default customer workflow;
    - Workshop invite (a prospect workflow with one Workshop event step);
    - Sophie on Workshop invite, invited;
    - Marc, a prospect;
    - Claire, a customer;
    - Léa, absent.
  - **Cases:**
    - **Sophie, `customer: true`, amount 120:** `stage` customer; an `order` of 120; the `workflow_id` is the default customer workflow, at its first position with `last_tick = p_today`; the `stage` entry is written by the trigger.
    - **Claire, amount null:** no order.
    - **Claire, amount 40:** an order of 40.
    - **Marc, `customer: true`, no amount:** an order with text "Registration order".
    - **Léa invited to the next:** she's on the second event, not going.
    - **The event:** `done_at` is set.
  - **Refusals:**
    - already done (P0001);
    - someone not invited, in `p_there` (P0001);
    - someone who came, in `p_invite_next` (P0001);
    - another owner (P0002).
- [x] **Step 2: Migration.**
  - `close_event`, plpgsql, `security invoker`, `search_path = ''`. It locks the event and validates as ruled.
  - It reads `p_there` with `jsonb_to_recordset(p_there) as t(person uuid, customer boolean, amount numeric, text text)`.
  - It writes in the ruled order, then sets `done_at`, and returns the event.
  - Grants: revoke from `public, anon`; grant to `authenticated`.

### Task 2: Deleting the mapping in Dart

**Files:**
- Modify:
  - `calendar_event.dart`, `event_repository.dart`, `event_form.dart`, `event_page.dart`, `calendar_preview.dart`, `who_was_there_sheet.dart`;
  - `event_workflow.dart`, `event_workflow_repository.dart`, `event_workflow_editor.dart`, `workflows_preview.dart`;
  - `today_events.dart`;
  - their tests and fakes.
- Delete: `follow_up_picker.dart`.

- [x] **Step 1:**
  - **Fields:** remove `CalendarEvent.followUps`, `EventDraft.followUps`, `EventWorkflow.followUps`, `followUpColumn`, `followUpsFromRow` / `followUpsToRow`, and `setFollowUps`.
  - **UI:** remove the editor's After the event section (`_Control.followUps`), the event page block and `followUpNames`, the form's `_followUps`, and `thereSummary`.
  - `draftToEventRow` / `seriesToRow` no longer send the columns.
- [x] **Step 2:** `todayEvents`: an event is to mark when `canMarkDone`, it has a type, it isn't joinable, and it's within 14 days. Before, it needed a mapping.
- [x] **Step 3:** Remove the copy that only the mapping used: `eventWorkflowAfter`, `eventWorkflowAfterHint`, `eventFollowUpStarts`, `eventFollowUpKeeps`, `eventWorkflowKeep`, `eventWhatHappensNext`, and the `eventThere*` summary keys. Remove them from `app_fr.arb` too, because `arb_keys_test.dart` requires it. `eventWorkflowFooter` loses its sentence about what people start.
- [x] **Step 4:** `flutter analyze` is clean, and the tests are updated for the removed fields.

### Task 3: Who was there and Change stage

**Files:**
- Modify: `who_was_there_sheet.dart`, `event_repository.dart`, `calendar_controller.dart`, `fake_event_repository.dart`, `change_stage_sheet.dart`, `app_en.arb`.
- Test: `test/features/calendar/presentation/who_was_there_sheet_test.dart`, `calendar_controller_test.dart`, `change_stage_sheet_test.dart`.

- [x] **Step 1: Failing tests.**
  - **The sheet, per attendee:**
    - there or not;
    - a prospect there: "Became a customer?" with the registration order amount, and "Starts New customer" when on;
    - a customer or team member there: "Order (optional)";
    - on an event step of this type: "Continues New customer → Give VIP access", or "Finishes Workshop invite";
    - not there, on a group type, with a next event: "Invite to Huiles et sommeil · Tue, Nov 3", on.
  - **Done sends** `close(e1, there: [...], inviteNext: [...], today)` exactly.
  - **A failure** shows the `FormError`.
  - **Change stage**, one prospect to Customer, with amount 120: `moveTo` then an order entry of 120.
- [x] **Step 2: Copy.**
  - `thereBecameCustomer` "Became a customer?";
  - `thereRegistrationOrder` "Registration order";
  - `thereOrder` "Order (optional)";
  - `thereStarts` ({workflow}) "Starts {workflow}";
  - `thereContinues` ({workflow}, {step}) "Continues {workflow} → {step}";
  - `thereFinishes` ({workflow}) "Finishes {workflow}";
  - `thereInviteNext` ({title}, {day} `MMMEd`) "Invite to {title} · {day}".

  Each with a description.
- [x] **Step 3: Repository and controller.**
  - `EventRepository.close(eventId, there, inviteNext, today)` calls `close_event`. `there` is `List<There>`, a record `({String personId, bool customer, double? amount, String? text})`.
  - `EventsController.close` invalidates people and history like `markDone`.
  - The fake applies the stage, the next invite and `done`.
- [x] **Step 4: Sheet.** Per-attendee rows: a `CheckboxListTile`, then indented controls. Amount fields reuse `parseAmount` with the business model's unit. The "Done · N were there" button stays.
- [x] **Step 5: Change stage.** With one person, a prospect, moved to Customer: a "Registration order" amount field (optional). Saving runs `moveTo`, then `historyProvider(id).notifier.add((kind: order, happenedOn: today, text: l10n.thereRegistrationOrder, amount))`.

### Task 4: Gate

- [x] Gate, goldens through CI, PR with the Database section. Open the cleanup issue (drop `mark_event_done` and the mapping columns) and link it from the PR.

## Found while implementing

- **The cleanup is #329:** drop `mark_event_done`, the six columns and `extend_event_series`'s copy, once both phones run this build.
- **`markDone` is gone from the Dart side** (repository, controller, fake). `close` replaces it everywhere. The server function stays only for older builds.
- **A local variable named `came` clashed with the column** in `close_event`, so the array is `there`.
- **Two Settings lines named what people start**: `eventWorkflowFooter` and `workflowsEventsHint`. Both were reworded in English and French. In `app_fr.arb` that counts as a translation fix; the keys stay.
- **Tests:**
  - those about the mapping are deleted;
  - plain and morning events in `today_events_test.dart` pass `eventWorkflowId: null` now that "to mark" means "has a type";
  - `event_workflow_repository_test.dart` keeps a steps test without stages.
- **Goldens:** `event_mobile_light` loses After the event; `event_workflow_editor_light` loses its pickers.

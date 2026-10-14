# What's Next Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A workflow can list what comes after it (#316, part of #313): Samples → Wellness check or Workshop invite. When someone finishes a workflow that has next options, Today shows "What's next for Sophie? · Samples is done" until it's answered. A customer with no LRP is also asked "Did Julie start an LRP?". Answering starts the chosen workflow, or none. A workflow with nothing next and nothing to ask stays silent, as it is today.

**Architecture:**
- **Migration:**
  - a `workflow_next (workflow_id, next_workflow_id)` table with a same-stage trigger;
  - the computed field `needs_next(person)`, the one rule for both Today and the push;
  - `due_people_count` counts it.
- **Workflows:** `Workflow` gains `next` (ids), read through an embed. The editor gets a What's next section with one checkbox per other workflow of the stage.
- **People:** `Person` gains `needsNext`. Today adds `DueNext`, and a `whats_next_sheet.dart` holds the LRP question and the radio list. The NEXT STEP card's Done state opens the same sheet when `needsNext`.

**Tech Stack:** Flutter (`material_ui`), `flutter_riverpod` 3, Supabase (Postgres, pgTAP).

**Spec:** `docs/superpowers/specs/2026-10-13-workflows-events-design.md` (Decisions: What's next, LRP question; §1 What's next; §4 Today, What's next sheet, Settings). Figma: [Workflows & events — #313](https://www.figma.com/design/spz2vsSK8gbt1Ok2rW1sdQ/Loomia?node-id=358-8961), frames "What's next sheet — prospect / customer, LRP question", "Settings / Workflow editor — what's next", "Today — new rows".

## Global Constraints

- One migration, `supabase migration new whats_next`. Never edit an applied one.
- **Database:** `supabase db push` after merge, before the app release. The released app keeps working: the migration adds a new table, a new function and a same-signature `due_people_count`.
  - **Visible quirk until people update:** the daily push also counts finished customers without an LRP, whom the released Today can't show.
- The rule lives in Postgres (`needs_next`). Dart only reads it.
- No new dependency. Stage files by path. `package:loomia/...` imports, `material_ui`, theme values only, `AppTheme.tonal` on tonal buttons.
- Copy in `app_en.arb` only, every key described; `flutter gen-l10n`.
- Gate: `dart format .`, `flutter analyze`, `flutter test`, `supabase test db`. Goldens through CI.
- Branch `feature/316-whats-next`; PR `Closes #316`, Database section filled.

## Rulings made while planning

- **No order column; the list order is fixed:** the default workflow first, then by name, as `forStage` sorts everywhere else. The editor's section is therefore one checkbox per other workflow of the stage. This departs from the Figma's reorderable list. Add a `position` column if someone wants a different order.
- **The LRP day picker waits for #317**, which adds `loyalty_day`. Here Yes calls `set_loyalty(person, today, today)` and nothing more.
- **Answering is up to two writes:** Yes on the LRP, then the workflow (`setPlace`).
  - "Nothing for now" sets `workflow_id = null`, which also stops the question.
  - With Yes and no next options, the sheet only sets the LRP, and `needs_next` turns false by itself.
  - A failure keeps the sheet open with its `FormError`.
- **The Today row's day is the finishing tick (`place.lastTick`).** It sorts like a step and shows no late chip: nothing is overdue about choosing what comes next.
- **The NEXT STEP card:** with `needsNext` true, Done shows a panel with "What's next for Sophie?" and a Choose button that opens the sheet. Without it, the panels stay as they are ("How did it end?", Follow with).

## Review Focus

1. `needs_next`:
   - finished with next options → true;
   - finished as a customer without an LRP → true;
   - repeating, on a step, paused, or no workflow → false;
   - answering turns it false.

   Pinned in Task 1.
2. A different stage is refused in `workflow_next`. Pinned in Task 1.
3. The sheet's two writes, and Today's row leaving. Pinned in Task 4.

---

### Task 1: Migration and pgTAP

**Files:** Create `supabase/migrations/<ts>_whats_next.sql`, `supabase/tests/whats_next_test.sql`.

- [x] **Step 1: Failing pgTAP.** Cases:
  - **RLS:** owner A sees their rows; B sees none and can't insert into A's workflows.
  - **Stage trigger:** a different stage → `23514`.
  - **`needs_next`:**
    - true for a prospect who finished Samples, which has a next option;
    - false for one who finished a workflow with no next option;
    - true for a customer who finished without an LRP;
    - false for that customer once `loyalty_since` is set;
    - false for a paused person;
    - false for one on a step;
    - false for someone on a repeating workflow at its end, which can't happen anyway;
    - false with `workflow_id` null.
  - **`due_people_count`:** counts the finished prospect.
- [x] **Step 2: Migration.**
  - `workflow_next`:
    - columns `workflow_id`, `next_workflow_id`, `owner_id default auth.uid()`, `created_at`;
    - PK `(workflow_id, next_workflow_id)`;
    - constraints named `workflow_next_from_fkey` and `workflow_next_to_fkey`, composite to `workflow (id, owner_id)`, both `on delete cascade`;
    - `check (workflow_id <> next_workflow_id)`;
    - an index on `(next_workflow_id, owner_id)`.
  - Trigger `workflow_next_same_stage`: a `before insert or update` that raises `23514` when the stages differ.
  - Access:
    - RLS: select, insert and delete owner policies;
    - `revoke all` from `anon, authenticated`, then `grant select, insert, delete` to `authenticated`.
  - `needs_next(p public.person) returns boolean`: `p.workflow_id is not null and p.paused_at is null and current_step_id(p) is null`, and `(exists workflow_next for it, or (stage = 'customer' and loyalty_since is null))`.
  - `due_people_count`: `create or replace` from `20261014171423_event_invitations.sql`, adding `or public.needs_next(p)`.
  - Grants: `needs_next` to `authenticated` and `service_role`.

### Task 2: Models and repositories

**Files:**
- Modify:
  - `lib/features/workflows/domain/workflow.dart`
  - `lib/features/workflows/data/workflow_repository.dart`
  - `lib/features/contacts/domain/person.dart`
  - `lib/features/contacts/data/people_repository.dart`
  - fakes: `fake_workflow_repository.dart`, `server_rule.dart`, `fake_people_repository.dart`
- Test: `workflow_repository_test.dart`, `people_repository_test.dart`.

- [x] **Step 1: Failing tests.** The row mapping reads:
  - `workflow_next` → `Workflow.next` (empty when the embed is missing);
  - `needs_next` → `Person.needsNext` (false when missing).
- [x] **Step 2:**
  - **`Workflow`:** gains `List<String> next`. The select becomes `*, workflow_step(*), workflow_next!workflow_next_from_fkey(next_workflow_id)`.
  - **Repository:** gains `addNext(workflowId, nextId)` and `removeNext(workflowId, nextId)`.
  - **`Person`:** gains `needsNext`. The people `_columns` add `needs_next`.
- [x] **Step 3: Fakes.**
  - `withServerFields` computes `needsNext`: a place, no current step, not paused, and either next options or a customer without an LRP. It is the Dart copy of `needs_next`.
  - The fake workflow repository supports `addNext` and `removeNext`.

### Task 3: Editor section

**Files:** Modify `workflow_editor.dart`, `workflows_preview.dart`, `app_en.arb`. Test `workflow_editor_test.dart`.

- [x] **Step 1: Failing widget test.**
  - Samples' editor lists Health professionals under WHAT'S NEXT, but not Samples itself or any customer workflow.
  - Ticking calls `addNext(samples, health)`; unticking calls `removeNext`.
- [x] **Step 2: Copy.**
  - `workflowNext` "What's next";
  - `workflowNextNote` ({name}) "When {name} is done, Today offers these. Same stage only.";
  - `workflowNextNone` "No other workflow for this stage yet."
- [x] **Step 3:** `WorkflowEditorView` gains `others` (`List<Workflow>`) and `onNext` (`Future<void> Function(String id, bool on)`), plus `_Control.next`. The section sits after the steps: a `SettingsGroup` of `CheckboxListTile`s, then the note.

### Task 4: The sheet, Today and the card

**Files:**
- Create `lib/features/contacts/presentation/whats_next_sheet.dart`.
- Modify:
  - `lib/features/today/domain/due.dart`
  - `today_page.dart`, `today_preview.dart`
  - `next_step_section.dart`
  - `app_en.arb`
- Test: `test/features/contacts/presentation/whats_next_sheet_test.dart`, `due_test.dart`, `today_page_test.dart`.

- [x] **Step 1: Failing tests.**
  - **`dueToday`:** someone with `needsNext` yields `DueNext`, keyed `next:<id>`, dated `place.lastTick`.
  - **Sheet, prospect:** it lists the next workflows and "Nothing for now", with the first one picked. Done with Wellness check calls `setPlace(p1, wellness)`. "Nothing for now" calls `setPlace(p1, none)`.
  - **Sheet, customer without an LRP:** it asks "Did Julie start an LRP?" first. Yes → `setLoyalty(p1)`, then `setPlace`. A failure shows the `FormError` and keeps the sheet.
  - **Today:** the row reads "What's next for Sophie? · Samples is done"; tapping it opens the sheet, and answering makes the row leave.
- [x] **Step 2: Copy.**
  - `nextWhatTitle` ({name}) "What's next for {name}?";
  - `nextWhatDone` ({workflow}) "{workflow} is done";
  - `nextWhatNothing` "Nothing for now";
  - `nextLoyaltyQuestion` ({name}) "Did {name} start an LRP?";
  - `nextLoyaltyYes` "Yes";
  - `nextLoyaltyNotYet` "Not yet";
  - `nextWhatChoose` "Choose";
  - `nextWhatSave` "Done".

  Each with a description.
- [x] **Step 3: Sheet.** `showWhatsNext(BuildContext, Person, Workflow)` is a `LoomiaDialog`:
  - the LRP `SegmentedButton` (Yes / Not yet) when `stage == customer && loyaltySince == null`;
  - a `RadioGroup` over `next` (resolved through `forStage`, so the order is fixed) plus "Nothing for now";
  - Done runs the writes through the `PeopleController`.
- [x] **Step 4: Today.**
  - `DueNext(person, workflow)`;
  - `_row` builds an `ActionItem` with a chevron-less `onOpen` that opens the sheet, and no ring and no buttons;
  - the rank is reminder < follow-up < next < step.
- [x] **Step 5: Card.** In the `Done` case, when `person.needsNext`, a `_Panel` with `nextWhatTitle` and a Choose button opens the sheet.
- [x] **Step 6: Preview.** Today's `_book` gains one `DueNext`. Julie's row gets the customer stage, fixing the tag left over from #315.

### Task 5: Gate

- [x] `dart format .`, `flutter analyze`, `flutter test`, `supabase test db`, `graphify update .`.
- [x] Push, regenerate goldens through CI, look at them, commit.
- [x] PR `feat(workflows): what's next when a workflow ends`, `Closes #316`, Database section.

## Found while implementing

- **The pgTAP push count is 2, not 3.** The repeating weekly step is due a week after its tick, so it doesn't count yet.
- **A prospect asked what's next doesn't see "How did it end?"**. Becoming a customer stays in Change stage. Done shows one panel: What's next when `needsNext`, the old ones otherwise.
- **The sheet's Done waits for the LRP answer**, so a tap can't skip the question.
- **The workflow editor preview has no `onNext`**, so its golden is unchanged. The section shows in the app and in the widget tests.
- **The Today preview's Julie is a customer** now, fixing the "Prospect" tag on her unboxing call from #315.
- **Goldens:** `today_*`.

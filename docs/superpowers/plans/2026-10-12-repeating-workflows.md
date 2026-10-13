# Repeating Workflows Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A workflow can start over after its last step (`workflow.repeats`). Ticking the last step of a repeating workflow brings the first step back, due its days after the tick; it is never Done. The editor has the switch and refuses a loop of zero days (#296).

**Architecture:** One migration adds `workflow.repeats` and replaces `complete_step` so the position after the last step is the first step's when the workflow repeats. `current_step_id` and `due_on` are unchanged. `Workflow` gains `repeats`, `WorkflowRepository` reads it and writes it with `setRepeats`. `canRepeat(steps)` in the domain guards the editor switch and the step sheet. `workflowSteps(l10n, workflow)` names "N steps · Repeats" for the three rows that list workflows.

**Tech Stack:** Flutter (`material_ui`), `flutter_riverpod` 3, Supabase (Postgres, pgTAP).

**Spec:** `docs/superpowers/specs/2026-10-12-repeating-workflows-design.md`. No Figma section (a switch in the existing editor).

## Global Constraints

- One migration, `supabase migration new repeating_workflows`. Never edit an applied one.
- No new dependency. Stage only changed files by path.
- The rule lives in Postgres; `test/features/workflows/server_rule.dart` is the only Dart copy and follows it.
- Dart: `package:loomia/...` imports; Material from `package:material_ui/material_ui.dart`. Theme values only.
- Copy: English only, in `lib/l10n/app_en.arb`, every key with a description; `flutter gen-l10n`.
- Quality gate: `dart format .`, `flutter analyze` ("No issues found!"), `flutter test`, `supabase test db`. Goldens through CI.
- Branch `feature/296-repeating-workflows`; PR body `Closes #296`.

## Rulings made while planning

- **Its own pgTAP file**, `supabase/tests/repeating_workflows_test.sql`, rather than growing `workflow_test.sql`: the cases need their own fixtures.
- **`canRepeat` is order-free:** the steps' days add up to at least 1. Reordering never changes it, so drag needs no guard. A repeating workflow with no steps is harmless (nothing to tick) and allowed.
- **The step sheet gets `loopOthers`**, the other steps when the workflow repeats (null otherwise). Save refuses days that make `canRepeat([...loopOthers, draft])` false, as a days-field error. Remove refuses when the others remain and `canRepeat(loopOthers)` is false, with a `FormError`.
- **Settings and Follow with share one copy helper,** `workflowSteps(l10n, workflow)` in `workflows_settings.dart`, so "· Repeats" can't drift between them.
- **The timeline page and the NEXT STEP card are unchanged.** A repeating workflow is always on a step, so their "Done" branches simply don't come up.

## Review Focus

1. Last step of a repeating workflow → first step, due its days after the tick; a non-repeating one still ends at `1e9`. Pinned in Task 1 (SQL) and Task 2 (fake).
2. Switching Repeat on leaves a Done person Done; off lets the round finish. Pinned in Task 1.
3. No way in the editor to save a repeating workflow whose days add up to 0. Pinned in Task 3.

---

### Task 1: `workflow.repeats` and `complete_step`

**Files:**
- Create: `supabase/migrations/<timestamp>_repeating_workflows.sql`
- Create: `supabase/tests/repeating_workflows_test.sql`

- [x] **Step 1: Failing pgTAP.** One owner; a customer workflow "Refill" (`repeats`) with steps 1 "Ask about supplies" (25 days) and 2 "Help with the order" (3 days, `loyalty_setup`); a non-repeating "Once" with one step. People: on Refill's step 2 (`loyalty_since` set), on Once's step, Done on Refill (`at_position = 1e9`). Cases:
  - ticking Refill's last step: `at_position` = step 1's, `current_step_id` = step 1, `due_on` = tick + 25, one `step` entry, `loyalty_since` unchanged;
  - ticking Once's only step: `at_position = 1e9`, no current step;
  - the Done person on Refill: no current step;
  - Repeat switched off on Refill, then step 1 then step 2 ticked: Done.
- [x] **Step 2: Migration.** `alter table public.workflow add column repeats boolean not null default false;` and `create or replace function public.complete_step` copied from `20261010130800_loyalty_on_person.sql` with the next position:

```sql
  select coalesce(
           min(s.position),
           case when w.repeats
             then (select min(f.position) from public.workflow_step f
                   where f.workflow_id = w.id)
             else 1e9
           end)
    into next_position
    from public.workflow w
    left join public.workflow_step s
      on s.workflow_id = w.id and s.position > step.position
    where w.id = step.workflow_id
    group by w.id, w.repeats;
```

  Grants are kept by `create or replace`. `supabase test db` passes.

### Task 2: Model, repository, fake

**Files:**
- Modify: `lib/features/workflows/domain/workflow.dart`
- Modify: `lib/features/workflows/data/workflow_repository.dart`
- Modify: `test/features/workflows/server_rule.dart`, `test/features/workflows/fake_workflow_repository.dart`
- Test: `test/features/workflows/domain/workflow_test.dart`, `test/features/workflows/data/workflow_repository_test.dart` (row mapping), `test/features/contacts/fake_people_repository_test.dart`

- [x] **Step 1: Failing tests.** `canRepeat`: no steps → false, all 0 days → false, one non-zero → true. Row mapping reads `repeats`. The fake people repository ticking the last step of a repeating workflow lands on step 1.
- [x] **Step 2:** `Workflow` gains `final bool repeats` (default false, doc: "After the last step, the first comes back: never Done."). `canRepeat(List<WorkflowStep> steps)` next to `positionAt`. `workflowFromRow` reads `row['repeats'] as bool? ?? false`. `WorkflowRepository.setRepeats(String id, bool on)` updates the column.
- [x] **Step 3:** `positionAfter` returns `steps.first.position` past the last step when `workflow.repeats`; the fake workflow repository gains `setRepeats`.

### Task 3: Editor, step sheet, rows

**Files:**
- Modify: `lib/features/workflows/presentation/workflow_editor.dart`, `step_sheet.dart`, `workflows_settings.dart`
- Modify: `lib/features/contacts/presentation/follow_with_field.dart`
- Modify: `lib/features/workflows/presentation/workflows_preview.dart` (Repeat on in one preview)
- Modify: `lib/l10n/app_en.arb`
- Test: `test/features/workflows/presentation/workflow_editor_test.dart`, `step_sheet_test.dart`, `workflows_settings_test.dart`

- [x] **Step 1: Failing widget tests.** Editor: the switch "Start over after the last step" calls `onRepeats(true)`; disabled with "Needs at least 1 day across the steps" when every step is 0 days; step 1's line reads "When you start, then right after the last step" / "{days} days after the start or the last step" while repeating. Step sheet: with `loopOthers: []` (one step), days 0 is refused with "A repeating workflow needs at least 1 day across its steps"; Remove with `loopOthers` all 0 days shows that error and calls nothing. Settings: "1 step · Repeats".
- [x] **Step 2: Copy:** `workflowRepeats`, `workflowRepeatsOn` ({days}), `workflowRepeatsNeedsDays`, `workflowRepeatsSteps` ({steps}), `workflowStepRepeatFirst` ({days}), `workflowStepRepeatFirstSameDay`, `workflowRepeatsStepError`, each described. `flutter gen-l10n`.
- [x] **Step 3: Editor.** `WorkflowEditorView.onRepeats`, `_Control.repeats`; the switch above the default switch in the same group; `WorkflowEditor` wires `repository.setRepeats`. Step 1's subtitle as above.
- [x] **Step 4: Step sheet.** `StepForm.loopOthers`; `showStepSheet` passes `workflow.repeats ? [others] : null`. The days validator and Remove refusal as ruled.
- [x] **Step 5: Rows.** `workflowSteps(l10n, workflow)` replaces `followWithSteps(workflow.steps.length)` in `workflows_settings.dart` (`_steps`) and `follow_with_field.dart`.
- [x] **Step 6: Gate.** All checks, `graphify update .`, push, regenerate goldens through CI if a preview changed, open the PR.

## Found while implementing

- **The default switch's tests find it by its text** now that the editor has two switches (`workflow_editor_test.dart`).
- **Switching Repeat off is always allowed,** even when the days add up to 0: the round ends normally.
- **`_loops(days)` in the step sheet is `days >= 1 || canRepeat(others)`**, the same rule without building a stand-in step.
- **Goldens:** the existing "Editor — light" preview gains the Start over row, and the new "Editor, repeating — light" preview needs its first golden. Both come from CI.

# New Defaults and Account Reset Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** New accounts are seeded with the advocate's workflows and event types (spec §2), and the two existing accounts are reset onto them (#319, last of #313).

**Architecture:** One migration.
- `seed_workflows` (same signature) seeds, in this order:
  1. the four event types with their checklists;
  2. the eight workflows, with event steps pointing at those types and the bilan's note;
  3. the six `workflow_next` links.

  It no longer places anyone on a workflow.
- Then the reset deletes every `workflow_seeded`, `event_workflow` and `workflow` row, and clears the workflow place of anyone left on none. The app seeds again on its next workflows load, in the device's language.

No Dart change: the app already calls `seed_workflows` on every workflows load.

**Spec:** `docs/superpowers/specs/2026-10-13-workflows-events-design.md` (§2 Seeded defaults; §1 Seeding and reset; Decisions: Existing accounts, Seeding places people, Seeded defaults).

## Global Constraints

- **Database:**
  - `supabase db push` after merge, after #318 is pushed. It needs `workflow_next`, `is_group` and event steps, which #314 to #316 already shipped.
  - **The reset deletes data**: every workflow and every event type, on every account. Agreed for the two accounts that exist. Push it only while that is still true.
  - Released app: keeps working. `seed_workflows` keeps its signature. The released app seeds the same content and shows event steps as plain steps, which still tick.
- Branch `feature/319-new-defaults`, stacked on `feature/318-who-was-there`.

## Rulings made while planning

- **Keep the old seed's tests where they test something else.**
  - `event_workflow_test.sql` keeps testing `mark_event_done`'s stage mapping (still there for older builds until #329) on its own fixtures.
  - `edit_workflows_test.sql` and `workflow_test.sql` place people themselves, since the seed doesn't any more, and use the new names.
  - `loyalty_step_test.sql` now checks that the seed marks no loyalty step.
- **What the seed creates is pinned in its own file**, `new_defaults_test.sql`, in English and French.
- **"Onboarding" stays "Onboarding" in French**, as the advocate wrote it.

## Review Focus

1. The seed matches spec §2: names, days, event types, groups, links, repeats.
2. The reset leaves people, history, orders, LRPs and events, and leaves nobody paused on no workflow.

---

### Task 1: Migration and pgTAP

- [x] `supabase/migrations/<ts>_new_defaults.sql`: `seed_workflows` and the reset.
- [x] `supabase/tests/new_defaults_test.sql`: event types and checklists, workflows and steps, the note, the links, no loyalty step, French.
- [x] The four older tests adapted as ruled. `supabase test db` passes.

### Task 2: Gate

- [x] `supabase test db`. No Dart change, so `flutter test` runs in CI.
- [x] PR `feat(workflows): new default workflows and account reset`, `Closes #319`, based on #318's branch, with the Database section stating the reset.

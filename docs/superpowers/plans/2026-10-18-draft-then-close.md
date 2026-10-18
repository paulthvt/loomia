# Draft, then close — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** The month-end ritual drafts next month's plan in the last 3 days of a month and only closes the month from the 1st, with one push per half.

**Architecture:** The window rule changes in its two copies, Dart `pendingRitual` (cards, close page) and SQL `pending_ritual` (push). The Dart rule gains a `drafted` flag so a saved draft shows as a one-line link instead of the card. The push claims one `notification_sent` row per half, keyed by a new `claim_date` the sender hands back on release.

**Tech Stack:** Flutter (Riverpod, go_router, `material_ui`), Supabase Postgres + pgTAP, Deno Edge Function `send-daily-summary`.

**Spec:** `docs/superpowers/specs/2026-10-18-draft-then-close-design.md` (issue #354)

## Global Constraints

- Imports `package:loomia/...`; Material from `package:material_ui/material_ui.dart`.
- No hard-coded colour, spacing, radius or font size; `Theme.of(context)`, `LoomiaColors.of(context)`, `AppSpacing.*`, `AppRadii.*`.
- Copy in `lib/l10n/app_en.arb` only, every key with a description; no French edits (Weblate).
- No new table, column, enum value or notification switch. No new dependency.
- Migration via `supabase migration new draft_then_close`; must be safe for the released app.
- Goldens are regenerated through CI only; never commit local goldens.
- Commits: Conventional Commits, `(#354)` suffix.
- Done = `dart format .`, `flutter analyze` "No issues found!", `flutter test`, `supabase test db`, `deno test` in `supabase/functions/send-daily-summary` all green.

## Review Focus

1. **Month lengths and year end:** the drafting half starts on the 3rd-to-last day (Feb 26 2027, Sep 28, Oct 29, Dec 29 plans January 2027). Tests in Tasks 1 and 2 pin Feb 26/25 and Dec 29.
2. **Month closed early by an old app** (Sep 29, before updating): on Oct 1 nothing to close; plan only if October is unplanned, else nothing. Task 1 test `closed early, next drafted: nothing on the 1st`.
3. **Draft saved after the drafting push went out:** no second push that half, the closing push still comes on the 1st. Task 2 pgTAP.
4. **Release of a drafting-half claim:** must re-open that row, not the closing half's. Task 2 pgTAP and Deno handler test.
5. **Re-opening the draft:** `ClosePage` in the drafting half with October planned shows `PlanForm` alone, prefilled, no "Nothing to close" state. Task 3 widget test.

---

### Task 1: Dart window rule

**Files:**
- Modify: `lib/features/goals/domain/goal_rules.dart:17-47`
- Test: `test/features/goals/domain/goal_rules_test.dart`

**Interfaces:**
- Produces: `typedef PendingRitual = ({DateTime close, DateTime plan, bool closes, bool drafted});` `drafted` is true only in the last 3 days when `plan` already has a plan; then `closes` is false. `ritualWindow` keeps its signature.
- Rule: last 3 days of M → `closes: false` always; returns `drafted: plans has M+1`, never null. 1st–5th → as today (`closes` when M planned and open; null when not `closes` and M+1 planned), `drafted: false`.

- [ ] **Step 1: Update and add tests** in the `pendingRitual` group:
  - `'a planned month to close, then the next to plan'` moves to Oct 1: `pendingRitual(DateTime(2026, 10, 1), [planned(september)])` == `(close: september, plan: october, closes: true, drafted: false)`.
  - `'last 3 days: never closes'`: `pendingRitual(DateTime(2026, 9, 28), [planned(september)])` == `(close: september, plan: october, closes: false, drafted: false)`.
  - `'last 3 days, next drafted: still offered'`: Sep 30 with `[planned(september), planned(october)]` → `drafted: true, closes: false`.
  - `'February drafts from the 26th'`: `pendingRitual(DateTime(2027, 2, 26), const [])?.plan == DateTime(2027, 3)`; Feb 25 → null.
  - `'December drafts January'`: Dec 29 2026 → `plan == DateTime(2027)`.
  - `'the 1st, next drafted: still asks to close'`: Oct 1, `[planned(september), planned(october)]` → `closes: true, drafted: false`.
  - `'closed early, next drafted: nothing on the 1st'`: Oct 1, `[planned(september, closed: true), planned(october)]` → null.
  - Existing `'closed, next not planned: only the plan'` (Sep 30) and `'closed and the next planned: nothing left'` (Oct 3) keep passing with `drafted` added where records are compared.

- [ ] **Step 2: Run** `flutter test test/features/goals/domain/goal_rules_test.dart` — FAIL (record shape, new cases).

- [ ] **Step 3: Implement** in `goal_rules.dart`. Update the doc comments of `ritualWindow` / `pendingRitual` to the new halves. Fix every compile error the new field causes (`flutter analyze`); callers still read `closes` only.

- [ ] **Step 4: Run** the test file and `flutter analyze` — PASS, no issues.

- [ ] **Step 5: Commit** `feat(goals): draft in the last 3 days, close from the 1st (#354)`

---

### Task 2: SQL rule, per-half push claim, sender

**Files:**
- Create: `supabase/migrations/<timestamp>_draft_then_close.sql` (`supabase migration new draft_then_close`)
- Modify: `supabase/tests/month_ritual_test.sql`
- Modify: `supabase/functions/send-daily-summary/message.ts:29-35` (`RitualClaim`), `handler.ts` (`ritualJob`), `handler_test.ts`

**Interfaces:**
- `pending_ritual(p_owner uuid, p_on date)`: `create or replace`, same parameters and return. Drafting half (on/after the 3rd-to-last day): `closes` always false, a row only when `to_plan` has no `month_plan`. Closing half (day 1–5): unchanged. Header comment: mirror of `pendingRitual` minus `drafted` (a saved draft gets no push).
- `claim_month_rituals(p_now timestamptz default now()) returns table (owner_id uuid, to_close date, to_plan date, closes boolean, claim_date date)`: `drop function` then `create` (return type changes), same grants (`service_role` only, revoked from `public, anon, authenticated`). `claim_date` = `to_plan - 1` (last day of M) in the drafting half, `to_plan` in the closing half; it is the `notification_sent.local_date` claimed. Last day of M never collides with a closing half's 1st, and is younger than the 30-day cleanup while its half lasts.
- `release_month_ritual(p_owner uuid, p_plan date)`: unchanged; the sender now passes `claim_date` as `p_plan`. Update its comment to say so (name kept so the deployed sender keeps working between `db push` and `functions deploy`).
- `RitualClaim` gains `claim_date: string`; `ritualJob.release` uses `c.claim_date`.

- [ ] **Step 1: Rewrite the pgTAP cases** in `month_ritual_test.sql` (adjust `plan(n)`):
  - `pending_ritual` edges: Sep 28 with September planned and open → `('2026-09-01','2026-10-01', false)`; Sep 28 with October planned → no row; Oct 1 with September open and October planned → `closes = true`; Feb 26 2027 opens, Feb 25 2027 empty; Oct 5 last, Oct 6 empty.
  - Claims: `'2026-09-28 17:00Z'` claims A, B, C with `closes = false` and `claim_date = '2026-09-30'`; next run and Sep 29 claim nothing; `'2026-10-01 17:00Z'` claims A again with `closes = true`, `claim_date = '2026-10-01'` (replaces "nor its second half").
  - Drafted after the drafting push: insert October's plan for A between the Sep 29 and Oct 1 runs; the Oct 1 run still claims A with `closes = true` (`'drafted after the push: the 1st still asks to close'`).
  - Release: `release_month_ritual(A, '2026-09-30')` on Sep 29 → claimed again on Sep 29 17:15Z; the Oct 1 row untouched. Keep the 3-attempt cases on the closing half.
  - Grants: `claim_month_rituals` not executable by `authenticated`.

- [ ] **Step 2: Run** `supabase test db` — FAIL on the new cases.

- [ ] **Step 3: Write the migration** per Interfaces.

- [ ] **Step 4: Run** `supabase db reset && supabase test db` — PASS (schema_rls_test included).

- [ ] **Step 5: Sender.** Deno test in `handler_test.ts`: `ritualJob` release receives `claim_date` (`'2026-09-30'`), not `to_plan`. Run `deno test` — FAIL, implement, PASS.

- [ ] **Step 6: Commit** `feat(goals): one month-end push per half (#354)`

---

### Task 3: The drafted line on Today and Goals

**Files:**
- Modify: `lib/features/goals/presentation/ritual_card.dart` (add `DraftLine`)
- Modify: `lib/features/today/presentation/today_page.dart:558-590`
- Modify: `lib/features/goals/presentation/goals_page.dart:110-180`
- Modify: `lib/l10n/app_en.arb` (after `ritualStart`)
- Test: `test/features/today/today_goals_test.dart`, `test/features/goals/presentation/goals_page_test.dart`, `test/features/goals/presentation/close_page_test.dart`

**Interfaces:**
- Consumes: `PendingRitual.drafted` (Task 1).
- Produces: `class DraftLine extends StatelessWidget { const DraftLine({required this.month, required this.onTap, super.key}); final DateTime month; final VoidCallback onTap; }`, laid out like `GoalLine` (muted `bodyLarge`, `chevron_right_rounded`, whole row `InkWell`, `Semantics(button: true)`).
- Copy: `"ritualDrafted": "{month}'s plan is drafted. Change it before the 1st."`, placeholder `month` `DateTime` `MMMM`, description: "One line on Today and Goals in the last 3 days of a month, once next month's plan is saved; opens it again." `"ritualDraftedOpen": "Change the plan"` for `onTapHint`.
- Rule at every place that shows `RitualCard` today: `ritual.drafted ? DraftLine(month: ritual.plan, onTap: onRitual) : RitualCard(...)`. Today mobile: under the goal line, `AppSpacing.sm` above, instead of the card's `AppSpacing.md`. Desktop side columns: the line in the card's place. Goals' `showRitual` condition unchanged.

- [ ] **Step 1: Widget tests**
  - Today, Sep 30, September planned, October planned: finds `"October's plan is drafted. Change it before the 1st."`, no `Start`; tapping calls `onRitual`.
  - Today, Sep 28, October unplanned: `"Plan October"` card with `Start`, no "Close September".
  - Goals mobile and desktop, Sep 30, drafted: the line, no card.
  - `ClosePage(day: DateTime(2026, 9, 30))` with September open and October planned (`ownVolumeTarget: 2800`): `PlanForm` shown with no step label, field prefilled `2 800`, no "Nothing to close".
  - Existing tests that expected "Close September" on Sep 28–30 move to Oct 1–5.

- [ ] **Step 2: Run** the three test files — FAIL.

- [ ] **Step 3: Implement** `DraftLine`, the ARB keys, `flutter gen-l10n` (or `flutter pub get`), the wiring.

- [ ] **Step 4: Run** the three files plus `flutter test test/previews_test.dart` — PASS (golden diffs only from changed previews, to regenerate through CI).

- [ ] **Step 5: Commit** `feat(goals): a saved draft shrinks to one line (#354)`

---

### Task 4: Step 2 says it starts from the draft

**Files:**
- Modify: `lib/features/goals/presentation/plan_page.dart` (`PlanForm` header, near `l10n.closeStep` at :278)
- Modify: `lib/l10n/app_en.arb`
- Test: `test/features/goals/presentation/close_page_test.dart`

**Interfaces:**
- Shown when `step != null && month.plan != null` (closing flow, a plan saved before). Muted caption style, under the step title.
- Copy: `"planFromDraft": "Started from your draft. Change anything, then save."`, description: "Under the title of step 2 of closing a month, when next month's plan was drafted before the 1st."

- [ ] **Step 1: Widget tests:** `ClosePage(day: DateTime(2026, 10, 1))`, September open, October planned: after step 1's Next, finds `planFromDraft` text and the draft's `2 800`; same without October's plan: text absent.
- [ ] **Step 2: Run** — FAIL.
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run** `close_page_test.dart` — PASS.
- [ ] **Step 5: Commit** `feat(goals): step 2 starts from the draft (#354)`

---

### Task 5: Docs and gate

**Files:**
- Modify: `docs/superpowers/specs/2026-10-02-goals-design.md` and `2026-10-13-month-end-push-design.md`: one line each where the window / "once per window" is described, "Changed by `2026-10-18-draft-then-close-design.md` (#354)".

- [ ] **Step 1:** Edit the two lines.
- [ ] **Step 2:** `dart format .`, `flutter analyze`, `flutter test`, `supabase test db`, `deno test` (in the function dir) — all green.
- [ ] **Step 3:** `graphify update .`
- [ ] **Step 4: Commit** `docs(goals): point older specs at draft-then-close (#354)`
- [ ] **Step 5:** PR body: **Ticket** `Closes #354`; **Database**: replaces `pending_ritual`, recreates `claim_month_rituals` (service_role only); `supabase db push` then `supabase functions deploy send-daily-summary` right after; independent of the app release; safe for the released app (old app keeps its own card rule; between push and deploy the old sender's release of a drafting-half claim is a no-op).

# Today chip and repeating reminders Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A Today choice first in the reminder day field, and reminders that repeat exactly like tasks (#486).

**Architecture:** One additive migration adds the task repeat columns to `reminder`; `complete_reminder` keeps its signature and rolls a repeating row forward instead of deleting it; two new RPCs skip one occurrence and undo a repeating tick. On the client, the task repeat rule, its line and its form block move to `lib/core/repeat/`, the scope dialog moves to `lib/core/ui/`, and the reminder form, repository, controller and rows use them.

**Tech Stack:** Flutter, Riverpod, Supabase (Postgres, pgTAP via `supabase test db`).

**Spec:** `docs/superpowers/specs/2026-11-12-repeating-reminders-design.md`

## Global Constraints

- AGENTS.md applies: `package:loomia/...` imports, Material from `package:material_ui/material_ui.dart`, theme tokens only, no new dependency.
- Copy: English in `lib/l10n/app_en.arb` only, every new key with a description; never edit other `.arb` files. **Keep existing `taskRepeat…` keys and reuse them for reminders** (renaming would drop the French translations). No duplicate English strings.
- Migration additive only: no dropped/renamed column, no changed function signature, no edit of an applied migration. `complete_reminder(uuid, date)` keeps its exact signature (`create or replace`).
- Every new function: `security invoker set search_path = ''`, `revoke execute ... from public, anon`, `grant execute ... to authenticated`.
- Goldens: never commit locally made goldens; regenerate through CI (README → Golden tests).
- Commits: Conventional Commits, branch `feature/486-reminder-today-repeat`.
- Quality gate before claiming done: `dart format .`, `flutter analyze` ("No issues found!"), `flutter test`, `supabase test db`.

## Review Focus

1. **Last tick then Undo**: a reminder whose tick ended its schedule (row deleted) must come back with its rule after Undo. → Task 1 pgTAP `undo after the end`, Task 3 controller test.
2. **Old-build edit on a repeating reminder** (writes only `text`, `due_on`): must act as a postpone, never break `reminder_repeat_whole`. → Task 1 pgTAP `plain update keeps rule`.
3. **Undo after the rolled reminder was edited** (e.g. text changed on the person page before tapping Undo): refused, history entry kept. → Task 1 pgTAP.
4. **Turning repeat off on edit**: all five columns cleared, ticking then deletes the row. → Task 4 widget test.
5. **Today chip when the reminder's day is today**: Today chip selected, not Pick a day; editing a past-due reminder selects Pick a day. → Task 4 widget test.

---

### Task 1: Migration — repeating reminders

**Files:**
- Create: `supabase/migrations/<timestamp>_repeating_reminders.sql` (via `supabase migration new repeating_reminders`)
- Test: `supabase/tests/repeating_reminders_test.sql`

**Interfaces:**
- Produces (SQL):
  - columns on `public.reminder`: `repeat_every int check (between 1 and 99)`, `repeat_unit text check (in ('day','week','month','year'))`, `repeat_from date`, `repeat_until date`, `scheduled_on date`; constraint `reminder_repeat_whole` (same body as `task_repeat_whole`); `grant update (repeat_every, repeat_unit, repeat_from, repeat_until, scheduled_on) on public.reminder to authenticated`.
  - `public.repeat_next_on(p_every int, p_unit text, p_from date, p_until date, p_scheduled date, p_on date) returns date` — stable; same algorithm as `task_next_on` in `20261026201738_repeating_tasks.sql` (null when `p_every` is null or the schedule ended). Leave `task_next_on` untouched.
  - `public.complete_reminder(p_reminder uuid, p_on date) returns public.person` — replaced, same signature: P0002 when gone; inserts the `reminder` activity as today; if repeating and `repeat_next_on(...)` non-null, `update ... set due_on = next, scheduled_on = next`; else delete.
  - `public.skip_reminder(p_reminder uuid, p_on date) returns void` — P0002 when gone or not repeating; moves to next as above with no activity, or deletes when the schedule ended.
  - `public.undo_repeating_reminder(p_reminder uuid, p_person uuid, p_text text, p_due_on date, p_created_at timestamptz, p_repeat_every int, p_repeat_unit text, p_repeat_from date, p_repeat_until date, p_scheduled_on date, p_on date, p_updated_at timestamptz) returns void` — finds the entry and checks the person exactly as `undo_reminder` (`20261024202500_undo_tick.sql`). Then: row with `p_reminder` exists and `updated_at = entry.created_at` and `due_on = scheduled_on` → set `due_on = p_due_on, scheduled_on = p_scheduled_on`; row absent → insert it with id, person, text, `due_on`, `created_at` and the rule; else P0002. Deletes the entry in the success cases.

- [ ] **Step 1: Write the pgTAP test** following `supabase/tests/repeating_tasks_test.sql` (users a/b, `set local role authenticated`, `request.jwt.claims`). Cases, each one `ok`/`is`/`throws_ok`:
  - tick of monthly reminder due 2027-01-31 (from 2027-01-31) on 2027-01-31 → same id, `due_on = scheduled_on = 2027-02-28`, one `reminder` activity on 2027-01-31; tick again on 2027-02-28 → 2027-03-31.
  - postponed (`due_on` 2027-02-05, `scheduled_on` 2027-02-03, monthly from 2027-01-03) ticked 2027-02-05 → 2027-03-03.
  - late tick: monthly from 2027-03-03, ticked 2027-04-10 → 2027-05-03.
  - `repeat_until` 2027-02-15, weekly from 2027-02-10, tick on 2027-02-10 → row gone, activity written.
  - plain reminder tick → row gone (unchanged behaviour).
  - `skip_reminder` → next day, no activity; on last occurrence → row gone; on plain → `throws_ok '...', 'P0002'`.
  - `undo_repeating_reminder` after a roll → `due_on`/`scheduled_on` restored, activity gone.
  - **undo after the end** (row deleted by the tick) → row back with same id and rule, activity gone.
  - undo after `update reminder set text = 'x'` → `P0002`, activity kept.
  - plain update of `text, due_on` on a repeating row (old build) → succeeds, rule kept.
  - user b ticking/skipping a's reminder → `P0002`.
  - `reminder_repeat_whole`: insert with `repeat_every` but no `repeat_unit` → `throws_ok ... '23514'`.

- [ ] **Step 2: Run** `supabase test db` — Expected: the new file fails (functions/columns missing); others pass.
- [ ] **Step 3: Write the migration** per Interfaces, header comment in the style of `20261026201738_repeating_tasks.sql` stating it is additive and what an old build does.
- [ ] **Step 4: Run** `supabase db reset && supabase test db` — Expected: all files pass, including `schema_rls_test.sql`.
- [ ] **Step 5: Commit** `feat(reminders): repeating reminders in the database`

### Task 2: Shared repeat and scope dialog (refactor, no behaviour change)

**Files:**
- Create: `lib/core/repeat/repeat.dart`, `lib/core/repeat/repeat_fields.dart`
- Move: `lib/features/calendar/presentation/scope_dialog.dart` → `lib/core/ui/scope_dialog.dart`
- Modify: `lib/features/tasks/domain/task.dart`, `task_row.dart`, `task_sheet.dart`, `task_page.dart`, `task_repository.dart`, calendar `event_form.dart`, `event_page.dart`, previews using `RepeatUnit`, `lib/l10n/app_en.arb`
- Move test: `test/features/tasks/presentation/repeat_line_test.dart` → `test/core/repeat/repeat_line_test.dart`; Test: `test/core/ui/scope_dialog_test.dart` (new, small)

**Interfaces:**
- Produces:
  - `repeat.dart`: `enum RepeatUnit { day, week, month, year }`; `typedef Repeat = ({int every, RepeatUnit unit, DateTime from, DateTime? until, DateTime scheduledOn});` (renamed from `TaskRepeat`, all task code updated).
  - `repeat_fields.dart`:
    - `String repeatLine(AppLocalizations l10n, Repeat repeat)` (moved from `task_row.dart`, body unchanged).
    - `class RepeatFields extends StatelessWidget` — `const RepeatFields({required bool on, required ValueChanged<bool>? onOn, required TextEditingController every, required RepeatUnit unit, required ValueChanged<RepeatUnit> onUnit, required DateTime? until, required ValueChanged<DateTime?> onUntil, required DateTime from, VoidCallback? onEvery, super.key})`; builds what `_repeatFields` builds today (switch, every + unit, line from `from`, Ends Never/On with its date picker, first day `from`). Returns a `Column` with `AppSpacing.ms` spacing matching the current sheet layout. `_unitLabel` and `_pickUntil` move inside.
    - `Future<(Repeat?,)?> repeatToSave(BuildContext context, {required bool on, required Repeat? old, required DateTime? oldDay, required DateTime day, required Repeat Function(DateTime from) ruleFrom, required ScopeWording wording})` — the logic of `_repeatToSave` in `task_sheet.dart` minus the done-task branch (stays in the task sheet). Null: cancelled.
  - `scope_dialog.dart`: `enum ScopeWording { event, task, reminder }`; `pickScope(context, {bool delete = false, bool ruleChanged = false, ScopeWording wording = ScopeWording.event, Set<EventScope> losesReport = const {}})` replacing the `task` bool. `reminder` uses new keys `reminderScopeChangeTitle`, `reminderScopeDeleteTitle`, `reminderScopeThis` ("This reminder"), `reminderScopeFollowing` ("This and following reminders"), `reminderScopeRuleChanged` — English modelled on the `taskScope…` values.

- [ ] **Step 1: Move and rename** (no new behaviour); task sheet uses `RepeatFields` and `repeatToSave(..., wording: ScopeWording.task)`.
- [ ] **Step 2: Add** `test/core/ui/scope_dialog_test.dart`: `pickScope(wording: ScopeWording.reminder)` shows "This reminder" and "This and following reminders"; `delete: true` shows the delete title.
- [ ] **Step 3: Run** `flutter analyze && flutter test` — Expected: no issues; all existing task, calendar and golden tests pass unchanged (layout identical).
- [ ] **Step 4: Commit** `refactor(tasks): share the repeat rule, its fields and the scope dialog`

### Task 3: Reminder data and controller

**Files:**
- Modify: `lib/features/contacts/domain/person.dart`, `lib/features/contacts/data/people_repository.dart`, `lib/features/contacts/presentation/people_controller.dart`, every `Reminder` record literal (previews, tests)
- Test: `test/features/contacts/fake_people_repository.dart`, `test/features/contacts/presentation/people_controller_test.dart`, `test/features/contacts/data/` if a row-mapping test exists

**Interfaces:**
- Consumes: `Repeat`, `RepeatUnit` (Task 2); RPCs (Task 1).
- Produces:
  - `Reminder` gains `Repeat? repeat` (null: doesn't repeat).
  - `PeopleRepository`: `_reminderColumns` adds the five columns; `reminderFromRow` maps them as `taskFromRow` does; `addReminder(String personId, String text, DateTime dueOn, {Repeat? repeat})` and `updateReminder(String id, String text, DateTime dueOn, {Repeat? repeat})` write the five columns (null clears; new: `repeat_from = scheduled_on = dueOn` is the caller's rule); `Future<void> skipReminder(String id, DateTime on)` → `skip_reminder`; `undoReminder` calls `undo_repeating_reminder` when `reminder.repeat != null`, else `undo_reminder` as today.
  - `PeopleController`: `addReminder(Person, String, DateTime, {Repeat? repeat})`, `editReminder(Person, Reminder, String, DateTime, {Repeat? repeat})`, `Future<void> skipReminder(Person person, Reminder reminder, DateTime today)`; `completeReminder`/`skipReminder`/`undoReminder` keep the optimistic list change for plain reminders and, for a repeating one, reload (`invalidateSelf`) instead of patching.
  - Fake repository: mirrors the server (roll forward with a Dart port of `repeat_next_on` kept in the fake only; records `skipReminder(id)`, `undoReminder(id)`).

- [ ] **Step 1: Failing tests** in `people_controller_test.dart`: `completes a repeating reminder: it stays, on its next day` (monthly from 2027-01-31 ticked 2027-01-31 → `dueOn == DateTime(2027, 2, 28)`); `skips a repeating reminder` (calls contain `skipReminder(r1)`, `dueOn` moved, no history); `undo of the last tick brings back the rule` (until reached, tick, undo → reminder back with `repeat != null`).
- [ ] **Step 2: Run** `flutter test test/features/contacts` — Expected: FAIL (no `repeat` field).
- [ ] **Step 3: Implement** per Interfaces; fix every `Reminder` literal with `repeat: null`.
- [ ] **Step 4: Run** `flutter analyze && flutter test` — Expected: PASS.
- [ ] **Step 5: Commit** `feat(reminders): read, write, skip and undo repeating reminders`

### Task 4: Reminder form — Today chip, repeat, scope

**Files:**
- Modify: `lib/features/contacts/presentation/reminder_sheet.dart`, `lib/l10n/app_en.arb`
- Test: `test/features/contacts/presentation/reminder_sheet_test.dart`, `test/features/contacts/presentation/log_activity_sheet_test.dart`

**Interfaces:**
- Consumes: `RepeatFields`, `repeatToSave`, `pickScope(wording: ScopeWording.reminder)` (Task 2); controller methods (Task 3).
- Produces: new key `reminderToday` ("Today", description: first day choice for a reminder).

- [ ] **Step 1: Failing widget tests:**
  - `offers Today first`: chips in order Today, Tomorrow, In 3 days, In a week, In 2 weeks, Pick a day; tapping Today saves `dueOn == today()`.
  - `editing a reminder due today selects Today`; `editing a past-due reminder selects Pick a day`.
  - `saves a repeat`: switch on, every 1 month → `people.reminders['p1']!.single.repeat` has `unit == RepeatUnit.month`, `from == scheduledOn == dueOn`.
  - `day change on a repeating reminder asks the scope`: "This reminder" keeps `repeat.from`; "This and following reminders" moves `from` and `scheduledOn` to the new day.
  - `turning repeat off clears it`: `repeat == null` after save.
  - `delete on a repeating reminder asks the scope`: "This reminder" → calls contain `skipReminder`; "This and following reminders" → `deleteReminder`. Plain reminder Delete unchanged (no dialog).
  - `log_activity_sheet_test.dart`: Remind me shows Today first and no Repeat switch.
- [ ] **Step 2: Run** `flutter test test/features/contacts/presentation/reminder_sheet_test.dart` — Expected: FAIL.
- [ ] **Step 3: Implement**: `ReminderDayField._presets = [0, 1, 3, 7, 14]`, `0 => l10n.reminderTomorrow` becomes `0 => l10n.reminderToday, 1 => l10n.reminderTomorrow`; Pick a day selected only when no preset matches (unchanged). Form state and save flow as the task sheet (Task 2 helpers), `ruleFrom` from `_day`. Default day stays tomorrow.
- [ ] **Step 4: Run** `flutter analyze && flutter test` — Expected: PASS.
- [ ] **Step 5: Commit** `feat(reminders): Today first, and a reminder can repeat`

### Task 5: Repeat shown on reminder rows

**Files:**
- Modify: `lib/features/contacts/presentation/next_step_section.dart`, `lib/features/today/presentation/today_page.dart`, `lib/l10n/app_en.arb`, contacts/today previews (add one repeating reminder)
- Test: `test/features/contacts/presentation/contact_details_test.dart` (or the next-step test that renders reminders), `test/features/today/today_page_test.dart`

**Interfaces:**
- Consumes: `repeatLine` (Task 2).
- Produces: new key `todayReminderRepeats` ("Reminder · {repeat}", placeholder `repeat` = the `repeatLine` text; description says it replaces `todayReminderDetail` on a repeating reminder).

- [ ] **Step 1: Failing tests:** person page: a repeating reminder row has an `Icons.repeat_rounded` icon with semantics label "Every month on the 3rd"; plain one has none. Today: a repeating reminder row's detail reads "Reminder · Every month on the 3rd".
- [ ] **Step 2: Run** the two test files — Expected: FAIL.
- [ ] **Step 3: Implement**: person page `ActionItem(tag: ...)` with the same `Icon` as `repeatIcon` in `task_row.dart` (Today's `tag` already holds the stage chip, hence the detail line there). Add a repeating reminder to the previews.
- [ ] **Step 4: Run** `dart format . && flutter analyze && flutter test` — Expected: PASS except golden diffs for changed previews.
- [ ] **Step 5: Commit** `feat(reminders): show a reminder repeats`; push, open PR (template: Ticket `Closes #486`, Database: `supabase db push` at merge by the Release workflow, safe for the released app — old build's Undo after ticking a repeating reminder says it can't be undone; no Edge Function deploy), then regenerate goldens through CI per README.

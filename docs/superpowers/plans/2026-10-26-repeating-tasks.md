# Repeating tasks — plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [x]`) syntax for tracking.

**Goal:** a task can repeat every *n* days, weeks, months or years, ending
never or on a date; ticking it makes the next one on the schedule; one task
can be postponed or the schedule moved; Undo takes back the next one too.
**Architecture:** six nullable columns on `task` and three SQL functions
(`complete_task`, `undo_task`, `delete_task`) that do the date maths and the
two writes in one transaction. The app never computes a next date; after a
repeating tick, undo or delete it reloads the list.
**Tech Stack:** Flutter, Riverpod (no codegen), Supabase (Postgres, pgTAP).
**Spec:** `docs/superpowers/specs/2026-10-26-repeating-tasks-design.md`.
Figma: section "Repeating tasks — #376" (node 442:13872).

## Global Constraints

- Migration additive only (nullable columns, new functions, a widened
  column grant). `supabase db push` before or with the app release.
- No new dependency. No colour, radius, spacing or font size literal in a
  widget.
- Copy in `lib/l10n/app_en.arb` only, every key described, informal register,
  ICU plurals; no concatenated translated pieces.
- `package:material_ui/material_ui.dart`, `package:loomia/...` imports.
- Goldens regenerated through CI only (README → Golden tests).
- Issue #376, branch `feature/376-repeating-tasks` off `origin/main`.

## Rulings made while planning

- **Unit stored as text** (`'day' | 'week' | 'month' | 'year'`), mapped to a
  Dart `enum RepeatUnit` by name. The SQL step is
  `make_interval(days => n)` / `weeks` / `months` / `years`.
- **Next date in SQL**: smallest `k ≥ 1` with
  `repeat_from + k × step > greatest(scheduled_on, p_on)`, found with
  `generate_series` capped at 100 000 (a daily rule from far back still
  ends). Always counted from `repeat_from`, so the month-end clamp never
  drifts (Jan 31 → Feb 28 → Mar 31).
- **Plain tasks keep the plain path**: `setDone` (one-column update) for
  non-repeating tasks, so #375's tick, undo and Calendar untick stay as they
  are. Only `task.repeat != null` goes through `complete_task`.
- **Undo for a repeating tick** calls `undo_task`, not `setDone(null)`; the
  same function serves the Calendar's untick of a crossed-out task that
  still carries a rule.
- **Scope dialog**: `pickScope` gains a `ScopeCopy` parameter (title,
  this, following, rule-changed note). Events pass the existing strings,
  tasks new ones; `EventScope` is reused as is.
- **Edit save on a repeating task** sends one `update` with the rule columns;
  no RPC: the "This task" / "following" choice only decides which of
  `due_on`, `scheduled_on`, `repeat_from` the app writes.

## Review Focus

- `complete_task` with a postponed task, a late tick, an early tick, an
  end date reached; `undo_task` against an edited or ticked next one.
- The form's save matrix (day changed × rule changed × repeat turned off).
- No regression on plain tasks (#375 tests untouched and green).

### Task 1: Migration and SQL tests

- [x] `supabase migration new repeating_tasks`; in it:
  - the `alter table` and `task_repeat_whole` constraint from the spec's
    *Data*; `create index task_follows_id_idx on public.task (follows_id)`;
  - `grant update (title, note, due_on, done_on, repeat_every, repeat_unit,
    repeat_from, repeat_until, scheduled_on) on public.task to
    authenticated` (no `follows_id`);
  - `public.task_next_on(t public.task, p_on date) returns date`
    (`stable`, `security invoker`): the ruling above; null
    when past `repeat_until`;
  - `complete_task(p_id uuid, p_on date) returns public.task`: `select ...
    for update` (raise `P0002` if not found or not open), set `done_on`; if
    repeating and `task_next_on` is not null, insert the next with `title`,
    `note`, the rule, `due_on = scheduled_on = next`, `follows_id = p_id`.
  - `undo_task(p_id uuid) returns void`: clear `done_on`; delete the
    `follows_id = p_id` row when `done_on is null and updated_at =
    created_at`; if none was deleted, null the five rule columns on `p_id`.
  - `delete_task(p_id uuid, p_on date, p_following boolean) returns void`:
    when repeating and not following, insert the next as above (with
    `follows_id` null, nothing to undo) then delete `p_id`; else delete.
  - all three `security invoker`, `set search_path = ''`, `revoke execute
    ... from public, anon`, `grant execute ... to authenticated`, as in
    `20261024202500_undo_tick.sql`.
- [x] `supabase/tests/repeating_tasks_test.sql` (pgTAP, two users as in
  `tasks_test.sql`), every case listed in the spec's *Data*, plus: a plain
  task through `complete_task` makes nothing; `follows_id` not updatable by
  `authenticated`.
- [x] Run against a local DB (apply migrations with `psql` if `supabase db
  reset` still fails on the first one), and `schema_rls_test.sql`.

### Task 2: Domain

- [x] Test first, `test/features/tasks/domain/task_test.dart`: `Task`
  without a rule has `repeat == null`; `taskFromRow` reads the columns
  (in the repository test, Task 3).
- [x] `lib/features/tasks/domain/task.dart`:
  `enum RepeatUnit { day, week, month, year }`;
  `typedef TaskRepeat = ({int every, RepeatUnit unit, DateTime from,
  DateTime? until})`; on `Task`: `final TaskRepeat? repeat`,
  `final DateTime? scheduledOn`; `TaskDraft` gains `TaskRepeat? repeat` and
  `DateTime? scheduledOn`. Every existing `Task(...)`/draft call keeps
  compiling (named, optional).

### Task 3: Repository and controller

- [x] Tests first against `test/features/tasks/fake_task_repository.dart`
  (extend it: `complete`, `undo`, `deleteTask(following:)` record calls and
  return a canned list) and a controller test: a repeating `setDone`
  goes to `complete` then reloads; a plain one still goes to `setDone`.
- [x] `task_repository.dart`: `_columns` adds `repeat_every, repeat_unit,
  repeat_from, repeat_until, scheduled_on`; `add`/`update` write them from
  the draft (nulls when no repeat); `complete(id, on)`, `undo(id)`,
  `delete(id, {DateTime? on, bool following = true})` call the RPCs,
  `guardPeople` around each. `taskFromRow` builds `repeat` when
  `repeat_every` is set.
- [x] `tasks_controller.dart`: `setDone` routes a repeating open task to
  `complete` and a repeating done one to `undo`, then `ref.invalidateSelf()`
  and awaits the reload; `remove(id, {following})` likewise.

### Task 4: Scope dialog wording

- [x] Test first: `test/features/calendar/presentation/scope_dialog_test.dart`
  (new) shows the task copy when given it; existing event page tests stay
  green.
- [x] `scope_dialog.dart`: `typedef ScopeCopy = ({String change, String
  delete, String one, String following, String ruleChanged})`;
  `pickScope(..., ScopeCopy? copy)` defaults to the event strings.
- [x] ARB keys `taskScopeChangeTitle`, `taskScopeDeleteTitle`,
  `taskScopeThis` ("This task"), `taskScopeFollowing` ("This and following
  tasks"), `taskScopeRuleChanged`.

### Task 5: Repeat block in the form

- [x] Widget tests first, `test/features/tasks/presentation/task_sheet_test.dart`:
  switch off by default; on shows "Repeats every", 1, week, the line and
  Never; number rejects 0 and 100; unit menu changes the line; Ends On picks
  a date not before the day; save of a new repeating task writes
  `repeat.from == scheduledOn == dueOn`; edit with only the day changed asks
  the scope, "This task" writes `dueOn` only, "following" writes all three;
  rule changed skips "This task"; repeat off clears it; delete asks the
  scope and calls `remove(following:)`.
- [x] `task_sheet.dart`: `_repeat` state (`TaskRepeat?`), a `SwitchListTile`
  "Repeat" under `ReminderDayField`; when on, a row with a digits-only
  `TextFormField` (1–99, validator) and a `DropdownMenu<RepeatUnit>`, the
  `repeatLine` text, then a `RadioGroup` Never / On with a day field
  (`ReminderDayField`, `firstDate` = the task's day, disabled when Never,
  hint "Pick a day" as mocked). `_save` and `_delete` apply the spec's
  *Saving an edit* matrix, calling `pickScope(copy: taskScopeCopy)`.
- [x] `repeatLine(l10n, TaskRepeat, MaterialLocalizations)` in `task_row.dart`
  next to the row: "Every month on the 3rd", "Every 2 weeks on Thursday",
  "Every year on March 3", "Every 3 days". Unit test for each unit and
  plural in `test/features/tasks/presentation/repeat_line_test.dart`.
- [x] ARB: `taskRepeat`, `taskRepeatsEvery`, `taskRepeatUnit` (ICU
  `{count, plural}` per unit inside a `select`), `taskRepeatLine*`,
  `taskRepeatEnds`, `taskRepeatNever`, `taskRepeatOn`,
  `taskRepeatEveryInvalid`, `taskRepeatIcon` (semantics "Repeats {line}").

### Task 6: Row icon, tick and Undo

- [x] Widget tests first: Today and the Calendar show the repeat icon on an
  open repeating task and not on a plain or done one; ticking a repeating
  task shows Undo and the next one appears; Undo removes it
  (`test/features/today/…`, `test/features/calendar/presentation/…`, next to
  the #375 task tests).
- [x] `task_row.dart`: when `task.repeat != null && !task.done`, an
  `Icons.repeat_rounded` after the title with the semantics label (via
  `ActionItem`'s trailing-on-name slot if it has one, else a small
  `name` widget variant; check `action_item.dart` first, no new pattern if
  the event row already does it).
- [x] `toggle_task.dart`: Undo calls `setDone(task, null)` as before; the
  controller already routes it to `undo` (Task 3).

### Task 7: Previews, checks, PR

- [x] Today and task-sheet previews: "Restock lavender" repeating monthly
  on the 3rd beside "Order flyers", as in the Figma frames.
- [x] `dart format .`, `flutter analyze` (No issues found!), `flutter test`.
- [ ] Commit, push `feature/376-repeating-tasks` (separate commands, literal
  branch), PR with `Closes #376` and the Database section (`supabase db
  push` needed, before or with the release, safe for the released app).
- [ ] Regenerate goldens through CI, check them against the Figma frames,
  commit them.

## Changed while implementing

- **`scheduledOn` lives in `TaskRepeat`**, not on `Task`: it exists only
  with a rule, so the record is whole or absent like the SQL constraint.
- **Scope dialog**: a `task: true` flag on `pickScope` picks the task
  strings, instead of a `ScopeCopy` record. Five strings, one caller.
- **Repository names**: `complete`, `undo`, `deleteRepeating`; the
  controller's `removeRepeating`. The functions' P0002 (task gone or
  already in that state) is swallowed: the controller reloads either way.
- **`undo_task`** clears the old task's rule only when a next one exists
  and was kept. If none was ever made (the repeat had ended), the old task
  keeps its rule, so it is back exactly as before.
- **Unit menu**: the menu lists the units as words (day, week, month, year,
  as mocked); the closed field reads them after the number ("months" after
  3), via `selectedItemBuilder`.
- **Day of the month**: an ordinal through `taskRepeatDayOfMonth`, a
  `select` on the day, so other languages write their own ("1er").
- **Repeat icon**: one `repeatIcon(context, task)` in `task_row.dart`,
  used by `TaskRow` and by Today's own task rows. Not on the desktop
  month's one-line task chips, where it would cut the title further.
- **No task-sheet preview**: #375 has none; the form is covered by its
  widget tests. Today and Calendar previews get one repeating task each.
- **Figma**: the token for the Figma MCP had expired while implementing,
  so the form follows Claude Code's description of the frames, not a read
  of them.

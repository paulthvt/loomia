# Repeating tasks — design

Issue: [#376](https://github.com/paulthvt/loomia/issues/376) (ticket 2 of 4
after #375). Figma: section "Repeating tasks — #376" on page "04 — Screens
(Light)" (node 442:13872). Builds on tasks
(`2026-10-25-tasks-design.md`, Non-goals 2), undo a tick
(`2026-10-24-undo-tick-design.md`) and editing repeating events
(`2026-10-19-edit-repeating-events` plan, the scope dialog).

## Intent

Some tasks come back: "restock lavender" every month on the 3rd. Today the
user has to add each one by hand, or keep them in Google Tasks. A repeating
task is ticked like any other, and ticking it makes the next one.

The schedule is fixed by the rule, not by when she gets to it. In her words:
due on the 3rd, if she can't do it that day she moves it to the 5th, and the
next one is still on the 3rd of the next month.

## Goals

- Set a repeat on a task: every *n* days, weeks, months or years, ending
  never or on a date.
- Ticking a repeating task makes the next one, on the next day the rule
  gives.
- Postpone one task without moving the schedule, or move the schedule.
- Undo a tick, including the next task it made.

## Non-goals

- A time on a task, alerts (#377).
- Upcoming occurrences shown ahead in the Calendar.
- Several weekdays in one weekly rule (Google's "Mon, Thu"): two tasks.
- "Ends after N occurrences".

## Decisions

| Question | Decision | Reason |
| --- | --- | --- |
| What makes the next one | Ticking. One open task per repeat, Google Tasks style. | The issue. Nothing to generate ahead, nothing piles up. |
| Next due day | The first day of the schedule strictly after both the task's scheduled day and the day it is ticked. | A postponed task (3rd → 5th) keeps the next one on the 3rd. A late tick skips the dates it missed: March ticked on April 10 makes May 3, not a late April. One late task on Today is enough. |
| Rule | **Repeats every** [1–99] [day / week / month / year]. | The Google Tasks form she uses (screenshot in the issue thread). Covers every 3 months and every day with no special case. |
| Day of the rule | The task's day: a week repeat keeps its weekday, a month repeat its day of the month, a year repeat its date. A 31st falls on the last day of shorter months and goes back to the 31st after. | No "Starts" field: it is the task's day. Counting every date from the start of the schedule (`repeat_from + k × step`) gives the clamp for free in Postgres. |
| Ends | **Never** (default) or **On** a date. When the next day would be after it, ticking makes nothing and the task is a plain one. | "After N" would count ticked tasks only, since missed dates are skipped: confusing. |
| Calendar | Only the real task, on its due day, with a repeat icon. Same on Today's row. | The icon says it comes back. Showing upcoming ones would put a dot on every week of a weekly task, forever. Can be added later, faded, if missed. |
| Changing the day | On a repeating task, Save asks **This task** (postpone: the schedule is unchanged) or **This and following tasks** (the schedule now counts from the new day). Only when the day changed. | Both are reasonable; she knows this dialog from repeating events (#299). Her example, postpone, is the preselected choice. |
| Changing the rule | Applies from this task on, no dialog. With a day change in the same save, the dialog opens with only "This and following" on, as for events. | Nothing else exists yet, so there is nothing for "this task" to spare. |
| Turning repeat off | Repeat off in the form; the task becomes a plain one. | |
| Delete | Asks **This task** (it goes, the next one is made as if it had been ticked, without the tick) or **This and following tasks** (it goes, the repeat ends). One dialog, its red Delete is the confirmation, as for events. | |
| Tick | One RPC, `complete_task`: sets `done_on` and inserts the next task, in one transaction. Plain tasks keep the one-column update. | If the app made two writes and was killed between them, the repeat would end silently. |
| Rule on a ticked task | Kept on the row, but a ticked task shows no repeat icon and its rule is never read again unless it is unticked. | Undo then only has to delete the next task: nothing to copy back. |
| Undo (snackbar) and untick (Calendar ring) | Same RPC, `undo_task`: clears `done_on`. If the task it made is still open and never edited, deletes it: the old task is back exactly as before. If it was ticked or edited, keeps it and clears the old task's rule, so it comes back as a plain task and there is still one open task per repeat. | Undo must not destroy work done on the next one. "Never edited" is `updated_at = created_at`: the insert sets both in one transaction. No value to carry from the tick, so the Calendar untick (which has none) works the same way. |
| Released app | Additive columns only. A build with #375 but not #376 ignores them: ticking a repeating task there is a plain tick, and no next one is made. | Harmless: the task is still ticked, only the repeat stops until the app updates. |

## Data

One additive migration on `task`:

```sql
alter table public.task
  add column repeat_every int check (repeat_every between 1 and 99),
  add column repeat_unit text
    check (repeat_unit in ('day', 'week', 'month', 'year')),
  add column repeat_from date,      -- the schedule counts from this day
  add column repeat_until date,     -- null: never ends
  add column scheduled_on date,     -- the day the rule gave this task
  add column follows_id uuid references public.task on delete set null,
  add constraint task_repeat_whole check (
    (repeat_every is null) = (repeat_unit is null)
    and (repeat_every is null) = (repeat_from is null)
    and (repeat_every is null) = (scheduled_on is null)
    and (repeat_every is not null or repeat_until is null)
    and (repeat_until is null or repeat_until >= repeat_from)
  );
```

- `due_on` stays the day the task shows. Postponing changes `due_on` only.
- `follows_id`: set on the task a tick made, pointing to the ticked one, so
  `undo_task` finds it. Index on `follows_id`.
- Grants: add the six columns to `grant update (...)` except `follows_id`
  (set only by the functions).
- `complete_task(p_id uuid, p_on date) returns task`: owner check, sets
  `done_on = p_on`. If repeating: next = first `repeat_from + k × step`
  (`step` = `repeat_every` × the unit as an `interval`) strictly after
  `greatest(scheduled_on, p_on)`; if `repeat_until` is null or next ≤ it,
  inserts a task with the same title, note and rule, `due_on = scheduled_on
  = next`, `follows_id = p_id`. The ticked task keeps its rule. Returns the
  ticked task. `security invoker`, RLS applies.
- `undo_task(p_id uuid) returns void`: clears `done_on`. If the task with
  `follows_id = p_id` is open and `updated_at = created_at`, deletes it.
  Otherwise (ticked, edited or already deleted) clears the rule columns on
  `p_id`.
- `delete_task(p_id uuid, p_on date, p_following boolean)`: if repeating and
  not `p_following`, makes the next one as `complete_task` would, then
  deletes `p_id`. Otherwise just deletes.
- `p_on` is the device's today, as in `complete_reminder`.
- pgTAP (new `supabase/tests/repeating_tasks_test.sql`): month-end clamp
  (Jan 31 → Feb 28 → Mar 31), postponed task keeps the schedule, late tick
  skips, early tick, `repeat_until` reached, undo deletes an untouched next,
  undo keeps an edited or ticked next, delete one vs following, another
  owner's task refused, the check constraint. `schema_rls_test.sql` passes.

Database summary for the PR: `supabase db push` needed, before or with the
app release; safe for the released app (new nullable columns and new functions).

## Behaviour

**Form** (new and edit task):
- Under the day: a **Repeat** switch, off by default. On, it shows
  "Repeats every" [number, 1–99, default 1] [unit menu: day / week / month /
  year, default week], then **Ends**: Never / On [date]. The On date picker
  is Cupertino on iOS, Material elsewhere, and can't be before the task's day.
- Units read as plurals after the number ("every 3 months"); ICU plurals,
  and in French the unit's gender ("toutes les 2 semaines", "tous les 3
  mois") via `select`.
- A line under the block says what it means, e.g. "Every month on the 3rd",
  "Every 2 weeks on Thursday", "Every year on March 3".
- Saving a new repeating task: `repeat_from = scheduled_on = due_on`.

**Saving an edit** of a repeating task:
- Day changed, rule unchanged: the scope dialog. This task → `due_on` only.
  This and following → `due_on = scheduled_on = repeat_from` = the new day.
- Rule changed (with or without the day): no "This task".
  `repeat_from = scheduled_on` = the task's day (new day if changed).
- Repeat turned off: the six columns cleared.
- Nothing about the day or the rule changed: plain save.

**Rows:** a repeat icon (`Icons.repeat_rounded`, as on repeating events)
after the title on Today and in the Calendar, with a semantics label
("Repeats every month"). Not on ticked tasks.

**Tick and Undo:** the #372 snackbar, unchanged copy. Undo and the Calendar
untick both call `undo_task`. After either, the tasks are read again, since
the server may have added or removed a row.

**Scope dialog:** `pickScope` in `scope_dialog.dart` takes its wording from
the caller (event or task) instead of fixed event strings; event behaviour
unchanged.

## Code

- `lib/features/tasks/domain/task.dart`: a `TaskRepeat` record (`every`,
  `unit`, `from`, `until`) and `scheduledOn` on `Task`; a pure
  `repeatLine(...)` for the form line and the icon's label.
- `task_repository.dart`: `complete`, `undo`, `delete(following:)` call the
  RPCs; reads and writes the new columns.
- `task_sheet.dart`: the Repeat block; the scope dialog on save and delete.
- `task_row.dart`: the icon.
- `toggle_task.dart` / `tasks_controller.dart`: repeating ticks through the
  RPC, then a reload.
- Copy in `app_en.arb` only, each key described.

## Testing

- Unit: `repeatLine` for each unit, plural, month-end day.
- Widget: the form (switch, number bounds, unit menu, Ends date), saving
  postpone vs following, rule change skips the dialog, delete one vs
  following, the repeat icon on Today and in the Calendar, tick then Undo
  reloads.
- pgTAP: listed under *Data*.
- Goldens for any new `@Preview`, through CI.

## To mock

Section "Repeating tasks — #376" on "04 — Screens (Light)", from the #375
task sheet (section "Tasks — #375", node 430:13589). Existing components and
variables only, apart from what's listed as new.

1. **Task sheet, mobile, Repeat off:** the #375 edit sheet with a Repeat
   switch row under the day.
2. **Task sheet, mobile, Repeat on:** "Repeats every" [1] [month ▾], the line
   "Every month on the 3rd", Ends: (•) Never ( ) On [date, disabled].
3. **Same, unit menu open:** day / week / month / year, "month" selected.
4. **Today, mobile:** the Tasks section with "Restock lavender" showing the
   repeat icon after its title, next to a plain task.

New pieces: the number field + unit menu row, the Ends radio group. Desktop,
dark mode and French not mocked; check « Se répète tous les » fits in the
first build.

## Left to the builder

- Number field: text field with digits only, or a stepper.

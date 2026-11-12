# Today chip and repeating reminders — design

Issue: [#486](https://github.com/paulthvt/loomia/issues/486). Builds on
reminders (`2026-10-08-reminders-design.md`), undo a tick
(`2026-10-24-undo-tick-design.md`) and repeating tasks
(`2026-10-26-repeating-tasks-design.md`), whose behaviour this copies.

## Intent

The issue, from the main tester: when she adds a reminder on a person by
hand, "Today" isn't offered, and she'd like it first. And she'd like a
reminder to be able to repeat. No concrete case yet; the decision is to
behave exactly like repeating tasks, which she already uses.

## Goals

- A **Today** choice, first, in the reminder day field.
- A repeat on a reminder: every *n* days, weeks, months or years, ending
  never or on a date, with the same rules as repeating tasks.
- Ticking a repeating reminder writes the history entry and moves the
  reminder to its next day.
- Postpone one occurrence, or move the schedule; delete one occurrence or
  the whole repeat; undo a tick.

## Non-goals

- Repeat in Log something's **Remind me** (it keeps the day field only,
  Today included). Set the repeat on the reminder afterwards.
- Upcoming occurrences shown ahead anywhere.
- Anything tasks don't do (several weekdays, "after N times").

## Anti-goals

- A reminder that silently stops repeating on the current build.
- Undo that destroys an edit made after the tick.

## Decisions

| Question | Decision |
| --- | --- |
| Today chip | Presets become Today · Tomorrow · In 3 days · In a week · In 2 weeks · Pick a day. Default stays Tomorrow. Applies to both users of `ReminderDayField` (reminder form and Remind me). |
| Rule, next day, ends | Exactly as tasks: **Repeats every** [1–99] [day/week/month/year], **Ends** Never / On [date]; the next day is the first of the schedule (`repeat_from + k × step`) strictly after both the reminder's scheduled day and the tick day; month-end clamp; late tick skips missed dates. |
| What a tick does | One reminder row per repeat, **kept with its id**: the tick inserts the history entry (as today) and moves the row to the next day (`due_on = scheduled_on = next`). Schedule ended: the row is deleted, as a plain tick. Unlike tasks (which keep the ticked row as done), a ticked reminder has no row of its own; history keeps it. |
| Changing the day | Save on a repeating reminder whose day changed asks **This reminder** (postpone: `due_on` only) or **This and following** (`due_on = scheduled_on = repeat_from` = new day). Rule changed: no "This reminder", as tasks. |
| Delete | Repeating: the scope dialog, its red Delete is the confirmation. **This reminder**: moves the row to its next day with no history entry (deleted if the schedule ended). **This and following**: deletes the row. Plain reminder: unchanged. |
| Undo (snackbar) | Removes the entry and puts the reminder back exactly as before the tick, rule included. The client calls the repeating undo whenever the ticked reminder had a repeat, passing the pre-tick reminder (rule included), since it can't tell whether the tick ended the schedule. Row still there and untouched since the tick (on the day the tick gave it, not edited): reset its `due_on` and `scheduled_on`. Row gone because the tick ended the schedule: re-insert it with the same id and rule. Otherwise (edited, ticked again, deleted by the user, or a row with that id still exists but was touched): refused, the existing "can't undo" path. *Builder's-check call: undo of the last tick restores the repeat.* |
| Rows | Repeat icon (`Icons.repeat_rounded`) after the text with the "Every month on the 3rd" semantics label, on the person page's reminder rows and Today's reminder rows, as task rows. |
| Released app | Additive migration. `complete_reminder` keeps its signature, so an old build ticking a repeating reminder gets the roll-forward too (it hides the row until it reloads). Old build's Undo on such a tick hits `undo_reminder`, which refuses because the row still exists: a clean "can't undo" until the app updates. Plain reminders unchanged on every build. |

## Data

One migration (`supabase migration new repeating_reminders`):

- `reminder` gets `repeat_every`, `repeat_unit`, `repeat_from`,
  `repeat_until`, `scheduled_on`, same types and checks as on `task`, and a
  `reminder_repeat_whole` constraint like `task_repeat_whole`. No
  `follows_id`: the row is kept. Grant update on the five columns.
- The next-day computation: reuse `task_next_on`'s logic. It takes a
  `public.task` row, so either add a generic
  `repeat_next_on(every, unit, from, until, scheduled, on)` and have the
  reminder functions call it (leave `task_next_on` as is), or copy it as
  `reminder_next_on(public.reminder, date)`. Builder's call; the generic one
  is preferred.
- `complete_reminder(p_reminder, p_on)` replaced (`create or replace`, same
  signature): entry as today, then roll forward or delete.
- `skip_reminder(p_reminder uuid, p_on date)`: Delete → This reminder.
- `undo_repeating_reminder(...)`: the undo above. Its parameters are the
  builder's; it must also check the person as `undo_reminder` does.
- Grants/revokes as the existing functions. `schema_rls_test.sql` passes.
- pgTAP `supabase/tests/repeating_reminders_test.sql`: roll forward, month
  clamp, postponed keeps schedule, late tick skips, end reached deletes,
  skip, undo restores, undo of the tick that ended the schedule restores
  the row with its rule, undo refused after an edit, another owner's refused,
  the constraint, plain reminder tick unchanged.

PR Database section: `supabase db push` at merge (Release workflow); safe
for the released app as above; no Edge Function deploy.

## Code

- **Shared repeat**: `RepeatUnit`, the rule record (today `TaskRepeat`) and
  the line function (today `repeatLine` in `task_row.dart`) move out of
  `features/tasks` to one shared place (e.g. `lib/core/repeat/`), so tasks
  and reminders both use them. Rename the record if it reads better
  (`Repeat`); tasks keep their behaviour. The calendar has its own
  `repeatLine` in `event_row.dart`; leave it.
- The task form's repeat block (switch, every, unit, ends, line) becomes one
  widget used by the task form and the reminder form. Existing l10n keys
  (`taskRepeat…`) can be reused or renamed to neutral keys; builder's call,
  but no duplicate English strings.
- `pickScope`: worded for reminders too ("This reminder" / "This and
  following reminders"); turn the `task` bool into a choice of wording.
- `Reminder` record gains `repeat` (nullable). `people_repository.dart`
  reads/writes the columns, calls `skip_reminder` and
  `undo_repeating_reminder`. `people_controller.dart`: after a repeating
  tick, skip or undo, reload rather than patching the list.
- `reminder_sheet.dart`: Today preset (new l10n key with description), the
  repeat block, scope dialog on save and delete.
- Undo paths: `undo_tick.dart` and Today's undo call the repeating undo for
  a reminder that repeated.
- Tests: widget tests for the form (Today chip, repeat block, scope on
  save/delete), domain tests for anything moved. Changed previews: goldens
  regenerated through CI (README → Golden tests).

## Left to the builder

Function names and parameters, where the shared repeat code lives, l10n key
names, the exact undo staleness check (within the rule above).

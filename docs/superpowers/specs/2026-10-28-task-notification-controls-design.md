# Task notification controls — design

Issue: [#389](https://github.com/paulthvt/loomia/issues/389), before the task
page ([#390](https://github.com/paulthvt/loomia/issues/390)). Figma: section
"Task notifications — #389" on page "04 — Screens (Light)" (node 463:14966). Builds on a time on a task (`2026-10-26-task-time-design.md`) and
notifications (`2026-10-11-notifications-design.md`), whose rules hold unless
changed here.

## Intent

Since #377, any task with a time pushes at that time. Using it, Paul found
two things missing: a way to stop task pushes altogether, and a way to give a
task a time just to order Today, without being notified. A time says *when*;
whether it notifies is a separate choice.

## Goals

- A **Tasks** switch in Settings → Notifications that turns every task push
  on or off.
- A **bell** beside a task's time that says whether that task notifies.
- A task pushes only when both are on.

## Non-goals

- A push ahead of the time, quiet hours, buttons on the notification (as in
  #377).
- Showing the bell in Today's or the Calendar's rows.

## Anti-goals

- Existing users or tasks changing behaviour after the update: both default
  to on, so everything pushes as it does today until someone turns it off.
- A bell that looks on while nothing will push: with the Tasks switch off,
  the bell says so.

## Decisions

| Question | Decision | Reason |
| --- | --- | --- |
| Reverses #377's "no switch for task pushes" | Yes. A time is no longer the opt-in; the bell is. | Paul, after using it. |
| Approaches | Two columns, both default true: `notification_settings.task_enabled` and `task.alert`, read by `claim_task_alerts`. Rejected: storing "a time without a push" inside the time, which mixes up when and whether. | Additive, each value in one place. |
| Tasks switch default | On. | Matches what pushes today. |
| Tasks switch place | A third `SwitchListTile` in the first group, after the summary and the month-end push. | Same group as the other kinds. *(My call.)* |
| Time and days | Stay tied to the summary and the month-end push (`settings.any`); the Tasks switch doesn't enable them. | A task pushes at its own time. |
| Permission | Turning the Tasks switch on asks the phone's permission, like the other two. The "notifications are off on this phone" line shows when any of the three is on. | Same rule as the other kinds. *(My call: with the switch on by default, that line shows to anyone who refused permission, which is true: their timed tasks won't push.)* |
| Bell default | On when a time is added (a new time, or a time added again after removing it). Turned off, it stays off when the time or the day changes. | Paul. |
| Bell, no time | Not shown. The stored value is kept but unused. | Nothing to notify at. |
| Bell look | The ghost icon button (44 px tap area) right after the time chip: the bell in the accent colour when on, a crossed-out grey bell when off. Tooltips: **Don't notify me** (on), **Notify me at this time** (off). Icons: Figma's Icon/bell and Icon/bell-off, mapped to the app's icon set like the others. | Figma. |
| Copy | Settings row **Tasks**, subtitle **At the time set on a task, when its bell is on.** The line with the switch off: **Task notifications are off. Turn them on in Settings**, "Settings" the link. | Figma. |
| Tasks switch off | The bell shows greyed out and takes no tap, with the line "Task notifications are off" under the time, linking to Settings → Notifications, like the existing permission-off line. | Paul. |
| Permission refused | As now: the line saying notifications are off on this phone. When both apply, only the Tasks-switch line shows. | One line at a time; turning the switch on is the first step. *(My call.)* |
| Turning the bell on | Asks the phone's permission the first time, as adding a time does now. | |
| Bell turned on late | Turning the bell on doesn't clear the claim. A time that is still in its hour's window and wasn't pushed yet pushes at the next minute. | Rare, and she just asked for it. *(My call.)* |
| The claim | The bell stays out of `task_rearm_alert`: toggling it never touches `alerted_for`. A bell turned off and on again after its push doesn't push twice for that time. | `alerted_for` is "pushed for this time"; the bell doesn't change the time. *(My call.)* |
| When the bell saves | With the rest of the form, on Save, like the time chip. No write of its own. | *(My call.)* |
| Permission prompt | Asked on Save when the task goes from not notifying to notifying: a time and the bell on, where before it had no time or the bell off. Not again when it already notified. | Covers add-time, and bell off then on. *(My call.)* |
| Repeating tasks | The next task keeps the bell, like the time. | |
| No settings row | The Tasks switch shows on (the column's default) until a row exists, and the form treats no row as on: the bell isn't greyed. Setting a first time still creates the row, as in #377; `ensureFor` relies on the column default. | |
| Daily summary | Unchanged: it still counts open tasks, whatever the switch and the bells. | The switch is about task pushes, not the summary. *(My call.)* |
| Released app | The old app doesn't send `task_enabled` or `alert`, so they keep their values. Its new tasks get `alert = true`. | Safe. |

## Data

One additive migration:

- `notification_settings.task_enabled boolean not null default true`,
  updatable by the owner like the other switches.
- `task.alert boolean not null default true`, granted update like
  `due_time`.
- `complete_task` and `delete_task` copy `alert` to the next task, beside
  `due_time`.
- `claim_task_alerts` adds `s.task_enabled and t.alert` to its `where`.
- pgTAP: no claim when the switch is off or the bell is off; the next task
  keeps `alert`; the grants.

Database summary for the PR: `supabase db push` before or with the app
release; safe for the released app. The Edge Function doesn't change.

## App

- `NotificationSettings.tasks` (`task_enabled`); `copyWith`, `fromRow`,
  `toRow`, `==`. The form's switch.
- `Task.alert`, `TaskDraft.alert`; the repository reads and writes it.
- Task form: the bell after the time chip, its greyed state and line, which
  reads the settings provider the form already uses for permission.
- Copy in `app_en.arb` only, each key described: the switch's title and
  body, the bell's two tooltips, the switch-off line.

## Testing

- Unit: `NotificationSettings` row round-trip with `task_enabled`.
- Widget: the Tasks switch saves; the bell appears with a time and is on by
  default, toggles, hides without a time, stays off when the time changes,
  turns on again for a time added after removal; greyed with the line when
  the switch is off.
- pgTAP: listed under *Data*.


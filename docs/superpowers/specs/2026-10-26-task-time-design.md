# A time on a task — design

Issue: [#377](https://github.com/paulthvt/loomia/issues/377) (ticket 3 of 4
after #375, #376). Figma: section "Task time — #377" on page "04 — Screens
(Light)" (node 445:14163). Builds on tasks
(`2026-10-25-tasks-design.md`, Non-goals 3), repeating tasks
(`2026-10-26-repeating-tasks-design.md`) and notifications
(`2026-10-11-notifications-design.md`, whose rules hold unless changed here).

## Intent

Some tasks have a moment: "call the supplier at 14:00". The person who
asked expects her phone to tell her at that time. When it does and she's
busy, she dismisses it or puts it off a little.

## Goals

- An optional time on a task, set in the task sheet.
- A push at that time, give or take a minute, on her phones.
- From that push, postpone the task by 15 minutes or an hour in two taps.
- Timed tasks ordered by time on Today, their time shown, and in the
  desktop week's hour grid.
- The daily summary counts tasks too.

## Non-goals

- Buttons on the notification itself (Postpone, Done): they need the app to
  draw its own notifications, a new package and per-platform setup. Tapping
  the push opens the task instead.
- A push ahead of the time ("10 minutes before").
- Web push (none exists yet).
- Times on reminders or workflow steps.
- Quiet hours: every task push is at a time she picked.

## Anti-goals

- A push she didn't ask for. A task without a time never pushes; the time
  is the opt-in, for that task.
- A stale push: ticked, deleted or moved before its time, it doesn't go.

## Decisions

| Question | Decision | Reason |
| --- | --- | --- |
| Precision | Within a minute: a push at 14:00 or 14:01. | Her answer ("14:01 is good enough"). |
| Who sends | The server, as for the daily summary: pg_cron calls the Edge Function every minute instead of every 15. | Reuses FCM, works when the task was added on the web or another phone. A phone-scheduled alarm would be exact and offline but needs a new package, has no web, and misses tasks added elsewhere until the app opens. *(My call.)* |
| Time zone | The time is a wall-clock time in the user's `notification_settings.time_zone`, like the summary's 19:00. Never stored as a UTC instant. | Same DST rules as the summary. Travel follows the last device launched. |
| No settings row | Setting a first time on a task creates the `notification_settings` row with `summary_enabled = false` and the device's zone, if there is none, then asks the OS permission (`push.dart`). | The sender needs a zone; the push needs permission. Asking at the moment she sets a time is when it makes sense. |
| Today's nudge card | It asks while there is no settings row. Once a first time created the row (summary off), it no longer asks; the summary stays one switch away in Settings. | The card's own rule: either answer makes a row and it goes. Asking again about the summary right after she allowed task pushes would be a second prompt for the same permission. *(My call.)* |
| Permission refused | The time is saved and shown. Under the time, the sheet says notifications are off, linking to Settings → Notifications, as Settings already does. | The time still orders Today. |
| A switch for task pushes | None. A time is the opt-in for that one task. | Fewer settings; she sets a time because she wants the push. *(My call.)* |
| Catch-up | Sent by the first run in `[time, time + 1 h)` in her local wall clock. After that, never. | A missed run still delivers; a "call at 14:00" push at 17:00 is noise. *(My call: 1 h.)* |
| Once | A task's push is claimed before sending, for that day and time. Changing the day or time clears the claim, so the new time pushes again. Ticking or deleting stops it (only open tasks are claimed). | At most one push per task per time set. |
| Copy | Title: the task's title, as typed. Body: its note, or none. Sent as literal text, not a localisation key. | It's her own words; there's nothing to translate. |
| Lock screen | Shows the title and note. | Unlike the summary's rule of counts only: she wrote it and asked to be told. The summary keeps counts only. *(My call; tell me if a task title should stay hidden.)* |
| Tap | Opens the app on Today with that task's sheet open (`data: {type: "task", task: <id>}`). A task gone or done: just Today. | Where she can postpone, tick or edit. |
| Postpone | In the sheet of a task whose time has passed or is less than 15 minutes away: **In 15 min** and **In 1 hour**, from now, rounded up to the minute. A tap saves `due_on` and `due_time` and closes the sheet. Past midnight, the day moves too. Saving clears the claim, so the push comes at the new time, by the first run in its window. | Her answer: a fixed bit later. Further than an hour, she picks a time. |
| The field | Under the day, an **Add a time** chip. It opens the time picker (Cupertino on iOS, Material elsewhere, `pickTime`), starting on the next full hour. Set, the chip shows the time and an ✕ that removes it. | Planned in the tasks spec: a chip, not inside the date picker. |
| Today order | Late tasks first (oldest day first), as now. Then today's tasks without a time, in creation order. Then today's timed tasks, earliest first. | No time is "any time today", like an all-day event above the timed ones. Her answer, agreed. |
| Today chip | A timed task due today shows its time in the row's chip ("14:00", locale format). A late one keeps its "since Friday" chip. | One chip per row. |
| Calendar, day lists and desktop month | A timed task stays with the day's tasks, above the events, in the Today order, its time shown before the title in the month chip ("14:00 · Call the supplier") and as the chip in the lists. | Tasks stay together; the time says when. |
| Desktop week | A timed task leaves the all-day strip for the hour grid: a half-hour block at its time, with the ring and its title only, laid out with the events (`week_grid.dart` lanes). Untimed ones stay in the strip. | The issue. Half an hour: the shortest block that holds a title. Title only: the block's place gives the time, and the mock showed "14:00 · Call the sup…" cut even at full width. *(My call.)* |
| Repeating tasks | The next one keeps the time. | |
| Daily summary | Counts people and open tasks due today or late, with Today's headline wording: "3 people and 2 tasks today", "2 tasks today". Sent when either is above zero. | The issue. Today already says it this way. |
| Summary copy with two counts | One push key per combination, each with plain numbered arguments and no plural inside: `pushSummaryTasks_one/_other` (tasks only), and `pushSummaryBoth` in four forms (person one/other × task one/other). The sender picks the key from the two counts, as it picks `_one`/`_other` now; people only keeps today's keys. `tool/push_strings.dart` is unchanged. | The tool handles one plural per message; four fixed keys are simpler than teaching it two. Right for EN and FR. *(My call.)* |
| Old apps | A device gets only the push kinds its app lists (`push_kinds`), so a released app gets no task pushes. Its summary copy keeps counting people only: the sender picks the people-only key for a device that doesn't list `daily_summary_tasks`. | No push that the released app would render wrong. |
| Data | One additive migration. | Safe for the released app. |

## Data

- `task.due_time time` (null: no time). Grant update on it.
- `task.alerted_for timestamp` (no zone): the local day and time the push
  was claimed for; null when not sent. A trigger clears it when `due_on` or
  `due_time` changes. Not granted to `authenticated`.
- `complete_task` and `delete_task` (#376) copy `due_time` to the next task.
- `notification_kind` gains `'task_alert'`, and `'daily_summary_tasks'`:
  not a push of its own, but the marker in `device_token.push_kinds` (an
  array of that enum) that the app renders the summary's task counts.
- `claim_task_alerts() returns table (owner_id, task_id, title, note,
  alerted_for)`, `service_role` only: open tasks with a time, of owners
  with a settings row. With `local = date_trunc('minute', now() at time zone
  time_zone)` and `at = due_on + due_time`: `local >= at and local < at +
  interval '1 hour'`, and `alerted_for is distinct from at`. So a run at
  14:00:30 local claims a 14:00 task, and a 15:00 task waits for the 15:00
  run. Sets `alerted_for = at` and returns those it claimed (`update …
  returning`, so concurrent runs claim each once).
- `release_task_alert(p_task uuid, p_for timestamp)`: clears `alerted_for`
  when it still equals `p_for`, so it never clears a newer claim. Called by
  the job's `release` (a temporary FCM failure on every device), with the
  claim's own `alerted_for`; the next minute retries. No attempt cap: the
  hour's window bounds it.
- `due_people_count` stays; a `due_tasks_count(p_owner, p_on)` beside it.
  A new `claim_daily_summaries_with_tasks()` returns both counts for the new
  sender; the old `claim_daily_summaries` stays as it is until the old
  sender is gone (the function deploys after `db push`).
- pg_cron: the job moves from every 15 minutes to every minute. The summary
  and month-end claims are unchanged (their windows and per-date claims make
  extra runs harmless). That is about 43,000 Edge Function calls a month,
  under the free plan's 500,000. *(My call: one job, not one per kind.)*
- pgTAP: the window edges (13:59 no, 14:00 yes, 14:59 yes, 15:00 no), once
  only, moved time pushes again, done and deleted don't, another zone, DST
  (a 02:30 time on the spring-forward day goes at 03:00), the grants, and the
  summary counts.

Database summary for the PR: `supabase db push`, then `supabase functions
deploy send-daily-summary`, before or with the app release; safe for the
released app.

## Sender

`send-daily-summary` gets a third job, `taskJob`, kind `'task_alert'`, next
to `summaryJob` and `ritualJob`. Its message: `notification.title` = title,
`notification.body` = note, `data: {type: 'task', task: id}`. The summary
message picks the people-and-tasks keys when the device lists
`daily_summary_tasks`. Its Deno tests cover both. The function keeps its
name: renaming it means new Vault secrets.

## App

- `Task.dueTime` (`TimeOfDay?`); repository reads and writes `due_time`.
- `todayTasks` orders as decided; a unit test pins it.
- Task sheet: the chip, the notifications-off line, the postpone buttons.
- `push.dart`: `Push.opened` emits the message's `data` instead of nothing
  (today it maps every tap to `void` and `PushScope` always goes to Today).
  Summary and month-end taps keep going where they go now. `type: task`
  goes to Today and opens that task's sheet once the tasks have loaded; a
  task not in the list (deleted, or done) leaves just Today. In scope here.
- The app lists `task_alert` and `daily_summary_tasks` in `push_kinds` when
  it registers.
- Push strings: the new `push*` summary keys through `tool/push_strings.dart`.
- Calendar: the time in rows and month chips; the week grid's timed block.
- Copy in `app_en.arb` only, each key described.

## Testing

- Unit: `todayTasks` order; the postpone time (rounding, past midnight).
- Widget: the chip (add, change, remove), postpone shown only near or past
  the time, postpone saves and closes, the notifications-off line, Today's
  order and chips, a tap's data opening the sheet, the week grid block.
- pgTAP: listed under *Data*.
- Deno: the task message; summary keys by `push_kinds`.
- Goldens for new or changed previews, through CI.

## To mock

Section "Task time — #377" on "04 — Screens (Light)", from the #376 task
sheet (node 442:13872) and the #375 Today and desktop week frames. Existing
components and variables only, apart from what's listed as new.

1. **Task sheet, mobile, no time:** the **Add a time** chip under the day.
2. **Task sheet, mobile, a time set:** the chip reads "14:00" with an ✕.
3. **Task sheet, mobile, opened from the push:** the time has passed; at the
   top, **In 15 min** and **In 1 hour**.
4. **Same, notifications off:** under the time, "Notifications are off" with
   a link to Settings.
5. **Today, mobile:** the Tasks section with a late task, "Order flyers" (no
   time), then "Call the supplier" with a "14:00" chip.
6. **Desktop week:** "Call the supplier" as a half-hour block at 14:00 next
   to an event, one untimed task left in the all-day strip.

New pieces: the postpone buttons (their placement in the sheet), the
notifications-off line. Dark mode and French not mocked.

## Left to the builder

- Exact copy beyond the strings named here.
- Whether postpone is two buttons or two chips, within the mock.

# Tasks — design

Issue: [#375](https://github.com/paulthvt/loomia/issues/375) (ticket 1 of 4; later: #376 repeat, #377 time and alert, #378 what's next). Figma: section "Tasks — #375" on
page "04 — Screens (Light)" (node 430:13589): Today with the three sections,
the Calendar with task rows and hollow dots, the ＋ choice, the new and edit
task sheets. Builds on Today
(`2026-10-07-calendar-design.md`, `2026-09-29-today-due-steps` plan), the
reminders work (#217) and undo a tick (`2026-10-24-undo-tick-design.md`).

## Intent

Some of what a wellness advocate has to do involves nobody: "order flyers",
"restock lavender". Today, those live in another app (Google Tasks, for the
person who asked), so the morning means opening two apps. Tasks bring them
into Loomia, so Today answers "what should I do today?" in full.

The risk is confusion: Today already mixes workflow steps, reminders,
renewals, follow-ups and event steps. The answer is to group by **what an
item is about**, not by how the app made it: an event, a person, or nothing.
The user does not need to know a step from a reminder; she needs to know who
it is for.

Every task has a due day: the person who asked dates all of hers.

## Goals

- Create, edit, tick, untick and delete a task: a title, a due day, an
  optional note.
- Today shows the tasks due today or late, in their own section.
- The Calendar shows every task on its due day, so a task due next Thursday
  can be found and edited before Thursday.

## Non-goals (later tickets, in this order)

2. **Repeat.** Ticking a repeating task makes the next one, the chosen
   interval later (Google Tasks style, not an event series).
3. **Time and alert.** An optional time on a task, a push at that time, and
   the task in the desktop week's hour grid. Needs a way to notify at a
   chosen time, which does not exist yet (only the daily summary). In the
   sheet: an optional "Add a time" chip under the day, not inside the date
   picker. No time field before the alert exists.
4. **What's next.** Reminders and workflow steps in the Calendar on their
   days. Then: Today is what to do now, the Calendar is what's coming.

Also out: lists or categories, a dedicated tasks screen (add it if the
Calendar turns out not to be enough), tasks linked to a person (that is a
reminder), tasks linked to an event (that is an event step).

## Anti-goals

- Today must not read as three apps glued together: one ring, one tick, one
  row style across sections.
- No "productivity app" creep: no priorities, no tags, no subtasks.

## Decisions

| Question | Decision | Reason |
| --- | --- | --- |
| Today's sections | **Events**, **People**, **Tasks**, in that order. "Priority" is renamed "People"; what it lists does not change. | The grouping the person who asked described. She called the middle one "network"; "People" avoids the network-marketing tone the app stays clear of. Events stay first (they have a time); tasks last (they wait for no one). |
| Order in Tasks | Oldest due day first, then creation order. Late ones say since when ("since Friday"), like the rest of Today. | Same rule as People. |
| Late tasks | Stay on Today until ticked or moved. | Same as steps and reminders. |
| Headline | Counts people and tasks: "3 people and 2 tasks today", "2 tasks today" with only tasks; the people-only copy unchanged. ICU plurals. | It counts people today; a task has none. |
| Progress bar | Rows, as now: tasks ticked today count in done, open tasks in total. | "Each tick moves the bar." |
| Up to date | Only when there are no person rows and no tasks. | |
| Tick | The same ring. Ticking sets `done_on` to the device's today; the row leaves; the #372 snackbar shows "Done: {title}" with Undo, which clears `done_on`. | A task is kept after it is done, so undo is a one-column update; no RPC needed. |
| Ticked tasks | Gone from Today. In the Calendar, kept on their due day, crossed out. | A quiet record of what got done. |
| Calendar placement | On its due day, above that day's events, as an all-day row with the ring. Mobile list, desktop month and day list. In the desktop hour-grid week: in an all-day strip at the top of the day if the grid has one, otherwise the builder adds the smallest one that fits the grid. | Tasks have no time in this ticket. |
| Day markers | Open tasks count in the Calendar's markers: a dot on the mobile month grid and week strip (a hollow dot, so a day with only tasks reads differently from a day with an event), a line in the desktop month cell, above events, inside the same "+N more". Ticked tasks add no marker. | The goal is to find next Thursday's task without tapping each day. A done task needs no attention. (Call made while writing, not discussed.) |
| Ring in the Calendar | Works both ways. Ticking an open task crosses it out in place (it stays on its day) and shows the same Undo snackbar. Tapping the ring of a crossed-out task unticks it, with no snackbar. The done count is read again from the server when Today is next opened. | Same ring everywhere. Unticking a crossed-out task is already a one-tap undo. (Call made while writing, not discussed.) |
| Late tasks in the Calendar | On their due day only, not repeated on each day since. | Today carries late ones; the Calendar shows what was planned when. |
| Adding | The Calendar's ＋ asks **Event** or **Task**, then opens that form on the selected day. Today gets an "Add a task" action in the Tasks section (shown even when the section is empty, so a first task can be added from Today). | The Calendar is where she plans; Today is where she thinks of it. |
| Task form | Title (required, trimmed, not blank), day (defaults to the selected day, or today from Today; Cupertino picker on iOS, Material elsewhere), note (optional, multi-line). Same form for edit, with Delete. | |
| Editing | Tap the row, on Today or in the Calendar. | |
| Deleting | As deleting an event does today, for consistency. | |
| Daily push | Unchanged in this ticket: still counts people. | Changing its copy touches the push strings tool and the edge function; do it with ticket 3, which reworks task notifications anyway. |
| History | A task writes no activity entry. | History is per person; a task has none. |
| Data | One additive migration: table `task`. | Safe for the released app, which never reads it. |

## Data

```sql
create table public.task (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null default auth.uid()
    references auth.users on delete cascade,
  title text not null check (length(trim(title)) > 0),
  note text,
  due_on date not null,
  done_on date,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
```

- Index on `(owner_id, due_on)`.
- `set_updated_at` trigger, as `reminder`.
- RLS enabled, the four owner policies, `revoke all ... from anon,
  authenticated`, then `grant select, insert, delete` and `grant update
  (title, note, due_on, done_on)`, as in `20261008135516_reminders.sql`.
  `schema_rls_test.sql` must pass; add a pgTAP test for the policies.
- `done_on` is a device day, like `p_on` in `complete_reminder`.
- Account deletion: the cascade on `owner_id` covers it; check the
  `delete-account` function needs nothing more.

Database summary for the PR: `supabase db push` needed, before the app
release, safe for the released app (new table only).

## Code

- New feature `lib/features/tasks/{domain,data,presentation}`: a `Task`
  model, a repository behind a provider (Supabase access only there), the
  form, the row.
- Today: a `todayTasks(tasks, today)` pure function (open, due on or before
  today, ordered), the section, the headline and bar counts. The done count
  (`doneTodayProvider`, today from the activity log) adds tasks with
  `done_on` = today.
- Calendar: tasks per day next to `eventsPerDay`; the ＋ choice.
- Routes, if the form is a page on some screen sizes: in `routes.dart` first.
- Copy in `app_en.arb` only, each key described; informal register.

## Testing

- Unit: `todayTasks` (late, today, future, done), the headline counts.
- Widget: Today with tasks only, people only, both; tick and undo; the
  Calendar showing a future task and a ticked one crossed out, its hollow dot, ticking
  and unticking there; the ＋ choice;
  the form's validation.
- pgTAP: owner policies, the grants, the blank-title check.
- Goldens for any new `@Preview`, generated through CI.

## Left to the builder

- Exact copy beyond the strings above.
- The ＋ choice's form (menu, sheet), within Material on all platforms.
- The "show more" cap on the Tasks section, if any (People caps at 5/6).
- Whether the task form is a sheet or a page on each screen size, as the
  event form does.

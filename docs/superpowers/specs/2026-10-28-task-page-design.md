# Task page — design

Issue: [#390](https://github.com/paulthvt/loomia/issues/390), after the task
notification controls ([#389](https://github.com/paulthvt/loomia/issues/389),
whose bell this page shows). Figma: section "Task page — #390" on page
"04 — Screens (Light)" (node 465:15232). Builds on tasks
(`2026-10-25-tasks-design.md`), repeating tasks
(`2026-10-26-repeating-tasks-design.md`), a time on a task
(`2026-10-26-task-time-design.md`) and the desktop calendar
(`2026-10-22-calendar-desktop-design.md`).

## Intent

Tapping a task, or its push, lands on the edit form. Paul finds that
awkward: most of the time she wants to read the task, its note, or postpone
it, not change it. Events already work the right way: a tap shows the event,
and Edit is a button. Tasks should behave the same, everywhere.

## Goals

- Tapping a task on Today, in the Calendar, or its push opens a task page
  that shows it.
- Edit and Delete from that page.
- From the push, postponing is still two taps.
- On web, the page sits in the Calendar's side pane, like an event.

## Non-goals

- Editing in place on the page.
- Tasks linked to contacts or events.

## Anti-goals

- Ticking getting slower: the ring in the rows still ticks without opening
  anything.
- Two ways of showing a task: no read mode inside the dialog beside a page.

## Decisions

| Question | Decision | Reason |
| --- | --- | --- |
| View, not form | Every tap on a task opens the page; the form is reached from its Edit button, or by creating a task. | Paul: consistency with events. |
| Approaches | `TaskPage` and `TaskPane`, shaped like `EventPage` and `EventPane`, with their own route, opened by `openTask` like `openEvent`. Rejected: a read mode in the current dialog, cheaper but not a page and not a pane. | Paul chose a full page. |
| Phone | A page pushed over the screen it was opened from (Today or the Calendar); back returns there. | As events. |
| Web (desktop) | In the Calendar's side pane, like `EventPane`. A task opened from Today on desktop goes to the Calendar with the task in the pane, as an event from Today does. | `openEvent`'s rule. |
| Route | Nested under the Calendar like events, e.g. `/calendar/task/:id`, so back returns to the month. Exact path: builder's call, as long as it can't be taken for an event id. | |
| Content | Header: the title, with Edit and Delete icon buttons (as `EventView`). Then the ring, the day, the time with its bell (#389) when there is one, how it repeats when it does, and the note when there is one. | Paul agreed. |
| Postpone | **In 15 min** / **In 1 hour** right under the title, under the same rule as now (`alertNear`: time passed or less than 15 minutes away). A tap saves; the page stays and shows the new day and time, and the buttons go since the time is no longer near. | The title stays first, as in the #377 sheet (Figma). Staying: *my call*, it's a page now. |
| Postpone in the form | Removed from the form: the page has it, and the form is only reached from the page. | One place. *(My call.)* |
| Edit | Opens the existing task form over the page; on save the page shows the new values. | |
| Delete | The form's flow, moved to the page: a confirmation, or **This task** / **This and following tasks** for a repeating one. Then the page closes: popped on the phone, the pane cleared on desktop. | |
| Postpone's write | Its own save on the page, without the form's `Navigator.pop`; the page reads the task from `tasksProvider`, so it redraws with the new values. | The form's write paths all close it. |
| Ring on the page | Ticks and unticks, as the Calendar's ring does, with the Undo snackbar, on desktop too: the pane has no modal barrier, unlike the day popover that made the Calendar drop Undo on desktop. The page stays, showing the task ticked. | *(My call.)* |
| After Delete on desktop | As an event: `context.go(Routes.calendar)`, the month keeps the day it had selected. | Same precedent. |
| Layout | The Figma frames are the reference: a back link ("Back to calendar", "Back to Today"), the title with Edit and Delete, postpone when near, then the ring with the day, the time with its bell, the repeat, the note. Desktop: the 440 px pane with a left border, as the event pane. Not mocked, follow the rest: a ticked task, the page after postponing, "not found". | Figma. |
| Narrow month with the pane | With the pane open, day cells are about 98 px: titles cut and a cell may show "+1 more" sooner. Accepted, as with an event open. | |
| Push tap | Opens Today, then the task page over it, so back lands on Today. The `?task=` link stays; Today pushes the page instead of opening the form. | |
| Push tap, task done | Opens the page, showing it ticked. Deleted: just Today, as now. | Seeing it's done beats landing nowhere. *(My call.)* |
| Missing task | A task not in the list (deleted elsewhere) shows the same "not found" state `EventPane` shows for a missing event. | |
| Data | None. The page reads the task by id from `tasksProvider`, which already holds every task; every task, repeating or not, is a real row. | |

## App

- `Routes`: the task path and `taskLocation(id)`; the `GoRoute` beside the
  event's, in the same `_calendarPage` shape (pane on desktop, page
  elsewhere).
- `openTask(context, id)` beside `openEvent`.
- `TaskPage`, `TaskPane`, and a `TaskView` they share, like the event's.
- Today's task rows, the Calendar's day lists and desktop day popover, the
  desktop month chips and the week grid's task blocks call `openTask`
  instead of `showTask(editing:)`. Creating a task still calls `showTask`.
- Today's `_openFromPush` pushes the task page.
- The task form loses its postpone row and its Delete action.
- Copy in `app_en.arb` only, each key described: Edit and Delete tooltips,
  and whatever the view needs that existing keys don't cover.

## Testing

- Widget: a tap on a task on Today and in the Calendar opens the page, not
  the form; Edit opens the form and the page shows the saved values; Delete
  (plain and repeating) closes the page; postpone shown only near or past,
  saves and stays; the ring ticks with Undo; a push's `?task=` opens the
  page over Today, a done task shows ticked, a deleted one leaves Today;
  on desktop, the task opens in the Calendar's pane, from Today too; a
  missing id shows "not found".
- Goldens: a `@Preview` of `TaskView` (with a time, a repeat and a note).


# Undo a tick — design

Issue: [#372](https://github.com/paulthvt/loomia/issues/372). Figma: section
"Undo — #372" on page "04 — Screens (Light)"; the Snackbar component is on the
Components page. Builds on the ticks of `2026-10-07-calendar-design.md`
(Today), `2026-10-13-workflows-events-design.md` (event steps) and the
reminders and LRP renewal work (#317).

## Intent

A tick is one tap on a ring, and it is not a light write: the person moves to
their next step, a reminder is deleted, a history entry is written and counts
as a contact. A thumb that lands on the wrong row has no way back today. Every
tick should be take-backable for a few seconds, without slowing down the
person who ticks ten rows in a row on purpose.

## Decisions

| Question | Decision | Reason |
| --- | --- | --- |
| Pattern | A snackbar after each tick with **Undo**. | Material's pattern for an action that can be reversed. It costs nothing to the user who meant it: the row still leaves at once and the bar still moves. |
| When the write happens | At once, as today. Undo is a second write that reverses the first. | Holding the write until the snackbar closes (Gmail style) loses the tick if the app is killed in those seconds, and every screen would have to guess the server's next step meanwhile. Writing at once keeps every screen showing what the server holds. |
| Rejected: confirm dialog | No. | A dialog on every tick punishes the 99% of deliberate ticks. |
| Rejected: row stays ticked with Undo in place | No. | Rows lingering for 5 s make a ten-row run feel stuck, and Today's "row leaves, bar moves" is the reward. |
| Rejected: hold to tick | No. | Undiscoverable, and slower for everyone. |
| Duration | 5 s, then it goes; swipe to dismiss. With a screen reader on (`MediaQuery.accessibleNavigationOf`), it stays until dismissed: `persist: accessibleNavigation`. | `SnackBar.persist` defaults to on whenever there is an action, so without it Undo would never time out. A screen reader user needs time to reach the action. |
| Message | Per kind, the person first so a cut only shortens the task: step and reminder "Done for {name}: {task}"; LRP renewal "LRP checked for {name}"; event step "Done: {step}". | On a person's row the title is their name and the task is the subtitle. The LRP subtitle ("Claire's LRP renews on the 15th") reads badly after "Done:". An event step's row title is the step itself. |
| Action colour | Add `inversePrimary` to both schemes: light `#E0AB7B` (8.4:1 on `inverseSurface` `#201B16`), dark `#8A4A0F` (5.9:1 on `#F1EEEC`). | Unset, it falls back to `onPrimary`, white: the same as the message in light mode, invisible in dark mode. `primary` itself is 4.3:1 on the dark inverse surface, below AA. |
| Desktop width | 480 px, bottom centre of the content area, set on each snackbar when `context.screenSize` is desktop. | A theme width would also apply on mobile, and `SnackBar` refuses `width` together with `margin`. |
| Several ticks in a row | Each tick replaces the snackbar. Undo takes back the last tick only. | One snackbar at a time is the Material rule; a queue would lag behind the ticking. |
| What Undo restores | Everything the tick did: the step and its due day, the deleted reminder (same id, text, due day and `created_at`), the LRP renewal check, and the history entry. An LRP the step started (`loyalty_setup`) is stopped again: `loyalty_since`, `loyalty_day` and `loyalty_checked_for` back to null, its "LRP started" entry removed. | A half-undo (step back, history entry left) would count a contact that never happened. |
| Which history entry | Found by the tick's transaction, not its text. A step tick and an LRP check update the person, so their entry has `created_at = person.updated_at` (both are that transaction's `now()`). A reminder tick does not touch the person: its entry is the latest `reminder` entry for that person on that day with the reminder's text. No match: refused as stale, nothing changes. | Entries are editable, and `check_loyalty` writes the same `reminder` kind as a reminder tick, so text alone is fragile. |
| Stale undo | Refused (`P0002`) when the person changed since the tick: their `updated_at` is not the one the app holds after the tick (from the RPC's result for a step or LRP check, from the book for a reminder), or they were deleted. The snackbar says "That changed in the meantime, so it wasn't undone." | `updated_at` catches every edit: another device's tick, a move, a pause, a rename. Checking the person first also turns a deleted person into the stale message, not a foreign-key error. |
| LRP checked on two devices | Accepted: when another device checked the same renewal a moment earlier, `check_loyalty` writes nothing, and Undo here takes back that device's check. | Needs two devices on the same renewal within seconds; both meant the same check, and it is ticked again in one tap. Telling the cases apart needs a new `check_loyalty` return, a two-release change for this. |
| Event steps | Undo calls the existing `EventRepository.untick` (a delete on `event_step_done`). | An event-step tick writes no history entry and is not in the done-today count, so there is nothing else to put back. |
| Leaving the screen | Undo still works after leaving the screen the tick was on: the snackbar lives on the app's messenger and calls the shared providers, not the page. | Ticking on a contact then going back is normal. |
| Where | Today: plain steps, reminders, LRP renewals, event steps. Contact page: next step and reminders. Workflow timeline: Mark done on the current step. | Every ring that makes something leave. |
| Not covered | The event page's step checklist (the box stays and tapping it again unticks), Going / Followed up / Remove on a follow-up row, Mark as done on an event. | The checklist already undoes in place. The others are buttons with their own flow, not ticks; widen later if asked. |
| Data | One additive migration: `undo_step`, `undo_reminder`, `undo_loyalty_check`. | Each reverse runs in one transaction, like its tick. Safe for the released app, which never calls them. |

## Behaviour

### Snackbar

- One line, cut with "…", **Undo** on the right in `inversePrimary`
  (component styling in `app_theme.dart`'s `snackBarTheme`: `actionTextColor`).
- Floating, 10 px above the bottom navigation on mobile; 480 px wide at the
  bottom centre of the content area on desktop.
- Undo pressed: the snackbar goes; the row comes back where it was once the
  reverse lands (the book, the person's history and the done-today count
  reload); the bar moves back.
- Undo failed: a plain snackbar with the failure (`peopleFailureCopy`), or the
  stale message. Nothing else changes.
- A tick that fails shows its failure as today, with no Undo.

### Server

Each refuses with `P0002`, changing nothing, when the person is missing, is
not the caller's, or has an `updated_at` other than `p_updated_at`, and when
the history entry is not found.

- `undo_step(p_person, p_step, p_on, p_last_tick, p_updated_at)`, `security
  definer` with an owner check, like `set_loyalty`: the RLS delete policy on
  `activity` excludes `loyalty_start`. Also requires the person's position to
  be `position_after(p_step)`. Puts `at_position` back on the step and
  `last_tick` back to `p_last_tick` (the value the app held before the tick).
  Removes the `step` entry with `created_at = p_updated_at`; if a
  `loyalty_start` entry has that same `created_at`, the tick started the LRP:
  removes it and nulls `loyalty_since`, `loyalty_day`, `loyalty_checked_for`.
- `undo_reminder(p_reminder, p_person, p_text, p_due_on, p_created_at, p_on,
  p_updated_at)`, `security invoker`: also requires that no reminder has that
  id. Inserts it back with its id, text, due day and `created_at`, and removes
  its entry.
- `undo_loyalty_check(p_person, p_renewal, p_previous, p_updated_at)`,
  `security invoker`: also requires `loyalty_checked_for = p_renewal`. Puts
  `p_previous` back and removes the `reminder` entry with `created_at =
  p_updated_at`.

Grants: `revoke ... from public, anon`, `grant execute ... to authenticated`,
as for the ticks. `Person` gains `updatedAt` from `updated_at`, and `Reminder`
its `createdAt` if it doesn't carry it yet; both are already in the selects.

## Copy

| Key | EN | Description |
| --- | --- | --- |
| `tickDoneFor` | Done for {name}: {task} | Snackbar after ticking a step or reminder on someone; `task` is its text. |
| `tickDoneLoyalty` | LRP checked for {name} | Snackbar after checking someone's LRP renewal. |
| `tickDone` | Done: {task} | Snackbar after ticking an event step; `task` is the step. |
| `tickUndo` | Undo | Snackbar action that takes the tick back. |
| `tickUndoStale` | That changed in the meantime, so it wasn't undone. | Undo refused because the person changed since. |

French from Weblate.

## Delivery

Migration: additive (three new functions). `supabase db push` is needed and
must go before or with the app release, since the new build calls them. Safe
for the released app.

## Testing

- pgTAP (`supabase/tests/undo_tick_test.sql`): each tick then its undo leaves
  person, reminder and history exactly as before; a step that started the LRP
  clears all three LRP columns and its entry; each undo is refused (and
  changes nothing) after an edit to the person, for a deleted person, for
  another owner's person, and when the entry was deleted.
- Widget, Today: tick a step, a reminder and an LRP renewal, press Undo, the
  row is back and the count back down; tick an event step, Undo, the row is
  back; two ticks then Undo restore only the second; a stale undo shows the
  stale message; Undo times out after 5 s and persists with
  `accessibleNavigation`.
- Widget, contact page: tick the next step, Undo, the same step is back; tick
  a reminder, leave the page, Undo still restores it. Workflow timeline: Mark
  done, Undo.
- Unit: `inversePrimary` passes AA on `inverseSurface` in both schemes (the
  existing contrast test).

## Figma

Mocked in "Undo — #372": mobile just ticked ("Done: Call back about the
diffuser", Sarah's reminder), mobile with a long reminder cut with "…", and
desktop at 1440 (480 px, bottom centre). The frames predate the per-kind
message: the reminder one reads "Done for Sarah: Call back about the diffuser"
in the build. Dark mode, French and the failure snackbars are not mocked.

# What's next in the Calendar — design

Issue: [#378](https://github.com/paulthvt/loomia/issues/378) (ticket 4 of 4
after #375–#377). Figma: section "What's next — #378" on page "04 — Screens
(Light)" (node 450:14616). Builds on tasks
(`2026-10-25-tasks-design.md`, Non-goals 4), the Calendar
(`2026-10-07-calendar-design.md`, `2026-10-19-calendar-week-view-design.md`,
`2026-10-22-calendar-desktop-design.md`) and Catch up
(`2026-10-15-catch-up-design.md`, its folded summary).

## Intent

On a Sunday evening, the person who asked wants to see what's coming in the
next days: not only events and tasks, but the people she'll follow up. It's
for looking, not for doing. Then: Today is what to do now, the Calendar is
what's coming.

## Goals

- The people due on a day — their workflow step, reminders, LRP renewal
  check, invitation follow-ups — show in the Calendar on that day.
- The month grid and week strip mark a day with people due, quietly.
- Folded by default, as one line ("5 people to follow up"); open, one row
  per person.

## Non-goals

- Ticking from the Calendar: Today is where things are done.
- Postponing a step or reminder (wanted later: its own ticket).
- Steps after the next one: they have no date until the current one is
  ticked.
- Late items on the days since: Today carries them.

## Anti-goals

- A Calendar that reads as a to-do list: people are quieter than events and
  tasks, folded, and never take an event's place in a crowded day.

## Decisions

| Question | Decision | Reason |
| --- | --- | --- |
| What counts | Due items whose day is the shown day: `DueStep` (`step.due`), `DueReminder`, `DueLoyalty` (its day, `renewal − loyaltyRenewalAhead`), `DueFollowUp` (`followUpOn`). Not `DueNext` (it is a reaction to a tick, never ahead). A paused person's step falls out, their reminders stay, as Today. | The same rules as Today's People section (`dueToday`), per day instead of "on or before". |
| Which days | Today and later. Past days show no people. Today shows only what is due today, not late. | Late ones live on Today; the Calendar shows what was planned when, as for tasks (#375). |
| Grouping | Per person: a person with a step and a reminder on Thursday is one person. | "5 people" counts people, as Today's headline. |
| Folded | The day's People block is Catch up's pattern: a "PEOPLE" `SectionHeader` with **Show** / **Hide**, then the summary card or the rows. It starts folded: a card with the avatars (`LoomiaAvatarGroup`, 3 + "+N") and "5 people to follow up", like Catch up's summary (`check_in_items.dart`). Tap or **Show** opens it; **Hide** folds it. Folded again when another day is selected. | Her answer: the count is enough, names one tap away. |
| Open | One row per person, `ActionItem` with their avatar, name, and what's due ("Send a first message"; several: the first, then "+1"). No ring. Tap: their contact page. | Informational: no tick. The contact page is where she'd act from the Calendar. |
| Order | People rows by name, as Today on one day. The block sits after the day's tasks and before its events on mobile. | Tasks and people are both "to do that day"; events keep their time order below. *(My call.)* |
| Grid marker | Mobile month grid and week strip: a short muted line under the dots, one per day with anyone due, whatever the count: 12 × 2 px, `textMuted`, 2 px under the dots row, the cell's height unchanged. It doesn't take one of the three dot places. Past days: none. | Her ask: a day with something to do must show it, but quieter than events and tasks. A third dot kind would crowd them. |
| Desktop month | At the top of the day cell, a muted "5 people" line (no ring, no colour bar), above tasks and events, one row in the "+N more" count. Tapping it opens the day's popover, which lists the People block (open). | Same as mobile, in the cell's own vocabulary. |
| Desktop week | "5 people" in the top strip, above the day's tasks; tap opens the day's popover. People have no time, so not on the hour grid. The strip now shows when any day has tasks or people. | |
| Mobile week list | Each day of the list gets the same People block, folded, after its tasks and before its events. A day with only people is not "Nothing planned". Not mocked. | The strip marks the day; without the block the names would only be in the month view. *(My call.)* |
| Desktop popover | The day's popover shows the People block open, no Show / Hide, as Catch up's desktop column. Not mocked. | The popover is already the "one tap away". |
| Screen readers | The day's label adds the count: "Thursday 8, 2 events, one task, 5 people". | Every marker is also said. |
| Data | None new: people, workflows and events are loaded the same way as on Today (the Calendar now watches the first two too). No migration. | |

## Code

- `lib/features/today/domain/due.dart`: `dueOn(people, workflows, day,
  {events})` — the Due items whose day is exactly [day] (local midnight,
  today or later; empty for a past day), sorted as `dueToday`, and
  `peopleDueOn` grouping them per person. `dueToday` unchanged. Per kind,
  where `dueToday` says "on or before today", `dueOn` says "on [day]":
  - **Step:** `progressOf(...)` is an `OnStep` and `step.due == day`. A
    paused, done or workflow-less person falls out, as in `dueToday`.
  - **Reminder:** `reminder.dueOn == day`.
  - **LRP renewal:** `loyaltyRenewal(person, day)` gives renewal `R` (this
    month's or next month's, as of [day], unless already checked for it),
    and `day == R − loyaltyRenewalAhead`: the check shows on the first day
    of its window, the day Today starts asking. *(My call: Today keeps
    asking until `R`; the Calendar shows it once, when it starts.)*
  - **Follow-up:** `attendee.followUpOn == day` and the event's day is not
    before [day]. `followUpOn` is the invite (or last follow-up) + 3 days,
    so it is often in the future.
  - Not `DueNext`.
  Unit tests beside `due_test.dart`.
- `lib/features/calendar/domain/`: per-day counts of people for the
  markers (`peoplePerDay(people, workflows, events, from, to)`), today and
  later only.
- Calendar presentation: the People block (reusing Catch up's summary card
  and `ActionItem`), the mobile marker in `month_grid.dart` and
  `week_view.dart`, the desktop month line and week strip line in
  `desktop_calendar.dart`, the semantics label.
- **Desktop month cell:** the "N people" line is the first entry of the
  cell's measured chip list, with its own `heightFor`, so `chipsThatFit`
  and "+N more" count it like any chip (it is the first kept, being first).
- **Wiring:** `calendar_page.dart` only invalidates `peopleProvider` today.
  It now watches `peopleProvider(owner)` and `workflowsProvider(owner)` (as
  Today does) and passes the lists down. While either loads or fails, the
  Calendar shows no people and no markers for them; events and tasks are
  unaffected.
- **Folding:** one bool in the day section's state, reset to folded
  whenever the selected day changes. Nothing is remembered per day.
- Copy in `app_en.arb` only: "{count, plural, =1{One person to follow up}
  other{{count} people to follow up}}", the desktop "{count} people"
  line, and the semantics addition.

## Testing

- Unit: `dueOn` per kind (step, reminder, LRP, follow-up), a paused
  person, a day in the past, today without late items, grouping per person;
  `peoplePerDay`.
- Widget: the folded block and its count, Show/Hide, the row opens the
  contact, folded again on another day; the mobile marker present for a
  future day with people and absent for a past one, and not counted among
  the three dots; the desktop month line and "+N more"; the desktop week
  strip line; the semantics label.
- Goldens for changed previews (Calendar mobile, desktop month and week),
  through CI.

## To mock

Section "What's next — #378" on "04 — Screens (Light)", from the Calendar
frames (#357, #366) and Catch up's summary card (#342). Existing components
only, apart from what's listed as new.

1. **Mobile month, folded:** Thursday selected; under its tasks, the card
   with 3 avatars + "+2" and "5 people to follow up", Show. Grid: the short
   muted line under several future days, some with dots, some without.
2. **Mobile month, open:** the same with Hide and five rows (name, what's
   due, e.g. "Send a first message", "Call back about the diffuser",
   "LRP renews on the 11th", "Follow up about the workshop").
3. **Mobile week strip:** the line under days in the strip.
4. **Desktop month:** a day cell with "5 people" above its task and event
   lines; another with "2 people" only.
5. **Desktop week:** "5 people" in the strip above a day's task.

New pieces: the muted line under a day (its width, thickness, gap to the
dots), the "N people" line in desktop cells. Dark mode and French not
mocked.

## Left to the builder

- Exact copy for the row's "what's due" beyond the existing Today reasons
  (reuse them).

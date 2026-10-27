# What's next in the Calendar — plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** the people due on a day (step, reminders, LRP check, invitation
follow-ups) show in the Calendar from today on: a folded People block under
the day, a muted line under the day in the mobile grid and strip, an
"N people" line in the desktop month cell and week strip. Look only, no tick.
**Architecture:** pure Dart. `dueOn` beside `dueToday` picks the Due items
of one day; a small `PeopleAhead` value carries people, workflows, events
and today down the Calendar's widgets and answers "who, on this day". The
Calendar page now watches `peopleProvider` and `workflowsProvider`.
**Tech Stack:** Flutter, Riverpod (no codegen).
**Spec:** `docs/superpowers/specs/2026-10-27-whats-next-design.md`. Figma:
section "What's next — #378" (node 450:14616).

## Global Constraints

- No migration, no new dependency, no database change.
- No colour, radius, spacing or font size literal: the marker is
  `LoomiaColors.textMuted`; its 12 × 2 px and 2 px gap are named constants
  on `DayCell`, as `_dot` and `_ring` are.
- Copy in `lib/l10n/app_en.arb` only, every key described.
- Goldens through CI only. Issue #378, branch `feature/378-whats-next` off
  `origin/main`.

## Rulings made while planning

- **`dueOn(people, workflows, day, today, {events})`** in `due.dart`, its
  own loop rather than a flag on `dueToday`: the four kinds' rules differ
  (`==` instead of "on or before", LRP read as of [day], no `DueNext`).
  The sort is shared: `dueToday`'s comparator moves to a private
  `_compare` used by both. Empty for `day < today`.
- **Grouping:** `byPerson(List<Due>) → List<List<Due>>`, consecutive runs
  of one person id (the sort already keeps a person's items together on
  one day). Each group is one row, its first item the reason, "· +N" after
  it for the rest.
- **`PeopleAhead`** (`lib/features/calendar/domain/people_ahead.dart`): a
  final class with `people`, `workflows`, `events`, `today`;
  `List<List<Due>> on(DateTime day)` and `int count(DateTime day)`;
  `PeopleAhead.none` (empty, used while loading or failed). Not an
  interface, one class, replacing four parameters on eight widgets.
  ponytail: `on` recomputes over every person per call (≤ 126 grid days ×
  people per build); memoise per day if a profile ever shows it.
- **Row text:** the reason switch in Today's `_row` moves to a top-level
  `dueReason(l10n, model, due)` in `today_page.dart`, beside
  `loyaltyRenewsText`, including the follow-up wording; Today's rows and
  the Calendar's both call it. The Calendar reads the model from
  `accountProvider` as Today does.
- **People rows** are `ActionItem(name, photoPath, reason, tag: stage
  chip, onOpen)`, no `onResolve`, no date chip; tap goes to
  `Routes.contactLocation(person.id)` through a new `onOpenPerson`
  callback on `CalendarView` (push on mobile, go on desktop, as
  `openEvent`).
- **The block** is one widget, `PeopleBlock` (`calendar/presentation/
  people_block.dart`): `foldable: true` gives Catch up's header with
  Show / Hide and the summary card, `false` (the desktop popover) gives the
  header and rows only. Its fold is local `setState`; callers key it by
  day (`ValueKey(day)`), so selecting another day builds a folded one: no
  reset logic. The summary card is Catch up's `_Summary`, made public as
  `PeopleSummary` in `check_in_items.dart` (no copy).
- **Semantics:** one helper `daySemantics(l10n, day, events, tasks,
  people)` in `month_grid.dart`, used by `DayCell` and the desktop month
  and week (replacing `desktop_calendar.dart`'s `_daySemantics`). Two new
  keys for the people cases: `calendarDaySemanticsPeople` (events, people)
  and `calendarDaySemanticsTasksPeople` (events, tasks, people).
- **Desktop month:** the people line is the first entry of `chips`, with
  `CalendarPeopleLine.heightFor`, so `chipsThatFit` counts it; "+N more"
  then counts it too if it ever doesn't fit (it is first, so it is kept
  first).
- **Desktop week strip:** shows when any day has untimed tasks or people;
  each day's column lists its people line, then its untimed tasks.

## Review Focus

- `dueOn` per kind against `dueToday` (paused, LRP window start, follow-up
  whose event has passed, today without late items).
- The People block's fold reset on another day, and its semantics (one
  button, count read once).
- The desktop month's "+N more" with the people line counted.

### Task 1: `dueOn` and grouping

- [x] Tests first, `test/features/today/domain/due_test.dart` (new group
  "dueOn"): a step due Thursday shows on Thursday only; a paused person's
  step is gone, their reminder stays; a reminder on its day; an LRP
  renewing on the 11th shows on the 8th only, and not when already checked
  for the 11th; a follow-up on its `followUpOn`, not when its event's day
  is before it; no `DueNext`; a past day is empty; today shows a step due
  today but not one due yesterday; `byPerson` groups a step and a reminder
  of one person into one run, two people into two, sorted by name.
- [x] `due.dart`: `_compare` out of `dueToday`, `dueOn`, `byPerson`.

### Task 2: `PeopleAhead` and the row text

- [x] Tests first, `test/features/calendar/domain/people_ahead_test.dart`:
  `on` / `count` per day, `none` empty.
- [x] `people_ahead.dart`.
- [x] `today_page.dart`: `dueReason(l10n, model, due)` from `_row`'s switch
  and `_followUp`'s reason; Today's tests unchanged and green.

### Task 3: The marker and the semantics

- [x] Widget tests first, `test/features/calendar/presentation/
  calendar_people_test.dart` (pumping `CalendarView` as
  `calendar_tasks_test.dart` does, with a `PeopleAhead`): a future day
  with people has the marker (find by key `ValueKey('people-marker')`),
  a past day with a person due then has none, a day with three events
  still shows three dots and the marker; the day's label reads "Thursday,
  October 8, no events, 5 people" and the tasks variant.
- [x] ARB: `calendarDaySemanticsPeople`, `calendarDaySemanticsTasksPeople`.
- [x] `month_grid.dart`: `daySemantics`; `DayCell.people` (int) and the
  marker under the dots row (`_marker` 12 × 2, `_markerGap` 2), within the
  same bottom padding so the cell height is unchanged (assert in the test:
  `tester.getSize` of a cell equal with and without people);
  `MonthGrid` / `WeekStrip` / `_DayRows` take `PeopleAhead`.

### Task 4: The People block on mobile

- [x] Widget tests first, same file: the selected day shows "PEOPLE",
  Show, the summary "5 people to follow up" with the avatar group; Show
  opens five rows by name, Léa's "Book the unboxing call · +1"; Hide folds
  it; selecting another day and back shows it folded; a row opens the
  contact (`onOpenPerson` called with the person); no ring on the rows; a
  day with only people is not "Nothing planned"; the order is tasks,
  people, events; the week list shows the block on each day with people.
- [x] ARB: `calendarPeopleSection` ("People"), `calendarPeopleSummary`
  (plural, "One person to follow up" / "{count} people to follow up"),
  `calendarPeopleMore` ("{reason} · +{count}"). Show / Hide reuse
  `todayCatchUpShow` / `todayCatchUpHide`.
- [x] `check_in_items.dart`: `_Summary` → public `PeopleSummary`.
- [x] `people_block.dart`: `PeopleBlock`.
- [x] `calendar_page.dart`: `DaySection` and `WeekList` (`week_view.dart`)
  take `PeopleAhead` and `onOpenPerson`, insert `PeopleBlock(key:
  ValueKey(day))` between tasks and events. `_CalendarPageState.build`
  watches `peopleProvider(owner)`, `workflowsProvider(owner)` and builds
  `PeopleAhead` only when both have a value (else `none`); model from
  `accountProvider`.

### Task 5: Desktop

- [x] Widget tests first, same file at 1440 × 900: a month cell shows "5
  people" above its task and event; a cell with only people shows "2
  people"; a cell too short for everything still shows the people line
  first and "+N more" counts the rest; the label includes the people; the
  week strip shows "5 people" above the day's untimed task, and shows for
  a week with people but no tasks; tapping the line opens the day's
  popover, which lists the open rows (no Show / Hide).
- [x] ARB: `calendarPeopleLine` ("{count, plural, =1{1 person} other{{count}
  people}}").
- [x] `desktop_calendar.dart`: `CalendarPeopleLine` (muted `labelSmall`,
  no ring, no bar, `heightFor`), first in `_MonthCell`'s `chips`; in
  `WeekGrid`'s strip; `daySemantics` replaces `_daySemantics`;
  `DesktopMonth` / `WeekGrid` / `_ColumnHeader` take `PeopleAhead`. The
  popover's `DaySection` gets `PeopleBlock(foldable: false)`.

### Task 6: Previews, checks, PR

- [x] `calendar_preview.dart`: five people due Thursday 8 as in frame 2
  (Bruno, Camille, Claire with LRP on the 11th, Hugo, Léa with a step and
  a reminder), two on a later day, so the mobile, week, desktop month and
  week previews show the marker, the block and the lines.
- [x] `dart format .`, `flutter analyze`, `flutter test`.
- [x] Commit, push `feature/378-whats-next` (separate commands, literal
  branch), PR with `Closes #378`, no Database section.
- [x] Goldens through CI, checked against the Figma frames, committed.

## Changed while implementing

- **`PeopleAhead.none()` is a const constructor** (its `today` null), so
  every widget can default `people` to it.
- **Opening a person** reuses `openContact` from `contacts_page.dart` (go
  on desktop, push elsewhere) rather than a new helper.
- **The marker sits in the cell's existing 4 px bottom padding**, aligned to
  its bottom: 2 px gap, 2 px line, no height change (pinned by the test).
- **Tests came with the code** for the widgets rather than strictly before;
  the domain tests (`dueOn`, `PeopleAhead`) were first.

# Calendar desktop (#366) Implementation Plan

**Goal:** Desktop calendar: full-width ruled month with event chips and a day
popover, hour-grid week; no day pane.

**Architecture:** Pure layout maths in `lib/features/calendar/domain/week_grid.dart`
(hour range, lanes, how many chips fit). Widgets in a new
`lib/features/calendar/presentation/desktop_calendar.dart`; `CalendarView`'s
desktop branch uses them. Mobile and tablet code paths are untouched.

**Tech Stack:** Flutter, Riverpod, go_router. No new dependency.

**Spec:** [2026-10-22-calendar-desktop-design.md](../specs/2026-10-22-calendar-desktop-design.md)

## Global Constraints

- Mobile and tablet render exactly as before: their goldens must not change.
- Theme values only (`LoomiaColors`, `AppSpacing`, `AppRadii`, text theme).
- English copy in `app_en.arb` with descriptions.

## Rulings made while planning

- `CalendarDayPane` is deleted; the desktop `/calendar` page is an empty pane
  and `CalendarPage` shows a pane only while an event is open.
- `WeekColumns` and its desktop test are replaced by `WeekGrid`.
- Chip heights are measured with `TextPainter` against the cell width, so the
  "+N more" cut is right at any text scale.
- `CalendarView` gains `now` (defaults to `today`, so no now line) for the
  week's now line; `CalendarPage` passes `DateTime.now()`.

## Review Focus

- Popover focus and dismissal; the lane packing; mobile goldens unchanged.

### Task 1: layout maths

- [x] `test/features/calendar/domain/week_grid_test.dart`: `hourRange`
  (default 8–22, stretched by an early start and a late end, cut at 24),
  `dayLanes` (no overlap → 1 lane each; a chain of overlaps shares lanes;
  a touching end/start doesn't overlap), `chipsThatFit`.
- [x] Implement in `lib/features/calendar/domain/week_grid.dart`.

### Task 2: desktop month and popover

- [x] Tests in `calendar_page_test.dart`: chips in their cell, "+N more" when
  a short window can't fit them, a chip opens its event, a day opens the
  popover with its events and Add, Escape closes it, Add closes and adds.
- [x] `DesktopMonth`, `MonthEventChip`, `showDayPopover`.

### Task 3: hour-grid week

- [x] Tests: cards placed by start and sized by length, overlapping ones side
  by side, a short one on one line, an early event stretches the hours, a
  card opens its event, a column opens the popover.
- [x] `WeekGrid` in `desktop_calendar.dart`; delete `WeekColumns`.

### Task 4: header, routing, previews

- [x] One-row desktop header; no pane at `/calendar`; update the in-app
  desktop tests; delete `CalendarDayPane`.
- [x] Previews: desktop month and week on the Figma's sample events.
- [ ] Format, analyze, test (done locally); goldens regenerated through CI.

## Changed while implementing

- The week's hour gutter is 72 px, not the Figma's 56: "10:00 AM" didn't fit
  in 12-hour locales.
- The day popover is a modal route (`showDialog`, transparent barrier), placed
  by a `SingleChildLayoutDelegate`; Escape, a click outside, Add and opening
  an event all close it.
- A week column's empty area opens the popover by mouse only; for keyboard and
  screen readers the column's heading is the day's button.

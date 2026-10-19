# Calendar week view Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [x]`) syntax for tracking.

**Goal:** The Calendar gets a Week view beside Month (#357), a title that jumps to any month (or any day's week), and month swipes that take every time: two quick swipes turn two months, and a swipe whose first pixels lean down still turns.

**Architecture:**
- **Domain:** `weekDays()` beside `monthDays()` in `domain/month_grid.dart`. No data change.
- **State:** `CalendarSelection` gains `mode` (`CalendarMode.month` / `.week`); `CalendarSelector.shift` moves by the mode's unit; `setMode`, `showMonth`.
- **Presentation:** `_SwipeableMonth` becomes `_SwipePager` (any anchor date, builder by page delta) with both swipe fixes. New `week_view.dart`: `WeekStrip`, `WeekList` (mobile/tablet), `WeekColumns` (desktop). `CalendarView` gains `desktop`, so desktop week view can render without a pane.
- **No migration.**

**Tech Stack:** Flutter (`material_ui`, `package:flutter/gestures.dart` for the recognizer), `flutter_riverpod` 3, `intl`.

**Spec:** `docs/superpowers/specs/2026-10-19-calendar-week-view-design.md`. Figma: section "Calendar week — #357" (node `394:12766`), new parts in frame `394:12767`.

## Global Constraints

- **Database:** none. No `supabase db push`; the PR's Database section says so.
- No new dependency. Theme values only (`colorScheme`, `LoomiaColors.of`, `AppSpacing.*`, `AppRadii.*`, `textTheme`); the switch is a stock `SegmentedButton` (M3's default is the Figma's pill with a check), as in `whats_next_sheet.dart`.
- Copy in `app_en.arb` only, every key described.
- Gate: `dart format .`, `flutter analyze` ("No issues found!"), `flutter test`. Goldens through CI, never committed from a local run.
- Branch `feature/357-calendar-week` off `origin/main`; PR `Closes #357`.

## Rulings made while planning

- **Title row (Figma finding).** Title + chevron + Today + ‹ › + account is ~400 px at 390. Today moves to the end of the switch row; the title stays `headlineSmall` (24 px), `maxLines: 1`, ellipsis. Buttons stay 48 px.
- **Desktop week has no day pane (Figma finding).** With the 440 px pane, columns are ~95 px. The pane only repeated one column, so at `/calendar` in week mode `CalendarPage` passes no pane; at `/calendar/:id` it passes the event pane. `CalendarView` decides desktop from a new `desktop` flag instead of `pane != null`. Card titles `maxLines: 2`, ellipsis.
- **Quick-swipe fix.** `_release` records the turn it is animating to (`_turning`). `onHorizontalDragStart` with `_turning != 0` stops the animation and calls `onShift(-_turning)` at once; `didUpdateWidget` then adds the step to the offset as it does for a finished drag (−0.9 + 1 = 0.1), so the new drag continues from where the page visibly is. The completion path only shifts if `_turning` is still its target. `TickerFuture` never completes once stopped, so the old continuation can't shift twice.
- **Diagonal-swipe fix.** A `_SidewaysDrag extends HorizontalDragGestureRecognizer` overriding `hasSufficientGlobalDistanceToAccept` to accept at half the hit slop (`computeHitSlop(kind, gestureSettings) / 2`), through `RawGestureDetector`. The page's vertical recognizer still needs its full slop, so a drag leaning sideways (more than ~27° from vertical) wins; a vertical scroll that drifts less still scrolls. Probe that motivated it: (−4, +5) × 4 frames, then (−25, +2) × 10, turned nothing on `main`.
- **Week shift keeps the weekday.** `shift(±1)` in week mode selects `day ± 7` (calendar dates), or today when it lands in the current week. Month mode keeps its rule (1st, or today in the current month).
- **`month` follows the day in week mode.** `select` already sets `month` to the day's month, so switching back to Month shows the month of the day you were on.
- **Week title copy.** `calendarWeek` "{start} – {end}" with String placeholders; code formats each end with `DateFormat.MMMd` (or `yMMMd` for both when the years differ). Spec Decisions → Week title.
- **Week list scroll to the selected day.** Each day's heading gets a `GlobalKey`; tapping a strip day calls `Scrollable.ensureVisible` on it (duration `context.motion(AppMotion.medium)`). No controller plumbing.
- **Picker range.** `pickMonth` / `pickDay` from 10 years before today to 10 years after.

## Review Focus

- The two gesture fixes: a vertical drag on the grid must still scroll the page and pull to refresh.
- `didUpdateWidget` offset arithmetic when a turn is committed early, in both directions.
- Desktop routing: week mode at `/calendar` (no pane) and `/calendar/:id` (pane), and selecting a day closing the event.

### Task 1: Swipe fixes

**Files:** `lib/features/calendar/presentation/calendar_page.dart`, `test/features/calendar/presentation/calendar_page_test.dart`.

- [x] Tests first, beside "the month follows the finger, then turns" (390×844, `pumpLoomia`, `/calendar`):
  - "two quick swipes turn two months": `tester.fling(grids.first, Offset(-150, 0), 1500)`, `pump(80 ms)`, fling again, `pumpAndSettle` → month + 2.
  - "a swipe that starts leaning down still turns": `startGesture` at the grid centre, 4 × `moveBy(Offset(-4, 5))` with `pump(16 ms)`, 10 × `moveBy(Offset(-25, 2))`, `up`, settle → month + 1.
  - "a vertical drag on the grid scrolls the page": `drag(grids, Offset(0, -200))` → month unchanged, and the grid moved up (`getTopLeft(grids).dy` smaller).
  Run: first two fail (1 and 0), third passes.
- [x] Rename `_SwipeableMonth` → `_SwipePager`: `anchor` (DateTime: the month's 1st or the week's first day), `onShift`, `builder: Widget Function(int delta)`. `didUpdateWidget` compares `anchor`. Month call site: `builder: (delta) => MonthGrid(month: DateTime(m.year, m.month + delta), ...)`.
- [x] Add `_turning` and the early commit (Rulings → Quick-swipe fix).
- [x] Replace `GestureDetector` with `RawGestureDetector` + `_SidewaysDrag` (Rulings → Diagonal-swipe fix), same three callbacks. Import `package:flutter/gestures.dart`.
- [x] Run the calendar tests: all pass.

### Task 2: `weekDays` and the week title

**Files:** `lib/features/calendar/domain/month_grid.dart`, `test/features/calendar/domain/month_grid_test.dart`, `lib/features/calendar/presentation/week_view.dart` (new), `test/features/calendar/presentation/week_view_test.dart` (new).

- [x] Tests: `weekDays(DateTime(2026, 10, 21), 1)` → Oct 19…25; with `0` → Oct 18…24; `weekDays(DateTime(2026, 12, 31), 1)` → Dec 28…Jan 3; across the October DST change in Europe/Paris (Oct 25 2026), 7 distinct local midnights. A day that is itself the first weekday starts its own week.
- [x] Implement:
  ```dart
  /// The 7 days of [day]'s week, from [firstDayOfWeek] (0 is Sunday). Local
  /// midnights from calendar dates, as [monthDays].
  List<DateTime> weekDays(DateTime day, int firstDayOfWeek) {
    final lead = (day.weekday % 7 - firstDayOfWeek) % 7;
    return [
      for (var i = 0; i < DateTime.daysPerWeek; i++)
        DateTime(day.year, day.month, day.day - lead + i),
    ];
  }
  ```
- [x] `String weekTitle(AppLocalizations l10n, List<DateTime> week)` in `week_view.dart`: `MMMd` both ends, `yMMMd` both when `first.year != last.year`, through `l10n.calendarWeek`. Unit tests (en): "Oct 19 – Oct 25", "Sep 28 – Oct 4", "Dec 28, 2026 – Jan 3, 2027"; (fr) « 19 oct. – 25 oct. ».
- [x] Add `calendarWeek` to `app_en.arb` (placeholders `start`, `end`: String; description says each end is a short date in the locale's format). `flutter gen-l10n` runs with `flutter pub get`/test.

### Task 3: Selection with a mode

**Files:** `lib/features/calendar/presentation/calendar_controller.dart`, `test/features/calendar/presentation/calendar_controller_test.dart`, the record literals in `calendar_preview.dart` and `calendar_page_test.dart` (lines 65, 200).

- [x] Tests (with `withClock` or the existing today seam the file uses): `setMode(week)` keeps `day`; with today Mon Oct 19 and weeks from Monday: week `shift(1)` from Wed Oct 14 lands in today's week → today (Oct 19); from Wed Oct 21 → Wed Oct 28; `shift(-1)` from Oct 28 → today. The same from Sunday (`firstDayOfWeek: 0`): from Sat Oct 17, `shift(1)` → Sat Oct 24 is in today's week (Oct 18–24) → today. Month `shift` unchanged. `showMonth(DateTime(2027, 3))` → month 2027-03, day Mar 1; `showMonth` of the current month → today. `toToday` keeps the mode.
- [x] `enum CalendarMode { month, week }`; `typedef CalendarSelection = ({CalendarMode mode, DateTime month, DateTime day});`. `_on(day, mode)`; `select` keeps `state.mode`; `setMode(mode)`; `showMonth(month)` = the month part of today's `shift`; `shift` branches on mode. "In today's week" compares `weekDays(target, first).first == weekDays(today, first).first` (calendar dates, never `difference`), so `shift(int delta, {int firstDayOfWeek = 0})`; the page passes `MaterialLocalizations.of(context).firstDayOfWeekIndex`.
- [x] Update the record literals to include `mode: CalendarMode.month`.

### Task 4: Header, switch and title pickers

**Files:** `calendar_page.dart`, `app_en.arb`, `calendar_page_test.dart`.

- [x] Tests: the switch shows Month selected; tapping Week shows the strip (`find.byType(WeekStrip)`) and the week title; the arrows' tooltips become "Previous week" / "Next week"; Today selects today in both modes. Title in month mode opens a picker: on the default test platform (Android) `find.byType(DatePickerDialog)`; pick 2027 / accept → month 2027-xx shown. Title in week mode → `pickDay` dialog, picked day selected and its week shown. The title keeps one line at 390 with the account button ("September 2026": `tester.getSize(title).height` equals one line of `headlineSmall`).
- [x] Header: `Row(Flexible(_TitleButton), IconButton ‹, IconButton ›, ?accountAction)`; `_TitleButton` is `InkWell` (radius `AppRadii.sm`) around `Row(Text(maxLines: 1, overflow: ellipsis), Icon(Icons.expand_more_rounded))` with `Semantics(button, label: calendarChooseMonth / calendarChooseWeek)`. Below: `Row(SegmentedButton<CalendarMode>(segments: Month, Week; showSelectedIcon default), Spacer, TextButton Today)`.
- [x] `CalendarView` gains `onMode`, `onPickTitle`; `CalendarPage` wires `onPickTitle` to `pickMonth` → `showMonth`, or `pickDay` → `select` (Rulings → Picker range).
- [x] Copy: `calendarViewMonth` "Month", `calendarViewWeek` "Week", `calendarPreviousWeek`, `calendarNextWeek`, `calendarChooseMonth` "{month}, choose a month" (DateTime yMMMM), `calendarChooseWeek` "{week}, choose a week" (String). Update `calendarToday`'s description (it now also shows today's week).

### Task 5: Week view, mobile and tablet

**Files:** `week_view.dart`, `calendar_page.dart`, `week_view_test.dart`, `calendar_page_test.dart`.

- [x] Tests: `WeekStrip` shows 7 days with the month grid's day semantics (`calendarDaySemantics`), selected and today states, tapping a day calls `onSelect`. `WeekList` with events on Wed (2) and Thu (1): 7 headings ("Mon 19", FR « lun. 19 »: `'${DateFormat.E(locale).format(d)} ${d.day}'`, since no `intl` skeleton gives weekday + day without the month), 3 `EventRow`s, 5 "Nothing planned"; the today heading has a "Today" pill (`calendarToday` reused); headings are `Semantics(header: true)`. In the app: week mode, swiping the strip turns a week; two quick flings turn two weeks.
- [x] Extract the month grid's `_Day` into a public `DayCell` (same file, `month_grid.dart`), used by both `MonthGrid` and `WeekStrip`. Strip: weekday letters row as `MonthGrid`, then one row of `DayCell`s.
- [x] `WeekList`: per day a `_WeekDayHeading` (Figma `394:12795`: `titleSmall` bold, selected in `colorScheme.primary`; today adds a pill: border `scheme.primary` 1.5, `labelSmall` in `colors.primaryText`, `AppRadii.pill`) then `EventRow`s with `AppSpacing.ms` gaps or the muted "Nothing planned". Headings keyed for `ensureVisible`.
- [x] In `CalendarView` mobile: week mode replaces `grid` + `Divider` + `DaySection` by `_SwipePager(anchor: week.first, builder: (d) => WeekStrip(days: weekDays(DateTime(f.year, f.month, f.day + 7 * d), first)))` with `f = week.first` + `WeekList`. FAB unchanged (selected day).

### Task 6: Week view, desktop

**Files:** `week_view.dart`, `calendar_page.dart`, `app_router.dart` (shell builder only), tests.

- [x] Tests (1440×900, `pumpLoomia`): week mode at `/calendar` has no `CalendarDayPane`, 7 `WeekColumns` columns; tapping a card goes to `/calendar/<id>` and shows `EventPane`; tapping a column's empty area selects that day and returns to `/calendar` (no pane). Month mode desktop unchanged (existing tests).
- [x] Shell builder: `CalendarPage(pane: child, eventOpen: state.pathParameters.containsKey('id'))`. `CalendarPage`: `desktop: context.screenSize.isDesktop`, `pane: week && !eventOpen ? null : pane`. `CalendarView.build` uses `desktop`; in week mode it drops `_monthMax`.
- [x] `WeekColumns`: `Row` of 7 `Expanded` columns, `AppSpacing.sm` gaps; header (Figma `394:12808`: weekday `labelSmall` muted, then the date in `DayCell`'s circle states — reuse `DayCell` without dots); then `_WeekCard`s (Figma `394:12815`: card with a 3 px start bar in `scheme.primary`, time `labelSmall`, title `titleSmall` `maxLines: 2`; done: 1 px `borderSubtle` outline, both texts `textMuted`). Column body is an `InkWell` → `onSelect(day)`.

### Task 7: Previews, copy and checks

**Files:** `calendar_preview.dart`, `app_en.arb`.

- [x] Previews: "Week — light" (390×844, Oct 19–25, today Wed 21, Thu 22 selected, events as Figma frame 2) and "Week desktop — light" (1440×900, no pane). Reuse `_events`; add one Wed event if needed.
- [x] `dart format .`, `flutter analyze`, `flutter test`. Tick this plan.
- [x] Commit, push `feature/357-calendar-week`, open the PR (Database: none), regenerate goldens through CI (README → *Golden tests*): new `calendar_week_light`, `calendar_week_desktop_light`; `calendar_mobile_*` and `calendar_desktop_light` change (title button, switch row).

## Changes while implementing

- **`shiftedDay` is a top-level function** in `calendar_controller.dart`, tested with fixed dates; `today()` reads the real clock, so testing week shifts through the notifier would depend on the day the suite runs.
- **`_SwipePager` tracks `_dragging`.** A turn landed early by a new drag rebuilds the pager mid-drag; `didUpdateWidget` then only re-bases the offset instead of animating it back to 0 under the finger.
- **The week title and headings are pinned by widget tests** (EN from Sunday, FR from Monday) instead of a separate `week_view_test.dart`.
- **`WeekStrip` and `DayCell` live in `month_grid.dart`**, sharing the month's day rows (`_DayRows`); `week_view.dart` holds the title, the list, the desktop columns and `eventsNotLoaded`, which `DaySection` now uses too.
- **The switch row shrinks the switch first** (`Flexible`, labels ellipsised): French "Mois / Semaine" + « Aujourd'hui » overflowed 390 otherwise.
- **`segmentedButtonTheme`** in `app_theme.dart`: selected `primaryContainer` / `onPrimaryContainer`, outline `scheme.outline`, as the Figma switch. It also restyles the What's next sheet's segmented button.

### After the first review (on device and web)

- **Missed swipes were mostly short ones.** A turn needed half the width or 300 px/s, so a 130 px thumb flick at ~200 px/s sprang back (pinned by "a short, unhurried swipe still turns"). Now a third of the width, or 100 px/s the way it was dragged; a flick back against the drag cancels. Pull to refresh only acts on vertical drags the page has already won, so it was not the cause.
- **The early turn re-bases the offset itself** (`_rebased`) instead of in `didUpdateWidget`, which may run only after the new drag's release.
- **Desktop week columns run to the bottom**, each scrolling its own cards, the selected one tinted `primaryContainer` full height as in the Figma (`398:13303`).
- **Refresh button on desktop and tablet**, in the account slot, as Today and Contacts.
- **Month picker off iOS is a year of months** (`_MonthDialog` in `pick_day.dart`): year with ‹ ›, 3 × 4 month buttons, the current one outlined, a tap picks. It replaces the Material calendar opened on its years, for "Member since"'s target month too. iOS keeps its month-and-year wheel; the week's day picker stays the platform date picker.

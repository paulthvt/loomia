# Mobile calendar time views Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** On phone and tablet, replace the stacked week list with hour grids (3 days and a focus-column Week), add a day sheet, and show the month's selected day as a timeline with free gaps.

**Architecture:** The desktop `WeekGrid` is generalised (column widths, compact cards, hour height) and reused on mobile inside the existing `_SwipePager`; nothing new is copied from it. Two pure domain helpers carry the logic worth testing: the 3-day selection rules and the day timeline (gaps, now). `DaySection` gains a timeline mode used under the month and in the new day sheet.

**Tech Stack:** Flutter, `flutter_riverpod`, `intl`, `flutter_test`. No new dependency, no migration, no Edge Function.

**Spec:** `docs/superpowers/specs/2026-11-06-mobile-calendar-time-views-design.md` (Figma section "Calendar mobile — #448", node 506:20001: frames A, B3, D).

## Global Constraints

- Material from `package:material_ui/material_ui.dart`, never `flutter/material.dart`; imports `package:loomia/...` only.
- No hard-coded colour, radius, spacing or font size in widgets: `Theme.of(context)`, `LoomiaColors.of(context)`, `AppSpacing.*`, `AppRadii.*`, `AppTypography.*`.
- Branch on `context.screenSize`, never raw widths — except the spec's column rule ("7 equal columns ≥ 90 dp"), which is a layout measure inside the grid, not a platform branch.
- Copy: English only in `lib/l10n/app_en.arb`, every key with a `@` description; FR comes from Weblate. No sales/MLM words.
- Dates: calendar arithmetic (`DateTime(y, m, d + n)`), never `Duration(days:)` steps.
- Desktop calendar behaviour unchanged (its existing tests must pass untouched, apart from mechanical renames).
- Quality gate before each commit: `dart format .`, `flutter analyze` ("No issues found!"), `flutter test`.
- Goldens: never commit locally made ones; regenerate through CI (README → *Golden tests*).
- Commits: Conventional Commits, scope `calendar`, ending `(#448)`.

## Review Focus

1. **Undo inside the day sheet.** A task ticked in the sheet would show its Undo snackbar behind the sheet's barrier, untappable. Expected: in the sheet the ring ticks and unticks with no snackbar, as in the desktop popover. Test in Task 6.
2. **Swipe on the grid vs its vertical scroll and pull to refresh.** A sideways swipe that starts leaning down, on the 3-day grid (which scrolls vertically), must still turn the page; a vertical drag must still scroll. Test in Task 6.
3. **DST and month edges in 3 days.** Pages starting Oct 24 (DST ends Oct 25 in Europe) or Dec 30 must show 3 distinct calendar days. Test in Task 1.
4. **Large system text size.** At text scale 2.0, narrow-column titles must not overflow (no red overflow error), only show fewer words or "…". Test in Task 4.
5. **Event in progress / now exactly on an event start in D.** Now at 14:30 inside a 14:00–15:00 event puts the now line after that event; now at 19:00 sharp with an event at 19:00 shows no "Free until" row. Test in Task 2.

---

### Task 1: Selection for 3 days

**Files:**
- Modify: `lib/features/calendar/presentation/calendar_controller.dart:218-300`
- Modify: every `CalendarSelection` record literal (`grep -rn "(mode:" lib test`) to pass `from:`
- Test: `test/features/calendar/presentation/calendar_controller_test.dart`

**Interfaces:**
- Produces:
  - `enum CalendarMode { month, threeDays, week }`
  - `typedef CalendarSelection = ({CalendarMode mode, DateTime month, DateTime day, DateTime from});` — `from`: first day of the 3-day page; equals `day` outside 3 days.
  - `List<DateTime> shownDays(CalendarSelection s, int firstDayOfWeek)` — the grid's columns: 3 days `from..from+2`, otherwise `weekDays(day, firstDayOfWeek)`.
  - `shiftedDay` gains the `threeDays` case; `CalendarSelector.select`, `setMode`, `shift`, `toToday`, `showMonth` keep their signatures.

- [ ] **Step 1: Write the failing tests** (group `'3 days'`), with `today = DateTime(2026, 10, 21)`:
  - `setMode(threeDays)` from day Oct 22 → `from == day == Oct 22`.
  - `select(Oct 24)` with `from` Oct 22 → `from` stays Oct 22, `day` Oct 24; `select(Oct 26)` → `from == day == Oct 26`.
  - `shift(1)` with `from` Oct 22, `day` Oct 23 → `from` Oct 25, `day` Oct 26 (same column); `shift(-1)` from `from` Oct 24, `day` Oct 24 → `from` Oct 21, `day` Oct 21 (today shown → today).
  - `toToday()` → `from == day == today`.
  - `shownDays` for `from` Oct 24 → `[Oct 24, Oct 25, Oct 26]` (DST); for `from` Dec 30 2026 → `[Dec 30, Dec 31, Jan 1 2027]`.
  - `setMode(week)` after 3 days with `day` Oct 24 → week of Oct 24, `day` Oct 24.

- [ ] **Step 2: Run** `flutter test test/features/calendar/presentation/calendar_controller_test.dart` — FAIL (no `threeDays`).

- [ ] **Step 3: Implement.** `_on(day, mode, {from})`: `from` defaults to `day`. `select`: in `threeDays`, keep `from` when `day` is within `from..from+2`, else `from = day`. `shift` in `threeDays`: `from + 3*delta`, `day` at the same offset from `from`, or today when the new page shows it (rule lives in `shiftedDay`'s new case; `shift` sets both). `toToday` and `setMode(threeDays)` set `from = day`.

- [ ] **Step 4: Run** the same test file, then `flutter test` — PASS (desktop tests untouched).

- [ ] **Step 5: Commit** `feat(calendar): a 3 days selection (#448)`.

---

### Task 2: The day timeline (domain)

**Files:**
- Create: `lib/features/calendar/domain/day_timeline.dart`
- Test: `test/features/calendar/domain/day_timeline_test.dart`

**Interfaces:**
- Consumes: `startMinute`, `endMinute` from `domain/week_grid.dart` (an event without an end lasts an hour).
- Produces:
  ```dart
  sealed class TimelineRow {}
  final class TimelineEvent extends TimelineRow { final CalendarEvent event; }
  /// Free from [start] to [end], minutes from local midnight. [untilOnly]:
  /// today's gap holding now, shown as "Free until {end}".
  final class TimelineGap extends TimelineRow { final int start, end; final bool untilOnly; }
  final class TimelineNow extends TimelineRow { final int minute; }
  const Duration minGap = Duration(hours: 1);
  List<TimelineRow> dayTimeline(List<CalendarEvent> events, {int? nowMinute});
  ```
  `events`: one day's, sorted by start (as `eventsOn`). `nowMinute` only for today.

- [ ] **Step 1: Write the failing tests** (times as minutes, events built with a small `_event(start, end)` helper):
  - No events → `[]`.
  - 9:00–9:30, 14:00–15:00, 19:00–21:00, no now → event, gap(570, 840), event, gap(900, 1140), event.
  - Gap under an hour (10:00–11:00, 11:30–12:00) → no gap row.
  - Overlaps merged: 10:00–12:00 and 11:00–13:00, then 15:00 → one gap (780, 900).
  - Event without end at 10:00, next at 11:30 → no gap (10:00–11:00 + 30 min).
  - Figma D: the three events above, now 15:20 → event, gap(570, 840), event, now(920), gap(920, 1140, untilOnly), event.
  - Now at 12:00 with 9–10 and 15–16 → event, now(720), gap(720, 900, untilOnly), event (the 10–12 part gone).
  - Now 7:00 before the first event at 9:00 → now(420), gap(420, 540, untilOnly), event.
  - Now 8:30 before the first event at 9:00 (under an hour) → now(510), event.
  - Now 14:30 inside 14:00–15:00 (with 19:00 next) → …, event(14:00), now(870), gap(900, 1140) — the line goes after the event in progress; the gap doesn't hold now, so it is a plain gap, not `untilOnly`.
  - Now 19:00 sharp, event at 19:00 → now(1140) directly before that event, no `untilOnly` gap.
  - Now after the last event (22:00) → events…, now(1320) last; no gap after.

- [ ] **Step 2: Run** `flutter test test/features/calendar/domain/day_timeline_test.dart` — FAIL.

- [ ] **Step 3: Implement** `dayTimeline`: walk events keeping the running busy end (`max` of ends); between busy end and next start emit a gap when `≥ minGap`; with `nowMinute`, drop free time before now, emit `TimelineNow` at its place (after every event with `start ≤ now`… in-progress events count as before now), and mark the gap that starts at now `untilOnly`. Gaps never before the first event except the one starting at now; never after the last.

- [ ] **Step 4: Run** the test file — PASS.

- [ ] **Step 5: Commit** `feat(calendar): free time and now in a day's timeline (#448)`.

---

### Task 3: Copy and the micro text style

**Files:**
- Modify: `lib/l10n/app_en.arb` (next to `calendarViewWeek`), then `flutter gen-l10n` runs on build (generated files as the repo already does).
- Modify: `lib/app/theme/app_typography.dart` (after `overline`)

**Interfaces:**
- Produces (keys, EN text verbatim):
  - `calendarViewThreeDays`: "3 days" — switch segment.
  - `calendarPreviousDays`: "Previous 3 days"; `calendarNextDays`: "Next 3 days" — arrow tooltips.
  - `calendarChooseDay`: "{days}, choose a day" — title button semantics in 3 days (`days` String).
  - `calendarFree`: "Free · {duration}"; `calendarFreeUntil`: "Free until {time}".
  - `calendarHours`: "{hours} h" and `calendarHoursMinutes`: "{hours} h {minutes}" (`minutes` a String, 2 digits) — the duration in `calendarFree`: "4 h 30", "1 h", "1 h 05"; minutes left out when 0.
  - `calendarPeopleToFollowUp`: "{count, plural, =1{1 person to follow up} other{{count} people to follow up}}".
  - `calendarCardSemantics`: "{title}, {start} to {end}".
  - The day sheet's label reuses `calendarDayTitle`.
  - Each with a `@` description saying where it shows.
- `static final micro = _style(10, 12, _medium);` with a doc comment: "The narrow week columns' titles (#448). The floor: nothing smaller."

- [ ] **Step 1:** Add the keys and `AppTypography.micro`.
- [ ] **Step 2:** `flutter analyze` — No issues found.
- [ ] **Step 3: Commit** `feat(calendar): copy for 3 days and free time (#448)`.

---

### Task 4: The grid on mobile — `WeekGrid` generalised

**Files:**
- Create: `lib/features/calendar/presentation/fit_words.dart`
- Modify: `lib/features/calendar/presentation/desktop_calendar.dart` (`WeekGrid` 599-800, `_ColumnHeader` 802-885, `_DayColumn` 887-1033, `_WeekCard` 1060-1170)
- Test: `test/features/calendar/presentation/fit_words_test.dart`, `test/features/calendar/presentation/calendar_page_test.dart` (week grid group)

**Interfaces:**
- Consumes: `AppTypography.micro`, `calendarCardSemantics` (Task 3).
- Produces:
  - `String fitWords(String text, {required TextStyle style, required double width, required int maxLines, required TextScaler scaler, required TextDirection direction})` — as many whole words as fit on `maxLines` lines of `width`, then "…"; when the first word alone doesn't fit, its leading letters + "…"; the text unchanged when it all fits.
  - `WeekGrid` new optional parameters (defaults keep desktop identical):
    - `bool compact = false` — cards show the title only (no time line, no short-event "14:00 · …" form), semantics `calendarCardSemantics`.
    - `bool focus = false` — when `true` and an equal column would be `< 90` dp, the selected day's column takes what's left after the others at `40` dp each; widths animate with `AppMotion.medium` / `AppMotion.standard`.
    - `double gutter` — default the current `72`; mobile passes `32`.
    - `double minHour = 40` — fit-to-height floor; mobile Week passes `28`.
    - `double? hourHeight` — fixed hour height (3 days passes `52`); null = fit, as now.
    - `int? scrollToMinute` — opens scrolled so this minute minus an hour is at the top.
    - `ValueChanged<DateTime>? onSelect` — a tap on an empty part of a column; null keeps today's behaviour (`onDay`).
  - Cards in a narrow (40 dp) column: `AppTypography.micro`, text through `fitWords` with `maxLines` = lines fitting the card; other compact cards: `labelSmall`, `maxLines` by height, ellipsis.

- [ ] **Step 1: Write failing `fit_words_test.dart`** (testWidgets so `TextPainter` uses the test font, where a glyph is as wide as the font size; style `fontSize: 10`, `TextScaler.noScaling`, `TextDirection.ltr`):
  - `'Dinner with Léa & Tom'`, width 60, 4 lines → `'Dinner with Léa & Tom'` (fits).
  - `'Open house brunch'`, width 50, 1 line → `'Open…'`.
  - `'Product evening'`, width 50, 1 line → `'Prod…'` (first word too long).
  - `'Coffee with Camille'`, width 70, 2 lines → `'Coffee with…'`; never a line break inside a word.
  - Scale 2.0, width 50, 1 line, `'Team check-in'` → `'Te…'` (and no exception).
- [ ] **Step 2: Run** — FAIL.
- [ ] **Step 3: Implement `fitWords`** (layout with `TextPainter`, drop words from the end until it fits in `maxLines` with "…"; then letters for a lone first word).
- [ ] **Step 4: Run** — PASS.
- [ ] **Step 5: Write failing widget tests** in `calendar_page_test.dart` (pump `WeekGrid` directly at 358×600 with the Figma week, Oct 19–25, selected Wed 21):
  - `'mobile week: the selected column is wide, the others 40'` — `tester.getSize` of Wed's column ≈ 358 − 32 − 6×40; Mon's 40.
  - `'mobile week: no time on the cards'` — `find.text('19:00')` finds only the hour label, not a card; `find.bySemanticsLabel('Essential oils for sleep, 19:00 to 21:00')` finds one.
  - `'mobile week: a narrow title keeps whole words'` — Fri's card text is `'Prod…'`.
  - `'mobile week: tapping a narrow column selects it, the header opens the day'` — tap empty part of Fri column → `onSelect(Oct 23)`; tap Fri header → `onDay(Oct 23, _)`.
  - `'mobile week at text scale 2: nothing overflows'` — `tester.takeException()` is null.
  - `'3 days: three equal columns, opened at an hour before now'` — 3 columns of equal width; the scroll offset equals `(now − 60 − firstHour*60) / 60 * 52`.
  - Desktop grid tests unchanged and passing.
- [ ] **Step 6: Run** — FAIL. **Step 7: Implement** the parameters above. **Step 8: Run** `flutter test` — PASS.
- [ ] **Step 9: Commit** `feat(calendar): the hour grid on a phone (#448)`.

---

### Task 5: The day as a timeline in `DaySection`

**Files:**
- Modify: `lib/features/calendar/presentation/calendar_page.dart` (`DaySection` 981+)
- Modify: `lib/features/calendar/presentation/people_block.dart` (`_PeopleBlockState` → public `PeopleBlockState` with `void unfold()`)
- Test: `test/features/calendar/presentation/calendar_page_test.dart`, `calendar_people_test.dart`

**Interfaces:**
- Consumes: `dayTimeline`, `TimelineEvent/Gap/Now` (Task 2), copy (Task 3), `PeopleAhead.count`.
- Produces: `DaySection({… bool timeline = false})`. With `timeline`, the events part is `dayTimeline(eventsOn(list, day), nowMinute: day == today-of-now ? … : null)` rendered as: `EventRow` (unchanged); gap row — dashed outline (`borderStrong`, `AppRadii.md`), indented by `EventRow`'s time column so it lines up with the cards, text `labelSmall` muted: `calendarFree(duration)` or `calendarFreeUntil(time)` + (today, people due > 0) `calendarPeopleToFollowUp(count)` in `primaryText`, tappable: `PeopleBlockState.unfold()` then `Scrollable.ensureVisible` on the block; now row — time (`timeLabel`) in primary + a 2 dp primary line with an 8 dp dot, as the grid's now line. Tasks and the People block above stay as they are. "Nothing planned" unchanged.
  - Dashed border: no package; a small `CustomPainter` in `calendar_page.dart` (or `BorderSide` dashes if the Flutter version has `BorderSide.strokeAlign`/dash support — check first; ponytail rule: the painter only if nothing built-in).

- [ ] **Step 1: Write failing tests:**
  - `'the day as a timeline: gaps between events, the now line'` — Figma D data (Wed Oct 21, now 15:20): finds `'Free · 4 h 30'`, `'Free until 19:00'`, the now row's `'15:20'`, in that vertical order relative to the event titles.
  - `'the gap after now says who is waiting, and opens them'` — with 3 people due today: `'3 people to follow up'` shows; tapping it unfolds the People block (a person's name becomes visible).
  - `'another day: gaps, no now, no people'` — Oct 22 shows no `'Free until'`, no `'to follow up'`.
  - `'the desktop popover keeps the plain list'` — existing popover test still finds no `'Free ·'`.
- [ ] **Step 2: Run** — FAIL. **Step 3: Implement.** **Step 4: Run** `flutter test` — PASS.
- [ ] **Step 5: Commit** `feat(calendar): the month's day as a timeline with free time (#448)`.

---

### Task 6: Wiring — switch, grids in the pager, the day sheet; `WeekList` removed

**Files:**
- Modify: `lib/features/calendar/presentation/calendar_page.dart` (`CalendarView.build` 330-560, `_CalendarPageState._pickTitle`, `_toggleTask`)
- Modify: `lib/features/calendar/presentation/week_view.dart` — delete `WeekList`, `_WeekDayHeading`; keep `weekTitle`, `eventsNotLoaded`.
- Modify: `lib/features/calendar/presentation/month_grid.dart` — delete `WeekStrip` if nothing else uses it (`grep -rn WeekStrip lib`).
- Test: `test/features/calendar/presentation/calendar_page_test.dart` (rewrite the "week view: the strip, then every day…" test; add the ones below), `calendar_tasks_test.dart`, `calendar_people_test.dart` where they used the week list.

**Interfaces:**
- Consumes: Tasks 1, 3, 4, 5.
- Produces:
  - `CalendarView` gets `onToggleTaskQuiet` (`void Function(Task task)?`, defaults to `onToggleTask`): the page passes `toggleTask(..., withUndo: false)`.
  - `Future<void> showDaySheet(BuildContext context, {required ValueNotifier<CalendarView> latest, required DateTime day})` in `calendar_page.dart`: `showModalBottomSheet(isScrollControlled: true, showDragHandle: true, useSafeArea: true)`, a `DraggableScrollableSheet`-free scroll view holding `DaySection(timeline: true, peopleFoldable: true)` built from `latest` like the desktop popover, actions closing the sheet first (same `closing` helper — extract it), ring through `onToggleTaskQuiet`.

- [ ] **Step 1: Write failing tests:**
  - `'the switch has Month, 3 days and Week on a phone, two on desktop'`.
  - `'3 days: three columns from the selected day; arrows move 3 days'` — title `'Oct 21 – Oct 23'`, tooltips `'Previous 3 days'` / `'Next 3 days'`; next → `'Oct 24 – Oct 26'`.
  - `'week on a phone: the hour grid, no strip, no list'` — no `WeekStrip`, no `'Nothing planned'`; the wide column is today's.
  - `'a day header opens its sheet; ticking a task there shows no Undo'` — tap Thu 22 header → sheet shows the day's tasks; tap the ring → task done, `find.text('Undo')` finds nothing; drag down closes.
  - `"'N people' in the strip opens the day's sheet"`.
  - `'in the app: a swipe on the 3-day grid that starts leaning down turns the page; a vertical drag scrolls'` (pattern of the existing "starts leaning down" test).
  - `'desktop in 3 days shows the week'` — selection `threeDays` on desktop renders `WeekGrid` with 7 columns.
  - `'the title in 3 days opens the day picker; the picked day starts the page'`.
- [ ] **Step 2: Run** — FAIL.
- [ ] **Step 3: Implement.** Mobile layout for 3 days / Week: header row, switch row, then `Expanded(_SwipePager(anchor: shownDays.first, builder: (delta) => WeekGrid(days: page delta's days, compact: true, focus: week, gutter: 32, minHour: 28, hourHeight: threeDays ? 52 : null, scrollToMinute: …, onDay: (day, _) => sheet, onSelect: onSelect)))` inside `RefreshIndicator` (grid scroll view with `AlwaysScrollableScrollPhysics`). `_SwipePager`'s `AnimatedSize` is skipped when its parent bounds the height (pass a flag, or wrap the grid page in `SizedBox.expand`). Landscape (`< _pinnedMinHeight`): the grid takes `hourHeight: 40`, no own scroll, inside the page's `ListView`. Month: `DaySection(timeline: true)`. `_pickTitle`: `threeDays` uses `pickDay` then `select` (Task 1 rule makes it the page start when outside). Desktop: `threeDays` renders as `week` (switch shows Week selected).
- [ ] **Step 4: Run** `flutter test` — PASS. Delete `WeekList` and (if unused) `WeekStrip`; run again — PASS.
- [ ] **Step 5: Commit** `feat(calendar): 3 days, the focus week and the day sheet on a phone (#448)`.

---

### Task 7: Previews, goldens, docs

**Files:**
- Modify: `lib/features/calendar/presentation/calendar_preview.dart` — add `@Preview(group: 'Calendar', name: '3 days — light', size: Size(390, 844))` `calendarThreeDaysLight()`; `Week — light` now shows the grid; `Mobile — light/dark` show the timeline (data with an afternoon gap and now inside it, people due today).
- Modify: `test/previews_test.dart` — `'calendar_three_days_light': (const Size(390, 844), calendarThreeDaysLight)`.
- Modify: `docs/architecture.md` only if it describes the week list (grep "week").

- [ ] **Step 1:** Add the preview and its golden entry; `flutter test test/previews_test.dart` fails locally on the missing/changed goldens (expected — compared on Linux only).
- [ ] **Step 2:** Push the branch, run the golden regeneration workflow (README → *Golden tests*), commit the CI goldens it produces. Never commit local ones.
- [ ] **Step 3:** `dart format .`, `flutter analyze`, `flutter test` — all green; `graphify update .`.
- [ ] **Step 4: Commit** `test(calendar): previews for 3 days, the week grid and the timeline (#448)`.
- [ ] **Step 5:** PR with `Closes #448`, Database section "none — no migration", screenshots of the three goldens.

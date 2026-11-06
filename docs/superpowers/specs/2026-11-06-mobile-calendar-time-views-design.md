# Mobile calendar: hour grids and the day as a timeline — design

Issue: #448 ("vue calendrier téléphone": a two- or three-day view on the
phone, like the desktop one). Revisits the week view of #357
(`2026-10-19-calendar-week-view-design.md`), whose "no hour grid, revisit
with a day view" this answers. Figma: section "Calendar mobile — #448" on
page "04 — Screens (Light)" (node 506:20001). Frames **A**, **B3** and
**D** are the chosen ones; B and B2 stay in the section as the rejected
steps (titles break mid-word, 10 px everywhere).

## Intent

On the phone, the week is a stacked list of days (`WeekList`): you read
*what* is on, but not *when* in the day, so you can't see a free afternoon
or how a day is shaped. The day under the month (`DaySection`) has the
same problem. The desktop already answers it with an hour grid (`WeekGrid`,
#366).

Goals:

- see at a glance when events happen, and where the free time is;
- read titles without words cut in half;
- the free time after now points at who is waiting: the calendar answers
  "what do I do with this afternoon?" (the app's one question).

Non-goals: drag to create or move events, pinch to zoom the hours, a
separate one-day view, changing the desktop calendar.

Anti-goals: anything that needs explaining to a non-technical user (the
"day rhythm bar" option C was dropped for that); text under 10 px; titles
broken mid-word.

## Decisions

| Question | Decision | Reason |
| --- | --- | --- |
| Views | Month / 3 days / Week, one segmented switch (the current one, a third segment). | The user's pick: A + B3 + D. |
| 3 days (A) | The selected day and the 2 after it, as columns on an hour grid, like the desktop week. | Google's pattern; columns ~105 px hold full titles. |
| Week (B3) | 7 columns on an hour grid; the selected day's column is wide, the other six narrow (40 dp). | Equal columns (~45 px) broke every title. The wide column reads, the narrow ones keep the week's shape. |
| Month (D) | Unchanged grid; the selected day under it becomes a timeline: its events in time order, free gaps between them, a now line on today. | "The day below has the same issue." |
| Desktop | Unchanged; the selection is shared, so `threeDays` shows as Week there. | Out of scope; its grid already works. |
| Remembering the view | As today: kept until restart, Month on start. | #357's rule; no preferences store. |
| Data | No change, no migration. | Events, tasks and people due are already loaded. |

## 1. Selection

`CalendarMode` gains `threeDays`: `{ month, threeDays, week }`.
`day` is the selected day in every view. `CalendarSelection` gains
`from`: the first shown day of the 3 days page (unused by the other views).
*Designer's call:* in 3 days, tapping a column selects that day and moves
the tint there, the page stays put (Google's behaviour, Figma A).

- **3 days** shows `from`, `from + 1`, `from + 2` (calendar dates, never
  24 h steps). Switching to 3 days sets `from = day`. `shift(±1)` moves
  `from` by 3 days and selects the day in the same column, or today when
  it is shown. Today sets `from` and `day` to today.
- **Week** shows `weekDays(day, firstDayOfWeek)`, as now. Arrows, swipe and
  Today as now (`shiftedDay`).
- `setMode` keeps `day`. Going Week → 3 days starts the 3 days at the
  selected day; 3 days → Week shows the week holding `day`.
- **Title.** 3 days: the range of its 3 days through the existing
  `weekTitle` (it takes any list of days: "Oct 21 – Oct 23",
  « 21 oct. – 23 oct. »). Tapping it opens `pickDay`; the picked day
  becomes the first column. Week and Month as now.

## 2. The mobile hour grid (A and B3)

One widget for phone and tablet, used by both views; the desktop
`WeekGrid` is left as is. Shared parts move out of `desktop_calendar.dart`
only where both use them: `hourRange`, `placeInLanes`, `startMinute`/
`endMinute`, `taskSpan` are already in `domain/week_grid.dart`; the column
header (`WeekColumnHeader` in Figma), the task strip and the now line are
reused rather than copied.

Common to both views:

- **Hours**: `hourRange` over the shown days' events and timed tasks
  (8:00–22:00, stretched to fit), as desktop.
- **Column headers**: weekday + date; today ringed, the selected day's
  column tinted (`primaryContainer`), as desktop. Tapping an empty part
  of a column selects that day.
- **The day sheet** (user's pick): tapping a day's header, or its "N
  people" or task chips in the strip, selects the day and opens a modal
  bottom sheet holding that day's `DaySection` with the timeline of §3:
  tasks with their tick ring, the People block, events with free gaps,
  the day's Add. The phone's version of the desktop day popover; it
  replaces what `WeekList` showed per day. Dragged down or tapped outside,
  it closes; opening an event or a person from it navigates as from the
  month.
- **Strip** under the headers: each day's untimed tasks and "N people", as
  the desktop strip; tapping them opens the day sheet (below). Timed tasks sit on the grid (#377), as desktop.
- **Events** placed at their start, as tall as they last (an hour without
  an end), overlapping ones side by side (`placeInLanes`). Events that are
  over step back (#451). Tapping one opens the event page.
- **No time on the cards**: the hour axis gives it. Each card's semantics
  label still reads the title, start and end.
- **Now line** on today's column, as desktop.
- **No `WeekStrip`** in 3 days and Week: the column headers replace it,
  and the grid takes everything below the switch row (*designer's call*).
  Month keeps its strip and grid as now.
- **Swipe** sideways anywhere on the grid moves to the previous/next page
  (3 days or a week), with the existing `_SwipePager` and its sideways-drag
  recogniser from #357 (a drag that leans sideways is the pager's, even
  inside the grid's vertical scroll and pull to refresh). Covered by the
  same kind of widget test as #357's diagonal swipe. Landscape phones
  (height under 560): the grid scrolls with the page, as the list does now.
- **Pull to refresh** as now. The FAB adds on the selected day, as now.

### A — 3 days

- 3 equal columns. Hour height: the grid scrolls vertically, an hour about
  52 dp (builder may tune to fit the Figma).
- Opens scrolled so the first thing worth seeing is near the top: on a
  page holding today, an hour before now; otherwise an hour before the
  first event of the 3 days; otherwise the range's first hour.
- Card title: the theme's caption style, wrapped over as many lines as the
  card is tall, "…" at the last.

### B3 — Week, focus column

- The selected day's column takes what's left after six 40 dp columns
  (about 94 dp on a 390 wide phone). Selecting another day moves the wide
  column there, animated with `AppMotion.medium` / `standard`.
- When the week opens (or the page turns) the selection follows
  `shiftedDay`: today in the current week, else the same weekday.
- **No vertical scroll** on a phone: the hour height is the space left
  divided by the hours shown, so the whole range fits. Under a floor
  (about 28 dp an hour, builder's call) it scrolls instead, as A.
- **Wide column**: titles in the caption style, wrapped over the card's
  height, "…" at the last line.
- **Narrow columns**: titles at 10 px, a new theme text style (e.g.
  `AppTypography.micro`, 10/12, medium) exposed through the theme, not a
  literal in the widget. Rule: as many **whole words** as fit on the
  card's lines, then "…"; a first word that doesn't fit on its own shows
  as its leading letters + "…" ("Prod…"). Never a word split over two
  lines. Implemented with a small `TextPainter`-based helper next to the
  widget, unit-tested.
- **Tablet and wide phones**: when 7 equal columns would each be at least
  90 dp, all columns are equal and the focus rule is off (same widget).

## 3. D — the day as a timeline (mobile and tablet month)

`DaySection` under the month changes its event list; tasks and the People
block above it stay as they are. The desktop day popover keeps today's
list (it uses `DaySection` with `peopleFoldable: false`; the timeline is
for mobile and tablet only, behind a flag on `DaySection`). The mobile day
sheet of §2 uses the timeline too.

Rows, in time order:

1. **Events**: the existing `EventRow`, unchanged (start and end on the
   left, title, place, invited, workflow chip).
2. **Free gaps**: between two events (overlapping events merged first), a
   dashed outlined row, no time on its left, aligned with the cards:
   "Free · 4 h 30". Only gaps of 1 hour or more; none before the first
   event or after the last.
3. **Now line** (today only): a row with the time ("15:20") in primary
   and a primary line with a dot, between the event before now and the
   one after. An event in progress has the line after it.
4. **The gap after now** (today only): free time that is already gone is
   not shown. A gap that holds now is cut to start at now (*designer's
   call*, as Figma D: training 14–15, now 15:20, the next row is "Free
   until 19:00"). Events 9–10 and 15–16 at 12:00 give: event, now line,
   "Free until 15:00 …", event. The same applies before the first event.
   The 1-hour threshold counts from now. It reads "Free until 19:00" and,
   when people are due today (`PeopleAhead.count(today)` > 0),
   "· N people to follow up ›" in primary. Tapping it unfolds the day's
   People block and scrolls it into view. After the last event there is
   no gap.

Events without an end count as an hour, as on the grid.

Past and future days: gaps without the people part. A day with no events
keeps "Nothing planned".

## 4. Copy (EN, in `app_en.arb` with descriptions; FR via Weblate)

- `calendarThreeDays`: "3 days" (switch segment).
- `calendarFree`: "Free · {duration}" — duration as "4 h 30", "1 h"
  (`{hours} h {minutes}`; minutes left out when 0).
- `calendarFreeUntil`: "Free until {time}" — time in the locale's
  `DateFormat.Hm`/`jm`, as `EventRow`.
- `calendarPeopleToFollowUp`: "{count, plural, =1{1 person to follow up}
  other{{count} people to follow up}}".
- Semantics for cards with hidden text: "{title}, {start} to {end}".

Informal register in FR (*tu*), and no sales/MLM wording.

## 5. Removed

`WeekList` and its `_WeekDayHeading` (the stacked week list) go once the
grid replaces them; their tests and golden go with them. The Figma
`WeekDayHeading` part is then unused (left in the file).

## 6. Tests

- Domain: `shiftedDay` / `shift` for `threeDays` (across months, DST);
  the free-gap computation (merged overlaps, 1 h threshold, now inside a
  gap, now before the first event, event in progress); the whole-words
  fitting helper (fits, cut with "…", single long word).
- Widgets: switch with 3 segments; 3 days shows 3 columns and scrolls to
  now; B3 widens the tapped day, hides card times, narrow titles never
  split a word; tapping a header or "N people" opens the day sheet; D
  shows gaps, the now line and the people link that unfolds the People
  block.
- Goldens: previews for A, B3 and D at mobile size, regenerated through
  CI (README → *Golden tests*).

## Left to the builder

Exact hour heights and the vertical floor, animation curve details, how
the shared grid code is split between files, the names of new widgets and
helpers, and whether the 10 px style lives as a new `TextTheme` slot or a
`LoomiaColors`-style theme extension.

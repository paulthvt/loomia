# Calendar week view — design

Issue: #357. Builds on the calendar epic (#150,
`2026-10-07-calendar-design.md`), whose "Month only" view and "revisit with a
week or day view" note this revisits. Figma: section "Calendar week — #357"
on page "04 — Screens (Light)" (node 394:12766).

## Intent

The month answers "is anything on that day?". Planning a week needs the
whole week at once: what's on each evening, where there's room for one more
workshop. Two smaller pains come with it: reaching a month far off takes one
tap or swipe per month, and the month swipe sometimes doesn't take, so it
needs a second or third try.

## Decisions

| Question | Decision | Reason |
| --- | --- | --- |
| Week view shape | A list of the week's days with their events, under a 7-day strip. No hour grid. | Events are a few per week, mostly evenings: an hour grid is mostly empty rows, and overlapping events need a layout algorithm. Revisit with a day view if someone runs several events a day. |
| Desktop week | The week as 7 columns, each day's events stacked as compact cards (time, title). No day pane: the columns already show every day, so they take the full width (about 165 px each at 1440). Opening an event brings the pane back beside them, the columns narrowing to about 95 px, titles cut to two lines. | The Figma at 1440 with the day pane left 95 px columns that cut most titles; the day pane only repeated one column. |
| Switching views | A Month / Week segmented button, under the title row, with Today at its end. | Two views, both always available. A menu hides it; a third icon in a full top bar doesn't fit at 390 wide. |
| Title row on mobile | The title button, ‹ › and the account button; Today moves to the switch row. The title keeps its 24 px and is cut with "…" if it still can't fit. | The Figma showed title + chevron + Today + ‹ › + account is about 400 px at 390 wide, before longer months ("September 2026", « septembre 2026 »). Moving Today keeps the type and 48 px tap targets. |
| Remembering the view | Kept until the app restarts, like the selected day. | No preferences store exists; adding one for this is a dependency nobody asked for. Persist it when someone asks. |
| Selected day across views | One selected day for both views. Month shows its month, Week its week. | Switching keeps your place. |
| Jumping to a month | Tapping the title opens the existing `pickMonth` (month-and-year wheel on iOS, Material calendar on its years elsewhere). Range: 10 years before and after today. | The picker is already used for "Member since"; the arrows and swipe stay for the neighbouring month. |
| Jumping in week view | Tapping the title opens `pickDay`; the week holding the picked day shows, that day selected. | Same gesture, the picker that fits a week. |
| Week title | Both ends with their month, in the locale's order: "Oct 19 – Oct 25", "Sep 28 – Oct 4" (FR « 19 oct. – 25 oct. »), and with the year when the week crosses one: "Dec 28, 2026 – Jan 3, 2027". `DateFormat.MMMd` / `yMMMd`. | `intl` has no date-range format; dropping the repeated month by hand gets the order wrong in some locales. |
| Week starts on | `MaterialLocalizations.firstDayOfWeekIndex`, as the month grid. | One rule for both views. |
| Arrows, swipe, Today | In week view they move by a week; Today selects today and shows its week. | Same controls, the view's own unit. |
| Empty days in the week list | One muted line under the day's heading: "Nothing planned". Today's heading is marked like the strip's ring. | Every day stays visible, so a free evening reads as free. |
| Quick swipes | A drag that starts while the page is still turning finishes that turn first. | Today the second drag cancels the first turn's animation, whose month change only happens on completion: two swipes, one month. Reproduced in a widget test. |
| Diagonal swipes | On the grid and the strip, a drag that leans sideways is the calendar's, even if its first pixels lean down. | Today the page's vertical scroll claims any drag that passes its slop downwards first; a thumb's arc often does. Reproduced in a widget test (a swipe starting 4 px left / 5 px down per frame turns nothing). |
| Data | No change. | Every event is already loaded (`EventRepository.list`), so a week is a filter. |

## 1. Behaviour

### Selection

`CalendarSelection` gains the view: `({CalendarMode mode, DateTime month,
DateTime day})` (`CalendarView` is already the screen widget's name). `shift(delta)` moves a month in
month view and a week in week view, selecting the same weekday in the new
week, or today when it falls in it. Week arithmetic uses calendar dates
(`DateTime(y, m, d + 7)`), never 7×24 hours, as `monthDays`.

A new domain helper, `weekDays(DateTime day, int firstDayOfWeek)`, returns the
7 days of `day`'s week, local midnights. The month grid's `monthDays` keeps
its contract.

### Month view

Unchanged apart from:

- Today moves from the title row to the end of the switch row;
- the title is a button, with a small chevron, that opens `pickMonth`; the
  month picked shows with its 1st selected, or today in the current month
  (the same rule as `shift`);
- the two swipe fixes above.

### Week view, mobile and tablet

Top to bottom:

1. Title row: the week's dates (a button opening `pickDay`), ‹ ›
   ("Previous week" / "Next week"), account.
2. The Month / Week switch, Today at the row's end.
3. The strip: the week's 7 days, the same day cells as the month grid
   (weekday letters above, dots, today's ring, the selected day filled).
   Swipes turn the week, with the month grid's follow-the-finger motion.
   Tapping a day selects it and scrolls the list to it.
4. The week list: for each day, a heading ("Mon 19", the selected day's in
   primary) and its event rows (`EventRow`, unchanged), or "Nothing planned".
5. The add button adds on the selected day, as today.

Pull to refresh as the month view.

### Week view, desktop

The full width beside the sidebar: title row, switch, then 7 equal columns
under their weekday and date (the date in the month grid's day states).
Each column holds its events as compact cards (time, title up to two lines;
done events muted like the month's past dots) and is a tap target for the
day. Tapping a day selects it and closes an open event; tapping a card opens
the event in a pane on the right, as `openEvent`. No strip and no day pane:
the columns are the days.

### Accessibility

The switch is a `SegmentedButton` (selected state announced). The title
button reads "October 2026, choose a month" / "19 to 25 October, choose a
week". The week list's day headings are headers. Swiping has the arrows as
its non-gesture equivalent, as today.

## 2. Copy

New English keys (FR from Weblate): `calendarViewMonth` "Month",
`calendarViewWeek` "Week", `calendarPreviousWeek` "Previous week",
`calendarNextWeek` "Next week", `calendarWeek` (the week title, from two
dates), `calendarChooseMonth` / `calendarChooseWeek` (the title button's
semantics). "Nothing planned" and the rest are reused.

## 3. To mock

Section "Calendar week — #357", mobile 390 wide unless said, existing
components only except where named:

1. **Month view** with the new title button (chevron) and the Month / Week
   switch under it.
2. **Week view**: strip with today ringed and another day selected, the
   week list with a day of two events, a day of one, empty days.
3. **Week view across two months** ("28 Sep – 4 Oct"), to settle the title.
4. **Desktop week view** (1440): 7 columns with a few cards, the selected
   day's pane on the right. Superseded while planning: no day pane (see
   Decisions → Desktop week); Today on the switch row.

New pieces: the title button, the strip (one row of the month grid's
cells), the week list's day heading, the desktop day column and its compact
card.

## 4. Testing

- Unit: `weekDays` (Monday and Sunday starts, a week across months and
  years, a DST change); week `shift` (same weekday, today when it is in the
  week); the week title's three shapes.
- Widget: switch between views keeps the selected day; week arrows and
  Today; the title opens the month picker and the picked month shows; week
  list shows empty days; desktop columns open an event.
- Swipe regressions (calendar_page_test): two flings 80 ms apart turn two
  months; a drag whose first frames lean down (−4, +5) then go sideways
  turns the month; a plain vertical drag on the grid still scrolls the page.
  The same quick-swipe test for the week strip.
- Goldens: the new `@Preview`s (week, mobile and desktop), regenerated
  through CI.

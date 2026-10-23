# Calendar on desktop — full-width month, hour-grid week

Issue: #366. Figma: "Calendar desktop — #366" on "04 — Screens (Light)",
frames *Month B* (418:13058) and *Week B* (420:15714), new part
`MonthEventChip` (416:12980).

## Intent

On desktop the month grid sits small in the top-left corner, numbers on the
background with no lines between days, and a wide empty area before the day
pane. The week has the same problem, less visibly. Desktop gets a calendar
that uses the window: a ruled month that shows each day's events, and a week
laid out on hours. Mobile and tablet do not change.

## Decisions

| Question | Decision | Reason |
| --- | --- | --- |
| Which proposal | Month B + Week B | Chosen in the issue. |
| Header | One row: title … Month/Week switch, Today, ‹ ›, Refresh | The Figma; Refresh (#358) stays at the end, as on Today. |
| Title size | `headlineSmall` (24) on desktop too | The Figma's title row. |
| Day pane | Gone on desktop. An open event still gets its pane | The popover replaces the day; an event needs its full page. |
| Clicking a day | Selects it and opens a popover under it: the day's events, then Add | The Figma. Chips open their event directly, as in any calendar. |
| Popover mechanics | A modal route with a transparent barrier, placed under the cell (above when there is no room), clamped to the window | Focus moves in, Escape and a click outside close it, focus returns to the day, a screen reader hears it as a dialog named after the day. |
| Add from the popover | Closes it, then opens New event on that day | The same form as everywhere; the saved day is selected. |
| Event in the popover | Closes it, then opens the event in the pane | |
| Month chips | Bar, start time, title on up to 2 lines; done ones greyed | The issue (the Figma's component note says 1 line; the issue wins). |
| Too many chips | As many as fit, then "+N more", which opens the popover | Measured, not a fixed count: a 6-week month and a tall window fit different numbers. |
| Today / selected, month | Today: filled badge. Selected: tinted cell | The Figma. |
| Today / selected, week | Today: ringed date and the now line. Selected: tinted column | Same meaning as the month: tint = selected. In the Figma today is the selected day. |
| Swipe on desktop | None; arrows and Today only | A mouse doesn't swipe. The pager stays on mobile and tablet. |
| Week hours | 8:00–22:00, stretched to whole hours to fit the week's events | Nothing is ever hidden above or below the grid. |
| Hour height | The grid fills the card; below 40 px an hour it scrolls instead | 50 px in the Figma at 900 tall. |
| Event length | Its end, or 1 hour when it has none; cut at midnight | A card needs a height; one that crosses midnight shows on its start day only, as everywhere else. |
| Short events | One line, "14:00 · Team check-in", when time and title don't fit on two | The issue. |
| Overlaps | Side by side: each group of overlapping events splits the column into as many lanes as it needs at once | The issue's open point. |
| Clicking an empty slot | Same as the day: selects it, opens the popover | One way to add, in both views. No add-at-this-hour yet. |
| Now line | Drawn when the page builds | Like Today, which reads the clock on build and resume. No timer. |

## Behaviour

**Header (desktop).** Title button (opens the month or day picker, as now),
then the switch, Today, previous, next, Refresh, on one line.

**Month.** One bordered card filling the rest of the window: weekday names in
overline caps, then the weeks, each an equal share of the height. Hairlines
between days; days of the previous or next month on the sunken surface with
their number dimmed. Each day: its number at the top centre (today in a
filled badge), then its events earliest first as `MonthEventChip`s, then
"+N more" if some don't fit. Clicking the day, its number, "+N more" or empty
space opens the day popover; clicking a chip opens that event.

**Day popover.** 340 wide: the day's heading with Add, then its events as
`EventRow`s, or "Nothing planned".

**Week.** One bordered card: a gutter, then 7 column headers (weekday, date
in a circle, today ringed). Under them the hour rows, hour labels in the
gutter, hairlines between hours and days. The selected column is tinted;
today's has a line at the current time. Events are placed at their start,
as tall as they last, with overlapping ones side by side. Clicking a card
opens the event; clicking elsewhere in a column opens that day's popover.

**Loading and errors** show above the grid, as now.

No database change.

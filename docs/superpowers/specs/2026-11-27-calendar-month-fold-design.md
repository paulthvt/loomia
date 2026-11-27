# Calendar month on phones: tighter rows and the fold — design

Issue: #561 ("more room for the day under the month on phones"). Builds on
#448 (`2026-11-06-mobile-calendar-time-views-design.md`, the day as a
timeline under the month) and keeps #369's swipe rule. Mockup: FigCraft,
Loomia file, page "04 — Screens (Light)", section "Calendar month
collapse — #561" (node 59008): frames 1 (open, tighter rows), 2 (folded to
the selected week) and 3 (folded, on another week).

## Intent

The month view is where the Calendar opens, and on a phone it leaves the
selected day almost no room. On a Pixel 6 (412 × 915 dp) the hero with a
6-row month ends about 588 dp down: about 195 dp, 1.5 event cards, are left
above the floating bar.

Goals:

- the selected day readable under the month, the whole of it when folded;
- the fold feels fluid: one eased movement, quick to start, soft to land,
  never a linear slide;
- nothing new to learn: scrolling the day up folds it, pulling down at the
  top unfolds it.

Non-goals: a continuous agenda (the list running on into the next days),
the tablet and desktop months, the title and hour-grid fixes of #562.

Anti-goals: a half-folded month left on screen; a fold that stops where the
finger stops; a swipe lost to the fold.

## Decisions

| Question | Decision | Reason |
| --- | --- | --- |
| Tighter rows | A day is one 48 dp square: 36 dp number circle, dots and people line inside it. Row 62 → 48 dp. | Frame 1: ~84 dp more on a 6-row month, with the tap size kept. |
| Fold | The month folds into the row holding the selected day. | Frame 2: hero 487 → 247 dp, the whole day fits. |
| Not the Week view | Kept: the folded month is an agenda with a date strip, Week is an hour grid. | Different questions (what vs when); Google, Outlook and Fantastical have both. |
| What drives it | A scroll gesture sets it off; the fold then runs as one timed, eased animation (420 ms, emphasized curve), not tied to the scroll offset. | The user's call: a non-linear fold reads more fluid than one that tracks the finger at constant speed. |
| Never half folded | Once started, the fold always reaches an end. The only way it turns back is the opposite gesture before it lands: it then reverses from where it is, on the same curve. | A half month reads as broken. |
| Unfold | Pull down when the list is at its top, drag the hero down, or tap the handle. | Pull at the top already means "more above" (refresh when open). |
| Pull to refresh | Only when open. Folded, the pull at the top unfolds instead. | One meaning per gesture and state. |
| Which month unfolds | The month holding the selected day. | Frame 3: a week across two months opens on the selected day's. |
| Folded paging | Swipe, ‹ and › move a week; the selection keeps its weekday, or today in today's week (the Week view's rule). | Frame 3; the same rule people already know from Week. |
| Vertical drag on the open grid | None, as now. The hero stays outside the list's scroll; only the folded hero takes a drag down, and a drag leaning sideways stays the pager's. | #369's rule holds: the open month has no vertical drag to lose a swipe to. |
| Reduce motion | Open ↔ folded is a 120 ms cross-fade, no movement. | The `Motion` contract (`app_theme.dart`). |
| Motion design | §7 of `docs/design/design-system.md` gains the emphasized 420 ms row (fold, and the nav pill that already uses it). | The fold doesn't fit the four durations; the nav pill already broke the table without it saying so. |
| Where | Phones with the pinned hero (height ≥ 560). Landscape keeps everything scrolling, no fold; tablet and desktop unchanged. | Only the phone is short of room. |
| Remembered | No: every visit opens unfolded, as the view itself resets to Month. | #357's rule, no preferences store. |
| Data | No change, no migration. | Pure layout. |

## 1. Tighter rows

`DayCell` in the month grid (`month_grid.dart`), mobile and tablet:

- One 48 dp square holds everything: the number in a 36 dp circle at its
  top (filled when selected, ringed today, 1.5 dp ring), then 2 dp, the
  dots (up to 3, 6 dp), then 2 dp, the people line (12 × 2 dp).
  The ink stays on the number circle.
- The rows carry no gap between them beyond the square; the weekday names
  keep their `AppSpacing.xs` gap above the first row.
- The desktop week's column headings, which also use `DayCell`, keep their
  current size: the compact layout is the month grid's, not the cell's
  default.
- At 1.3× text, the number scales down inside its circle (`FittedBox`,
  `scaleDown`) rather than growing the row.

This ships first, on its own, before the fold.

## 2. The fold

### Structure

The pinned month page keeps its shape: the hero, then the day's list in an
`Expanded` (`calendar_page.dart`). The hero holds an `AnimationController`
for the fold, `t` from 0 (open) to 1 (folded). The header row and the
Month / 3 days / Week switch never move; only the grid folds. As the hero
shrinks, the list's top rises with the hero's bottom edge: its content
moves with the hero, never on its own.

### Triggers

A fold or unfold is a *gesture*, read from the list's scroll notifications
and the folded hero's drag, not a scroll position:

- **Fold** (open → folded): the user drags the list up by at least 24 dp in
  one gesture (scroll, or overscroll when the day is too short to scroll:
  an empty day folds too). A fling up folds at once.
- **Unfold** (folded → open), any of:
  - the list is at its top and the user pulls down 24 dp more (or flings
    down from the top);
  - a drag down of 24 dp, or a fling down, starting on the folded hero;
  - a tap on the handle.
- Scrolling down inside a folded day that is not at its top only scrolls
  the list.
- 24 dp is about one row's half: enough to never fire on a tap or a
  sideways swipe's wobble.

### Running

- **Duration and curve**: `AppMotion.emphasized` (420 ms) on
  `Curves.easeInOutCubicEmphasized`, the nav pill's: a quick start, a long
  soft landing. Through `context.motion`.
- **No stop**: a running fold cannot be held or cancelled by a touch. The
  list under it still scrolls with the finger.
- **Reverse**: the opposite trigger while it runs (a pull down at the top
  during a fold, a drag up during an unfold) reverses it from where it is
  (`controller.reverse()` / `forward()`), on the same curve, over the time
  it has already run.
- Taps on the grid while it moves are ignored; the day list's taps work.

### The fold, frame by frame

With `rows` the month's rows (5 or 6), `s` the selected day's row index and
`h` the 48 dp row height, at the animation's eased value `e(t)`:

- **Height**: the grid's visible height is `rows·h − (rows − 1)·h·e`.
  The fold distance is `(rows − 1)·h`: 240 dp on a 6-row month.
- **The selected row** slides up from `s·h` to 0: offset `−s·h·e`. It is
  never faded, so the eye keeps hold of it.
- **The other rows** move with it (the grid moves as one block, clipped
  under the weekday names and at the hero's bottom edge) and fade out over
  the first 60 % of the time (`Interval(0, 0.6, curve: accelerate)`). By
  the time they are clipped they are gone, so no half-cut numbers linger.
  Unfolding, they fade in over the last 60 % (`Interval(0.4, 1, curve:
  decelerate)`), once there is room for them.
- **The weekday names** stay put.
- **The handle** (32 × 4 dp, pill radius, `onHeroQuiet`) fades in over the
  last 30 % of a fold, out over the first 30 % of an unfold, centred
  `AppSpacing.sm` above the hero's bottom edge. Open, it is absent.
- **The hero's bottom radius** and shadow are unchanged at every frame.

The fold math is a pure function in `domain/month_fold.dart`
(`MonthFold(rows, selectedRow, rowHeight).at(e)` → grid offset, visible
height, other rows' opacity, handle opacity), unit tested on its own. The
widget feeds it the controller's eased value and the direction.

### Folded

At `t = 1` the grid's single row is a week pager:

- The `_SwipePager` switches its anchor from the month's 1st to the
  selected day's week start (`weekDays(day, firstDayOfWeek).first`) and its
  pages are one week each. The visible row is the same row in both, so the
  swap shows nothing.
- Swipe, ‹ and › move a week: the day becomes `shiftedDay` with the Week
  view's rule (same weekday, or today in today's week). The page turns as
  the month does now, and the day's list fades to the new day
  (`FadeSwap`, as on a day tap).
- Days outside the selected day's month are dimmed, as in that month's
  grid (frame 3: Mon 30 Nov under "December").
- The title reads the selected day's month and year (#562 drops the
  current year).
- Tapping a day selects it and stays folded.
- Today (the calendar icon) selects today, stays folded, and turns to
  today's week.
- Tapping the title opens the day picker as now; the picked day's week
  shows, still folded.
- Unfolding shows the selected day's month with that day's row in place,
  so the week opens out of itself: `s` is recomputed for that month before
  the first unfold frame.

### Leaving and coming back

- Switching to 3 days or Week and back opens Month unfolded.
- Selecting a day while open never folds; the list keeps its position.
- Turning the phone to landscape (no pinned hero) shows the open month in
  the scrolling page, as now. Back to portrait, it opens unfolded.

### Reduce motion

With the OS flag (`context.reduceMotion`), the triggers are the same and the
change is a 120 ms cross-fade between the open and the folded hero: no
slide, no growing or shrinking in between (`context.motion` and
`FadeSwap`'s reduce-motion path).

## 3. Motion design

`docs/design/design-system.md` §7 and §7.1:

- The duration table gains **420 ms — a large surface changing shape
  (the month folding, the nav pill travelling)**, curve
  `easeInOutCubicEmphasized`. The nav pill (`floating_nav_bar.dart`)
  already uses it; the doc never listed it.
- The decision table gains a row: *Month fold / unfold | 420 ms |
  emphasized | `AnimationController` in the month hero, values from
  `MonthFold`*.
- The rule "no bounce or overshoot" stays: the emphasized curve has none.

A wider review of §7 ("Restrained", the four durations) toward a more fluid
app is its own issue, not this one.

## 4. Copy

One string in `app_en.arb`, with its description:

- `calendarShowMonth`: "Show the whole month" — the folded month's handle,
  for screen readers.

French via Weblate (*tu* register; this one has no verb form to watch).

## 5. Tests

- **Unit** (`test/features/calendar/domain/month_fold_test.dart`):
  `MonthFold.at` at 0, 0.5 and 1 for a 6-row month with the selected day
  in row 0, 3 and 5: height, offset, opacities in both directions; the
  5-row fold distance.
- **Widget** (`test/features/calendar/presentation/calendar_page_test.dart`):
  - a 30 dp drag up on the list folds: after 420 ms the hero is folded,
    the handle shown, one row visible; a 10 dp drag does nothing;
  - mid-fold (200 ms), the fold cannot be stopped: holding the finger still
    and pumping past 420 ms ends folded;
  - mid-fold, a pull down at the list's top reverses it: it ends open;
  - an empty day still folds;
  - folded, pulling down at the top unfolds and does not refresh; open,
    the same pull refreshes;
  - folded, a drag down on the hero unfolds; tapping the handle unfolds;
  - folded, a swipe left selects the same weekday a week later; on a week
    holding today it selects today;
  - folded on Thu 3 Dec, unfolding shows December with Thu 3 selected;
  - a diagonal swipe on the open month still turns the month, and a
    vertical drag on it folds nothing (#369);
  - reduce motion: a fold is done after 120 ms with no frame in between;
  - landscape: no fold, the page scrolls as now.
- **Goldens** (via CI): open with tighter rows (6-row month, French),
  folded, folded on another week, folded at 1.3× text; the existing month
  goldens regenerate for the tighter rows.
- **Long translations**: French previews of the three states, per
  `AGENTS.md`.

## 6. Left to the builder

- The 24 dp trigger and the fade intervals may be tuned on a device; the
  rules they serve (never on a tap or a swipe's wobble, the selected row
  never fades, no half-cut numbers, the handle last) stay.
- Whether the gesture is read from `ScrollUpdateNotification` /
  `OverscrollNotification` or from a `Listener`, as long as a sideways
  swipe never counts toward it.

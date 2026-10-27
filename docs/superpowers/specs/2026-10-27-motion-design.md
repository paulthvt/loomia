# Motion — design

Issue: #384. No Figma section: every end state is already drawn, and what this
adds is how the app gets from one to the next, which a frame can't show. Builds
on `docs/design/design-system.md` §7, which stays the motion language.

## Intent

The app already has a motion language (§7: four durations, three curves, a
"Never" list, reduce motion), but most of it was never applied. Things still
cut: the check snaps in, some ticked rows vanish at once, a new history entry is
already there when the sheet closes, and Show/Hide or picking a day makes
everything below jump. The user then wonders whether anything happened.

This ticket applies §7 where the app still jumps, so every change is seen
happening. The tone is §7's: motion explains what moved, it never celebrates.

- **Goal:** after any tap that changes a list, the user saw what changed
  without having to look for it.
- **Non-goals:** new durations or curves, page transitions (§7.2 stays), haptics,
  sound.
- **Anti-goals:** anything that reads as a reward (a burst, a scale-up, a
  counter), anything that makes a tap feel slower, staggered entrances.

## Decisions

| Question | Decision | Reason |
| --- | --- | --- |
| A new motion language? | No. §7 is it. One row is added to its table (the drawn check) and one rule to its text (lists animate inserts and removals). | The rules already say "a check, then the card slides out"; only the doing is missing. |
| How the check appears | The ring fills (180ms, standard) and the check is drawn stroke by stroke over the fill: short stroke then long stroke, 240ms, decelerate, starting with the fill. | A drawn check says "done" without celebrating. |
| Does the row wait? | Yes: a ticked row leaves only once the check is fully drawn, then slides out (320ms, as now). About 560ms from tap to gone. | Seeing the check is the point; it is also the hold the user asked for. |
| Does saving wait? | No. The tick saves at once, as now. Only the row's removal waits for the draw. | Undo (#372) and the data stay as they are. |
| Save fails | The check un-draws (120ms) and the ring empties, then the existing error snackbar shows. The row never left. | The ring must not claim a tick that didn't happen. |
| Unticking (a crossed-out task in the Calendar) | The check un-draws (120ms) and the ring empties. No hold. | Taking back is not an event. |
| Ghost check in an empty ring | Kept. It fades out (120ms) as the fill starts. | It's the affordance; the drawn check replaces it. |
| Reduce motion | The check appears with a 120ms fade (no drawing), the row fades out (120ms, `SlideSwap`'s existing fallback). Every other item below: its 120ms fade. | §7.3. |
| Lists | A row added grows into its slot and fades in (240ms, decelerate); a row removed fades and its slot closes (240ms, accelerate). Rows that *change key in place* keep `SlideSwap` (320ms). | §7.1 "List reorder" is 240ms. |
| When the new history entry appears | After the sheet has closed, so its arrival is seen. | The user's own example. |
| First load | A list that appears for the first time (load, refresh, pull-to-refresh) does not animate its rows; only inserts and removals after it has shown. | §7.4: "a list appears at once, or it is not ready." |
| Loading → content | The spinner and the content cross-fade (180ms) where the spinner sits in the content's place. | §7.1 "Label ↔ spinner"; the content wasn't on screen, so it's not a page-load fade. |
| Calendar day change | The selected day's list cross-fades (240ms, standard), keyed by the day. No slide. | §7.1 "tab change"; a slide would claim a direction the month grid already shows. |
| Show / Hide (People block, Catch up) | The height eases (240ms, standard); the rows fade in with it. | The jump below is what reads as raw. |
| One ticket | Everything below ships in one PR. | Paul's call. |

## 1. Ticking

**Where:** every tick ring. Today (steps, reminders, LRP checks, tasks, event
steps), the contact page (next step, reminders), the Calendar's task rows, the
workflow timeline's Mark done, the event page's checklist
(`event_page.dart:454`), and Catch up's check-ins (`check_in_items.dart`).

**The ring** is one widget, so the check is built once. Today it is an
`IconButton` with `Icons.check_rounded` and `AppTheme.resolveRing`
(`action_item.dart:196`); the timeline, event page and event items use the same
style with their own `IconButton`. They all move to one shared ring widget in
`lib/core/ui/` that owns the draw.

**Sequence on tap**, for a row that leaves:

| t (ms) | What the user sees |
| --- | --- |
| 0 | The ghost check fades out (120ms); the ring starts filling with `primary` (180ms). The check starts drawing in `onPrimary`: short stroke, then long stroke (240ms total, decelerate). |
| 240 | Check fully drawn. The row starts sliding out to the start (320ms, existing `SlideSwap`), the rows below close the gap. |
| 560 | Gone. The Undo snackbar has been showing since the tick saved. |

- **Rows that stay** (the contact page's next step swapping to the following
  step, the timeline's current step moving on): the check draws the same way,
  and the swap starts once it's drawn.
- **The save is slower than 240ms:** the row stays, check drawn, until the data
  comes back, then leaves. As today, but now with a check on it.
- **The save is faster:** the row still waits for the draw.
- **Undo:** the row comes back as today (`SlideSwap` in), with an empty ring.
- **Two quick ticks** on two rows: each runs its own sequence.
- **Screen readers:** the label doesn't change; the row's removal is announced
  as it is today.

**How it's wired** (my call, after the builder check). Removal today is not
optimistic: the tick sets the row's busy flag (`resolved` on `ActionItem`), the
save is awaited, and the row drops out when the provider updates
(`people_controller.dart` `completeStep`/`completeReminder`,
`tasks_controller.dart` `setDone`). That stays. The motion hangs off the two
signals that already exist, so no tick caller changes:

- **The ring draws when it becomes selected** (`resolved || done` going false →
  true, the moment the tap sets busy) and **un-draws when it stops being
  selected while still on screen** (busy cleared and the row is still there:
  the save failed, or a task was unticked). So a failed save un-draws with no
  new callback; the caller's error snackbar shows as today.
- **The row leaves at the later of** "the provider dropped it" and "240ms after
  the ring started drawing". `SlideSwap` holds the outgoing child (the
  `AnimatedSwitcher` keeps its old widget and state, so the check keeps drawing)
  until its ring has finished, then slides it out. A save slower than 240ms adds
  no extra wait. A swap in place (next step) waits the same way.
- `resolved` keeps its meaning: tick in flight, no second tap.

**Drawing:** a `CustomPainter` that strokes the check's path cut to
`animation.value` (`PathMetric.extractPath`), in a round cap, the width of
`Icons.check_rounded` at 18px. No package.

## 2. Rows that vanish today

- **Contact reminders** (`next_step_section.dart:272`, `:380`): plain `for`
  loops. Each reminder goes into its own `SlideSwap` keyed by reminder id, as the
  step beside it. A ticked one slides out; a new one (from the reminder sheet)
  grows in.
- **Today's event steps** (`today_event_items.dart:55`): plain `for` loop. Same
  slotted `SlideSwap` as Today's people rows (`_slotted`, `today_page.dart`).

## 3. History

`history_section.dart:120` lists entries in a plain `for` loop.

- **Added** (log activity sheet, a tick writing an entry while the page is open):
  the entry grows into its place and fades in (240ms), after the sheet is closed.
  Entries below move down with it.
- **Deleted:** the entry fades and its slot closes (240ms). Entries below move up.
- **Edited:** the entry's text changes in place, no motion. If the edit moves it
  (a new date), it is a remove at the old place and an add at the new one.
- **"See all":** the extra entries appear at once (a list that wasn't shown is
  not an insert). The button's own disappearance follows the list rule.
- **Undo of a tick** removes its entry with the same fold.

## 4. Lists elsewhere

The same list rule (grow in, fold out, 240ms) for inserts and removals after a
list has shown:

- **Contacts list** (`contact_list.dart:237`): a person added or deleted. A
  filter change is a new list: it cross-fades (180ms) instead of animating rows.
- **Tags** in the tag sheet and settings, **workflows** in settings, **tasks** in
  the Calendar's day list: any list that gains or loses one row from the user's
  own action.

## 5. Sections and swaps

- **People block / Catch up Show-Hide** (`lib/features/calendar/presentation/people_block.dart:60`): `AnimatedSize`
  (240ms, standard) around the folded/open body; the rows fade in with it.
- **Calendar day change** (`calendar_page.dart` around `:498`, the `below`
  list): `AnimatedSwitcher` keyed by the selected day, 240ms cross-fade. The
  mobile week list and the desktop day popover are unaffected.
- **Nudge card** (`today_page.dart:788`): grows in and folds out (180ms, §7.1
  "Inline message appearing").
- **Today all done** (`today_page.dart:864`, `_allDone` vs `_due`): when the last
  row leaves, the done state fades in (320ms) after the row's slide, not in its
  place mid-slide.
- **Workflow timeline:** the current step's wash moves with `AnimatedContainer`
  (180ms) when Mark done moves it on.
- **Loading → content:** wherever a centred `CircularProgressIndicator` sits in
  the content's place (contacts, history, Today, timeline and the rest; the
  builder finds them with a grep), the branch goes through one `AnimatedSwitcher`
  (180ms fade). A shared helper if three or more need it.

## 6. Design system

`docs/design/design-system.md` §7:

- Table: add "Tick | ring 180ms standard, check drawn 240ms decelerate, then the
  row's slide | shared ring widget".
- Rules: "completing an action is a check, then the card slides out" becomes
  "the check is drawn, then the card slides out". Add: "a list animates the rows
  the user added or removed (240ms); a list that appears for the first time does
  not."
- §7.1: add rows for list insert/remove, day change, Show/Hide, loading swap,
  with the widget each uses.

## 7. Tests

- **Ring:** after a tap, at 120ms the check is partly drawn (the painter's
  progress is between 0 and 1), at 240ms fully drawn; with reduce motion, a fade
  of 120ms and no draw.
- **Hold:** with a save that returns at once, the row is still in the tree at
  200ms and gone after 240 + 320ms. With a save that takes 500ms, it starts
  leaving at 500ms, not 740ms. With a save that fails, the ring is empty again
  after 120ms and the row never left.
- **History:** an added entry is present and growing after the sheet closes; a
  deleted one is gone after 240ms.
- **First load:** a list loaded from scratch has no row in mid-animation.
- **Contact reminders, Today event steps:** a ticked one is still visible during
  the slide, gone after it.
- **Calendar day change, Show/Hide:** an `AnimatedSwitcher`/`AnimatedSize` is
  running right after the tap and settles at 240ms.
- **Goldens:** end states only, so none should change. If one does, it is a bug.

## Left to the builder

- Widget names, and whether the list rule is one shared widget or
  `AnimatedList` per list.
- The exact path of the drawn check, as long as it matches the
  `check_rounded` glyph's shape and weight.
- Which loading spinners qualify, by the rule in §5.

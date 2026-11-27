# Calendar month fold Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** On phones, give the selected day more room under the month: tighter rows, then the month folding to the selected week as one eased animation set off by a scroll gesture.

**Architecture:** The fold state is UI state beside the selection: a `bool` provider the selector resets on a mode change and reads to page by weeks. `CalendarView` stays a function of its inputs (`folded`, `onFold`); a small stateful `_Folding` turns the bool into an `AnimationController` (420 ms, emphasized). `MonthGrid` draws any fold progress (clip, offset, fades) from a pure `MonthFold`, and shows one week when given `week`.

**Tech Stack:** Flutter, `flutter_riverpod`, `flutter_test`. No new dependency, no migration, no Edge Function.

**Spec:** `docs/superpowers/specs/2026-11-27-calendar-month-fold-design.md` (FigCraft section "Calendar month collapse — #561", node 59008).

## Global Constraints

- Material from `package:material_ui/material_ui.dart`; imports `package:loomia/...` only.
- No hard-coded colour, radius, spacing or font size in widgets.
- Durations through `context.motion(...)`; the fold is `AppMotion.emphasized` on `Curves.easeInOutCubicEmphasized`.
- Copy only in `lib/l10n/app_en.arb`, with a description.
- Desktop and tablet-with-sidebar behaviour unchanged.
- Quality gate before each commit: `dart format .`, `flutter analyze`, `flutter test`. Goldens regenerate through CI only.
- Commits: Conventional Commits, scope `calendar`, ending `(#561)`.

## Rulings made while planning

- `DayCell` is used only by `MonthGrid` (mobile and tablet); the compact layout replaces its layout, no flag. Spec corrected.
- The title tap in month opens the month picker, as now (spec said day picker; corrected).
- `folded` lives in its own provider, not in `CalendarSelection`: the record has 28 literal sites and the fold is not part of what is selected.
- Fade intervals run on the animation's raw time, geometry on the eased value. With raw time `t`, "fade out over the first 60 % of a fold" and "fade in over the last 60 % of an unfold" are the same function `1 − t/0.6`; the handle's is `(t − 0.7)/0.3` both ways.
- Pull to refresh stays mounted (so the list keeps its scroll position) and ignores pulls while folded through `notificationPredicate`.

## Review Focus

1. **The swap at the end of a fold is invisible**: month grid at progress 1 and the one-week grid draw the same pixels. Golden of both.
2. **#369**: the open month has no vertical drag; a diagonal swipe still turns the month. Test in Task 4.
3. **Reverse mid-way** ends where the user last asked, never half folded. Test in Task 4.

---

### Task 1: Tighter rows

**Files:** Modify `lib/features/calendar/presentation/month_grid.dart`. Test `test/features/calendar/presentation/month_grid_test.dart`.

- [x] Test: a 6-row month's rows are 48 dp apart (`tester.getTopLeft` of the cells of day 2 and day 9); the number circle is 36 dp.
- [x] Implement: `DayCell` is one 48 dp square (tap anywhere in it), a 36 dp circle (ink on it), 2 dp, dots 6 dp, 2 dp, people line 2 dp; the number in a `FittedBox(scaleDown)`. Rows with no gap between them.
- [x] Run the calendar tests; commit `feat(calendar): tighter month rows on phones (#561)`.

### Task 2: `MonthFold`

**Files:** Create `lib/features/calendar/domain/month_fold.dart`, test `test/features/calendar/domain/month_fold_test.dart`.

- [x] Test: for 6 rows, row 3, 48 dp: `height(0) == 288`, `height(1) == 48`, `height(0.5) == 168`; `offset(1) == -144`, `offset(0) == 0`; `othersOpacity(0) == 1`, `(0.3) == 0.5`, `(0.6..1) == 0`; `handleOpacity(0.7) == 0`, `(1) == 1`; `distance == 240`; 5 rows `distance == 192`.
- [x] Implement `MonthFold(rows, selectedRow, rowHeight)` with those four functions and `distance`, plain Dart.

### Task 3: Fold state and week paging

**Files:** Modify `lib/features/calendar/presentation/calendar_controller.dart`, test `calendar_controller_test.dart`.

- [x] Test: `monthFoldedProvider` starts false; `setMode(week)` resets it; folded, `shift(1)` on Thu 5 Nov selects Thu 12 Nov, and on the week before today's selects today; open, `shift(1)` still moves a month.
- [x] Implement `monthFoldedProvider` (`NotifierProvider<MonthFolded, bool>` with `set(bool)`); `setMode` resets it; `shift` in month and folded uses the Week rule of `shiftedDay`.

### Task 4: The fold on the page

**Files:** Modify `month_grid.dart`, `calendar_page.dart`, `lib/l10n/app_en.arb`. Test `calendar_page_test.dart`.

- [x] `MonthGrid` gains `fold` (eased progress), `fade` (raw time) and `week` (a week start: one row). Rows clip under the weekday names; the block moves by `MonthFold.offset`; rows other than the selected one take `othersOpacity`.
- [x] `CalendarView` gains `folded` and `onFold`; with `onFold` null nothing folds (previews, desktop). `_Folding` owns the controller; at a completed fold the month pager becomes a week pager (anchor the selected day's week start). The handle (32 × 4, `onHeroQuiet`) sits in the hero's bottom padding, a button "Show the whole month".
- [x] Gestures: a list drag of 24 dp up (scroll or overscroll) folds; folded, at the list's top, 24 dp down unfolds; a 24 dp drag down on the folded hero unfolds; the handle unfolds. Refresh ignores pulls while folded.
- [x] Reduce motion: the grid shows its end state through `FadeSwap`, 120 ms.
- [x] Tests (phone 390 × 844): 30 dp drag up folds after 420 ms, 10 dp does nothing; mid-fold the fold cannot be held; mid-fold a pull down at the top reverses it; empty day folds; folded pull at the top unfolds without refreshing; handle unfolds; folded swipe moves a week; unfolding after paging into December shows December; diagonal swipe on the open month still turns it; reduce motion done in 120 ms; landscape no fold.
- [x] Wire `CalendarPage`: `folded: ref.watch(monthFoldedProvider)`, `onFold: notifier.set`.
- [x] Commit `feat(calendar): fold the month to the selected week on phones (#561)`.

### Task 5: Previews and docs

- [x] Preview `calendar_month_folded_light` (folded, Oct 8 week), registered in `test/previews_test.dart`.
- [x] Goldens through CI (run 46042468505).
- [x] French render check of the touched screens (`--dart-define=GOLDEN_LOCALE=fr`).
- [ ] Tick #561's boxes.

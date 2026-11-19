# Today All-Done on Desktop Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** On desktop, once everything on Today is ticked, the hero band carries the all-done moment (greeting, a hero-inset panel with the headline, the warm line and a full bar, badge and confetti art on the right) instead of a white card on the far right. Catch up moves into the main column, and the empty Tasks header goes.

**Architecture:** A new `AllDoneBand` next to `AllDoneCard` in `all_done_card.dart`, sharing its private `_Confetti` and a new private `_DoneBadge` (Task 1). `TodayView`'s desktop branch puts `AllDoneBand` in the `HeroPanel` for the `done` branch and moves the check-in items from `side` to the main rows (Task 2). Two new previews get CI goldens (Task 3). Phone and tablet code paths are untouched.

**Tech Stack:** Flutter, `material_ui`, `flutter_riverpod` (no codegen), gen-l10n ARB (no new keys).

**Spec:** `docs/superpowers/specs/2026-11-15-today-all-done-desktop-design.md`. Visual reference: `docs/design/horizon/today_all_done_desktop_light.png`, `today_all_done_desktop_dark.png`.

## Global Constraints

- Branch `feature/518-today-all-done-desktop` off `main`; Conventional Commits; PR body `Closes #518`.
- No new dependency, no new ARB key. Material from `package:material_ui/material_ui.dart`, imports `package:loomia/...`.
- No hard-coded colour, radius, font size or spacing: `LoomiaColors.of(context)`, `Theme.of(context).colorScheme`, `AppSpacing.*`, `AppRadii.*`, `AppTypography.*`, `AppTheme.heroInset(context)`. The art box (300 × 200), the badge (112) and the panel's max width (520) are layout constants, named `static const` on `AllDoneBand`.
- Branch on `context.screenSize` only. Mobile and tablet render exactly as before: no existing golden may change.
- No streaks, scores or ranks. The all-done test's competitive-word check covers the band too.
- Never commit locally rendered goldens: `git checkout -- test/goldens` before every commit.
- Before calling a task done: `dart format .`, `flutter analyze` ("No issues found!"), `flutter test`.

## Rulings made while planning

- **Bar caption under the bar**, through `LoomiaProgressBar(leadingLabel: todayDone(done, done))`, not beside it. That's the widget's only caption slot, and Goals' band does the same. The mockup was updated to match.
- **The band swaps as a whole.** On desktop the `HeroPanel`'s single child is a `FadeSwap` keyed by the band layout (`due-card`, `done`, `plain`). `FadeSwap` already holds the shared greeting without dimming and animates the height.
- **`side` is built after the branch is known.** That way the check-ins can leave it in the `done` branch. `ritualInvitation` and `volumeCard` stay in `side` in every branch.
- **No art below 1200.** There is nothing to hide: `AllDoneBand` exists on desktop only, and desktop starts at `Breakpoints.desktop`.

## Review Focus

- **Contrast:** every glyph of the all-done text is on the hero inset, never bare on the gradient. → Task 1 test `the band's text sits on the hero inset`. The inset's 4.5:1 is already pinned by `app_theme_test.dart` ("the hero inset's white text meets AA over the gradient's end").
- **French at 1.3× on the narrowest desktop (1200 × 900)** wraps without overflow. → Task 2 test `done band survives French at 1.3x on a 1200 window`.
- **The last ticked task still shows its check before it leaves**, now that the done branch drops the tasks block on desktop. → existing `today_tasks_test.dart` / `undo_tick_test.dart` must pass unchanged. Run them in Task 2 at desktop size as well (Step 5).
- **Catch up exists once.** It moves to the main column and is gone from the side column, never in both. → Task 2 test `done on desktop: Catch up leads the main column, not the side`.
- **Phone unchanged.** → no change under `test/goldens/` for existing names after the CI run (Task 3).

---

### Task 1: `AllDoneBand`

**Files:**
- Modify: `lib/features/today/presentation/all_done_card.dart`
- Test: `test/features/today/all_done_card_test.dart`

**Interfaces:**
- Produces: `class AllDoneBand extends StatelessWidget { const AllDoneBand({required Widget header, required int done, required String firstName, super.key}); static const panelKey = ValueKey('all-done-panel'); static const confettiKey = ValueKey('all-done-band-confetti'); }`
  - Layout: `Row(crossAxisAlignment: center)` → `Expanded(Column(start))` [`header`, `SizedBox(height: AppSpacing.lg)`, `ConstrainedBox(maxWidth: 520)` → `DecoratedBox(key: panelKey, decoration: AppTheme.heroInset(context))` → `Padding(AppSpacing.lg)` → `Semantics(container: true)` → `Column(start)` [headline `titleLarge` onHero, `SizedBox(sm)`, body `body` onHero, `SizedBox(md)`, `LoomiaProgressBar(value: 1, tone: ProgressTone.onHero, leadingLabel: l10n.todayDone(done, done))`]], `SizedBox(width: AppSpacing.xl)`, `ExcludeSemantics(SizedBox(300 × 200, Stack(center) [Positioned.fill(key: confettiKey, _Confetti(colors: [onHero, onHeroQuiet, brand, chrome, onHero, onHeroQuiet])), _DoneBadge(size: 112, decoration: BoxDecoration(shape: BoxShape.circle, color: colors.onHero, boxShadow: colors.heroCardShadow), ink: scheme.primary)]))`.
  - The body is the same string `AllDoneCard` picks: `firstName.trim().isEmpty ? todayAllDoneBodyUnnamed : todayAllDoneBody(firstName.trim())`. Move that choice into one private top-level helper `_body(l10n, firstName)` that both widgets use.
- Produces (private): `_DoneBadge({required double size, required Decoration decoration, required Color ink})`. `AllDoneCard` passes its existing gradient circle, `AllDoneBand` a white circle with `heroCardShadow`. The icon is `Icons.check_rounded` at `size / 2`.

- [x] **Step 1: Write the failing tests** in `all_done_card_test.dart`, with a `pumpBand(tester, {firstName = 'Pauline'})` that pumps `AllDoneBand(header: const Text('Good morning, Pauline'), done: 15, firstName: firstName)` in a `SizedBox(width: 1128)` under `AppTheme.light`:
  - `the band shows the greeting, title, warm line and count`: finds `'Good morning, Pauline'`, `"You're all done for today"`, `textContaining('Congrats, Pauline')`, `'15 of 15 done'`. Runs the same competitive-word loop as the card test.
  - `the band's text sits on the hero inset`: for each of the title, body and count `Text`, `find.ancestor(of: it, matching: find.byKey(AllDoneBand.panelKey))` finds one, and `tester.widget<Text>(it).style!.color == LoomiaColors.light.onHero`.
  - `the band's art is hidden from screen readers`: as the card's confetti test, with `AllDoneBand.confettiKey`, and also `find.byIcon(Icons.check_rounded)` has an `ExcludeSemantics` ancestor.
  - `the band: no first name, the warm line goes without`: as the card's test.
  - `the band is read greeting first, then the panel`: with `ensureSemantics`, the panel's `Semantics` node label contains the title and `15 of 15 done`, and its rect is below the header's.
- [x] **Step 2:** `flutter test test/features/today/all_done_card_test.dart` → FAIL (`AllDoneBand` undefined).
- [x] **Step 3:** Implement `_body`, `_DoneBadge` (refactor `AllDoneCard` onto it, same pixels) and `AllDoneBand` as above.
- [x] **Step 4:** `flutter test test/features/today/` → PASS (the existing card tests are unchanged).
- [x] **Step 5:** Commit `feat(today): an all-done band for the desktop hero (#518)`.

### Task 2: Wire it into `TodayView` on desktop

**Files:**
- Modify: `lib/features/today/presentation/today_page.dart` (`build` of `_TodayViewState`, lines ~705–1000)
- Test: `test/features/today/today_progress_test.dart`

**Interfaces:**
- Consumes: `AllDoneBand` (Task 1), `checkInItems` (unchanged signature).
- Changes, desktop only (`desktop == true`):
  1. The `done` branch's rows are `[...eventsBlock, ...catchUp]`, where `catchUp = checkInItems(l10n, widget.checkIns, onOpen: …, onCheckIn: …, onNotNow: …)` with no `collapsed`/`onToggle` (open, no Hide, as in `side` today). There is no `tasksBlock`. On mobile, the `done` rows stay `[...ritualCard, ...eventsBlock, ...tasksBlock]`.
  2. `side` is built after the `(branch, rows)` switch; its check-in group is added only `if (widget.checkIns.isNotEmpty && !(desktop && branch == 'done'))`.
  3. The desktop `HeroPanel` child becomes `FadeSwap(duration: AppMotion.slow, child: …)`, where the child is `KeyedSubtree(key: ValueKey('band-done'), child: Semantics(container: true, child: AllDoneBand(header: topBar, done: widget.done!, firstName: widget.firstName)))` when `branch == 'done'`, and otherwise `KeyedSubtree(key: ValueKey('band-$branch'), child: Row([Expanded(topBar), if (heroCard != null) …]))` (today's Row, unchanged). In the `done` branch on desktop, `heroCard` is not built.
  4. `_heroCardWidth` stays: the `due` card still uses it.

- [x] **Step 1: Write the failing tests** in `today_progress_test.dart`. Extend `pump` with `List<CheckIn> checkIns = const []` and `Locale? locale` (passed to `MaterialApp.locale`). For text scale, set `tester.platformDispatcher.textScaleFactorTestValue = 1.3` with `addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue)`, as `app_shell_test.dart` does. Build one `CheckIn` record inline: `(person: Person(id: 'lea', name: 'Léa Moreau', stage: Stage.team, stageSince: DateTime.utc(2025, 2)), reason: CheckInReason.quiet, since: DateTime(2026, 7, 12), days: 92)`.
  - **Replace** `everything done on desktop: the line on the hero card, beside the greeting` with `everything done on desktop: the band carries it, no white card`: at 1440 × 900, `find.byType(AllDoneBand)` finds one, `find.byType(AllDoneCard)` and `find.byType(HeroCard)` find nothing, and the test file's `_body` string has a `HeroPanel` ancestor.
  - `done on desktop: no empty Tasks header`: `find.text('Tasks')` finds nothing.
  - `done on desktop: Catch up leads the main column, not the side`: with one check-in, `find.text('Catch up')` finds one; its left edge is less than the volume card's left edge (pass `goals:` the same way `today_goals_test.dart` does, or assert it's less than `1440 / 2`); `find.text('Hide')` finds nothing.
  - `done on desktop, undone: back to the card`: pump done, then re-pump with `due: [_due('Anna')], done: 1`, `pumpAndSettle`; `HeroCard` finds one, `AllDoneBand` finds nothing.
  - `done band survives French at 1.3x on a 1200 window`: size 1200 × 900, `locale: Locale('fr')`, `textScale: 1.3`; `tester.takeException()` is null.
  - `phone done is unchanged`: at 390 × 844, `AllDoneCard` finds one, `AllDoneBand` finds nothing, `find.text('Tasks')` finds one (pins today's phone behaviour).
- [x] **Step 2:** `flutter test test/features/today/today_progress_test.dart` → FAIL.
- [x] **Step 3:** Implement changes 1–4.
- [x] **Step 4:** `flutter test test/features/today/` → PASS.
- [x] **Step 5:** Re-run the tick tests at desktop size too: temporarily set the `size` in `today_tasks_test.dart`'s "last task ticked" case to `Size(1440, 900)`, run, revert. Confirm the check still draws before the row leaves. No commit of that change.
- [x] **Step 6:** Visual check (local render, thrown away):
  ```bash
  RENDER_PREVIEWS=1 flutter test test/previews_test.dart --update-goldens --plain-name today_all_done_desktop_light
  # compare test/goldens/today_all_done_desktop_light.png with docs/design/horizon/today_all_done_desktop_light.png
  git checkout -- test/goldens
  ```
  (This needs Task 3's preview. If you're running tasks in order, do this check after Task 3 Step 1.)
- [x] **Step 7:** `dart format .`, `flutter analyze`, `flutter test`; commit `feat(today): the desktop band is the all-done moment; Catch up leads (#518)`.

### Task 3: Previews and goldens

**Files:**
- Modify: `lib/features/today/presentation/today_preview.dart`
- Modify: `test/previews_test.dart`
- Add (from CI only): `test/goldens/today_all_done_desktop_light.png`, `today_all_done_desktop_dark.png`

- [x] **Step 1:** Add, after the mobile all-done previews:
  ```dart
  /// Everything ticked on desktop: the band carries the moment and Catch up
  /// leads the main column.
  @Preview(group: 'Today', name: 'All done desktop — light', size: Size(1440, 900))
  Widget todayAllDoneDesktopLight() =>
      _app(AppTheme.light, const [], goals: _goals, done: 15, checkIns: _catchUp);

  @Preview(group: 'Today', name: 'All done desktop — dark', size: Size(1440, 900))
  Widget todayAllDoneDesktopDark() =>
      _app(AppTheme.dark, const [], goals: _goals, done: 15, checkIns: _catchUp);
  ```
  and in `previews_test.dart` after `today_all_done_mobile_dark`:
  ```dart
  'today_all_done_desktop_light': (const Size(1440, 900), todayAllDoneDesktopLight),
  'today_all_done_desktop_dark': (const Size(1440, 900), todayAllDoneDesktopDark),
  ```
- [x] **Step 2:** `flutter test test/previews_test.dart` → PASS off Linux (renders without exception). Visual check both names against the PNGs (see Task 2 Step 6).
- [ ] **Step 3:** Commit `test(today): all-done desktop previews (#518)`, push the branch, then regenerate through CI (README → *Golden tests*):
  ```bash
  gh workflow run CI --ref feature/518-today-all-done-desktop -f update-goldens=true
  gh run list --workflow CI --branch feature/518-today-all-done-desktop --event workflow_dispatch --limit 1
  gh run watch <run-id>
  rm test/goldens/*.png
  gh run download <run-id> -n goldens -D test/goldens
  ```
- [ ] **Step 4:** Open the two new PNGs next to the mockups. `git status test/goldens` must show only the two new files: any modified existing golden means the phone or the desktop `due` state changed, so stop and fix it. Commit `test(today): goldens for the all-done desktop band (#518)`.

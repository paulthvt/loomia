# Today Progress Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** The Today hero shows "X of N done" and a white bar that grows on each tick. X is the steps and reminders ticked today; N is X plus what is still on the list. Once everything is done, the hero stays: "That's everyone for today", with a full bar (#292).

**Architecture:** No schema change. `ActivityRepository.doneOn(day)` counts today's `step` / `reminder` activity rows (a PostgREST head count). `doneTodayProvider`, an autoDispose family keyed by `(owner, day)` next to `TodayPage`, holds that count. `TodayPage._tick` adds one when `writePeople` succeeds. `TodayView` takes `int? done` and passes `(done, total)` to `TodayHero`, which renders the existing `LoomiaProgressBar(tone: primary)`.

**Tech Stack:** Flutter (`material_ui`), `flutter_riverpod` 3, Supabase (PostgREST).

**Spec:** `docs/superpowers/specs/2026-10-12-today-progress-design.md`. Figma: [Today progress — #292](https://www.figma.com/design/spz2vsSK8gbt1Ok2rW1sdQ/Loomia?node-id=320-10151).

## Global Constraints

- No new dependency and no migration. Stage only changed files by path.
- "Today" is the device's: `today()`; days go to PostgREST through `dayColumn()`.
- Dart: `package:loomia/...` imports; Material from `package:material_ui/material_ui.dart`.
- Theme from `colorScheme`, `LoomiaColors`, `AppSpacing`, `AppTypography`. No literal sizes or colours.
- Copy: English only, in `lib/l10n/app_en.arb`, every key with a description; `flutter gen-l10n`. `app_fr.arb` untouched.
- The headline keeps counting people. The bar counts rows. No percentage anywhere, including semantics.
- Quality gate per task: `dart format .`, `flutter analyze` ("No issues found!"), `flutter test`. Goldens from CI only.
- Branch `feature/292-today-progress`; PR body `Closes #292`.

## Rulings made while planning

- **The +1 is in `TodayPage._tick`, not in `PeopleController`.** Only Today shows the count, and a contact-page tick is picked up when Today is built again (autoDispose). This keeps `contacts/` from importing `today/`.
- **`TodayHero` reads `AppLocalizations` itself** for the caption. It takes the numbers, not a preformatted string, so the screen-reader label and the caption can't drift.
- **Hero spacing follows Figma:** 12 (`AppSpacing.ms`) between the headline and the bar. The bar-to-caption gap stays `LoomiaProgressBar`'s own 8. Figma shows 12; `LoomiaProgressBar` is shared with the goal cards and isn't changed for this.
- **The existing previews pass `done`**, so the Mobile, Desktop, Events and Nudge goldens show the bar. Empty stays `done: 0`. One new preview covers the all-done state.
- **Figma leftovers ignored:** the desktop frames' sidebar still shows "Team" and a September date, and the Priority header's "See all" is a template leftover. None of them are in scope.

## Review Focus

1. The count only includes `step` and `reminder` entries on the device's today. Pinned in Task 1 (fake) and Task 3 (page).
2. A failed tick doesn't move the count. Pinned in Task 3.
3. The all-done hero appears only when nothing is due and something was done. Nothing due and nothing done (or the count unknown) is still the up-to-date empty state. Pinned in Task 2.
4. A screen reader hears "1 of 3 done", once, and no percentage. Pinned in Task 2.

---

### Task 1: `doneOn` and `doneTodayProvider`

**Files:**
- Modify: `lib/features/contacts/data/activity_repository.dart`
- Modify: `test/features/contacts/fake_activity_repository.dart`
- Create: `lib/features/today/presentation/done_today.dart`
- Create: `test/features/today/done_today_test.dart`

- [x] **Step 1: Failing test** `test/features/today/done_today_test.dart`. It's a `ProviderContainer` with `activityRepositoryProvider` overridden by a `FakeActivityRepository` holding, for day `2026-10-12`:
  - one `step` and one `reminder` that day;
  - a `call` that day;
  - a `step` on `2026-10-11`.

  The cases:
  - `doneTodayProvider((owner: 'a@x', day: DateTime(2026, 10, 12))).future` completes with 2;
  - `add()` makes it 3;
  - with `owner: null` it is 0, and the fake records no call;
  - with `failWith = PeopleFailure.network` it is an `AsyncError`, and `add()` leaves it an error.
- [x] **Step 2: `ActivityRepository.doneOn`:**

```dart
  /// Steps and reminders ticked on [day]: the entries `complete_step` and
  /// `complete_reminder` write. Today's "X of N done".
  // ponytail: no (owner_id, happened_on) index; add one if this shows up slow.
  Future<int> doneOn(DateTime day) => guardPeople(() async {
    final response = await _client
        .from(_table)
        .select('id')
        .inFilter('kind', [ActivityKind.step.name, ActivityKind.reminder.name])
        .eq('happened_on', dayColumn(day))
        .count(CountOption.exact);
    return response.count;
  });
```

  `ActivityKind.step` / `.reminder` are the enum names. Ruling while implementing: no `.limit(0)`. Older PostgREST mishandles `limit=0` with a count, and a day's ids are a few bytes.
- [x] **Step 3: Fake.** In `FakeActivityRepository`:

```dart
  @override
  Future<int> doneOn(DateTime day) async {
    await _record('doneOn(${day.year}-${day.month}-${day.day})');
    return store
        .where(
          (entry) =>
              (entry.kind == ActivityKind.step ||
                  entry.kind == ActivityKind.reminder) &&
              entry.happenedOn == day,
        )
        .length;
  }
```

- [x] **Step 4: `done_today.dart`:**

```dart
/// Today's ticks so far, for the hero's "X of N done". Keyed by the day, so
/// a resume on the next day reads a new count. Disposed with Today: ticks
/// made elsewhere show once Today is opened again.
final doneTodayProvider = AsyncNotifierProvider.autoDispose
    .family<DoneToday, int, ({String? owner, DateTime day})>(
      DoneToday.new,
      retry: (error, _) => null,
    );

class DoneToday extends AsyncNotifier<int> {
  DoneToday(this.key);

  final ({String? owner, DateTime day}) key;

  @override
  Future<int> build() async => key.owner == null
      ? 0
      : ref.watch(activityRepositoryProvider).doneOn(key.day);

  /// A tick on Today went through: counted at once, in the same frame the
  /// row leaves. An unknown count stays unknown.
  void add() {
    if (state case AsyncData(:final value)) state = AsyncData(value + 1);
  }
}
```

- [x] **Step 5:** Run the gate. Commit `feat(today): count the steps and reminders done today`.

### Task 2: The hero's bar and the all-done state

**Files:**
- Modify: `lib/l10n/app_en.arb`
- Modify: `lib/features/today/presentation/today_hero.dart`
- Modify: `lib/features/today/presentation/today_page.dart` (`TodayView` only)
- Modify: `test/features/today/today_page_test.dart` (a `TodayView` group)

- [ ] **Step 1: Copy.** Next to `todayHeadline`:

```json
  "todayDone": "{done} of {total} done",
  "@todayDone": {
    "description": "The Today hero's caption under its progress bar: steps and reminders ticked today out of today's whole list (done + still waiting). Never a target or a percentage.",
    "placeholders": { "done": { "type": "int" }, "total": { "type": "int" } }
  },
  "todayAllDone": "That's everyone for today",
  "@todayAllDone": {
    "description": "The Today hero's sentence once everything on today's list was ticked. Calm, not a celebration."
  },
```

  Then run `flutter gen-l10n`.
- [ ] **Step 2: Failing tests**, a `group('TodayView progress', …)` pumping `TodayView` directly in a `MaterialApp` with `localizationsDelegates`, as `today_preview.dart`'s `_app` does, on `Size(390, 844)`:
  - two rows due (two people), `done: 1`: `find.text('1 of 3 done')` and `find.text('2 people are worth a message today')`. `tester.getSemantics(find.byType(LoomiaProgressBar))` has label `'1 of 3 done'`. `find.bySemanticsLabel(RegExp('%'))` finds nothing.
  - two rows due, `done: null`: `find.byType(LoomiaProgressBar)` finds nothing.
  - nothing due, `done: 3`: "That's everyone for today", "3 of 3 done" and the `todayEmptyBody` text. No "You are up to date".
  - nothing due, `done: 0`, and again with `null`: "You are up to date", and no `LoomiaProgressBar`.
  - desktop (`Size(1440, 900)`), nothing due, `done: 2`: the body is below the hero (`getTopLeft(body).dy > getBottomLeft(find.byType(TodayHero)).dy`).
- [ ] **Step 3: `TodayHero`:**

```dart
  const TodayHero({
    required this.eyebrow,
    required this.headline,
    this.progress,
    super.key,
  });

  /// Rows ticked today out of today's list; null while unknown, and then the
  /// hero is the sentence alone.
  final ({int done, int total})? progress;
```

  In `build`, after the headline:

```dart
          if (progress case (:final done, :final total)) ...[
            const SizedBox(height: AppSpacing.ms),
            // Heard as the caption, once; never as the indicator's percent.
            Semantics(
              label: l10n.todayDone(done, total),
              excludeSemantics: true,
              child: LoomiaProgressBar(
                tone: ProgressTone.primary,
                value: total == 0 ? 0 : done / total,
                leadingLabel: l10n.todayDone(done, total),
              ),
            ),
          ],
```

  Update the class doc: the footer counts today's own list.
- [ ] **Step 4: `TodayView`.** Add `this.done` to the constructor:

```dart
  /// Steps and reminders ticked today; null while unknown or failed, and
  /// then the hero has no bar.
  final int? done;
```

  - In `_due`, pass `progress: switch (widget.done) { final done? => (done: done, total: done + due.length), null => null }`.
  - In `build`'s `listed` switch, before the `value.isEmpty` case, add `AsyncData(:final value) when value.isEmpty && (widget.done ?? 0) > 0 => _allDone(l10n, desktop, goalWidgets, eventsBlock)`.
  - `_allDone` returns:
    - `TodayHero(eyebrow: l10n.todayTitle, headline: l10n.todayAllDone, progress: (done: d, total: d))`;
    - then `...goalWidgets`;
    - then `Padding(padding: desktop ? const EdgeInsets.only(top: AppSpacing.sm) : const EdgeInsets.fromLTRB(AppSpacing.xs, AppSpacing.xs, AppSpacing.xs, 0), child: Text(l10n.todayEmptyBody, style: Theme.of(context).textTheme.bodySmall))`;
    - then the same `SizedBox(height: desktop ? AppSpacing.xl : AppSpacing.lg)` as `_due`;
    - then `...eventsBlock`.

    The theme's `bodySmall` is already body-sm in `text/secondary` (`app_typography.dart`, `inkVariant`).
- [ ] **Step 5:** Run the gate. Commit `feat(today): progress bar and all-done state on the hero`.

### Task 3: Wire the count into `TodayPage`

**Files:**
- Modify: `lib/features/today/presentation/today_page.dart` (`_TodayPageState`)
- Modify: `test/features/today/today_page_test.dart`

- [ ] **Step 1: Failing tests** (through `pumpLoomia`):
  - **"the hero counts today's ticks"**: `activities: FakeActivityRepository([<a step entry on today()>])` with Anna due. The page shows "1 of 2 done".
  - **"a tick moves the bar"**: Anna and Bruno due, no entries. "0 of 2 done"; tap Anna's ring, `pumpAndSettle`; "1 of 2 done".
  - **"a failed tick keeps the count"**: as the existing failed-tick test. "0 of 1 done" before and after.
  - **"the last tick shows the all-done hero"**: update the existing "a tick sends completeStep and the row leaves". It now expects "That's everyone for today" and "1 of 1 done", and no "You are up to date".
  - **"pull to refresh reloads the count"**: the fake's `calls` has `doneOn(...)` twice after a drag-to-refresh.
- [ ] **Step 2: Wire it.**
  - In `build`: `final done = doneTodayProvider((owner: owner, day: today()));` and pass `done: ref.watch(done).value` to `TodayView`.
  - In `_tick`:
    - read the notifier before the `await`: `final counter = ref.read(doneTodayProvider((owner: ref.read(accountProvider)?.email, day: today())).notifier);`;
    - `if (await writePeople(...)) counter.add();`, keeping the `try`/`finally`.

    The notifier is autoDispose, but Today is watching it, so it's alive.
  - In `_refresh`: `ref.invalidate(doneTodayProvider);` (the whole family).
- [ ] **Step 3:** Run the gate. Commit `feat(today): the hero counts what was done today`.

### Task 4: Previews, docs, goldens

**Files:**
- Modify: `lib/features/today/presentation/today_preview.dart`
- Modify: `docs/design/components.md`
- Regenerate: `test/goldens/today_*.png` (CI)

- [ ] **Step 1: Previews.**
  - `_app` gains `int? done`, passed to `TodayView`.
  - Mobile and Desktop (both modes) pass `done: 2`. With seven rows, that reads "2 of 9 done".
  - Events and Nudge pass `done: 1`. Empty passes `done: 0`.
  - New: `@Preview(group: 'Today', name: 'All done — light', size: Size(390, 844)) Widget todayAllDoneMobileLight() => _app(AppTheme.light, const [], goals: _goals, done: 3);`
- [ ] **Step 2: `components.md` #11.**
  - Anatomy: replace "footer: progress left, effort in minutes right" with "footer: today's count, left ("1 of 3 done")".
  - Props: `eyebrow`, `headline`, `progress` (`done`, `total`; none hides the bar).
  - Rules: replace the effort sentence with "The footer counts today's own list (done + still waiting), never a target and never a percentage. Everything done keeps the hero: 'That's everyone for today', full bar."
- [ ] **Step 3:** Run the gate (on macOS the goldens are skipped). Commit `docs(design): TodayHero counts today's list`.
- [ ] **Step 4: Goldens through CI**, per the testing steering:

```bash
git push -u origin feature/292-today-progress
gh workflow run CI --ref feature/292-today-progress -f update-goldens=true
```

  Download them into `test/goldens/` and open each `today_*` PNG. Check that the bar is white on the darker track, the caption sits on the left, and all-done has a full bar with the body under the goal line. Then commit `test(today): goldens with the hero's progress`.
- [ ] **Step 5:** Run `graphify update .`. Open the PR with `Closes #292`, listing what was tested.

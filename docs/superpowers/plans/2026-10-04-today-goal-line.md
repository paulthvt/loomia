# Goal Line and Close-the-Month Card on Today Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Today shows one line for the month's own volume under the hero, "960 PV to go · 11 days left" or "On pace · 11 days left", which opens Goals. During the ritual window it also shows the close-and-plan card, which opens `/goals/close` (#144).

**Architecture:**
- `TodayPage` also watches `goalsProvider` (#142) and passes its value to `TodayView` as `GoalsMonth?`. `TodayView` stays provider-free.
- A small `GoalLine` widget in `lib/features/goals/presentation/goal_line.dart` turns a month into its line.
- `RitualCard` (#143) is restyled to the Today Figma frame: a secondary container with a filled Start. Goals and Today then show the same card.
- If Goals fails or is still loading, Today shows neither the line nor the card. Today's own content never waits for Goals.

**Tech Stack:** Flutter, `flutter_riverpod` 3, `go_router`, `material_ui`, `intl`.

**Spec:** `docs/superpowers/specs/2026-10-02-goals-design.md` §4 *Today*. Figma: Today with goal line `205:3033`, close-month card `205:3087`.

## Global Constraints

- Imports `package:loomia/...`; Material from `material_ui`; theme values only. No path literals in widgets (`Routes.goals`, `Routes.goalsClose`).
- Copy in `lib/l10n/app_en.arb` only, every key described; business-model words via `select` on `model.name`. Pace is stated, never judged; never red.
- Goldens only through CI. The `today_*` goldens with a book change (line and card), because the previews sit on September 29, inside the window.
- Quality gate: `dart format .`, `flutter analyze`, `flutter test`.

## Rulings made while planning

- **The line's three forms:**
  - "960 PV to go · 11 days left" by default;
  - "On pace · 11 days left" when `pace` says so (from day 4);
  - "You reached what you planned · 11 days left" once the volume is at or over the target.
- **The line hides** without a plan, without an own-volume target, or while Goals hasn't loaded.
- **The card on Today shows whenever `pendingRitual` asks for something**, including "Plan October" in the first 5 days when the current month has no plan, because Today has no empty state to do that.
- **One card style.** The Today frame is the only Figma for the card, so `RitualCard` takes it on both screens: `secondaryContainer` with ink in `onSecondaryContainer`, its body copy, and a filled `Start`. The copy is the Figma's: "See how the month went, then pick what you aim for in October. About two minutes."
- **Placement.** With people due, the line and card go after the hero, as in the Figma. In the up-to-date, loading or failed states, they go right under the top bar.

## Review Focus

1. Goals failing or loading doesn't hide or delay Today's people. Pinned in Task 2.
2. Day 1 to 3: "to go" (no "On pace"); over the target: "reached". Pinned in Task 1.
3. Other business model: no PV in the line. Pinned in Task 1.
4. Tapping the line opens Goals; Start opens the close flow. Pinned in Task 2.
5. Up to date (no one due): the line and the card still show. Pinned in Task 2.

---

### Task 1: `GoalLine`, the card restyle, copy

**Files:**
- Create: `lib/features/goals/presentation/goal_line.dart`
- Modify: `lib/features/goals/presentation/ritual_card.dart`
- Modify: `lib/l10n/app_en.arb` (after `"@closeBackToGoals"`; `ritualBody` text changes)
- Test: `test/features/goals/presentation/goal_line_test.dart` (create)

**Interfaces:**
- Consumes: `GoalsMonth` (#142), `pace` (#141), `PendingRitual` (#143).
- Produces:
  - `GoalLine({required GoalsMonth month, required DateTime today, required BusinessModel model, required VoidCallback onTap})`. It renders `SizedBox.shrink()` when there is nothing to say;
  - `bool hasGoalLine(GoalsMonth month)`, true with a plan and an own-volume target above 0.

- [ ] **Step 1: Copy**

Add:

```json
  "goalLineToGo": "{model, select, doterra{{amount} PV to go · {days, plural, =0{last day} =1{1 day left} other{{days} days left}}} other{{amount} to go · {days, plural, =0{last day} =1{1 day left} other{{days} days left}}}}",
  "@goalLineToGo": {
    "description": "Today, under the hero: own volume left to reach the month's plan, and days left after today. dōTERRA: PV, not translated.",
    "placeholders": {
      "model": { "type": "String" },
      "amount": { "type": "String" },
      "days": { "type": "int" }
    }
  },
  "goalLineOnPace": "{days, plural, =0{On pace · last day} =1{On pace · 1 day left} other{On pace · {days} days left}}",
  "@goalLineOnPace": {
    "description": "Today, under the hero: at this rate the month reaches its plan.",
    "placeholders": { "days": { "type": "int" } }
  },
  "goalLineReached": "{days, plural, =0{You reached what you planned · last day} =1{You reached what you planned · 1 day left} other{You reached what you planned · {days} days left}}",
  "@goalLineReached": {
    "description": "Today, under the hero: the month's own volume is at or over the plan. Never a celebration badge, a plain line.",
    "placeholders": { "days": { "type": "int" } }
  },
  "goalLineOpen": "Open Goals",
  "@goalLineOpen": { "description": "Screen-reader hint of the goal line on Today: tapping it opens Goals." },
```

Change `ritualBody`'s text to the Figma's, "See how the month went, then pick what you aim for in {plan}. About two minutes.", with a `plan` placeholder (`DateTime`, `MMMM`), and update its description. `RitualCard` passes `ritual.plan`. Run `flutter gen-l10n`. If gen-l10n refuses the nested `select`/`plural` in `goalLineToGo`, split the days into the existing `goalDaysLeft` key and join it with " · " in code, then ledger it.

- [ ] **Step 2: Write the failing tests**

`test/features/goals/presentation/goal_line_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:loomia/app/theme/app_theme.dart';
import 'package:loomia/core/business_model/business_model.dart';
import 'package:loomia/features/goals/domain/month_plan.dart';
import 'package:loomia/features/goals/presentation/goal_line.dart';
import 'package:loomia/features/goals/presentation/goals_controller.dart';
import 'package:loomia/l10n/app_localizations.dart';
import 'package:loomia/l10n/localizations_delegates.dart';
import 'package:material_ui/material_ui.dart';

final _september = DateTime(2026, 9);

GoalsMonth _month(double volume, {double? target = 2800}) => (
  month: _september,
  plan: MonthPlan(month: _september, ownVolumeTarget: target),
  progress: Progress(
    ownVolume: volume,
    prospects: 0,
    customers: 0,
    teamMembers: 0,
    loyalty: 0,
  ),
  forecast: 0,
  plans: const [],
);

void main() {
  late int taps;

  Future<void> pump(
    WidgetTester tester,
    GoalsMonth month, {
    DateTime? day,
    BusinessModel model = BusinessModel.doterra,
  }) {
    taps = 0;
    return tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        localizationsDelegates: localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: GoalLine(
            month: month,
            today: day ?? DateTime(2026, 9, 19),
            model: model,
            onTap: () => taps++,
          ),
        ),
      ),
    );
  }

  testWidgets('behind: what is left and the days', (tester) async {
    await pump(tester, _month(1000));

    expect(find.text('1,800 PV to go · 11 days left'), findsOneWidget);
    await tester.tap(find.byType(GoalLine));
    expect(taps, 1);
  });

  testWidgets('on pace from day 4', (tester) async {
    await pump(tester, _month(1840));

    expect(find.text('On pace · 11 days left'), findsOneWidget);
  });

  testWidgets('the first 3 days: no pace, what is left', (tester) async {
    await pump(tester, _month(500), day: DateTime(2026, 9, 3));

    expect(find.text('2,300 PV to go · 27 days left'), findsOneWidget);
  });

  testWidgets('reached', (tester) async {
    await pump(tester, _month(2900));

    expect(
      find.text('You reached what you planned · 11 days left'),
      findsOneWidget,
    );
  });

  testWidgets('no target: nothing', (tester) async {
    await pump(tester, _month(1000, target: null));

    expect(find.byType(InkWell), findsNothing);
    expect(hasGoalLine(_month(1000, target: null)), isFalse);
  });

  testWidgets('Other: no unit', (tester) async {
    await pump(tester, _month(1000), model: BusinessModel.other);

    expect(find.text('1,800 to go · 11 days left'), findsOneWidget);
  });
}
```

- [ ] **Step 3: Run them**

Run: `flutter test test/features/goals/presentation/goal_line_test.dart`
Expected: compile error, `goal_line.dart` doesn't exist.

- [ ] **Step 4: Implement**

`lib/features/goals/presentation/goal_line.dart`:

```dart
import 'package:intl/intl.dart';
import 'package:loomia/app/theme/app_colors.dart';
import 'package:loomia/app/theme/app_spacing.dart';
import 'package:loomia/core/business_model/business_model.dart';
import 'package:loomia/features/goals/domain/goal_rules.dart';
import 'package:loomia/features/goals/presentation/goals_controller.dart';
import 'package:loomia/l10n/app_localizations.dart';
import 'package:material_ui/material_ui.dart';

/// Whether [month] has a volume line for Today: a plan with an own-volume
/// target.
bool hasGoalLine(GoalsMonth month) {
  final target = month.plan?.ownVolumeTarget;
  return target != null && target > 0;
}

/// Today's one line about the month: what is left, on pace, or reached,
/// then the days left. Stated, never judged. Tapping it opens Goals.
class GoalLine extends StatelessWidget {
  const GoalLine({
    required this.month,
    required this.today,
    required this.model,
    required this.onTap,
    super.key,
  });

  final GoalsMonth month;
  final DateTime today;
  final BusinessModel model;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    if (!hasGoalLine(month)) return const SizedBox.shrink();
    final l10n = AppLocalizations.of(context);
    final colors = LoomiaColors.of(context);
    final target = month.plan!.ownVolumeTarget!;
    final done = month.progress.ownVolume;
    final days = DateTime(today.year, today.month + 1, 0).day - today.day;
    final number = NumberFormat.decimalPattern(l10n.localeName);
    final text = done >= target
        ? l10n.goalLineReached(days)
        : pace(target, done, today)?.onPace ?? false
        ? l10n.goalLineOnPace(days)
        : l10n.goalLineToGo(model.name, number.format(target - done), days);

    return Semantics(
      button: true,
      onTapHint: l10n.goalLineOpen,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  text,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: colors.textMuted,
                  ),
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: colors.textMuted),
            ],
          ),
        ),
      ),
    );
  }
}
```

`ritual_card.dart`, restyled to the Figma: replace the `Card` with

```dart
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: scheme.secondaryContainer,
        borderRadius: BorderRadius.circular(AppRadii.lg),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: AppSpacing.xs,
        children: [
          Text(
            /* title as before */,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: scheme.onSecondaryContainer,
            ),
          ),
          Text(
            ritual.closes ? l10n.ritualBody(ritual.plan) : l10n.ritualPlanBody,
            style: AppTypography.caption.copyWith(
              color: scheme.onSecondaryContainer,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          FilledButton(onPressed: onStart, child: Text(l10n.ritualStart)),
        ],
      ),
    );
```

Drop the now-unused imports (`AppTheme`, `LoomiaColors`) if the analyzer flags them.

- [ ] **Step 5: Run them**

Run: `flutter test test/features/goals && flutter analyze`
Expected: all pass, "No issues found!". The Goals card tests look for text only.

- [ ] **Step 6: Commit**

```bash
git add lib/l10n/app_en.arb lib/features/goals test/features/goals
git commit -m "feat(goals): a goal line for Today, and the ritual card in its Figma style"
```

---

### Task 2: Today shows them

**Files:**
- Modify: `lib/features/today/presentation/today_page.dart` (`TodayPage` watches `goalsProvider`; `TodayView` gains `goals`, `onGoals`, `onRitual`)
- Modify: `lib/features/today/presentation/today_preview.dart` (a September plan in the book previews)
- Modify: `docs/design/screens.md` §1 (the "Goal, stats…" paragraph)
- Test: `test/features/today/today_goals_test.dart` (create). `TodayView` alone, on fixed days. The existing `today_page_test.dart` drives the whole app on the real clock.

**Interfaces:**
- Consumes: `GoalLine`, `hasGoalLine` (Task 1); `RitualCard`, `pendingRitual` (#143); `goalsProvider`, `GoalsMonth`; `Routes.goals`, `Routes.goalsClose`.
- Produces: `TodayView(..., GoalsMonth? goals, VoidCallback? onGoals, VoidCallback? onRitual)`. All three are optional, so existing callers and tests compile unchanged.

- [ ] **Step 1: Write the failing tests**

`test/features/today/today_goals_test.dart`:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loomia/app/theme/app_theme.dart';
import 'package:loomia/core/business_model/business_model.dart';
import 'package:loomia/features/contacts/domain/person.dart';
import 'package:loomia/features/goals/domain/month_plan.dart';
import 'package:loomia/features/goals/presentation/goals_controller.dart';
import 'package:loomia/features/today/domain/due.dart';
import 'package:loomia/features/today/presentation/today_page.dart';
import 'package:loomia/features/workflows/domain/progress.dart';
import 'package:loomia/features/workflows/domain/workflow.dart';
import 'package:loomia/l10n/app_localizations.dart';
import 'package:loomia/l10n/localizations_delegates.dart';
import 'package:material_ui/material_ui.dart';

final _september = DateTime(2026, 9);

final _samples = Workflow(
  id: 'samples',
  stage: Stage.prospect,
  name: 'Samples',
  isDefault: true,
  steps: const [
    WorkflowStep(id: 's1', position: 1, label: 'Send a first message', days: 0),
  ],
);

Due _due(String name, DateTime due) => (
  person: Person(
    id: name,
    name: name,
    stage: Stage.prospect,
    stageSince: DateTime.utc(2026, 9),
  ),
  step: OnStep(
    workflow: _samples,
    step: _samples.steps.first,
    index: 1,
    total: 1,
    due: due,
  ),
);

GoalsMonth _goals() => (
  month: _september,
  plan: MonthPlan(month: _september, ownVolumeTarget: 2800),
  progress: const Progress(
    ownVolume: 1000,
    prospects: 0,
    customers: 0,
    teamMembers: 0,
    loyalty: 0,
  ),
  forecast: 0,
  plans: [MonthPlan(month: _september, ownVolumeTarget: 2800)],
);

void main() {
  late int goalsTaps;
  late int ritualTaps;

  Future<void> pump(
    WidgetTester tester, {
    required DateTime now,
    List<Due>? due,
    GoalsMonth? goals,
  }) {
    goalsTaps = 0;
    ritualTaps = 0;
    tester.view.physicalSize = const Size(390, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    return tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        localizationsDelegates: localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: TodayView(
          due: AsyncData(due ?? [_due('Anna', DateTime(now.year, now.month, now.day))]),
          now: now,
          firstName: 'Pauline',
          onTick: (_) {},
          onOpen: (_) {},
          onRetry: () {},
          onRefresh: () async {},
          goals: goals,
          model: BusinessModel.doterra,
          onGoals: () => goalsTaps++,
          onRitual: () => ritualTaps++,
        ),
      ),
    );
  }

  testWidgets('a planned month: the line under the hero opens Goals', (
    tester,
  ) async {
    await pump(tester, now: DateTime(2026, 9, 19, 9), goals: _goals());

    final line = find.text('1,800 PV to go · 11 days left');
    expect(line, findsOneWidget);
    expect(
      tester.getTopLeft(line).dy,
      greaterThan(tester.getTopLeft(find.text('One person is worth a message today')).dy),
    );
    expect(find.textContaining('Close September'), findsNothing);
    await tester.tap(line);
    expect(goalsTaps, 1);
  });

  testWidgets('the window: the card opens the close flow', (tester) async {
    await pump(tester, now: DateTime(2026, 9, 29, 9), goals: _goals());

    expect(find.text('Close September, plan October'), findsOneWidget);
    await tester.tap(find.text('Start'));
    expect(ritualTaps, 1);
  });

  testWidgets('no one due: the line and the card still show', (tester) async {
    await pump(
      tester,
      now: DateTime(2026, 9, 29, 9),
      due: const [],
      goals: _goals(),
    );

    expect(find.text('You are up to date'), findsOneWidget);
    expect(find.text('1,800 PV to go · 1 day left'), findsOneWidget);
    expect(find.text('Close September, plan October'), findsOneWidget);
  });

  testWidgets('Goals not loaded: Today as before', (tester) async {
    await pump(tester, now: DateTime(2026, 9, 29, 9));

    expect(find.text('Anna'), findsOneWidget);
    expect(find.textContaining('to go'), findsNothing);
    expect(find.textContaining('Close September'), findsNothing);
  });
}
```

- [ ] **Step 2: Run them**

Run: `flutter test test/features/today/today_goals_test.dart`
Expected: compile errors (`goals`, `model`, `onGoals` and `onRitual` aren't parameters).

- [ ] **Step 3: Implement**

`TodayView`:
- Gains `this.goals`, `this.onGoals` and `this.onRitual`, with doc comments: "This month's goals; null while loading or failed, and then Today shows nothing of them."
- In `_TodayViewState.build`, compute:

```dart
    final day = DateTime(widget.now.year, widget.now.month, widget.now.day);
    final goals = widget.goals;
    final ritual = goals == null ? null : pendingRitual(day, goals.plans);
    final goalWidgets = [
      if (goals != null && hasGoalLine(goals))
        GoalLine(
          month: goals,
          today: day,
          model: widget.model,
          onTap: widget.onGoals ?? () {},
        ),
      if (ritual != null) ...[
        const SizedBox(height: AppSpacing.md),
        RitualCard(ritual: ritual, onStart: widget.onRitual ?? () {}),
      ],
    ];
```

- `TodayView` also needs a `BusinessModel model` for the unit. Add `this.model = BusinessModel.other`; `TodayPage` passes the account's.
- With people due, insert `...goalWidgets` in `_due` right after the `TodayHero`, before its `SizedBox`. In every other branch (up to date, failed, loading), insert them right after the `LoomiaTopBar`. Pass `goalWidgets` into `_due` as a parameter.

`TodayPage.build` adds:

```dart
    final goals = ref.watch(goalsProvider(account?.email)).value;
```

and passes `goals: goals, model: account?.businessModel ?? BusinessModel.other, onGoals: () => context.go(Routes.goals), onRitual: () => context.push(Routes.goalsClose),`. The `.value` survives a refresh and is null on error. Today's people never wait for it.

`today_preview.dart`: the book previews (mobile light/dark, desktop) pass `goals:` a `GoalsMonth` with a September plan (`ownVolumeTarget: 2800`, `prospectsTarget: 8`) and `Progress(ownVolume: 2650, …)`, and `model: BusinessModel.doterra`. On September 29 the previews then show "150 PV to go · 1 day left" and the card, as in the Figma. `todayEmptyLight` stays without goals.

`docs/design/screens.md` §1: replace "Goal, stats, "You talked to" and the desktop right column are gone until their features exist (goals, activity summaries)." with:

```markdown
Under the hero, one line for the month's own volume ("960 PV to go · 11 days
left", "On pace · 11 days left", or "You reached what you planned"), which
opens Goals; hidden without a plan or a volume target. From the last 3 days
of a month to the 5th of the next, the close-and-plan card follows it
([#144](https://github.com/paulthvt/loomia/issues/144)). Stats, "You talked
to" and the desktop right column are gone until activity summaries exist.
```

- [ ] **Step 4: Run them, gate**

Run: `dart format . && flutter analyze && flutter test`
Expected: "No issues found!", all pass.

- [ ] **Step 5: Commit**

```bash
git add lib test docs/design/screens.md
git commit -m "feat(today): the goal line and the close-the-month card"
```

After the push, regenerate goldens through CI (`today_mobile_*`, `today_desktop_*`).

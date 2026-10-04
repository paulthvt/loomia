# Close the Month and Plan the Next Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** `/goals/close`, the month-end ritual (#143).
- Step 1, "How did September go?", shows what the book counted against the plan, takes the two figures the company gives, and closes the month (`close_month`, #141).
- Step 2, "What are you aiming for in October?", is the existing `PlanForm`, with the step header.
- The Goals tab offers it with a card while the ritual window is open.

**Architecture:**
- A pure `pendingRitual(today, plans)` in `goal_rules.dart` decides what the window still asks: close a planned month that isn't closed, then plan the next month if it has no plan.
- A `closingProvider` loads what `/goals/close` needs: the plans, the closing month's progress, and the next month's forecast.
- `ClosePage` holds the step as local state. Step 1 is a new `CloseForm`; step 2 reuses `PlanForm`, which gains an optional step header.
- The level picker moves out of `PlanForm` into a shared `LevelField`, used by both steps.
- `RitualCard` on the Goals tab opens the flow. #144 reuses it on Today.

**Tech Stack:** Flutter, `flutter_riverpod` 3, `go_router`, `material_ui`, `intl`.

**Spec:** `docs/superpowers/specs/2026-10-02-goals-design.md` §4 *Close and plan*, decisions table ("When to plan and review": the 3 last days of a month through the 5 first of the next). Figma step 1 `202:2816`, step 2 `202:2930`.

## Global Constraints

- Imports `package:loomia/...`; Material from `material_ui`; theme values only (`colorScheme`, `LoomiaColors`, `AppSpacing`, `AppRadii`, `AppTypography`); tonal buttons pass `style: AppTheme.tonal(context)`.
- Routing: path in `routes.dart` first, then the `GoRoute`; no path literals in widgets.
- Copy in `lib/l10n/app_en.arb` only, every key described; business-model words via `select` on `model.name`; informal. Under the plan: neutral, no red, no "missed". Run `flutter gen-l10n`.
- Providers that load set `retry: (error, _) => null`. A write that outlives its page invalidates through the `ProviderContainer`, never a widget `ref`, as `savePlan` does.
- Every `@Preview` has a golden in `test/previews_test.dart`, made by CI only.
- Quality gate: `dart format .`, `flutter analyze`, `flutter test`.

## Rulings made while planning

- **Step 1 only for a planned month.** If the month to close was never planned, there's nothing to look back on, so the flow goes straight to step 2. The spec's "the first time, with no past month, only step 2 shows" is the same rule.
- **Step 2 only when it's still needed.** If the month was closed but the next one isn't planned (the user left after step 1), `/goals/close` opens on step 2. If both are done, it says so and offers to go back.
- **The entry point is a card on the Goals tab**, at the top. The spec puts the card on Today, which is #144, and #144 reuses `RitualCard`.
  - It reads "Close September, plan October" while step 1 is pending.
  - It reads "Plan October" when only planning the next month is left.
  - It's hidden when the only thing left is planning the current month, because the empty state's `Plan September` already does that.
- **Closed months aren't edited.** `Change the plan` hides when this month's plan is closed (RLS refuses the update, #141). That happens in the last 3 days, after closing.
- **The typed actuals start empty**, with "You planned 6,000" and "You aimed for Elite" as helpers, as in the Figma. Both are optional.
- **Reached** means the actual is at or above the target, shown with a check icon in `colorScheme.primary`. Under the target, the bar stays the neutral secondary tone. With no target, the row shows the count alone, without a bar.
- **Back on step 2 leaves the flow.** The month is already closed, so there's no step 1 to return to.

## Review Focus

1. A day outside the window, a closed month with a planned next one, and an unplanned month to close all give the right step or nothing. Pinned in Task 1.
2. Over the target, the bar is full with a check; under it, the bar is neutral and has no check. Pinned in Task 2.
3. A failed close keeps step 1 and what was typed; a failed save keeps step 2. Pinned in Task 3.
4. After the flow, the Goals tab shows the new month's plan and no card. Pinned in Task 3 (invalidation) and Task 4.
5. Other business model: no PV, OV, rank or LRP, and a typed level. Pinned in Task 2.

---
### Task 1: Copy, `pendingRitual` and `closingProvider`

**Files:**
- Modify: `lib/l10n/app_en.arb` (after `"@planNumberInvalid"`'s entry)
- Modify: `lib/features/goals/domain/goal_rules.dart`
- Modify: `lib/features/goals/presentation/goals_controller.dart`
- Test: `test/features/goals/domain/goal_rules_test.dart`, `test/features/goals/presentation/goals_controller_test.dart` (append)

**Interfaces:**
- Consumes: `ritualWindow`, `MonthPlan`, `Progress`, `GoalsRepository` (#141), `FakeGoalsRepository` (#142).
- Produces:
  - `typedef PendingRitual = ({DateTime close, DateTime plan, bool closes})`;
  - `PendingRitual? pendingRitual(DateTime today, List<MonthPlan> plans)`;
  - `typedef Closing = ({PendingRitual ritual, MonthPlan? closing, Progress? done, int forecast, List<MonthPlan> plans})`;
  - `final closingProvider = FutureProvider.autoDispose.family<Closing?, ({String? email, DateTime day})>(...)`.

  It's keyed by the day so tests pin the date, and `ClosePage` passes `today()`. `closing` and `done` are null unless `ritual.closes`.

- [ ] **Step 1: Copy**

```json
  "ritualCloseAndPlan": "Close {close}, plan {plan}",
  "@ritualCloseAndPlan": {
    "description": "Card title on Goals (and Today, later) in the last 3 days of a month and the first 5 of the next: look back on a month, then plan the next.",
    "placeholders": {
      "close": { "type": "DateTime", "format": "MMMM" },
      "plan": { "type": "DateTime", "format": "MMMM" }
    }
  },
  "ritualBody": "A few minutes: what the month did, then the numbers for the next one.",
  "@ritualBody": { "description": "Under the close-and-plan card's title." },
  "ritualPlanBody": "Pick a few numbers before the month starts.",
  "@ritualPlanBody": { "description": "Under the card's title when only next month's plan is left." },
  "ritualStart": "Start",
  "@ritualStart": { "description": "Button of the close-and-plan card; opens the flow." },
  "closeStep": "Step {step} of {total}",
  "@closeStep": {
    "description": "Eyebrow above the close-and-plan titles, shown uppercased.",
    "placeholders": { "step": { "type": "int" }, "total": { "type": "int" } }
  },
  "closeTitle": "How did {month} go?",
  "@closeTitle": {
    "description": "Title of step 1: looking back on a month. Never a verdict.",
    "placeholders": { "month": { "type": "DateTime", "format": "MMMM" } }
  },
  "closeIntro": "What Loomia counted, next to what you planned. Then add the two your company tells you.",
  "@closeIntro": { "description": "Under the step 1 title." },
  "closeOf": "{done} of {target}",
  "@closeOf": {
    "description": "Right of a counted objective in step 1, e.g. '7 of 8'.",
    "placeholders": { "done": { "type": "String" }, "target": { "type": "String" } }
  },
  "closeVolumeOf": "{model, select, doterra{{done} of {target} PV} other{{done} of {target}}}",
  "@closeVolumeOf": {
    "description": "Right of own volume in step 1, e.g. '2,650 of 2,800 PV'. dōTERRA: PV, not translated.",
    "placeholders": { "model": { "type": "String" }, "done": { "type": "String" }, "target": { "type": "String" } }
  },
  "closeVolumeAlone": "{model, select, doterra{{done} PV} other{{done}}}",
  "@closeVolumeAlone": {
    "description": "Right of own volume in step 1 when there was no target, e.g. '2,650 PV'.",
    "placeholders": { "model": { "type": "String" }, "done": { "type": "String" } }
  },
  "closeReached": "Reached",
  "@closeReached": { "description": "Screen-reader label of the check beside an objective that reached its plan." },
  "closePlanned": "You planned {amount}",
  "@closePlanned": {
    "description": "Under the typed team volume: what the plan said.",
    "placeholders": { "amount": { "type": "String" } }
  },
  "closeAimedFor": "You aimed for {level}",
  "@closeAimedFor": {
    "description": "Under the typed rank or level: what the plan said.",
    "placeholders": { "level": { "type": "String" } }
  },
  "closeNext": "Next",
  "@closeNext": { "description": "Step 1 button: closes the month and goes to step 2." },
  "closeNothing": "Nothing to close or plan right now.",
  "@closeNothing": { "description": "The close-and-plan screen when the window is shut or both steps are done." },
  "closeNothingBody": "The month-end look back opens in the last 3 days of a month.",
  "@closeNothingBody": { "description": "Under 'Nothing to close or plan right now.'" },
  "closeBackToGoals": "Back to Goals",
  "@closeBackToGoals": { "description": "Button under 'Nothing to close or plan right now.'" },
```

Run `flutter gen-l10n`.

- [ ] **Step 2: Write the failing tests**

Append inside `main()` of `goal_rules_test.dart`:

```dart
  group('pendingRitual', () {
    final september = DateTime(2026, 9);
    final october = DateTime(2026, 10);
    MonthPlan planned(DateTime month, {bool closed = false}) => MonthPlan(
      month: month,
      ownVolumeTarget: 100,
      closedAt: closed ? DateTime(2026, 9, 29) : null,
    );

    test('outside the window: nothing', () {
      expect(pendingRitual(DateTime(2026, 9, 15), [planned(september)]), isNull);
    });

    test('a planned month to close, then the next to plan', () {
      expect(pendingRitual(DateTime(2026, 9, 29), [planned(september)]), (
        close: september,
        plan: october,
        closes: true,
      ));
    });

    test('never planned: nothing to close, only the plan', () {
      expect(pendingRitual(DateTime(2026, 10, 2), const [])?.closes, isFalse);
    });

    test('closed, next not planned: only the plan', () {
      final ritual = pendingRitual(DateTime(2026, 9, 30), [
        planned(september, closed: true),
      ]);
      expect(ritual?.closes, isFalse);
      expect(ritual?.plan, october);
    });

    test('closed and the next planned: nothing left', () {
      expect(
        pendingRitual(DateTime(2026, 10, 3), [
          planned(september, closed: true),
          planned(october),
        ]),
        isNull,
      );
    });
  });
```

Append inside `main()` of `goals_controller_test.dart`:

```dart
  test('closing loads the month to close and the next forecast', () async {
    final goals = FakeGoalsRepository(
      plans: [MonthPlan(month: DateTime(2026, 9), ownVolumeTarget: 2800)],
      progressValue: const Progress(
        ownVolume: 2650,
        prospects: 7,
        customers: 5,
        teamMembers: 1,
        loyalty: 2,
      ),
      forecastValue: 3,
    );
    final c = container(goals);
    final key = (email: null, day: DateTime(2026, 9, 29));
    c.listen(closingProvider(key), (_, _) {});

    final closing = (await c.read(closingProvider(key).future))!;

    expect(closing.ritual.closes, isTrue);
    expect(closing.closing?.ownVolumeTarget, 2800);
    expect(closing.done?.ownVolume, 2650);
    expect(closing.forecast, 3);
    expect(goals.calls, containsAll(['progress(2026-09)', 'forecast(2026-10)']));
  });

  test('closing outside the window is null', () async {
    final c = container(FakeGoalsRepository());
    final key = (email: null, day: DateTime(2026, 9, 15));
    c.listen(closingProvider(key), (_, _) {});

    expect(await c.read(closingProvider(key).future), isNull);
  });
```

- [ ] **Step 3: Run them**

Run: `flutter test test/features/goals`
Expected: compile errors, since `pendingRitual` and `closingProvider` aren't defined.

- [ ] **Step 4: Implement**

`goal_rules.dart`, after `ritualWindow`:

```dart
/// What the month-end window still asks: close [close] when it was planned
/// and isn't closed, then plan [plan] if it has no plan.
typedef PendingRitual = ({DateTime close, DateTime plan, bool closes});

/// Null outside the window, or when both are done. A month never planned has
/// nothing to look back on, so only the plan is asked.
PendingRitual? pendingRitual(DateTime today, List<MonthPlan> plans) {
  final window = ritualWindow(today);
  if (window == null) return null;
  MonthPlan? find(DateTime month) =>
      plans.where((plan) => plan.month == month).firstOrNull;
  final closing = find(window.close);
  final closes = closing != null && !closing.closed;
  if (!closes && find(window.plan) != null) return null;
  return (close: window.close, plan: window.plan, closes: closes);
}
```

`goals_controller.dart`:

```dart
/// What `/goals/close` needs on [day]: the ritual, the month to close with
/// its progress (step 1 only), the next month's forecast, and every plan for
/// the suggestions. Null when there's nothing to do.
typedef Closing = ({
  PendingRitual ritual,
  MonthPlan? closing,
  Progress? done,
  int forecast,
  List<MonthPlan> plans,
});

/// Keyed by the account and the day, so a test can pin the date.
final closingProvider = FutureProvider.autoDispose
    .family<Closing?, ({String? email, DateTime day})>(
      (ref, key) => _loadClosing(ref, key.day),
      retry: (error, _) => null,
    );

Future<Closing?> _loadClosing(Ref ref, DateTime day) async {
  final repository = ref.watch(goalsRepositoryProvider);
  final plans = await repository.plans();
  final ritual = pendingRitual(day, plans);
  if (ritual == null) return null;
  final closing = ritual.closes
      ? plans.firstWhere((plan) => plan.month == ritual.close)
      : null;
  final done = ritual.closes ? await repository.progress(ritual.close) : null;
  final forecast = await repository.forecast(ritual.plan);
  return (
    ritual: ritual,
    closing: closing,
    done: done,
    forecast: forecast,
    plans: plans,
  );
}
```

Import `goal_rules.dart` in `goals_controller.dart`.

- [ ] **Step 5: Run them**

Run: `flutter test test/features/goals && flutter analyze`
Expected: all pass, "No issues found!".

- [ ] **Step 6: Commit**

```bash
git add lib/l10n/app_en.arb lib/features/goals test/features/goals
git commit -m "feat(goals): what the month-end ritual still asks"
```

---
### Task 2: Step 1 — `CloseForm`, and the shared `LevelField` and `StepBar`

**Files:**
- Modify: `lib/features/goals/presentation/plan_page.dart` (extract `LevelField`; add `StepBar`; `PlanForm` gains `int? step`)
- Create: `lib/features/goals/presentation/close_form.dart`
- Test: `test/features/goals/presentation/close_form_test.dart` (create); `plan_page_test.dart` still passes unchanged

**Interfaces:**
- Consumes: `Closing` (Task 1); `LoomiaProgressBar`, `LabeledField`, `FormError`, `SectionHeader`, `LoomiaTopBar`; `parseAmount`; the Task 1 copy.
- Produces:
  - `LevelField({required String label, required BusinessModel model, required String? value, required ValueChanged<String?> onChanged, String? helper})`;
  - `StepBar({required int step, int total = 2})`;
  - `PlanForm(..., int? step)`. With a `step`, it shows the "Step N of 2" eyebrow and the `StepBar`;
  - `CloseForm({required Closing closing, required BusinessModel model, required Future<void> Function({double? teamVolume, String? level}) onClose})`. `onClose` throws `PeopleFailure`, and the form stays.

- [ ] **Step 1: Write the failing test**

`test/features/goals/presentation/close_form_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:loomia/app/theme/app_theme.dart';
import 'package:loomia/core/business_model/business_model.dart';
import 'package:loomia/core/ui/form_error.dart';
import 'package:loomia/core/ui/labeled_field.dart';
import 'package:loomia/core/ui/loomia_progress_bar.dart';
import 'package:loomia/features/contacts/domain/people_failure.dart';
import 'package:loomia/features/goals/domain/month_plan.dart';
import 'package:loomia/features/goals/presentation/close_form.dart';
import 'package:loomia/features/goals/presentation/goals_controller.dart';
import 'package:loomia/l10n/app_localizations.dart';
import 'package:loomia/l10n/localizations_delegates.dart';
import 'package:material_ui/material_ui.dart';

final _september = DateTime(2026, 9);

Closing _closing({MonthPlan? plan, Progress? done}) => (
  ritual: (close: _september, plan: DateTime(2026, 10), closes: true),
  closing:
      plan ??
      MonthPlan(
        month: _september,
        ownVolumeTarget: 2800,
        teamVolumeTarget: 6000,
        levelTarget: 'Elite',
        prospectsTarget: 8,
        customersTarget: 6,
        teamMembersTarget: 1,
        loyaltyTarget: 2,
      ),
  done:
      done ??
      const Progress(
        ownVolume: 2650,
        prospects: 9,
        customers: 5,
        teamMembers: 1,
        loyalty: 2,
      ),
  forecast: 3,
  plans: const [],
);

void main() {
  late List<({double? teamVolume, String? level})> closes;
  Object? failWith;

  Future<void> pump(
    WidgetTester tester, {
    Closing? closing,
    BusinessModel model = BusinessModel.doterra,
  }) {
    closes = [];
    failWith = null;
    tester.view.physicalSize = const Size(390, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    return tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        localizationsDelegates: localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: CloseForm(
            closing: closing ?? _closing(),
            model: model,
            onClose: ({teamVolume, level}) async {
              if (failWith case final failure?) throw failure;
              closes.add((teamVolume: teamVolume, level: level));
            },
          ),
        ),
      ),
    );
  }

  Finder field(String label) => find.descendant(
    of: find.widgetWithText(LabeledField, label),
    matching: find.byType(TextFormField),
  );

  testWidgets('what the book counted against the plan', (tester) async {
    await pump(tester);

    expect(find.text('STEP 1 OF 2'), findsOneWidget);
    expect(find.text('How did September go?'), findsOneWidget);
    expect(find.text('2,650 of 2,800 PV'), findsOneWidget);
    expect(find.text('9 of 8'), findsOneWidget);
    expect(find.text('5 of 6'), findsOneWidget);
    // Prospects (over), team members and LRPs reached; volume and customers
    // under, with no mark.
    expect(find.bySemanticsLabel('Reached'), findsNWidgets(3));
    final bars = tester
        .widgetList<LoomiaProgressBar>(find.byType(LoomiaProgressBar))
        .map((bar) => bar.value)
        .toList();
    expect(bars.where((value) => value == 1), hasLength(3));
    expect(find.text('You planned 6,000'), findsOneWidget);
    expect(find.text('You aimed for Elite'), findsOneWidget);
  });

  testWidgets('Next closes with the two typed figures', (tester) async {
    await pump(tester);

    await tester.enterText(field('OV'), '5000');
    await tester.tap(find.byType(DropdownButtonFormField<String?>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Executive').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();

    expect(closes, [(teamVolume: 5000.0, level: 'Executive')]);
  });

  testWidgets('both typed figures are optional', (tester) async {
    await pump(tester);

    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();

    expect(closes, [(teamVolume: null, level: null)]);
  });

  testWidgets('a failed close keeps the step and what was typed', (
    tester,
  ) async {
    await pump(tester);
    failWith = PeopleFailure.network;

    await tester.enterText(field('OV'), '5000');
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();

    expect(find.byType(FormError), findsOneWidget);
    expect(tester.widget<TextFormField>(field('OV')).controller!.text, '5000');
    expect(closes, isEmpty);
  });

  testWidgets('no target: the count alone, no bar', (tester) async {
    await pump(
      tester,
      closing: _closing(plan: MonthPlan(month: _september)),
    );

    expect(find.text('2,650 PV'), findsOneWidget);
    expect(find.text('9'), findsOneWidget);
    expect(find.byType(LoomiaProgressBar), findsNothing);
    expect(find.bySemanticsLabel('Reached'), findsNothing);
  });

  testWidgets('Other: neutral words, a typed level', (tester) async {
    await pump(tester, model: BusinessModel.other);

    expect(find.text('2,650 of 2,800'), findsOneWidget);
    expect(field('Team volume'), findsOneWidget);
    await tester.enterText(field('Level'), ' Gold ');
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();

    expect(closes.single.level, 'Gold');
    expect(find.textContaining('PV'), findsNothing);
  });
}
```

- [ ] **Step 2: Run it**

Run: `flutter test test/features/goals/presentation/close_form_test.dart`
Expected: compile error, `close_form.dart` doesn't exist.

- [ ] **Step 3: Implement**

`plan_page.dart`, at the bottom:

```dart
/// The rank picker for dōTERRA, typed words for Other. A stored label the
/// list lacks (a renamed rank) stays a choice.
class LevelField extends StatelessWidget {
  const LevelField({
    required this.label,
    required this.model,
    required this.value,
    required this.onChanged,
    this.helper,
    super.key,
  });

  final String label;
  final BusinessModel model;
  final String? value;
  final ValueChanged<String?> onChanged;
  final String? helper;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final decoration = InputDecoration(helperText: helper);
    return LabeledField(
      label: label,
      child: model.levels.isEmpty
          ? TextFormField(
              initialValue: value,
              textCapitalization: TextCapitalization.words,
              decoration: decoration,
              onChanged: onChanged,
            )
          : DropdownButtonFormField<String?>(
              initialValue: value,
              isExpanded: true,
              style: Theme.of(context).textTheme.bodyLarge,
              decoration: decoration,
              items: [
                DropdownMenuItem(child: Text(l10n.editLevelNone)),
                for (final name in [
                  ...model.levels,
                  if (value case final saved? when !model.levels.contains(saved))
                    saved,
                ])
                  DropdownMenuItem(value: name, child: Text(name)),
              ],
              onChanged: onChanged,
            ),
    );
  }
}

/// Where the close-and-plan flow is: one segment per step, done ones filled.
class StepBar extends StatelessWidget {
  const StepBar({required this.step, this.total = 2, super.key});

  /// From 1.
  final int step;
  final int total;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final colors = LoomiaColors.of(context);
    return Row(
      spacing: AppSpacing.xs,
      children: [
        for (var index = 1; index <= total; index++)
          Expanded(
            child: Container(
              height: AppSpacing.xs,
              decoration: BoxDecoration(
                color: index <= step ? scheme.primary : colors.secondaryTrack,
                borderRadius: BorderRadius.circular(AppRadii.sm),
              ),
            ),
          ),
      ],
    );
  }
}
```

In `PlanForm`:
- Replace the level `LabeledField(...)` with `LevelField(label: l10n.planLevel(model.name), model: model, value: _level, onChanged: (value) => _level = value)`.
- Add `this.step` to the constructor, with `/// In the close-and-plan flow: which step this is.` and `final int? step;`.
- The `LoomiaTopBar` gains `eyebrow: switch (widget.step) { final step? => l10n.closeStep(step, 2), null => null },`.
- After it: `if (widget.step case final step?) ...[StepBar(step: step), const SizedBox(height: AppSpacing.md)],`.

`lib/features/goals/presentation/close_form.dart`:

```dart
import 'package:intl/intl.dart';
import 'package:loomia/app/theme/app_colors.dart';
import 'package:loomia/app/theme/app_spacing.dart';
import 'package:loomia/core/business_model/business_model.dart';
import 'package:loomia/core/ui/form_error.dart';
import 'package:loomia/core/ui/labeled_field.dart';
import 'package:loomia/core/ui/loomia_progress_bar.dart';
import 'package:loomia/core/ui/loomia_top_bar.dart';
import 'package:loomia/core/ui/section_header.dart';
import 'package:loomia/features/contacts/domain/activity.dart';
import 'package:loomia/features/contacts/domain/people_failure.dart';
import 'package:loomia/features/contacts/presentation/people_copy.dart';
import 'package:loomia/features/goals/presentation/goals_controller.dart';
import 'package:loomia/features/goals/presentation/plan_page.dart';
import 'package:loomia/l10n/app_localizations.dart';
import 'package:material_ui/material_ui.dart';

/// Step 1: what the book counted against the plan, and the two figures only
/// the company knows. Under the plan stays neutral: no red, no "missed".
class CloseForm extends StatefulWidget {
  const CloseForm({
    required this.closing,
    required this.model,
    required this.onClose,
    super.key,
  });

  /// With `closing` and `done` set: there's a planned month to close.
  final Closing closing;
  final BusinessModel model;

  /// Throws `PeopleFailure`; the form stays, with what was typed.
  final Future<void> Function({double? teamVolume, String? level}) onClose;

  @override
  State<CloseForm> createState() => _CloseFormState();
}

class _CloseFormState extends State<CloseForm> {
  final _form = GlobalKey<FormState>();
  final _teamVolume = TextEditingController();
  String? _level;
  bool _saving = false;
  PeopleFailure? _failure;

  @override
  void dispose() {
    _teamVolume.dispose();
    super.dispose();
  }

  Future<void> _close() async {
    if (_saving || !_form.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _failure = null;
    });
    final level = _level?.trim();
    try {
      await widget.onClose(
        teamVolume: parseAmount(
          _teamVolume.text,
          AppLocalizations.of(context).localeName,
        ),
        level: level == null || level.isEmpty ? null : level,
      );
      if (mounted) setState(() => _saving = false);
    } on PeopleFailure catch (failure) {
      if (mounted) {
        setState(() {
          _saving = false;
          _failure = failure;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final colors = LoomiaColors.of(context);
    final number = NumberFormat.decimalPattern(l10n.localeName);
    final model = widget.model;
    final plan = widget.closing.closing!;
    final done = widget.closing.done!;
    final failure = _failure;

    Widget row(String label, String value, num doneValue, num? target) {
      final reached = target != null && doneValue >= target;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: AppSpacing.xs,
        children: [
          Row(
            spacing: AppSpacing.xs,
            children: [
              Expanded(child: Text(label, style: theme.textTheme.bodyLarge)),
              Text(
                value,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colors.textMuted,
                ),
              ),
              if (reached)
                Icon(
                  Icons.check_circle_rounded,
                  color: theme.colorScheme.primary,
                  semanticLabel: l10n.closeReached,
                ),
            ],
          ),
          if (target != null && target > 0)
            LoomiaProgressBar(value: (doneValue / target).clamp(0, 1)),
        ],
      );
    }

    Widget count(String label, int doneValue, int? target) => row(
      label,
      target == null
          ? '$doneValue'
          : l10n.closeOf(number.format(doneValue), number.format(target)),
      doneValue,
      target,
    );

    final volumeTarget = plan.ownVolumeTarget;
    final teamTarget = plan.teamVolumeTarget;
    final levelTarget = plan.levelTarget;

    return Form(
      key: _form,
      child: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          LoomiaTopBar(
            eyebrow: l10n.closeStep(1, 2),
            title: l10n.closeTitle(widget.closing.ritual.close),
            gap: AppSpacing.sm,
          ),
          const StepBar(step: 1),
          const SizedBox(height: AppSpacing.md),
          Text(
            l10n.closeIntro,
            style: theme.textTheme.bodyLarge?.copyWith(color: colors.textMuted),
          ),
          const SizedBox(height: AppSpacing.lg),
          if (failure != null) ...[
            FormError(peopleFailureCopy(l10n, failure)),
            const SizedBox(height: AppSpacing.ms),
          ],
          SectionHeader(title: l10n.planFromBook),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                spacing: AppSpacing.md,
                children: [
                  row(
                    l10n.goalOwnVolume,
                    volumeTarget == null
                        ? l10n.closeVolumeAlone(
                            model.name,
                            number.format(done.ownVolume),
                          )
                        : l10n.closeVolumeOf(
                            model.name,
                            number.format(done.ownVolume),
                            number.format(volumeTarget),
                          ),
                    done.ownVolume,
                    volumeTarget,
                  ),
                  count(l10n.goalNewProspects, done.prospects, plan.prospectsTarget),
                  count(l10n.goalNewCustomers, done.customers, plan.customersTarget),
                  count(
                    l10n.goalNewTeamMembers,
                    done.teamMembers,
                    plan.teamMembersTarget,
                  ),
                  count(l10n.goalLoyalty(model.name), done.loyalty, plan.loyaltyTarget),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          SectionHeader(title: l10n.planFromCompany),
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: AppSpacing.ms,
            children: [
              LabeledField(
                label: l10n.planTeamVolume(model.name),
                child: TextFormField(
                  controller: _teamVolume,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: InputDecoration(
                    helperText: teamTarget == null
                        ? null
                        : l10n.closePlanned(number.format(teamTarget)),
                  ),
                  validator: (value) {
                    final typed = (value ?? '').trim();
                    return typed.isEmpty ||
                            parseAmount(typed, l10n.localeName) != null
                        ? null
                        : l10n.planNumberInvalid;
                  },
                ),
              ),
              LevelField(
                label: l10n.planLevel(model.name),
                model: model,
                value: _level,
                helper: levelTarget == null
                    ? null
                    : l10n.closeAimedFor(levelTarget),
                onChanged: (value) => _level = value,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          FilledButton(
            onPressed: _saving ? null : _close,
            child: _saving
                ? const SizedBox.square(
                    dimension: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(l10n.closeNext),
          ),
        ],
      ),
    );
  }
}
```

`plan_page.dart` needs `AppRadii.sm` (in `app_spacing.dart`, beside `AppSpacing`) and `LoomiaColors`.

- [ ] **Step 4: Run them**

Run: `flutter test test/features/goals && flutter analyze`
Expected: all pass, `plan_page_test` included, "No issues found!".

- [ ] **Step 5: Commit**

```bash
git add lib/features/goals test/features/goals
git commit -m "feat(goals): look back on a month before closing it"
```

---
### Task 3: `/goals/close` — the two steps together

**Files:**
- Modify: `lib/app/router/routes.dart` (`goalsClose`, `goalsCloseName`), `lib/app/router/app_router.dart` (top level, beside `goalsPlan`)
- Create: `lib/features/goals/presentation/close_page.dart`
- Modify: `test/features/goals/fake_goals_repository.dart` (a real `close`)
- Test: `test/features/goals/presentation/close_page_test.dart`

**Interfaces:**
- Consumes: `closingProvider`, `Closing` (Task 1); `CloseForm`, `PlanForm(step:)` (Task 2); `savePlan`, `goalsProvider`, `GoalsMonth`, `goalsRepositoryProvider`; `noProgress` (the fake's file has it; the page builds its own zero `Progress`).
- Produces:
  - `Routes.goalsClose = '/goals/close'`;
  - `ClosePage({DateTime? day, VoidCallback? onDone})`. The day defaults to `today()`, and `onDone` defaults to `backOr(context, Routes.goals)`; both are injectable for tests.

- [ ] **Step 1: A fake that closes**

In `fake_goals_repository.dart`, replace `close`:

```dart
  /// Like `close_month`: the month's progress frozen into its plan, or into
  /// a new record when it had none.
  @override
  Future<MonthPlan> close(
    DateTime month, {
    double? teamVolume,
    String? level,
  }) async {
    await _record('close(${_month(month)})');
    final plan =
        store.where((saved) => saved.month == month).firstOrNull ??
        MonthPlan(month: month);
    final closed = MonthPlan(
      month: month,
      ownVolumeTarget: plan.ownVolumeTarget,
      teamVolumeTarget: plan.teamVolumeTarget,
      levelTarget: plan.levelTarget,
      prospectsTarget: plan.prospectsTarget,
      customersTarget: plan.customersTarget,
      teamMembersTarget: plan.teamMembersTarget,
      loyaltyTarget: plan.loyaltyTarget,
      loyaltyForecast: plan.loyaltyForecast,
      actual: progressValue,
      teamVolumeActual: teamVolume,
      levelActual: level,
      closedAt: DateTime(month.year, month.month + 1),
    );
    store
      ..remove(plan)
      ..add(closed);
    return closed;
  }
```

- [ ] **Step 2: Write the failing tests**

`test/features/goals/presentation/close_page_test.dart`:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loomia/app/theme/app_theme.dart';
import 'package:loomia/core/business_model/business_model.dart';
import 'package:loomia/core/ui/form_error.dart';
import 'package:loomia/core/ui/labeled_field.dart';
import 'package:loomia/features/auth/data/auth_repository.dart';
import 'package:loomia/features/auth/domain/account.dart';
import 'package:loomia/features/contacts/domain/people_failure.dart';
import 'package:loomia/features/goals/data/goals_repository.dart';
import 'package:loomia/features/goals/domain/month_plan.dart';
import 'package:loomia/features/goals/presentation/close_page.dart';
import 'package:loomia/l10n/app_localizations.dart';
import 'package:loomia/l10n/localizations_delegates.dart';
import 'package:material_ui/material_ui.dart';

import '../../auth/fake_auth_repository.dart';
import '../fake_goals_repository.dart';

void main() {
  final september = DateTime(2026, 9);
  final october = DateTime(2026, 10);
  late FakeGoalsRepository goals;
  late int done;

  Future<void> open(WidgetTester tester, DateTime day) async {
    done = 0;
    final auth = FakeAuthRepository()
      ..session = true
      ..account = const Account(
        firstName: 'Pauline',
        email: 'p@example.com',
        businessModel: BusinessModel.doterra,
      );
    addTearDown(auth.dispose);
    tester.view.physicalSize = const Size(390, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authRepositoryProvider.overrideWithValue(auth),
          goalsRepositoryProvider.overrideWithValue(goals),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          localizationsDelegates: localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: ClosePage(day: day, onDone: () => done++),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Finder field(String label) => find.descendant(
    of: find.widgetWithText(LabeledField, label),
    matching: find.byType(TextFormField),
  );

  testWidgets('close September, then plan October', (tester) async {
    goals = FakeGoalsRepository(
      plans: [MonthPlan(month: september, ownVolumeTarget: 2800)],
      progressValue: const Progress(
        ownVolume: 2650,
        prospects: 7,
        customers: 5,
        teamMembers: 1,
        loyalty: 2,
      ),
      forecastValue: 3,
    );
    await open(tester, DateTime(2026, 9, 29));

    expect(find.text('How did September go?'), findsOneWidget);
    await tester.enterText(field('OV'), '5000');
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();

    final closed = goals.store.singleWhere((plan) => plan.month == september);
    expect(closed.closed, isTrue);
    expect(closed.teamVolumeActual, 5000);
    expect(find.text('STEP 2 OF 2'), findsOneWidget);
    expect(find.text('What are you aiming for in October?'), findsOneWidget);
    // Starts from the month just closed.
    expect(
      tester.widget<TextFormField>(field('Own volume (PV)')).controller!.text,
      '2650',
    );

    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(goals.store.where((plan) => plan.month == october), hasLength(1));
    expect(done, 1);
  });

  testWidgets('closed, next not planned: straight to the plan', (
    tester,
  ) async {
    goals = FakeGoalsRepository(
      plans: [
        MonthPlan(month: september, closedAt: DateTime(2026, 9, 30)),
      ],
    );
    await open(tester, DateTime(2026, 9, 30));

    expect(find.text('What are you aiming for in October?'), findsOneWidget);
    expect(find.textContaining('STEP'), findsNothing);
    expect(goals.calls, isNot(contains('progress(2026-09)')));
  });

  testWidgets('nothing left: says so and goes back', (tester) async {
    goals = FakeGoalsRepository();
    await open(tester, DateTime(2026, 9, 15));

    expect(find.text('Nothing to close or plan right now.'), findsOneWidget);
    await tester.tap(find.text('Back to Goals'));
    expect(done, 1);
  });

  testWidgets('a failed close stays on step 1', (tester) async {
    goals = FakeGoalsRepository(
      plans: [MonthPlan(month: september, ownVolumeTarget: 2800)],
    );
    await open(tester, DateTime(2026, 9, 29));
    goals.failWith = PeopleFailure.network;

    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();

    expect(find.text('How did September go?'), findsOneWidget);
    expect(find.byType(FormError), findsOneWidget);
    expect(goals.store.single.closed, isFalse);
  });
}
```

- [ ] **Step 3: Run them**

Run: `flutter test test/features/goals/presentation/close_page_test.dart`
Expected: compile error, `close_page.dart` doesn't exist.

- [ ] **Step 4: Implement**

`routes.dart`, after `goalsPlanName`:

```dart
  /// Full screen, outside the tabs: close a month, then plan the next.
  static const String goalsClose = '/goals/close';
  static const String goalsCloseName = 'goalsClose';
```

`app_router.dart`, beside the `goalsPlan` route:

```dart
      GoRoute(
        path: Routes.goalsClose,
        name: Routes.goalsCloseName,
        builder: (context, state) => const ClosePage(),
      ),
```

`lib/features/goals/presentation/close_page.dart`:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loomia/app/router/back.dart';
import 'package:loomia/app/router/routes.dart';
import 'package:loomia/core/business_model/business_model.dart';
import 'package:loomia/core/ui/empty_state.dart';
import 'package:loomia/core/ui/pick_day.dart';
import 'package:loomia/features/auth/data/auth_repository.dart';
import 'package:loomia/features/goals/data/goals_repository.dart';
import 'package:loomia/features/goals/domain/month_plan.dart';
import 'package:loomia/features/goals/presentation/close_form.dart';
import 'package:loomia/features/goals/presentation/goals_controller.dart';
import 'package:loomia/features/goals/presentation/plan_page.dart';
import 'package:loomia/l10n/app_localizations.dart';
import 'package:material_ui/material_ui.dart';

/// The month-end ritual, full screen: step 1 closes the month (when it was
/// planned and isn't closed yet), step 2 plans the next. The step is local
/// state: closing can't be undone, so back on step 2 leaves.
class ClosePage extends ConsumerStatefulWidget {
  const ClosePage({this.day, this.onDone, super.key});

  /// Today unless a test pins it.
  final DateTime? day;

  /// After the plan is saved, or from "Back to Goals". Defaults to going back
  /// to Goals.
  final VoidCallback? onDone;

  @override
  ConsumerState<ClosePage> createState() => _ClosePageState();
}

class _ClosePageState extends ConsumerState<ClosePage> {
  late final DateTime _day = widget.day ?? today();

  /// What step 1 closed this visit; null before.
  MonthPlan? _closed;

  void _done() => (widget.onDone ?? () => backOr(context, Routes.goals))();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final account = ref.watch(accountProvider);
    final model = account?.businessModel ?? BusinessModel.other;
    final provider = closingProvider((email: account?.email, day: _day));
    final closing = ref.watch(provider);
    final container = ProviderScope.containerOf(context, listen: false);

    return Scaffold(
      appBar: AppBar(
        leading: BackButton(onPressed: () => backOr(context, Routes.goals)),
      ),
      body: SafeArea(
        child: switch (closing) {
          AsyncValue(value: null, hasValue: true) => EmptyState(
            icon: Icons.flag_outlined,
            title: l10n.closeNothing,
            body: l10n.closeNothingBody,
            actionLabel: l10n.closeBackToGoals,
            onAction: _done,
          ),
          AsyncValue(value: final value?)
              when value.ritual.closes && _closed == null =>
            CloseForm(
              closing: value,
              model: model,
              onClose: ({teamVolume, level}) async {
                final closed = await container
                    .read(goalsRepositoryProvider)
                    .close(
                      value.ritual.close,
                      teamVolume: teamVolume,
                      level: level,
                    );
                container.invalidate(goalsProvider);
                if (mounted) setState(() => _closed = closed);
              },
            ),
          AsyncValue(value: final value?) => PlanForm(
            step: value.ritual.closes ? 2 : null,
            month: (
              month: value.ritual.plan,
              plan: value.plans
                  .where((plan) => plan.month == value.ritual.plan)
                  .firstOrNull,
              // Planning reads no progress.
              progress: const Progress(
                ownVolume: 0,
                prospects: 0,
                customers: 0,
                teamMembers: 0,
                loyalty: 0,
              ),
              forecast: value.forecast,
              // The month just closed counts toward the suggestions.
              plans: [
                for (final plan in value.plans)
                  if (plan.month != _closed?.month) plan,
                ?_closed,
              ],
            ),
            model: model,
            onSave: (plan) async {
              await savePlan(container, plan);
              container.invalidate(closingProvider);
            },
            onSaved: _done,
          ),
          AsyncError() => EmptyState(
            icon: Icons.cloud_off_outlined,
            title: l10n.goalsLoadFailed,
            body: l10n.contactsLoadErrorBody,
            actionLabel: l10n.contactsRetry,
            onAction: () => ref.invalidate(provider),
          ),
          _ => const Center(child: CircularProgressIndicator()),
        },
      ),
    );
  }
}
```

Invalidating `closingProvider` after the save reloads it while `PlanForm` is still on screen. If the reload's `null` swaps in "Nothing to close" before `onSaved` pops, move that invalidation into `_done` after the pop.

- [ ] **Step 5: Run them**

Run: `flutter test test/features/goals && flutter analyze`
Expected: all pass, "No issues found!".

- [ ] **Step 6: Commit**

```bash
git add lib/app/router lib/features/goals test/features/goals
git commit -m "feat(goals): close the month, then plan the next"
```

---

### Task 4: The card on Goals, previews and docs

**Files:**
- Create: `lib/features/goals/presentation/ritual_card.dart`
- Modify: `lib/features/goals/presentation/goals_page.dart` (`onRitual`, the card, hide `Change the plan` when closed)
- Modify: `lib/features/goals/presentation/goals_preview.dart` (pass `onRitual`; add `goalsCloseLight`)
- Modify: `test/previews_test.dart` (`goals_close_light`)
- Modify: `docs/design/screens.md` §5 (the Built paragraph)
- Test: `test/features/goals/presentation/goals_page_test.dart` (append)

**Interfaces:**
- Consumes: `pendingRitual`, `PendingRitual` (Task 1); `CloseForm` (Task 2); `Routes.goalsClose` (Task 3).
- Produces:
  - `RitualCard({required PendingRitual ritual, required VoidCallback onStart})`, which #144 reuses on Today;
  - `GoalsView(..., required VoidCallback onRitual)`.

- [ ] **Step 1: Write the failing tests**

In `goals_page_test.dart`, add `var rituals = 0;` beside the other counters. Reset it in `pumpGoals`, and pass `onRitual: () => rituals++`. Then append:

```dart
  testWidgets('the last days: a card to close and plan', (tester) async {
    await pumpGoals(
      tester,
      AsyncData(month(plan: full, progress: progress)),
      day: DateTime(2026, 9, 29),
    );

    expect(find.text('Close September, plan October'), findsOneWidget);
    await tester.tap(find.text('Start'));
    expect(rituals, 1);
  });

  testWidgets('mid-month: no card', (tester) async {
    await pumpGoals(tester, AsyncData(month(plan: full, progress: progress)));

    expect(find.textContaining('Close September'), findsNothing);
  });

  testWidgets('closed: the plan no longer changes', (tester) async {
    await pumpGoals(
      tester,
      AsyncData(
        month(
          plan: MonthPlan(
            month: _september,
            ownVolumeTarget: 2800,
            actual: progress,
            closedAt: DateTime(2026, 9, 29),
          ),
          progress: progress,
        ),
      ),
      day: DateTime(2026, 9, 29),
    );

    expect(find.text('Change the plan'), findsNothing);
    // Closed, October not planned yet: the card offers October alone.
    expect(find.text('Plan October'), findsOneWidget);
  });
```

`month()` builds `plans` from `plan` plus `past`, so `pendingRitual` sees September.

- [ ] **Step 2: Run them**

Run: `flutter test test/features/goals/presentation/goals_page_test.dart`
Expected: compile error, since `GoalsView` has no `onRitual`.

- [ ] **Step 3: Implement**

`lib/features/goals/presentation/ritual_card.dart`:

```dart
import 'package:loomia/app/theme/app_colors.dart';
import 'package:loomia/app/theme/app_spacing.dart';
import 'package:loomia/app/theme/app_theme.dart';
import 'package:loomia/app/theme/app_typography.dart';
import 'package:loomia/features/goals/domain/goal_rules.dart';
import 'package:loomia/l10n/app_localizations.dart';
import 'package:material_ui/material_ui.dart';

/// The month-end ritual's invitation: "Close September, plan October", or
/// "Plan October" when only that is left. Goals shows it; Today will (#144).
class RitualCard extends StatelessWidget {
  const RitualCard({required this.ritual, required this.onStart, super.key});

  final PendingRitual ritual;
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = LoomiaColors.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: AppSpacing.xs,
          children: [
            Text(
              ritual.closes
                  ? l10n.ritualCloseAndPlan(ritual.close, ritual.plan)
                  : l10n.goalsPlanMonth(ritual.plan),
              style: Theme.of(context).textTheme.titleMedium,
            ),
            Text(
              ritual.closes ? l10n.ritualBody : l10n.ritualPlanBody,
              style: AppTypography.caption.copyWith(color: colors.textMuted),
            ),
            const SizedBox(height: AppSpacing.xs),
            FilledButton.tonal(
              onPressed: onStart,
              style: AppTheme.tonal(context),
              child: Text(l10n.ritualStart),
            ),
          ],
        ),
      ),
    );
  }
}
```

`goals_page.dart`:
- `GoalsView` gains `required this.onRitual` (`/// Opens /goals/close.` `final VoidCallback onRitual;`).
- In `build`, compute:

```dart
    final ritual = switch (month) {
      AsyncData(:final value) => pendingRitual(today, value.plans),
      _ => null,
    };
    // Planning this month alone is the empty state's job.
    final showRitual =
        ritual != null &&
        (ritual.closes ||
            month.value?.month != ritual.plan);
```

  and insert `if (showRitual) ...[RitualCard(ritual: ritual, onStart: onRitual), const SizedBox(height: AppSpacing.md)],` right after the `LoomiaTopBar`.
- In `_dashboard`, wrap the `Change the plan` `Align` in `if (!plan.closed)`.
- `GoalsPage` passes `onRitual: () => context.push(Routes.goalsClose)`.

`goals_preview.dart`: pass `onRitual: () {}` to `GoalsView`, and add:

```dart
@Preview(group: 'Goals', name: 'Close — light', size: Size(390, 844))
Widget goalsCloseLight() => _app(
  AppTheme.light,
  Scaffold(
    body: SafeArea(
      child: CloseForm(
        closing: (
          ritual: (close: _september, plan: DateTime(2026, 10), closes: true),
          closing: _month.plan,
          done: const Progress(
            ownVolume: 2650,
            prospects: 7,
            customers: 5,
            teamMembers: 2,
            loyalty: 3,
          ),
          forecast: 3,
          plans: _past,
        ),
        model: BusinessModel.doterra,
        onClose: ({teamVolume, level}) async {},
      ),
    ),
  ),
);
```

with `import 'package:loomia/features/goals/presentation/close_form.dart';`. In `test/previews_test.dart`, add `'goals_close_light': (const Size(390, 844), goalsCloseLight),` after `goals_plan_light`.

`docs/design/screens.md` §5 Built paragraph: replace "Closing a month is\n[#143](https://github.com/paulthvt/loomia/issues/143)." with:

```markdown
From the last 3 days of a month to the 5th of the next, a card at the top
opens `/goals/close` ([#143](https://github.com/paulthvt/loomia/issues/143)):
"How did September go?" (each counted objective against its plan, a check
when reached, a neutral bar under it; team volume and rank typed), `Next`
closes it, then "What are you aiming for in October?" starts from the last 3
closed months. A month never planned skips to the plan; a closed month's plan
no longer changes.
```

- [ ] **Step 4: Run them, gate**

Run: `dart format . && flutter analyze && flutter test`
Expected: "No issues found!", all pass.

- [ ] **Step 5: Commit**

```bash
git add lib test docs/design/screens.md
git commit -m "feat(goals): the close-and-plan card on Goals"
```

After the push, regenerate goldens through CI: `goals_close_light` is new, and nothing else is expected to change, since the September 19 previews show no card.

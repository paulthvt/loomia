# Desktop Columns Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Two real columns on desktop for Today, Goals, Team and the contact detail, and centred, capped planning and closing screens (#171, #145 folded in). Figma comes first.

**Architecture:**
- One desktop-only layout widget, `ContentColumns` (`lib/core/layout/content_columns.dart`). The side column has a fixed width, the main one goes up to 624px, and the pair is centred.
- Each screen keeps its mobile path untouched and builds `ContentColumns(main:, side:)` when `context.screenSize.isDesktop`.
- Three pieces become shared:
  - Team's check-in rows (`checkInItems`), for Today;
  - Goals' volume card (`volumeCard`), for Today;
  - the orders sheet's list (`OrdersList`), for the Goals side column.

**Tech Stack:** Flutter, `flutter_riverpod` 3, `material_ui`; Figma via the `use_figma` MCP tool.

**Spec:** `docs/superpowers/specs/2026-10-04-desktop-columns-design.md`. Responsive rules: `docs/design/responsive-design.md`.

## Global Constraints

- Desktop only (`context.screenSize.isDesktop`, ≥ 1024px). Mobile and tablet render exactly as before, and their goldens don't change.
- Widths: main capped at 624px; side 400px (340px on the contact pane); gap `AppSpacing.xl`; the pair centred within 1440px.
- One scroll per page. Pull-to-refresh and the top bar stay where they are, and the top bar sits at the top of the main column.
- Theme values only. Tonal buttons pass `style: AppTheme.tonal(context)`. Material from `material_ui`.
- No new data, copy or feature, except the orders list's section title, which reuses `ordersTitle`.
- Goldens are made by CI only. Changing on desktop: `today_desktop_*`, `goals_desktop_light`, `team_desktop_light`, `contacts_desktop_light`. New: `goals_plan_desktop_light`.
- Quality gate: `dart format .`, `flutter analyze`, `flutter test`.
- For cross-file questions, use `graphify query` first.

## Review Focus

1. A desktop window between 1024px and 1100px: the main column shrinks and nothing overflows. Pinned in Task 2, with a test at 1024px.
2. Mobile renders exactly as before on every touched screen. Pinned by the existing mobile tests and goldens, unchanged in every task.
3. A deleted order in the Goals side column refreshes the volume and the month, as in the sheet. Pinned in Task 5.
4. Today's side column with no plan and no check-ins: the side is empty, and the main column still sits where it would with a side. Pinned in Task 4.
5. The contact pane at a 1440px window: the facts column is 340px and the main one isn't squeezed below 300px. Pinned in Task 6.

---

### Task 1: Figma — desktop frames and #145's library fixes (then a review gate)

**Files:** none in the repo. Figma file `spz2vsSK8gbt1Ok2rW1sdQ`.

**Interfaces:** Produces the frames Tasks 2 to 7 follow.

- [ ] **Step 1: Load the skill.** Invoke `figma:figma-use` before any `use_figma` call. Read the existing frames you'll copy from:
  - Today desktop (`docs/design/screens.md` lists the frames);
  - Goals desktop `202:2706`;
  - Contacts desktop (stages);
  - Team mobile.
- [ ] **Step 2: #145's library fixes:**
  - the progress bar component gains a `value` property (0 to 100) that drives the fill width;
  - a `Switch` component (On/Off), replacing the "On" SettingsRow in the "Workflow step — loyalty switch" frame;
  - the TextField gets a suffix slot showing "PV";
  - the StatTile value text style goes to the 20px numeric style;
  - the desktop sidebar wordmark reads "Loomia".
- [ ] **Step 3: Desktop frames** at 1440 × 900, built from component instances, each light:
  - "Today — desktop (columns)": main is the top bar, the hero and PRIORITY. The 400px side holds the own-volume GoalCard, the close-and-plan card and WORTH A CHECK-IN.
  - "Goals — desktop (columns)": main is the volume card, the tiles, the declared row, the pace card, Log my own order and Change the plan. The side holds the close-and-plan card, "Orders in October" (rows with a delete icon) and PAST MONTHS.
  - "Team — desktop (columns)": main is EVERYONE. The side holds the summary card and WORTH A CHECK-IN.
  - "Contact detail — desktop (wide facts)": next step and history capped at 624px, and a 340px facts column.
  - "Plan — desktop": the planning form, one column capped at 624px and centred.
- [ ] **Step 4: Screenshot each frame** with `get_screenshot` and keep the node ids.
- [ ] **Step 5: STOP — review gate.** Send the user the node ids and screenshots, and wait for their OK. Their changes go back into the frames, and into this plan's widths if they move. No code before the OK.

---

### Task 2: `ContentColumns`

**Files:**
- Create: `lib/core/layout/content_columns.dart`
- Test: `test/core/layout/content_columns_test.dart`

**Interfaces:**
- Produces: `ContentColumns({required List<Widget> main, required List<Widget> side, double sideWidth = 400})`.
  - Use it only on desktop.
  - Below desktop, as a fallback, it stacks `main` then `side`.
  - Each list is laid out in a `Column` stretched to its column's width.

- [ ] **Step 1: Write the failing test**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:loomia/core/layout/content_columns.dart';
import 'package:material_ui/material_ui.dart';

const _main = Key('main');
const _side = Key('side');

Future<void> _pump(WidgetTester tester, double width) {
  tester.view
    ..physicalSize = Size(width, 900)
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  return tester.pumpWidget(
    const MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: ContentColumns(
            main: [SizedBox(key: _main, height: 100)],
            side: [SizedBox(key: _side, height: 50)],
          ),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('desktop: side to the right at 400, main at most 624', (
    tester,
  ) async {
    await _pump(tester, 1440);

    expect(tester.getSize(find.byKey(_side)).width, 400);
    expect(tester.getSize(find.byKey(_main)).width, 624);
    expect(
      tester.getTopLeft(find.byKey(_side)).dx,
      greaterThan(tester.getTopRight(find.byKey(_main)).dx),
    );
    expect(
      tester.getTopLeft(find.byKey(_side)).dy,
      tester.getTopLeft(find.byKey(_main)).dy,
    );
  });

  testWidgets('a wide window centres the pair', (tester) async {
    await _pump(tester, 1920);

    final left = tester.getTopLeft(find.byKey(_main)).dx;
    final right = 1920 - tester.getTopRight(find.byKey(_side)).dx;
    expect(left, moreOrLessEquals(right, epsilon: 1));
  });

  testWidgets('a narrow desktop shrinks main, never side', (tester) async {
    await _pump(tester, 1024);

    expect(tester.getSize(find.byKey(_side)).width, 400);
    expect(tester.getSize(find.byKey(_main)).width, lessThan(624));
    expect(tester.takeException(), isNull);
  });

  testWidgets('mobile: main then side, full width', (tester) async {
    await _pump(tester, 390);

    expect(
      tester.getTopLeft(find.byKey(_side)).dy,
      greaterThan(tester.getTopLeft(find.byKey(_main)).dy),
    );
    expect(tester.getSize(find.byKey(_side)).width, 390);
  });
}
```

- [ ] **Step 2: Run it**

Run: `flutter test test/core/layout/content_columns_test.dart`
Expected: compile error, `content_columns.dart` doesn't exist.

- [ ] **Step 3: Implement**

```dart
import 'package:loomia/app/theme/app_spacing.dart';
import 'package:loomia/core/layout/breakpoints.dart';
import 'package:material_ui/material_ui.dart';

/// Desktop's two columns (`docs/design/responsive-design.md`): [main] up to
/// [mainMax], [side] fixed at [sideWidth], top-aligned, the pair centred.
/// A narrower window shrinks [main], never [side]. Below desktop, [main]
/// then [side] in one column.
class ContentColumns extends StatelessWidget {
  const ContentColumns({
    required this.main,
    required this.side,
    this.sideWidth = 400,
    super.key,
  });

  final List<Widget> main;
  final List<Widget> side;
  final double sideWidth;

  static const double mainMax = 624;

  @override
  Widget build(BuildContext context) {
    Widget column(List<Widget> children) => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: children,
    );
    if (!context.screenSize.isDesktop) return column([...main, ...side]);
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: mainMax + AppSpacing.xl + sideWidth,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: column(main)),
            const SizedBox(width: AppSpacing.xl),
            SizedBox(width: sideWidth, child: column(side)),
          ],
        ),
      ),
    );
  }
}
```

With the outer cap of `mainMax + gap + side`, `Expanded` gives main exactly 624px when there's room and less when there isn't. Centring inside the scroll view gives the margins. The 1440px limit holds because the pair is narrower than that.

- [ ] **Step 4: Run it**

Run: `flutter test test/core/layout && flutter analyze`
Expected: PASS, "No issues found!".

- [ ] **Step 5: Commit**

```bash
git add lib/core/layout test/core/layout
git commit -m "feat(layout): two columns on desktop"
```

---
### Task 3: Team on desktop, and shared check-in rows

**Files:**
- Create: `lib/features/team/presentation/check_in_items.dart` (`checkInItems`, `checkInReason`, moved from `team_page.dart`)
- Modify: `lib/features/team/presentation/team_page.dart`
- Test: `test/features/team/team_desktop_test.dart` (create)

**Interfaces:**
- Consumes: `ContentColumns` (Task 2).
- Produces:
  - `List<Widget> checkInItems(AppLocalizations l10n, List<CheckIn> due, {required void Function(Person) onOpen, required void Function(Person) onCheckIn})`: the `WORTH A CHECK-IN` header and its `ActionItem`s, or `[]` when `due` is empty;
  - `String checkInReason(AppLocalizations l10n, CheckIn checkIn)`: `_reason`'s body, verbatim.

- [ ] **Step 1: Write the failing test**

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loomia/app/theme/app_theme.dart';
import 'package:loomia/features/contacts/domain/person.dart';
import 'package:loomia/features/team/presentation/team_page.dart';
import 'package:loomia/l10n/app_localizations.dart';
import 'package:loomia/l10n/localizations_delegates.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  final today = DateTime(2026, 9, 29);
  Person member(String name, {DateTime? talked}) => Person(
    id: name,
    name: name,
    stage: Stage.team,
    stageSince: DateTime(2026, 5),
    lastContactOn: talked,
  );

  testWidgets('desktop: roster left, summary and check-ins right', (
    tester,
  ) async {
    tester.view
      ..physicalSize = const Size(1440, 900)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        localizationsDelegates: localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: TeamView(
          people: AsyncData([
            member('Janine', talked: DateTime(2026, 9, 1)),
            member('Jeanne', talked: DateTime(2026, 9, 28)),
          ]),
          today: today,
          onOpen: (_) {},
          onRetry: () {},
          onCheckIn: (_) {},
          onRefresh: () async {},
        ),
      ),
    );

    final everyone = tester.getTopLeft(find.text('EVERYONE')).dx;
    expect(
      tester.getTopLeft(find.text('WORTH A CHECK-IN')).dx,
      greaterThan(everyone + 600),
    );
    expect(
      tester.getTopLeft(find.textContaining('people on your team')).dx,
      greaterThan(everyone + 600),
    );
  });
}
```

Check `teamSectionCheckIn` and `teamSectionEveryone` in `app_en.arb` (`SectionHeader` uppercases them), and the summary's headline key ("people on your team").

- [ ] **Step 2: Run it**

Run: `flutter test test/features/team/team_desktop_test.dart`
Expected: FAIL. The check-ins sit above EVERYONE in one column, so their `dx` is the same.

- [ ] **Step 3: Implement**

`check_in_items.dart`:

```dart
import 'package:loomia/app/theme/app_spacing.dart';
import 'package:loomia/core/ui/action_item.dart';
import 'package:loomia/core/ui/section_header.dart';
import 'package:loomia/features/contacts/domain/person.dart';
import 'package:loomia/features/contacts/presentation/people_copy.dart';
import 'package:loomia/features/team/domain/check_in.dart';
import 'package:loomia/l10n/app_localizations.dart';
import 'package:material_ui/material_ui.dart';

/// `WORTH A CHECK-IN`: its header and one row per member who might need
/// you. Team shows it; Today's desktop side column too. Nothing when [due]
/// is empty.
List<Widget> checkInItems(
  AppLocalizations l10n,
  List<CheckIn> due, {
  required void Function(Person person) onOpen,
  required void Function(Person person) onCheckIn,
}) => [
  if (due.isNotEmpty) ...[
    SectionHeader(title: l10n.teamSectionCheckIn),
    for (final (index, checkIn) in due.indexed) ...[
      if (index > 0) const SizedBox(height: AppSpacing.ms),
      ActionItem(
        name: checkIn.person.name,
        reason: checkInReason(l10n, checkIn),
        chip: DateChip(switch (checkIn.reason) {
          CheckInReason.isNew => l10n.teamChipNew,
          CheckInReason.quiet => l10n.teamChipQuiet(checkIn.days ~/ 7),
        }),
        onOpen: () => onOpen(checkIn.person),
        onResolve: () => onCheckIn(checkIn.person),
        resolveLabel: l10n.logTitle(firstName(checkIn.person)),
      ),
    ],
  ],
];

/// Why [checkIn]'s member is worth a check-in, in plain words.
String checkInReason(AppLocalizations l10n, CheckIn checkIn) {
  final (:person, :reason, :since, :days) = checkIn;
  return switch (reason) {
    CheckInReason.isNew when days <= 0 => l10n.teamReasonNewToday,
    CheckInReason.isNew when days < 7 => l10n.teamReasonNewDays(days),
    CheckInReason.isNew => l10n.teamReasonNewWeeks(days ~/ 7),
    CheckInReason.quiet when person.lastContactOn == null =>
      l10n.teamReasonQuietNothing(since),
    CheckInReason.quiet => l10n.teamReasonQuiet(since),
  };
}
```

`DateChip` lives in `action_item.dart`; check where Today imports it from and match that.

`team_page.dart`:
- Delete `_reason`.
- Split `_team` into three lists: `summary` (the `_Summary`), `checks` (`checkInItems(...)`) and `roster` (the EVERYONE header and the `ContactRow`s).
- Mobile keeps the old order and spacing: summary, then `lg`, checks, `lg`, roster.
- In `build`, when `desktop` and the team isn't empty, replace the `ListView`'s children after the top bar with:

```dart
ContentColumns(
  main: roster,
  side: [summary, if (checks.isNotEmpty) ...[const SizedBox(height: AppSpacing.lg), ...checks]],
)
```

  The top bar goes into `main`, before `roster`.
- Drop the `ConstrainedBox(maxWidth: _column)` and `Align` on desktop. `ContentColumns` caps and centres. Mobile keeps both.
- The empty and error states on desktop stay one column, centred with `ContentColumns(main: [...], side: const [])`.

Have `_team` return a record, `({List<Widget> summary, List<Widget> checks, List<Widget> roster})?`, null when the team is empty, so `build` chooses the layout.

- [ ] **Step 4: Run them**

Run: `flutter test test/features/team && flutter analyze`
Expected: all pass, the old mobile tests unchanged, "No issues found!".

- [ ] **Step 5: Commit**

```bash
git add lib/features/team test/features/team
git commit -m "feat(team): roster and check-ins side by side on desktop"
```

---

### Task 4: Today on desktop

**Files:**
- Create: `lib/features/goals/presentation/volume_card.dart` (`volumeCard`, moved out of `_dashboard`)
- Modify: `lib/features/goals/presentation/goals_page.dart` (uses `volumeCard`)
- Modify: `lib/features/today/presentation/today_page.dart`
- Test: `test/features/today/today_goals_test.dart` (append)

**Interfaces:**
- Consumes: `ContentColumns` (Task 2); `checkInItems` and `checkIns(team, today)` (Task 3, and `team/domain/check_in.dart`); `RitualCard`, `pendingRitual`, `GoalsMonth`.
- Produces:
  - `Widget volumeCard(BuildContext context, {required GoalsMonth month, required DateTime today, required BusinessModel model, VoidCallback? onTap})`: the own-volume `GoalCard` exactly as `_dashboard` builds it;
  - `TodayView(..., List<CheckIn> checkIns = const [], void Function(Person)? onCheckIn)`.

- [ ] **Step 1: Write the failing tests**

Append to `today_goals_test.dart`:
- a `pumpDesktop` variant of `pump` with `tester.view.physicalSize = const Size(1440, 900)`;
- an optional `checkIns` passed through.

```dart
  testWidgets('desktop: the volume card and the card on the side', (
    tester,
  ) async {
    await pump(
      tester,
      now: DateTime(2026, 9, 29, 9),
      goals: _goals(),
      size: const Size(1440, 900),
    );

    expect(find.text('1,800 PV to go · 1 day left'), findsNothing);
    expect(find.text('Own volume'), findsOneWidget);
    final priority = tester.getTopLeft(find.text('PRIORITY')).dx;
    expect(
      tester.getTopLeft(find.text('Own volume')).dx,
      greaterThan(priority + 600),
    );
    expect(
      tester.getTopLeft(find.text('Close September, plan October')).dx,
      greaterThan(priority + 600),
    );
    await tester.tap(find.text('Own volume'));
    expect(goalsTaps, 1);
  });

  testWidgets('desktop, nothing for the side: main stays put', (
    tester,
  ) async {
    await pump(tester, now: DateTime(2026, 9, 15, 9), size: const Size(1440, 900));

    expect(find.text('Anna'), findsOneWidget);
    expect(find.text('Own volume'), findsNothing);
  });
```

Give `pump` a `Size size = const Size(390, 1400)` parameter for this. The check-in rows' placement is covered by Team's test (same `checkInItems`).

- [ ] **Step 2: Run them**

Run: `flutter test test/features/today/today_goals_test.dart`
Expected: FAIL: the line shows, and there's no "Own volume".

- [ ] **Step 3: Implement**

`volume_card.dart`: move the `GoalCard(...)` construction from `_dashboard`, with its `number`, `hasTarget`, `pacing` and `daysLeft` locals, into:

```dart
/// The own-volume card: Goals' first card, and Today's on desktop.
Widget volumeCard(
  BuildContext context, {
  required GoalsMonth month,
  required DateTime today,
  required BusinessModel model,
  VoidCallback? onTap,
}) {
  final l10n = AppLocalizations.of(context);
  final number = NumberFormat.decimalPattern(l10n.localeName);
  final done = month.progress;
  final target = month.plan?.ownVolumeTarget;
  final hasTarget = target != null && target > 0;
  final pacing = pace(hasTarget ? target : null, done.ownVolume, today);
  final daysLeft = DateTime(today.year, today.month + 1, 0).day - today.day;
  return GoalCard(/* exactly the arguments _dashboard passes today */);
}
```

`_dashboard` calls `volumeCard(context, month: month, today: today, model: model, onTap: onOrders)`.

`TodayView` gains `this.checkIns = const []` and `this.onCheckIn`. In `build`, when `desktop`, the `ListView` children become one `ContentColumns`:
- `main`: the top bar, then the current switch's content without `goalWidgets`.
- `side`: in order,
  - `if (goals != null && hasGoalLine(goals)) volumeCard(context, month: goals, today: day, model: widget.model, onTap: widget.onGoals)`;
  - the `RitualCard` if `ritual != null`;
  - `...checkInItems(l10n, widget.checkIns, onOpen: widget.onOpen, onCheckIn: widget.onCheckIn ?? (_) {})`;
  - with `AppSpacing.md` between the pieces.

`_due` gets an empty `goalWidgets` on desktop. Drop the `Align` and `ConstrainedBox(_column)` on desktop, as for Team.

`TodayPage` passes:
- `checkIns: checkIns([for (final p in people.value ?? const <Person>[]) if (p.stage == Stage.team) p], today())`;
- `onCheckIn: (person) => unawaited(showLogActivity(context, person))`.

- [ ] **Step 4: Run them**

Run: `flutter test test/features/today test/features/goals && flutter analyze`
Expected: all pass, "No issues found!".

- [ ] **Step 5: Commit**

```bash
git add lib/features/goals lib/features/today test/features/today
git commit -m "feat(today): goals and check-ins beside the priority list on desktop"
```

---

### Task 5: Goals on desktop, the orders listed inline

**Files:**
- Modify: `lib/features/goals/presentation/orders_sheet.dart` (extract `OrdersList`)
- Modify: `lib/features/goals/presentation/goals_page.dart`
- Test: `test/features/goals/presentation/goals_desktop_test.dart` (create); `orders_sheet_test.dart` still passes

**Interfaces:**
- Consumes: `ContentColumns` (Task 2); `ordersProvider`, `refreshOrders`, `MonthOrder`.
- Produces:
  - `OrdersList({required DateTime month})`: a `ConsumerStatefulWidget` holding today's `_OrdersState` body (failure, rows, empty, error, loading). The sheet's `LoomiaDialog` wraps it, and Goals' side column uses it under `SectionHeader(title: l10n.ordersTitle(month))`;
  - `GoalsView` builds `ContentColumns` on desktop.

- [ ] **Step 1: Write the failing test**

`goals_desktop_test.dart` pumps `GoalsView` at 1440 × 900 inside a `ProviderScope`. `OrdersList` reads `ordersProvider`, so override `activityRepositoryProvider` with a `FakeActivityRepository` holding one order this month, and `authRepositoryProvider` with a signed-in `FakeAuthRepository`. Use the `month(plan:, progress:)` data from `goals_page_test.dart`, copied locally.

```dart
  testWidgets('desktop: dashboard left, orders and past months right', (
    tester,
  ) async {
    // pump as described, day September 19
    final tiles = tester.getTopLeft(find.text('NEW PROSPECTS')).dx;
    expect(
      tester.getTopLeft(find.textContaining('Orders in')).dx,
      greaterThan(tiles + 600),
    );
    expect(find.text('Order · 100 PV'), findsOneWidget);
    // The list is already there: the card doesn't open the sheet.
    await tester.tap(find.text('Own volume'));
    await tester.pumpAndSettle();
    expect(find.byType(Dialog), findsNothing);
  });
```

Write the pump fully, following `orders_sheet_test.dart`'s use of `pumpFormHarness` for the providers, with `open:` replaced by building `GoalsView` directly in a `ProviderScope`. If `pumpFormHarness` only opens through a button, build the `ProviderScope` and the overrides by hand, as `close_page_test.dart` does. `GoalsView` with `onOrders: () => showOrders(...)` would open a sheet; the test passes `onOrders: () => fail('no sheet on desktop')`, and the view must pass `onTap: null` on desktop.

- [ ] **Step 2: Run it**

Run: `flutter test test/features/goals/presentation/goals_desktop_test.dart`
Expected: FAIL, "Orders in" not found.

- [ ] **Step 3: Implement**

`orders_sheet.dart`:
- Rename `_Orders`/`_OrdersState` to `OrdersList`/`_OrdersListState` and make it public.
- Its `build` returns the `Column` (failure, then the switch), not the `LoomiaDialog`.
- `showOrders` becomes `LoomiaDialog.show(context, (context) => LoomiaDialog(title: ..., actions: [close], child: OrdersList(month: month)))`. The `ConsumerWidget` wrapper reads nothing, so `LoomiaDialog` can take `OrdersList` directly.

`goals_page.dart`:
- Split `_dashboard` into `main` (volume card, tiles, declared, pace, buttons) and `past` (the PAST MONTHS header and card).
- Mobile: `[ritual card], ...main, ...past`, as now.
- Desktop: the `ListView` children are `[ContentColumns(main: [topBar, ...main], side: [if (showRitual) RitualCard(...), SizedBox md, SectionHeader(title: l10n.ordersTitle(value.month)), OrdersList(month: value.month), SizedBox lg, ...past])]`, with `volumeCard(..., onTap: null)`.
- The empty state on desktop stays one centred column: `ContentColumns(main: [topBar, emptyState], side: const [])`.

- [ ] **Step 4: Run them**

Run: `flutter test test/features/goals && flutter analyze`
Expected: all pass, "No issues found!".

- [ ] **Step 5: Commit**

```bash
git add lib/features/goals test/features/goals
git commit -m "feat(goals): the month's orders and past months beside the dashboard on desktop"
```

---

### Task 6: The contact pane

**Files:**
- Modify: `lib/features/contacts/presentation/contact_details.dart` (desktop split at lines ~432-454; `_factsWidth`)
- Test: `test/features/contacts/presentation/contact_details_test.dart` (append)

**Interfaces:**
- Consumes: `ContentColumns` (Task 2).

- [ ] **Step 1: Write the failing test**

Append a desktop test. Find the file's existing desktop pump with `grep -n "1440\|isDesktop\|physicalSize" test/features/contacts/presentation/contact_details_test.dart`. If it has none, set `tester.view.physicalSize = const Size(752, 900)` and the desktop screen size the same way the contacts page tests do (`grep -rn "screenSize\|ScreenSize" test/features/contacts | head`). Then:

```dart
  testWidgets('desktop pane: the facts column is 340 wide', (tester) async {
    // pump ContactDetails for a team member at the pane's 752px, desktop
    final facts = find.text('WHAT YOU KNOW');
    final column = tester.getSize(
      find.ancestor(of: facts, matching: find.byType(Column)).first,
    );
    expect(column.width, 340);
    expect(
      tester.getTopLeft(find.text('NEXT STEP')).dx,
      lessThan(tester.getTopLeft(facts).dx),
    );
  });
```

Before writing it, check how `ContactDetails` decides desktop: `context.screenSize` reads the window width, not the pane's. The test sets the window to 1440 and lets the widget take the pane's 752px through a `SizedBox(width: 752)` around it.

- [ ] **Step 2: Run it**

Expected: FAIL, width 272.

- [ ] **Step 3: Implement**

`_factsWidth = 340`. Replace the desktop `Row` with:

```dart
ContentColumns(
  sideWidth: _factsWidth,
  main: spaced([whereItStands, [?nextStep], [?history]]),
  side: spaced([aimingFor, whatYouKnow]),
)
```

`ContentColumns` caps main at 624px and centres the pair inside a wide pane. WHERE IT STANDS stays in main, as now: the spec lists it in the side column, but it's a control for the prospect, beside the next step. Ledger the ruling.

- [ ] **Step 4: Run them**

Run: `flutter test test/features/contacts && flutter analyze`
Expected: all pass, "No issues found!".

- [ ] **Step 5: Commit**

```bash
git add lib/features/contacts test/features/contacts
git commit -m "feat(contacts): a wider facts column on the desktop pane"
```

---

### Task 7: Planning and closing centred, previews, docs

**Files:**
- Modify: `lib/features/goals/presentation/plan_page.dart` (`PlanForm` `ListView` → centred and capped), `close_form.dart` (same)
- Modify: `lib/features/goals/presentation/goals_preview.dart` (`goalsPlanDesktopLight`), `test/previews_test.dart`
- Modify: `docs/design/responsive-design.md` (Desktop section: how Today, Goals, Team and the contact pane split), `docs/design/screens.md` (one line in §5 Built)
- Test: `test/features/goals/presentation/plan_page_test.dart` (append)

- [ ] **Step 1: Write the failing test**

```dart
  testWidgets('desktop: the form is one centred column', (tester) async {
    goals = FakeGoalsRepository();
    await open(tester);
    tester.view.physicalSize = const Size(1440, 900);
    await tester.pumpAndSettle();

    final field = tester.getRect(field('Own volume (PV)'));
    expect(field.width, lessThanOrEqualTo(624));
    expect(field.center.dx, moreOrLessEquals(720, epsilon: 2));
  });
```

`open` sets the view to 390 × 2400. Setting it after `open`, as above, resizes it; or give `open` a `Size` parameter.

- [ ] **Step 2: Run it**

Expected: FAIL, the field is about 1400px wide.

- [ ] **Step 3: Implement**

In both `PlanForm` and `CloseForm`, wrap the `ListView` in:

```dart
Center(
  child: ConstrainedBox(
    constraints: const BoxConstraints(maxWidth: ContentColumns.mainMax),
    child: ListView(...),
  ),
)
```

`ListView` inside a centred box needs a bounded height, which the `Scaffold` body gives. Leave the back arrow as it is: `AppBar.leading` sits at the window's start. Aligning it with the column is cosmetic, and the Figma gate in Task 1 decides it. Ledger the choice.

`goals_preview.dart`: add `@Preview(group: 'Goals', name: 'Plan — desktop', size: Size(1440, 900)) Widget goalsPlanDesktopLight() => goalsPlanLight();`. The same widget at desktop size is enough, because the preview harness sets the size. Add `'goals_plan_desktop_light': (const Size(1440, 900), goalsPlanDesktopLight),` to `previews_test.dart`.

`responsive-design.md` Desktop section: replace the Today two-column bullet with the four splits from the spec (widths included) and note `ContentColumns`.

- [ ] **Step 4: Gate**

Run: `dart format . && flutter analyze && flutter test`
Expected: "No issues found!", all pass.

- [ ] **Step 5: Commit**

```bash
git add lib test docs/design
git commit -m "feat(goals): planning and closing in one centred column on desktop"
```

After the push, regenerate goldens through CI and check them against the Task 1 frames: `today_desktop_*`, `goals_desktop_light`, `team_desktop_light`, `contacts_desktop_light`, and the new `goals_plan_desktop_light`.

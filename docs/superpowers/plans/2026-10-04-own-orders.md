# Own Orders and the Month's Orders Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** `Log my own order` on the Goals tab, and a tap on the own-volume card lists this month's orders (contacts' and own), each removable (#165).

**Architecture:**
- `Activity.personId` becomes nullable.
- `ActivityRepository` gains `addOwnOrder(draft)` and `ordersIn(month)`. The latter returns each order with its person's name, through PostgREST's `person(name)` embed.
- The Log something form takes an optional person and a save callback. `showLogOwnOrder` opens it with no person: Order only, amount required.
- Goals adds the button and an orders sheet, fed by an `ordersProvider`. After an add or a removal, the Goals month, the orders, the person's history and the book are all invalidated.

**Tech Stack:** Flutter, `flutter_riverpod` 3, `supabase_flutter`, `material_ui`.

**Spec:** `docs/superpowers/specs/2026-10-02-goals-design.md` §1 decision "Own orders: logged from Goals, an `order` activity with no person", §4 Goals tab ("Tapping the volume card lists this month's orders…, each removable"). Figma own order `204:3039`. The DB already allows an own order (#138: no person only on an order with an amount).

## Global Constraints

- Imports `package:loomia/...`; Material from `material_ui`; theme values only; layout via `context.screenSize`.
- Copy in `lib/l10n/app_en.arb` only, every key described; business-model words via `select` on `model.name`; informal. Run `flutter gen-l10n`.
- Repositories throw `PeopleFailure` only (`guardPeople`). Riverpod providers that load set `retry: (error, _) => null`, as `goalsProvider` and `historyProvider` do.
- Goldens only through CI (README → Golden tests); `goals_mobile_*` and `goals_desktop_light` change (new button).
- Quality gate: `dart format .`, `flutter analyze`, `flutter test`.

## Rulings made while planning

- **Removing an order asks first**, with the history's `confirmDestructive` ("Delete this entry?"), because it's the same entry as in the person's history.
- **Orders without an amount are listed too.** A contact's order can be text only. It shows by its text, and it counts 0 toward volume.
- **The orders sheet has no Figma frame.** It's a `LoomiaDialog` titled "Orders in September", with one row per order: the title from the history ("Order · 100 PV"), then "September 2 · Marie Dupont", or "· Your own order". There's a delete icon button per row, newest first.
- **The own order's date** can be any past day up to today, as in Log something. Goals counts it in its own month.

## Review Focus

1. An own order saved from Goals shows at once in the volume and in the orders sheet. Pinned in Task 3.
2. Removing a contact's order from the sheet also leaves that person's history. Pinned in Task 3 (the history is invalidated).
3. A failed save keeps the sheet and what was typed; a failed removal shows a snack bar and keeps the row. Pinned in Tasks 2 and 3.
4. An own order without an amount is refused in the form, never sent. Pinned in Task 2.
5. Other business model: no "PV" in the sheet or the orders list. Pinned in Tasks 2 and 3.

---
### Task 1: Orders with no person, and a month's orders

**Files:**
- Modify: `lib/features/contacts/domain/activity.dart` (`personId` nullable, `MonthOrder`)
- Modify: `lib/features/contacts/data/activity_repository.dart` (`addOwnOrder`, `ordersIn`, `monthOrderFromRow`, `activityDraftToRow(String? ...)`)
- Modify: `test/features/contacts/fake_activity_repository.dart`
- Test: `test/features/contacts/data/activity_repository_test.dart`

**Interfaces:**
- Produces:
  - `Activity.personId` is a `String?`. It's null only on an order with an amount (DB rule `person_or_own_order`).
  - `typedef MonthOrder = ({Activity order, String? personName})`.
  - `ActivityRepository.addOwnOrder(ActivityDraft draft) → Future<Activity>`.
  - `ActivityRepository.ordersIn(DateTime month) → Future<List<MonthOrder>>`, newest day first.
  - `monthOrderFromRow(Map<String, dynamic>)`.
  - Fake: `addOwnOrder`, `ordersIn`, and a `names` map from person id to name.

- [ ] **Step 1: Write the failing tests**

Append inside `main()` of `activity_repository_test.dart`:

```dart
  test('an own order has no person', () {
    final order = activityFromRow(
      _row({'person_id': null, 'kind': 'order', 'text': null, 'amount': 80}),
    );

    expect(order.personId, isNull);
    expect(order.amount, 80);
  });

  test("a month's order carries its person's name, or none", () {
    final theirs = monthOrderFromRow(
      _row({
        'kind': 'order',
        'amount': 100,
        'person': {'name': 'Marie Dupont'},
      }),
    );
    final own = monthOrderFromRow(
      _row({
        'person_id': null,
        'kind': 'order',
        'text': null,
        'amount': 80,
        'person': null,
      }),
    );

    expect(theirs.personName, 'Marie Dupont');
    expect(theirs.order.amount, 100);
    expect(own.personName, isNull);
  });

  test('activityDraftToRow: an own order writes no person', () {
    final row = activityDraftToRow(null, (
      kind: ActivityKind.order,
      happenedOn: DateTime(2026, 9, 19),
      text: '',
      amount: 100,
    ));

    expect(row['person_id'], isNull);
    expect(row['amount'], 100);
  });
```

- [ ] **Step 2: Run them**

Run: `flutter test test/features/contacts/data/activity_repository_test.dart`
Expected: compile errors. `monthOrderFromRow` isn't defined, and `null` can't be passed as the `String` `personId`.

- [ ] **Step 3: Implement**

`activity.dart`:
- `final String? personId;` with a doc comment: "Null on the user's own order, which has an amount (Goals)."
- In the constructor's assert, add `&& (personId != null || (kind == ActivityKind.order && amount != null))`, and add "; only an own order has no person" to its message.
- After `typedef ActivityDraft`:

```dart
/// An order in a month's list: the entry and whose it is (null: the user's
/// own).
typedef MonthOrder = ({Activity order, String? personName});
```

`activity_repository.dart`:
- `activityFromRow`: `personId: row['person_id'] as String?,`
- `activityDraftToRow(String? personId, ActivityDraft draft)`, unchanged otherwise.
- Methods after `add`:

```dart
  /// The user's own order, with no person. Needs an amount (the database
  /// refuses one without).
  Future<Activity> addOwnOrder(ActivityDraft draft) => guardPeople(() async {
    assert(
      draft.kind == ActivityKind.order && draft.amount != null,
      'An own order needs an amount',
    );
    final row = await _client
        .from(_table)
        .insert(activityDraftToRow(null, draft))
        .select()
        .single();
    return activityFromRow(row);
  });

  /// Every order in [month], contacts' and own, latest day first, then
  /// latest made.
  Future<List<MonthOrder>> ordersIn(DateTime month) => guardPeople(() async {
    final rows = await _client
        .from(_table)
        .select('*, person(name)')
        .eq('kind', ActivityKind.order.name)
        .gte('happened_on', dayColumn(DateTime(month.year, month.month)))
        .lt('happened_on', dayColumn(DateTime(month.year, month.month + 1)))
        .order('happened_on', ascending: false)
        .order('created_at', ascending: false);
    return rows.map(monthOrderFromRow).toList();
  });
```

- Top level:

```dart
MonthOrder monthOrderFromRow(Map<String, dynamic> row) => (
  order: activityFromRow(row),
  personName: (row['person'] as Map<String, dynamic>?)?['name'] as String?,
);
```

`person(name)` embeds through the composite foreign key `(person_id, owner_id)`, the only one from `activity` to `person`. An own order embeds `null`.

Fake (`fake_activity_repository.dart`):

```dart
  /// Person id to name, for [ordersIn].
  final Map<String, String> names = {};

  @override
  Future<Activity> addOwnOrder(ActivityDraft draft) async {
    await _record('addOwnOrder()');
    final text = draft.text.trim();
    final activity = Activity(
      id: 'a-${_next++}',
      personId: null,
      kind: ActivityKind.order,
      happenedOn: draft.happenedOn,
      text: text.isEmpty ? null : text,
      amount: draft.amount,
      createdAt: DateTime.utc(2026, 9, 28, 12),
    );
    store.add(activity);
    return activity;
  }

  @override
  Future<List<MonthOrder>> ordersIn(DateTime month) async {
    await _record('ordersIn(${month.year}-${month.month})');
    return [
      for (final entry in store.reversed)
        if (entry.kind == ActivityKind.order &&
            entry.happenedOn.year == month.year &&
            entry.happenedOn.month == month.month)
          (order: entry, personName: names[entry.personId]),
    ]..sort((a, b) => b.order.happenedOn.compareTo(a.order.happenedOn));
  }
```

Then run `flutter analyze`. Any `activity.personId` used as a `String` now fails to compile; there were none outside the repository and the fake (`grep -rn "\.personId" lib test`). Fix each with a null check that matches its meaning.

- [ ] **Step 4: Run them**

Run: `flutter test test/features/contacts && flutter analyze`
Expected: all pass, "No issues found!".

- [ ] **Step 5: Commit**

```bash
git add lib/features/contacts test/features/contacts
git commit -m "feat(goals): read and write own orders and a month's orders"
```

---
### Task 2: Your own order sheet

**Files:**
- Modify: `lib/l10n/app_en.arb` (all of this plan's keys, after `"logNote"`'s entry)
- Modify: `lib/features/contacts/presentation/log_activity_sheet.dart`
- Test: `test/features/contacts/presentation/log_activity_sheet_test.dart` (append a group)

**Interfaces:**
- Consumes: `ActivityRepository.addOwnOrder`, `activityRepositoryProvider` (Task 1).
- Produces: `Future<void> showLogOwnOrder(BuildContext context, {required VoidCallback onSaved})`. `showLogActivity(context, person)` stays as it is.

- [ ] **Step 1: Copy**

Add after the `"@logNote"` entry:

```json
  "logOwnOrderTitle": "Your own order",
  "@logOwnOrderTitle": { "description": "Title of the sheet that logs an order of the user's own, from Goals: no person." },
  "logOwnOrderAmountRequired": "Enter the amount.",
  "@logOwnOrderAmountRequired": { "description": "Error under the amount of an own order, which can't be saved without one." },
  "goalLogOwnOrder": "Log my own order",
  "@goalLogOwnOrder": { "description": "Goals button: opens Your own order." },
  "ordersTitle": "Orders in {month}",
  "@ordersTitle": {
    "description": "Title of the sheet listing this month's orders, opened from the own-volume card.",
    "placeholders": { "month": { "type": "DateTime", "format": "MMMM" } }
  },
  "ordersOwn": "Your own order",
  "@ordersOwn": { "description": "In the month's orders, in place of a person's name: the user's own order." },
  "ordersEmpty": "No orders yet this month.",
  "@ordersEmpty": { "description": "The month's orders sheet when there is none." },
  "ordersLoadFailed": "Couldn't load the orders.",
  "@ordersLoadFailed": { "description": "The month's orders sheet when they can't be loaded." },
  "ordersRemove": "Delete this order",
  "@ordersRemove": { "description": "Tooltip and screen-reader label of the delete button on an order in the month's list." },
```

Run `flutter gen-l10n`.

- [ ] **Step 2: Write the failing tests**

Append inside `main()`:

```dart
  group('your own order', () {
    late int saved;

    Future<void> openOwn(
      WidgetTester tester, {
      BusinessModel model = BusinessModel.doterra,
    }) {
      saved = 0;
      return pumpFormHarness(
        tester,
        people: FakePeopleRepository(),
        activities: activities,
        account: Account(
          firstName: 'Pauline',
          email: 'p@example.com',
          businessModel: model,
        ),
        open: (context) => showLogOwnOrder(context, onSaved: () => saved++),
        result: (_) {},
      );
    }

    testWidgets('an order, no kinds to pick, amount required', (tester) async {
      await openOwn(tester);

      expect(find.text('Your own order'), findsOneWidget);
      expect(find.byType(ChoiceChip), findsNothing);
      await save(tester);
      expect(find.text('Enter the amount.'), findsOneWidget);
      expect(activities.store, isEmpty);

      await tester.enterText(field('Amount'), '100');
      await tester.enterText(field('Note'), 'For the house');
      await save(tester);

      final order = activities.store.single;
      expect(order.personId, isNull);
      expect(order.kind, ActivityKind.order);
      expect(order.amount, 100);
      expect(order.text, 'For the house');
      expect(saved, 1);
      expect(find.text('Your own order'), findsNothing);
    });

    testWidgets('a failed save keeps the sheet and the amount', (tester) async {
      await openOwn(tester);
      activities.failWith = PeopleFailure.network;

      await tester.enterText(field('Amount'), '100');
      await save(tester);

      expect(find.text('Your own order'), findsOneWidget);
      expect(
        tester.widget<TextFormField>(field('Amount')).controller!.text,
        '100',
      );
      expect(saved, 0);
    });

    testWidgets('Other: no unit', (tester) async {
      await openOwn(tester, model: BusinessModel.other);

      expect(find.text('PV'), findsNothing);
    });
  });
```

- [ ] **Step 3: Run them**

Run: `flutter test test/features/contacts/presentation/log_activity_sheet_test.dart`
Expected: compile error, `showLogOwnOrder` isn't defined.

- [ ] **Step 4: Implement**

`log_activity_sheet.dart`:

```dart
Future<void> showLogActivity(BuildContext context, Person person) =>
    LoomiaDialog.show<void>(context, (_) => _LogActivityForm(person: person));

/// The user's own order, from Goals: Order only, with an amount. [onSaved]
/// runs once it is saved, before the sheet closes.
Future<void> showLogOwnOrder(
  BuildContext context, {
  required VoidCallback onSaved,
}) => LoomiaDialog.show<void>(
  context,
  (_) => _LogActivityForm(onSaved: onSaved),
);
```

`_LogActivityForm({this.person, this.onSaved})`, with `final Person? person;` (null is an own order) and `final VoidCallback? onSaved;`. In the state:
- `late ActivityKind _kind = widget.person == null ? ActivityKind.order : ActivityKind.note;`
- `_submit` builds the draft as before, then:

```dart
      final person = widget.person;
      if (person == null) {
        await ref.read(activityRepositoryProvider).addOwnOrder(draft);
        widget.onSaved?.call();
      } else {
        await ref.read(historyProvider(person.id).notifier).add(draft);
      }
```

- `build`:
  - `final person = widget.person;` and `if (person != null) ref.watch(historyProvider(person.id));`.
  - The title is `person == null ? l10n.logOwnOrderTitle : l10n.logTitle(firstName(person))`.
  - The kind `Wrap` only shows `if (person != null)`.
  - The amount validator, when the field is empty, returns `person == null ? l10n.logOwnOrderAmountRequired : null` instead of `null`.
- The `text` field's validator already lets an order through with an amount, and its empty-text branch reads `_amount`, so it doesn't change.

Import `package:loomia/features/contacts/data/activity_repository.dart`.

- [ ] **Step 5: Run them**

Run: `flutter test test/features/contacts && flutter analyze`
Expected: all pass, "No issues found!".

- [ ] **Step 6: Commit**

```bash
git add lib/l10n/app_en.arb lib/features/contacts test/features/contacts
git commit -m "feat(goals): log my own order"
```

---
### Task 3: Goals — the button and the month's orders

**Files:**
- Modify: `lib/features/goals/presentation/goals_controller.dart` (`ordersProvider`, `refreshOrders`)
- Create: `lib/features/goals/presentation/orders_sheet.dart`
- Modify: `lib/features/goals/presentation/goals_page.dart` (`onLogOrder`, `onOrders`, the button, the card tap)
- Modify: `lib/features/goals/presentation/goals_preview.dart` (pass the two callbacks)
- Modify: `docs/design/screens.md` §5 (the Built paragraph)
- Test: `test/features/goals/presentation/orders_sheet_test.dart` (create), `goals_page_test.dart` (append), `test/app/shell/app_shell_test.dart` (append)

**Interfaces:**
- Consumes: `showLogOwnOrder` (Task 2); `ordersIn`, `delete`, `MonthOrder` (Task 1); `activityTitle`, `dayLabel`, `peopleFailureCopy` (`people_copy.dart`); `confirmDestructive`, `LoomiaDialog`, `ActivityItem`; `historyProvider`, `peopleProvider`, `accountProvider`.
- Produces:
  - `final ordersProvider = FutureProvider.autoDispose.family<List<MonthOrder>, DateTime>(...)`;
  - `void refreshOrders(ProviderContainer container)`, which invalidates `goalsProvider` and `ordersProvider`;
  - `Future<void> showOrders(BuildContext context, DateTime month)`;
  - `GoalsView` gains `required VoidCallback onLogOrder` and `required VoidCallback onOrders`.

- [ ] **Step 1: Write the failing tests**

In `goals_page_test.dart`, give `pumpGoals` two more counters and pass them:

```dart
var orders = 0;
var logs = 0;
```

Reset both in `pumpGoals`, and add `onLogOrder: () => logs++, onOrders: () => orders++,` to its `GoalsView`. Then append inside `main()`:

```dart
  testWidgets('the card opens the orders; the button logs one', (
    tester,
  ) async {
    await pumpGoals(tester, AsyncData(month(plan: full, progress: progress)));

    await tester.tap(find.text('Own volume'));
    expect(orders, 1);
    await tester.scrollUntilVisible(find.text('Log my own order'), 200);
    await tester.tap(find.text('Log my own order'));
    expect(logs, 1);
  });
```

`test/features/goals/presentation/orders_sheet_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:loomia/core/business_model/business_model.dart';
import 'package:loomia/features/auth/domain/account.dart';
import 'package:loomia/features/contacts/domain/activity.dart';
import 'package:loomia/features/contacts/domain/people_failure.dart';
import 'package:loomia/features/goals/presentation/orders_sheet.dart';
import 'package:material_ui/material_ui.dart';

import '../../contacts/fake_activity_repository.dart';
import '../../contacts/fake_people_repository.dart';
import '../../contacts/presentation/form_harness.dart';

void main() {
  final now = DateTime.now();
  final thisMonth = DateTime(now.year, now.month);
  late FakeActivityRepository activities;

  Activity order(String id, String? personId, double amount, int day) =>
      Activity(
        id: id,
        personId: personId,
        kind: ActivityKind.order,
        happenedOn: DateTime(now.year, now.month, day),
        amount: amount,
        createdAt: DateTime.utc(now.year, now.month, day, 12),
      );

  setUp(() {
    activities = FakeActivityRepository([
      order('o1', 'p1', 100, 1),
      order('o2', null, 80, 2),
      // Last month: not listed.
      Activity(
        id: 'o3',
        personId: null,
        kind: ActivityKind.order,
        happenedOn: DateTime(now.year, now.month - 1, 1),
        amount: 50,
        createdAt: DateTime.utc(now.year, now.month - 1, 1, 12),
      ),
    ])..names['p1'] = 'Marie Dupont';
  });

  Future<void> open(
    WidgetTester tester, {
    BusinessModel model = BusinessModel.doterra,
  }) => pumpFormHarness(
    tester,
    people: FakePeopleRepository(),
    activities: activities,
    account: Account(
      firstName: 'Pauline',
      email: 'p@example.com',
      businessModel: model,
    ),
    open: (context) => showOrders(context, thisMonth),
    result: (_) {},
  );

  testWidgets("this month's orders, own and contacts', latest first", (
    tester,
  ) async {
    await open(tester);

    expect(find.textContaining('Orders in'), findsOneWidget);
    expect(find.text('Order · 100 PV'), findsOneWidget);
    expect(find.text('Order · 80 PV'), findsOneWidget);
    expect(find.text('Order · 50 PV'), findsNothing);
    expect(find.textContaining('Marie Dupont'), findsOneWidget);
    expect(find.textContaining('Your own order'), findsOneWidget);
    expect(
      tester.getTopLeft(find.text('Order · 80 PV')).dy,
      lessThan(tester.getTopLeft(find.text('Order · 100 PV')).dy),
    );
  });

  testWidgets('an order is deleted once confirmed', (tester) async {
    await open(tester);

    await tester.tap(find.byTooltip('Delete this order').first);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
    await tester.pumpAndSettle();

    expect(activities.calls, contains('delete(o2)'));
    expect(find.text('Order · 80 PV'), findsNothing);
    expect(find.text('Order · 100 PV'), findsOneWidget);
  });

  testWidgets('a failed delete keeps the order and says why', (tester) async {
    await open(tester);
    activities.failWith = PeopleFailure.network;

    await tester.tap(find.byTooltip('Delete this order').first);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
    await tester.pumpAndSettle();

    expect(find.text('Order · 80 PV'), findsOneWidget);
    expect(find.byType(SnackBar), findsOneWidget);
  });

  testWidgets('no orders yet', (tester) async {
    activities = FakeActivityRepository();
    await open(tester);

    expect(find.text('No orders yet this month.'), findsOneWidget);
  });

  testWidgets('Other: no unit', (tester) async {
    await open(tester, model: BusinessModel.other);

    expect(find.text('Order · 100'), findsOneWidget);
    expect(find.textContaining('PV'), findsNothing);
  });
}
```

`confirmDestructive` draws its action as a `FilledButton` labelled with `historyDeleteConfirm` ("Delete").

In `test/app/shell/app_shell_test.dart`, append:

```dart
  testWidgets('an own order from Goals counts at once', (tester) async {
    final now = DateTime.now();
    final goals = FakeGoalsRepository(
      plans: [MonthPlan(month: DateTime(now.year, now.month))],
    );
    final activities = FakeActivityRepository();
    await pumpLoomia(
      tester,
      size: const Size(390, 844),
      goals: goals,
      activities: activities,
    );
    await tester.tap(find.text('Goals'));
    await tester.pumpAndSettle();
    final loads = goals.calls.where((call) => call == 'plans()').length;

    await tester.scrollUntilVisible(find.text('Log my own order'), 200);
    await tester.tap(find.text('Log my own order'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.descendant(
        of: find.widgetWithText(LabeledField, 'Amount'),
        matching: find.byType(TextFormField),
      ),
      '100',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();

    expect(activities.store.single.personId, isNull);
    expect(goals.calls.where((call) => call == 'plans()').length, loads + 1);
  });
```

with imports for `month_plan.dart`, `labeled_field.dart`, `fake_goals_repository.dart` and `fake_activity_repository.dart`.

- [ ] **Step 2: Run them**

Run: `flutter test test/features/goals test/app/shell`
Expected: compile errors, since `orders_sheet.dart` doesn't exist and `GoalsView` has no `onLogOrder`/`onOrders`.

- [ ] **Step 3: Implement**

`goals_controller.dart`, add:

```dart
/// [month]'s orders for the sheet the volume card opens.
final ordersProvider = FutureProvider.autoDispose
    .family<List<MonthOrder>, DateTime>(
      (ref, month) => ref.watch(activityRepositoryProvider).ordersIn(month),
      retry: (error, _) => null,
    );

/// After an order is added or removed: the month and its orders recount.
/// The container, not a widget's ref: the sheet may be closing.
void refreshOrders(ProviderContainer container) {
  container
    ..invalidate(goalsProvider)
    ..invalidate(ordersProvider);
}
```

`lib/features/goals/presentation/orders_sheet.dart`:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loomia/app/theme/app_colors.dart';
import 'package:loomia/core/business_model/business_model.dart';
import 'package:loomia/core/ui/activity_item.dart';
import 'package:loomia/core/ui/loomia_dialog.dart';
import 'package:loomia/core/ui/pick_day.dart';
import 'package:loomia/features/auth/data/auth_repository.dart';
import 'package:loomia/features/contacts/data/activity_repository.dart';
import 'package:loomia/features/contacts/domain/activity.dart';
import 'package:loomia/features/contacts/domain/people_failure.dart';
import 'package:loomia/features/contacts/presentation/history_controller.dart';
import 'package:loomia/features/contacts/presentation/people_controller.dart';
import 'package:loomia/features/contacts/presentation/people_copy.dart';
import 'package:loomia/features/goals/presentation/goals_controller.dart';
import 'package:loomia/l10n/app_localizations.dart';
import 'package:material_ui/material_ui.dart';

/// [month]'s orders, contacts' and own, each deletable: a sheet on mobile, a
/// dialog elsewhere.
Future<void> showOrders(BuildContext context, DateTime month) =>
    LoomiaDialog.show<void>(context, (_) => _Orders(month));

class _Orders extends ConsumerWidget {
  const _Orders(this.month);

  final DateTime month;

  Future<void> _delete(
    BuildContext context,
    WidgetRef ref,
    MonthOrder entry,
  ) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final container = ProviderScope.containerOf(context, listen: false);
    final confirmed = await confirmDestructive(
      context,
      title: l10n.historyDeleteTitle,
      action: l10n.historyDeleteConfirm,
    );
    if (!confirmed) return;
    try {
      await container.read(activityRepositoryProvider).delete(entry.order.id);
    } on PeopleFailure catch (failure) {
      messenger.showSnackBar(
        SnackBar(content: Text(peopleFailureCopy(l10n, failure))),
      );
      return;
    }
    refreshOrders(container);
    // The same entry was in that person's history, and their last contact
    // may move.
    if (entry.order.personId case final personId?) {
      container.invalidate(historyProvider(personId));
    }
    container.invalidate(
      peopleProvider(container.read(accountProvider)?.email),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final material = MaterialLocalizations.of(context);
    final colors = LoomiaColors.of(context);
    final model =
        ref.watch(accountProvider)?.businessModel ?? BusinessModel.other;
    final orders = ref.watch(ordersProvider(month));
    final day = today();
    Widget muted(String text) => Text(
      text,
      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
        color: colors.textMuted,
      ),
    );

    return LoomiaDialog(
      title: l10n.ordersTitle(month),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(material.closeButtonLabel),
        ),
      ],
      child: switch (orders) {
        AsyncValue(value: final entries?) when entries.isEmpty => muted(
          l10n.ordersEmpty,
        ),
        AsyncValue(value: final entries?) => Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final (index, entry) in entries.indexed)
              Row(
                children: [
                  Expanded(
                    child: ActivityItem(
                      title: activityTitle(l10n, entry.order, model),
                      meta: l10n.historyMeta(
                        dayLabel(l10n, entry.order.day, day),
                        entry.personName ?? l10n.ordersOwn,
                      ),
                      showRailLine: index < entries.length - 1,
                    ),
                  ),
                  IconButton(
                    tooltip: l10n.ordersRemove,
                    onPressed: () => _delete(context, ref, entry),
                    icon: const Icon(Icons.delete_outline),
                  ),
                ],
              ),
          ],
        ),
        AsyncError() => Row(
          children: [
            Expanded(child: muted(l10n.ordersLoadFailed)),
            TextButton(
              onPressed: () => ref.invalidate(ordersProvider(month)),
              child: Text(l10n.contactsRetry),
            ),
          ],
        ),
        _ => const Center(child: CircularProgressIndicator()),
      },
    );
  }
}
```

`LoomiaDialog` scrolls its child, so a long list fits. `historyMeta` is "{day} · {kind}", reused here for "September 2 · Marie Dupont". Its description in `app_en.arb` says "kind": widen it to "a label after the day: the kind of entry, or whose order it is".

`goals_page.dart`:
- `GoalsView` gains `required this.onLogOrder, required this.onOrders` (`VoidCallback`s).
- In `_dashboard`, the `GoalCard` gets `onTap: onOrders`.
- Before the `Change the plan` `Align`:

```dart
      const SizedBox(height: AppSpacing.md),
      FilledButton.tonalIcon(
        onPressed: onLogOrder,
        icon: const Icon(Icons.add_rounded),
        label: Text(l10n.goalLogOwnOrder),
      ),
```

- `GoalsPage` passes:

```dart
      onLogOrder: () {
        final container = ProviderScope.containerOf(context, listen: false);
        unawaited(
          showLogOwnOrder(context, onSaved: () => refreshOrders(container)),
        );
      },
      onOrders: () => unawaited(
        showOrders(context, DateTime(today().year, today().month)),
      ),
```

  It needs `dart:async`, `log_activity_sheet.dart` and `orders_sheet.dart`. `FilledButton.tonalIcon` stretches in the `ListView`, like the Figma.

`goals_preview.dart`: add `onLogOrder: () {}, onOrders: () {},` to the `GoalsView`.

`docs/design/screens.md` §5 Built paragraph: replace "Own orders and the month's orders list are [#165](…); closing" with "`Log my own order` opens Your own order (an amount, no person), and tapping the volume card lists the month's orders, contacts' and own, each deletable ([#165](https://github.com/paulthvt/loomia/issues/165)). Closing".

- [ ] **Step 4: Run them**

Run: `flutter test test/features/goals test/app/shell && flutter analyze`
Expected: all pass, "No issues found!".

- [ ] **Step 5: Gate and commit**

Run: `dart format . && flutter analyze && flutter test`

```bash
git add lib test docs/design/screens.md
git commit -m "feat(goals): the month's orders, and an own order from Goals"
```

After the push, regenerate goldens through CI (`goals_mobile_*`, `goals_desktop_light` change).

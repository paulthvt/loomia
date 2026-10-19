import 'package:flutter_test/flutter_test.dart';
import 'package:loomia/core/business_model/business_model.dart';
import 'package:loomia/core/ui/form_error.dart';
import 'package:loomia/core/ui/loomia_dialog.dart';
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
    // Inside the sheet: on a phone a snack bar would sit under it.
    expect(
      find.descendant(
        of: find.byType(LoomiaDialog),
        matching: find.byType(FormError),
      ),
      findsOneWidget,
    );
  });

  testWidgets('tapping an order edits it, and the list shows the change', (
    tester,
  ) async {
    await open(tester);

    await tester.tap(find.text('Order · 80 PV'));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(LoomiaDialog, 'Edit'), findsOneWidget);
    // An order stays an order: no kind to pick.
    expect(find.byType(ChoiceChip), findsNothing);

    await tester.enterText(find.widgetWithText(TextFormField, '80'), '95');
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();

    expect(activities.calls, contains('update(o2)'));
    expect(find.widgetWithText(LoomiaDialog, 'Edit'), findsNothing);
    expect(find.text('Order · 95 PV'), findsOneWidget);
    expect(find.text('Order · 80 PV'), findsNothing);
  });

  testWidgets("a contact's order needs no amount, like in their history", (
    tester,
  ) async {
    activities = FakeActivityRepository([
      Activity(
        id: 'o4',
        personId: 'p1',
        kind: ActivityKind.order,
        happenedOn: DateTime(now.year, now.month),
        text: 'Lavender',
        createdAt: DateTime.utc(now.year, now.month, 1, 12),
      ),
    ])..names['p1'] = 'Marie Dupont';
    await open(tester);

    await tester.tap(find.textContaining('Lavender'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();

    expect(activities.calls, contains('update(o4)'));
  });

  testWidgets('Delete in the edit form confirms, then deletes', (tester) async {
    await open(tester);

    await tester.tap(find.text('Order · 80 PV'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'Delete'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
    await tester.pumpAndSettle();

    expect(activities.calls, contains('delete(o2)'));
    expect(find.text('Order · 80 PV'), findsNothing);
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

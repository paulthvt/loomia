import 'package:cupertino_ui/cupertino_ui.dart' show CupertinoDatePicker;
import 'package:flutter_test/flutter_test.dart';
import 'package:loomia/core/business_model/business_model.dart';
import 'package:loomia/core/ui/labeled_field.dart';
import 'package:loomia/features/auth/domain/account.dart';
import 'package:loomia/features/contacts/domain/activity.dart';
import 'package:loomia/features/contacts/domain/people_failure.dart';
import 'package:loomia/features/contacts/domain/person.dart';
import 'package:loomia/features/contacts/presentation/log_activity_sheet.dart';
import 'package:material_ui/material_ui.dart';

import '../fake_activity_repository.dart';
import '../fake_people_repository.dart';
import 'form_harness.dart';

final _claire = Person(
  id: 'p1',
  name: 'Claire Petit',
  stage: Stage.customer,
  stageSince: DateTime.utc(2026, 3, 4),
);

DateTime _today() {
  final now = DateTime.now();
  return DateTime(now.year, now.month, now.day);
}

void main() {
  late FakeActivityRepository activities;

  setUp(() => activities = FakeActivityRepository());

  Future<void> open(
    WidgetTester tester, {
    BusinessModel model = BusinessModel.doterra,
  }) => pumpFormHarness(
    tester,
    people: FakePeopleRepository([_claire]),
    activities: activities,
    account: Account(
      firstName: 'Pauline',
      email: 'p@example.com',
      businessModel: model,
    ),
    open: (context) => showLogActivity(context, _claire),
    result: (_) {},
  );

  Finder field(String label) => find.descendant(
    of: find.widgetWithText(LabeledField, label),
    matching: find.byType(TextFormField),
  );

  Future<void> save(WidgetTester tester) async {
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();
  }

  testWidgets('titled with the first name, Note and today preset', (
    tester,
  ) async {
    await open(tester);

    expect(find.text('Log something with Claire'), findsOneWidget);
    expect(
      tester
          .widget<ChoiceChip>(find.widgetWithText(ChoiceChip, 'Note'))
          .selected,
      isTrue,
    );
    expect(find.textContaining('Today, '), findsOneWidget);
  });

  testWidgets(
    'on a phone with the keyboard up: no overflow, buttons in a row',
    (tester) async {
      tester.view
        ..devicePixelRatio = 1
        ..physicalSize = const Size(390, 844)
        // Roughly a phone keyboard with its suggestion bar.
        ..viewInsets = const FakeViewPadding(bottom: 430);
      addTearDown(tester.view.reset);
      await open(tester);

      expect(tester.takeException(), isNull);
      final cancel = tester.getRect(find.widgetWithText(TextButton, 'Cancel'));
      final save = tester.getRect(find.widgetWithText(FilledButton, 'Save'));
      expect(cancel.center.dy, save.center.dy);
      expect(cancel.right, lessThan(save.left));
      expect(save.bottom, lessThanOrEqualTo(844 - 430));
    },
  );

  testWidgets('nothing written, or only spaces, is refused', (tester) async {
    await open(tester);

    await tester.enterText(find.byType(TextFormField), '   ');
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();

    expect(find.text('Say what happened.'), findsOneWidget);
    expect(activities.calls, isNot(contains('add(p1)')));
  });

  testWidgets('saves the kind, the day and the text, then closes', (
    tester,
  ) async {
    await open(tester);

    await tester.tap(find.widgetWithText(ChoiceChip, 'Call'));
    await tester.enterText(find.byType(TextFormField), 'Asked about the cream');
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();

    final saved = activities.store.single;
    expect(saved.kind, ActivityKind.call);
    expect(saved.happenedOn, _today());
    expect(saved.text, 'Asked about the cream');
    expect(find.text('Log something with Claire'), findsNothing);
  });

  testWidgets('a failed save says so and keeps what was typed', (tester) async {
    await open(tester);
    activities.failWith = PeopleFailure.network;

    await tester.enterText(find.byType(TextFormField), 'Asked about the cream');
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();

    expect(
      find.text("Couldn't save. Check your connection and try again."),
      findsOneWidget,
    );
    expect(find.text('Asked about the cream'), findsOneWidget);
    expect(find.text('Log something with Claire'), findsOneWidget);
  });

  testWidgets('the calendar ends today; a picked day is saved', (tester) async {
    await open(tester);

    await tester.tap(find.textContaining('Today, '));
    await tester.pumpAndSettle();
    expect(
      tester.widget<DatePickerDialog>(find.byType(DatePickerDialog)).lastDate,
      _today(),
    );
    await tester.tap(find.text('1'));
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField), 'Met at the market');
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();

    final today = _today();
    expect(
      activities.store.single.happenedOn,
      DateTime(today.year, today.month, 1),
    );
  });

  testWidgets('iOS: a wheel that cannot go past today', (tester) async {
    await open(tester);

    await tester.tap(find.textContaining('Today, '));
    await tester.pumpAndSettle();
    final wheel = tester.widget<CupertinoDatePicker>(
      find.byType(CupertinoDatePicker),
    );
    expect(wheel.maximumDate, _today());
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();

    expect(find.byType(CupertinoDatePicker), findsNothing);
    expect(find.textContaining('Today, '), findsOneWidget);
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

  testWidgets('Step is never offered: the app writes those', (tester) async {
    await open(tester);

    expect(find.widgetWithText(ChoiceChip, 'Step'), findsNothing);
    expect(find.widgetWithText(ChoiceChip, 'Note'), findsOneWidget);
  });

  testWidgets('Order asks for an amount in PV and a note', (tester) async {
    await open(tester);
    expect(find.text('Amount'), findsNothing);

    await tester.tap(find.widgetWithText(ChoiceChip, 'Order'));
    await tester.pumpAndSettle();

    expect(field('Amount'), findsOneWidget);
    expect(find.text('PV'), findsOneWidget);
    expect(
      tester.getSemantics(field('Amount')),
      isSemantics(label: 'Amount', hint: 'PV'),
    );
    expect(field('Note'), findsOneWidget);
    expect(find.text('What happened'), findsNothing);
  });

  testWidgets('Other shows no unit', (tester) async {
    await open(tester, model: BusinessModel.other);
    await tester.tap(find.widgetWithText(ChoiceChip, 'Order'));
    await tester.pumpAndSettle();

    expect(field('Amount'), findsOneWidget);
    expect(find.text('PV'), findsNothing);
  });

  testWidgets('an amount alone saves', (tester) async {
    await open(tester);
    await tester.tap(find.widgetWithText(ChoiceChip, 'Order'));
    await tester.pumpAndSettle();

    await tester.enterText(field('Amount'), '100');
    await save(tester);

    final saved = activities.store.single;
    expect(saved.kind, ActivityKind.order);
    expect(saved.amount, 100);
    expect(saved.text, isNull);
  });

  testWidgets('an amount and a note save together', (tester) async {
    await open(tester);
    await tester.tap(find.widgetWithText(ChoiceChip, 'Order'));
    await tester.pumpAndSettle();

    await tester.enterText(field('Amount'), '12.5');
    await tester.enterText(field('Note'), 'Wild Orange');
    await save(tester);

    final saved = activities.store.single;
    expect(saved.amount, 12.5);
    expect(saved.text, 'Wild Orange');
  });

  testWidgets('an order with neither is refused', (tester) async {
    await open(tester);
    await tester.tap(find.widgetWithText(ChoiceChip, 'Order'));
    await tester.pumpAndSettle();

    await save(tester);

    expect(find.text('Add an amount or a note.'), findsOneWidget);
    expect(activities.calls, isNot(contains('add(p1)')));
  });

  testWidgets('a bad amount is refused', (tester) async {
    await open(tester);
    await tester.tap(find.widgetWithText(ChoiceChip, 'Order'));
    await tester.pumpAndSettle();

    for (final typed in ['6,00', '0', 'abc']) {
      await tester.enterText(field('Amount'), typed);
      await save(tester);
      expect(
        find.text('Use a number above 0, like 100 or 99.5.'),
        findsOneWidget,
        reason: typed,
      );
    }
    expect(activities.calls, isNot(contains('add(p1)')));
  });

  testWidgets('6,000 in English is six thousand', (tester) async {
    await open(tester);
    await tester.tap(find.widgetWithText(ChoiceChip, 'Order'));
    await tester.pumpAndSettle();

    await tester.enterText(field('Amount'), '6,000');
    await save(tester);

    expect(activities.store.single.amount, 6000);
  });

  testWidgets('an amount typed under Order is dropped for another kind', (
    tester,
  ) async {
    await open(tester);
    await tester.tap(find.widgetWithText(ChoiceChip, 'Order'));
    await tester.pumpAndSettle();
    await tester.enterText(field('Amount'), '100');

    await tester.tap(find.widgetWithText(ChoiceChip, 'Call'));
    await tester.pumpAndSettle();
    await tester.enterText(field('What happened'), 'Called back');
    await save(tester);

    final saved = activities.store.single;
    expect(saved.kind, ActivityKind.call);
    expect(saved.amount, isNull);
  });

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

  group('edit', () {
    Future<Object?> openEdit(WidgetTester tester, Activity activity) async {
      Object? resolved;
      await pumpFormHarness(
        tester,
        people: FakePeopleRepository([_claire])..activities = activities,
        activities: activities,
        account: const Account(
          firstName: 'Pauline',
          email: 'p@example.com',
          businessModel: BusinessModel.doterra,
        ),
        open: (context) => showEditActivity(context, _claire, activity),
        result: (value) => resolved = value,
      );
      return resolved;
    }

    testWidgets('a note opens filled in, without kinds, and saves', (
      tester,
    ) async {
      final note = Activity(
        id: 'a1',
        personId: 'p1',
        kind: ActivityKind.note,
        happenedOn: DateTime(2026, 9, 10),
        text: 'Asked abot the cream',
        createdAt: DateTime.utc(2026, 9, 10, 12),
      );
      activities.store.add(note);
      await openEdit(tester, note);

      expect(find.text('Edit'), findsOneWidget);
      expect(find.byType(ChoiceChip), findsNothing);
      await tester.enterText(field('What happened'), 'Asked about the cream');
      await save(tester);

      expect(activities.calls.last, 'update(a1)');
      expect(activities.store.single.text, 'Asked about the cream');
      expect(activities.store.single.happenedOn, DateTime(2026, 9, 10));
    });

    testWidgets('an order keeps its amount, written plainly', (tester) async {
      final order = Activity(
        id: 'a1',
        personId: 'p1',
        kind: ActivityKind.order,
        happenedOn: DateTime(2026, 9, 10),
        amount: 40,
        createdAt: DateTime.utc(2026, 9, 10, 12),
      );
      activities.store.add(order);
      await openEdit(tester, order);

      expect(find.text('40'), findsOneWidget);
      await tester.enterText(field('Amount'), '55.5');
      await save(tester);

      expect(activities.store.single.amount, 55.5);
    });

    testWidgets("a day after the device's today still opens the calendar", (
      tester,
    ) async {
      // Logged on a device a day ahead (another time zone, a clock change).
      final ahead = _today().add(const Duration(days: 1));
      final note = Activity(
        id: 'a1',
        personId: 'p1',
        kind: ActivityKind.note,
        happenedOn: ahead,
        text: 'Note',
        createdAt: DateTime.utc(2026, 9, 10, 12),
      );
      activities.store.add(note);
      await openEdit(tester, note);

      await tester.tap(find.byIcon(Icons.calendar_today_outlined));
      await tester.pumpAndSettle();

      expect(find.byType(DatePickerDialog), findsOneWidget);
    });

    testWidgets('a step entry saves its new text', (tester) async {
      final step = Activity(
        id: 'a1',
        personId: 'p1',
        kind: ActivityKind.step,
        happenedOn: DateTime(2026, 9, 10),
        text: 'Thank them',
        createdAt: DateTime.utc(2026, 9, 10, 12),
      );
      activities.store.add(step);
      await openEdit(tester, step);

      await tester.enterText(field('What happened'), 'Thanked them by phone');
      await save(tester);

      expect(activities.store.single.kind, ActivityKind.step);
      expect(activities.store.single.text, 'Thanked them by phone');
    });

    testWidgets('Delete hands back to the history', (tester) async {
      final note = Activity(
        id: 'a1',
        personId: 'p1',
        kind: ActivityKind.note,
        happenedOn: DateTime(2026, 9, 10),
        text: 'Note',
        createdAt: DateTime.utc(2026, 9, 10, 12),
      );
      activities.store.add(note);
      Object? resolved;
      await pumpFormHarness(
        tester,
        people: FakePeopleRepository([_claire]),
        activities: activities,
        open: (context) => showEditActivity(context, _claire, note),
        result: (value) => resolved = value,
      );

      await tester.tap(find.widgetWithText(TextButton, 'Delete'));
      await tester.pumpAndSettle();

      expect(resolved, isTrue);
      expect(activities.calls, isNot(contains('delete(a1)')));
    });

    testWidgets('a stage entry edits only its day, which is the since', (
      tester,
    ) async {
      activities.recordStage('p1', Stage.customer);
      final stage = activities.store.single;
      final people = FakePeopleRepository([_claire])..activities = activities;
      await pumpFormHarness(
        tester,
        people: people,
        activities: activities,
        open: (context) => showEditActivity(context, _claire, stage),
        result: (_) {},
      );

      expect(find.byType(TextFormField), findsNothing);
      expect(find.widgetWithText(TextButton, 'Delete'), findsNothing);
      await tester.tap(find.byIcon(Icons.calendar_today_outlined));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.edit_outlined));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).last, '09/01/2026');
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      await save(tester);

      expect(people.calls.last, 'setStageSince(p1)');
      expect(people.store['p1']!.stageSince, DateTime(2026, 9).toUtc());
      expect(activities.store.single.day, DateTime(2026, 9));
    });

    testWidgets('a stage entry saved on the same day writes nothing', (
      tester,
    ) async {
      activities.recordStage('p1', Stage.customer);
      final stage = activities.store.single;
      final people = FakePeopleRepository([_claire])..activities = activities;
      await pumpFormHarness(
        tester,
        people: people,
        activities: activities,
        open: (context) => showEditActivity(context, _claire, stage),
        result: (_) {},
      );

      await save(tester);

      expect(people.calls, isNot(contains('setStageSince(p1)')));
      expect(find.text('Edit'), findsNothing);
    });

    testWidgets("a stage entry's day starts at the stage before it", (
      tester,
    ) async {
      final customer = Activity(
        id: 'customer',
        personId: 'p1',
        kind: ActivityKind.stage,
        happenedOn: DateTime(2026, 9, 20),
        stage: Stage.customer,
        createdAt: DateTime(2026, 9, 20, 12).toUtc(),
      );
      final team = Activity(
        id: 'team',
        personId: 'p1',
        kind: ActivityKind.stage,
        happenedOn: DateTime(2026, 9, 25),
        stage: Stage.team,
        createdAt: DateTime(2026, 9, 25, 12).toUtc(),
      );
      activities.store.addAll([customer, team]);
      await pumpFormHarness(
        tester,
        people: FakePeopleRepository([_claire])..activities = activities,
        activities: activities,
        open: (context) => showEditActivity(context, _claire, team),
        result: (_) {},
      );

      await tester.tap(find.byIcon(Icons.calendar_today_outlined));
      await tester.pumpAndSettle();

      expect(
        tester
            .widget<DatePickerDialog>(find.byType(DatePickerDialog))
            .firstDate,
        DateTime(2026, 9, 20),
      );
    });
  });
}

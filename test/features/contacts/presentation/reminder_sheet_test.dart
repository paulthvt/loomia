import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:loomia/core/ui/labeled_field.dart';
import 'package:loomia/core/ui/pick_day.dart';
import 'package:loomia/features/contacts/domain/people_failure.dart';
import 'package:loomia/features/contacts/domain/person.dart';
import 'package:loomia/features/contacts/presentation/reminder_sheet.dart';
import 'package:loomia/features/workflows/domain/progress.dart';
import 'package:material_ui/material_ui.dart';

import '../fake_people_repository.dart';
import 'form_harness.dart';

final _claire = Person(
  id: 'p1',
  name: 'Claire Petit',
  stage: Stage.customer,
  stageSince: DateTime.utc(2026, 3, 4),
);

String _written(DateTime day) =>
    (day.year == today().year
            ? DateFormat.MMMMEEEEd('en')
            : DateFormat.yMMMMEEEEd('en'))
        .format(day);

bool _selected(WidgetTester tester, String chip) =>
    tester.widget<ChoiceChip>(find.widgetWithText(ChoiceChip, chip)).selected;

void main() {
  late FakePeopleRepository people;

  Future<void> open(WidgetTester tester, {Reminder? editing}) async {
    await pumpFormHarness(
      tester,
      people: people,
      open: (context) => showReminder(context, _claire, editing: editing),
      result: (_) {},
    );
  }

  final what = find.descendant(
    of: find.widgetWithText(LabeledField, 'What'),
    matching: find.byType(TextFormField),
  );

  Future<void> save(WidgetTester tester) async {
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();
  }

  setUp(() => people = FakePeopleRepository([_claire]));

  testWidgets('a new one: tomorrow, then In a week; saved with its text', (
    tester,
  ) async {
    await open(tester);

    expect(find.text('Remind me'), findsOneWidget);
    expect(_selected(tester, 'Tomorrow'), isTrue);
    expect(find.text(_written(addDays(today(), 1))), findsOneWidget);

    await tester.tap(find.text('In a week'));
    await tester.pumpAndSettle();
    expect(_selected(tester, 'In a week'), isTrue);
    expect(find.text(_written(addDays(today(), 7))), findsOneWidget);

    await tester.enterText(what, 'Call back about the diffuser');
    await save(tester);

    expect(people.calls, contains('addReminder(p1)'));
    expect(people.reminders['p1']!.single.text, 'Call back about the diffuser');
    expect(people.reminders['p1']!.single.dueOn, addDays(today(), 7));
    expect(find.text('Remind me'), findsNothing);
  });

  testWidgets('says what is missing and saves nothing', (tester) async {
    await open(tester);

    await save(tester);

    expect(find.text('Say what to do.'), findsOneWidget);
    expect(people.calls.where((call) => call.startsWith('add')), isEmpty);
  });

  testWidgets('edit: prefilled, Pick a day for a day no chip has; saves', (
    tester,
  ) async {
    final reminder = await people.addReminder(
      'p1',
      'Price list',
      addDays(today(), 5),
    );
    await open(tester, editing: reminder);

    expect(find.text('Edit reminder'), findsOneWidget);
    expect(find.text('Price list'), findsOneWidget);
    expect(_selected(tester, 'Pick a day'), isTrue);

    await tester.tap(find.text('In 2 weeks'));
    await tester.pumpAndSettle();
    await save(tester);

    expect(people.calls.last, 'updateReminder(${reminder.id})');
    expect(people.reminders['p1']!.single.dueOn, addDays(today(), 14));
  });

  testWidgets('Delete deletes it, no confirmation', (tester) async {
    final reminder = await people.addReminder('p1', 'Price list', today());
    await open(tester, editing: reminder);

    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();

    expect(people.calls.last, 'deleteReminder(${reminder.id})');
    expect(people.reminders['p1'], isEmpty);
    expect(find.text('Edit reminder'), findsNothing);
  });

  testWidgets('a failed save says so and stays open', (tester) async {
    await open(tester);
    people.failWith = PeopleFailure.network;

    await tester.enterText(what, 'Call back');
    await save(tester);

    expect(
      find.text("Couldn't save. Check your connection and try again."),
      findsOneWidget,
    );
    expect(find.text('Remind me'), findsOneWidget);
  });
}

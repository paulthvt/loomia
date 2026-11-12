import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:loomia/core/repeat/repeat.dart';
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

  group('Today (#486)', () {
    testWidgets('comes first, and saves today', (tester) async {
      await open(tester);
      final chips = tester
          .widgetList<ChoiceChip>(find.byType(ChoiceChip))
          .map((chip) => (chip.label as Text).data)
          .toList();
      expect(chips, [
        'Today',
        'Tomorrow',
        'In 3 days',
        'In a week',
        'In 2 weeks',
        'Pick a day',
      ]);

      await tester.tap(find.text('Today'));
      await tester.pumpAndSettle();
      await tester.enterText(what, 'Call back');
      await save(tester);

      expect(people.reminders['p1']!.single.dueOn, today());
    });

    testWidgets('a reminder due today selects it', (tester) async {
      final reminder = await people.addReminder('p1', 'Price list', today());
      await open(tester, editing: reminder);
      expect(_selected(tester, 'Today'), isTrue);
      expect(_selected(tester, 'Pick a day'), isFalse);
    });

    testWidgets('a late one selects Pick a day', (tester) async {
      final reminder = await people.addReminder(
        'p1',
        'Price list',
        addDays(today(), -2),
      );
      await open(tester, editing: reminder);
      expect(_selected(tester, 'Today'), isFalse);
      expect(_selected(tester, 'Pick a day'), isTrue);
    });
  });

  group('repeat (#486)', () {
    final repeatSwitch = find.widgetWithText(SwitchListTile, 'Repeat');

    Future<void> turnOn(WidgetTester tester) async {
      await tester.ensureVisible(repeatSwitch);
      await tester.tap(repeatSwitch);
      await tester.pumpAndSettle();
    }

    Future<void> pickUnit(WidgetTester tester, String unit) async {
      await tester.ensureVisible(
        find.byType(DropdownButtonFormField<RepeatUnit>),
      );
      await tester.tap(find.byType(DropdownButtonFormField<RepeatUnit>));
      await tester.pumpAndSettle();
      await tester.tap(find.text(unit).last);
      await tester.pumpAndSettle();
    }

    /// Monthly, from the 3rd of last month, due in five days.
    Future<Reminder> monthly() {
      final due = addDays(today(), 5);
      return people.addReminder(
        'p1',
        'Ask how the oils go',
        due,
        repeat: (
          every: 1,
          unit: RepeatUnit.month,
          from: DateTime(2026, 10, 3),
          until: null,
          scheduledOn: due,
        ),
      );
    }

    Future<void> moveToTomorrow(WidgetTester tester) async {
      await tester.ensureVisible(find.text('Tomorrow'));
      await tester.tap(find.text('Tomorrow'));
      await tester.pumpAndSettle();
      await save(tester);
    }

    testWidgets('saves a repeat counted from its day', (tester) async {
      await open(tester);
      expect(tester.widget<SwitchListTile>(repeatSwitch).value, isFalse);

      await tester.enterText(what, 'Ask how the oils go');
      await turnOn(tester);
      await pickUnit(tester, 'month');
      await save(tester);

      final saved = people.reminders['p1']!.single;
      final tomorrow = addDays(today(), 1);
      expect(saved.repeat?.unit, RepeatUnit.month);
      expect(saved.repeat?.every, 1);
      expect(saved.repeat?.from, tomorrow);
      expect(saved.repeat?.scheduledOn, tomorrow);
      expect(saved.dueOn, tomorrow);
    });

    testWidgets('moving the day, This reminder: postponed', (tester) async {
      final reminder = await monthly();
      await open(tester, editing: reminder);
      await moveToTomorrow(tester);

      expect(find.text('Change a repeating reminder'), findsOneWidget);
      await tester.tap(find.widgetWithText(FilledButton, 'Save').last);
      await tester.pumpAndSettle();

      final saved = people.reminders['p1']!.single;
      expect(saved.dueOn, addDays(today(), 1));
      expect(saved.repeat?.from, DateTime(2026, 10, 3));
      expect(saved.repeat?.scheduledOn, reminder.dueOn);
    });

    testWidgets('moving the day, following: the schedule moves', (
      tester,
    ) async {
      final reminder = await monthly();
      await open(tester, editing: reminder);
      await moveToTomorrow(tester);
      await tester.tap(find.text('This and following reminders'));
      await tester.tap(find.widgetWithText(FilledButton, 'Save').last);
      await tester.pumpAndSettle();

      final tomorrow = addDays(today(), 1);
      final saved = people.reminders['p1']!.single;
      expect(saved.repeat?.from, tomorrow);
      expect(saved.repeat?.scheduledOn, tomorrow);
    });

    testWidgets('a day past its end drops the end', (tester) async {
      final due = addDays(today(), 1);
      final reminder = await people.addReminder(
        'p1',
        'Ask how the oils go',
        due,
        repeat: (
          every: 1,
          unit: RepeatUnit.day,
          from: due,
          until: addDays(today(), 3),
          scheduledOn: due,
        ),
      );
      await open(tester, editing: reminder);
      await tester.ensureVisible(find.text('In a week'));
      await tester.tap(find.text('In a week'));
      await tester.pumpAndSettle();
      await save(tester);
      await tester.tap(find.widgetWithText(FilledButton, 'Save').last);
      await tester.pumpAndSettle();

      final saved = people.reminders['p1']!.single;
      expect(saved.dueOn, addDays(today(), 7));
      expect(saved.repeat?.until, isNull);
    });

    testWidgets('turning it off clears the repeat', (tester) async {
      final reminder = await monthly();
      await open(tester, editing: reminder);
      await turnOn(tester);
      await save(tester);

      expect(people.reminders['p1']!.single.repeat, isNull);
    });

    testWidgets('Delete, This reminder: skipped to its next day', (
      tester,
    ) async {
      final reminder = await monthly();
      await open(tester, editing: reminder);
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();

      expect(find.text('Delete a repeating reminder'), findsOneWidget);
      await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
      await tester.pumpAndSettle();

      expect(people.calls, contains('skipReminder(${reminder.id})'));
      expect(find.text('Edit reminder'), findsNothing);
    });

    testWidgets('Delete, following: it goes', (tester) async {
      final reminder = await monthly();
      await open(tester, editing: reminder);
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('This and following reminders'));
      await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
      await tester.pumpAndSettle();

      expect(people.calls.last, 'deleteReminder(${reminder.id})');
      expect(people.reminders['p1'], isEmpty);
    });
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

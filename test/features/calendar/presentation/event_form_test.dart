import 'package:flutter_test/flutter_test.dart';
import 'package:loomia/core/ui/contact_row.dart';
import 'package:loomia/core/ui/form_error.dart';
import 'package:loomia/core/ui/labeled_field.dart';
import 'package:loomia/features/calendar/domain/calendar_event.dart';
import 'package:loomia/features/calendar/presentation/event_form.dart';
import 'package:loomia/features/calendar/presentation/scope_dialog.dart';
import 'package:loomia/features/contacts/domain/people_failure.dart';
import 'package:loomia/features/contacts/domain/person.dart';
import 'package:loomia/features/workflows/domain/event_workflow.dart';
import 'package:material_ui/material_ui.dart';

import '../../contacts/fake_people_repository.dart';
import '../../workflows/fake_event_workflow_repository.dart';
import '../calendar_harness.dart';
import '../fake_event_repository.dart';

Finder _field(String label) => find.descendant(
  of: find.widgetWithText(LabeledField, label),
  matching: find.byType(TextFormField),
);

final _day = DateTime(2026, 10, 8);

void main() {
  group('shiftEnd (#461)', () {
    const t = TimeOfDay.new;

    test('keeps the length when the start moves', () {
      expect(
        shiftEnd(
          t(hour: 19, minute: 0),
          t(hour: 9, minute: 30),
          t(hour: 21, minute: 0),
        ),
        t(hour: 11, minute: 30),
      );
    });

    test('no end stays no end', () {
      expect(
        shiftEnd(t(hour: 19, minute: 0), t(hour: 9, minute: 0), null),
        isNull,
      );
    });

    test('an end not after the start becomes an hour', () {
      expect(
        shiftEnd(
          t(hour: 19, minute: 0),
          t(hour: 10, minute: 0),
          t(hour: 18, minute: 0),
        ),
        t(hour: 11, minute: 0),
      );
    });

    test('stops at 23:59 rather than passing midnight', () {
      expect(
        shiftEnd(
          t(hour: 19, minute: 0),
          t(hour: 23, minute: 30),
          t(hour: 21, minute: 0),
        ),
        t(hour: 23, minute: 59),
      );
    });
  });

  testWidgets('a new event on the day, 19:00 to 20:00, with what was typed', (
    tester,
  ) async {
    final events = FakeEventRepository();
    Object? saved;
    await pumpCalendarHarness(
      tester,
      events: events,
      open: (context) => showEventForm(context, day: _day),
      result: (value) => saved = value,
    );

    expect(find.text('New event'), findsOneWidget);
    await tester.enterText(_field('Title'), ' Essential oils for sleep ');
    await tester.enterText(_field('Place'), 'Studio Lumière, Lyon');
    await tester.enterText(_field('Link'), 'meet.google.com/abc');
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();

    final event = events.store.single;
    expect(saved, event);
    expect(event.title, 'Essential oils for sleep');
    expect(event.startsAt, DateTime(2026, 10, 8, 19));
    expect(event.endsAt, DateTime(2026, 10, 8, 20));
    expect(event.place, 'Studio Lumière, Lyon');
    expect(event.link, 'https://meet.google.com/abc');
    expect(event.notes, isNull);
  });

  testWidgets('a title is required', (tester) async {
    final events = FakeEventRepository();
    await pumpCalendarHarness(
      tester,
      events: events,
      open: (context) => showEventForm(context, day: _day),
      result: (_) {},
    );

    await tester.enterText(_field('Title'), '');
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();

    expect(find.text('Give it a title'), findsOneWidget);
    expect(events.calls, isEmpty);
  });

  testWidgets('a link that is not a web address is refused', (tester) async {
    final events = FakeEventRepository();
    await pumpCalendarHarness(
      tester,
      events: events,
      open: (context) => showEventForm(context, day: _day),
      result: (_) {},
    );

    await tester.enterText(_field('Title'), 'Call');
    await tester.enterText(_field('Link'), 'javascript:alert(1)');
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();

    expect(find.text("That doesn't look like a web link."), findsOneWidget);
    expect(events.calls, isEmpty);
  });

  testWidgets('editing: prefilled, and an end before the start is refused', (
    tester,
  ) async {
    final event = CalendarEvent(
      id: 'e1',
      title: 'Workshop',
      startsAt: DateTime(2026, 10, 8, 19),
      // Not something the table keeps; here to reach the form's check.
      endsAt: DateTime(2026, 10, 8, 18),
      notes: 'Bring the diffuser',
    );
    final events = FakeEventRepository([event]);
    await pumpCalendarHarness(
      tester,
      events: events,
      open: (context) => showEventForm(context, event: event),
      result: (_) {},
    );

    expect(find.text('Edit event'), findsOneWidget);
    expect(
      find.descendant(
        of: find.widgetWithText(LabeledField, 'Title'),
        matching: find.text('Workshop'),
      ),
      findsOneWidget,
    );
    expect(find.text('Bring the diffuser'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();

    expect(find.text('It has to end after it starts.'), findsOneWidget);
    expect(events.calls, isEmpty);

    // Clearing the end time saves.
    await tester.tap(find.byTooltip('Clear text'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();

    // list() is the provider's first load when the notifier is read.
    expect(events.calls, ['list()', 'update(e1)']);
    expect(events.store.single.endsAt, isNull);
  });

  testWidgets('a failed save keeps the form and what was typed', (
    tester,
  ) async {
    final events = FakeEventRepository()..failWith = PeopleFailure.network;
    await pumpCalendarHarness(
      tester,
      events: events,
      open: (context) => showEventForm(context, day: _day),
      result: (_) {},
    );

    await tester.enterText(_field('Title'), 'Workshop');
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();

    expect(find.byType(FormError), findsOneWidget);
    expect(
      find.descendant(
        of: find.widgetWithText(LabeledField, 'Title'),
        matching: find.text('Workshop'),
      ),
      findsOneWidget,
    );
    expect(find.text('New event'), findsOneWidget);
  });

  testWidgets('another type keeps a title that was typed', (tester) async {
    final events = FakeEventRepository();
    await pumpCalendarHarness(
      tester,
      events: events,
      open: (context) => showEventForm(context, day: _day),
      result: (_) {},
    );

    await tester.enterText(_field('Title'), 'Essential oils for sleep');
    await tester.tap(find.widgetWithText(ChoiceChip, 'Training'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();

    expect(events.store.single.title, 'Essential oils for sleep');
    expect(events.store.single.eventWorkflowId, 'training');
  });

  testWidgets('an event from before keeps having no type', (tester) async {
    final event = CalendarEvent(
      id: 'e1',
      title: 'Coffee',
      startsAt: DateTime(2026, 10, 8, 10),
    );
    final events = FakeEventRepository([event]);
    await pumpCalendarHarness(
      tester,
      events: events,
      open: (context) => showEventForm(context, event: event),
      result: (_) {},
    );

    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();

    expect(events.store.single.eventWorkflowId, isNull);
    expect(events.store.single.title, 'Coffee');
  });

  testWidgets('a type with a report calls its notes Prep notes (#495)', (
    tester,
  ) async {
    await pumpCalendarHarness(
      tester,
      events: FakeEventRepository(),
      eventWorkflows: FakeEventWorkflowRepository([
        EventWorkflow(
          id: 'm',
          name: 'Mentoring',
          steps: const [],
          isGroup: false,
          reportFields: const ['Topics covered'],
        ),
        EventWorkflow(id: 'w', name: 'Workshop', steps: const []),
      ]),
      open: (context) => showEventForm(context, day: _day),
      result: (_) {},
    );

    expect(find.widgetWithText(LabeledField, 'Notes'), findsOneWidget);
    await tester.tap(find.widgetWithText(ChoiceChip, 'Mentoring'));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(LabeledField, 'Prep notes'), findsOneWidget);
    expect(find.widgetWithText(LabeledField, 'Notes'), findsNothing);
    await tester.tap(find.widgetWithText(ChoiceChip, 'Workshop'));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(LabeledField, 'Notes'), findsOneWidget);
  });

  group('Repeat', () {
    Future<void> open(
      WidgetTester tester,
      FakeEventRepository events, {
      String? timeZone = 'Europe/Paris',
    }) => pumpCalendarHarness(
      tester,
      events: events,
      timeZone: timeZone,
      open: (context) => showEventForm(context, day: _day),
      result: (_) {},
    );

    Future<void> save(WidgetTester tester) async {
      await tester.ensureVisible(find.widgetWithText(FilledButton, 'Save'));
      await tester.tap(find.widgetWithText(FilledButton, 'Save'));
      await tester.pumpAndSettle();
    }

    testWidgets('every week: a series, in the device zone', (tester) async {
      final events = FakeEventRepository();
      await open(tester, events);

      expect(find.text('Repeat ends'), findsNothing);
      await tester.enterText(_field('Title'), 'Team call');
      await tester.tap(find.widgetWithText(ChoiceChip, 'Every week'));
      await tester.pumpAndSettle();
      // October 8, 2026 is a Thursday.
      expect(find.text('Every week on Thursday'), findsOneWidget);
      expect(find.text('Repeat ends'), findsOneWidget);
      final never = find.widgetWithText(ChoiceChip, 'Never');
      expect(tester.widget<ChoiceChip>(never).selected, isTrue);
      await save(tester);

      expect(events.calls, contains('addSeries(Team call, 1, Europe/Paris)'));
      expect(events.store.first.startsAt, DateTime(2026, 10, 8, 19));
      expect(events.store.length, greaterThan(50));
    });

    testWidgets("doesn't repeat: a single event", (tester) async {
      final events = FakeEventRepository();
      await open(tester, events);

      await tester.enterText(_field('Title'), 'Coffee');
      await save(tester);

      expect(events.calls, contains('add(Coffee)'));
      expect(events.store.single.series, isNull);
    });

    testWidgets('a device that cannot say its zone does not save', (
      tester,
    ) async {
      final events = FakeEventRepository();
      await open(tester, events, timeZone: null);

      await tester.enterText(_field('Title'), 'Team call');
      await tester.tap(find.widgetWithText(ChoiceChip, 'Every 2 weeks'));
      await tester.pumpAndSettle();
      await save(tester);

      expect(find.byType(FormError), findsOneWidget);
      expect(events.store, isEmpty);
    });

    testWidgets('a single event made to repeat becomes a series', (
      tester,
    ) async {
      final event = CalendarEvent(
        id: 'e1',
        title: 'Coffee',
        startsAt: DateTime(2026, 10, 8, 10),
      );
      final events = FakeEventRepository([event]);
      Object? saved;
      await pumpCalendarHarness(
        tester,
        events: events,
        open: (context) => showEventForm(context, event: event),
        result: (value) => saved = value,
      );

      await tester.tap(find.widgetWithText(ChoiceChip, 'Every week'));
      await tester.pumpAndSettle();
      await save(tester);

      expect(
        events.calls,
        containsAllInOrder(['update(e1)', 'repeat(e1, 1, Europe/Paris)']),
      );
      expect((saved! as CalendarEvent).series?.everyWeeks, 1);
      expect(find.text('Change a repeating event'), findsNothing);
    });

    group('on an occurrence', () {
      Future<(FakeEventRepository, CalendarEvent)> occurrence() async {
        final events = FakeEventRepository();
        await events.addSeries(
          (
            title: 'Team call',
            startsAt: DateTime(2026, 10, 13, 19),
            endsAt: null,
            place: null,
            link: null,
            notes: null,
            eventWorkflowId: null,
          ),
          (everyWeeks: 1, untilOn: null),
          'Europe/Paris',
        );
        events.calls.clear();
        return (events, events.store[1]);
      }

      Future<void> edit(
        WidgetTester tester,
        FakeEventRepository events,
        CalendarEvent event,
      ) => pumpCalendarHarness(
        tester,
        events: events,
        open: (context) => showEventForm(context, event: event),
        result: (_) {},
      );

      RadioListTile<EventScope> radio(WidgetTester tester, String label) =>
          tester.widget(find.widgetWithText(RadioListTile<EventScope>, label));

      testWidgets('Save asks; This event changes that one', (tester) async {
        final (events, event) = await occurrence();
        await edit(tester, events, event);

        expect(find.text("Doesn't repeat"), findsNothing);
        await tester.enterText(_field('Title'), 'Big call');
        await save(tester);
        expect(find.text('Change a repeating event'), findsOneWidget);
        expect(radio(tester, 'This event').enabled, isTrue);
        await tester.tap(find.widgetWithText(FilledButton, 'Save').last);
        await tester.pumpAndSettle();

        expect(events.calls, contains('update(${event.id})'));
        expect(events.store[1].title, 'Big call');
        expect(events.store[2].title, 'Team call');
      });

      testWidgets('This and following changes the rest', (tester) async {
        final (events, event) = await occurrence();
        await edit(tester, events, event);

        await tester.enterText(_field('Title'), 'Big call');
        await save(tester);
        await tester.tap(find.text('This and following events'));
        await tester.pumpAndSettle();
        await tester.tap(find.widgetWithText(FilledButton, 'Save').last);
        await tester.pumpAndSettle();

        expect(events.calls, contains('updateSeries(${event.id}, 1)'));
        expect(events.store[0].title, 'Team call');
        expect(events.store[1].title, 'Big call');
        expect(events.store[2].title, 'Big call');
      });

      testWidgets('a new repeat only reaches the following ones', (
        tester,
      ) async {
        final (events, event) = await occurrence();
        await edit(tester, events, event);

        await tester.tap(find.widgetWithText(ChoiceChip, 'Every 2 weeks'));
        await tester.pumpAndSettle();
        await save(tester);

        expect(radio(tester, 'This event').enabled, isFalse);
        expect(
          find.text('A new repeat applies to this and the following events.'),
          findsOneWidget,
        );
        await tester.tap(find.widgetWithText(FilledButton, 'Save').last);
        await tester.pumpAndSettle();

        expect(events.calls, contains('updateSeries(${event.id}, 2)'));
      });

      testWidgets('Cancel keeps the form open, unsaved', (tester) async {
        final (events, event) = await occurrence();
        await edit(tester, events, event);

        await save(tester);
        await tester.tap(find.text('Cancel').last);
        await tester.pumpAndSettle();

        expect(
          events.calls.where((call) => call.startsWith('update')),
          isEmpty,
        );
        expect(find.text('Edit event'), findsOneWidget);
      });
    });

    group('notes on a repeating event (#495)', () {
      final copy = find.widgetWithText(
        CheckboxListTile,
        'Copy to every occurrence',
      );

      testWidgets('only the first occurrence gets them', (tester) async {
        final events = FakeEventRepository();
        await open(tester, events);

        await tester.enterText(_field('Title'), 'Team call');
        await tester.tap(find.widgetWithText(ChoiceChip, 'Every week'));
        await tester.pumpAndSettle();
        await tester.enterText(_field('Notes'), 'Bring the kit');
        await tester.pumpAndSettle();
        expect(tester.widget<CheckboxListTile>(copy).value, isFalse);
        await save(tester);

        final sorted = byStart(events.store);
        expect(sorted.first.notes, 'Bring the kit');
        expect(sorted.skip(1).every((event) => event.notes == null), isTrue);
      });

      testWidgets('Copy to every occurrence: all of them get them', (
        tester,
      ) async {
        final events = FakeEventRepository();
        await open(tester, events);

        await tester.enterText(_field('Title'), 'Workshop');
        await tester.tap(find.widgetWithText(ChoiceChip, 'Every week'));
        await tester.pumpAndSettle();
        await tester.enterText(_field('Notes'), 'Bring the flyers');
        await tester.pumpAndSettle();
        await tester.ensureVisible(copy);
        await tester.tap(copy);
        await tester.pumpAndSettle();
        await save(tester);

        expect(events.store.length, greaterThan(1));
        expect(
          events.store.every((event) => event.notes == 'Bring the flyers'),
          isTrue,
        );
      });

      testWidgets('offered only when it repeats and has notes', (tester) async {
        await open(tester, FakeEventRepository());

        await tester.enterText(_field('Notes'), 'Bring the kit');
        await tester.pumpAndSettle();
        expect(copy, findsNothing);
        await tester.tap(find.widgetWithText(ChoiceChip, 'Every week'));
        await tester.pumpAndSettle();
        expect(copy, findsOneWidget);
        await tester.enterText(_field('Notes'), '');
        await tester.pumpAndSettle();
        expect(copy, findsNothing);
      });

      testWidgets('a single event made to repeat keeps its notes to itself', (
        tester,
      ) async {
        final event = CalendarEvent(
          id: 'e1',
          title: 'Coffee',
          startsAt: DateTime(2026, 10, 8, 10),
          notes: 'Ask about her goals',
        );
        final events = FakeEventRepository([event]);
        await pumpCalendarHarness(
          tester,
          events: events,
          open: (context) => showEventForm(context, event: event),
          result: (_) {},
        );

        await tester.tap(find.widgetWithText(ChoiceChip, 'Every week'));
        await tester.pumpAndSettle();
        await save(tester);

        final sorted = byStart(events.store);
        expect(sorted.first.notes, 'Ask about her goals');
        expect(sorted.length, greaterThan(1));
        expect(sorted.skip(1).every((event) => event.notes == null), isTrue);
      });
    });
  });

  group('People (#446)', () {
    Person person(String id, String name) => Person(
      id: id,
      name: name,
      stage: Stage.customer,
      stageSince: DateTime.utc(2026, 9),
    );
    final claire = person('p1', 'Claire Dubois');
    final sarah = person('p2', 'Sarah Petit');

    Future<void> open(
      WidgetTester tester,
      FakeEventRepository events, {
      List<Person> picked = const [],
    }) => pumpCalendarHarness(
      tester,
      events: events,
      people: FakePeopleRepository([claire, sarah]),
      open: (context) => showEventForm(context, day: _day, people: picked),
      result: (_) {},
    );

    Future<void> add(WidgetTester tester, List<String> names) async {
      final chip = find.widgetWithText(ActionChip, 'Add people');
      await tester.ensureVisible(chip);
      await tester.tap(chip);
      await tester.pumpAndSettle();
      for (final name in names) {
        await tester.tap(find.text(name).last);
      }
      await tester.pump();
      await tester.tap(
        find.textContaining(RegExp('^Add (one|${names.length})')),
      );
      await tester.pumpAndSettle();
    }

    Future<void> save(WidgetTester tester) async {
      await tester.ensureVisible(find.widgetWithText(FilledButton, 'Save'));
      await tester.tap(find.widgetWithText(FilledButton, 'Save'));
      await tester.pumpAndSettle();
    }

    testWidgets('picked, one taken off: the event saves with the other', (
      tester,
    ) async {
      final events = FakeEventRepository();
      await open(tester, events);

      await tester.enterText(_field('Title'), 'Workshop');
      await add(tester, ['Claire Dubois', 'Sarah Petit']);
      expect(find.widgetWithText(InputChip, 'Claire Dubois'), findsOneWidget);
      await tester.tap(find.byTooltip('Remove Claire Dubois'));
      await tester.pumpAndSettle();
      await save(tester);

      final event = events.store.single;
      expect(
        events.calls,
        containsAllInOrder(['add(Workshop)', 'invite(${event.id}:p2)']),
      );
      expect(event.attendees.map((a) => a.personId), ['p2']);
    });

    testWidgets('nobody picked: no invite', (tester) async {
      final events = FakeEventRepository();
      await open(tester, events);

      await tester.enterText(_field('Title'), 'Workshop');
      await save(tester);

      expect(events.calls.where((c) => c.startsWith('invite')), isEmpty);
    });

    testWidgets('prefilled, and the picker leaves them out', (tester) async {
      final events = FakeEventRepository();
      await open(tester, events, picked: [claire]);

      expect(find.widgetWithText(InputChip, 'Claire Dubois'), findsOneWidget);
      await tester.ensureVisible(find.widgetWithText(ActionChip, 'Add people'));
      await tester.tap(find.widgetWithText(ActionChip, 'Add people'));
      await tester.pumpAndSettle();
      expect(find.widgetWithText(ContactRow, 'Claire Dubois'), findsNothing);
      expect(find.widgetWithText(ContactRow, 'Sarah Petit'), findsOneWidget);
    });

    testWidgets('a repeating one: they join the series', (tester) async {
      final events = FakeEventRepository();
      await open(tester, events, picked: [claire]);

      await tester.enterText(_field('Title'), 'Team call');
      await tester.tap(find.widgetWithText(ChoiceChip, 'Every week'));
      await tester.pumpAndSettle();
      await save(tester);

      final first = events.store.first;
      expect(events.calls, contains('setSeriesPeople(${first.id}:+p1-)'));
      expect(events.store[1].attendees.single.personId, 'p1');
    });

    testWidgets('a failed invite: the event stays, and it says so', (
      tester,
    ) async {
      final events = FakeEventRepository()
        ..failWith = PeopleFailure.network
        ..failOnly = 'invite(';
      await open(tester, events, picked: [claire]);

      await tester.enterText(_field('Title'), 'Workshop');
      await save(tester);

      expect(events.store.single.attendees, isEmpty);
      expect(find.text('New event'), findsNothing);
      expect(find.byType(SnackBar), findsOneWidget);
    });

    testWidgets('editing: no People field', (tester) async {
      final event = CalendarEvent(
        id: 'e1',
        title: 'Coffee',
        startsAt: DateTime(2026, 10, 8, 10),
      );
      await pumpCalendarHarness(
        tester,
        events: FakeEventRepository([event]),
        open: (context) => showEventForm(context, event: event),
        result: (_) {},
      );

      expect(find.widgetWithText(ActionChip, 'Add people'), findsNothing);
    });
  });
}

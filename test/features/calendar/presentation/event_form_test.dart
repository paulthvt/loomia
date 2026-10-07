import 'package:flutter_test/flutter_test.dart';
import 'package:loomia/core/ui/form_error.dart';
import 'package:loomia/core/ui/labeled_field.dart';
import 'package:loomia/features/calendar/domain/calendar_event.dart';
import 'package:loomia/features/calendar/presentation/event_form.dart';
import 'package:loomia/features/contacts/domain/people_failure.dart';
import 'package:material_ui/material_ui.dart';

import '../calendar_harness.dart';
import '../fake_event_repository.dart';

Finder _field(String label) => find.descendant(
  of: find.widgetWithText(LabeledField, label),
  matching: find.byType(TextFormField),
);

final _day = DateTime(2026, 10, 8);

void main() {
  testWidgets('a new event on the day, at 19:00, with what was typed', (
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
    expect(event.endsAt, isNull);
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
    expect(find.text('Workshop'), findsOneWidget);
    expect(find.text('Bring the diffuser'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();

    expect(find.text('It has to end after it starts.'), findsOneWidget);
    expect(events.calls, isEmpty);

    // Clearing the end time saves.
    await tester.tap(find.byTooltip('Delete'));
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
    expect(find.text('Workshop'), findsOneWidget);
    expect(find.text('New event'), findsOneWidget);
  });
}

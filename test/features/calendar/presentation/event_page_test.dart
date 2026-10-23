import 'package:flutter_test/flutter_test.dart';
import 'package:loomia/app/router/app_router.dart';
import 'package:loomia/app/router/routes.dart';
import 'package:loomia/app/theme/app_theme.dart';
import 'package:loomia/core/ui/contact_row.dart';
import 'package:loomia/core/ui/labeled_field.dart';
import 'package:loomia/core/ui/pick_day.dart';
import 'package:loomia/features/calendar/domain/calendar_event.dart';
import 'package:loomia/features/calendar/presentation/calendar_page.dart';
import 'package:loomia/features/calendar/presentation/desktop_calendar.dart';
import 'package:loomia/features/calendar/presentation/event_page.dart';
import 'package:loomia/features/contacts/domain/people_failure.dart';
import 'package:loomia/features/contacts/domain/person.dart';
import 'package:loomia/features/workflows/domain/event_workflow.dart';
import 'package:loomia/features/workflows/domain/workflow.dart';
import 'package:loomia/l10n/app_localizations.dart';
import 'package:loomia/l10n/localizations_delegates.dart';
import 'package:material_ui/material_ui.dart';

import '../../../app/app_harness.dart';
import '../../contacts/fake_people_repository.dart';
import '../../workflows/fake_workflow_repository.dart';
import '../fake_event_repository.dart';

final _workshop = CalendarEvent(
  id: 'e1',
  title: 'Essential oils for sleep',
  startsAt: DateTime(2026, 10, 8, 19),
  endsAt: DateTime(2026, 10, 8, 21),
  place: 'Studio Lumière, Lyon',
  link: 'https://meet.google.com/abc',
  notes: 'Bring the diffuser',
);

final _claire = Person(
  id: 'p1',
  name: 'Claire Moreau',
  stage: Stage.prospect,
  stageSince: DateTime.utc(2026, 9),
);
final _sarah = Person(
  id: 'p2',
  name: 'Sarah Lemaire',
  stage: Stage.customer,
  stageSince: DateTime.utc(2026, 9),
);

/// Today at 19:00, so the Calendar lists it as it opens.
CalendarEvent _tonight() {
  final day = today();
  return CalendarEvent(
    id: 'e1',
    title: 'Workshop',
    startsAt: DateTime(day.year, day.month, day.day, 19),
  );
}

Future<void> _pumpView(
  WidgetTester tester,
  CalendarEvent event, {
  List<EventPerson> people = const [],
  DateTime? now,
  VoidCallback? onAddPeople,
  void Function(Person)? onRemove,
  void Function(Person)? onGoing,
  void Function(Person)? onFollowedUp,
  void Function(Person)? onOpenPerson,
  VoidCallback? onMarkDone,
  void Function(String place)? onOpenPlace,
  void Function(Uri link)? onJoin,
  List<EventWorkflowStep> steps = const [],
  void Function(EventWorkflowStep, bool)? onTick,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      locale: const Locale('en'),
      localizationsDelegates: localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      theme: AppTheme.light,
      home: Scaffold(
        body: EventView(
          event: event,
          people: people,
          now: now ?? DateTime(2026, 10, 8, 18),
          onAddPeople: onAddPeople ?? () {},
          onRemove: onRemove ?? (_) {},
          onGoing: onGoing ?? (_) {},
          onFollowedUp: onFollowedUp ?? (_) {},
          onOpenPerson: onOpenPerson ?? (_) {},
          onMarkDone: onMarkDone ?? () {},
          onEdit: () {},
          onDelete: () {},
          onOpenPlace: onOpenPlace ?? (_) {},
          onJoin: onJoin ?? (_) {},
          steps: steps,
          onTick: onTick ?? (_, _) {},
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('what, when, where, the link and the notes', (tester) async {
    String? place;
    Uri? joined;
    await _pumpView(
      tester,
      _workshop,
      onOpenPlace: (value) => place = value,
      onJoin: (value) => joined = value,
    );

    expect(find.text('Essential oils for sleep'), findsOneWidget);
    expect(
      find.text('Thursday, October 8 · 7:00 PM – 9:00 PM'),
      findsOneWidget,
    );
    expect(find.text('meet.google.com/abc'), findsOneWidget);
    expect(find.text('Bring the diffuser'), findsOneWidget);

    await tester.tap(find.text('Studio Lumière, Lyon'));
    await tester.tap(find.text('Join'));

    expect(place, 'Studio Lumière, Lyon');
    expect(joined, Uri.parse('https://meet.google.com/abc'));
  });

  testWidgets('no place, link or notes: only when', (tester) async {
    await _pumpView(
      tester,
      CalendarEvent(
        id: 'e2',
        title: 'Call',
        startsAt: DateTime(2026, 10, 8, 9),
      ),
    );

    expect(find.text('Thursday, October 8 · 9:00 AM'), findsOneWidget);
    expect(find.text('Join'), findsNothing);
    expect(find.byIcon(Icons.place_outlined), findsNothing);
    expect(find.byIcon(Icons.repeat_rounded), findsNothing);
  });

  testWidgets('an occurrence says how it repeats', (tester) async {
    await _pumpView(
      tester,
      CalendarEvent(
        id: 'e3',
        title: 'Team call',
        startsAt: DateTime(2026, 10, 13, 19),
        series: (
          id: 's1',
          everyWeeks: 1,
          firstOn: DateTime(2026, 10, 13),
          untilOn: DateTime(2026, 12, 15),
        ),
      ),
    );

    expect(
      find.text('Every week on Tuesday · until December 15'),
      findsOneWidget,
    );
  });

  testWidgets('before it starts: who is invited, add and remove', (
    tester,
  ) async {
    Person? removed;
    var adding = false;
    await _pumpView(
      tester,
      _workshop,
      people: [
        (person: _claire, attendee: const Attendee(personId: 'p1')),
        (person: _sarah, attendee: const Attendee(personId: 'p2')),
      ],
      onAddPeople: () => adding = true,
      onRemove: (person) => removed = person,
    );

    await tester.scrollUntilVisible(find.text('Sarah Lemaire'), 200);
    expect(find.text('Prospect · going'), findsOneWidget);
    expect(find.text('Customer · going'), findsOneWidget);
    expect(find.text('PEOPLE'), findsOneWidget);
    expect(find.text('Mark who was there'), findsNothing);

    await tester.tap(find.byTooltip('More for Claire Moreau'));
    await tester.pumpAndSettle();
    expect(find.text('Going'), findsNothing);
    expect(find.text('Followed up'), findsNothing);
    await tester.tap(find.text('Remove from the event'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add people'));
    expect(removed, _claire);
    expect(adding, isTrue);
  });

  testWidgets('a group event: who is invited, going, followed up, and the '
      'menu for each', (tester) async {
    final invited = Attendee(
      personId: 'p1',
      going: false,
      invitedOn: DateTime(2026, 10, 1),
    );
    final followed = Attendee(
      personId: 'p2',
      going: false,
      invitedOn: DateTime(2026, 10, 1),
      followedUpOn: DateTime(2026, 10, 5),
    );
    final event = CalendarEvent(
      id: 'e1',
      title: 'Huiles et sommeil',
      startsAt: DateTime(2026, 10, 8, 19),
      attendees: [
        invited,
        followed,
        const Attendee(personId: 'p3'),
      ],
    );
    final marie = Person(
      id: 'p3',
      name: 'Marie Dupont',
      stage: Stage.customer,
      stageSince: DateTime.utc(2026, 9),
    );
    Person? going;
    Person? followedUp;
    await _pumpView(
      tester,
      event,
      people: [
        (person: _claire, attendee: invited),
        (person: marie, attendee: const Attendee(personId: 'p3')),
        (person: _sarah, attendee: followed),
      ],
      onGoing: (person) => going = person,
      onFollowedUp: (person) => followedUp = person,
    );

    await tester.scrollUntilVisible(find.text('Sarah Lemaire'), 200);
    expect(find.text('PEOPLE · 3 · 1 GOING'), findsOneWidget);
    expect(find.text('Prospect · invited Oct 1'), findsOneWidget);
    expect(find.text('Customer · going'), findsOneWidget);
    expect(
      find.text('Customer · invited Oct 1 · followed up Oct 5'),
      findsOneWidget,
    );

    await tester.tap(find.byTooltip('More for Claire Moreau'));
    await tester.pumpAndSettle();
    expect(find.text('Remove from the event'), findsOneWidget);
    await tester.tap(find.text('Going'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('More for Sarah Lemaire'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Followed up'));
    await tester.pumpAndSettle();

    expect(going, _claire);
    expect(followedUp, _sarah);
  });

  testWidgets('once started: Mark who was there', (tester) async {
    var marking = false;
    final started = CalendarEvent(
      id: 'e1',
      title: 'Essential oils for sleep',
      startsAt: DateTime(2026, 10, 8, 19),
      attendees: const [Attendee(personId: 'p1', came: false)],
    );
    await _pumpView(
      tester,
      started,
      people: [(person: _claire, attendee: const Attendee(personId: 'p1'))],
      now: DateTime(2026, 10, 8, 19, 5),
      onMarkDone: () => marking = true,
    );

    await tester.tap(find.text('Mark who was there'));
    expect(marking, isTrue);
  });

  testWidgets('done: the banner, who was there, nothing to change', (
    tester,
  ) async {
    final done = CalendarEvent(
      id: 'e1',
      title: 'Workshop',
      startsAt: DateTime(2026, 10, 8, 19),
      doneAt: DateTime(2026, 10, 9),
      attendees: const [
        Attendee(personId: 'p1', came: true),
        Attendee(personId: 'p2', came: false),
      ],
    );
    await _pumpView(
      tester,
      done,
      people: [
        (person: _claire, attendee: const Attendee(personId: 'p1', came: true)),
        (person: _sarah, attendee: const Attendee(personId: 'p2')),
      ],
      now: DateTime(2026, 10, 9, 9),
    );

    expect(find.text('Done · 1 of 2 was there'), findsOneWidget);
    expect(find.text('Prospect · was there'), findsOneWidget);
    expect(find.text('Customer · missed it'), findsOneWidget);
    expect(find.text('Mark who was there'), findsNothing);
    expect(find.text('Add people'), findsNothing);
    expect(find.byIcon(Icons.close_rounded), findsNothing);
  });

  testWidgets('mobile: opens from the day, edits, back to the month', (
    tester,
  ) async {
    final events = FakeEventRepository([_tonight()]);
    final container = await pumpLoomia(
      tester,
      size: const Size(390, 844),
      events: events,
    );
    container.read(routerProvider).go(Routes.calendar);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Workshop'));
    await tester.pumpAndSettle();
    expect(find.byType(EventPage), findsOneWidget);

    await tester.tap(find.byTooltip('Edit event'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.descendant(
        of: find.widgetWithText(LabeledField, 'Title'),
        matching: find.byType(TextFormField),
      ),
      'Product evening',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();
    expect(find.text('Product evening'), findsOneWidget);

    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(find.byType(CalendarView), findsOneWidget);
    expect(find.text('Product evening'), findsOneWidget);
  });

  testWidgets('delete: confirmed, back on the month, never "not found"', (
    tester,
  ) async {
    final events = FakeEventRepository([_tonight()]);
    final container = await pumpLoomia(
      tester,
      size: const Size(390, 844),
      events: events,
    );
    container.read(routerProvider).go(Routes.calendar);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Workshop'));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Delete event'));
    await tester.pumpAndSettle();
    expect(find.text('Delete Workshop?'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
    await tester.pump();
    expect(
      find.text("This event isn't in your calendar any more."),
      findsNothing,
    );
    await tester.pumpAndSettle();

    expect(find.byType(CalendarView), findsOneWidget);
    expect(find.text('Workshop'), findsNothing);
    expect(events.calls, contains('remove(e1)'));
    expect(
      find.text("This event isn't in your calendar any more."),
      findsNothing,
    );
  });

  group('an occurrence', () {
    /// A weekly call from tonight; returns the repository and the second
    /// occurrence's id.
    Future<(FakeEventRepository, String)> weekly() async {
      final events = FakeEventRepository();
      final day = today();
      await events.addSeries(
        (
          title: 'Team call',
          startsAt: DateTime(day.year, day.month, day.day, 19),
          endsAt: null,
          place: null,
          link: null,
          notes: null,
          eventWorkflowId: null,
        ),
        (everyWeeks: 1, untilOn: null),
        'Europe/Paris',
      );
      return (events, events.store[1].id);
    }

    testWidgets('delete asks once; This and following ends the series', (
      tester,
    ) async {
      final (events, id) = await weekly();
      final container = await pumpLoomia(
        tester,
        size: const Size(390, 844),
        events: events,
      );
      container.read(routerProvider).go(Routes.eventLocation(id));
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Delete event'));
      await tester.pumpAndSettle();
      expect(find.text('Delete a repeating event'), findsOneWidget);
      await tester.tap(find.text('This and following events'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
      await tester.pumpAndSettle();

      expect(events.calls, contains('endSeries($id)'));
      expect(events.calls, isNot(contains('remove($id)')));
      expect(find.text('Team call'), findsOneWidget);
      expect(events.store, hasLength(1));
    });

    testWidgets('delete, This event: that one only', (tester) async {
      final (events, id) = await weekly();
      final container = await pumpLoomia(
        tester,
        size: const Size(390, 844),
        events: events,
      );
      container.read(routerProvider).go(Routes.eventLocation(id));
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Delete event'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
      await tester.pumpAndSettle();

      expect(events.calls, contains('remove($id)'));
      expect(events.store.length, greaterThan(50));
    });

    testWidgets('add and remove people ask, then reach the following', (
      tester,
    ) async {
      final (events, id) = await weekly();
      final container = await pumpLoomia(
        tester,
        size: const Size(390, 1000),
        events: events,
        people: FakePeopleRepository([_claire, _sarah]),
      );
      container.read(routerProvider).go(Routes.eventLocation(id));
      await tester.pumpAndSettle();

      await tester.scrollUntilVisible(find.text('Add people'), 200);
      await tester.tap(find.text('Add people'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Claire Moreau'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Add one person'));
      await tester.pumpAndSettle();
      expect(find.text('Change a repeating event'), findsOneWidget);
      await tester.tap(find.text('This and following events'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Save'));
      await tester.pumpAndSettle();
      expect(events.calls, contains('setSeriesPeople($id:+p1-)'));

      await tester.tap(find.byTooltip('More for Claire Moreau'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Remove from the event'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Save'));
      await tester.pumpAndSettle();
      expect(events.calls, contains('uninvite($id:p1)'));
      expect(events.store[2].attendees.single.personId, 'p1');
    });
  });

  testWidgets('desktop: the event opens in the pane, the month stays', (
    tester,
  ) async {
    final container = await pumpLoomia(
      tester,
      size: const Size(1440, 900),
      events: FakeEventRepository([_tonight()]),
    );
    container.read(routerProvider).go(Routes.calendar);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Workshop'));
    await tester.pumpAndSettle();

    expect(find.byType(DesktopMonth), findsOneWidget);
    expect(find.byType(EventView), findsOneWidget);
    expect(find.byType(BackButton), findsNothing);
  });

  testWidgets('in the app: invite from the picker, then remove', (
    tester,
  ) async {
    final events = FakeEventRepository([_tonight()]);
    final container = await pumpLoomia(
      tester,
      size: const Size(390, 1000),
      events: events,
      people: FakePeopleRepository([_claire, _sarah]),
    );
    container.read(routerProvider).go(Routes.eventLocation('e1'));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(find.text('Add people'), 200);
    await tester.tap(find.text('Add people'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Claire Moreau'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add one person'));
    await tester.pumpAndSettle();

    expect(events.calls, contains('invite(e1:p1)'));
    expect(find.text('Prospect · going'), findsOneWidget);

    await tester.tap(find.byTooltip('More for Claire Moreau'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Remove from the event'));
    await tester.pumpAndSettle();

    expect(events.calls, contains('uninvite(e1:p1)'));
    expect(find.text('Nobody invited yet.'), findsOneWidget);
  });

  testWidgets('in the app: who was there, then the banner', (tester) async {
    final started = DateTime.now().subtract(const Duration(hours: 1));
    final events = FakeEventRepository([
      CalendarEvent(
        id: 'e1',
        title: 'Workshop',
        startsAt: started,
        attendees: const [
          Attendee(personId: 'p1', came: false),
          Attendee(personId: 'p2', came: false),
        ],
      ),
    ]);
    final container = await pumpLoomia(
      tester,
      size: const Size(390, 1000),
      events: events,
      people: FakePeopleRepository([_claire, _sarah]),
    );
    container.read(routerProvider).go(Routes.eventLocation('e1'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Mark who was there'));
    await tester.pumpAndSettle();
    expect(find.text('Who was there?'), findsOneWidget);
    // Everyone starts ticked; Sarah missed it.
    await tester.tap(find.widgetWithText(CheckboxListTile, 'Sarah Lemaire'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Done · 1 was there'));
    await tester.pumpAndSettle();

    expect(events.calls, contains('close(e1:p1|next:)'));
    expect(find.text('Done · 1 of 2 was there'), findsOneWidget);
  });

  testWidgets('someone no longer in the book is not listed', (tester) async {
    final day = today();
    final container = await pumpLoomia(
      tester,
      size: const Size(390, 1000),
      events: FakeEventRepository([
        CalendarEvent(
          id: 'e1',
          title: 'Workshop',
          startsAt: DateTime(day.year, day.month, day.day, 19),
          attendees: const [
            Attendee(personId: 'p1', came: false),
            Attendee(personId: 'gone', came: false),
          ],
        ),
      ]),
      people: FakePeopleRepository([_claire]),
    );
    container.read(routerProvider).go(Routes.eventLocation('e1'));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(find.text('Claire Moreau'), 200);
    expect(find.byType(ContactRow), findsOneWidget);
  });

  testWidgets('a link to an event that is gone says so', (tester) async {
    final container = await pumpLoomia(tester, size: const Size(390, 844));
    container.read(routerProvider).go(Routes.eventLocation('nope'));
    await tester.pumpAndSettle();

    expect(
      find.text("This event isn't in your calendar any more."),
      findsOneWidget,
    );
  });

  testWidgets('people load failed: error state, no Mark who was there', (
    tester,
  ) async {
    final started = DateTime.now().subtract(const Duration(hours: 1));
    final events = FakeEventRepository([
      CalendarEvent(
        id: 'e1',
        title: 'Workshop',
        startsAt: started,
        attendees: const [Attendee(personId: 'p1', came: false)],
      ),
    ]);
    final people = FakePeopleRepository([_claire]);
    people.failWith = PeopleFailure.network;
    final container = await pumpLoomia(
      tester,
      size: const Size(390, 1000),
      events: events,
      people: people,
    );
    container.read(routerProvider).go(Routes.eventLocation('e1'));
    await tester.pumpAndSettle();

    expect(find.text("You're offline"), findsOneWidget);
    expect(find.text('Mark who was there'), findsNothing);
    expect(find.text('Try again'), findsOneWidget);
  });

  testWidgets('the checklist: when each step is due, tick and untick', (
    tester,
  ) async {
    final ticks = <(String, bool)>[];
    final event = CalendarEvent(
      id: 'e1',
      title: 'Workshop',
      startsAt: DateTime(2026, 10, 8, 19),
      eventWorkflowId: 'workshop',
      stepsDone: {'thank': DateTime(2026, 10, 9)},
    );
    await _pumpView(
      tester,
      event,
      steps: const [
        EventWorkflowStep(
          id: 'remind',
          label: "Remind everyone it's tomorrow",
          days: -1,
        ),
        EventWorkflowStep(
          id: 'thank',
          label: 'Send a thank-you and the notes',
          days: 1,
        ),
      ],
      onTick: (step, done) => ticks.add((step.id, done)),
    );

    expect(find.text('CHECKLIST'), findsOneWidget);
    expect(find.text('1 day before · Wednesday, October 7'), findsOneWidget);
    expect(find.text('1 day after · Friday, October 9'), findsOneWidget);

    await tester.tap(
      find.byTooltip('Mark "Remind everyone it\'s tomorrow" done'),
    );
    await tester.tap(
      find.byTooltip('Mark "Send a thank-you and the notes" not done'),
    );
    expect(ticks, [('remind', true), ('thank', false)]);
  });

  group('who was there', () {
    CalendarEvent workshop({String id = 'e1', DateTime? startsAt}) =>
        CalendarEvent(
          id: id,
          title: id == 'e1' ? 'Huiles et sommeil' : 'Essential oils for kids',
          startsAt:
              startsAt ?? DateTime.now().subtract(const Duration(hours: 1)),
          eventWorkflowId: 'workshop',
          attendees: id == 'e1'
              ? const [
                  Attendee(personId: 'p1', came: false),
                  Attendee(personId: 'p2', came: false),
                ]
              : const [],
        );

    Future<FakeEventRepository> open(
      WidgetTester tester, {
      List<CalendarEvent> more = const [],
      List<Person>? people,
      FakeWorkflowRepository? workflows,
    }) async {
      final events = FakeEventRepository([workshop(), ...more]);
      final book = FakePeopleRepository(people ?? [_claire, _sarah]);
      if (workflows != null) book.workflows = workflows.store;
      final container = await pumpLoomia(
        tester,
        size: const Size(390, 1400),
        events: events,
        people: book,
        workflows: workflows,
      );
      container.read(routerProvider).go(Routes.eventLocation('e1'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Mark who was there'));
      await tester.pumpAndSettle();
      return events;
    }

    testWidgets('a prospect who became a customer, with the registration '
        'order; a customer with nothing', (tester) async {
      final events = await open(tester);

      expect(find.text('Became a customer?'), findsOneWidget);
      expect(find.text('Order (optional)'), findsOneWidget);
      await tester.tap(find.text('Became a customer?'));
      await tester.pumpAndSettle();
      expect(find.text('Starts New customer'), findsOneWidget);
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Registration order'),
        '120',
      );
      await tester.tap(find.text('Done · 2 were there'));
      await tester.pumpAndSettle();

      expect(events.closedThere, [
        (
          personId: 'p1',
          customer: true,
          amount: 120.0,
          text: 'Registration order',
        ),
        (personId: 'p2', customer: false, amount: null, text: null),
      ]);
      expect(find.text('Who was there?'), findsNothing);
    });

    testWidgets('an amount that is not one is refused', (tester) async {
      final events = await open(tester);

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Order (optional)'),
        'abc',
      );
      await tester.tap(find.text('Done · 2 were there'));
      await tester.pumpAndSettle();

      expect(
        find.text('Use a number above 0, like 100 or 99.5.'),
        findsOneWidget,
      );
      expect(events.calls.where((c) => c.startsWith('close(')), isEmpty);
    });

    testWidgets('someone who missed it: invited to the next one, on by '
        'default', (tester) async {
      final events = await open(
        tester,
        more: [
          workshop(
            id: 'e2',
            startsAt: DateTime.now().add(const Duration(days: 20)),
          ),
        ],
      );

      await tester.tap(find.widgetWithText(CheckboxListTile, 'Sarah Lemaire'));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('Invite to Essential oils for kids'),
        findsOneWidget,
      );
      await tester.tap(find.text('Done · 1 was there'));
      await tester.pumpAndSettle();

      expect(events.calls, contains('close(e1:p1|next:p2)'));
      expect(
        events.store.firstWhere((e) => e.id == 'e2').attendees.single.personId,
        'p2',
      );
    });

    testWidgets('someone on the step this event was for: where they go next', (
      tester,
    ) async {
      final workflows = FakeWorkflowRepository([
        ...FakeWorkflowRepository.samples(),
        Workflow(
          id: 'invite',
          stage: Stage.customer,
          name: 'New customer',
          isDefault: false,
          steps: const [
            WorkflowStep(
              id: 'book',
              position: 1,
              label: 'Book the workshop',
              days: 0,
              eventWorkflowId: 'workshop',
            ),
            WorkflowStep(
              id: 'access',
              position: 2,
              label: 'Give VIP access',
              days: 0,
            ),
          ],
        ),
      ]);
      await open(
        tester,
        workflows: workflows,
        people: [
          _claire,
          Person(
            id: 'p2',
            name: 'Sarah Lemaire',
            stage: Stage.customer,
            stageSince: DateTime.utc(2026, 9),
            place: (workflowId: 'invite', atPosition: 1, lastTick: today()),
          ),
        ],
      );

      expect(
        find.text('Continues New customer → Give VIP access'),
        findsOneWidget,
      );
    });
  });
}

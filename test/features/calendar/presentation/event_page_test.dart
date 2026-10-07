import 'package:flutter_test/flutter_test.dart';
import 'package:loomia/app/router/app_router.dart';
import 'package:loomia/app/router/routes.dart';
import 'package:loomia/app/theme/app_theme.dart';
import 'package:loomia/core/ui/contact_row.dart';
import 'package:loomia/core/ui/labeled_field.dart';
import 'package:loomia/core/ui/pick_day.dart';
import 'package:loomia/features/calendar/domain/calendar_event.dart';
import 'package:loomia/features/calendar/presentation/calendar_page.dart';
import 'package:loomia/features/calendar/presentation/event_page.dart';
import 'package:loomia/features/calendar/presentation/month_grid.dart';
import 'package:loomia/features/contacts/domain/people_failure.dart';
import 'package:loomia/features/contacts/domain/person.dart';
import 'package:loomia/features/workflows/domain/event_workflow.dart';
import 'package:loomia/l10n/app_localizations.dart';
import 'package:loomia/l10n/localizations_delegates.dart';
import 'package:material_ui/material_ui.dart';

import '../../../app/app_harness.dart';
import '../../contacts/fake_people_repository.dart';
import '../../workflows/fake_event_workflow_repository.dart';
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
  void Function(Person)? onOpenPerson,
  VoidCallback? onMarkDone,
  void Function(String place)? onOpenPlace,
  void Function(Uri link)? onJoin,
  List<EventWorkflowStep> steps = const [],
  void Function(EventWorkflowStep, bool)? onTick,
  Map<Stage, String> followUpNames = const {},
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
          onOpenPerson: onOpenPerson ?? (_) {},
          onMarkDone: onMarkDone ?? () {},
          onEdit: () {},
          onDelete: () {},
          onOpenPlace: onOpenPlace ?? (_) {},
          onJoin: onJoin ?? (_) {},
          steps: steps,
          onTick: onTick ?? (_, _) {},
          followUpNames: followUpNames,
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
  });

  testWidgets('before it starts: who is invited, add and remove', (
    tester,
  ) async {
    Person? removed;
    var adding = false;
    await _pumpView(
      tester,
      _workshop,
      people: [(person: _claire, came: false), (person: _sarah, came: false)],
      onAddPeople: () => adding = true,
      onRemove: (person) => removed = person,
    );

    await tester.scrollUntilVisible(find.text('Sarah Lemaire'), 200);
    expect(find.text('Prospect · invited'), findsOneWidget);
    expect(find.text('Customer · invited'), findsOneWidget);
    expect(find.text('Mark who was there'), findsNothing);

    await tester.tap(find.byTooltip('Remove Claire Moreau from the event'));
    await tester.tap(find.text('Add people'));
    expect(removed, _claire);
    expect(adding, isTrue);
  });

  testWidgets('once started: Mark who was there', (tester) async {
    var marking = false;
    final started = CalendarEvent(
      id: 'e1',
      title: 'Essential oils for sleep',
      startsAt: DateTime(2026, 10, 8, 19),
      attendees: const [(personId: 'p1', came: false)],
    );
    await _pumpView(
      tester,
      started,
      people: [(person: _claire, came: false)],
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
        (personId: 'p1', came: true),
        (personId: 'p2', came: false),
      ],
    );
    await _pumpView(
      tester,
      done,
      people: [(person: _claire, came: true), (person: _sarah, came: false)],
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

    expect(find.byType(MonthGrid), findsOneWidget);
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
    expect(find.text('Prospect · invited'), findsOneWidget);

    await tester.tap(find.byTooltip('Remove Claire Moreau from the event'));
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
          (personId: 'p1', came: false),
          (personId: 'p2', came: false),
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

    expect(events.calls, contains('markDone(e1:p1)'));
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
            (personId: 'p1', came: false),
            (personId: 'gone', came: false),
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
        attendees: const [(personId: 'p1', came: false)],
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

    expect(find.text("Couldn't load your contacts."), findsOneWidget);
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

  testWidgets('after the event: what each stage starts', (tester) async {
    await _pumpView(
      tester,
      CalendarEvent(
        id: 'e1',
        title: 'Workshop',
        startsAt: DateTime(2026, 10, 8, 19),
        eventWorkflowId: 'workshop',
      ),
      followUpNames: const {Stage.prospect: 'Samples'},
    );

    await tester.scrollUntilVisible(find.text('Start Samples'), 200);
    expect(find.text('Prospects'), findsOneWidget);
    expect(find.text('Keep their workflow'), findsNWidgets(2));
  });

  testWidgets('who was there says what happens next', (tester) async {
    final started = DateTime.now().subtract(const Duration(hours: 1));
    final events = FakeEventRepository([
      CalendarEvent(
        id: 'e1',
        title: 'Workshop',
        startsAt: started,
        eventWorkflowId: 'workshop',
        followUps: FakeEventWorkflowRepository.samples().first.followUps,
        attendees: const [
          (personId: 'p1', came: false),
          (personId: 'p2', came: false),
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

    expect(find.text('WHAT HAPPENS NEXT'), findsOneWidget);
    expect(find.text('1 prospect starts Samples'), findsOneWidget);
    expect(find.text('1 customer starts New customer'), findsOneWidget);
    await tester.tap(find.widgetWithText(CheckboxListTile, 'Sarah Lemaire'));
    await tester.pumpAndSettle();
    expect(find.text('1 customer starts New customer'), findsNothing);
  });
}

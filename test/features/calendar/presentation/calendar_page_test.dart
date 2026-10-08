import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loomia/app/router/app_router.dart';
import 'package:loomia/app/router/routes.dart';
import 'package:loomia/app/theme/app_theme.dart';
import 'package:loomia/core/ui/labeled_field.dart';
import 'package:loomia/core/ui/pick_day.dart';
import 'package:loomia/features/calendar/domain/calendar_event.dart';
import 'package:loomia/features/calendar/presentation/calendar_controller.dart';
import 'package:loomia/features/calendar/presentation/calendar_page.dart';
import 'package:loomia/features/calendar/presentation/month_grid.dart';
import 'package:loomia/features/contacts/domain/person.dart';
import 'package:loomia/features/contacts/presentation/people_controller.dart';
import 'package:loomia/l10n/app_localizations.dart';
import 'package:loomia/l10n/localizations_delegates.dart';
import 'package:material_ui/material_ui.dart';

import '../../../app/app_harness.dart';
import '../../contacts/fake_people_repository.dart';
import '../fake_event_repository.dart';

final _workshop = CalendarEvent(
  id: 'e1',
  title: 'Essential oils for sleep',
  startsAt: DateTime(2026, 10, 8, 19),
  endsAt: DateTime(2026, 10, 8, 21),
  place: 'Studio Lumière, Lyon',
);

final _training = CalendarEvent(
  id: 'e2',
  title: 'New member training',
  startsAt: DateTime(2026, 10, 8, 14),
  link: 'https://meet.google.com/abc',
);

Future<void> _pump(
  WidgetTester tester, {
  List<CalendarEvent> events = const [],
  AsyncValue<List<CalendarEvent>>? value,
  CalendarSelection? selection,
  Locale locale = const Locale('en'),
  Size size = const Size(390, 1000),
  ValueChanged<DateTime>? onSelect,
  ValueChanged<int>? onShift,
  VoidCallback? onToday,
  void Function(CalendarEvent event)? onOpen,
  ValueChanged<DateTime>? onAdd,
  Widget? pane,
}) async {
  tester.view
    ..physicalSize = size
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      locale: locale,
      localizationsDelegates: localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      theme: AppTheme.light,
      home: CalendarView(
        events: value ?? AsyncData(events),
        selection:
            selection ??
            (month: DateTime(2026, 10), day: DateTime(2026, 10, 8)),
        today: DateTime(2026, 10, 7),
        onSelect: onSelect ?? (_) {},
        onShift: onShift ?? (_) {},
        onToday: onToday ?? () {},
        onOpen: onOpen ?? (_) {},
        onAdd: onAdd ?? (_) {},
        onRetry: () {},
        pane: pane,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('the month, its weeks from Sunday in English', (tester) async {
    final semantics = tester.ensureSemantics();
    await _pump(tester);

    expect(find.text('October 2026'), findsOneWidget);
    expect(
      tester.getCenter(find.text('Sun')).dx,
      lessThan(tester.getCenter(find.text('Mon')).dx),
    );
    expect(
      find.bySemanticsLabel('Sunday, September 27, nothing planned'),
      findsOneWidget,
    );
    semantics.dispose();
  });

  testWidgets('in French, the weeks start on Monday', (tester) async {
    await _pump(tester, locale: const Locale('fr'));

    expect(find.text('octobre 2026'), findsOneWidget);
    expect(
      tester.getCenter(find.text('lun.')).dx,
      lessThan(tester.getCenter(find.text('dim.')).dx),
    );
  });

  testWidgets('a day says how many events it has', (tester) async {
    final semantics = tester.ensureSemantics();
    await _pump(tester, events: [_workshop, _training]);

    expect(
      find.bySemanticsLabel('Thursday, October 8, 2 events'),
      findsOneWidget,
    );
    semantics.dispose();
  });

  testWidgets('a row says how many are invited, or were there', (tester) async {
    await _pump(
      tester,
      events: [
        CalendarEvent(
          id: 'e1',
          title: 'Essential oils for sleep',
          startsAt: DateTime(2026, 10, 8, 19),
          place: 'Studio Lumière',
          attendees: const [
            (personId: 'p1', came: false),
            (personId: 'p2', came: false),
          ],
        ),
        CalendarEvent(
          id: 'e2',
          title: 'Training',
          startsAt: DateTime(2026, 10, 8, 10),
          doneAt: DateTime(2026, 10, 8, 12),
          attendees: const [(personId: 'p1', came: true)],
        ),
      ],
    );

    expect(find.text('Studio Lumière · 2 invited'), findsOneWidget);
    expect(find.text('1 was there'), findsOneWidget);
  });

  testWidgets('tapping a day selects it', (tester) async {
    DateTime? selected;
    await _pump(tester, onSelect: (day) => selected = day);

    await tester.tap(find.text('14'));

    expect(selected, DateTime(2026, 10, 14));
  });

  testWidgets('the arrows change month, Today comes back', (tester) async {
    final shifts = <int>[];
    var backToToday = false;
    await _pump(tester, onShift: shifts.add, onToday: () => backToToday = true);

    await tester.tap(find.byTooltip('Next month'));
    await tester.tap(find.byTooltip('Previous month'));
    await tester.tap(find.text('Today'));

    expect(shifts, [1, -1]);
    expect(backToToday, isTrue);
  });

  testWidgets("the selected day's events, earliest first, open on tap", (
    tester,
  ) async {
    CalendarEvent? opened;
    await _pump(
      tester,
      events: [_workshop, _training],
      onOpen: (event) => opened = event,
    );

    expect(find.text('THURSDAY, OCTOBER 8'), findsOneWidget);
    expect(
      tester.getTopLeft(find.text('New member training')).dy,
      lessThan(tester.getTopLeft(find.text('Essential oils for sleep')).dy),
    );
    expect(find.text('7:00 PM'), findsOneWidget);
    expect(find.text('9:00 PM'), findsOneWidget);
    expect(find.text('Studio Lumière, Lyon'), findsOneWidget);
    // A link and no place.
    expect(find.text('Online'), findsOneWidget);

    await tester.tap(find.text('Essential oils for sleep'));
    expect(opened, _workshop);
  });

  testWidgets('an empty day says so; Add and the button add on it', (
    tester,
  ) async {
    final added = <DateTime>[];
    await _pump(
      tester,
      events: [_workshop],
      selection: (month: DateTime(2026, 10), day: DateTime(2026, 10, 9)),
      onAdd: added.add,
    );

    expect(find.text('Nothing planned'), findsOneWidget);
    await tester.tap(find.text('Add'));
    await tester.tap(find.byTooltip('New event'));

    expect(added, [DateTime(2026, 10, 9), DateTime(2026, 10, 9)]);
  });

  testWidgets('a failed load says so', (tester) async {
    await _pump(
      tester,
      value: AsyncError(Exception('offline'), StackTrace.empty),
    );

    expect(find.text("Couldn't load your calendar."), findsOneWidget);
  });

  testWidgets('desktop: the grid, and the pane beside it', (tester) async {
    await _pump(tester, size: const Size(1440, 900), pane: const Text('pane'));

    expect(find.text('pane'), findsOneWidget);
    expect(find.byType(FloatingActionButton), findsNothing);
    expect(
      tester.getCenter(find.text('October 2026')).dx,
      lessThan(tester.getCenter(find.text('pane')).dx),
    );
  });

  testWidgets('desktop: a wide window caps the month', (tester) async {
    await _pump(tester, size: const Size(2400, 900), pane: const Text('pane'));

    expect(tester.getSize(find.byType(MonthGrid)).width, lessThan(840));
  });

  testWidgets('the ink of a day centres on its number', (tester) async {
    await _pump(tester, events: [_workshop]);

    final day = find.ancestor(
      of: find.text('8'),
      matching: find.byType(InkWell),
    );
    expect(tester.getCenter(day), tester.getCenter(find.text('8')));
  });

  testWidgets('in the app: deleting a contact updates the count', (
    tester,
  ) async {
    final day = today();
    final startsAt = DateTime(day.year, day.month, day.day, 19);
    final events = FakeEventRepository([
      CalendarEvent(
        id: 'e1',
        title: 'Workshop',
        startsAt: startsAt,
        attendees: const [
          (personId: 'p1', came: false),
          (personId: 'p2', came: false),
        ],
      ),
    ]);
    Person person(String id, String name) => Person(
      id: id,
      name: name,
      stage: Stage.prospect,
      stageSince: DateTime.utc(2026, 9),
    );
    final container = await pumpLoomia(
      tester,
      size: const Size(390, 844),
      events: events,
      people: FakePeopleRepository([
        person('p1', 'Claire Moreau'),
        person('p2', 'Sarah Lemaire'),
      ]),
    );
    container.read(routerProvider).go(Routes.calendar);
    await tester.pumpAndSettle();
    expect(find.text('2 invited'), findsOneWidget);

    // The database removes her from the event as it deletes her.
    events.store[0] = CalendarEvent(
      id: 'e1',
      title: 'Workshop',
      startsAt: startsAt,
      attendees: const [(personId: 'p1', came: false)],
    );
    await container.read(peopleProvider('p@example.com').notifier).remove([
      'p2',
    ]);
    await tester.pumpAndSettle();

    expect(find.text('1 invited'), findsOneWidget);
  });

  testWidgets('in the app: the month follows the finger, then turns', (
    tester,
  ) async {
    final container = await pumpLoomia(tester, size: const Size(390, 844));
    container.read(routerProvider).go(Routes.calendar);
    await tester.pumpAndSettle();
    final month = container.read(calendarSelectionProvider).month;
    final grids = find.byType(MonthGrid);
    final left = tester.getTopLeft(grids).dx;

    // Held mid-drag: the month moved with the finger, the next one beside it.
    final gesture = await tester.startGesture(tester.getCenter(grids));
    await gesture.moveBy(const Offset(-20, 0));
    await gesture.moveBy(const Offset(-80, 0));
    await tester.pump();
    expect(grids, findsNWidgets(2));
    // The first pixels go to telling a sideways drag from a scroll.
    expect(tester.getTopLeft(grids.first).dx, lessThan(left - 60));
    expect(tester.getTopLeft(grids.last).dx, greaterThan(left));

    // Released short of halfway, slowly: it springs back.
    await tester.pump(const Duration(seconds: 1));
    await gesture.up();
    await tester.pumpAndSettle();
    expect(grids, findsOneWidget);
    expect(tester.getTopLeft(grids).dx, left);
    expect(container.read(calendarSelectionProvider).month, month);

    // Past halfway: the next month.
    await tester.drag(grids, const Offset(-250, 0));
    await tester.pumpAndSettle();
    expect(grids, findsOneWidget);
    expect(
      container.read(calendarSelectionProvider).month,
      DateTime(month.year, month.month + 1),
    );
  });

  testWidgets('in the app: pulling down reloads the events', (tester) async {
    final events = FakeEventRepository();
    final container = await pumpLoomia(
      tester,
      size: const Size(390, 844),
      events: events,
    );
    container.read(routerProvider).go(Routes.calendar);
    await tester.pumpAndSettle();
    final loads = events.calls.where((call) => call == 'list()').length;

    await tester.fling(
      find.text('Nothing planned'),
      const Offset(0, 400),
      1000,
    );
    await tester.pumpAndSettle();

    expect(events.calls.where((call) => call == 'list()').length, loads + 1);
  });

  testWidgets('in the app: an event added today shows under today', (
    tester,
  ) async {
    final events = FakeEventRepository();
    final container = await pumpLoomia(
      tester,
      size: const Size(390, 844),
      events: events,
    );
    container.read(routerProvider).go(Routes.calendar);
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('New event'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.descendant(
        of: find.widgetWithText(LabeledField, 'Title'),
        matching: find.byType(TextFormField),
      ),
      'Workshop',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();

    expect(find.text('Workshop'), findsOneWidget);
    expect(events.store.single.day, today());
  });

  testWidgets('changing an event date selects that day', (tester) async {
    // Start with the Calendar on October 15, 2026 with an event that day.
    final event = CalendarEvent(
      id: 'e1',
      title: 'Workshop',
      startsAt: DateTime(2026, 10, 15, 19, 0),
      endsAt: null,
      place: null,
      link: null,
      notes: null,
    );
    final events = FakeEventRepository([event]);
    final container = await pumpLoomia(
      tester,
      size: const Size(390, 844),
      events: events,
    );
    container.read(routerProvider).go(Routes.calendar);
    await tester.pumpAndSettle();

    // Select October 15 (the event's day).
    await tester.tap(find.text('15'));
    await tester.pumpAndSettle();

    // Open the event from the day section.
    await tester.tap(find.text('Workshop'));
    await tester.pumpAndSettle();

    // Edit it.
    await tester.tap(find.byTooltip('Edit event'));
    await tester.pumpAndSettle();

    // Change the date to October 20.
    await tester.tap(find.text('Thu, Oct 15'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('20'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();

    // Save.
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    // Go back to the calendar.
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();

    // The selected day should now be October 20, with the event listed.
    expect(find.text('TUESDAY, OCTOBER 20'), findsOneWidget);
    expect(find.text('Workshop'), findsOneWidget);
  });
}

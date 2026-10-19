import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:loomia/app/router/app_router.dart';
import 'package:loomia/app/router/routes.dart';
import 'package:loomia/app/theme/app_theme.dart';
import 'package:loomia/core/ui/labeled_field.dart';
import 'package:loomia/core/ui/pick_day.dart';
import 'package:loomia/features/calendar/domain/calendar_event.dart';
import 'package:loomia/features/calendar/presentation/calendar_controller.dart';
import 'package:loomia/features/calendar/presentation/calendar_page.dart';
import 'package:loomia/features/calendar/presentation/month_grid.dart';
import 'package:loomia/features/calendar/presentation/week_view.dart';
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
  ValueChanged<CalendarMode>? onMode,
  VoidCallback? onPickTitle,
  bool? desktop,
  Widget? accountAction,
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
            (
              mode: CalendarMode.month,
              month: DateTime(2026, 10),
              day: DateTime(2026, 10, 8),
            ),
        today: DateTime(2026, 10, 7),
        onSelect: onSelect ?? (_) {},
        onShift: onShift ?? (_) {},
        onToday: onToday ?? () {},
        onOpen: onOpen ?? (_) {},
        onAdd: onAdd ?? (_) {},
        onRetry: () {},
        onMode: onMode,
        onPickTitle: onPickTitle,
        desktop: desktop ?? pane != null,
        accountAction: accountAction,
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
            Attendee(personId: 'p1', came: false),
            Attendee(personId: 'p2', came: false),
          ],
        ),
        CalendarEvent(
          id: 'e2',
          title: 'Training',
          startsAt: DateTime(2026, 10, 8, 10),
          doneAt: DateTime(2026, 10, 8, 12),
          attendees: const [Attendee(personId: 'p1', came: true)],
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

  final week = (
    mode: CalendarMode.week,
    month: DateTime(2026, 10),
    day: DateTime(2026, 10, 8),
  );

  testWidgets('the switch asks for the other view', (tester) async {
    final modes = <CalendarMode>[];
    await _pump(tester, onMode: modes.add);

    await tester.tap(find.text('Week'));

    expect(modes, [CalendarMode.week]);
  });

  testWidgets('the title opens its picker, in one line beside the account', (
    tester,
  ) async {
    var picked = 0;
    await _pump(
      tester,
      size: const Size(390, 844),
      selection: (
        mode: CalendarMode.month,
        month: DateTime(2026, 9),
        day: DateTime(2026, 9),
      ),
      onPickTitle: () => picked++,
      accountAction: IconButton(
        onPressed: () {},
        icon: const Icon(Icons.person_rounded),
      ),
    );

    await tester.tap(find.bySemanticsLabel('September 2026, choose a month'));
    expect(picked, 1);
    final title = find.text('September 2026');
    expect(
      tester.getSize(title).height,
      tester.renderObject<RenderParagraph>(title).preferredLineHeight,
    );
  });

  testWidgets('week view: the strip, then every day with its events', (
    tester,
  ) async {
    CalendarEvent? opened;
    await _pump(
      tester,
      selection: week,
      events: [_workshop, _training],
      onOpen: (event) => opened = event,
    );

    // From Sunday in English: October 4 to 10.
    expect(find.text('Oct 4 – Oct 10'), findsOneWidget);
    expect(find.byType(WeekStrip), findsOneWidget);
    expect(find.byType(MonthGrid), findsNothing);
    for (final heading in ['Sun 4', 'Wed 7', 'Thu 8', 'Sat 10']) {
      expect(find.text(heading), findsOneWidget);
    }
    // Today's heading says so; six days have nothing.
    expect(
      find.descendant(
        of: find.ancestor(of: find.text('Wed 7'), matching: find.byType(Row)),
        matching: find.text('Today'),
      ),
      findsOneWidget,
    );
    expect(find.text('Nothing planned'), findsNWidgets(6));
    expect(
      tester.getTopLeft(find.text('New member training')).dy,
      lessThan(tester.getTopLeft(find.text('Essential oils for sleep')).dy),
    );
    await tester.tap(find.text('Essential oils for sleep'));
    expect(opened, _workshop);
  });

  testWidgets('week view: the arrows say week, and the title the week', (
    tester,
  ) async {
    final shifts = <int>[];
    var picked = false;
    await _pump(
      tester,
      selection: week,
      onShift: shifts.add,
      onPickTitle: () => picked = true,
    );

    await tester.tap(find.byTooltip('Next week'));
    await tester.tap(find.byTooltip('Previous week'));
    await tester.tap(find.bySemanticsLabel('Oct 4 – Oct 10, choose a week'));

    expect(shifts, [1, -1]);
    expect(picked, isTrue);
  });

  testWidgets('week view in French: from Monday, its own date order', (
    tester,
  ) async {
    await _pump(tester, selection: week, locale: const Locale('fr'));

    expect(find.text('5 oct. – 11 oct.'), findsOneWidget);
    expect(find.text('lun. 5'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('week view on desktop: 7 columns and no pane', (tester) async {
    CalendarEvent? opened;
    DateTime? selected;
    await _pump(
      tester,
      size: const Size(1440, 900),
      desktop: true,
      selection: week,
      events: [_workshop],
      onOpen: (event) => opened = event,
      onSelect: (day) => selected = day,
    );

    expect(find.byType(WeekColumns), findsOneWidget);
    expect(find.byType(FloatingActionButton), findsNothing);
    // The columns take the width beside the sidebar's place.
    expect(tester.getSize(find.byType(WeekColumns)).width, greaterThan(1000));
    // And run to the bottom of the window, as in the Figma.
    expect(tester.getBottomLeft(find.byType(WeekColumns)).dy, greaterThan(800));

    await tester.tap(find.text('Essential oils for sleep'));
    expect(opened, _workshop);
    await tester.tap(find.text('10'));
    expect(selected, DateTime(2026, 10, 10));
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
      selection: (
        mode: CalendarMode.month,
        month: DateTime(2026, 10),
        day: DateTime(2026, 10, 9),
      ),
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
          Attendee(personId: 'p1', came: false),
          Attendee(personId: 'p2', came: false),
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
      attendees: const [Attendee(personId: 'p1', came: false)],
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

  testWidgets('in the app: two quick swipes turn two months', (tester) async {
    final container = await pumpLoomia(tester, size: const Size(390, 844));
    container.read(routerProvider).go(Routes.calendar);
    await tester.pumpAndSettle();
    final month = container.read(calendarSelectionProvider).month;
    final grids = find.byType(MonthGrid);

    // The second starts while the first is still turning.
    // From the same spot: the page under it is still sliding out.
    final from = tester.getCenter(grids);
    await tester.flingFrom(from, const Offset(-150, 0), 1500);
    // A few frames of the turn, as a finger coming back 80 ms later sees.
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    await tester.flingFrom(from, const Offset(-150, 0), 1500);
    await tester.pumpAndSettle();

    expect(
      container.read(calendarSelectionProvider).month,
      DateTime(month.year, month.month + 2),
    );
  });

  testWidgets('in the app: a short, unhurried swipe still turns', (
    tester,
  ) async {
    final container = await pumpLoomia(tester, size: const Size(390, 844));
    container.read(routerProvider).go(Routes.calendar);
    await tester.pumpAndSettle();
    final month = container.read(calendarSelectionProvider).month;
    final grids = find.byType(MonthGrid);

    // A third of the width at ~200 px/s: a thumb's flick, not a fling.
    await tester.timedDrag(
      grids,
      const Offset(-130, 0),
      const Duration(milliseconds: 650),
    );
    await tester.pumpAndSettle();
    expect(
      container.read(calendarSelectionProvider).month,
      DateTime(month.year, month.month + 1),
    );

    // A nudge springs back.
    await tester.timedDrag(
      grids,
      const Offset(40, 0),
      const Duration(seconds: 1),
    );
    await tester.pumpAndSettle();
    expect(
      container.read(calendarSelectionProvider).month,
      DateTime(month.year, month.month + 1),
    );
  });

  testWidgets('in the app: a swipe that starts leaning down still turns', (
    tester,
  ) async {
    final container = await pumpLoomia(tester, size: const Size(390, 844));
    container.read(routerProvider).go(Routes.calendar);
    await tester.pumpAndSettle();
    final month = container.read(calendarSelectionProvider).month;

    // A thumb's arc: the first pixels go down as much as sideways.
    final gesture = await tester.startGesture(
      tester.getCenter(find.byType(MonthGrid)),
    );
    for (var i = 0; i < 4; i++) {
      await gesture.moveBy(const Offset(-4, 5));
      await tester.pump(const Duration(milliseconds: 16));
    }
    for (var i = 0; i < 10; i++) {
      await gesture.moveBy(const Offset(-25, 2));
      await tester.pump(const Duration(milliseconds: 16));
    }
    await gesture.up();
    await tester.pumpAndSettle();

    expect(
      container.read(calendarSelectionProvider).month,
      DateTime(month.year, month.month + 1),
    );
  });

  testWidgets('in the app: a vertical drag on the month scrolls the page', (
    tester,
  ) async {
    final container = await pumpLoomia(tester, size: const Size(390, 600));
    container.read(routerProvider).go(Routes.calendar);
    await tester.pumpAndSettle();
    final month = container.read(calendarSelectionProvider).month;
    final grids = find.byType(MonthGrid);
    final top = tester.getTopLeft(grids).dy;

    await tester.drag(grids, const Offset(6, -200));
    await tester.pump();

    expect(tester.getTopLeft(grids).dy, lessThan(top));
    await tester.pumpAndSettle();
    expect(container.read(calendarSelectionProvider).month, month);
  });

  testWidgets('in the app: week view swipes by the week, two quick ones too', (
    tester,
  ) async {
    final container = await pumpLoomia(tester, size: const Size(390, 844));
    container.read(routerProvider).go(Routes.calendar);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Week'));
    await tester.pumpAndSettle();
    final day = container.read(calendarSelectionProvider).day;
    final strips = find.byType(WeekStrip);

    // From the same spot: the page under it is still sliding out.
    final from = tester.getCenter(strips);
    await tester.flingFrom(from, const Offset(-150, 0), 1500);
    // A few frames of the turn, as a finger coming back 80 ms later sees.
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    await tester.flingFrom(from, const Offset(-150, 0), 1500);
    await tester.pumpAndSettle();

    final selection = container.read(calendarSelectionProvider);
    expect(selection.mode, CalendarMode.week);
    expect(selection.day, DateTime(day.year, day.month, day.day + 14));
  });

  testWidgets('in the app: the title jumps to a month', (tester) async {
    final container = await pumpLoomia(tester, size: const Size(390, 844));
    container.read(routerProvider).go(Routes.calendar);
    await tester.pumpAndSettle();
    final now = today();

    await tester.tap(find.text(DateFormat.yMMMM('en').format(now)));
    await tester.pumpAndSettle();
    // A year of months; the arrows change the year.
    expect(find.text(DateFormat.MMM('en').format(now)), findsOneWidget);
    await tester.tap(find.byTooltip('Next year'));
    await tester.tap(find.byTooltip('Next year'));
    await tester.pumpAndSettle();
    expect(find.text('${now.year + 2}'), findsOneWidget);
    await tester.tap(find.text('Mar'));
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsNothing);
    expect(
      container.read(calendarSelectionProvider).month,
      DateTime(now.year + 2, 3),
    );
  });

  testWidgets('in the app, desktop: a button reloads the events', (
    tester,
  ) async {
    final events = FakeEventRepository();
    final container = await pumpLoomia(
      tester,
      size: const Size(1440, 900),
      events: events,
    );
    container.read(routerProvider).go(Routes.calendar);
    await tester.pumpAndSettle();
    final loads = events.calls.where((call) => call == 'list()').length;

    await tester.tap(find.byTooltip('Refresh'));
    await tester.pumpAndSettle();

    expect(events.calls.where((call) => call == 'list()').length, loads + 1);
  });

  testWidgets('in the app, desktop: week view has no day pane until an event '
      'opens', (tester) async {
    final events = FakeEventRepository();
    final container = await pumpLoomia(
      tester,
      size: const Size(1440, 900),
      events: events,
    );
    final router = container.read(routerProvider)..go(Routes.calendar);
    await tester.pumpAndSettle();
    final now = today();
    events.store.add(
      CalendarEvent(
        id: 'w1',
        title: 'Workshop this week',
        startsAt: DateTime(now.year, now.month, now.day, 19),
      ),
    );
    container.invalidate(eventsProvider('p@example.com'));
    await tester.tap(find.text('Week'));
    await tester.pumpAndSettle();

    expect(find.byType(CalendarDayPane), findsNothing);
    expect(find.byType(WeekColumns), findsOneWidget);

    await tester.tap(find.text('Workshop this week'));
    await tester.pumpAndSettle();
    expect(
      router.routerDelegate.currentConfiguration.uri.path,
      Routes.eventLocation('w1'),
    );
    expect(find.byType(WeekColumns), findsOneWidget);

    // A day gives the width back to the week.
    await tester.tap(find.text('${now.day}').first);
    await tester.pumpAndSettle();
    expect(
      router.routerDelegate.currentConfiguration.uri.path,
      Routes.calendar,
    );
    expect(find.byType(CalendarDayPane), findsNothing);
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

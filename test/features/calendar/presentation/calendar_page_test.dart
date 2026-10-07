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
import 'package:loomia/l10n/app_localizations.dart';
import 'package:loomia/l10n/localizations_delegates.dart';
import 'package:material_ui/material_ui.dart';

import '../../../app/app_harness.dart';
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
}

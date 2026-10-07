import 'package:flutter_test/flutter_test.dart';
import 'package:loomia/app/router/app_router.dart';
import 'package:loomia/app/router/routes.dart';
import 'package:loomia/app/theme/app_theme.dart';
import 'package:loomia/core/ui/labeled_field.dart';
import 'package:loomia/core/ui/pick_day.dart';
import 'package:loomia/features/calendar/domain/calendar_event.dart';
import 'package:loomia/features/calendar/presentation/calendar_page.dart';
import 'package:loomia/features/calendar/presentation/event_page.dart';
import 'package:loomia/features/calendar/presentation/month_grid.dart';
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
  link: 'https://meet.google.com/abc',
  notes: 'Bring the diffuser',
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
  void Function(String place)? onOpenPlace,
  void Function(Uri link)? onJoin,
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
          onEdit: () {},
          onDelete: () {},
          onOpenPlace: onOpenPlace ?? (_) {},
          onJoin: onJoin ?? (_) {},
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

  testWidgets('a link to an event that is gone says so', (tester) async {
    final container = await pumpLoomia(tester, size: const Size(390, 844));
    container.read(routerProvider).go(Routes.eventLocation('nope'));
    await tester.pumpAndSettle();

    expect(
      find.text("This event isn't in your calendar any more."),
      findsOneWidget,
    );
  });
}

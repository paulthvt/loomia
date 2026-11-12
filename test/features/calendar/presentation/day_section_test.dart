import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loomia/app/theme/app_theme.dart';
import 'package:loomia/features/calendar/domain/calendar_event.dart';
import 'package:loomia/features/calendar/domain/people_ahead.dart';
import 'package:loomia/features/calendar/presentation/calendar_page.dart';
import 'package:loomia/features/contacts/domain/person.dart';
import 'package:loomia/l10n/app_localizations.dart';
import 'package:loomia/l10n/localizations_delegates.dart';
import 'package:material_ui/material_ui.dart';

import '../../../load_fonts.dart';

/// [DaySection]'s timeline with the app's real fonts: what fits a line.
void main() {
  setUpAll(loadAppFonts);

  final day = DateTime(2026, 10, 21);
  final events = [
    CalendarEvent(
      id: 'e',
      title: 'Evening workshop',
      startsAt: DateTime(2026, 10, 21, 19),
      endsAt: DateTime(2026, 10, 21, 21),
    ),
  ];
  final people = [
    for (final id in ['a', 'b', 'c'])
      Person(
        id: id,
        name: 'Person $id',
        stage: Stage.prospect,
        stageSince: DateTime.utc(2026),
        reminders: [
          (
            id: id,
            text: 'Call',
            dueOn: day,
            createdAt: DateTime.utc(2026),
            repeat: null,
          ),
        ],
      ),
  ];

  testWidgets('Figma D: free until and who is due on one line', (tester) async {
    tester.view
      ..physicalSize = const Size(390, 844)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: AppTheme.light,
        home: Scaffold(
          body: SingleChildScrollView(
            child: DaySection(
              events: AsyncData(events),
              day: day,
              now: DateTime(2026, 10, 21, 15, 20),
              timeline: true,
              people: PeopleAhead(
                people: people,
                workflows: const [],
                events: events,
                today: day,
              ),
              onOpen: (_) {},
              onAdd: (_) {},
              onRetry: () {},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final free = find.textContaining('Free until');
    final due = find.text('3 people to follow up').last;
    expect(
      tester.getCenter(due).dy,
      moreOrLessEquals(tester.getCenter(free).dy),
    );
    expect(tester.getTopLeft(due).dx, greaterThan(tester.getTopRight(free).dx));
    expect(find.text('·'), findsOneWidget);
    expect(find.byIcon(Icons.chevron_right_rounded), findsOneWidget);
  });
}

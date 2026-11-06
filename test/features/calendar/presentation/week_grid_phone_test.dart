import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:loomia/app/theme/app_spacing.dart';
import 'package:loomia/app/theme/app_theme.dart';
import 'package:loomia/features/calendar/domain/calendar_event.dart';
import 'package:loomia/features/calendar/presentation/desktop_calendar.dart';
import 'package:loomia/l10n/app_localizations.dart';
import 'package:loomia/l10n/localizations_delegates.dart';
import 'package:material_ui/material_ui.dart';

import '../../../load_fonts.dart';

/// [WeekGrid] on a phone (#448), with the app's real fonts: a 40 dp column's
/// title, and the hour labels, are cut by what they measure.
void main() {
  setUpAll(loadAppFonts);

  // The Figma week: Oct 19-25, Wednesday 21 selected.
  final days = [for (var d = 19; d <= 25; d++) DateTime(2026, 10, d)];
  final events = [
    CalendarEvent(
      id: 'w',
      title: 'Essential oils for sleep',
      startsAt: DateTime(2026, 10, 21, 19),
      endsAt: DateTime(2026, 10, 21, 21),
    ),
    CalendarEvent(
      id: 'f',
      title: 'Product evening',
      startsAt: DateTime(2026, 10, 23, 18),
      endsAt: DateTime(2026, 10, 23, 20),
    ),
    CalendarEvent(
      id: 'm',
      title: 'Coffee with Camille',
      startsAt: DateTime(2026, 10, 19, 10),
    ),
  ];

  Future<void> pumpGrid(
    WidgetTester tester, {
    List<DateTime>? shown,
    bool threeDays = false,
    DateTime? now,
    double textScale = 1,
    ValueChanged<DateTime>? onSelect,
    OpenDay? onDay,
    Size size = const Size(358, 600),
    Locale locale = const Locale('en'),
    bool use24 = true,
    List<CalendarEvent> more = const [],
  }) async {
    tester.view
      ..physicalSize = size
      ..devicePixelRatio = 1;
    tester.platformDispatcher
      ..alwaysUse24HourFormatTestValue = use24
      ..textScaleFactorTestValue = textScale;
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearAllTestValues);
    await tester.pumpWidget(
      MaterialApp(
        locale: locale,
        localizationsDelegates: localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: AppTheme.light,
        home: WeekGrid(
          days: shown ?? days,
          events: [...events, ...more],
          selected: DateTime(2026, 10, 21),
          today: DateTime(2026, 10, 21),
          now: now,
          onOpen: (_) {},
          onDay: onDay ?? (_, _) {},
          onSelect: onSelect ?? (_) {},
          compact: true,
          focus: !threeDays,
          gutter: 32,
          minHour: 28,
          hourHeight: threeDays ? 52 : null,
          scrollToMinute: threeDays && now != null
              ? now.hour * 60 + now.minute
              : null,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Finder header(String day) => find.bySemanticsLabel(RegExp('^$day'));

  testWidgets('mobile week: the selected column is wide, the others 40', (
    tester,
  ) async {
    await pumpGrid(tester);
    expect(
      tester.getSize(header('Wednesday, October 21')).width,
      moreOrLessEquals(358 - 32 - 6 * 40),
    );
    expect(
      tester.getSize(header('Monday, October 19')).width,
      moreOrLessEquals(40),
    );
  });

  testWidgets('mobile week: no time on the cards', (tester) async {
    await pumpGrid(tester);
    final card = find.bySemanticsLabel(
      'Essential oils for sleep, 19:00 to 21:00',
    );
    expect(card, findsOneWidget);
    // An event without an end lasts an hour.
    expect(
      find.bySemanticsLabel('Coffee with Camille, 10:00 to 11:00'),
      findsOneWidget,
    );
    // The 19:00 on screen is the hour axis's, not the card's.
    for (final title in ['Essential oils for sleep', 'Prod…']) {
      final inCard = find.ancestor(
        of: find.text(title),
        matching: find.byType(InkWell),
      );
      expect(
        find.descendant(
          of: inCard.first,
          matching: find.textContaining(RegExp(r'\d:\d\d')),
        ),
        findsNothing,
      );
    }
  });

  testWidgets('mobile week: a narrow title keeps whole words', (tester) async {
    await pumpGrid(tester);
    expect(find.text('Prod…'), findsOneWidget);
    expect(find.text('Product evening'), findsNothing);
    // The wide column wraps it whole.
    expect(find.text('Essential oils for sleep'), findsOneWidget);
  });

  testWidgets('mobile week: tapping a narrow column selects it, the header '
      'opens the day', (tester) async {
    DateTime? selected;
    DateTime? opened;
    await pumpGrid(
      tester,
      onSelect: (day) => selected = day,
      onDay: (day, _) => opened = day,
    );
    final friday = header('Friday, October 23');
    await tester.tapAt(tester.getBottomLeft(friday) + const Offset(20, 40));
    expect(selected, DateTime(2026, 10, 23));
    expect(opened, isNull);

    await tester.tap(friday);
    expect(opened, DateTime(2026, 10, 23));
  });

  testWidgets('mobile week at text scale 2: nothing overflows', (tester) async {
    await pumpGrid(tester, textScale: 2);
    expect(tester.takeException(), isNull);
  });

  testWidgets('3 days: three equal columns, opened at an hour before now', (
    tester,
  ) async {
    final now = DateTime(2026, 10, 21, 11, 30);
    await pumpGrid(
      tester,
      shown: days.sublist(1, 4),
      threeDays: true,
      now: now,
    );
    final widths = [
      for (final day in [
        'Tuesday, October 20',
        'Wednesday, October 21',
        'Thursday, October 22',
      ])
        tester.getSize(header(day)).width,
    ];
    expect(widths[0], moreOrLessEquals((358 - 32) / 3));
    expect(widths[1], moreOrLessEquals(widths[0]));
    expect(widths[2], moreOrLessEquals(widths[0]));
    // The 3 days' range starts at 8:00.
    const firstHour = 8;
    final position = tester
        .state<ScrollableState>(find.byType(Scrollable).last)
        .position;
    expect(
      position.pixels,
      moreOrLessEquals((11 * 60 + 30 - 60 - firstHour * 60) / 60 * 52),
    );
  });

  testWidgets('3 days: an early event loading later opens it again at now', (
    tester,
  ) async {
    final now = DateTime(2026, 10, 21, 11, 30);
    final shown = days.sublist(1, 4);
    await pumpGrid(tester, shown: shown, threeDays: true, now: now);
    await pumpGrid(
      tester,
      shown: shown,
      threeDays: true,
      now: now,
      more: [
        CalendarEvent(
          id: 'early',
          title: 'Early walk',
          startsAt: DateTime(2026, 10, 22, 6),
        ),
      ],
    );
    // The range now starts at 6:00.
    final position = tester
        .state<ScrollableState>(find.byType(Scrollable).last)
        .position;
    expect(
      position.pixels,
      moreOrLessEquals((11 * 60 + 30 - 60 - 6 * 60) / 60 * 52),
    );
  });

  testWidgets('3 days late in the day: opened as far down as it goes', (
    tester,
  ) async {
    await pumpGrid(
      tester,
      shown: days.sublist(1, 4),
      threeDays: true,
      now: DateTime(2026, 10, 21, 15, 30),
    );
    final position = tester
        .state<ScrollableState>(find.byType(Scrollable).last)
        .position;
    expect(position.pixels, position.maxScrollExtent);
    expect(position.pixels, greaterThan(0));
  });

  testWidgets('mobile week under 32 + 7 × 40: equal columns, no overflow', (
    tester,
  ) async {
    await pumpGrid(tester, size: const Size(250, 600));
    expect(tester.takeException(), isNull);
    final monday = tester.getSize(header('Monday, October 19')).width;
    expect(monday, moreOrLessEquals((250 - 32) / 7));
    expect(
      tester.getSize(header('Wednesday, October 21')).width,
      moreOrLessEquals(monday),
    );
  });

  for (final locale in const [Locale('en', 'US'), Locale('fr')]) {
    testWidgets('the hour labels fit the gutter in $locale', (tester) async {
      await pumpGrid(tester, locale: locale, use24: false);
      final hour = DateFormat.j(locale.toString());
      for (var h = 8; h < 22; h++) {
        final label = hour.format(DateTime(2000, 1, 1, h));
        expect(
          tester.getSize(find.text(label)).width,
          lessThanOrEqualTo(32 - AppSpacing.xs / 2),
          reason: label,
        );
      }
    });
  }

  testWidgets('the hour labels follow the 24-hour setting', (tester) async {
    await pumpGrid(tester, locale: const Locale('en', 'US'));
    expect(find.text('14'), findsOneWidget);
    expect(find.text('2 PM'), findsNothing);
    for (var h = 8; h < 22; h++) {
      final label = DateFormat.H('en_US').format(DateTime(2000, 1, 1, h));
      // "19" to "21" are also the headings' dates: the hour's is the last.
      expect(
        tester.getSize(find.text(label).last).width,
        lessThanOrEqualTo(32 - AppSpacing.xs / 2),
        reason: label,
      );
    }
  });
}

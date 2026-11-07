import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:loomia/app/theme/app_spacing.dart';
import 'package:loomia/app/theme/app_theme.dart';
import 'package:loomia/features/calendar/domain/calendar_event.dart';
import 'package:loomia/features/calendar/domain/people_ahead.dart';
import 'package:loomia/features/calendar/presentation/calendar_controller.dart';
import 'package:loomia/features/calendar/presentation/calendar_page.dart';
import 'package:loomia/features/calendar/presentation/desktop_calendar.dart';
import 'package:loomia/features/contacts/domain/person.dart';
import 'package:loomia/features/tasks/domain/task.dart';
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
    List<Task> tasks = const [],
    PeopleAhead people = const PeopleAhead.none(),
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
          tasks: tasks,
          onOpenTask: (_) {},
          people: people,
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

  Task task(
    String id,
    DateTime on, {
    bool done = false,
    TaskTime? at,
    String? title,
  }) => Task(
    id: id,
    title: title ?? 'Task $id',
    note: null,
    dueOn: on,
    doneOn: done ? on : null,
    createdAt: DateTime(2026, 10),
    dueTime: at,
  );

  /// 6 done and 2 open on [on].
  List<Task> eight(DateTime on) => [
    for (var i = 0; i < 6; i++) task('d$i$on', on, done: true),
    task('o1$on', on),
    task('o2$on', on),
  ];

  // The hours' top: under the strip.
  double gridTop(WidgetTester tester) =>
      tester.getTopLeft(find.byType(SingleChildScrollView).last).dy;

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

  testWidgets('mobile week: one chip of open tasks a day, one line high', (
    tester,
  ) async {
    final monday = DateTime(2026, 10, 19);
    final wednesday = DateTime(2026, 10, 21);
    await pumpGrid(tester, tasks: [task('one', wednesday)]);
    final oneTask = gridTop(tester);
    expect(find.text('1 task'), findsOneWidget);

    await pumpGrid(tester, tasks: [...eight(monday), ...eight(wednesday)]);
    // Narrow: the number; wide: the words.
    expect(find.text('2'), findsOneWidget);
    expect(find.text('2 tasks'), findsOneWidget);
    expect(find.textContaining('Task '), findsNothing);
    expect(gridTop(tester), moreOrLessEquals(oneTask));
    expect(tester.takeException(), isNull);
  });

  testWidgets('mobile week: a day with only done tasks has no chip', (
    tester,
  ) async {
    await pumpGrid(tester);
    final none = gridTop(tester);
    await pumpGrid(
      tester,
      tasks: [task('d', DateTime(2026, 10, 21), done: true)],
    );
    expect(find.textContaining('task'), findsNothing);
    expect(find.textContaining('Task'), findsNothing);
    expect(gridTop(tester), moreOrLessEquals(none));
  });

  testWidgets('mobile week: a strip chip opens its day', (tester) async {
    final opened = <DateTime>[];
    await pumpGrid(
      tester,
      onDay: (day, _) => opened.add(day),
      tasks: eight(DateTime(2026, 10, 19)),
    );
    await tester.tap(find.text('2'));
    expect(opened, [DateTime(2026, 10, 19)]);
  });

  testWidgets('3 days: one chip of open tasks a column, one line high', (
    tester,
  ) async {
    final shown = days.sublist(1, 4);
    final wednesday = DateTime(2026, 10, 21);
    await pumpGrid(
      tester,
      shown: shown,
      threeDays: true,
      tasks: [task('one', wednesday)],
    );
    final oneTask = gridTop(tester);

    await pumpGrid(
      tester,
      shown: shown,
      threeDays: true,
      tasks: eight(wednesday),
    );
    expect(find.text('2 tasks'), findsOneWidget);
    expect(find.textContaining('Task '), findsNothing);
    expect(gridTop(tester), moreOrLessEquals(oneTask));
  });

  testWidgets('mobile week: a narrow timed task is its title in whole words, '
      'no ring; the wide one keeps its ring', (tester) async {
    await pumpGrid(
      tester,
      tasks: [
        task(
          'n',
          DateTime(2026, 10, 19),
          at: (hour: 14, minute: 0),
          title: 'Call the supplier',
        ),
      ],
    );
    expect(find.byType(MonthTaskChip), findsNothing);
    expect(find.text('Call the supplier'), findsNothing);
    final cut = tester
        .widget<Text>(find.textContaining(RegExp(r'^Cal.*…$')))
        .data!;
    expect('Call the supplier'.startsWith(cut.replaceAll('…', '')), isTrue);

    await pumpGrid(
      tester,
      tasks: [
        task(
          'w',
          DateTime(2026, 10, 21),
          at: (hour: 14, minute: 0),
          title: 'Call the supplier',
        ),
      ],
    );
    expect(find.byType(MonthTaskChip), findsOneWidget);
    expect(find.text('Call the supplier'), findsOneWidget);
  });

  testWidgets('mobile week at text scale 2: the strip stays one line', (
    tester,
  ) async {
    final monday = DateTime(2026, 10, 19);
    final wednesday = DateTime(2026, 10, 21);
    await pumpGrid(tester, textScale: 2, tasks: [task('one', wednesday)]);
    final oneTask = gridTop(tester);
    await pumpGrid(
      tester,
      textScale: 2,
      tasks: [...eight(monday), ...eight(wednesday)],
    );
    expect(tester.takeException(), isNull);
    expect(gridTop(tester), moreOrLessEquals(oneTask));
  });

  testWidgets('mobile week at 328: the focused column under 60 counts only', (
    tester,
  ) async {
    await pumpGrid(
      tester,
      size: const Size(328, 600),
      tasks: eight(DateTime(2026, 10, 21)),
    );
    expect(tester.takeException(), isNull);
    expect(find.text('2'), findsOneWidget);
    expect(find.text('2 tasks'), findsNothing);
  });

  testWidgets('a screen reader can tap the strip chip, a narrow task and a '
      'header', (tester) async {
    final semantics = tester.ensureSemantics();
    final opened = <DateTime>[];
    await pumpGrid(
      tester,
      onDay: (day, _) => opened.add(day),
      tasks: [
        ...eight(DateTime(2026, 10, 21)),
        task(
          'n',
          DateTime(2026, 10, 19),
          at: (hour: 14, minute: 0),
          title: 'Call the supplier',
          done: true,
        ),
      ],
    );
    expect(
      tester.getSemantics(find.bySemanticsLabel('2 tasks')),
      isSemantics(isButton: true, hasTapAction: true),
    );
    expect(
      tester.getSemantics(find.bySemanticsLabel('Call the supplier')),
      isSemantics(
        isButton: true,
        hasTapAction: true,
        hasCheckedState: true,
        isChecked: true,
      ),
    );
    expect(
      tester.getSemantics(header('Monday, October 19')),
      isSemantics(isButton: true, hasTapAction: true),
    );
    // The action does what the tap does.
    tester.semantics.tap(find.semantics.byLabel('2 tasks'));
    expect(opened, [DateTime(2026, 10, 21)]);
    semantics.dispose();
  });

  /// Five people due on [on].
  PeopleAhead fiveDue(DateTime on) => PeopleAhead(
    people: [
      for (var i = 0; i < 5; i++)
        Person(
          id: 'p$i',
          name: 'Person $i',
          stage: Stage.prospect,
          stageSince: DateTime(2026, 9),
          reminders: [
            (
              id: 'r$i',
              text: 'Call back',
              dueOn: on,
              createdAt: DateTime(2026, 10),
            ),
          ],
        ),
    ],
    workflows: const [],
    today: DateTime(2026, 10, 19),
  );

  for (final threeDays in [false, true]) {
    testWidgets('${threeDays ? '3 days' : 'mobile week at 358'}: tasks and '
        'people together are two counts, whole', (tester) async {
      final semantics = tester.ensureSemantics();
      final wednesday = DateTime(2026, 10, 21);
      await pumpGrid(
        tester,
        shown: threeDays ? days.sublist(1, 4) : null,
        threeDays: threeDays,
        tasks: [task('a', wednesday)],
        people: fiveDue(wednesday),
      );
      expect(tester.takeException(), isNull);
      for (final count in ['1', '5']) {
        expect(
          tester
              .renderObject<RenderParagraph>(find.text(count))
              .didExceedMaxLines,
          isFalse,
          reason: count,
        );
      }
      expect(find.byIcon(Icons.people_outline_rounded), findsOneWidget);
      expect(find.text('1 task'), findsNothing);
      expect(find.text('5 people'), findsNothing);
      // Read in words, one button.
      expect(
        tester.getSemantics(
          find.bySemanticsLabel(
            RegExp('1 task.*5 people to follow up', dotAll: true),
          ),
        ),
        isSemantics(isButton: true, hasTapAction: true),
      );
      semantics.dispose();
    });
  }

  testWidgets('mobile week: a timed task beside an event at its time keeps '
      'its title, no bare ring', (tester) async {
    final wednesday = DateTime(2026, 10, 21);
    await pumpGrid(
      tester,
      more: [
        CalendarEvent(
          id: 'same',
          title: 'Team check-in',
          startsAt: DateTime(2026, 10, 21, 14),
          endsAt: DateTime(2026, 10, 21, 15),
        ),
      ],
      tasks: [
        task(
          'call',
          wednesday,
          at: (hour: 14, minute: 0),
          title: 'Call the supplier',
        ),
      ],
    );
    expect(find.byType(MonthTaskChip), findsNothing);
    expect(find.textContaining(RegExp(r'^Cal')), findsOneWidget);
  });

  Future<void> pumpView(
    WidgetTester tester, {
    Locale locale = const Locale('en'),
    VoidCallback? onToday,
    double width = 390,
  }) async {
    tester.view
      ..physicalSize = Size(width, 844)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        locale: locale,
        localizationsDelegates: localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: AppTheme.light,
        home: CalendarView(
          events: const AsyncData([]),
          selection: (
            mode: CalendarMode.week,
            month: DateTime(2026, 10),
            day: DateTime(2026, 10, 28),
            from: DateTime(2026, 10, 28),
          ),
          today: DateTime(2026, 10, 7),
          onSelect: (_) {},
          onShift: (_) {},
          onToday: onToday ?? () {},
          onOpen: (_) {},
          onAdd: (_) {},
          onAddTask: (_) {},
          onRetry: () {},
          tasks: const [],
          onToggleTask: (_) {},
          onOpenTask: (_) {},
          onMode: (_) {},
          accountAction: IconButton(
            onPressed: () {},
            icon: const Icon(Icons.person_rounded),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('phone: Today is an icon beside the arrows', (tester) async {
    var today = 0;
    await pumpView(tester, onToday: () => today++);
    expect(find.text('Today'), findsNothing);
    await tester.tap(find.byTooltip('Today'));
    expect(today, 1);
    expect(
      tester.getCenter(find.byTooltip('Today')).dy,
      moreOrLessEquals(tester.getCenter(find.byTooltip('Next week')).dy),
    );
  });

  for (final width in const [390.0, 360.0]) {
    testWidgets('phone in French at $width: the title row fits, "Semaine" '
        'whole', (tester) async {
      await pumpView(tester, locale: const Locale('fr'), width: width);
      expect(tester.takeException(), isNull);
      final week = find.text('Semaine');
      expect(week, findsOneWidget);
      expect(
        tester.renderObject<RenderParagraph>(week).didExceedMaxLines,
        isFalse,
      );
    });
  }

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

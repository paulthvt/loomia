import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loomia/app/theme/app_spacing.dart';
import 'package:loomia/app/theme/app_theme.dart';
import 'package:loomia/core/ui/action_item.dart';
import 'package:loomia/features/calendar/domain/calendar_event.dart';
import 'package:loomia/features/calendar/domain/people_ahead.dart';
import 'package:loomia/features/calendar/presentation/calendar_controller.dart';
import 'package:loomia/features/calendar/presentation/calendar_page.dart';
import 'package:loomia/features/calendar/presentation/event_row.dart';
import 'package:loomia/features/calendar/presentation/month_grid.dart';
import 'package:loomia/features/contacts/domain/person.dart';
import 'package:loomia/features/tasks/domain/task.dart';
import 'package:loomia/l10n/app_localizations.dart';
import 'package:loomia/l10n/localizations_delegates.dart';
import 'package:material_ui/material_ui.dart';

final _today = DateTime(2026, 10, 7);
final _day = DateTime(2026, 10, 8);

Reminder _reminder(String id, DateTime on) =>
    (id: id, text: 'Call $id', dueOn: on, createdAt: DateTime.utc(2026));

Person _person(String id, String name, List<Reminder> reminders) => Person(
  id: id,
  name: name,
  stage: Stage.prospect,
  stageSince: DateTime.utc(2026),
  reminders: reminders,
);

/// Five people on the 8th as in the Figma, Léa with two things; one on the
/// 6th, before today.
final _people = [
  _person('b', 'Bruno Keller', [_reminder('b', _day)]),
  _person('c', 'Camille Roux', [_reminder('c', _day)]),
  _person('cl', 'Claire Moreau', [_reminder('cl', _day)]),
  _person('h', 'Hugo Martin', [_reminder('h', _day)]),
  _person('l', 'Léa Fontaine', [_reminder('l1', _day), _reminder('l2', _day)]),
  _person('p', 'Past Person', [_reminder('p', DateTime(2026, 10, 6))]),
];

Future<List<String>> _pump(
  WidgetTester tester, {
  List<Person> people = const [],
  List<CalendarEvent> events = const [],
  List<Task> tasks = const [],
  CalendarMode mode = CalendarMode.month,
  bool desktop = false,
  DateTime? selected,
  ValueChanged<DateTime>? onSelect,
}) async {
  tester.view
    ..physicalSize = desktop ? const Size(1440, 900) : const Size(390, 1600)
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final opened = <String>[];
  await tester.pumpWidget(
    ProviderScope(
      child: MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: AppTheme.light,
        home: CalendarView(
          events: AsyncData(events),
          tasks: tasks,
          people: PeopleAhead(
            people: people,
            workflows: const [],
            events: events,
            today: _today,
          ),
          onOpenPerson: (person) => opened.add(person.id),
          selection: (
            mode: mode,
            month: DateTime(2026, 10),
            day: selected ?? _day,
          ),
          today: _today,
          onSelect: onSelect ?? (_) {},
          onShift: (_) {},
          onToday: () {},
          onOpen: (_) {},
          onAdd: (_) {},
          onAddTask: (_) {},
          onToggleTask: (_) {},
          onOpenTask: (_) {},
          onRetry: () {},
          desktop: desktop,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return opened;
}

Finder _cell(DateTime day) =>
    find.byWidgetPredicate((w) => w is DayCell && w.day == day);

Finder _marker(DateTime day) => find.descendant(
  of: _cell(day),
  matching: find.byKey(const ValueKey('people-marker')),
);

Task _task(String id) => Task(
  id: id,
  title: 'Task $id',
  note: null,
  dueOn: _day,
  doneOn: null,
  createdAt: DateTime(2026, 10, 1),
);

CalendarEvent _event(String id, int hour, {DateTime? on}) {
  final day = on ?? _day;
  return CalendarEvent(
    id: id,
    title: 'Event $id',
    startsAt: DateTime(day.year, day.month, day.day, hour),
  );
}

void main() {
  group('the marker', () {
    testWidgets('under a day with people from today on, none before', (
      tester,
    ) async {
      await _pump(tester, people: _people);

      expect(_marker(_day), findsOneWidget);
      expect(_marker(DateTime(2026, 10, 6)), findsNothing);
      expect(_marker(DateTime(2026, 10, 9)), findsNothing);
      // Round ends, as in the Figma.
      final marker = tester.widget<Container>(_marker(_day));
      expect(
        (marker.decoration! as BoxDecoration).borderRadius,
        BorderRadius.circular(AppRadii.pill),
      );
    });

    testWidgets('beside three dots, and the day keeps its height', (
      tester,
    ) async {
      await _pump(
        tester,
        people: _people,
        events: [_event('1', 9), _event('2', 10), _event('3', 11)],
      );

      expect(_marker(_day), findsOneWidget);
      expect(
        tester.getSize(_cell(_day)),
        tester.getSize(_cell(DateTime(2026, 10, 9))),
      );
    });

    testWidgets('the day says how many people', (tester) async {
      final semantics = tester.ensureSemantics();
      await _pump(tester, people: _people, tasks: [_task('t1')]);

      expect(
        find.bySemanticsLabel(
          'Thursday, October 8, no events, one task, 5 people',
        ),
        findsOneWidget,
      );
      semantics.dispose();
    });

    testWidgets('the week strip has it too', (tester) async {
      await _pump(tester, people: _people, mode: CalendarMode.week);

      expect(_marker(_day), findsOneWidget);
    });
  });

  group('the People block', () {
    testWidgets('folded: the header, Show and how many', (tester) async {
      await _pump(tester, people: _people);

      expect(find.text('PEOPLE'), findsOneWidget);
      expect(find.text('Show'), findsOneWidget);
      expect(find.text('5 people to follow up'), findsOneWidget);
      expect(find.byType(ActionItem), findsNothing);
    });

    testWidgets('Show opens one row per person by name, no ring; Hide '
        'folds it', (tester) async {
      await _pump(tester, people: _people);

      await tester.tap(find.text('Show'));
      await tester.pumpAndSettle();

      final names = [
        for (final row in tester.widgetList<ActionItem>(
          find.byType(ActionItem),
        ))
          row.name,
      ];
      expect(names, [
        'Bruno Keller',
        'Camille Roux',
        'Claire Moreau',
        'Hugo Martin',
        'Léa Fontaine',
      ]);
      expect(find.text('Call l1 · +1'), findsOneWidget);
      expect(find.byIcon(Icons.check_rounded), findsNothing);

      await tester.tap(find.text('Hide'));
      await tester.pumpAndSettle();
      expect(find.byType(ActionItem), findsNothing);
    });

    testWidgets('a row opens the person', (tester) async {
      final opened = await _pump(tester, people: _people);

      await tester.tap(find.text('5 people to follow up'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Hugo Martin'));

      expect(opened, ['h']);
    });

    testWidgets('another day starts folded again', (tester) async {
      final people = [
        ..._people,
        _person('z', 'Zoé', [_reminder('z', DateTime(2026, 10, 9))]),
      ];
      await _pump(tester, people: people);
      await tester.tap(find.text('Show'));
      await tester.pumpAndSettle();

      await _pump(tester, people: people, selected: DateTime(2026, 10, 9));
      expect(find.text('One person to follow up'), findsOneWidget);
      await _pump(tester, people: people);
      expect(find.text('5 people to follow up'), findsOneWidget);
    });

    testWidgets('tasks, then people, then events; not "Nothing planned"', (
      tester,
    ) async {
      await _pump(
        tester,
        people: _people,
        tasks: [_task('t1')],
        events: [_event('e1', 10)],
      );

      final task = tester.getTopLeft(find.text('Task t1')).dy;
      final people = tester.getTopLeft(find.text('PEOPLE')).dy;
      final event = tester.getTopLeft(find.byType(EventRow)).dy;
      expect(task, lessThan(people));
      expect(people, lessThan(event));
    });

    testWidgets('a day with only people is not "Nothing planned"', (
      tester,
    ) async {
      await _pump(tester, people: _people);

      expect(find.text('Nothing planned'), findsNothing);
    });

    testWidgets('the week list folds each day with people', (tester) async {
      await _pump(tester, people: _people, mode: CalendarMode.week);

      expect(find.text('5 people to follow up'), findsOneWidget);
      expect(find.text('Nothing planned'), findsNWidgets(6));
    });

    testWidgets('nobody shows while people are not loaded', (tester) async {
      tester.view
        ..physicalSize = const Size(390, 1600)
        ..devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          theme: AppTheme.light,
          home: DaySection(
            events: const AsyncData(<CalendarEvent>[]),
            day: _day,
            onOpen: (_) {},
            onAdd: (_) {},
            onRetry: () {},
          ),
        ),
      );

      expect(find.text('PEOPLE'), findsNothing);
      expect(find.text('Nothing planned'), findsOneWidget);
    });
  });

  group('desktop', () {
    testWidgets('a month day: "5 people" above its task and event', (
      tester,
    ) async {
      await _pump(
        tester,
        desktop: true,
        people: _people,
        tasks: [_task('t1')],
        events: [_event('e1', 10)],
      );

      final people = tester.getTopLeft(find.text('5 people')).dy;
      expect(people, lessThan(tester.getTopLeft(find.text('Task t1')).dy));
      expect(people, lessThan(tester.getTopLeft(find.text('Event e1')).dy));
    });

    testWidgets('a full day keeps "5 people" and counts the rest in "+N '
        'more"', (tester) async {
      await _pump(
        tester,
        desktop: true,
        people: _people,
        events: [for (var hour = 8; hour < 16; hour++) _event('$hour', hour)],
      );

      expect(find.text('5 people'), findsOneWidget);
      expect(find.textContaining(RegExp(r'^\+\d+ more$')), findsOneWidget);
    });

    testWidgets('the popover lists the people open', (tester) async {
      await _pump(tester, desktop: true, people: _people);

      await tester.tap(find.text('5 people'));
      await tester.pumpAndSettle();

      expect(find.text('PEOPLE'), findsOneWidget);
      expect(find.text('Show'), findsNothing);
      expect(find.text('Hugo Martin'), findsOneWidget);
    });

    testWidgets('the week strip: "5 people" above the day\'s task, with no '
        'task at all too', (tester) async {
      await _pump(
        tester,
        desktop: true,
        mode: CalendarMode.week,
        people: _people,
        tasks: [_task('t1')],
      );
      expect(
        tester.getTopLeft(find.text('5 people')).dy,
        lessThan(tester.getTopLeft(find.text('Task t1')).dy),
      );

      await _pump(
        tester,
        desktop: true,
        mode: CalendarMode.week,
        people: _people,
      );
      expect(find.text('5 people'), findsOneWidget);
    });

    testWidgets('the week strip line opens the day', (tester) async {
      await _pump(
        tester,
        desktop: true,
        mode: CalendarMode.week,
        people: _people,
      );

      await tester.tap(find.text('5 people'));
      await tester.pumpAndSettle();

      expect(find.text('Hugo Martin'), findsOneWidget);
    });
  });
}

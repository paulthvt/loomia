import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loomia/app/router/app_router.dart';
import 'package:loomia/app/router/routes.dart';
import 'package:loomia/app/theme/app_theme.dart';
import 'package:loomia/core/ui/pick_day.dart';
import 'package:loomia/features/auth/data/auth_repository.dart';
import 'package:loomia/features/auth/domain/account.dart';
import 'package:loomia/features/calendar/domain/calendar_event.dart';
import 'package:loomia/features/calendar/presentation/calendar_controller.dart';
import 'package:loomia/features/calendar/presentation/calendar_page.dart';
import 'package:loomia/features/calendar/presentation/event_row.dart';
import 'package:loomia/features/calendar/presentation/month_grid.dart';
import 'package:loomia/features/contacts/domain/people_failure.dart';
import 'package:loomia/features/tasks/data/task_repository.dart';
import 'package:loomia/features/tasks/domain/task.dart';
import 'package:loomia/features/tasks/presentation/task_row.dart';
import 'package:loomia/l10n/app_localizations.dart';
import 'package:loomia/l10n/localizations_delegates.dart';
import 'package:material_ui/material_ui.dart';

import '../../../app/app_harness.dart';
import '../../auth/fake_auth_repository.dart';
import '../../tasks/fake_task_repository.dart';
import '../fake_event_repository.dart';

final _day = DateTime(2026, 10, 8);

CalendarEvent _event(String id, int hour, {DateTime? on}) {
  final day = on ?? _day;
  return CalendarEvent(
    id: id,
    title: 'Event $id',
    startsAt: DateTime(day.year, day.month, day.day, hour),
  );
}

Task _task(String id, {DateTime? on, DateTime? doneOn, int created = 0}) =>
    Task(
      id: id,
      title: 'Task $id',
      note: null,
      dueOn: on ?? _day,
      doneOn: doneOn,
      createdAt: DateTime(2026, 10, 1, created),
    );

/// The view on October 2026, the 8th selected, today the 7th, inside a
/// signed-in ProviderScope so the task sheet can open.
Future<FakeTaskRepository> _pump(
  WidgetTester tester, {
  List<CalendarEvent> events = const [],
  List<Task> tasks = const [],
  CalendarMode mode = CalendarMode.month,
  ValueChanged<DateTime>? onAdd,
  void Function(Task task)? onToggleTask,
}) async {
  tester.view
    ..physicalSize = const Size(390, 1400)
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final auth = FakeAuthRepository()
    ..session = true
    ..account = const Account(firstName: 'Pauline', email: 'p@example.com');
  addTearDown(auth.dispose);
  final repo = FakeTaskRepository();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authRepositoryProvider.overrideWithValue(auth),
        taskRepositoryProvider.overrideWithValue(repo),
      ],
      child: MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: AppTheme.light,
        home: CalendarView(
          events: AsyncData(events),
          tasks: tasks,
          selection: (mode: mode, month: DateTime(2026, 10), day: _day),
          today: DateTime(2026, 10, 7),
          onSelect: (_) {},
          onShift: (_) {},
          onToday: () {},
          onOpen: (_) {},
          onAdd: onAdd ?? (_) {},
          onToggleTask: onToggleTask ?? (_) {},
          onOpenTask: (_) {},
          onRetry: () {},
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return repo;
}

/// The dots under [day]'s number, as `filled` / `hollow`, left to right.
List<String> _dots(WidgetTester tester, DateTime day) {
  final cell = find.byWidgetPredicate((w) => w is DayCell && w.day == day);
  final dots = tester
      .widgetList<Container>(
        find.descendant(of: cell, matching: find.byType(Container)),
      )
      .where((c) => c.constraints?.maxWidth == 6)
      .toList();
  return [
    for (final dot in dots)
      (dot.decoration! as BoxDecoration).color != null ? 'filled' : 'hollow',
  ];
}

void main() {
  testWidgets('an event and an open task: a filled and a hollow dot', (
    tester,
  ) async {
    await _pump(tester, events: [_event('e1', 10)], tasks: [_task('t1')]);

    expect(_dots(tester, _day), ['filled', 'hollow']);
  });

  testWidgets('events first, three dots at most; a done task adds none', (
    tester,
  ) async {
    final ninth = DateTime(2026, 10, 9);
    await _pump(
      tester,
      events: [_event('e1', 9), _event('e2', 10), _event('e3', 11)],
      tasks: [
        _task('t1'),
        _task('t2', on: ninth, doneOn: ninth),
      ],
    );

    expect(_dots(tester, _day), ['filled', 'filled', 'filled']);
    expect(_dots(tester, ninth), isEmpty);
  });

  testWidgets('a task alone: a hollow dot, and the day says so', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await _pump(tester, tasks: [_task('t1', on: DateTime(2026, 10, 9))]);

    expect(_dots(tester, DateTime(2026, 10, 9)), ['hollow']);
    expect(
      find.bySemanticsLabel('Friday, October 9, no events, one task'),
      findsOneWidget,
    );
    semantics.dispose();
  });

  testWidgets('the selected day lists its tasks above its events', (
    tester,
  ) async {
    await _pump(
      tester,
      events: [_event('e1', 10)],
      tasks: [
        _task('done', doneOn: _day),
        _task('open', created: 1),
      ],
    );

    expect(find.byType(TaskRow), findsNWidgets(2));
    final open = tester.getTopLeft(find.text('Task open')).dy;
    final done = tester.getTopLeft(find.text('Task done')).dy;
    final event = tester.getTopLeft(find.byType(EventRow)).dy;
    expect(open, lessThan(done));
    expect(done, lessThan(event));
    expect(
      tester.widget<Text>(find.text('Task done')).style?.decoration,
      TextDecoration.lineThrough,
    );
    expect(
      tester.widget<Text>(find.text('Task open')).style?.decoration,
      isNot(TextDecoration.lineThrough),
    );
    expect(find.text('Nothing planned'), findsNothing);
  });

  testWidgets('a day with only a task is not "Nothing planned"', (
    tester,
  ) async {
    await _pump(tester, tasks: [_task('t1')]);

    expect(find.text('Task t1'), findsOneWidget);
    expect(find.text('Nothing planned'), findsNothing);
  });

  testWidgets('the week list shows a day\'s tasks above its events', (
    tester,
  ) async {
    await _pump(
      tester,
      mode: CalendarMode.week,
      events: [_event('e1', 10)],
      tasks: [_task('t1')],
    );

    expect(
      tester.getTopLeft(find.text('Task t1')).dy,
      lessThan(tester.getTopLeft(find.byType(EventRow)).dy),
    );
  });

  testWidgets('the rings call back with their task', (tester) async {
    final toggled = <String>[];
    await _pump(
      tester,
      tasks: [
        _task('open'),
        _task('done', doneOn: _day),
      ],
      onToggleTask: (task) => toggled.add(task.id),
    );

    await tester.tap(find.byTooltip('Mark "Task open" done'));
    await tester.tap(find.byTooltip('Mark "Task done" not done'));

    expect(toggled, ['open', 'done']);
  });

  for (final (name, entry) in [
    ('the add button', find.byTooltip('Add')),
    ("the day's Add", find.text('Add')),
  ]) {
    testWidgets('$name asks Event or Task', (tester) async {
      final added = <DateTime>[];
      await _pump(tester, onAdd: added.add);

      await tester.tap(entry.first);
      await tester.pumpAndSettle();
      expect(find.text('Event'), findsOneWidget);
      expect(find.text('Task'), findsOneWidget);
      await tester.tap(find.text('Event'));
      await tester.pumpAndSettle();
      expect(added, [_day]);

      await tester.tap(entry.first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Task'));
      await tester.pumpAndSettle();
      expect(find.text('New task'), findsOneWidget);
      expect(find.text('Thursday, October 8'), findsWidgets);
    });
  }

  group('in the app', () {
    late FakeTaskRepository tasks;
    late FakeEventRepository events;

    setUp(() {
      tasks = FakeTaskRepository();
      events = FakeEventRepository();
    });

    Future<void> pumpCalendar(WidgetTester tester) async {
      final container = await pumpLoomia(
        tester,
        size: const Size(390, 1200),
        events: events,
        tasks: tasks,
      );
      container.read(routerProvider).go(Routes.calendar);
      await tester.pumpAndSettle();
    }

    testWidgets('ticking crosses it out in place, with Undo', (tester) async {
      tasks.store['t1'] = _task('t1', on: today());
      await pumpCalendar(tester);

      await tester.tap(find.byTooltip('Mark "Task t1" done'));
      await tester.pumpAndSettle();

      expect(tasks.calls, contains('setDone(t1, ${_iso(today())})'));
      expect(find.text('Done: Task t1'), findsOneWidget);
      expect(
        tester.widget<Text>(find.text('Task t1')).style?.decoration,
        TextDecoration.lineThrough,
      );
    });

    testWidgets('the ring of a done one unticks it, no snackbar', (
      tester,
    ) async {
      tasks.store['t1'] = _task('t1', on: today(), doneOn: today());
      await pumpCalendar(tester);

      await tester.tap(find.byTooltip('Mark "Task t1" not done'));
      await tester.pumpAndSettle();

      expect(tasks.calls, contains('setDone(t1, null)'));
      expect(find.byType(SnackBar), findsNothing);
      expect(
        tester.widget<Text>(find.text('Task t1')).style?.decoration,
        isNot(TextDecoration.lineThrough),
      );
    });

    testWidgets('a failed tasks load shows the events, no tasks', (
      tester,
    ) async {
      tasks
        ..store['t1'] = _task('t1', on: today())
        ..failWith = PeopleFailure.network;
      events.store.add(_event('e1', 10, on: today()));
      await pumpCalendar(tester);

      expect(find.text('Event e1'), findsOneWidget);
      expect(find.text('Task t1'), findsNothing);
    });
  });
}

String _iso(DateTime day) => day.toIso8601String().substring(0, 10);

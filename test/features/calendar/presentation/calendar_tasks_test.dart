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
import 'package:loomia/features/calendar/presentation/desktop_calendar.dart';
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
  ValueChanged<DateTime>? onAddTask,
  void Function(Task task)? onToggleTask,
  void Function(Task task)? onOpenTask,
  bool desktop = false,
}) async {
  tester.view
    ..physicalSize = desktop ? const Size(1440, 900) : const Size(390, 1400)
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
          onAddTask: onAddTask ?? (_) {},
          onToggleTask: onToggleTask ?? (_) {},
          onOpenTask: onOpenTask ?? (_) {},
          onRetry: () {},
          desktop: desktop,
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

  testWidgets('a long title and note are cut at two lines', (tester) async {
    final long = Task(
      id: 'long',
      title: 'Order ' * 50,
      note: 'n' * 300,
      dueOn: _day,
      doneOn: null,
      createdAt: DateTime(2026, 10, 1),
    );
    await _pump(tester, tasks: [long]);

    for (final text in [long.title, long.note!]) {
      final widget = tester.widget<Text>(find.text(text));
      expect(widget.maxLines, 2);
      expect(widget.overflow, TextOverflow.ellipsis);
    }
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
      final addedTasks = <DateTime>[];
      await _pump(tester, onAdd: added.add, onAddTask: addedTasks.add);

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
      expect(addedTasks, [_day]);
    });
  }

  group('on desktop', () {
    testWidgets(
      'a month cell lists its tasks above its events, one "+N more"',
      (tester) async {
        await _pump(
          tester,
          desktop: true,
          events: [for (var i = 0; i < 6; i++) _event('e$i', 9 + i)],
          tasks: [
            _task('done', doneOn: _day),
            _task('open', created: 1),
          ],
        );

        final tasks = tester
            .widgetList<MonthTaskChip>(find.byType(MonthTaskChip))
            .toList();
        expect([for (final chip in tasks) chip.task.id], ['open', 'done']);
        final events = find.byType(MonthEventChip);
        expect(events, findsWidgets);
        expect(
          tester.getTopLeft(find.byType(MonthTaskChip).last).dy,
          lessThan(tester.getTopLeft(events.first).dy),
        );
        final more = 8 - tasks.length - events.evaluate().length;
        expect(more, greaterThan(0));
        expect(find.text('+$more more'), findsOneWidget);
      },
    );

    testWidgets('a task chip: one line; done, struck through', (tester) async {
      final long = Task(
        id: 'long',
        title: 'Order ' * 50,
        note: null,
        dueOn: _day,
        doneOn: _day,
        createdAt: DateTime(2026, 10, 1),
      );
      await _pump(tester, desktop: true, tasks: [long]);

      final title = tester.widget<Text>(
        find.descendant(
          of: find.byType(MonthTaskChip),
          matching: find.text(long.title),
        ),
      );
      expect(title.maxLines, 1);
      expect(title.overflow, TextOverflow.ellipsis);
      expect(title.style?.decoration, TextDecoration.lineThrough);
    });

    testWidgets('a task chip opens its task', (tester) async {
      final opened = <String>[];
      await _pump(
        tester,
        desktop: true,
        tasks: [_task('t1')],
        onOpenTask: (task) => opened.add(task.id),
      );

      await tester.tap(find.byType(MonthTaskChip));
      await tester.pumpAndSettle();

      expect(opened, ['t1']);
      expect(find.byType(TaskRow), findsNothing);
    });

    testWidgets("the day's popover lists its tasks above its events", (
      tester,
    ) async {
      final toggled = <String>[];
      await _pump(
        tester,
        desktop: true,
        events: [_event('e1', 10)],
        tasks: [_task('t1')],
        onToggleTask: (task) => toggled.add(task.id),
      );

      await tester.tap(find.text('8'));
      await tester.pumpAndSettle();

      expect(find.byType(TaskRow), findsOneWidget);
      expect(
        tester.getTopLeft(find.byType(TaskRow)).dy,
        lessThan(tester.getTopLeft(find.byType(EventRow)).dy),
      );
      await tester.tap(find.byTooltip('Mark "Task t1" done'));
      await tester.pumpAndSettle();
      expect(toggled, ['t1']);
      expect(find.byType(TaskRow), findsOneWidget);
    });

    testWidgets("the popover's Add asks Event or Task", (tester) async {
      final addedTasks = <DateTime>[];
      await _pump(tester, desktop: true, onAddTask: addedTasks.add);

      await tester.tap(find.text('8'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Add'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Task'));
      await tester.pumpAndSettle();

      expect(addedTasks, [_day]);
      expect(find.byType(TaskRow), findsNothing);
    });

    testWidgets('the week grid has a strip of tasks under the headers', (
      tester,
    ) async {
      await _pump(
        tester,
        desktop: true,
        mode: CalendarMode.week,
        events: [_event('e1', 10)],
        tasks: [_task('t1')],
      );

      final chip = find.byType(MonthTaskChip);
      expect(chip, findsOneWidget);
      final header = find.text('8');
      expect(
        tester.getTopLeft(chip).dy,
        greaterThan(tester.getBottomLeft(header).dy),
      );
      expect(
        tester.getCenter(chip).dx,
        moreOrLessEquals(tester.getCenter(header).dx, epsilon: 2),
      );
      expect(
        tester.getBottomLeft(chip).dy,
        lessThan(tester.getTopLeft(find.text('Event e1')).dy),
      );
    });

    testWidgets('a week without tasks has no strip', (tester) async {
      Future<double> gridTop(List<Task> tasks) async {
        await _pump(
          tester,
          desktop: true,
          mode: CalendarMode.week,
          tasks: tasks,
        );
        return tester.getTopLeft(find.byType(SingleChildScrollView).last).dy;
      }

      final none = await gridTop([_task('t1', on: DateTime(2026, 10, 20))]);
      expect(find.byType(MonthTaskChip), findsNothing);
      final some = await gridTop([_task('t1')]);
      expect(some, greaterThan(none));
    });
  });

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

    testWidgets('on desktop, the popover crosses a ticked task out', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      tasks.store['t1'] = _task('t1', on: today());
      final container = await pumpLoomia(
        tester,
        size: const Size(1440, 900),
        tasks: tasks,
      );
      container.read(routerProvider).go(Routes.calendar);
      await tester.pumpAndSettle();

      await tester.tap(find.bySemanticsLabel(RegExp(r'no events, one task$')));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Mark "Task t1" done'));
      await tester.pumpAndSettle();

      final row = find.descendant(
        of: find.byType(TaskRow),
        matching: find.text('Task t1'),
      );
      expect(
        tester.widget<Text>(row).style?.decoration,
        TextDecoration.lineThrough,
      );
      semantics.dispose();
    });

    testWidgets('a task saved on another day selects that day', (tester) async {
      await pumpCalendar(tester);

      await tester.tap(find.byTooltip('Add'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Task'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField).first, 'Call back');
      await tester.tap(find.text('Tomorrow'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Save'));
      await tester.pumpAndSettle();

      final tomorrow = DateTime(today().year, today().month, today().day + 1);
      expect(tasks.calls, contains('add(Call back, ${_iso(tomorrow)})'));
      final container = ProviderScope.containerOf(
        tester.element(find.byType(CalendarView)),
      );
      expect(container.read(calendarSelectionProvider).day, tomorrow);
    });

    testWidgets('on desktop, the popover ticks with no Undo, and unticks', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      tasks.store['t1'] = _task('t1', on: today());
      final container = await pumpLoomia(
        tester,
        size: const Size(1440, 900),
        tasks: tasks,
      );
      container.read(routerProvider).go(Routes.calendar);
      await tester.pumpAndSettle();

      await tester.tap(find.bySemanticsLabel(RegExp(r'no events, one task$')));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Mark "Task t1" done'));
      await tester.pumpAndSettle();

      expect(tasks.calls, contains('setDone(t1, ${_iso(today())})'));
      expect(find.byType(SnackBar), findsNothing);

      await tester.tap(find.byTooltip('Mark "Task t1" not done'));
      await tester.pumpAndSettle();

      expect(tasks.calls, contains('setDone(t1, null)'));
      expect(find.byType(TaskRow), findsOneWidget);
      semantics.dispose();
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

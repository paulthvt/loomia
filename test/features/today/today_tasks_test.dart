import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loomia/app/theme/app_theme.dart';
import 'package:loomia/core/ui/load_failed.dart';
import 'package:loomia/core/ui/pick_day.dart';
import 'package:loomia/features/contacts/domain/people_failure.dart';
import 'package:loomia/features/contacts/domain/person.dart';
import 'package:loomia/features/tasks/domain/task.dart';
import 'package:loomia/features/today/domain/due.dart';
import 'package:loomia/features/today/presentation/today_page.dart';
import 'package:loomia/features/workflows/domain/progress.dart';
import 'package:loomia/features/workflows/domain/workflow.dart';
import 'package:loomia/l10n/app_localizations.dart';
import 'package:loomia/l10n/localizations_delegates.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/app_harness.dart';
import '../contacts/fake_people_repository.dart';
import '../tasks/fake_task_repository.dart';

final _now = DateTime(2026, 10, 20, 9);
final _today = DateTime(2026, 10, 20);

final _samples = Workflow(
  id: 'samples',
  stage: Stage.prospect,
  name: 'Samples',
  isDefault: true,
  steps: const [
    WorkflowStep(id: 's1', position: 1, label: 'Send a first message', days: 0),
  ],
);

Person _person(String name) => Person(
  id: name,
  name: name,
  stage: Stage.prospect,
  stageSince: DateTime.utc(2026, 9),
  place: (workflowId: 'samples', atPosition: 1, lastTick: _today),
);

Due _due(String name) => DueStep(
  _person(name),
  OnStep(
    workflow: _samples,
    step: _samples.steps.first,
    index: 1,
    total: 1,
    due: _today,
  ),
);

Task _task({
  required String id,
  required String title,
  String? note,
  required DateTime dueOn,
  DateTime? doneOn,
}) => Task(
  id: id,
  title: title,
  note: note,
  dueOn: dueOn,
  doneOn: doneOn,
  createdAt: DateTime.utc(2026, 10, 1),
);

void main() {
  Future<void> pumpView(
    WidgetTester tester, {
    required List<Due> due,
    required AsyncValue<List<Task>> tasks,
    int? done,
    Size size = const Size(390, 844),
  }) {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    return tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        localizationsDelegates: localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: TodayView(
          due: AsyncData(due),
          tasks: tasks,
          done: done,
          now: _now,
          firstName: 'Pauline',
          onTick: (_) {},
          onTickTask: (_) {},
          onOpen: (_) {},
          onOpenTask: (_) {},
          onAddTask: () {},
          onRetry: () {},
          onRefresh: () async {},
        ),
      ),
    );
  }

  group('TodayView sections', () {
    testWidgets('sections appear in order: People then Tasks', (tester) async {
      final tasks = [_task(id: 't1', title: 'Order flyers', dueOn: _today)];
      await pumpView(tester, due: [_due('Anna')], tasks: AsyncData(tasks));
      await tester.pumpAndSettle();

      final peopleFinder = find.text('PEOPLE');
      final tasksFinder = find.text('TASKS');
      expect(peopleFinder, findsOneWidget);
      expect(tasksFinder, findsOneWidget);

      // People section should come before Tasks section
      final peopleY = tester.getTopLeft(peopleFinder).dy;
      final tasksY = tester.getTopLeft(tasksFinder).dy;
      expect(peopleY, lessThan(tasksY));
    });

    testWidgets('Tasks header shows "Add a task" when no tasks due', (
      tester,
    ) async {
      await pumpView(tester, due: [_due('Anna')], tasks: const AsyncData([]));
      await tester.pumpAndSettle();

      expect(find.text('TASKS'), findsOneWidget);
      expect(find.text('Add a task'), findsOneWidget);
    });

    testWidgets('late task shows its dueLabel chip', (tester) async {
      final tasks = [
        _task(
          id: 't1',
          title: 'Order flyers',
          dueOn: DateTime(2026, 10, 18), // 2 days ago
        ),
      ];
      await pumpView(tester, due: const [], tasks: AsyncData(tasks));
      await tester.pumpAndSettle();

      expect(find.text('2 days late'), findsOneWidget);
    });

    testWidgets('late first, then no time, then by time, the time in a chip', (
      tester,
    ) async {
      final tasks = [
        Task(
          id: 'call',
          title: 'Call the supplier',
          note: null,
          dueOn: _today,
          doneOn: null,
          createdAt: DateTime.utc(2026, 10, 1),
          dueTime: (hour: 14, minute: 0),
        ),
        _task(id: 'flyers', title: 'Order flyers', dueOn: _today),
        _task(
          id: 'late',
          title: 'Print price list',
          dueOn: DateTime(2026, 10, 18),
        ),
      ];
      await pumpView(tester, due: const [], tasks: AsyncData(tasks));
      await tester.pumpAndSettle();

      double y(String text) => tester.getTopLeft(find.text(text)).dy;
      expect(y('Print price list'), lessThan(y('Order flyers')));
      expect(y('Order flyers'), lessThan(y('Call the supplier')));
      expect(find.text('2:00 PM'), findsOneWidget);
    });
  });

  group('TodayView headlines', () {
    testWidgets('people only: unchanged copy', (tester) async {
      await pumpView(tester, due: [_due('Anna')], tasks: const AsyncData([]));

      expect(find.text('One person is worth a message today'), findsOneWidget);
    });

    testWidgets('tasks only: "2 tasks today"', (tester) async {
      final tasks = [
        _task(id: 't1', title: 'Order flyers', dueOn: _today),
        _task(id: 't2', title: 'Call supplier', dueOn: _today),
      ];
      await pumpView(tester, due: const [], tasks: AsyncData(tasks));

      expect(find.text('2 tasks today'), findsOneWidget);
    });

    testWidgets('both: "3 people and 2 tasks today"', (tester) async {
      final tasks = [
        _task(id: 't1', title: 'Order flyers', dueOn: _today),
        _task(id: 't2', title: 'Call supplier', dueOn: _today),
      ];
      await pumpView(
        tester,
        due: [_due('Anna'), _due('Bruno'), _due('Claire')],
        tasks: AsyncData(tasks),
      );

      expect(find.text('3 people and 2 tasks today'), findsOneWidget);
    });
  });

  group('TodayView progress', () {
    testWidgets('bar total counts open tasks', (tester) async {
      final tasks = [
        _task(id: 't1', title: 'Order flyers', dueOn: _today),
        _task(id: 't2', title: 'Call supplier', dueOn: _today),
      ];
      await pumpView(
        tester,
        due: [_due('Anna')],
        tasks: AsyncData(tasks),
        done: 0,
      );

      // 1 person + 2 tasks = 3 total
      expect(find.text('0 of 3 done'), findsOneWidget);
    });

    testWidgets('bar done adds tasks done today', (tester) async {
      final tasks = [
        _task(id: 't1', title: 'Order flyers', dueOn: _today, doneOn: _today),
        _task(id: 't2', title: 'Call supplier', dueOn: _today),
      ];
      await pumpView(
        tester,
        due: [_due('Anna')],
        tasks: AsyncData(tasks),
        done: 2, // 1 task + 1 person
      );

      // 1 due person + 1 open task = 2 remaining, but 2 done (person + task)
      expect(find.text('2 of 4 done'), findsOneWidget);
    });
  });

  group('TodayView up to date', () {
    testWidgets('up to date only with no person row and no task', (
      tester,
    ) async {
      await pumpView(
        tester,
        due: const [],
        tasks: const AsyncData([]),
        done: 0,
      );

      expect(find.text('You are up to date'), findsOneWidget);
      expect(find.text('Add a task'), findsOneWidget);
    });

    testWidgets('no up to date while the tasks load', (tester) async {
      await pumpView(tester, due: const [], tasks: const AsyncLoading());

      expect(find.text('You are up to date'), findsNothing);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      await pumpView(
        tester,
        due: const [],
        tasks: AsyncData([
          _task(id: 't1', title: 'Order flyers', dueOn: _today),
          _task(id: 't2', title: 'Call supplier', dueOn: _today),
        ]),
      );

      expect(find.text('2 tasks today'), findsOneWidget);
      expect(find.text('You are up to date'), findsNothing);
    });

    testWidgets('no people-only headline while the tasks load', (tester) async {
      await pumpView(tester, due: [_due('Anna')], tasks: const AsyncLoading());

      expect(find.text('One person is worth a message today'), findsNothing);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('all done keeps the Tasks section', (tester) async {
      await pumpView(
        tester,
        due: const [],
        tasks: AsyncData([
          _task(id: 't1', title: 'Order flyers', dueOn: _today, doneOn: _today),
        ]),
        done: 1,
      );

      expect(find.text('1 of 1 done'), findsOneWidget);
      expect(find.text('Order flyers'), findsNothing);
      expect(find.text('Add a task'), findsOneWidget);
    });

    testWidgets('not up to date with tasks', (tester) async {
      final tasks = [_task(id: 't1', title: 'Order flyers', dueOn: _today)];
      await pumpView(tester, due: const [], tasks: AsyncData(tasks));

      expect(find.text('You are up to date'), findsNothing);
    });
  });

  group('TodayPage tick behavior', () {
    late FakeTaskRepository taskRepo;
    late FakePeopleRepository peopleRepo;

    setUp(() {
      taskRepo = FakeTaskRepository();
      peopleRepo = FakePeopleRepository([_person('Anna')]);
    });

    Future<void> pumpPage(WidgetTester tester, {Size? size}) => pumpLoomia(
      tester,
      size: size ?? const Size(390, 1400),
      people: peopleRepo,
      tasks: taskRepo,
    );

    testWidgets('tick removes row and shows Undo', (tester) async {
      taskRepo.store['t1'] = _task(
        id: 't1',
        title: 'Order flyers',
        dueOn: _today,
      );
      await pumpPage(tester);

      expect(find.text('Order flyers'), findsOneWidget);
      await tester.tap(find.byTooltip('Mark "Order flyers" done'));
      await tester.pumpAndSettle();

      expect(find.text('Order flyers'), findsNothing);
      expect(find.text('Done: Order flyers'), findsOneWidget);
      expect(find.text('Undo'), findsOneWidget);
      // Counted once, from the task list: Anna is still due.
      expect(find.text('1 of 2 done'), findsOneWidget);
    });

    testWidgets('a ticked task among others stays while its check is drawn '
        'and held, then slides out (#384)', (tester) async {
      taskRepo.store['t1'] = _task(
        id: 't1',
        title: 'Order flyers',
        dueOn: _today,
      );
      taskRepo.store['t2'] = _task(
        id: 't2',
        title: 'Print labels',
        dueOn: _today,
      );
      await pumpPage(tester);
      final row = find.text('Order flyers');
      final x = tester.getTopLeft(row).dx;

      await tester.tap(find.byTooltip('Mark "Order flyers" done'));
      await tester.pump();
      await tester.pump(AppMotion.medium + AppMotion.slow ~/ 2);
      // Drawn and held: not moved, not gone.
      expect(tester.getTopLeft(row).dx, x);

      await tester.pump(AppMotion.slow ~/ 2);
      await tester.pump(AppMotion.slow ~/ 2);
      expect(tester.getTopLeft(row).dx, lessThan(x));
      await tester.pumpAndSettle();
      expect(row, findsNothing);
      expect(find.text('Print labels'), findsOneWidget);
    });

    testWidgets('Undo brings it back', (tester) async {
      taskRepo.store['t1'] = _task(
        id: 't1',
        title: 'Order flyers',
        dueOn: _today,
      );
      await pumpPage(tester);

      await tester.tap(find.byTooltip('Mark "Order flyers" done'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Undo'));
      await tester.pumpAndSettle();

      expect(find.text('Order flyers'), findsOneWidget);
      // Check that setDone was called twice: once to mark done, once to undo
      final setDoneCalls = taskRepo.calls
          .where((call) => call.startsWith('setDone(t1,'))
          .toList();
      expect(setDoneCalls, hasLength(2));
      expect(setDoneCalls.last, 'setDone(t1, null)');
    });

    testWidgets('a repeating task: icon, tick makes the next, Undo takes it', (
      tester,
    ) async {
      final day = today();
      taskRepo.store['t1'] = Task(
        id: 't1',
        title: 'Restock lavender',
        note: null,
        dueOn: day,
        doneOn: null,
        createdAt: DateTime.utc(2026, 10, 1),
        repeat: (
          every: 1,
          unit: RepeatUnit.month,
          from: day,
          until: null,
          scheduledOn: day,
        ),
      );
      await pumpPage(tester);
      expect(find.byIcon(Icons.repeat_rounded), findsOneWidget);

      await tester.tap(find.byTooltip('Mark "Restock lavender" done'));
      await tester.pumpAndSettle();

      expect(taskRepo.calls, contains(startsWith('complete(t1,')));
      expect(find.text('Restock lavender'), findsNothing);
      expect(taskRepo.store, hasLength(2));

      await tester.tap(find.text('Undo'));
      await tester.pumpAndSettle();

      expect(taskRepo.calls, contains('undo(t1)'));
      expect(taskRepo.store.keys, ['t1']);
      expect(find.text('Restock lavender'), findsOneWidget);
    });

    testWidgets('two quick taps write once', (tester) async {
      taskRepo.store['t1'] = _task(
        id: 't1',
        title: 'Order flyers',
        dueOn: _today,
      );
      await pumpPage(tester);
      taskRepo.gate = Completer<void>();

      final button = find.byTooltip('Mark "Order flyers" done');
      await tester.tap(button);
      await tester.pump();
      await tester.tap(button, warnIfMissed: false);
      await tester.pump();
      taskRepo.gate!.complete();
      taskRepo.gate = null;
      await tester.pumpAndSettle();

      final setDoneCalls = taskRepo.calls
          .where((call) => call.startsWith('setDone'))
          .length;
      expect(setDoneCalls, 1);
    });

    testWidgets('tick, Undo, tick ends ticked', (tester) async {
      taskRepo.store['t1'] = _task(
        id: 't1',
        title: 'Order flyers',
        dueOn: _today,
      );
      await pumpPage(tester);

      final button = find.byTooltip('Mark "Order flyers" done');
      await tester.tap(button);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Undo'));
      await tester.pumpAndSettle();
      await tester.tap(button);
      await tester.pumpAndSettle();

      expect(find.text('Order flyers'), findsNothing);
      expect(find.text('Done: Order flyers'), findsOneWidget);
    });

    testWidgets('Undo after fake deleted task: no row, no throw', (
      tester,
    ) async {
      taskRepo.store['t1'] = _task(
        id: 't1',
        title: 'Order flyers',
        dueOn: _today,
      );
      await pumpPage(tester);

      await tester.tap(find.byTooltip('Mark "Order flyers" done'));
      await tester.pumpAndSettle();

      // Deleted on another device - setDone will return null
      taskRepo.store.remove('t1');

      await tester.tap(find.text('Undo'));
      await tester.pumpAndSettle();

      expect(find.text('Order flyers'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  });

  group('TodayPage failed load', () {
    testWidgets('failed tasks load shows LoadFailed in Tasks section only', (
      tester,
    ) async {
      final peopleRepo = FakePeopleRepository([_person('Anna')]);
      final taskRepo = FakeTaskRepository();
      // Not network: offline has its own copy, whatever the section.
      taskRepo.failWith = PeopleFailure.unknown;

      await pumpLoomia(
        tester,
        size: const Size(390, 1400),
        people: peopleRepo,
        tasks: taskRepo,
      );
      await tester.pumpAndSettle();

      // People section should work
      expect(find.text('Anna'), findsOneWidget);
      expect(find.text('PEOPLE'), findsOneWidget);

      // Tasks section shows LoadFailed
      expect(find.text('TASKS'), findsOneWidget);
      expect(find.text("Couldn't load your tasks."), findsOneWidget);
      expect(find.text("Couldn't load today."), findsNothing);
      expect(
        find.descendant(
          of: find.byType(LoadFailed),
          matching: find.text('Try again'),
        ),
        findsOneWidget,
      );
    });
  });
}

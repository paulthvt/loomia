import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loomia/app/router/app_router.dart';
import 'package:loomia/app/router/routes.dart';
import 'package:loomia/core/ui/form_error.dart';
import 'package:loomia/core/ui/tick_ring.dart';
import 'package:loomia/features/calendar/presentation/calendar_page.dart';
import 'package:loomia/features/contacts/domain/people_failure.dart';
import 'package:loomia/features/tasks/domain/task.dart';
import 'package:loomia/features/tasks/presentation/task_page.dart';
import 'package:loomia/features/tasks/presentation/tasks_controller.dart';
import 'package:material_ui/material_ui.dart';

import '../../../app/app_harness.dart';
import '../fake_task_repository.dart';

void main() {
  const phone = Size(390, 844);
  const desktop = Size(1440, 900);

  late FakeTaskRepository tasks;

  setUp(() {
    tasks = FakeTaskRepository([
      Task(
        id: 't1',
        title: 'Call the supplier',
        note: 'Ask about the 10 ml bottles',
        dueOn: DateTime(2026, 10, 22),
        doneOn: null,
        createdAt: DateTime(2026, 10, 1),
        dueTime: (hour: 14, minute: 0),
      ),
    ]);
  });

  group('the task route (#390)', () {
    testWidgets('a page of its own on the phone', (tester) async {
      final container = await pumpLoomia(tester, size: phone, tasks: tasks);
      container.read(routerProvider).go(Routes.taskLocation('t1'));
      await tester.pumpAndSettle();

      expect(find.byType(TaskPage), findsOneWidget);
      expect(find.text('Call the supplier'), findsOneWidget);
    });

    testWidgets('the pane beside the month on desktop', (tester) async {
      final container = await pumpLoomia(tester, size: desktop, tasks: tasks);
      container.read(routerProvider).go(Routes.taskLocation('t1'));
      await tester.pumpAndSettle();

      expect(find.byType(CalendarPage), findsOneWidget);
      expect(find.byType(TaskPane), findsOneWidget);
      expect(find.byType(TaskPage), findsNothing);
    });
  });

  group('the task page (#390)', () {
    Future<ProviderContainer> open(
      WidgetTester tester,
      String id, {
      Size size = phone,
    }) async {
      final container = await pumpLoomia(tester, size: size, tasks: tasks);
      container.read(routerProvider).go(Routes.taskLocation(id));
      await tester.pumpAndSettle();
      return container;
    }

    Future<Task> add({
      required DateTime at,
      bool alert = true,
      bool weekly = false,
    }) {
      final day = DateTime(at.year, at.month, at.day);
      return tasks.add((
        title: 'Call the supplier',
        note: 'Ask about the 10 ml bottles',
        dueOn: day,
        dueTime: (hour: at.hour, minute: at.minute),
        alert: alert,
        repeat: weekly
            ? (
                every: 1,
                unit: RepeatUnit.week,
                from: day,
                until: null,
                scheduledOn: day,
              )
            : null,
      ));
    }

    Finder icon(String label) => find.byWidgetPredicate(
      (widget) => widget is Icon && widget.semanticLabel == label,
    );

    testWidgets('shows the title, day, time with its bell, repeat and note', (
      tester,
    ) async {
      final task = await add(at: DateTime(2026, 12, 3, 14), weekly: true);
      await open(tester, task.id);

      expect(find.text('Call the supplier'), findsOneWidget);
      expect(find.text('Thursday, December 3'), findsOneWidget);
      expect(find.text('2:00 PM'), findsOneWidget);
      expect(icon('Notifies at this time'), findsOneWidget);
      expect(find.textContaining('Every week'), findsOneWidget);
      expect(find.text('Ask about the 10 ml bottles'), findsOneWidget);
      expect(find.byTooltip('Edit'), findsOneWidget);
      expect(find.byTooltip('Delete task'), findsOneWidget);
      expect(find.text('In 15 min'), findsNothing, reason: 'far from its time');
    });

    testWidgets('a bell turned off says so', (tester) async {
      final task = await add(at: DateTime(2026, 12, 3, 14), alert: false);
      await open(tester, task.id);
      expect(icon("Doesn't notify"), findsOneWidget);
    });

    testWidgets('Edit opens the form; the page shows what was saved', (
      tester,
    ) async {
      final task = await add(at: DateTime(2026, 12, 3, 14));
      await open(tester, task.id);

      await tester.tap(find.byTooltip('Edit'));
      await tester.pumpAndSettle();
      expect(find.text('Edit task'), findsOneWidget);
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Call the supplier'),
        'Call the supplier back',
      );
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(find.text('Edit task'), findsNothing);
      expect(find.byType(TaskPage), findsOneWidget);
      expect(find.text('Call the supplier back'), findsOneWidget);
    });

    testWidgets('the form has no postpone and no Delete', (tester) async {
      final task = await add(
        at: DateTime.now().subtract(const Duration(hours: 1)),
      );
      await open(tester, task.id);
      await tester.tap(find.byTooltip('Edit'));
      await tester.pumpAndSettle();

      expect(
        find.descendant(
          of: find.byType(Form),
          matching: find.text('In 15 min'),
        ),
        findsNothing,
      );
      expect(
        find.descendant(of: find.byType(Form), matching: find.text('Delete')),
        findsNothing,
      );
    });

    testWidgets('Delete asks, then the page closes', (tester) async {
      final task = await add(at: DateTime(2026, 12, 3, 14));
      await open(tester, task.id);

      await tester.tap(find.byTooltip('Delete task'));
      await tester.pumpAndSettle();
      expect(find.text('Delete this task?'), findsOneWidget);
      await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
      await tester.pumpAndSettle();

      expect(tasks.calls.last, 'delete(${task.id})');
      expect(find.byType(TaskPage), findsNothing);
    });

    testWidgets('a repeating task: Delete asks this or following', (
      tester,
    ) async {
      final task = await add(at: DateTime(2026, 12, 3, 14), weekly: true);
      await open(tester, task.id);

      await tester.tap(find.byTooltip('Delete task'));
      await tester.pumpAndSettle();
      expect(find.text('Delete a repeating task'), findsOneWidget);
      await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
      await tester.pumpAndSettle();

      expect(
        tasks.calls,
        contains('deleteRepeating(${task.id}, following: false)'),
      );
      expect(find.byType(TaskPage), findsNothing);
    });

    testWidgets('past its time: In 15 min saves, the page stays', (
      tester,
    ) async {
      final task = await add(
        at: DateTime.now().subtract(const Duration(hours: 1)),
        alert: false,
      );
      await open(tester, task.id);
      expect(find.textContaining('It was due at'), findsOneWidget);

      final before = postponed(DateTime.now(), const Duration(minutes: 15));
      await tester.tap(find.text('In 15 min'));
      await tester.pumpAndSettle();
      final after = postponed(DateTime.now(), const Duration(minutes: 15));

      final saved = tasks.store[task.id]!;
      expect([before.time, after.time], contains(saved.dueTime));
      expect([before.day, after.day], contains(saved.dueOn));
      expect(saved.alert, isFalse, reason: 'postponing keeps the bell');
      expect(find.byType(TaskPage), findsOneWidget);
      expect(find.text('In 15 min'), findsNothing);
    });

    testWidgets('a failed postpone says so and keeps the buttons', (
      tester,
    ) async {
      final task = await add(
        at: DateTime.now().subtract(const Duration(hours: 1)),
      );
      await open(tester, task.id);
      tasks.failWith = PeopleFailure.network;

      await tester.tap(find.text('In 15 min'));
      await tester.pumpAndSettle();

      expect(find.byType(FormError), findsOneWidget);
      expect(find.text('In 15 min'), findsOneWidget);
    });

    for (final (name, size) in [('phone', phone), ('desktop', desktop)]) {
      testWidgets('on $name, the ring ticks with Undo and the page stays', (
        tester,
      ) async {
        final task = await add(at: DateTime(2026, 12, 3, 14));
        await open(tester, task.id, size: size);

        await tester.tap(find.byType(TickRing));
        await tester.pumpAndSettle();

        expect(tasks.store[task.id]!.done, isTrue);
        expect(find.text('Undo'), findsOneWidget);
        expect(find.byType(TaskPane), findsOneWidget);
        expect(tester.widget<TickRing>(find.byType(TickRing)).selected, isTrue);
      });
    }

    testWidgets('a repeating task ticked: the page keeps the ticked one', (
      tester,
    ) async {
      final task = await add(at: DateTime(2026, 12, 3, 14), weekly: true);
      await open(tester, task.id);

      await tester.tap(find.byType(TickRing));
      await tester.pumpAndSettle();

      expect(tasks.nextOf, contains(task.id), reason: 'the next one was made');
      expect(find.text('Thursday, December 3'), findsOneWidget);
      expect(tester.widget<TickRing>(find.byType(TickRing)).selected, isTrue);
    });

    testWidgets('an unknown task: not found', (tester) async {
      await open(tester, 'gone');
      expect(
        find.text("This task isn't in your list any more."),
        findsOneWidget,
      );
    });

    testWidgets('deleted elsewhere while shown: not found', (tester) async {
      final task = await add(at: DateTime(2026, 12, 3, 14));
      final container = await open(tester, task.id);

      tasks.store.remove(task.id);
      container.invalidate(tasksProvider('p@example.com'));
      await tester.pumpAndSettle();

      expect(
        find.text("This task isn't in your list any more."),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });
  });
}

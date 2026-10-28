import 'package:flutter_test/flutter_test.dart';
import 'package:loomia/app/router/app_router.dart';
import 'package:loomia/app/router/routes.dart';
import 'package:loomia/features/calendar/presentation/calendar_page.dart';
import 'package:loomia/features/tasks/domain/task.dart';
import 'package:loomia/features/tasks/presentation/task_page.dart';
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
}

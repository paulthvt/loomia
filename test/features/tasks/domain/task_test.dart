import 'package:flutter_test/flutter_test.dart';
import 'package:loomia/features/tasks/data/task_repository.dart';
import 'package:loomia/features/tasks/domain/task.dart';

void main() {
  group('todayTasks', () {
    test('keeps late and today, drops tomorrow and done', () {
      final now = DateTime(2026, 10, 25);
      final tasks = [
        Task(
          id: '1',
          title: 'Late',
          note: null,
          dueOn: DateTime(2026, 10, 20),
          doneOn: null,
          createdAt: DateTime(2026, 10, 20, 10),
        ),
        Task(
          id: '2',
          title: 'Today',
          note: null,
          dueOn: DateTime(2026, 10, 25),
          doneOn: null,
          createdAt: DateTime(2026, 10, 25, 10),
        ),
        Task(
          id: '3',
          title: 'Tomorrow',
          note: null,
          dueOn: DateTime(2026, 10, 26),
          doneOn: null,
          createdAt: DateTime(2026, 10, 26, 10),
        ),
        Task(
          id: '4',
          title: 'Done today',
          note: null,
          dueOn: DateTime(2026, 10, 25),
          doneOn: DateTime(2026, 10, 25),
          createdAt: DateTime(2026, 10, 25, 11),
        ),
      ];

      final result = todayTasks(tasks, now);

      expect(result.map((t) => t.id), ['1', '2']);
    });

    test('orders by due day then creation time', () {
      final now = DateTime(2026, 10, 25);
      final tasks = [
        Task(
          id: '1',
          title: 'Today late',
          note: null,
          dueOn: DateTime(2026, 10, 25),
          doneOn: null,
          createdAt: DateTime(2026, 10, 25, 14),
        ),
        Task(
          id: '2',
          title: 'Yesterday early',
          note: null,
          dueOn: DateTime(2026, 10, 24),
          doneOn: null,
          createdAt: DateTime(2026, 10, 24, 8),
        ),
        Task(
          id: '3',
          title: 'Yesterday late',
          note: null,
          dueOn: DateTime(2026, 10, 24),
          doneOn: null,
          createdAt: DateTime(2026, 10, 24, 16),
        ),
        Task(
          id: '4',
          title: 'Today early',
          note: null,
          dueOn: DateTime(2026, 10, 25),
          doneOn: null,
          createdAt: DateTime(2026, 10, 25, 9),
        ),
      ];

      final result = todayTasks(tasks, now);

      expect(result.map((t) => t.id), ['2', '3', '4', '1']);
    });

    test('row parsing yields local midnights', () {
      final task = taskFromRow({
        'id': '1',
        'title': 'Task',
        'note': 'Note',
        'due_on': '2026-10-25',
        'done_on': '2026-10-25',
        'created_at': '2026-10-25T10:30:00Z',
      });

      expect(task.dueOn, DateTime(2026, 10, 25));
      expect(task.dueOn.isUtc, false);
      expect(task.doneOn, DateTime(2026, 10, 25));
      expect(task.doneOn!.isUtc, false);
    });

    test('compares calendar days only, not timestamps', () {
      final task = Task(
        id: '1',
        title: 'Task',
        note: null,
        dueOn: DateTime(2026, 10, 25),
        doneOn: null,
        createdAt: DateTime(2026, 10, 25),
      );

      // Same day, start of day
      expect(todayTasks([task], DateTime(2026, 10, 25)), [task]);
      // Same day, end of day
      expect(todayTasks([task], DateTime(2026, 10, 25, 23, 59)), [task]);
      // Day before, end of day
      expect(todayTasks([task], DateTime(2026, 10, 24, 23, 59)), isEmpty);
    });

    test('excludes task due day before today', () {
      final task = Task(
        id: '1',
        title: 'Task',
        note: null,
        dueOn: DateTime(2026, 10, 25),
        doneOn: null,
        createdAt: DateTime(2026, 10, 25),
      );

      final result = todayTasks([task], DateTime(2026, 10, 24));

      expect(result, isEmpty);
    });
  });

  group('tasksOn', () {
    test('returns every task due that day', () {
      final day = DateTime(2026, 10, 25);
      final tasks = [
        Task(
          id: '1',
          title: 'Task 1',
          note: null,
          dueOn: DateTime(2026, 10, 24),
          doneOn: null,
          createdAt: DateTime(2026, 10, 24),
        ),
        Task(
          id: '2',
          title: 'Task 2',
          note: null,
          dueOn: DateTime(2026, 10, 25),
          doneOn: null,
          createdAt: DateTime(2026, 10, 25, 10),
        ),
        Task(
          id: '3',
          title: 'Task 3',
          note: null,
          dueOn: DateTime(2026, 10, 25),
          doneOn: DateTime(2026, 10, 25),
          createdAt: DateTime(2026, 10, 25, 11),
        ),
        Task(
          id: '4',
          title: 'Task 4',
          note: null,
          dueOn: DateTime(2026, 10, 26),
          doneOn: null,
          createdAt: DateTime(2026, 10, 26),
        ),
      ];

      final result = tasksOn(tasks, day);

      expect(result.map((t) => t.id), ['2', '3']);
    });

    test('puts open before done', () {
      final day = DateTime(2026, 10, 25);
      final tasks = [
        Task(
          id: '1',
          title: 'Done early',
          note: null,
          dueOn: DateTime(2026, 10, 25),
          doneOn: DateTime(2026, 10, 25),
          createdAt: DateTime(2026, 10, 25, 8),
        ),
        Task(
          id: '2',
          title: 'Open late',
          note: null,
          dueOn: DateTime(2026, 10, 25),
          doneOn: null,
          createdAt: DateTime(2026, 10, 25, 14),
        ),
        Task(
          id: '3',
          title: 'Open early',
          note: null,
          dueOn: DateTime(2026, 10, 25),
          doneOn: null,
          createdAt: DateTime(2026, 10, 25, 9),
        ),
        Task(
          id: '4',
          title: 'Done late',
          note: null,
          dueOn: DateTime(2026, 10, 25),
          doneOn: DateTime(2026, 10, 25),
          createdAt: DateTime(2026, 10, 25, 15),
        ),
      ];

      final result = tasksOn(tasks, day);

      expect(result.map((t) => t.id), ['3', '2', '1', '4']);
    });
  });

  group('openTasksPerDay', () {
    test('skips done tasks', () {
      final tasks = [
        Task(
          id: '1',
          title: 'Open 1',
          note: null,
          dueOn: DateTime(2026, 10, 24),
          doneOn: null,
          createdAt: DateTime(2026, 10, 24),
        ),
        Task(
          id: '2',
          title: 'Open 2',
          note: null,
          dueOn: DateTime(2026, 10, 24),
          doneOn: null,
          createdAt: DateTime(2026, 10, 24),
        ),
        Task(
          id: '3',
          title: 'Done',
          note: null,
          dueOn: DateTime(2026, 10, 24),
          doneOn: DateTime(2026, 10, 24),
          createdAt: DateTime(2026, 10, 24),
        ),
        Task(
          id: '4',
          title: 'Open 3',
          note: null,
          dueOn: DateTime(2026, 10, 25),
          doneOn: null,
          createdAt: DateTime(2026, 10, 25),
        ),
      ];

      final result = openTasksPerDay(tasks);

      expect(result, {DateTime(2026, 10, 24): 2, DateTime(2026, 10, 25): 1});
    });
  });

  test('Task.done', () {
    final open = Task(
      id: '1',
      title: 'Open',
      note: null,
      dueOn: DateTime(2026, 10, 25),
      doneOn: null,
      createdAt: DateTime(2026, 10, 25),
    );
    final done = Task(
      id: '2',
      title: 'Done',
      note: null,
      dueOn: DateTime(2026, 10, 25),
      doneOn: DateTime(2026, 10, 25),
      createdAt: DateTime(2026, 10, 25),
    );

    expect(open.done, false);
    expect(done.done, true);
  });

  test('Task.key', () {
    final task = Task(
      id: 'abc-123',
      title: 'Task',
      note: null,
      dueOn: DateTime(2026, 10, 25),
      doneOn: null,
      createdAt: DateTime(2026, 10, 25),
    );

    expect(task.key, 'task:abc-123');
  });
}

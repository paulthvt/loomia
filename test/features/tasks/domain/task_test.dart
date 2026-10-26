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

  group('a time (#377)', () {
    Task at(
      String id,
      DateTime day, {
      TaskTime? time,
      int created = 0,
      DateTime? doneOn,
    }) => Task(
      id: id,
      title: id,
      note: null,
      dueOn: day,
      doneOn: doneOn,
      createdAt: DateTime(2026, 10, 1, created),
      dueTime: time,
    );
    final today = DateTime(2026, 10, 27);

    test('Today: late first, then no time by creation, then by time', () {
      final tasks = [
        at('call 14:00', today, time: (hour: 14, minute: 0)),
        at('order flyers', today, created: 2),
        at('call 9:30', today, time: (hour: 9, minute: 30)),
        at('late', DateTime(2026, 10, 23), time: (hour: 18, minute: 0)),
        at('restock', today, created: 1),
      ];
      expect(todayTasks(tasks, today).map((t) => t.id), [
        'late',
        'restock',
        'order flyers',
        'call 9:30',
        'call 14:00',
      ]);
    });

    test('a day in the Calendar: the same order, done ones last', () {
      final tasks = [
        at('call 14:00', today, time: (hour: 14, minute: 0)),
        at('done', today, doneOn: today),
        at('order flyers', today),
      ];
      expect(tasksOn(tasks, today).map((t) => t.id), [
        'order flyers',
        'call 14:00',
        'done',
      ]);
    });

    test('postponed rounds up to the minute and moves the day at midnight', () {
      expect(
        postponed(
          DateTime(2026, 10, 27, 14, 0, 40),
          const Duration(minutes: 15),
        ),
        (day: DateTime(2026, 10, 27), time: (hour: 14, minute: 16)),
      );
      expect(
        postponed(DateTime(2026, 10, 27, 14, 5), const Duration(hours: 1)),
        (day: DateTime(2026, 10, 27), time: (hour: 15, minute: 5)),
      );
      expect(
        postponed(DateTime(2026, 10, 27, 23, 50), const Duration(minutes: 15)),
        (day: DateTime(2026, 10, 28), time: (hour: 0, minute: 5)),
      );
      expect(
        postponed(DateTime(2026, 10, 27, 23, 30), const Duration(hours: 1)),
        (day: DateTime(2026, 10, 28), time: (hour: 0, minute: 30)),
      );
    });

    test('due_time round-trips as Postgres time', () {
      expect(timeFromColumn('14:00:00'), (hour: 14, minute: 0));
      expect(timeFromColumn('09:05:00'), (hour: 9, minute: 5));
      expect(timeFromColumn(null), isNull);
      expect(timeColumn((hour: 9, minute: 5)), '09:05');
      expect(timeColumn(null), isNull);
    });

    test('alertNear: open and timed, past or under 15 minutes away', () {
      final task = at('call', today, time: (hour: 14, minute: 0));
      expect(alertNear(task, DateTime(2026, 10, 27, 13, 44)), isFalse);
      expect(alertNear(task, DateTime(2026, 10, 27, 13, 46)), isTrue);
      expect(alertNear(task, DateTime(2026, 10, 27, 16)), isTrue);
      expect(
        alertNear(at('untimed', today), DateTime(2026, 10, 27, 16)),
        isFalse,
      );
      expect(
        alertNear(
          at('done', today, time: (hour: 14, minute: 0), doneOn: today),
          DateTime(2026, 10, 27, 16),
        ),
        isFalse,
      );
    });
  });
}

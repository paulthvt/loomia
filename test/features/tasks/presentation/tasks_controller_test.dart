import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loomia/features/contacts/domain/people_failure.dart';
import 'package:loomia/features/tasks/data/task_repository.dart';
import 'package:loomia/features/tasks/domain/task.dart';
import 'package:loomia/features/tasks/presentation/tasks_controller.dart';

import '../fake_task_repository.dart';

void main() {
  test('add puts the task in the list', () async {
    final repo = FakeTaskRepository();
    final container = ProviderContainer(
      overrides: [taskRepositoryProvider.overrideWithValue(repo)],
    );
    addTearDown(container.dispose);

    await container.read(tasksProvider('p@example.com').future);
    expect(container.read(tasksProvider('p@example.com')).value, isEmpty);

    await container.read(tasksProvider('p@example.com').notifier).add((
      title: 'Buy milk',
      note: null,
      dueOn: DateTime(2026, 10, 25),
      dueTime: null,
      alert: true,
      repeat: null,
    ));

    final tasks = container.read(tasksProvider('p@example.com')).value!;
    expect(tasks, hasLength(1));
    expect(tasks.first.title, 'Buy milk');
    expect(tasks.first.dueOn, DateTime(2026, 10, 25));
  });

  test('setDone then setDone(null) restores it', () async {
    final repo = FakeTaskRepository([
      Task(
        id: '1',
        title: 'Task',
        note: null,
        dueOn: DateTime(2026, 10, 25),
        doneOn: null,
        createdAt: DateTime(2026, 10, 25),
      ),
    ]);
    final container = ProviderContainer(
      overrides: [taskRepositoryProvider.overrideWithValue(repo)],
    );
    addTearDown(container.dispose);

    await container.read(tasksProvider('p@example.com').future);
    final controller = container.read(tasksProvider('p@example.com').notifier);
    var tasks = container.read(tasksProvider('p@example.com')).value!;
    expect(tasks.first.done, false);

    await controller.setDone(tasks.first, DateTime(2026, 10, 25));

    tasks = container.read(tasksProvider('p@example.com')).value!;
    expect(tasks.first.done, true);
    expect(tasks.first.doneOn, DateTime(2026, 10, 25));

    await controller.setDone(tasks.first, null);

    tasks = container.read(tasksProvider('p@example.com')).value!;
    expect(tasks.first.done, false);
    expect(tasks.first.doneOn, null);
  });

  test('setDone on deleted task removes it from state, no throw', () async {
    final repo = FakeTaskRepository([
      Task(
        id: '1',
        title: 'Task',
        note: null,
        dueOn: DateTime(2026, 10, 25),
        doneOn: null,
        createdAt: DateTime(2026, 10, 25),
      ),
    ]);
    final container = ProviderContainer(
      overrides: [taskRepositoryProvider.overrideWithValue(repo)],
    );
    addTearDown(container.dispose);

    await container.read(tasksProvider('p@example.com').future);
    final controller = container.read(tasksProvider('p@example.com').notifier);
    final task = container.read(tasksProvider('p@example.com')).value!.first;

    // Delete behind the controller's back
    repo.store.remove('1');

    await controller.setDone(task, DateTime(2026, 10, 25));

    final tasks = container.read(tasksProvider('p@example.com')).value!;
    expect(tasks, isEmpty);
  });

  test('failing fake leaves state unchanged', () async {
    final repo = FakeTaskRepository([
      Task(
        id: '1',
        title: 'Task',
        note: null,
        dueOn: DateTime(2026, 10, 25),
        doneOn: null,
        createdAt: DateTime(2026, 10, 25),
      ),
    ]);
    final container = ProviderContainer(
      overrides: [taskRepositoryProvider.overrideWithValue(repo)],
    );
    addTearDown(container.dispose);

    await container.read(tasksProvider('p@example.com').future);
    final controller = container.read(tasksProvider('p@example.com').notifier);

    repo.failWith = PeopleFailure.network;

    await expectLater(
      controller.add((
        title: 'New task',
        note: null,
        dueOn: DateTime(2026, 10, 26),
        dueTime: null,
        alert: true,
        repeat: null,
      )),
      throwsA(PeopleFailure.network),
    );

    final tasks = container.read(tasksProvider('p@example.com')).value!;
    expect(tasks, hasLength(1));
    expect(tasks.first.id, '1');
  });

  group('repeating', () {
    final lavender = Task(
      id: 'l',
      title: 'Restock lavender',
      note: null,
      dueOn: DateTime(2026, 11, 5),
      doneOn: null,
      createdAt: DateTime(2026, 10, 3),
      repeat: (
        every: 1,
        unit: RepeatUnit.month,
        from: DateTime(2026, 10, 3),
        until: null,
        scheduledOn: DateTime(2026, 11, 3),
      ),
    );

    Future<(FakeTaskRepository, TasksController, List<Task> Function())>
    openTasks() async {
      final repo = FakeTaskRepository([lavender]);
      final container = ProviderContainer(
        overrides: [taskRepositoryProvider.overrideWithValue(repo)],
      );
      addTearDown(container.dispose);
      await container.read(tasksProvider('p@example.com').future);
      return (
        repo,
        container.read(tasksProvider('p@example.com').notifier),
        () => container.read(tasksProvider('p@example.com')).value!,
      );
    }

    test('a tick goes through complete and shows the next one', () async {
      final (repo, controller, tasks) = await openTasks();

      await controller.setDone(lavender, DateTime(2026, 11, 5));

      expect(repo.calls, contains('complete(l, 2026-11-05)'));
      expect(repo.calls, isNot(contains(startsWith('setDone'))));
      expect(repo.calls.last, 'list');
      final next = tasks().where((t) => !t.done).single;
      expect(next.dueOn, DateTime(2026, 12, 3));
      expect(tasks().singleWhere((t) => t.id == 'l').done, isTrue);
    });

    test('undo goes through undo and the next one goes', () async {
      final (repo, controller, tasks) = await openTasks();
      await controller.setDone(lavender, DateTime(2026, 11, 5));

      await controller.setDone(lavender, null);

      expect(repo.calls, contains('undo(l)'));
      expect(tasks().single.id, 'l');
      expect(tasks().single.done, isFalse);
    });

    test('delete alone makes the next one; following does not', () async {
      final (repo, controller, tasks) = await openTasks();

      await controller.removeRepeating(
        lavender,
        on: DateTime(2026, 11, 1),
        following: false,
      );
      expect(repo.calls, contains('deleteRepeating(l, following: false)'));
      expect(tasks().single.dueOn, DateTime(2026, 12, 3));

      await controller.removeRepeating(
        tasks().single,
        on: DateTime(2026, 11, 1),
        following: true,
      );
      expect(tasks(), isEmpty);
    });
  });
}

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
      )),
      throwsA(PeopleFailure.network),
    );

    final tasks = container.read(tasksProvider('p@example.com')).value!;
    expect(tasks, hasLength(1));
    expect(tasks.first.id, '1');
  });
}

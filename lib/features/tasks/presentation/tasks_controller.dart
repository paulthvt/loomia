import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loomia/features/tasks/data/task_repository.dart';
import 'package:loomia/features/tasks/domain/task.dart';

/// One account's tasks, `tasksProvider(account?.email)`, unordered. Keyed by
/// account for the same reason as `peopleProvider`. No automatic retry: a
/// failed load shows its error with Try again.
final tasksProvider =
    AsyncNotifierProvider.family<TasksController, List<Task>, String?>(
      TasksController.new,
      retry: (error, _) => null,
    );

class TasksController extends AsyncNotifier<List<Task>> {
  TasksController(this.owner);

  /// The email of the account; null when signed out.
  final String? owner;

  @override
  Future<List<Task>> build() async {
    final repository = ref.watch(taskRepositoryProvider);
    if (owner == null) return const [];
    return repository.list();
  }

  /// Saves a new task; the list shows it without a reload. Throws
  /// `PeopleFailure`, and then the list stays as it was.
  Future<Task> add(TaskDraft draft) async {
    final task = await ref.read(taskRepositoryProvider).add(draft);
    _put(task);
    return task;
  }

  /// Saves [id] as [draft]. Throws `PeopleFailure`.
  Future<Task> save(String id, TaskDraft draft) async {
    final task = await ref.read(taskRepositoryProvider).update(id, draft);
    _put(task);
    return task;
  }

  /// Marks [task] done on [on], or reopens it when [on] is null. When the
  /// task was deleted behind the controller's back, removes it from the state,
  /// no throw. Throws `PeopleFailure`, and then the task stays.
  Future<void> setDone(Task task, DateTime? on) async {
    final updated = await ref.read(taskRepositoryProvider).setDone(task.id, on);
    if (!ref.mounted) return;
    if (updated == null) {
      state = AsyncData([
        for (final t in state.value ?? const <Task>[])
          if (t.id != task.id) t,
      ]);
    } else {
      _put(updated);
    }
  }

  /// Throws `PeopleFailure`, and then the task stays.
  Future<void> remove(String id) async {
    await ref.read(taskRepositoryProvider).delete(id);
    if (!ref.mounted) return;
    state = AsyncData([
      for (final task in state.value ?? const <Task>[])
        if (task.id != id) task,
    ]);
  }

  void _put(Task saved) {
    if (!ref.mounted) return;
    state = AsyncData([
      for (final task in state.value ?? const <Task>[])
        if (task.id != saved.id) task,
      saved,
    ]);
  }
}

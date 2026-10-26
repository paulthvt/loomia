import 'dart:async';

import 'package:loomia/features/tasks/data/task_repository.dart';
import 'package:loomia/features/tasks/domain/task.dart';

/// An in-memory `task` table that records calls and fails on demand.
class FakeTaskRepository implements TaskRepository {
  FakeTaskRepository([Iterable<Task> tasks = const []]) {
    for (final task in tasks) {
      store[task.id] = task;
    }
  }

  final Map<String, Task> store = {};

  /// One entry per call, e.g. `add(Buy milk, 2026-10-25)`.
  final List<String> calls = <String>[];

  /// Thrown by calls started while set. Use a `PeopleFailure`.
  Object? failWith;

  /// Calls started while set wait on it.
  Completer<void>? gate;

  var _next = 0;

  Future<void> _record(String call) async {
    calls.add(call);
    final failure = failWith;
    final wait = gate;
    if (wait != null) await wait.future;
    if (failure != null) throw failure;
  }

  @override
  Future<List<Task>> list() async {
    await _record('list');
    return store.values.toList();
  }

  @override
  Future<Task> add(TaskDraft draft) async {
    await _record('add(${draft.title}, ${_day(draft.dueOn)})');
    final task = Task(
      id: 'new-${_next++}',
      title: draft.title,
      note: draft.note,
      dueOn: draft.dueOn,
      doneOn: null,
      createdAt: DateTime.now(),
      repeat: draft.repeat,
    );
    return store[task.id] = task;
  }

  @override
  Future<Task> update(String id, TaskDraft draft) async {
    await _record('update($id, ${draft.title}, ${_day(draft.dueOn)})');
    final old = store[id]!;
    final updated = Task(
      id: old.id,
      title: draft.title,
      note: draft.note,
      dueOn: draft.dueOn,
      doneOn: old.doneOn,
      createdAt: old.createdAt,
      repeat: draft.repeat,
    );
    return store[id] = updated;
  }

  @override
  Future<Task?> setDone(String id, DateTime? on) async {
    await _record('setDone($id, ${on == null ? 'null' : _day(on)})');
    final task = store[id];
    if (task == null) return null;
    final updated = Task(
      id: task.id,
      title: task.title,
      note: task.note,
      dueOn: task.dueOn,
      doneOn: on,
      createdAt: task.createdAt,
      repeat: task.repeat,
    );
    return store[id] = updated;
  }

  /// The task each repeating tick made, by the ticked task's id.
  final Map<String, String> nextOf = {};

  @override
  Future<void> complete(String id, DateTime on) async {
    await _record('complete($id, ${_day(on)})');
    final task = store[id];
    if (task == null || task.done) return;
    store[id] = _with(task, doneOn: on);
    final next = _following(task);
    if (next != null) nextOf[id] = next.id;
  }

  @override
  Future<void> undo(String id) async {
    await _record('undo($id)');
    final task = store[id];
    if (task == null) return;
    store[id] = _with(task, doneOn: null);
    final next = nextOf.remove(id);
    if (next != null) store.remove(next);
  }

  @override
  Future<void> deleteRepeating(
    String id, {
    required DateTime on,
    required bool following,
  }) async {
    await _record('deleteRepeating($id, following: $following)');
    final task = store.remove(id);
    if (task != null && !following) _following(task);
  }

  /// The next task of [task]'s rule, naively one step after its scheduled
  /// day (no month-end clamp: the server does the real maths).
  Task? _following(Task task) {
    final repeat = task.repeat;
    if (repeat == null) return null;
    final s = repeat.scheduledOn;
    final n = repeat.every;
    final day = switch (repeat.unit) {
      RepeatUnit.day => DateTime(s.year, s.month, s.day + n),
      RepeatUnit.week => DateTime(s.year, s.month, s.day + 7 * n),
      RepeatUnit.month => DateTime(s.year, s.month + n, s.day),
      RepeatUnit.year => DateTime(s.year + n, s.month, s.day),
    };
    final next = Task(
      id: 'next-${_next++}',
      title: task.title,
      note: task.note,
      dueOn: day,
      doneOn: null,
      createdAt: DateTime.now(),
      repeat: (
        every: n,
        unit: repeat.unit,
        from: repeat.from,
        until: repeat.until,
        scheduledOn: day,
      ),
    );
    return store[next.id] = next;
  }

  Task _with(Task task, {required DateTime? doneOn}) => Task(
    id: task.id,
    title: task.title,
    note: task.note,
    dueOn: task.dueOn,
    doneOn: doneOn,
    createdAt: task.createdAt,
    repeat: task.repeat,
  );

  @override
  Future<void> delete(String id) async {
    await _record('delete($id)');
    store.remove(id);
  }

  String _day(DateTime day) =>
      '${day.year}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';
}

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loomia/core/supabase/supabase_provider.dart';
import 'package:loomia/features/contacts/data/people_repository.dart';
import 'package:loomia/features/tasks/domain/task.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// The `task` table. Every method throws `PeopleFailure` and nothing else.
/// RLS scopes everything to the user. `owner_id` defaults to them on insert.
class TaskRepository {
  TaskRepository(this._client);

  final SupabaseClient _client;

  static const String _table = 'task';
  static const String _columns =
      'id, title, note, due_on, done_on, created_at, '
      'repeat_every, repeat_unit, repeat_from, repeat_until, scheduled_on, '
      'due_time';

  Future<List<Task>> list() => guardPeople(() async {
    final rows = await _client.from(_table).select(_columns);
    return rows.map(taskFromRow).toList();
  });

  Future<Task> add(TaskDraft draft) => guardPeople(() async {
    final row = await _client
        .from(_table)
        .insert(_draftColumns(draft))
        .select(_columns)
        .single();
    return taskFromRow(row);
  });

  Future<Task> update(String id, TaskDraft draft) => guardPeople(() async {
    final row = await _client
        .from(_table)
        .update(_draftColumns(draft))
        .eq('id', id)
        .select(_columns)
        .single();
    return taskFromRow(row);
  });

  /// Marks [id] done on [on], or reopens it when [on] is null. Returns null
  /// when the row is gone.
  Future<Task?> setDone(String id, DateTime? on) => guardPeople(() async {
    final row = await _client
        .from(_table)
        .update({'done_on': on == null ? null : dayColumn(on)})
        .eq('id', id)
        .select(_columns)
        .maybeSingle();
    return row == null ? null : taskFromRow(row);
  });

  Future<void> delete(String id) => guardPeople(() async {
    await _client.from(_table).delete().eq('id', id);
  });

  /// Ticks a repeating task on [on] and makes the next one on its schedule
  /// (#376). A task already done or gone elsewhere is left as it is: the
  /// caller reloads either way.
  Future<void> complete(String id, DateTime on) =>
      _call('complete_task', {'p_id': id, 'p_on': dayColumn(on)});

  /// Reopens [id] and deletes the task its tick made, unless that one was
  /// ticked or edited since; then [id] comes back without its rule.
  Future<void> undo(String id) => _call('undo_task', {'p_id': id});

  /// Deletes a repeating task. Alone ([following] false), the next one is
  /// made first, as of [on]; with [following], the repeat ends.
  Future<void> deleteRepeating(
    String id, {
    required DateTime on,
    required bool following,
  }) => _call('delete_task', {
    'p_id': id,
    'p_on': dayColumn(on),
    'p_following': following,
  });

  /// The task functions raise P0002 for a task gone or already in that
  /// state: nothing to do.
  Future<void> _call(String function, Map<String, Object?> params) =>
      guardPeople(() async {
        try {
          await _client.rpc<void>(function, params: params);
        } on PostgrestException catch (e) {
          if (e.code != 'P0002') rethrow;
        }
      });
}

Map<String, Object?> _draftColumns(TaskDraft draft) {
  final repeat = draft.repeat;
  return {
    'title': draft.title.trim(),
    'note': draft.note?.trim(),
    'due_on': dayColumn(draft.dueOn),
    'repeat_every': repeat?.every,
    'repeat_unit': repeat?.unit.name,
    'repeat_from': repeat == null ? null : dayColumn(repeat.from),
    'repeat_until': switch (repeat?.until) {
      final until? => dayColumn(until),
      null => null,
    },
    'scheduled_on': repeat == null ? null : dayColumn(repeat.scheduledOn),
    'due_time': timeColumn(draft.dueTime),
  };
}

DateTime? _day(Object? column) =>
    column == null ? null : DateTime.parse(column as String);

Task taskFromRow(Map<String, dynamic> row) => Task(
  id: row['id'] as String,
  title: row['title'] as String,
  note: row['note'] as String?,
  dueOn: DateTime.parse(row['due_on'] as String),
  doneOn: row['done_on'] == null
      ? null
      : DateTime.parse(row['done_on'] as String),
  createdAt: DateTime.parse(row['created_at'] as String),
  repeat: switch (row['repeat_every']) {
    final int every => (
      every: every,
      unit: RepeatUnit.values.byName(row['repeat_unit'] as String),
      from: _day(row['repeat_from'])!,
      until: _day(row['repeat_until']),
      scheduledOn: _day(row['scheduled_on'])!,
    ),
    _ => null,
  },
  dueTime: timeFromColumn(row['due_time'] as String?),
);

/// Postgres `time` ("14:00:00") as a [TaskTime]; null stays null.
TaskTime? timeFromColumn(String? column) {
  if (column == null) return null;
  final parts = column.split(':');
  return (hour: int.parse(parts[0]), minute: int.parse(parts[1]));
}

/// A [TaskTime] as Postgres `time`.
String? timeColumn(TaskTime? time) => time == null
    ? null
    : '${time.hour.toString().padLeft(2, '0')}:'
          '${time.minute.toString().padLeft(2, '0')}';

final taskRepositoryProvider = Provider<TaskRepository>(
  (ref) => TaskRepository(ref.watch(supabaseClientProvider)),
);

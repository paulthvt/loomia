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
  static const String _columns = 'id, title, note, due_on, done_on, created_at';

  Future<List<Task>> list() => guardPeople(() async {
    final rows = await _client.from(_table).select(_columns);
    return rows.map(taskFromRow).toList();
  });

  Future<Task> add(TaskDraft draft) => guardPeople(() async {
    final row = await _client
        .from(_table)
        .insert({
          'title': draft.title.trim(),
          'note': draft.note?.trim(),
          'due_on': dayColumn(draft.dueOn),
        })
        .select(_columns)
        .single();
    return taskFromRow(row);
  });

  Future<Task> update(String id, TaskDraft draft) => guardPeople(() async {
    final row = await _client
        .from(_table)
        .update({
          'title': draft.title.trim(),
          'note': draft.note?.trim(),
          'due_on': dayColumn(draft.dueOn),
        })
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
}

Task taskFromRow(Map<String, dynamic> row) => Task(
  id: row['id'] as String,
  title: row['title'] as String,
  note: row['note'] as String?,
  dueOn: DateTime.parse(row['due_on'] as String),
  doneOn: row['done_on'] == null
      ? null
      : DateTime.parse(row['done_on'] as String),
  createdAt: DateTime.parse(row['created_at'] as String),
);

final taskRepositoryProvider = Provider<TaskRepository>(
  (ref) => TaskRepository(ref.watch(supabaseClientProvider)),
);

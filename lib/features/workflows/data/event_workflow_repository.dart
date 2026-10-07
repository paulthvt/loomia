import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loomia/core/supabase/supabase_provider.dart';
import 'package:loomia/features/contacts/data/people_repository.dart';
import 'package:loomia/features/contacts/domain/person.dart';
import 'package:loomia/features/workflows/domain/event_workflow.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// The `event_workflow` and `event_workflow_step` tables. Every method
/// throws [PeopleFailure] and nothing else. RLS scopes everything to the
/// user. They are seeded with the person workflows (`seed_workflows`).
class EventWorkflowRepository {
  EventWorkflowRepository(this._client);

  final SupabaseClient _client;

  static const String _columns = '*, event_workflow_step(*)';

  /// By name.
  Future<List<EventWorkflow>> list() => guardPeople(() async {
    final rows = await _client
        .from('event_workflow')
        .select(_columns)
        .order('name');
    return rows.map(eventWorkflowFromRow).toList();
  });

  /// A new one with no steps, and every stage keeping their workflow.
  Future<EventWorkflow> create(String name) => guardPeople(() async {
    final row = await _client
        .from('event_workflow')
        .insert({'name': name})
        .select(_columns)
        .single();
    return eventWorkflowFromRow(row);
  });

  Future<void> rename(String id, String name) => guardPeople(() async {
    await _client.from('event_workflow').update({'name': name}).eq('id', id);
  });

  /// Every stage: one missing from [followUps] keeps their workflow.
  Future<void> setFollowUps(String id, Map<Stage, String> followUps) =>
      guardPeople(() async {
        await _client
            .from('event_workflow')
            .update(followUpsToRow(followUps))
            .eq('id', id);
      });

  /// Its steps go with it; its events keep their title, without a checklist.
  Future<void> delete(String id) => guardPeople(() async {
    await _client.from('event_workflow').delete().eq('id', id);
  });

  Future<void> addStep(
    String eventWorkflowId, {
    required String label,
    required int days,
    String? note,
  }) => guardPeople(() async {
    await _client.from('event_workflow_step').insert({
      'event_workflow_id': eventWorkflowId,
      'label': label,
      'days': days,
      'note': note,
    });
  });

  Future<void> updateStep(
    String stepId, {
    required String label,
    required int days,
    String? note,
  }) => guardPeople(() async {
    await _client
        .from('event_workflow_step')
        .update({'label': label, 'days': days, 'note': note})
        .eq('id', stepId);
  });

  Future<void> removeStep(String stepId) => guardPeople(() async {
    await _client.from('event_workflow_step').delete().eq('id', stepId);
  });
}

final eventWorkflowRepositoryProvider = Provider<EventWorkflowRepository>(
  (ref) => EventWorkflowRepository(ref.watch(supabaseClientProvider)),
);

/// The three stage columns of [row], the missing ones left out.
Map<Stage, String> followUpsFromRow(Map<String, dynamic> row) => {
  for (final stage in Stage.values)
    if (row[followUpColumn(stage)] case final String id) stage: id,
};

/// Every stage column, null for "keep their workflow".
Map<String, Object?> followUpsToRow(Map<Stage, String> followUps) => {
  for (final stage in Stage.values) followUpColumn(stage): followUps[stage],
};

EventWorkflow eventWorkflowFromRow(Map<String, dynamic> row) => EventWorkflow(
  id: row['id'] as String,
  name: row['name'] as String,
  followUps: followUpsFromRow(row),
  steps: [
    for (final step
        in ((row['event_workflow_step'] as List?) ?? const [])
            .cast<Map<String, dynamic>>())
      EventWorkflowStep(
        id: step['id'] as String,
        label: step['label'] as String,
        days: step['days'] as int,
        note: step['note'] as String?,
      ),
  ],
);

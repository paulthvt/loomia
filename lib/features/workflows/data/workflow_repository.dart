import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loomia/core/supabase/supabase_provider.dart';
import 'package:loomia/features/contacts/data/people_repository.dart';
import 'package:loomia/features/contacts/domain/people_failure.dart';
import 'package:loomia/features/contacts/domain/person.dart';
import 'package:loomia/features/workflows/domain/workflow.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// The `workflow` and `workflow_step` tables. Every method throws
/// [PeopleFailure] and nothing else. RLS scopes everything to the user.
class WorkflowRepository {
  WorkflowRepository(this._client);

  final SupabaseClient _client;

  Future<List<Workflow>> list() => guardPeople(() async {
    final rows = await _client.from('workflow').select('*, workflow_step(*)');
    return rows.map(workflowFromRow).toList();
  });

  /// The default workflows in [lang], once per account, ever: the server
  /// no-ops after the first time. Also starts everyone without a workflow on
  /// their stage's default.
  Future<void> seed(String lang, DateTime today) => guardPeople(() async {
    await _client.rpc<void>(
      'seed_workflows',
      params: {'p_lang': lang, 'p_today': dayColumn(today)},
    );
  });

  /// A new workflow with no steps, not the default.
  Future<Workflow> create(Stage stage, String name) => guardPeople(() async {
    final row = await _client
        .from('workflow')
        .insert({'stage': stage.name, 'name': name})
        .select('*, workflow_step(*)')
        .single();
    return workflowFromRow(row);
  });

  Future<void> rename(String id, String name) => guardPeople(() async {
    await _client.from('workflow').update({'name': name}).eq('id', id);
  });

  /// Its steps go with it; its people are left with no workflow.
  Future<void> delete(String id) => guardPeople(() async {
    await _client.from('workflow').delete().eq('id', id);
  });

  /// On: the default of its stage, instead of any other. Off: the stage has
  /// none.
  Future<void> setDefault(String id, bool on) => guardPeople(() async {
    await _client.rpc<void>(
      'set_default',
      params: {'p_workflow': id, 'p_on': on},
    );
  });

  /// [position] from `positionAt`.
  Future<void> addStep(
    String workflowId, {
    required String label,
    required int days,
    String? note,
    required num position,
    bool loyaltySetup = false,
  }) => guardPeople(() async {
    await _client.from('workflow_step').insert({
      'workflow_id': workflowId,
      'position': position,
      'label': label,
      'days': days,
      'note': note,
      'loyalty_setup': loyaltySetup,
    });
  });

  Future<void> updateStep(
    String stepId, {
    required String label,
    required int days,
    String? note,
    required bool loyaltySetup,
  }) => guardPeople(() async {
    await _client
        .from('workflow_step')
        .update({
          'label': label,
          'days': days,
          'note': note,
          'loyalty_setup': loyaltySetup,
        })
        .eq('id', stepId);
  });

  /// People follow the position, not the step: see `current_step_id`.
  Future<void> moveStep(String stepId, num position) => guardPeople(() async {
    await _client
        .from('workflow_step')
        .update({'position': position})
        .eq('id', stepId);
  });

  Future<void> removeStep(String stepId) => guardPeople(() async {
    await _client.from('workflow_step').delete().eq('id', stepId);
  });
}

final workflowRepositoryProvider = Provider<WorkflowRepository>(
  (ref) => WorkflowRepository(ref.watch(supabaseClientProvider)),
);

Workflow workflowFromRow(Map<String, dynamic> row) => Workflow(
  id: row['id'] as String,
  stage:
      Stage.values.asNameMap()[row['stage']] ?? (throw PeopleFailure.unknown),
  name: row['name'] as String,
  isDefault: row['is_default'] as bool,
  steps: [
    for (final step
        in (row['workflow_step'] as List).cast<Map<String, dynamic>>())
      WorkflowStep(
        id: step['id'] as String,
        position: step['position'] as num,
        label: step['label'] as String,
        days: step['days'] as int,
        note: step['note'] as String?,
        loyaltySetup: step['loyalty_setup'] as bool,
      ),
  ],
);

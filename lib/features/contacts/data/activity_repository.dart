import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loomia/core/supabase/supabase_provider.dart';
import 'package:loomia/features/contacts/data/people_repository.dart';
import 'package:loomia/features/contacts/domain/activity.dart';
import 'package:loomia/features/contacts/domain/people_failure.dart';
import 'package:loomia/features/contacts/domain/person.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// The `activity` table: every person's history. Every method throws
/// [PeopleFailure] and nothing else.
///
/// RLS scopes every query to the signed-in user and refuses stage entries,
/// which only the database writes.
class ActivityRepository {
  ActivityRepository(this._client);

  final SupabaseClient _client;

  static const String _table = 'activity';

  /// Unordered: the controller sorts by the local day, which the server
  /// doesn't know.
  // ponytail: whole history in one fetch, paginate when a person has hundreds.
  Future<List<Activity>> list(String personId) => guardPeople(() async {
    final rows = await _client.from(_table).select().eq('person_id', personId);
    return rows.map(activityFromRow).toList();
  });

  Future<Activity> add(String personId, ActivityDraft draft) =>
      guardPeople(() async {
        final row = await _client
            .from(_table)
            .insert(activityDraftToRow(personId, draft))
            .select()
            .single();
        return activityFromRow(row);
      });

  /// The user's own order, with no person. Needs an amount (the database
  /// refuses one without).
  Future<Activity> addOwnOrder(ActivityDraft draft) => guardPeople(() async {
    assert(
      draft.kind == ActivityKind.order && draft.amount != null,
      'An own order needs an amount',
    );
    final row = await _client
        .from(_table)
        .insert(activityDraftToRow(null, draft))
        .select()
        .single();
    return activityFromRow(row);
  });

  /// What an edit may change: the day, the text and an order's amount. The
  /// database refuses any other column, and stage entries altogether.
  Future<Activity> update(String id, ActivityDraft draft) =>
      guardPeople(() async {
        final row = await _client
            .from(_table)
            .update(activityEditToRow(draft))
            .eq('id', id)
            .select()
            .single();
        return activityFromRow(row);
      });

  /// Every order in [month], contacts' and own, latest day first, then
  /// latest made.
  Future<List<MonthOrder>> ordersIn(DateTime month) => guardPeople(() async {
    final rows = await _client
        .from(_table)
        .select('*, person(name)')
        .eq('kind', ActivityKind.order.name)
        .gte('happened_on', dayColumn(DateTime(month.year, month.month)))
        .lt('happened_on', dayColumn(DateTime(month.year, month.month + 1)))
        .order('happened_on', ascending: false)
        .order('created_at', ascending: false);
    return rows.map(monthOrderFromRow).toList();
  });

  Future<void> delete(String id) =>
      guardPeople(() => _client.from(_table).delete().eq('id', id));
}

final activityRepositoryProvider = Provider<ActivityRepository>(
  (ref) => ActivityRepository(ref.watch(supabaseClientProvider)),
);

Activity activityFromRow(Map<String, dynamic> row) {
  final stage = row['stage'] as String?;
  return Activity(
    id: row['id'] as String,
    personId: row['person_id'] as String?,
    kind:
        ActivityKind.values.asNameMap()[row['kind']] ??
        (throw PeopleFailure.unknown),
    // A bare date parses as local midnight, which is what a day is here.
    happenedOn: DateTime.parse(row['happened_on'] as String),
    text: row['text'] as String?,
    amount: (row['amount'] as num?)?.toDouble(),
    stage: stage == null
        ? null
        : Stage.values.asNameMap()[stage] ?? (throw PeopleFailure.unknown),
    createdAt: DateTime.parse(row['created_at'] as String),
  );
}

Map<String, dynamic> activityDraftToRow(String? personId, ActivityDraft draft) {
  assert(
    draft.kind.byUser,
    'Only the database writes stage entries; step entries come from complete_step',
  );
  return {
    'person_id': personId,
    'kind': draft.kind.name,
    ...activityEditToRow(draft),
  };
}

/// The columns an edit writes; [activityDraftToRow] adds whose and what kind.
/// Any kind, steps included: the kind itself is never written.
Map<String, dynamic> activityEditToRow(ActivityDraft draft) {
  assert(
    draft.amount == null || draft.kind == ActivityKind.order,
    'Only an order has an amount',
  );
  final text = draft.text.trim();
  return {
    'happened_on': dayColumn(draft.happenedOn),
    'text': text.isEmpty ? null : text,
    'amount': draft.amount,
  };
}

MonthOrder monthOrderFromRow(Map<String, dynamic> row) => (
  order: activityFromRow(row),
  personName: (row['person'] as Map<String, dynamic>?)?['name'] as String?,
);

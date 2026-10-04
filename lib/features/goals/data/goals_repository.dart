import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loomia/core/supabase/supabase_provider.dart';
import 'package:loomia/features/contacts/data/people_repository.dart';
import 'package:loomia/features/contacts/domain/people_failure.dart';
import 'package:loomia/features/goals/domain/month_plan.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// The `month_plan` table and the goal functions. Every method throws
/// [PeopleFailure] and nothing else. RLS scopes everything to the user.
class GoalsRepository {
  GoalsRepository(this._client);

  final SupabaseClient _client;

  /// Latest month first.
  Future<List<MonthPlan>> plans() => guardPeople(() async {
    final rows = await _client
        .from('month_plan')
        .select()
        .order('month', ascending: false);
    return rows.map(monthPlanFromRow).toList();
  });

  /// Creates or updates the plan's month with its targets and forecast.
  Future<MonthPlan> saveTargets(MonthPlan plan) => guardPeople(() async {
    final row = await _client
        .from('month_plan')
        .upsert(targetsToRow(plan), onConflict: 'owner_id,month')
        .select()
        .single();
    return monthPlanFromRow(row);
  });

  /// What [month] did so far, counted by the server in the device's month.
  Future<Progress> progress(DateTime month) => guardPeople(() async {
    final row = await _client
        .rpc<Object?>('month_progress', params: _monthParams(month))
        .single();
    return progressFromRow(row);
  });

  /// Customers likely to set up loyalty in [month].
  Future<int> forecast(DateTime month) => guardPeople(
    () => _client.rpc<int>(
      'loyalty_forecast',
      params: {'p_month': dayColumn(month)},
    ),
  );

  /// Freezes [month]'s progress with the two figures only the company
  /// knows. A month closes once: a second close is a failure.
  Future<MonthPlan> close(
    DateTime month, {
    double? teamVolume,
    String? level,
  }) => guardPeople(() async {
    final row = await _client
        .rpc<Object?>(
          'close_month',
          params: {
            ..._monthParams(month),
            'p_team_volume_actual': teamVolume,
            'p_level_actual': level,
          },
        )
        .select()
        .single();
    return monthPlanFromRow(row);
  });

  Map<String, Object?> _monthParams(DateTime month) {
    final (:starts, :ends) = monthBounds(month);
    return {
      'p_month': dayColumn(month),
      'p_starts': starts.toIso8601String(),
      'p_ends': ends.toIso8601String(),
    };
  }
}

final goalsRepositoryProvider = Provider<GoalsRepository>(
  (ref) => GoalsRepository(ref.watch(supabaseClientProvider)),
);

/// [month]'s local midnights, the 1st and the next 1st, as UTC: the server
/// counts people added between them, whatever its own time zone.
({DateTime starts, DateTime ends}) monthBounds(DateTime month) => (
  starts: DateTime(month.year, month.month).toUtc(),
  ends: DateTime(month.year, month.month + 1).toUtc(),
);

double? _number(Object? value) => (value as num?)?.toDouble();

MonthPlan monthPlanFromRow(Map<String, dynamic> row) {
  final closedAt = switch (row['closed_at']) {
    final String at => DateTime.parse(at),
    _ => null,
  };
  return MonthPlan(
    // A bare date parses as local midnight.
    month: DateTime.parse(row['month'] as String),
    ownVolumeTarget: _number(row['own_volume_target']),
    teamVolumeTarget: _number(row['team_volume_target']),
    levelTarget: row['level_target'] as String?,
    prospectsTarget: row['prospects_target'] as int?,
    customersTarget: row['customers_target'] as int?,
    teamMembersTarget: row['team_members_target'] as int?,
    loyaltyTarget: row['loyalty_target'] as int?,
    loyaltyForecast: row['loyalty_forecast'] as int?,
    actual: closedAt == null
        ? null
        : Progress(
            ownVolume: _number(row['own_volume_actual']) ?? 0,
            prospects: row['prospects_actual'] as int? ?? 0,
            customers: row['customers_actual'] as int? ?? 0,
            teamMembers: row['team_members_actual'] as int? ?? 0,
            loyalty: row['loyalty_actual'] as int? ?? 0,
          ),
    teamVolumeActual: _number(row['team_volume_actual']),
    levelActual: row['level_actual'] as String?,
    closedAt: closedAt,
  );
}

/// What planning writes. Actuals and `closed_at` are `close_month`'s.
Map<String, Object?> targetsToRow(MonthPlan plan) => {
  'month': dayColumn(plan.month),
  'own_volume_target': plan.ownVolumeTarget,
  'team_volume_target': plan.teamVolumeTarget,
  'level_target': plan.levelTarget,
  'prospects_target': plan.prospectsTarget,
  'customers_target': plan.customersTarget,
  'team_members_target': plan.teamMembersTarget,
  'loyalty_target': plan.loyaltyTarget,
  'loyalty_forecast': plan.loyaltyForecast,
};

Progress progressFromRow(Map<String, dynamic> row) => Progress(
  ownVolume: _number(row['own_volume']) ?? 0,
  prospects: row['prospects'] as int,
  customers: row['customers'] as int,
  teamMembers: row['team_members'] as int,
  loyalty: row['loyalty'] as int,
);

import 'package:flutter_test/flutter_test.dart';
import 'package:loomia/features/goals/data/goals_repository.dart';
import 'package:loomia/features/goals/domain/month_plan.dart';

void main() {
  test('the local month as two instants', () {
    final (:starts, :ends) = monthBounds(DateTime(2026, 12));
    expect(starts, DateTime(2026, 12).toUtc());
    expect(ends, DateTime(2027).toUtc());
    expect(starts.isUtc, isTrue);
  });

  test('reads an open plan: targets, no actuals', () {
    final plan = monthPlanFromRow({
      'month': '2026-10-01',
      'own_volume_target': 500,
      'team_volume_target': null,
      'level_target': 'Elite',
      'prospects_target': 4,
      'customers_target': null,
      'team_members_target': null,
      'loyalty_target': 3,
      'loyalty_forecast': 2,
      'own_volume_actual': null,
      'prospects_actual': null,
      'customers_actual': null,
      'team_members_actual': null,
      'loyalty_actual': null,
      'team_volume_actual': null,
      'level_actual': null,
      'closed_at': null,
    });

    expect(plan.month, DateTime(2026, 10));
    expect(plan.ownVolumeTarget, 500.0);
    expect(plan.levelTarget, 'Elite');
    expect(plan.prospectsTarget, 4);
    expect(plan.loyaltyForecast, 2);
    expect(plan.closed, isFalse);
    expect(plan.actual, isNull);
  });

  test('reads a closed plan with its frozen actuals', () {
    final plan = monthPlanFromRow({
      'month': '2026-09-01',
      'own_volume_target': null,
      'team_volume_target': null,
      'level_target': null,
      'prospects_target': null,
      'customers_target': null,
      'team_members_target': null,
      'loyalty_target': null,
      'loyalty_forecast': null,
      'own_volume_actual': 180.5,
      'prospects_actual': 1,
      'customers_actual': 2,
      'team_members_actual': 1,
      'loyalty_actual': 1,
      'team_volume_actual': 1200,
      'level_actual': 'Elite',
      'closed_at': '2026-10-01T08:00:00+00:00',
    });

    expect(plan.closed, isTrue);
    expect(plan.actual!.ownVolume, 180.5);
    expect(plan.actual!.customers, 2);
    expect(plan.teamVolumeActual, 1200.0);
  });

  test('writes the targets and the forecast, never the actuals', () {
    final row = targetsToRow(
      MonthPlan(
        month: DateTime(2026, 11),
        ownVolumeTarget: 600,
        loyaltyForecast: 3,
        teamVolumeActual: 9,
      ),
    );

    expect(row['month'], '2026-11-01');
    expect(row['own_volume_target'], 600);
    expect(row['loyalty_forecast'], 3);
    // Cleared targets are written as null, not left as they were.
    expect(row.containsKey('prospects_target'), isTrue);
    expect(row['prospects_target'], isNull);
    expect(row.keys.where((key) => key.endsWith('_actual')), isEmpty);
    expect(row.containsKey('closed_at'), isFalse);
  });

  test('reads progress; numeric volume may come as an int', () {
    final progress = progressFromRow({
      'own_volume': 0,
      'prospects': 1,
      'customers': 2,
      'team_members': 0,
      'loyalty': 1,
    });

    expect(progress.ownVolume, 0.0);
    expect(progress.customers, 2);
  });
}

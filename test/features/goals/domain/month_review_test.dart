import 'package:flutter_test/flutter_test.dart';
import 'package:loomia/core/business_model/business_model.dart';
import 'package:loomia/features/goals/domain/month_plan.dart';
import 'package:loomia/features/goals/domain/month_review.dart';

void main() {
  final september = DateTime(2026, 9);
  const progress = Progress(
    ownVolume: 2850,
    prospects: 7,
    customers: 6,
    teamMembers: 0,
    loyalty: 2,
  );

  test('only objectives with a target, in close-screen order', () {
    final goals = goalsOf(
      MonthPlan(
        month: september,
        ownVolumeTarget: 2800,
        prospectsTarget: 8,
        loyaltyTarget: 2,
        actual: progress,
      ),
      BusinessModel.doterra,
    );

    expect(goals.map((goal) => goal.kind), [
      GoalKind.ownVolume,
      GoalKind.prospects,
      GoalKind.loyalty,
    ]);
    expect(goals.map((goal) => goal.reached), [true, false, true]);
    expect(goals[1].done, 7);
  });

  test('no targets: nothing to review', () {
    expect(
      goalsOf(
        MonthPlan(month: september, actual: progress),
        BusinessModel.other,
      ),
      isEmpty,
    );
  });

  test('typed figures left empty are not reached', () {
    final goals = goalsOf(
      MonthPlan(
        month: september,
        teamVolumeTarget: 6000,
        levelTarget: 'Elite',
        actual: progress,
      ),
      BusinessModel.doterra,
    );
    expect(goals.map((goal) => (goal.done, goal.reached)), [
      (null, false),
      (null, false),
    ]);
  });

  test('team volume reached at the target', () {
    final goals = goalsOf(
      MonthPlan(
        month: september,
        teamVolumeTarget: 6000,
        teamVolumeActual: 6000,
        actual: progress,
      ),
      BusinessModel.doterra,
    );
    expect(goals.single.reached, isTrue);
  });

  group('levelReached', () {
    test('at or above on the ladder', () {
      expect(levelReached(BusinessModel.doterra, 'Elite', 'Elite'), isTrue);
      expect(levelReached(BusinessModel.doterra, 'Premier', 'Elite'), isTrue);
      expect(
        levelReached(BusinessModel.doterra, 'Executive', 'Elite'),
        isFalse,
      );
      expect(levelReached(BusinessModel.doterra, ' elite ', 'Elite'), isTrue);
    });

    test('no ladder: the same words', () {
      expect(levelReached(BusinessModel.other, 'Gold', 'gold'), isTrue);
      expect(levelReached(BusinessModel.other, 'Gold', 'Silver'), isFalse);
    });
  });
}

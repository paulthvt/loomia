import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loomia/core/ui/pick_day.dart';
import 'package:loomia/features/contacts/domain/people_failure.dart';
import 'package:loomia/features/goals/data/goals_repository.dart';
import 'package:loomia/features/goals/domain/month_plan.dart';
import 'package:loomia/features/goals/presentation/goals_controller.dart';

import '../fake_goals_repository.dart';

void main() {
  final now = today();
  final thisMonth = DateTime(now.year, now.month);
  final lastMonth = DateTime(now.year, now.month - 1);

  ProviderContainer container(FakeGoalsRepository goals) {
    final container = ProviderContainer(
      overrides: [goalsRepositoryProvider.overrideWithValue(goals)],
    );
    addTearDown(container.dispose);
    return container;
  }

  test("loads this month's plan, progress and forecast", () async {
    final goals = FakeGoalsRepository(
      plans: [
        MonthPlan(month: lastMonth, closedAt: thisMonth),
        MonthPlan(month: thisMonth, ownVolumeTarget: 2800),
      ],
      progressValue: const Progress(
        ownVolume: 1840,
        prospects: 5,
        customers: 4,
        teamMembers: 1,
        loyalty: 2,
      ),
      forecastValue: 1,
    );
    final c = container(goals);
    final provider = goalsProvider('p@example.com');
    c.listen(provider, (_, _) {});

    final month = await c.read(provider.future);

    expect(month.month, thisMonth);
    expect(month.plan?.ownVolumeTarget, 2800);
    expect(month.progress.ownVolume, 1840);
    expect(month.forecast, 1);
    expect(
      [for (final plan in month.plans) plan.month],
      [thisMonth, lastMonth],
    );
  });

  test('no plan this month', () async {
    final c = container(FakeGoalsRepository());
    c.listen(goalsProvider(null), (_, _) {});

    expect((await c.read(goalsProvider(null).future)).plan, isNull);
  });

  test('a failure surfaces as the failure', () async {
    final goals = FakeGoalsRepository()..failWith = PeopleFailure.network;
    final c = container(goals);
    c.listen(goalsProvider(null), (_, _) {});

    await expectLater(
      c.read(goalsProvider(null).future),
      throwsA(PeopleFailure.network),
    );
  });
}

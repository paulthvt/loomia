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

  test('closing loads the month to close and the next forecast', () async {
    final goals = FakeGoalsRepository(
      plans: [MonthPlan(month: DateTime(2026, 9), ownVolumeTarget: 2800)],
      progressValue: const Progress(
        ownVolume: 2650,
        prospects: 7,
        customers: 5,
        teamMembers: 1,
        loyalty: 2,
      ),
      forecastValue: 3,
    );
    final c = container(goals);
    final key = (email: null, day: DateTime(2026, 9, 29));
    c.listen(closingProvider(key), (_, _) {});

    final closing = (await c.read(closingProvider(key).future))!;

    expect(closing.ritual.closes, isTrue);
    expect(closing.closing?.ownVolumeTarget, 2800);
    expect(closing.done?.ownVolume, 2650);
    expect(closing.forecast, 3);
    expect(
      goals.calls,
      containsAll(['progress(2026-09)', 'forecast(2026-10)']),
    );
  });

  test('closing outside the window is null', () async {
    final c = container(FakeGoalsRepository());
    final key = (email: null, day: DateTime(2026, 9, 15));
    c.listen(closingProvider(key), (_, _) {});

    expect(await c.read(closingProvider(key).future), isNull);
  });
}

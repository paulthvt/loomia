import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loomia/core/ui/pick_day.dart';
import 'package:loomia/features/goals/data/goals_repository.dart';
import 'package:loomia/features/goals/domain/month_plan.dart';

/// The Goals tab's month: its plan (null before planning), what the book did
/// so far, the customers likely to set up loyalty before it ends, and every
/// plan, latest first, for past months and suggestions.
typedef GoalsMonth = ({
  DateTime month,
  MonthPlan? plan,
  Progress progress,
  int forecast,
  List<MonthPlan> plans,
});

/// Per account, like `peopleProvider`. Dropped when the tab is left, so
/// coming back recounts the month. No automatic retry: a failed load shows
/// its error with Try again.
final goalsProvider = FutureProvider.autoDispose.family<GoalsMonth, String?>(
  (ref, _) => _load(ref),
  retry: (error, _) => null,
);

Future<GoalsMonth> _load(Ref ref) async {
  final repository = ref.watch(goalsRepositoryProvider);
  final day = today();
  final month = DateTime(day.year, day.month);
  // ponytail: three round trips one after the other; run them together
  // if the tab feels slow to open.
  final plans = await repository.plans();
  final progress = await repository.progress(month);
  final forecast = await repository.forecast(month);
  return (
    month: month,
    plan: plans.where((plan) => plan.month == month).firstOrNull,
    progress: progress,
    forecast: forecast,
    plans: plans,
  );
}

/// Saves [plan]'s targets, then reloads the tab. Throws `PeopleFailure`.
/// Takes the container, not a widget's ref: the page may be gone by the time
/// the save lands (back during a save), and the tab must still reload.
Future<void> savePlan(ProviderContainer container, MonthPlan plan) async {
  await container.read(goalsRepositoryProvider).saveTargets(plan);
  container.invalidate(goalsProvider);
}

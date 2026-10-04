import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loomia/core/ui/pick_day.dart';
import 'package:loomia/features/contacts/data/activity_repository.dart';
import 'package:loomia/features/contacts/domain/activity.dart';
import 'package:loomia/features/goals/data/goals_repository.dart';
import 'package:loomia/features/goals/domain/goal_rules.dart';
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

/// [month]'s orders for the sheet the volume card opens.
final ordersProvider = FutureProvider.autoDispose
    .family<List<MonthOrder>, DateTime>(
      (ref, month) => ref.watch(activityRepositoryProvider).ordersIn(month),
      retry: (error, _) => null,
    );

/// After an order is added or removed: the month and its orders recount.
/// The container, not a widget's ref: the sheet may be closing.
void refreshOrders(ProviderContainer container) {
  container
    ..invalidate(goalsProvider)
    ..invalidate(ordersProvider);
}

/// What `/goals/close` needs on [day]: the ritual, the month to close with
/// its progress (step 1 only), the next month's forecast, and every plan for
/// the suggestions. Null when there's nothing to do.
typedef Closing = ({
  PendingRitual ritual,
  MonthPlan? closing,
  Progress? done,
  int forecast,
  List<MonthPlan> plans,
});

/// Keyed by the account and the day, so a test can pin the date.
final closingProvider = FutureProvider.autoDispose
    .family<Closing?, ({String? email, DateTime day})>(
      (ref, key) => _loadClosing(ref, key.day),
      retry: (error, _) => null,
    );

Future<Closing?> _loadClosing(Ref ref, DateTime day) async {
  final repository = ref.watch(goalsRepositoryProvider);
  final plans = await repository.plans();
  final ritual = pendingRitual(day, plans);
  if (ritual == null) return null;
  final closing = ritual.closes
      ? plans.firstWhere((plan) => plan.month == ritual.close)
      : null;
  final done = ritual.closes ? await repository.progress(ritual.close) : null;
  final forecast = await repository.forecast(ritual.plan);
  return (
    ritual: ritual,
    closing: closing,
    done: done,
    forecast: forecast,
    plans: plans,
  );
}

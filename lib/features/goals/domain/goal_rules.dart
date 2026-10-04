import 'package:loomia/features/goals/domain/month_plan.dart';

int _daysIn(DateTime day) => DateTime(day.year, day.month + 1, 0).day;

/// Where the month ends at this rate, and whether that reaches [target].
typedef Pace = ({double projected, bool onPace});

/// Null without a target, and in the first 3 days, when a projection means
/// nothing.
Pace? pace(num? target, num done, DateTime today) {
  if (target == null || today.day <= 3) return null;
  final projected = done / today.day * _daysIn(today);
  return (projected: projected.toDouble(), onPace: projected >= target);
}

/// The month to close and the month to plan, both the 1st at local midnight.
typedef Ritual = ({DateTime close, DateTime plan});

/// Open the last 3 days of a month (closing it) and the first 5 of the next
/// (closing the one before). Null in between.
Ritual? ritualWindow(DateTime today) {
  final month = DateTime(today.year, today.month);
  if (today.day >= _daysIn(today) - 2) {
    return (close: month, plan: DateTime(today.year, today.month + 1));
  }
  if (today.day <= 5) {
    return (close: DateTime(today.year, today.month - 1), plan: month);
  }
  return null;
}

/// Targets to start from. Loyalty comes from the forecast instead, and the
/// level is the user's own call.
typedef Suggestion = ({
  double? ownVolume,
  double? teamVolume,
  int? prospects,
  int? customers,
  int? teamMembers,
});

/// Per objective, the rounded mean of what the last 3 closed months did.
/// Null where none of them has a value.
Suggestion suggest(List<MonthPlan> plans) {
  final closed = [...plans.where((plan) => plan.closed)]
    ..sort((a, b) => b.month.compareTo(a.month));
  final last = closed.take(3).toList();
  double? mean(num? Function(MonthPlan plan) value) {
    final known = last.map(value).nonNulls.toList();
    if (known.isEmpty) return null;
    return known.reduce((a, b) => a + b) / known.length;
  }

  return (
    ownVolume: mean((plan) => plan.actual?.ownVolume)?.roundToDouble(),
    teamVolume: mean((plan) => plan.teamVolumeActual)?.roundToDouble(),
    prospects: mean((plan) => plan.actual?.prospects)?.round(),
    customers: mean((plan) => plan.actual?.customers)?.round(),
    teamMembers: mean((plan) => plan.actual?.teamMembers)?.round(),
  );
}

import 'dart:async';

import 'package:loomia/features/goals/data/goals_repository.dart';
import 'package:loomia/features/goals/domain/month_plan.dart';

const noProgress = Progress(
  ownVolume: 0,
  prospects: 0,
  customers: 0,
  teamMembers: 0,
  loyalty: 0,
);

/// In-memory plans with a set progress and forecast. Records calls, and
/// fails or stalls on demand.
class FakeGoalsRepository implements GoalsRepository {
  FakeGoalsRepository({
    List<MonthPlan> plans = const [],
    this.progressValue = noProgress,
    this.forecastValue = 0,
  }) {
    store.addAll(plans);
  }

  final List<MonthPlan> store = [];
  Progress progressValue;
  int forecastValue;

  /// One entry per call, e.g. `saveTargets(2026-10)`.
  final List<String> calls = [];

  /// Thrown by calls started while set. Use a `PeopleFailure`.
  Object? failWith;

  /// Calls started while set wait on it.
  Completer<void>? gate;

  Future<void> _record(String call) async {
    calls.add(call);
    final failure = failWith;
    final wait = gate;
    if (wait != null) await wait.future;
    if (failure != null) throw failure;
  }

  static String _month(DateTime month) =>
      '${month.year}-${month.month.toString().padLeft(2, '0')}';

  @override
  Future<List<MonthPlan>> plans() async {
    await _record('plans()');
    return [...store]..sort((a, b) => b.month.compareTo(a.month));
  }

  @override
  Future<MonthPlan> saveTargets(MonthPlan plan) async {
    await _record('saveTargets(${_month(plan.month)})');
    store
      ..removeWhere((saved) => saved.month == plan.month)
      ..add(plan);
    return plan;
  }

  @override
  Future<Progress> progress(DateTime month) async {
    await _record('progress(${_month(month)})');
    return progressValue;
  }

  @override
  Future<int> forecast(DateTime month) async {
    await _record('forecast(${_month(month)})');
    return forecastValue;
  }

  @override
  Future<MonthPlan> close(
    DateTime month, {
    double? teamVolume,
    String? level,
  }) => throw UnimplementedError('close is #143');
}

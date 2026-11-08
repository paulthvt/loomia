import 'package:loomia/core/business_model/business_model.dart';
import 'package:loomia/features/goals/domain/month_plan.dart';

/// One objective of a month, in the order the close screen lists them.
enum GoalKind {
  ownVolume,
  prospects,
  customers,
  teamMembers,
  loyalty,
  teamVolume,
  level,
}

/// An objective the user set for a month, next to what happened.
///
/// [done] is null for the two typed figures (team volume, level) when the
/// user left them empty at close: Loomia can't tell, so it isn't reached.
typedef GoalResult = ({
  GoalKind kind,
  Object? done,
  Object target,
  bool reached,
});

/// Every objective [plan] had a target for. Empty for a month planned with
/// no targets: there's nothing to look back on.
/// Counted figures come from [MonthPlan.actual]; an open month reads as zero.
List<GoalResult> goalsOf(MonthPlan plan, BusinessModel model) {
  final actual = plan.actual;
  GoalResult? counted(GoalKind kind, num? target, num? value) => target == null
      ? null
      : (
          kind: kind,
          done: value ?? 0,
          target: target,
          reached: (value ?? 0) >= target,
        );
  final teamVolume = plan.teamVolumeActual;
  final level = plan.levelActual;
  return [
    ?counted(GoalKind.ownVolume, plan.ownVolumeTarget, actual?.ownVolume),
    ?counted(GoalKind.prospects, plan.prospectsTarget, actual?.prospects),
    ?counted(GoalKind.customers, plan.customersTarget, actual?.customers),
    ?counted(GoalKind.teamMembers, plan.teamMembersTarget, actual?.teamMembers),
    ?counted(GoalKind.loyalty, plan.loyaltyTarget, actual?.loyalty),
    if (plan.teamVolumeTarget case final target?)
      (
        kind: GoalKind.teamVolume,
        done: teamVolume,
        target: target,
        reached: teamVolume != null && teamVolume >= target,
      ),
    if (plan.levelTarget case final target?)
      (
        kind: GoalKind.level,
        done: level,
        target: target,
        reached: level != null && levelReached(model, level, target),
      ),
  ];
}

/// At or above [target] on the company's ladder; without a known ladder, the
/// same words.
bool levelReached(BusinessModel model, String level, String target) {
  String key(String value) => value.trim().toLowerCase();
  final ladder = model.levels.map(key).toList();
  final at = ladder.indexOf(key(level));
  final aim = ladder.indexOf(key(target));
  if (at == -1 || aim == -1) return key(level) == key(target);
  return at >= aim;
}

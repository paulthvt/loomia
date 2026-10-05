import 'package:intl/intl.dart';
import 'package:loomia/core/business_model/business_model.dart';
import 'package:loomia/core/ui/goal_card.dart';
import 'package:loomia/features/goals/domain/goal_rules.dart';
import 'package:loomia/features/goals/presentation/goals_controller.dart';
import 'package:loomia/l10n/app_localizations.dart';
import 'package:material_ui/material_ui.dart';

/// The own-volume card: Goals' first card, and Today's on desktop.
Widget volumeCard(
  BuildContext context, {
  required GoalsMonth month,
  required DateTime today,
  required BusinessModel model,
  VoidCallback? onTap,
}) {
  final l10n = AppLocalizations.of(context);
  final number = NumberFormat.decimalPattern(l10n.localeName);
  final done = month.progress;
  final target = month.plan?.ownVolumeTarget;
  final hasTarget = target != null && target > 0;
  final pacing = pace(hasTarget ? target : null, done.ownVolume, today);
  final daysLeft = DateTime(today.year, today.month + 1, 0).day - today.day;
  return GoalCard(
    title: l10n.goalOwnVolume,
    value: number.format(done.ownVolume),
    suffix: hasTarget
        ? l10n.goalVolumeOf(model.name, number.format(target))
        : l10n.goalVolumeAlone(model.name),
    progress: hasTarget ? done.ownVolume / target : null,
    pace: switch (pacing) {
      null => null,
      (onPace: true, projected: _) => l10n.goalOnPace,
      _ => l10n.goalBehindPace,
    },
    behindPace: pacing?.onPace == false,
    leading: hasTarget
        ? l10n.goalPercentPlanned((done.ownVolume / target * 100).round())
        : null,
    timeLeft: hasTarget ? l10n.goalDaysLeft(daysLeft) : null,
    onTap: onTap,
  );
}

import 'package:intl/intl.dart';
import 'package:loomia/app/theme/app_colors.dart';
import 'package:loomia/app/theme/app_spacing.dart';
import 'package:loomia/core/business_model/business_model.dart';
import 'package:loomia/features/goals/domain/goal_rules.dart';
import 'package:loomia/features/goals/presentation/goals_controller.dart';
import 'package:loomia/l10n/app_localizations.dart';
import 'package:material_ui/material_ui.dart';

/// Whether [month] has a volume line for Today: a plan with an own-volume
/// target.
bool hasGoalLine(GoalsMonth month) {
  final target = month.plan?.ownVolumeTarget;
  return target != null && target > 0;
}

/// Today's one line about the month: what is left, on pace, or reached,
/// then the days left. Stated, never judged. Tapping it opens Goals.
class GoalLine extends StatelessWidget {
  const GoalLine({
    required this.month,
    required this.today,
    required this.model,
    required this.onTap,
    super.key,
  });

  final GoalsMonth month;
  final DateTime today;
  final BusinessModel model;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    if (!hasGoalLine(month)) return const SizedBox.shrink();
    final l10n = AppLocalizations.of(context);
    final colors = LoomiaColors.of(context);
    final target = month.plan!.ownVolumeTarget!;
    final done = month.progress.ownVolume;
    final days = DateTime(today.year, today.month + 1, 0).day - today.day;
    final number = NumberFormat.decimalPattern(l10n.localeName);
    final text = done >= target
        ? l10n.goalLineReached(days)
        : pace(target, done, today)?.onPace ?? false
        ? l10n.goalLineOnPace(days)
        : l10n.goalLineToGo(model.name, number.format(target - done), days);

    return Semantics(
      button: true,
      onTapHint: l10n.goalLineOpen,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  text,
                  style: Theme.of(context).textTheme.bodyLarge
                      ?.copyWith(color: colors.textMuted),
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: colors.textMuted),
            ],
          ),
        ),
      ),
    );
  }
}

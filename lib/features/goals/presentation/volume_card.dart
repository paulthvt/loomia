import 'package:intl/intl.dart';
import 'package:loomia/app/theme/app_colors.dart';
import 'package:loomia/app/theme/app_spacing.dart';
import 'package:loomia/app/theme/app_typography.dart';
import 'package:loomia/core/business_model/business_model.dart';
import 'package:loomia/core/ui/goal_card.dart';
import 'package:loomia/core/ui/hero_panel.dart';
import 'package:loomia/core/ui/loomia_progress_bar.dart';
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

/// The own volume inside Goals' white hero card: the chip and pace, the
/// value, its bar, then where the pace leads and [onPlan]'s button. The top
/// half opens the month's orders through [onTap].
class OwnVolumeHero extends StatelessWidget {
  const OwnVolumeHero({
    required this.month,
    required this.today,
    required this.model,
    this.onTap,
    this.onPlan,
    super.key,
  });

  final GoalsMonth month;
  final DateTime today;
  final BusinessModel model;
  final VoidCallback? onTap;

  /// "Change the plan"; none once the month is closed.
  final VoidCallback? onPlan;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final colors = LoomiaColors.of(context);
    final number = NumberFormat.decimalPattern(l10n.localeName);
    final done = month.progress;
    final target = month.plan?.ownVolumeTarget;
    final hasTarget = target != null && target > 0;
    final pacing = pace(hasTarget ? target : null, done.ownVolume, today);
    final daysLeft = DateTime(today.year, today.month + 1, 0).day - today.day;
    final big = AppTypography.numeric.copyWith(color: scheme.onSurface);
    final plan = onPlan;

    final volume = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            HeroEyebrow(l10n.goalOwnVolume),
            const Spacer(),
            if (pacing != null)
              Text(
                pacing.onPace ? l10n.goalOnPace : l10n.goalBehindPace,
                // As GoalCard: behind takes the warm secondary ink.
                style: AppTypography.caption.copyWith(
                  color: pacing.onPace
                      ? colors.textMuted
                      : colors.secondaryText,
                ),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        // Same style on both: wraps as words when the number is long.
        Wrap(
          spacing: AppSpacing.xs,
          children: [
            Text(number.format(done.ownVolume), style: big),
            Text(
              hasTarget
                  ? l10n.goalVolumeOf(model.name, number.format(target))
                  : l10n.goalVolumeAlone(model.name),
              style: big,
            ),
          ],
        ),
        if (hasTarget) ...[
          const SizedBox(height: AppSpacing.md),
          LoomiaProgressBar(
            value: done.ownVolume / target,
            leadingLabel: l10n.goalPercentPlanned(
              (done.ownVolume / target * 100).round(),
            ),
            trailingLabel: l10n.goalDaysLeft(daysLeft),
          ),
        ],
      ],
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (onTap == null)
          volume
        else
          // Heard apart from the pace block and the button below.
          Semantics(
            container: true,
            button: true,
            child: Material(
              type: MaterialType.transparency,
              child: InkWell(
                onTap: onTap,
                borderRadius: BorderRadius.circular(AppRadii.md),
                child: volume,
              ),
            ),
          ),
        if (pacing != null) ...[
          const Divider(height: AppSpacing.xl),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: AppSpacing.ms,
            children: [
              DecoratedBox(
                decoration: BoxDecoration(
                  color: scheme.primaryContainer,
                  shape: BoxShape.circle,
                ),
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.ms),
                  child: Icon(
                    Icons.north_east_rounded,
                    size: 20,
                    color: colors.primaryText,
                  ),
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: AppSpacing.xs,
                  children: [
                    Text(
                      l10n.goalPaceProjection(
                        model.name,
                        number.format(pacing.projected.round()),
                      ),
                      style: theme.textTheme.titleMedium,
                    ),
                    Text(
                      l10n.goalPaceNote,
                      style: AppTypography.body.copyWith(
                        color: colors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
        if (plan != null) ...[
          const SizedBox(height: AppSpacing.lg),
          FilledButton.icon(
            onPressed: plan,
            icon: const Icon(Icons.flag_rounded),
            label: Text(l10n.goalChangePlan),
          ),
        ],
      ],
    );
  }
}

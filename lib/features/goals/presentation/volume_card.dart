import 'package:intl/intl.dart';
import 'package:loomia/app/theme/app_colors.dart';
import 'package:loomia/app/theme/app_spacing.dart';
import 'package:loomia/app/theme/app_theme.dart';
import 'package:loomia/app/theme/app_typography.dart';
import 'package:loomia/core/business_model/business_model.dart';
import 'package:loomia/core/ui/goal_card.dart';
import 'package:loomia/core/ui/hero_panel.dart';
import 'package:loomia/core/ui/loomia_progress_bar.dart';
import 'package:loomia/features/goals/domain/goal_rules.dart';
import 'package:loomia/features/goals/presentation/goals_controller.dart';
import 'package:loomia/l10n/app_localizations.dart';
import 'package:material_ui/material_ui.dart';

/// The own volume against its plan: the target (null when none, or zero),
/// where the pace leads, and the days left. One reading for the card, the
/// hero card and the band.
({double? target, Pace? pacing, int daysLeft}) _volume(
  GoalsMonth month,
  DateTime today,
) {
  final target = month.plan?.ownVolumeTarget;
  final aimed = target != null && target > 0 ? target : null;
  return (
    target: aimed,
    pacing: pace(aimed, month.progress.ownVolume, today),
    daysLeft: DateTime(today.year, today.month + 1, 0).day - today.day,
  );
}

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
  final (:target, :pacing, :daysLeft) = _volume(month, today);
  final hasTarget = target != null;
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
    final (:target, :pacing, :daysLeft) = _volume(month, today);
    final hasTarget = target != null;
    final big = AppTypography.numeric.copyWith(color: scheme.onSurface);
    final plan = onPlan;

    final volume = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        HeroCardHead(
          eyebrow: l10n.goalOwnVolume,
          status: pacing == null
              ? null
              : Text(
                  pacing.onPace ? l10n.goalOnPace : l10n.goalBehindPace,
                  // As GoalCard: behind takes the warm secondary ink.
                  style: AppTypography.caption.copyWith(
                    color: pacing.onPace
                        ? colors.textMuted
                        : colors.secondaryText,
                  ),
                ),
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

/// Desktop Goals' band (#507): [header] (days left, "Goals": the bar does
/// not repeat them, white small text fails over the light end), the own volume
/// in white with its bar and pace; at the end a translucent panel with where
/// the pace leads and [onPlan]'s white button. Side by side at every
/// desktop width: the narrowest (1200, sidebar expanded) still leaves the
/// volume about 390px.
class OwnVolumeBand extends StatelessWidget {
  const OwnVolumeBand({
    required this.header,
    required this.month,
    required this.today,
    required this.model,
    this.onPlan,
    super.key,
  });

  final Widget header;
  final GoalsMonth month;
  final DateTime today;
  final BusinessModel model;

  /// "Change the plan"; none once the month is closed.
  final VoidCallback? onPlan;

  static const double _panelWidth = 360;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final colors = LoomiaColors.of(context);
    final number = NumberFormat.decimalPattern(l10n.localeName);
    final done = month.progress;
    final (:target, :pacing, daysLeft: _) = _volume(month, today);
    final hasTarget = target != null;
    final plan = onPlan;

    final volume = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        header,
        const SizedBox(height: AppSpacing.lg),
        // One node: "Own volume, 1,840 of 2,800 PV".
        MergeSemantics(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.goalOwnVolume.toUpperCase(),
                style: AppTypography.overline.copyWith(color: colors.onHero),
              ),
              const SizedBox(height: AppSpacing.sm),
              // One paragraph: the suffix wraps as words and sits on the
              // baseline.
              Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: number.format(done.ownVolume),
                      style: AppTypography.numericHero.copyWith(
                        color: colors.onHero,
                      ),
                    ),
                    TextSpan(
                      text:
                          ' ${hasTarget ? l10n.goalVolumeOf(model.name, number.format(target)) : l10n.goalVolumeAlone(model.name)}',
                      // Regular: the figure is what reads first.
                      style: AppTypography.titleLarge.copyWith(
                        color: colors.onHero,
                        fontWeight: AppTypography.bodyLarge.fontWeight,
                        fontVariations: AppTypography.bodyLarge.fontVariations,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        if (hasTarget) ...[
          const SizedBox(height: AppSpacing.md),
          LoomiaProgressBar(
            value: done.ownVolume / target,
            tone: ProgressTone.onHero,
            leadingLabel: [
              l10n.goalPercentPlanned((done.ownVolume / target * 100).round()),
              if (pacing != null)
                pacing.onPace ? l10n.goalOnPace : l10n.goalBehindPace,
            ].join(' · '),
          ),
        ],
      ],
    );

    final hasPanel = pacing != null || plan != null;
    final panel = DecoratedBox(
      decoration: AppTheme.heroInset(context),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (pacing != null) ...[
              Text(
                l10n.goalPaceProjection(
                  model.name,
                  number.format(pacing.projected.round()),
                ),
                style: AppTypography.titleLarge.copyWith(color: colors.onHero),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                l10n.goalPaceNote,
                style: AppTypography.body.copyWith(color: colors.onHero),
              ),
            ],
            if (plan != null) ...[
              if (pacing != null) const SizedBox(height: AppSpacing.md),
              FilledButton.icon(
                onPressed: plan,
                style: AppTheme.heroPill(context),
                icon: Icon(Icons.flag_rounded, color: scheme.primary),
                label: Text(l10n.goalChangePlan),
              ),
            ],
          ],
        ),
      ),
    );

    if (!hasPanel) return volume;
    return Row(
      spacing: AppSpacing.lg,
      children: [
        Expanded(child: volume),
        SizedBox(
          width: _panelWidth,
          child: Semantics(container: true, child: panel),
        ),
      ],
    );
  }
}

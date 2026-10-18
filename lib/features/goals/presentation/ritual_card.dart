import 'package:loomia/app/theme/app_colors.dart';
import 'package:loomia/app/theme/app_spacing.dart';
import 'package:loomia/app/theme/app_typography.dart';
import 'package:loomia/features/goals/domain/goal_rules.dart';
import 'package:loomia/l10n/app_localizations.dart';
import 'package:material_ui/material_ui.dart';

/// The month-end ritual's invitation: "Close September, plan October", or
/// "Plan October" when only that is left. Goals and Today show it; the
/// month-end push says the same, from the same keys (#148).
class RitualCard extends StatelessWidget {
  const RitualCard({required this.ritual, required this.onStart, super.key});

  final PendingRitual ritual;
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: scheme.secondaryContainer,
        borderRadius: BorderRadius.circular(AppRadii.lg),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: AppSpacing.xs,
        children: [
          Text(
            ritual.closes
                ? l10n.pushRitualTitle(ritual.close, ritual.plan)
                : l10n.pushRitualPlanTitle(ritual.plan),
            style: theme.textTheme.titleMedium?.copyWith(
              color: scheme.onSecondaryContainer,
            ),
          ),
          Text(
            ritual.closes
                ? l10n.pushRitualBody(ritual.plan)
                : l10n.pushRitualPlanBody,
            style: AppTypography.caption.copyWith(
              color: scheme.onSecondaryContainer,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          FilledButton(onPressed: onStart, child: Text(l10n.ritualStart)),
        ],
      ),
    );
  }
}

/// The invitation once next month is drafted, in the last 3 days: one line,
/// as [GoalLine], that opens the draft again until the 1st (#354).
class DraftLine extends StatelessWidget {
  const DraftLine({required this.month, required this.onTap, super.key});

  final DateTime month;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = LoomiaColors.of(context);
    return Semantics(
      button: true,
      onTapHint: l10n.ritualDraftedOpen,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  l10n.ritualDrafted(month),
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

/// [RitualCard], or [DraftLine] once next month is drafted.
Widget ritualInvitation(PendingRitual ritual, VoidCallback onStart) =>
    ritual.drafted
    ? DraftLine(month: ritual.plan, onTap: onStart)
    : RitualCard(ritual: ritual, onStart: onStart);

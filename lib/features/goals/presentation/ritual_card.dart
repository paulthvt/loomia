import 'package:loomia/app/theme/app_colors.dart';
import 'package:loomia/app/theme/app_spacing.dart';
import 'package:loomia/app/theme/app_theme.dart';
import 'package:loomia/app/theme/app_typography.dart';
import 'package:loomia/features/goals/domain/goal_rules.dart';
import 'package:loomia/l10n/app_localizations.dart';
import 'package:material_ui/material_ui.dart';

/// The month-end ritual's invitation: "Close September, plan October", or
/// "Plan October" when only that is left. Goals shows it; Today will (#144).
class RitualCard extends StatelessWidget {
  const RitualCard({required this.ritual, required this.onStart, super.key});

  final PendingRitual ritual;
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = LoomiaColors.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: AppSpacing.xs,
          children: [
            Text(
              ritual.closes
                  ? l10n.ritualCloseAndPlan(ritual.close, ritual.plan)
                  : l10n.goalsPlanMonth(ritual.plan),
              style: Theme.of(context).textTheme.titleMedium,
            ),
            Text(
              ritual.closes ? l10n.ritualBody : l10n.ritualPlanBody,
              style: AppTypography.caption.copyWith(color: colors.textMuted),
            ),
            const SizedBox(height: AppSpacing.xs),
            FilledButton.tonal(
              onPressed: onStart,
              style: AppTheme.tonal(context),
              child: Text(l10n.ritualStart),
            ),
          ],
        ),
      ),
    );
  }
}

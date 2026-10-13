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

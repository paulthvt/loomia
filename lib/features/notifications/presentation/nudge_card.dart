import 'package:loomia/app/theme/app_spacing.dart';
import 'package:loomia/app/theme/app_typography.dart';
import 'package:loomia/l10n/app_localizations.dart';
import 'package:material_ui/material_ui.dart';

/// Today's one-time offer of the daily summary (design principle 4: no push
/// before the user opts in). Styled as the month's ritual card.
class NudgeCard extends StatelessWidget {
  const NudgeCard({
    required this.time,
    required this.onTurnOn,
    required this.onNotNow,
    super.key,
  });

  /// The default summary time, formatted for the device.
  final String time;
  final VoidCallback onTurnOn;
  final VoidCallback onNotNow;

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
            l10n.todayNudgeTitle(time),
            style: theme.textTheme.titleMedium?.copyWith(
              color: scheme.onSecondaryContainer,
            ),
          ),
          Text(
            l10n.todayNudgeBody,
            style: AppTypography.caption.copyWith(
              color: scheme.onSecondaryContainer,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Row(
            spacing: AppSpacing.sm,
            children: [
              FilledButton(
                onPressed: onTurnOn,
                child: Text(l10n.todayNudgeTurnOn),
              ),
              TextButton(
                onPressed: onNotNow,
                child: Text(l10n.todayNudgeNotNow),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

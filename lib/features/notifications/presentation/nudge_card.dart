import 'package:loomia/app/theme/app_spacing.dart';
import 'package:loomia/app/theme/app_theme.dart';
import 'package:loomia/app/theme/app_typography.dart';
import 'package:loomia/l10n/app_localizations.dart';
import 'package:material_ui/material_ui.dart';

/// Today's one-time offer of the daily summary (design principle 4: no push
/// before the user opts in). Styled as the month's ritual card. The time is a
/// button, not a line of text: a time that doesn't suit is the reason to say
/// no, so it is changed here (#288).
class NudgeCard extends StatelessWidget {
  const NudgeCard({
    required this.time,
    required this.onPickTime,
    required this.onTurnOn,
    required this.onNotNow,
    super.key,
  });

  /// The time Turn on saves, formatted for the device.
  final String time;
  final VoidCallback onPickTime;
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
        spacing: AppSpacing.sm,
        children: [
          Text(
            l10n.todayNudgeQuestion,
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
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.xs),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: AppSpacing.sm,
              children: [
                Semantics(
                  label: l10n.todayNudgeTimeLabel(time),
                  button: true,
                  excludeSemantics: true,
                  child: FilledButton.tonal(
                    style: AppTheme.tonal(context),
                    onPressed: onPickTime,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      spacing: AppSpacing.sm,
                      children: [
                        const Icon(Icons.schedule_rounded),
                        Text(time),
                        const Icon(Icons.expand_more_rounded),
                      ],
                    ),
                  ),
                ),
                // A Wrap, not a Row: the French labels don't fit side by side.
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.xs,
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
          ),
        ],
      ),
    );
  }
}

import 'package:loomia/app/theme/app_colors.dart';
import 'package:loomia/app/theme/app_spacing.dart';
import 'package:loomia/app/theme/app_theme.dart';
import 'package:loomia/app/theme/app_typography.dart';
import 'package:loomia/core/ui/loomia_progress_bar.dart';
import 'package:material_ui/material_ui.dart';

/// Own intent vs. own progress (`docs/design/components.md` #17). Pace is never
/// red and never a comparison with another person (design principle #5).
class GoalCard extends StatelessWidget {
  const GoalCard({
    required this.title,
    required this.value,
    this.suffix,
    this.progress,
    this.pace,
    this.behindPace = false,
    this.leading,
    this.timeLeft,
    this.onTap,
    super.key,
  });

  final String title;

  /// Where the user is, formatted: "1,840".
  final String value;

  /// After the value: "of 2,800 PV", or "PV this month" without a target.
  final String? suffix;

  /// Value over target. Null without a target: no bar.
  final double? progress;

  /// "Slightly behind pace" / "On pace" — direction, never a verdict.
  final String? pace;

  /// Behind pace takes the warm secondary ink; on pace stays muted.
  final bool behindPace;

  /// Under the bar, on the left: "66% of what you planned".
  final String? leading;

  /// "11 days left" — how much time is left, never a percentage.
  final String? timeLeft;

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = LoomiaColors.of(context);
    final paceText = pace;
    final suffixText = suffix;
    final fill = progress;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(title, style: theme.textTheme.titleMedium),
                  ),
                  if (paceText != null)
                    // Pace ink changes as the number moves, so it fades
                    // rather than flicks between warm and muted (§7, 180ms).
                    AnimatedDefaultTextStyle(
                      duration: context.motion(AppMotion.quick),
                      curve: AppMotion.standard,
                      style: AppTypography.caption.copyWith(
                        color: behindPace
                            ? colors.secondaryText
                            : colors.textMuted,
                      ),
                      child: Text(paceText),
                    ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    value,
                    style: AppTypography.numeric.copyWith(
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                  if (suffixText != null) ...[
                    const SizedBox(width: AppSpacing.xs),
                    Text(
                      suffixText,
                      style: AppTypography.body.copyWith(
                        color: colors.textMuted,
                      ),
                    ),
                  ],
                ],
              ),
              if (fill != null) ...[
                const SizedBox(height: AppSpacing.ms),
                LoomiaProgressBar(
                  value: fill.clamp(0, 1),
                  leadingLabel: leading,
                  trailingLabel: timeLeft,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

import 'package:loomia/app/theme/app_colors.dart';
import 'package:loomia/app/theme/app_spacing.dart';
import 'package:loomia/app/theme/app_theme.dart';
import 'package:loomia/app/theme/app_typography.dart';
import 'package:material_ui/material_ui.dart';

/// At most one tinted pair per screen (`docs/design/components.md` #16).
enum StatTone { plain, primary, secondary }

/// A count plus the reason it matters. The value stays below the 24px
/// screen title (guardrail #4). The note frames the number against the
/// user's own intent, never against other people (design principle #5).
class StatTile extends StatelessWidget {
  const StatTile({
    required this.label,
    required this.value,
    this.note,
    this.tone = StatTone.plain,
    super.key,
  });

  final String label;
  final String value;
  final String? note;
  final StatTone tone;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final colors = LoomiaColors.of(context);
    final (background, ink, border) = switch (tone) {
      StatTone.plain => (
        colors.surfaceDefault,
        scheme.onSurface,
        colors.borderSubtle,
      ),
      StatTone.primary => (
        scheme.primaryContainer,
        scheme.onPrimaryContainer,
        Colors.transparent,
      ),
      StatTone.secondary => (
        scheme.secondaryContainer,
        scheme.onSecondaryContainer,
        Colors.transparent,
      ),
    };
    final subdued = tone == StatTone.plain ? colors.textMuted : ink;
    final noteText = note;

    return AnimatedContainer(
      duration: context.motion(AppMotion.fast),
      curve: AppMotion.standard,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(AppRadii.lg),
        border: Border.all(color: border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: AppTypography.overline.copyWith(color: subdued),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(value, style: AppTypography.numeric.copyWith(color: ink)),
          if (noteText != null) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              noteText,
              style: AppTypography.caption.copyWith(color: subdued),
            ),
          ],
        ],
      ),
    );
  }
}

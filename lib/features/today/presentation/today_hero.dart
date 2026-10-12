import 'package:loomia/app/theme/app_colors.dart';
import 'package:loomia/app/theme/app_spacing.dart';
import 'package:loomia/app/theme/app_typography.dart';
import 'package:loomia/core/ui/loomia_progress_bar.dart';
import 'package:loomia/l10n/app_localizations.dart';
import 'package:material_ui/material_ui.dart';

/// Answers "what should I do today?" from arm's length
/// (`docs/design/components.md` #11).
///
/// The only filled colour block in the product. Its colour is identical in light
/// and dark, which is why the labels on it can be white at 78% in both modes.
/// The footer counts today's own list, never a target.
class TodayHero extends StatelessWidget {
  const TodayHero({
    required this.eyebrow,
    required this.headline,
    this.progress,
    super.key,
  });

  final String eyebrow;

  /// A sentence. The count lives inside it so it cannot read as a quota.
  final String headline;

  /// Rows ticked today out of today's list; null while unknown, and then the
  /// hero is the sentence alone.
  final ({int done, int total})? progress;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final quiet = scheme.onPrimary.withValues(alpha: AppColors.quietOnPrimary);

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: scheme.primary,
        borderRadius: BorderRadius.circular(AppRadii.xl),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            eyebrow.toUpperCase(),
            style: AppTypography.overline.copyWith(color: quiet),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            headline,
            style: AppTypography.titleLarge.copyWith(color: scheme.onPrimary),
          ),
          if (progress case (:final done, :final total)) ...[
            const SizedBox(height: AppSpacing.ms),
            _Progress(done: done, total: total),
          ],
        ],
      ),
    );
  }
}

class _Progress extends StatelessWidget {
  const _Progress({required this.done, required this.total});

  final int done;
  final int total;

  @override
  Widget build(BuildContext context) {
    final caption = AppLocalizations.of(context).todayDone(done, total);
    // Heard as the caption, once; never as the indicator's percentage.
    return Semantics(
      container: true,
      label: caption,
      excludeSemantics: true,
      child: LoomiaProgressBar(
        tone: ProgressTone.primary,
        value: total == 0 ? 0 : done / total,
        leadingLabel: caption,
      ),
    );
  }
}

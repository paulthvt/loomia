import 'package:loomia/app/theme/app_colors.dart';
import 'package:loomia/app/theme/app_spacing.dart';
import 'package:loomia/app/theme/app_typography.dart';
import 'package:loomia/core/ui/hero_panel.dart';
import 'package:loomia/core/ui/loomia_progress_bar.dart';
import 'package:loomia/l10n/app_localizations.dart';
import 'package:material_ui/material_ui.dart';

/// Answers "what should I do today?" from arm's length
/// (`docs/design/components.md` #11).
///
/// The content of the white card on Today's gradient: the eyebrow as an amber
/// tint chip, the count beside it, the sentence, the bar. The count is
/// today's own list, never a target.
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
    final colors = LoomiaColors.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            HeroEyebrow(eyebrow),
            const Spacer(),
            if (progress case (:final done, :final total))
              // Heard on its own, after the sentence's eyebrow.
              Semantics(
                container: true,
                child: Text(
                  AppLocalizations.of(context).todayDone(done, total),
                  style: AppTypography.caption.copyWith(
                    color: colors.textMuted,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        Text(
          headline,
          style: AppTypography.titleLarge.copyWith(color: scheme.onSurface),
        ),
        if (progress case (:final done, :final total)) ...[
          const SizedBox(height: AppSpacing.md),
          // Heard as the count above, once; never as the bar's percentage.
          ExcludeSemantics(
            child: LoomiaProgressBar(
              tone: ProgressTone.primary,
              value: total == 0 ? 0 : done / total,
            ),
          ),
        ],
      ],
    );
  }
}

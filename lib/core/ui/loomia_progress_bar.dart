import 'package:loomia/app/theme/app_colors.dart';
import 'package:loomia/app/theme/app_spacing.dart';
import 'package:loomia/app/theme/app_theme.dart';
import 'package:loomia/app/theme/app_typography.dart';
import 'package:material_ui/material_ui.dart';

/// Pace, not score (`docs/design/components.md` #7).
enum ProgressTone {
  /// Secondary on its own track. The default everywhere.
  secondary,

  /// Only on the Today hero card: amber on its amber tint.
  primary,

  /// On the hero gradient itself (desktop Goals' band): white on a
  /// translucent track, white captions (quiet ones fall short over the
  /// gradient's light end).
  onHero,
}

/// A pill track with an optional caption row. The right caption says how much
/// time is left — never a verdict (design principle #5).
class LoomiaProgressBar extends StatelessWidget {
  const LoomiaProgressBar({
    required this.value,
    this.tone = ProgressTone.secondary,
    this.leadingLabel,
    this.trailingLabel,
    super.key,
  });

  final double value;
  final ProgressTone tone;
  final String? leadingLabel;
  final String? trailingLabel;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final colors = LoomiaColors.of(context);
    final (track, bar, caption) = switch (tone) {
      ProgressTone.secondary => (colors.secondaryTrack, null, colors.textMuted),
      ProgressTone.primary => (
        scheme.primaryContainer,
        scheme.primary,
        colors.textMuted,
      ),
      ProgressTone.onHero => (colors.heroFill, colors.onHero, colors.onHero),
    };
    final indicator = ClipRRect(
      borderRadius: BorderRadius.circular(AppRadii.pill),
      // The bar grows into its new value instead of jumping: the movement is
      // the only thing that says progress was made (§7, 240ms).
      child: TweenAnimationBuilder<double>(
        tween: Tween(end: value.clamp(0, 1)),
        duration: context.motion(AppMotion.medium),
        curve: AppMotion.standard,
        builder: (context, animated, child) => LinearProgressIndicator(
          value: animated,
          backgroundColor: track,
          color: bar,
        ),
      ),
    );
    // Its own node, so it never absorbs the text around it.
    return Semantics(
      container: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // A leading label says the figure in words: the bar's "66%" would
          // only repeat it.
          if (leadingLabel != null)
            ExcludeSemantics(child: indicator)
          else
            indicator,
          if (leadingLabel != null || trailingLabel != null)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.sm),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      leadingLabel ?? '',
                      style: AppTypography.caption.copyWith(color: caption),
                    ),
                  ),
                  Text(
                    trailingLabel ?? '',
                    style: AppTypography.caption.copyWith(color: caption),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

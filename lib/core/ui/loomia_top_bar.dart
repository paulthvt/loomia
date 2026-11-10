import 'package:loomia/app/theme/app_colors.dart';
import 'package:loomia/app/theme/app_spacing.dart';
import 'package:loomia/app/theme/app_typography.dart';
import 'package:material_ui/material_ui.dart';

/// Screen header (`docs/design/components.md` #24): the eyebrow carries the date,
/// the title carries the place. No shadow and no border — the canvas colour is
/// the whole chrome.
///
/// A plain widget rather than an `AppBar` because it scrolls with the content and
/// its title is two lines of different styles.
class LoomiaTopBar extends StatelessWidget {
  const LoomiaTopBar({
    required this.title,
    this.eyebrow,
    this.large = false,
    this.action,
    this.gap = AppSpacing.lg,
    super.key,
  });

  final String title;

  /// Uppercased by the style — pass it in sentence case.
  final String? eyebrow;

  /// Desktop uses the 32px `display` style, mobile the 24px `headline`.
  final bool large;

  /// One trailing ghost action, at most.
  final Widget? action;

  /// Space below: less on Today, where the hero continues the greeting.
  final double gap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = LoomiaColors.of(context);
    final eyebrowText = eyebrow;
    final trailing = action;

    return Padding(
      padding: EdgeInsets.only(bottom: gap),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (eyebrowText != null) ...[
                  Text(
                    eyebrowText.toUpperCase(),
                    style: AppTypography.overline.copyWith(
                      color: colors.textMuted,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                ],
                Text(
                  title,
                  style: large
                      ? theme.textTheme.displaySmall
                      : theme.textTheme.headlineSmall,
                ),
              ],
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}

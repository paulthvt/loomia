import 'package:loomia/app/theme/app_colors.dart';
import 'package:loomia/app/theme/app_spacing.dart';
import 'package:loomia/app/theme/app_typography.dart';
import 'package:material_ui/material_ui.dart';

/// The only structural divider in the product (`docs/design/components.md` #10):
/// no rules, no card headers, no chevrons — space and this header do all the
/// grouping (design principle #6).
class SectionHeader extends StatelessWidget {
  const SectionHeader({
    required this.title,
    this.actionLabel,
    this.onAction,
    this.trailing,
    super.key,
  });

  final String title;
  final String? actionLabel;

  /// Null with an [actionLabel] set renders the label as a plain count.
  final VoidCallback? onAction;

  /// In place of the action: a menu, sized as the action is.
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final colors = LoomiaColors.of(context);
    final label = actionLabel;

    return Padding(
      // The action's own height stands in for part of the gap.
      padding: EdgeInsets.only(
        bottom: (label != null && onAction != null) || trailing != null
            ? AppSpacing.xs
            : AppSpacing.ms,
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title.toUpperCase(),
              style: AppTypography.overline.copyWith(color: colors.textMuted),
            ),
          ),
          if (trailing case final trailing?)
            trailing
          else if (label != null)
            if (onAction == null)
              Text(
                label,
                style: AppTypography.caption.copyWith(color: colors.textMuted),
              )
            else
              // 32px, not the theme's 44: the header sits 16px tall in Figma,
              // and 32 still clears the 24px minimum target.
              TextButton(
                onPressed: onAction,
                style: TextButton.styleFrom(
                  minimumSize: const Size(0, 32),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm,
                  ),
                ),
                child: Text(label, style: AppTypography.label),
              ),
        ],
      ),
    );
  }
}

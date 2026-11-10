import 'package:loomia/app/theme/app_colors.dart';
import 'package:loomia/app/theme/app_spacing.dart';
import 'package:loomia/app/theme/app_typography.dart';
import 'package:material_ui/material_ui.dart';

/// One thing that happened (`docs/design/components.md` #14). Reads as memory,
/// not as an audit log: no edit metadata, no author.
class ActivityItem extends StatelessWidget {
  const ActivityItem({
    required this.title,
    required this.meta,
    this.showRailLine = true,
    this.dimmed = false,
    this.preview,
    super.key,
  });

  final String title;

  /// Date · kind, e.g. "2 days ago · Call".
  final String meta;

  /// Off on the last item in a list.
  final bool showRailLine;

  /// Greyed, for what is behind: a workflow's steps before the current one.
  final bool dimmed;

  /// The first line of its report, under [title], with the report icon at
  /// the end; null when there is none.
  final String? preview;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = LoomiaColors.of(context);

    // IntrinsicHeight so the rail can fill the height of the text beside it
    // without either side knowing the other's size.
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: AppSpacing.md,
            child: Column(
              children: [
                Container(
                  margin: const EdgeInsets.only(top: AppSpacing.xs),
                  width: AppSpacing.sm,
                  height: AppSpacing.sm,
                  decoration: BoxDecoration(
                    color: dimmed ? colors.borderSubtle : colors.borderStrong,
                    shape: BoxShape.circle,
                  ),
                ),
                if (showRailLine)
                  Expanded(
                    child: Container(width: 2, color: colors.borderSubtle),
                  ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.ms),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(
                bottom: showRailLine ? AppSpacing.md : 0,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: dimmed
                                ? colors.textDisabled
                                : theme.colorScheme.onSurface,
                          ),
                        ),
                      ),
                      if (preview != null)
                        Icon(
                          Icons.description_outlined,
                          size: 20,
                          color: theme.colorScheme.primary,
                        ),
                    ],
                  ),
                  if (preview case final preview?)
                    Text(
                      preview,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colors.textMuted,
                      ),
                    ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    meta,
                    style: AppTypography.caption.copyWith(
                      color: dimmed ? colors.textDisabled : colors.textMuted,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

import 'package:loomia/app/theme/app_colors.dart';
import 'package:loomia/app/theme/app_spacing.dart';
import 'package:loomia/app/theme/app_typography.dart';
import 'package:loomia/core/ui/loomia_avatar.dart';
import 'package:loomia/core/ui/loomia_chip.dart';
import 'package:loomia/core/ui/tick_ring.dart';
import 'package:loomia/l10n/app_localizations.dart';
import 'package:material_ui/material_ui.dart';

/// The unit of Today — a suggestion, not a task (`docs/design/components.md` #12).
///
/// [reason] explains why the item is shown. Usually required (it makes the item
/// an offer instead of a demand, design principle #4); nullable only when the
/// context is already clear (e.g., a task the user created themselves).
class ActionItem extends StatelessWidget {
  const ActionItem({
    required this.name,
    this.reason,
    this.photoPath,
    this.title,
    this.icon,
    this.detail,
    this.chip,
    this.tag,
    this.onOpen,
    this.onResolve,
    this.resolveLabel,
    this.resolved = false,
    this.done = false,
    this.maxLines,
    this.actions,
    super.key,
  });

  final String name;
  final String? reason;

  /// The person's photo's Storage path; null shows initials.
  final String? photoPath;

  /// The first line; defaults to [name]. The avatar always reads [name].
  final String? title;

  /// Replaces the avatar where the person is already on screen (their own
  /// page): says what kind of item this is instead.
  final IconData? icon;

  /// Metadata under [reason], quieter than it: where the item comes from.
  final String? detail;

  /// Usually an accent chip, and only when a real date drives the item.
  final Widget? chip;

  /// A neutral chip right after the name: who the person is to the user
  /// (Prospect, Customer, Team).
  final Widget? tag;

  /// Opening the row opens the person.
  final VoidCallback? onOpen;

  /// Resolves in one tap; the caller slides the row out with `SlideSwap`.
  final VoidCallback? onResolve;

  /// Label of the resolve button. Defaults to the localized "Mark as done".
  final String? resolveLabel;

  /// The tick is in flight: the ring stays filled and takes no second tap.
  final bool resolved;

  /// Already resolved, and it stays on screen: the title struck through and
  /// muted, the ring filled; [onResolve] still takes a tap, to undo it.
  final bool done;

  /// Cuts the title and the reason, each, after this many lines with "…".
  /// Null lets them run.
  final int? maxLines;

  /// Buttons under the text, for an item resolved more than one way
  /// (Going, Followed up, Remove); replaces the ring.
  final List<Widget>? actions;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = LoomiaColors.of(context);
    final chipWidget = chip;
    final label = resolveLabel ?? AppLocalizations.of(context).actionMarkAsDone;

    return Material(
      color: colors.surfaceDefault,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadii.lg),
        side: BorderSide(color: colors.borderSubtle),
      ),
      child: InkWell(
        onTap: onOpen,
        // Hover and press are the ink's own fade — the row states the wash to
        // use and lets `InkWell` time it (§7).
        hoverColor: colors.surfaceSunken,
        borderRadius: BorderRadius.circular(AppRadii.lg),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          // Intrinsic height so the avatar (or icon) and the ring can centre
          // on the card while the text stays top-aligned.
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (icon case final glyph?)
                  Center(
                    child: Container(
                      width: AvatarSize.row.diameter,
                      height: AvatarSize.row.diameter,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primaryContainer,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        glyph,
                        color: theme.colorScheme.onPrimaryContainer,
                      ),
                    ),
                  )
                else
                  Center(
                    child: PhotoAvatar(name: name, photoPath: photoPath),
                  ),
                const SizedBox(width: AppSpacing.ms),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        spacing: AppSpacing.sm,
                        children: [
                          // Flexible, not Expanded: the tag sits right after
                          // the name instead of floating at the line's end.
                          Flexible(
                            child: Text(
                              title ?? name,
                              maxLines: maxLines,
                              overflow: maxLines == null
                                  ? null
                                  : TextOverflow.ellipsis,
                              style: done
                                  ? theme.textTheme.titleMedium?.copyWith(
                                      color: colors.textMuted,
                                      decoration: TextDecoration.lineThrough,
                                    )
                                  : theme.textTheme.titleMedium,
                            ),
                          ),
                          ?tag,
                        ],
                      ),
                      if (reason case final text?) ...[
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          text,
                          maxLines: maxLines,
                          overflow: maxLines == null
                              ? null
                              : TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall,
                        ),
                      ],
                      if (detail case final meta?) ...[
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          meta,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.caption.copyWith(
                            color: colors.textMuted,
                          ),
                        ),
                      ],
                      if (chipWidget != null) ...[
                        const SizedBox(height: AppSpacing.sm),
                        chipWidget,
                      ],
                      if (actions case final buttons?) ...[
                        const SizedBox(height: AppSpacing.sm),
                        Wrap(
                          spacing: AppSpacing.xs,
                          runSpacing: AppSpacing.xs,
                          children: buttons,
                        ),
                      ],
                    ],
                  ),
                ),
                if (onResolve != null && actions == null) ...[
                  const SizedBox(width: AppSpacing.sm),
                  Center(
                    child: TickRing(
                      onPressed: resolved ? null : onResolve,
                      selected: resolved || done,
                      tooltip: label,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The accent chip an [ActionItem] uses when a real date drives it — kept here
/// so the "accent means a date" rule lives next to its only caller.
class DateChip extends StatelessWidget {
  const DateChip(this.label, {super.key});

  final String label;

  @override
  Widget build(BuildContext context) => LoomiaChip(
    label: label,
    tone: ChipTone.accent,
    icon: Icons.event_rounded,
  );
}

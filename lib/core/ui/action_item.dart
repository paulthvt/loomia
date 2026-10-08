import 'package:loomia/app/theme/app_colors.dart';
import 'package:loomia/app/theme/app_spacing.dart';
import 'package:loomia/app/theme/app_theme.dart';
import 'package:loomia/core/ui/loomia_avatar.dart';
import 'package:loomia/core/ui/loomia_chip.dart';
import 'package:loomia/l10n/app_localizations.dart';
import 'package:material_ui/material_ui.dart';

/// The unit of Today — a suggestion, not a task (`docs/design/components.md` #12).
///
/// [reason] is required on purpose: it is what makes the item an offer instead of
/// a demand (design principle #4).
class ActionItem extends StatelessWidget {
  const ActionItem({
    required this.name,
    required this.reason,
    this.title,
    this.chip,
    this.onOpen,
    this.onResolve,
    this.resolveLabel,
    this.resolved = false,
    super.key,
  });

  final String name;
  final String reason;

  /// The first line; defaults to [name]. The avatar always reads [name].
  final String? title;

  /// Usually an accent chip, and only when a real date drives the item.
  final Widget? chip;

  /// Opening the row opens the person.
  final VoidCallback? onOpen;

  /// Resolves in one tap; the caller slides the row out with `SlideSwap`.
  final VoidCallback? onResolve;

  /// Label of the resolve button. Defaults to the localized "Mark as done".
  final String? resolveLabel;

  /// The tick is in flight: the ring stays filled and takes no second tap.
  final bool resolved;

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
          // Intrinsic height so the ring can centre on the card while the
          // avatar and text stay top-aligned.
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                LoomiaAvatar(name: name),
                const SizedBox(width: AppSpacing.ms),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title ?? name, style: theme.textTheme.titleMedium),
                      const SizedBox(height: AppSpacing.xs),
                      Text(reason, style: theme.textTheme.bodySmall),
                      if (chipWidget != null) ...[
                        const SizedBox(height: AppSpacing.sm),
                        chipWidget,
                      ],
                    ],
                  ),
                ),
                if (onResolve != null) ...[
                  const SizedBox(width: AppSpacing.sm),
                  Center(
                    child: IconButton(
                      onPressed: resolved ? null : onResolve,
                      isSelected: resolved,
                      tooltip: label,
                      style: AppTheme.resolveRing(context),
                      icon: const Icon(Icons.check_rounded),
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

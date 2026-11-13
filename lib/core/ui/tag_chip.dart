import 'package:loomia/app/theme/app_colors.dart';
import 'package:loomia/app/theme/app_spacing.dart';
import 'package:loomia/app/theme/app_theme.dart';
import 'package:loomia/app/theme/app_typography.dart';
import 'package:loomia/l10n/app_localizations.dart';
import 'package:material_ui/material_ui.dart';

/// The smallest tap area of a tag chip or action.
const double tagTapTarget = 32;

/// A tag on a person (#332), the `LoomiaChip` shape in the tag's colours.
///
/// [selected] null is the plain chip (contact page, tag sheet); false and
/// true are the filter row's off and on. On takes the tag's colour, not
/// Primary: the one exception to "an active filter is Primary"
/// (`docs/design/components.md` #6).
class TagChip extends StatelessWidget {
  const TagChip({
    required this.label,
    required this.color,
    this.onTap,
    this.selected,
    this.onHero = false,
    super.key,
  });

  final String label;
  final TagColor color;
  final VoidCallback? onTap;
  final bool? selected;

  /// On the hero gradient (the Contacts filter, the contact's hero): off and
  /// plain are an outline in the hero's white, and the chip is a pill like
  /// the stage chips.
  final bool onHero;

  /// The outline's opacity on the hero.
  static const double _heroOutline = .25;

  @override
  Widget build(BuildContext context) {
    final tag = color.of(context);
    final colors = LoomiaColors.of(context);
    final off = selected == false || (onHero && selected == null);
    final (background, text) = switch ((off, onHero)) {
      (true, true) => (Colors.transparent, colors.onHero),
      (true, false) => (
        colors.surfaceSunken,
        Theme.of(context).colorScheme.onSurfaceVariant,
      ),
      _ => (tag.container, tag.ink),
    };
    final radius = BorderRadius.circular(onHero ? AppRadii.pill : AppRadii.sm);
    final chip = AnimatedContainer(
      duration: context.motion(AppMotion.quick),
      curve: AppMotion.standard,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: background,
        borderRadius: radius,
        border: off && onHero
            ? Border.all(color: colors.onHero.withValues(alpha: _heroOutline))
            : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        spacing: AppSpacing.xs,
        children: [
          if (off) TagDot(color: color),
          if (selected == true)
            Icon(Icons.check_rounded, size: 14, color: tag.ink),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.caption.copyWith(color: text),
            ),
          ),
        ],
      ),
    );
    final tap = onTap;
    if (tap == null) return chip;
    // Its own node: on the hero it shares a Material with other content.
    return Semantics(
      container: true,
      button: true,
      selected: selected,
      child: InkWell(
        onTap: tap,
        borderRadius: radius,
        // 32px like the LRP line under the stage chip: it keeps the tags
        // tight under it, and 32 still clears the 24px minimum target.
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: tagTapTarget),
          child: Align(widthFactor: 1, child: chip),
        ),
      ),
    );
  }
}

/// A tag's colour as a dot, in its ink.
class TagDot extends StatelessWidget {
  const TagDot({required this.color, this.size = 8, super.key});

  final TagColor color;
  final double size;

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      color: color.of(context).ink,
      shape: BoxShape.circle,
    ),
  );
}

/// A person's tags after their name in a list: up to [shown] dots, then
/// "+N". Read out as their names.
class TagDots extends StatelessWidget {
  const TagDots({required this.tags, this.shown = 3, super.key});

  final List<({String name, TagColor color})> tags;
  final int shown;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final more = tags.length - shown;
    return Semantics(
      label: l10n.tagsSemantics(tags.map((tag) => tag.name).join(', ')),
      child: ExcludeSemantics(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          spacing: AppSpacing.xs,
          children: [
            for (final tag in tags.take(shown)) TagDot(color: tag.color),
            if (more > 0)
              Text(
                '+$more',
                style: AppTypography.caption.copyWith(
                  color: LoomiaColors.of(context).textMuted,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// After a person's tags: "+ Add tag" when they have none, an edit chip when
/// they have some. Both open the tag sheet.
class TagAction extends StatelessWidget {
  const TagAction({
    required this.empty,
    required this.onTap,
    this.onHero = false,
    super.key,
  });

  final bool empty;
  final VoidCallback onTap;

  /// On the hero gradient: outlined in the hero's white, a pill as the
  /// tags beside it.
  final bool onHero;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = LoomiaColors.of(context);
    final ink = onHero
        ? colors.onHero
        : Theme.of(context).colorScheme.onSurfaceVariant;
    final radius = BorderRadius.circular(onHero ? AppRadii.pill : AppRadii.sm);
    final chip = Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        border: Border.all(
          color: onHero
              ? colors.onHero.withValues(alpha: TagChip._heroOutline)
              : colors.borderStrong,
        ),
        borderRadius: radius,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        spacing: AppSpacing.xs,
        children: [
          Icon(
            empty ? Icons.add_rounded : Icons.edit_outlined,
            size: 14,
            color: ink,
          ),
          if (empty)
            // Like TagChip's label: a narrow column (French, 10" tablet)
            // shortens it rather than overflowing.
            Flexible(
              child: Text(
                l10n.tagsAdd,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.caption.copyWith(color: ink),
              ),
            ),
        ],
      ),
    );
    final button = Semantics(
      container: true,
      button: true,
      label: empty ? null : l10n.tagsEdit,
      child: InkWell(
        onTap: onTap,
        borderRadius: radius,
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            minHeight: tagTapTarget,
            minWidth: tagTapTarget,
          ),
          child: Align(widthFactor: 1, child: chip),
        ),
      ),
    );
    return empty ? button : Tooltip(message: l10n.tagsEdit, child: button);
  }
}

/// A palette key's name, for screen readers on its swatch.
String tagColorName(AppLocalizations l10n, TagColor color) => switch (color) {
  TagColor.stone => l10n.tagColorStone,
  TagColor.sand => l10n.tagColorSand,
  TagColor.olive => l10n.tagColorOlive,
  TagColor.sage => l10n.tagColorSage,
  TagColor.teal => l10n.tagColorTeal,
  TagColor.sky => l10n.tagColorSky,
  TagColor.indigo => l10n.tagColorIndigo,
  TagColor.violet => l10n.tagColorViolet,
};

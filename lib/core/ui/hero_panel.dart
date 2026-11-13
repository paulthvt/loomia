import 'package:loomia/app/theme/app_colors.dart';
import 'package:loomia/app/theme/app_spacing.dart';
import 'package:loomia/app/theme/app_theme.dart';
import 'package:loomia/app/theme/app_typography.dart';
import 'package:material_ui/material_ui.dart';

/// Hero panel shape: screen-top paints under the status bar with bottom-only
/// rounded corners; band has all corners rounded (desktop).
enum HeroShape {
  /// Full width, bottom corners rounded, pads content by status bar height.
  screenTop,

  /// All corners rounded (desktop, panes).
  band,
}

/// Gradient header panel with white text/icons. Wraps its children in a column
/// with the given gap.
class HeroPanel extends StatelessWidget {
  const HeroPanel({
    required this.children,
    this.shape = HeroShape.screenTop,
    this.gap = AppSpacing.lg,
    this.padding = const EdgeInsets.fromLTRB(
      AppSpacing.lg,
      AppSpacing.md,
      AppSpacing.lg,
      AppSpacing.lg,
    ),
    super.key,
  });

  final List<Widget> children;
  final HeroShape shape;
  final double gap;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final colors = LoomiaColors.of(context);
    final statusBarPadding = MediaQuery.paddingOf(context).top;

    final borderRadius = shape == HeroShape.screenTop
        ? const BorderRadius.vertical(bottom: Radius.circular(AppRadii.hero))
        : BorderRadius.circular(AppRadii.hero);

    final effectivePadding = shape == HeroShape.screenTop
        ? padding.add(EdgeInsets.only(top: statusBarPadding))
        : padding;

    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: colors.heroGradient,
        borderRadius: borderRadius,
      ),
      child: DefaultTextStyle.merge(
        style: TextStyle(color: colors.onHero),
        child: IconTheme.merge(
          data: IconThemeData(color: colors.onHero),
          // A Material for the children's ink: without it, an InkWell's
          // splash paints on the Scaffold, under the gradient.
          child: Material(
            type: MaterialType.transparency,
            child: Padding(
              padding: effectivePadding,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (var i = 0; i < children.length; i++) ...[
                    children[i],
                    if (i < children.length - 1) SizedBox(height: gap),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Card on hero gradient: white surface with deeper shadow, resets text/icon
/// colours to onSurface.
class HeroCard extends StatelessWidget {
  const HeroCard({
    required this.child,
    this.padding = const EdgeInsets.all(AppSpacing.lg),
    super.key,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return DecoratedBox(
      decoration: AppTheme.heroCard(context),
      child: DefaultTextStyle.merge(
        style: TextStyle(color: scheme.onSurface),
        child: IconTheme.merge(
          data: IconThemeData(color: scheme.onSurface),
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }
}

/// Icon button on hero gradient: 44px circle with translucent white fill.
class HeroIconButton extends StatelessWidget {
  const HeroIconButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    super.key,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;

  /// Its look, for an icon button that is not this one (the back button).
  static ButtonStyle styleOf(BuildContext context) {
    final colors = LoomiaColors.of(context);
    return IconButton.styleFrom(
      backgroundColor: colors.heroFill,
      foregroundColor: colors.onHero,
      fixedSize: const Size.square(44),
      minimumSize: const Size.square(44),
      shape: const CircleBorder(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Icon(icon),
      tooltip: tooltip,
      onPressed: onPressed,
      style: styleOf(context),
    );
  }
}

/// The hero of a detail screen (an event, a task): back when [onBack] is
/// set, then edit and delete, the title, and its [lines]. A band on
/// desktop, where it heads a pane.
class DetailHero extends StatelessWidget {
  const DetailHero({
    required this.title,
    required this.editTooltip,
    required this.onEdit,
    required this.deleteTooltip,
    required this.onDelete,
    required this.lines,
    this.onBack,
    this.band = false,
    super.key,
  });

  final String title;
  final String editTooltip;
  final VoidCallback onEdit;
  final String deleteTooltip;
  final VoidCallback onDelete;
  final List<Widget> lines;
  final VoidCallback? onBack;
  final bool band;

  @override
  Widget build(BuildContext context) {
    final back = onBack;
    return HeroPanel(
      shape: band ? HeroShape.band : HeroShape.screenTop,
      gap: AppSpacing.md,
      children: [
        Row(
          spacing: AppSpacing.sm,
          children: [
            if (back != null)
              BackButton(
                onPressed: back,
                style: HeroIconButton.styleOf(context),
              ),
            const Spacer(),
            HeroIconButton(
              icon: Icons.edit_rounded,
              tooltip: editTooltip,
              onPressed: onEdit,
            ),
            HeroIconButton(
              icon: Icons.delete_rounded,
              tooltip: deleteTooltip,
              onPressed: onDelete,
            ),
          ],
        ),
        Text(
          title,
          style: AppTypography.headline.copyWith(
            color: LoomiaColors.of(context).onHero,
          ),
        ),
        Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: lines),
      ],
    );
  }
}

/// An icon and a line on the hero. With [onTap], the line reads as a link,
/// underlined.
class HeroLine extends StatelessWidget {
  const HeroLine({
    required this.icon,
    required this.text,
    this.onTap,
    this.trailing,
    this.singleLine = false,
    super.key,
  });

  final Widget icon;
  final String text;
  final VoidCallback? onTap;
  final Widget? trailing;
  final bool singleLine;

  @override
  Widget build(BuildContext context) {
    final onHero = LoomiaColors.of(context).onHero;
    final tap = onTap;
    final row = Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Row(
        spacing: AppSpacing.ms,
        children: [
          icon,
          Expanded(
            child: Text(
              text,
              maxLines: singleLine ? 1 : null,
              overflow: singleLine ? TextOverflow.ellipsis : null,
              style: AppTypography.bodyLarge.copyWith(
                color: onHero,
                decoration: tap == null ? null : TextDecoration.underline,
                decorationColor: onHero,
              ),
            ),
          ),
          ?trailing,
        ],
      ),
    );
    return tap == null
        ? row
        : Semantics(
            container: true,
            link: true,
            child: InkWell(onTap: tap, child: row),
          );
  }
}

/// A white pill on the hero that is not a button (the task's bell): [icon],
/// then [label] when there is one.
class HeroBadge extends StatelessWidget {
  const HeroBadge({required this.icon, this.label, super.key});

  final Widget icon;
  final String? label;

  @override
  Widget build(BuildContext context) {
    final colors = LoomiaColors.of(context);
    final text = label;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.onHero,
        borderRadius: BorderRadius.circular(AppRadii.pill),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        child: IconTheme.merge(
          data: IconThemeData(color: colors.onHeroFill, size: 18),
          // One node for a screen reader: the icon's label, then the text.
          child: MergeSemantics(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              spacing: AppSpacing.xs,
              children: [
                icon,
                if (text != null)
                  Text(
                    text,
                    style: AppTypography.labelLarge.copyWith(
                      color: colors.onHeroFill,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// "• TODAY" on the amber tint: the label of a white card on the hero.
class HeroEyebrow extends StatelessWidget {
  const HeroEyebrow(this.label, {super.key});

  final String label;

  /// The dot before the label.
  static const double _dot = 6;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.primaryContainer,
        borderRadius: BorderRadius.circular(AppRadii.pill),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.ms,
          vertical: AppSpacing.xs,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            DecoratedBox(
              decoration: BoxDecoration(
                color: scheme.primary,
                shape: BoxShape.circle,
              ),
              child: const SizedBox.square(dimension: _dot),
            ),
            const SizedBox(width: AppSpacing.sm),
            Text(
              label.toUpperCase(),
              style: AppTypography.overline.copyWith(
                color: scheme.onPrimaryContainer,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

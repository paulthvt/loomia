import 'package:loomia/app/theme/app_colors.dart';
import 'package:loomia/app/theme/app_spacing.dart';
import 'package:loomia/app/theme/app_theme.dart';
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

  @override
  Widget build(BuildContext context) {
    final colors = LoomiaColors.of(context);

    return IconButton(
      icon: Icon(icon),
      tooltip: tooltip,
      onPressed: onPressed,
      style: IconButton.styleFrom(
        backgroundColor: colors.heroFill,
        foregroundColor: colors.onHero,
        fixedSize: const Size.square(44),
        minimumSize: const Size.square(44),
        shape: const CircleBorder(),
      ),
    );
  }
}

import 'package:loomia/app/theme/app_spacing.dart';
import 'package:loomia/core/layout/breakpoints.dart';
import 'package:loomia/core/ui/hero_panel.dart';
import 'package:loomia/core/ui/loomia_top_bar.dart';
import 'package:material_ui/material_ui.dart';

/// A Settings screen: its top bar, then [child], centred and scrolling.
/// With [hero], the title (and [subtitle], [onBack]) sit on the hero.
class SettingsScroll extends StatelessWidget {
  const SettingsScroll({
    required this.title,
    required this.child,
    this.eyebrow,
    this.hero = false,
    this.subtitle,
    this.onBack,
    super.key,
  });

  final String title;

  /// Above [title], e.g. a workflow's stage.
  final String? eyebrow;
  final Widget child;
  final bool hero;
  final String? subtitle;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    final desktop = context.screenSize.isDesktop;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 600),
        child: hero
            ? HeroFormList(
                eyebrow: eyebrow,
                title: title,
                subtitle: subtitle,
                onBack: onBack,
                children: [child],
              )
            : ListView(
                padding: EdgeInsets.all(
                  desktop ? AppSpacing.xl : AppSpacing.md,
                ),
                children: [
                  LoomiaTopBar(title: title, eyebrow: eyebrow, large: desktop),
                  child,
                ],
              ),
      ),
    );
  }
}

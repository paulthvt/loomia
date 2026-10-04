import 'package:loomia/app/theme/app_spacing.dart';
import 'package:loomia/core/layout/breakpoints.dart';
import 'package:material_ui/material_ui.dart';

/// Desktop's two columns (`docs/design/responsive-design.md`): [main] up to
/// [mainMax], [side] fixed at [sideWidth], top-aligned, the pair centred.
/// A narrower window shrinks [main], never [side]. Below desktop, [main]
/// then [side] in one column.
class ContentColumns extends StatelessWidget {
  const ContentColumns({
    required this.main,
    required this.side,
    this.sideWidth = 400,
    super.key,
  });

  final List<Widget> main;
  final List<Widget> side;
  final double sideWidth;

  static const double mainMax = 624;

  @override
  Widget build(BuildContext context) {
    Widget column(List<Widget> children) => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: children,
    );
    if (!context.screenSize.isDesktop) return column([...main, ...side]);
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: mainMax + AppSpacing.xl + sideWidth,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: column(main)),
            const SizedBox(width: AppSpacing.xl),
            SizedBox(width: sideWidth, child: column(side)),
          ],
        ),
      ),
    );
  }
}

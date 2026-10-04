import 'package:loomia/app/theme/app_spacing.dart';
import 'package:loomia/core/layout/breakpoints.dart';
import 'package:material_ui/material_ui.dart';

/// Desktop's two columns (`docs/design/responsive-design.md`): [main] up to
/// [mainMax], [side] fixed at [sideWidth], top-aligned, the pair centred.
/// A narrower window shrinks [main], never [side]; once [main] would fall
/// under [mainMin] (a contact pane on a laptop), the two stack instead.
/// Below desktop, [main] then [side] in one column.
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

  /// Under this, the main column stops shrinking and the two stack.
  static const double mainMin = 300;

  /// [child] at the width of the centred pair: a top bar that lines up with
  /// the columns below it. Below desktop, [child] as it is.
  static Widget aligned(Widget child, {double sideWidth = 400}) => Builder(
    builder: (context) => context.screenSize.isDesktop
        ? Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: mainMax + AppSpacing.xl + sideWidth,
              ),
              child: SizedBox(width: double.infinity, child: child),
            ),
          )
        : child,
  );

  @override
  Widget build(BuildContext context) {
    Widget column(List<Widget> children) => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: children,
    );
    if (!context.screenSize.isDesktop) return column([...main, ...side]);
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < mainMin + AppSpacing.xl + sideWidth) {
          return column([...main, ...side]);
        }
        return _row(column);
      },
    );
  }

  Widget _row(Widget Function(List<Widget> children) column) {
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

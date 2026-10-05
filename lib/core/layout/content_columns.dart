import 'package:loomia/app/theme/app_spacing.dart';
import 'package:loomia/core/layout/breakpoints.dart';
import 'package:material_ui/material_ui.dart';

/// Desktop's two columns (`docs/design/responsive-design.md`): [side] fixed
/// at [sideWidth], [main] taking the rest, top-aligned, from the start edge
/// as in the Figma frames. The pair stops at [maxWidth]; a wider window
/// leaves the space after it. Once [main] would fall under [mainMin] (a
/// contact pane on a laptop), the two stack. Below desktop, [main] then
/// [side] in one column.
class ContentColumns extends StatelessWidget {
  const ContentColumns({
    required this.main,
    required this.side,
    this.sideWidth = 400,
    this.maxWidth = pairMax,
    super.key,
  });

  final List<Widget> main;
  final List<Widget> side;
  final double sideWidth;

  /// [pairMax] for a page; [double.infinity] inside an already bounded pane.
  final double maxWidth;

  /// One centred form column (planning, closing).
  static const double mainMax = 624;

  /// Under this, the main column stops shrinking and the two stack.
  static const double mainMin = 300;

  /// The pair at a 1440 window: 1440 − 248 sidebar − 2 × 48 padding, as in
  /// the frames. Beyond it, lines would only get longer.
  static const double pairMax = 1096;

  /// [child] at the pair's width, from the start edge: a top bar that lines
  /// up with the columns below it. Below desktop, [child] as it is.
  static Widget aligned(Widget child, {double maxWidth = pairMax}) => Builder(
    builder: (context) => context.screenSize.isDesktop
        ? Align(
            alignment: AlignmentDirectional.topStart,
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: maxWidth),
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
        return Align(
          alignment: AlignmentDirectional.topStart,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxWidth),
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
      },
    );
  }
}

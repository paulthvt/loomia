/// The phone month folding into the row that holds the selected day (#561,
/// spec §2). Geometry follows the animation's eased value `e` (0 open,
/// 1 folded); the fades follow its raw time `t`, so the other rows are gone
/// before they are clipped and the handle comes last, either way.
class MonthFold {
  const MonthFold({
    required this.rows,
    required this.selectedRow,
    required this.rowHeight,
  });

  final int rows;

  /// The row holding the selected day, from 0.
  final int selectedRow;
  final double rowHeight;

  /// How much the grid gives back once folded.
  double get distance => (rows - 1) * rowHeight;

  /// The grid's visible height.
  double height(double e) => rows * rowHeight - distance * e;

  /// How far the rows move up: the selected row ends at the top.
  double offset(double e) => -selectedRow * rowHeight * e;

  /// The rows other than the selected one: out over the first 60 % of a
  /// fold, in over the last 60 % of an unfold.
  static double othersOpacity(double t) => (1 - t / 0.6).clamp(0, 1);

  /// The handle: in over the last 30 % of a fold, out over the first 30 %
  /// of an unfold.
  static double handleOpacity(double t) => ((t - 0.7) / 0.3).clamp(0, 1);
}

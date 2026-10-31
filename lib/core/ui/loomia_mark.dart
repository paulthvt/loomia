import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';

/// The mark (Figma `07 — Loomia logo`, E5b): a ring the size of the Bold "o",
/// and three dots growing towards the top, each 0.065em clear of the ring.
///
/// Paints into a [box]-shaped canvas; geometry is in em, measured on the Figma
/// component at 100px type. [dots] scales each dot, smallest first — the
/// launch splash grows them in.
///
/// The same geometry lives in `tool/brand/icons.sh`,
/// `android/app/src/main/res/drawable/ic_launcher_foreground.xml` and the
/// marketing site's `src/components/Mark.astro` (paulthvt/loomia-site):
/// change them together.
class LoomiaMarkPainter extends CustomPainter {
  const LoomiaMarkPainter(this.color, {this.dots = const [1, 1, 1]});

  final Color color;
  final List<double> dots;

  static const outer = 0.285;
  static const _inner = 0.155;
  static const _dots = [
    (Offset(-0.35119, -0.16376), 0.0375),
    (Offset(-0.18046, -0.35418), 0.0475),
    (Offset(0.07076, -0.40131), 0.0575),
  ];

  /// Ring centre from the top-left of the box, which the dots widen and heighten.
  static const centre = Offset(0.38869, 0.45881);
  static const box = Size(0.67369, 0.74381);

  /// Space before "omia": the "o"'s left side bearing plus the Figma kerning.
  static const gap = 0.046;
  static const overshoot = 0.016;

  @override
  void paint(Canvas canvas, Size size) {
    final em = size.height / box.height;
    final paint = Paint()..color = color;
    canvas
      ..scale(em)
      ..translate(centre.dx, centre.dy)
      ..drawCircle(
        Offset.zero,
        (outer + _inner) / 2,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = outer - _inner,
      );
    for (var i = 0; i < _dots.length; i++) {
      final (at, radius) = _dots[i];
      if (dots[i] > 0) canvas.drawCircle(at, radius * dots[i], paint);
    }
  }

  @override
  bool shouldRepaint(LoomiaMarkPainter old) =>
      old.color != color || !listEquals(old.dots, dots);
}

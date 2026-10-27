import 'dart:ui' show PathMetric;

import 'package:loomia/app/theme/app_theme.dart';
import 'package:loomia/core/ui/slide_swap.dart';
import 'package:material_ui/material_ui.dart';

/// The tick ring (§7): empty with a faint check, then, once [selected], the
/// ring fills and the check is drawn, short stroke then long (240ms,
/// decelerate). Un-selected while on screen (a failed save, an untick), it
/// un-draws in 120ms. Built selected, it starts drawn.
///
/// Inside a [SlideSwap], the slot waits for the check before the row leaves.
/// Reduce motion: the whole check fades in and out (120ms), no drawing.
class TickRing extends StatefulWidget {
  const TickRing({
    required this.selected,
    this.onPressed,
    this.tooltip,
    super.key,
  });

  final bool selected;
  final VoidCallback? onPressed;
  final String? tooltip;

  @override
  State<TickRing> createState() => _TickRingState();
}

class _TickRingState extends State<TickRing>
    with SingleTickerProviderStateMixin {
  late final _controller = AnimationController(
    vsync: this,
    value: widget.selected ? 1 : 0,
  );

  @override
  void didUpdateWidget(TickRing old) {
    super.didUpdateWidget(old);
    if (widget.selected == old.selected) return;
    if (widget.selected) {
      _controller.duration = context.motion(AppMotion.medium);
      TickHold.maybeOf(context)?.attach(_controller);
      _controller.forward();
    } else {
      _controller.reverseDuration = AppMotion.fast;
      _controller.reverse();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduce = context.reduceMotion;
    return IconButton(
      onPressed: widget.onPressed,
      isSelected: widget.selected,
      tooltip: widget.tooltip,
      style: AppTheme.resolveRing(context),
      icon: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          final value = _controller.value;
          if (value == 0) return const Icon(Icons.check_rounded);
          final icon = IconTheme.of(context);
          final size = icon.size ?? 18;
          final painted = CustomPaint(
            size: Size.square(size),
            painter: CheckPainter(
              progress: reduce
                  ? 1
                  : AppMotion.decelerate.transform(value.clamp(0, 1)),
              color: icon.color ?? Theme.of(context).colorScheme.onPrimary,
            ),
          );
          return reduce ? Opacity(opacity: value, child: painted) : painted;
        },
      ),
    );
  }
}

/// `check_rounded`'s two strokes, cut to [progress] (0 nothing, 1 whole).
class CheckPainter extends CustomPainter {
  const CheckPainter({required this.progress, required this.color});

  final double progress;
  final Color color;

  // On an 18px box, the glyph's short stroke then its long one.
  static const _points = [Offset(4.5, 9.5), Offset(7.5, 12.5), Offset(13.5, 6)];

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.width / 18;
    final path = Path()
      ..moveTo(_points[0].dx * scale, _points[0].dy * scale)
      ..lineTo(_points[1].dx * scale, _points[1].dy * scale)
      ..lineTo(_points[2].dx * scale, _points[2].dy * scale);
    final PathMetric metric = path.computeMetrics().single;
    canvas.drawPath(
      metric.extractPath(0, metric.length * progress),
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2 * scale
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(CheckPainter old) =>
      old.progress != progress || old.color != color;
}

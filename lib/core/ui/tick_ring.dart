import 'dart:ui' show PathMetric;

import 'package:loomia/app/theme/app_theme.dart';
import 'package:loomia/core/ui/slide_swap.dart';
import 'package:material_ui/material_ui.dart';

/// The tick ring (§7): empty with a faint check, then, once [selected], the
/// ring fills and the check is drawn, short stroke then long (240ms,
/// decelerate), and stays whole for a beat (320ms). Un-selected while on
/// screen (a failed save, an untick), it un-draws in 120ms. Built selected,
/// it starts drawn.
///
/// Inside a [SlideSwap], the slot waits for the draw and the beat before the
/// row leaves. Reduce motion: the whole check fades in and out (120ms), no
/// drawing, and a 120ms beat.
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

  /// Tapped, and not yet confirmed by [TickRing.selected].
  var _pressed = false;

  @override
  void didUpdateWidget(TickRing old) {
    super.didUpdateWidget(old);
    if (widget.selected) {
      _pressed = false;
      if (!old.selected) _draw();
    } else if (old.selected || _pressed) {
      // A failed save, an untick, or a save that came and went before a
      // frame showed the ring selected while this row stayed.
      _pressed = false;
      // Only the draw plays back, whatever was left of the beat.
      _controller
        ..value = _controller.value.clamp(0, _share)
        ..animateBack(0, duration: AppMotion.fast);
    }
  }

  /// The draw, then a beat with the check whole: the row waits for both (the
  /// slots read this controller), so the tick is seen done.
  void _draw() {
    if (_controller.status == AnimationStatus.forward ||
        _controller.status == AnimationStatus.completed) {
      return;
    }
    _controller.duration = _drawTime + _rest;
    TickHold.maybeOf(context)?.attach(_controller);
    _controller.forward();
  }

  /// Draws at once, before the save: a save faster than a frame must not
  /// take the row away undrawn.
  void _press() {
    if (!widget.selected) {
      _pressed = true;
      _draw();
    }
    widget.onPressed?.call();
  }

  Duration get _drawTime => context.motion(AppMotion.medium);
  Duration get _rest => context.motion(AppMotion.slow);

  /// The draw's share of the controller's run; the beat is the rest.
  double get _share {
    final draw = _drawTime.inMicroseconds;
    return draw / (draw + _rest.inMicroseconds);
  }

  /// How far the check is drawn.
  double _drawn(double value) => (value / _share).clamp(0, 1);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduce = context.reduceMotion;
    return IconButton(
      onPressed: widget.onPressed == null ? null : _press,
      isSelected: widget.selected,
      tooltip: widget.tooltip,
      style: AppTheme.resolveRing(context),
      icon: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          final value = _drawn(_controller.value);
          // At rest, empty or ticked, the glyph itself: what the design
          // draws. The painter only exists while the check is being drawn.
          if (value == 0 || value == 1) {
            return const Icon(Icons.check_rounded);
          }
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

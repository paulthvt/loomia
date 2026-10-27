import 'package:loomia/app/theme/app_theme.dart';
import 'package:loomia/core/ui/slide_swap.dart';
import 'package:material_ui/material_ui.dart';

/// A fade when [child]'s key changes (§7): the new one is in place at once
/// and the old one fades out over it while the height eases. For one thing
/// replacing another in the same place: a spinner and its content, one day's
/// list and the next, Today's list and its done state.
///
/// Like `SlideSwap`, it waits for a check being drawn inside the old child
/// before swapping, so the last row ticked is seen done. Reduce motion: 120ms.
class FadeSwap extends StatefulWidget {
  const FadeSwap({required this.child, required this.duration, super.key});

  final Widget child;

  /// An `AppMotion` token.
  final Duration duration;

  @override
  State<FadeSwap> createState() => _FadeSwapState();
}

class _FadeSwapState extends State<FadeSwap> with HoldsForTick {
  @override
  Widget? get incoming => widget.child;

  @override
  Key? keyOf(Widget? child) => child?.key;

  @override
  Widget build(BuildContext context) {
    final time = context.motion(widget.duration);
    final current = shown!;
    return holdFor(
      AnimatedSize(
        duration: time,
        curve: AppMotion.standard,
        alignment: Alignment.topCenter,
        child: AnimatedSwitcher(
          duration: time,
          switchInCurve: AppMotion.decelerate,
          switchOutCurve: AppMotion.accelerate,
          // The new child is there at once; only the old one fades, on top.
          // What both share (a header, the goal line) never dims.
          transitionBuilder: (item, animation) => item.key == current.key
              ? item
              : IgnorePointer(
                  child: FadeTransition(opacity: animation, child: item),
                ),
          layoutBuilder: (current, previous) => Stack(
            fit: StackFit.passthrough,
            clipBehavior: Clip.none,
            alignment: Alignment.topCenter,
            children: [
              ?current,
              for (final old in previous)
                Positioned(top: 0, left: 0, right: 0, child: old),
            ],
          ),
          child: current,
        ),
      ),
    );
  }
}

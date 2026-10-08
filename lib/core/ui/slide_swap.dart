import 'package:loomia/app/theme/app_theme.dart';
import 'package:material_ui/material_ui.dart';

/// A slot whose card slides out to the start when [child] changes key, the
/// new one sliding in from the end at the same time (§7, 320ms). A null
/// [child] slides the card out and closes the slot: a ticked row leaving.
///
/// The height eases between the two, so the rows below follow. [padding]
/// (the gap to the row above) closes with it. Reduce motion: a fade.
class SlideSwap extends StatelessWidget {
  const SlideSwap({
    required this.child,
    this.padding = EdgeInsets.zero,
    super.key,
  });

  final Widget? child;
  final EdgeInsetsGeometry padding;

  static const _gone = Key('slide-swap-gone');

  @override
  Widget build(BuildContext context) {
    final current = child ?? const SizedBox.shrink(key: _gone);
    // Slow, not medium: at 240ms people missed that the card had changed.
    final duration = context.motion(AppMotion.slow);
    final reduce = context.reduceMotion;
    // Outside the size: the leaving card stays visible while the slot closes,
    // and the incoming one never crosses a neighbouring column.
    return ClipRect(
      child: AnimatedPadding(
        duration: duration,
        curve: AppMotion.standard,
        padding: child == null ? EdgeInsets.zero : padding,
        child: AnimatedSize(
          duration: duration,
          curve: AppMotion.standard,
          alignment: Alignment.topCenter,
          child: AnimatedSwitcher(
            duration: duration,
            switchInCurve: AppMotion.decelerate,
            switchOutCurve: AppMotion.decelerate,
            // A new closure each build, so the switcher re-wraps the outgoing
            // card too: anything that isn't [current] is leaving.
            transitionBuilder: (item, animation) {
              final faded = FadeTransition(opacity: animation, child: item);
              if (reduce) return faded;
              final from = item.key == current.key ? 1.0 : -1.0;
              return SlideTransition(
                position: Tween(
                  begin: Offset(from, 0),
                  end: Offset.zero,
                ).animate(animation),
                child: faded,
              );
            },
            // Only the current card sizes the slot; the leaving one is laid
            // over it from the top.
            layoutBuilder: (current, previous) => Stack(
              fit: StackFit.passthrough,
              clipBehavior: Clip.none,
              alignment: Alignment.topCenter,
              children: [
                for (final card in previous)
                  Positioned(top: 0, left: 0, right: 0, child: card),
                ?current,
              ],
            ),
            child: current,
          ),
        ),
      ),
    );
  }
}

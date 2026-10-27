import 'dart:async';

import 'package:loomia/app/theme/app_theme.dart';
import 'package:material_ui/material_ui.dart';

/// A slot whose card slides out to the start when [child] changes key, the
/// new one sliding in from the end at the same time (§7, 320ms). A null
/// [child] slides the card out and closes the slot: a ticked row leaving.
///
/// A card whose `TickRing` is still drawing its check stays until the check
/// is whole, then leaves: the user sees what they ticked. A card that leaves
/// with no tick (deleted elsewhere, a reload) goes at once.
///
/// The height eases between the two, so the rows below follow. [padding]
/// (the gap to the row above) closes with it. Reduce motion: a fade.
class SlideSwap extends StatefulWidget {
  const SlideSwap({
    required this.child,
    this.padding = EdgeInsets.zero,
    super.key,
  });

  final Widget? child;
  final EdgeInsetsGeometry padding;

  @override
  State<SlideSwap> createState() => _SlideSwapState();
}

class _SlideSwapState extends State<SlideSwap> {
  static const _gone = Key('slide-swap-gone');

  /// What the switcher shows: [SlideSwap.child], or the card being held.
  late Widget? _shown = widget.child;

  /// The ring drawing inside the shown card, if any.
  AnimationController? _ring;
  Timer? _hold;

  Key? _keyOf(Widget? child) => child == null ? _gone : child.key;

  @override
  void didUpdateWidget(SlideSwap old) {
    super.didUpdateWidget(old);
    _hold?.cancel();
    _hold = null;
    final next = widget.child;
    if (_keyOf(next) == _keyOf(_shown)) {
      // Same card (an Undo during the hold, a rebuild): no change of card.
      _shown = next;
      return;
    }
    final ring = _ring;
    final wait = ring == null || ring.status != AnimationStatus.forward
        ? Duration.zero
        : ring.duration! * (1 - ring.value);
    if (wait == Duration.zero) {
      _swap();
      return;
    }
    _hold = Timer(wait, () {
      if (mounted) setState(_swap);
    });
  }

  void _swap() {
    _shown = widget.child;
    _ring = null;
  }

  @override
  void dispose() {
    _hold?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final shown = _shown;
    final current = shown ?? const SizedBox.shrink(key: _gone);
    // Slow, not medium: at 240ms people missed that the card had changed.
    final duration = context.motion(AppMotion.slow);
    final reduce = context.reduceMotion;
    // Outside the size: the leaving card stays visible while the slot closes,
    // and the incoming one never crosses a neighbouring column.
    return TickHold._(
      // An outer slot (a whole state swapping) waits for the same ring.
      attach: (ring) {
        _ring = ring;
        TickHold.maybeOf(context)?.attach(ring);
      },
      child: ClipRect(
        child: AnimatedPadding(
          duration: duration,
          curve: AppMotion.standard,
          padding: shown == null ? EdgeInsets.zero : widget.padding,
          child: AnimatedSize(
            duration: duration,
            curve: AppMotion.standard,
            alignment: Alignment.topCenter,
            child: AnimatedSwitcher(
              duration: duration,
              switchInCurve: AppMotion.decelerate,
              switchOutCurve: AppMotion.decelerate,
              // A new closure each build, so the switcher re-wraps the
              // outgoing card too: anything that isn't [current] is leaving.
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
      ),
    );
  }
}

/// How a `TickRing` tells the [SlideSwap] around it that it is drawing, so
/// the slot holds its card until the check is whole.
class TickHold extends InheritedWidget {
  const TickHold._({required this.attach, required super.child});

  final void Function(AnimationController ring) attach;

  static TickHold? maybeOf(BuildContext context) =>
      context.getInheritedWidgetOfExactType<TickHold>();

  @override
  bool updateShouldNotify(TickHold old) => false;
}

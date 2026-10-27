import 'dart:async';

import 'package:loomia/app/theme/app_theme.dart';
import 'package:loomia/core/ui/slide_swap.dart';
import 'package:material_ui/material_ui.dart';

/// A column whose rows animate when the user adds or removes one (§7): a new
/// key grows in and fades in, a gone key folds out where it was (240ms). The
/// first build, and a rebuild with the same keys (a refresh), move nothing:
/// a list appears at once.
///
/// [slideOut]: a gone row slides out instead, waiting for its tick's check
/// first (`SlideSwap`), as Today's rows do; a new one appears at once.
///
/// [delay] holds every change for that long: the sheet or dialog that caused
/// it is closing. Each child needs a distinct key. Reduce motion: 120ms.
class AnimatedRows extends StatefulWidget {
  const AnimatedRows({
    required this.children,
    this.spacing = 0,
    this.gap = RowGap.between,
    this.slideOut = false,
    this.delay = Duration.zero,
    super.key,
  });

  final List<Widget> children;

  /// The gap between rows ([spacing]) belongs to a row's slot, so it opens
  /// and closes with it. [gap] says where: between rows, or above or below
  /// every row (a group that follows or precedes something else).
  final double spacing;
  final RowGap gap;
  final bool slideOut;
  final Duration delay;

  @override
  State<AnimatedRows> createState() => _AnimatedRowsState();
}

/// Where an [AnimatedRows] puts its spacing.
enum RowGap { between, above, below }

class _Row {
  _Row(this.child, {required this.fresh});

  Widget child;
  bool alive = true;

  /// Added after the first build: grows in.
  final bool fresh;
}

class _AnimatedRowsState extends State<AnimatedRows> {
  late final List<_Row> _rows = [
    for (final child in widget.children) _Row(child, fresh: false),
  ];
  final _drops = <Key, Timer>{};

  @override
  void didUpdateWidget(AnimatedRows old) {
    super.didUpdateWidget(old);
    final byKey = {for (final row in _rows) row.child.key!: row};
    final next = <_Row>[];
    for (final child in widget.children) {
      final key = child.key!;
      final row = byKey.remove(key);
      if (row == null) {
        next.add(_Row(child, fresh: true));
        continue;
      }
      _drops.remove(key)?.cancel();
      next.add(
        row
          ..child = child
          ..alive = true,
      );
    }
    // A gone row keeps its place: after the row that was above it.
    for (final (index, row) in _rows.indexed) {
      if (!byKey.containsKey(row.child.key)) continue;
      var at = 0;
      for (var above = index - 1; above >= 0; above--) {
        final found = next.indexOf(_rows[above]);
        if (found != -1) {
          at = found + 1;
          break;
        }
      }
      next.insert(at, row);
      if (row.alive) {
        row.alive = false;
        final key = row.child.key!;
        _drops[key] = Timer(_lingers(), () {
          if (!mounted) return;
          setState(() => _rows.removeWhere((each) => each.child.key == key));
          _drops.remove(key);
        });
      }
    }
    _rows
      ..clear()
      ..addAll(next);
  }

  /// How long a gone row stays in the tree: its whole exit.
  Duration _lingers() =>
      widget.delay +
      (widget.slideOut
          ? context.motion(AppMotion.medium) + context.motion(AppMotion.slow)
          : context.motion(AppMotion.medium));

  @override
  void dispose() {
    for (final timer in _drops.values) {
      timer.cancel();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    var above = false;
    final slots = <Widget>[];
    for (final row in _rows) {
      final gap = widget.gap != RowGap.between || above ? widget.spacing : 0.0;
      final padding = widget.gap == RowGap.below
          ? EdgeInsets.only(bottom: gap)
          : EdgeInsets.only(top: gap);
      final key = row.child.key!;
      slots.add(
        widget.slideOut
            ? SlideSwap(
                key: _SlotKey(key),
                padding: padding,
                child: row.alive ? row.child : null,
              )
            : _Grow(
                key: _SlotKey(key),
                visible: row.alive,
                fresh: row.fresh,
                delay: widget.delay,
                padding: padding,
                child: row.child,
              ),
      );
      if (row.alive) above = true;
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: slots,
    );
  }
}

/// A slot's key, distinct from its row's own key in the same subtree.
class _SlotKey extends ValueKey<Key> {
  const _SlotKey(super.value);
}

/// One row growing in (fresh) or folding out (not [visible]).
class _Grow extends StatefulWidget {
  const _Grow({
    required this.visible,
    required this.fresh,
    required this.delay,
    required this.padding,
    required this.child,
    super.key,
  });

  final bool visible;
  final bool fresh;
  final Duration delay;
  final EdgeInsets padding;
  final Widget child;

  @override
  State<_Grow> createState() => _GrowState();
}

class _GrowState extends State<_Grow> with SingleTickerProviderStateMixin {
  late final _controller = AnimationController(
    vsync: this,
    value: widget.fresh ? 0 : 1,
  );
  late final _curved = CurvedAnimation(
    parent: _controller,
    curve: AppMotion.decelerate,
    // Leaving accelerates: slow at first, in time.
    reverseCurve: AppMotion.accelerate.flipped,
  );
  Timer? _wait;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _controller.duration = context.motion(AppMotion.medium);
    if (widget.fresh && _controller.value == 0 && _wait == null) {
      _later(_controller.forward);
    }
  }

  @override
  void didUpdateWidget(_Grow old) {
    super.didUpdateWidget(old);
    if (widget.visible == old.visible) return;
    _later(widget.visible ? _controller.forward : _controller.reverse);
  }

  void _later(TickerFuture Function() run) {
    _wait?.cancel();
    if (widget.delay == Duration.zero) {
      run();
      return;
    }
    _wait = Timer(widget.delay, () {
      if (mounted) run();
    });
  }

  @override
  void dispose() {
    _wait?.cancel();
    _curved.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final curved = _curved;
    return SizeTransition(
      sizeFactor: curved,
      alignment: Alignment.topCenter,
      child: FadeTransition(
        opacity: curved,
        child: Padding(padding: widget.padding, child: widget.child),
      ),
    );
  }
}

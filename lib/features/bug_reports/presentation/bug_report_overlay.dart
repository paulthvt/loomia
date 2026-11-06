import 'package:feedback/feedback.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loomia/app/router/app_router.dart';
import 'package:loomia/app/theme/app_spacing.dart';
import 'package:loomia/app/theme/app_theme.dart';
import 'package:loomia/features/bug_reports/data/device_facts.dart';
import 'package:loomia/features/bug_reports/presentation/bug_report_controller.dart';
import 'package:loomia/features/bug_reports/presentation/bug_report_mode.dart';
import 'package:loomia/l10n/app_localizations.dart';
import 'package:material_ui/material_ui.dart';

/// Height above the bottom inset where the button never rests: the
/// navigation bar (80) and a floating snackbar (88), so it never covers a
/// snackbar's action (Undo, Retry). Figma "Bug reports — #463", frames 7–8.
// ponytail: one fixed band for every size class; desktop has no bottom bar,
// so it gets a little more empty room than it needs.
const double bugReportBand = 168;

const double _buttonSize = 48;
const double _margin = AppSpacing.md;
const double _targetIdle = 56;
const double _targetOver = 72;

/// How close (centre to centre) a drop must be to the ✕ to turn reports off.
const double _dropRadius = 48;

/// The floating bug-report button over every screen while the mode is on
/// (#463), and the ✕ it is dragged onto to turn the mode off. Sits inside
/// `BetterFeedback`, so it is hidden while the panel is open (and never in
/// the screenshot).
class BugReportOverlay extends ConsumerStatefulWidget {
  const BugReportOverlay({required this.child, super.key});

  final Widget child;

  @override
  ConsumerState<BugReportOverlay> createState() => _BugReportOverlayState();
}

class _BugReportOverlayState extends ConsumerState<BugReportOverlay> {
  /// Top-left of the button; null until placed at its start.
  Offset? _position;

  /// Where a drag began, restored when the drop turns the mode off, so Undo
  /// puts the button back.
  Offset? _beforeDrag;
  bool _dragging = false;
  bool _over = false;

  Rect _safe(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final padding = MediaQuery.paddingOf(context);
    return Rect.fromLTRB(
      padding.left + _margin,
      padding.top + _margin,
      size.width - padding.right - _margin - _buttonSize,
      size.height - padding.bottom - _margin - _buttonSize,
    );
  }

  /// The lowest top the button may rest at.
  double _restBottom(BuildContext context) =>
      MediaQuery.sizeOf(context).height -
      MediaQuery.paddingOf(context).bottom -
      bugReportBand -
      _buttonSize;

  Offset _clamp(Offset p, Rect safe) => Offset(
    p.dx.clamp(safe.left, safe.right),
    p.dy.clamp(safe.top, safe.bottom),
  );

  Offset _targetCentre(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    return Offset(
      size.width / 2,
      size.height -
          MediaQuery.paddingOf(context).bottom -
          AppSpacing.lg -
          _targetOver / 2,
    );
  }

  Offset _start(BuildContext context) =>
      Offset(_safe(context).right, _restBottom(context));

  void _onPanUpdate(DragUpdateDetails details) {
    final position = _clamp(
      (_position ?? _start(context)) + details.delta,
      _safe(context),
    );
    final centre = position + const Offset(_buttonSize / 2, _buttonSize / 2);
    setState(() {
      _position = position;
      _over = (centre - _targetCentre(context)).distance <= _dropRadius;
    });
  }

  void _onPanEnd() {
    if (_over) {
      final messenger = ScaffoldMessenger.of(context);
      final l10n = AppLocalizations.of(context);
      final mode = ref.read(bugReportModeProvider.notifier);
      setState(() {
        _position = _beforeDrag;
        _dragging = _over = false;
      });
      mode.turnOff();
      messenger.showSnackBar(
        SnackBar(
          content: Text(l10n.bugReportsOff),
          // An action keeps a snackbar up while accessibleNavigation is on,
          // which any Android accessibility service turns on (#386, #467).
          persist: false,
          action: SnackBarAction(
            label: l10n.bugReportUndo,
            onPressed: mode.turnOn,
          ),
        ),
      );
      return;
    }
    final p = _position ?? _start(context);
    final rest = _restBottom(context);
    setState(() {
      _position = Offset(p.dx, p.dy > rest ? rest : p.dy);
      _dragging = false;
    });
  }

  void _open() {
    final feedback = BetterFeedback.of(context);
    final controller = ref.read(bugReportControllerProvider.notifier);
    // Read now: the panel shrinks the app, so size and route are the
    // screen's as the tester saw it.
    final route = ref
        .read(routerProvider)
        .routerDelegate
        .currentConfiguration
        .uri
        .path;
    final locale = Localizations.localeOf(context);
    final size = MediaQuery.sizeOf(context);
    final brightness = Theme.of(context).brightness;
    feedback.show((userFeedback) async {
      final facts = await collectDeviceFacts(
        route: route,
        locale: locale,
        size: size,
        brightness: brightness,
      );
      await controller.submit(userFeedback, facts: facts);
    });
  }

  void _onSendState(BugReportSendState state) {
    final messenger = ScaffoldMessenger.of(context);
    final l10n = AppLocalizations.of(context);
    switch (state) {
      case Sent(:final issue):
        messenger.showSnackBar(
          SnackBar(content: Text(l10n.bugReportSent(issue))),
        );
      case Failed():
        messenger.showSnackBar(
          SnackBar(
            content: Text(l10n.bugReportFailed),
            // Same as "Bug reports off": close even with a service on.
            persist: false,
            action: SnackBarAction(
              label: l10n.bugReportRetry,
              onPressed: ref.read(bugReportControllerProvider.notifier).retry,
            ),
          ),
        );
      case Idle() || Sending():
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(bugReportControllerProvider, (_, next) => _onSendState(next));
    final on = ref.watch(bugReportModeProvider);
    final feedback = BetterFeedback.of(context);
    return Stack(
      fit: StackFit.expand,
      children: [
        widget.child,
        if (on)
          ListenableBuilder(
            listenable: feedback,
            builder: (context, _) =>
                feedback.isVisible ? const SizedBox.shrink() : _controls(),
          ),
      ],
    );
  }

  Widget _controls() {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final position = _position ?? _start(context);
    final target = _targetCentre(context);
    final targetSize = _over ? _targetOver : _targetIdle;
    return Stack(
      children: [
        if (_dragging)
          Positioned(
            left: target.dx - targetSize / 2,
            top: target.dy - targetSize / 2,
            child: Semantics(
              label: l10n.bugReportDismissTarget,
              child: AnimatedContainer(
                duration: AppMotion.fast,
                width: targetSize,
                height: targetSize,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  // The ink colour, not red: red is for errors.
                  color: _over
                      ? scheme.onSurface
                      : scheme.surfaceContainerHighest,
                ),
                child: Icon(
                  Icons.close_rounded,
                  color: _over ? scheme.surface : scheme.onSurface,
                ),
              ),
            ),
          ),
        // Keyed: the ✕ appearing before it must not rebuild it mid-drag,
        // which would drop the gesture.
        Positioned(
          key: const ValueKey('bug-report-button'),
          left: position.dx,
          top: position.dy,
          child: GestureDetector(
            // From the touch-down point, so the button stays under the
            // finger instead of lagging by the drag slop.
            dragStartBehavior: DragStartBehavior.down,
            onPanStart: (_) => setState(() {
              _beforeDrag = position;
              _dragging = true;
            }),
            onPanUpdate: _onPanUpdate,
            onPanEnd: (_) => _onPanEnd(),
            onPanCancel: () => setState(() => _dragging = _over = false),
            child: Semantics(
              label: l10n.bugReportButton,
              button: true,
              excludeSemantics: true,
              child: SizedBox.square(
                dimension: _buttonSize,
                child: IconButton.filledTonal(
                  style: AppTheme.tonal(context),
                  onPressed: _open,
                  icon: const Icon(Icons.bug_report_outlined),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

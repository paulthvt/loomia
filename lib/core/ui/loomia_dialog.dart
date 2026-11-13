import 'package:loomia/app/theme/app_spacing.dart';
import 'package:loomia/core/layout/breakpoints.dart';
import 'package:material_ui/material_ui.dart';

/// ConfirmDialog (`docs/design/components.md` #19), and any short form: a
/// bottom sheet on mobile, a centred dialog elsewhere, the same internals.
class LoomiaDialog extends StatelessWidget {
  const LoomiaDialog({
    required this.title,
    required this.actions,
    this.body,
    this.child,
    this.footer,
    super.key,
  });

  static const double _maxWidth = 480;

  final String title;
  final String? body;

  /// A form field, under the body. It scrolls when the keyboard leaves too
  /// little room; the title and the buttons stay.
  final Widget? child;

  /// The safe action first, then the primary one, read left to right. In a
  /// sheet they share the width, so the keyboard leaves room for the form.
  final List<Widget> actions;

  /// A secondary action, centred under [actions].
  final Widget? footer;

  static Future<T?> show<T>(BuildContext context, WidgetBuilder builder) =>
      context.screenSize.isMobile
      ? showModalBottomSheet<T>(
          context: context,
          // Over the floating bar, which a tab's own navigator lies under.
          useRootNavigator: true,
          isScrollControlled: true,
          useSafeArea: true,
          showDragHandle: true,
          builder: builder,
        )
      : showDialog<T>(
          context: context,
          builder: (context) => Dialog(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: _maxWidth),
              child: builder(context),
            ),
          ),
        );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final mobile = context.screenSize.isMobile;
    final bodyText = body;

    return Padding(
      // Keeps a sheet's field above the keyboard.
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      // `useSafeArea` only clears the top; this clears the system navigation
      // bar under a sheet.
      child: SafeArea(
        top: false,
        child: Padding(
          padding: mobile
              ? const EdgeInsets.fromLTRB(
                  AppSpacing.lg,
                  0,
                  AppSpacing.lg,
                  AppSpacing.lg,
                )
              : const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: AppSpacing.ms,
            children: [
              Text(title, style: theme.textTheme.titleLarge),
              if (bodyText != null)
                Text(
                  bodyText,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              if (child case final child?)
                Flexible(child: SingleChildScrollView(child: child)),
              const SizedBox(height: AppSpacing.xs),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                spacing: AppSpacing.sm,
                children: [
                  for (final action in actions)
                    mobile ? Expanded(child: action) : action,
                ],
              ),
              if (footer case final footer?) Center(child: footer),
            ],
          ),
        ),
      ),
    );
  }
}

/// "Delete …?" with Cancel and a red [action]; true once confirmed.
Future<bool> confirmDestructive(
  BuildContext context, {
  required String title,
  required String action,
  String? body,
}) async {
  final confirmed = await LoomiaDialog.show<bool>(context, (context) {
    final scheme = Theme.of(context).colorScheme;
    return LoomiaDialog(
      title: title,
      body: body,
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text(MaterialLocalizations.of(context).cancelButtonLabel),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: scheme.error,
            foregroundColor: scheme.onError,
          ),
          onPressed: () => Navigator.pop(context, true),
          child: Text(action),
        ),
      ],
    );
  });
  return confirmed ?? false;
}

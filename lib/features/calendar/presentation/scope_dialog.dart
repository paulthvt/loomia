import 'package:loomia/app/theme/app_colors.dart';
import 'package:loomia/core/ui/loomia_dialog.dart';
import 'package:loomia/l10n/app_localizations.dart';
import 'package:material_ui/material_ui.dart';

/// What a change on an occurrence of a repeating event reaches (#299).
enum EventScope { one, following }

/// "This event" or "This and following events", before a change on an
/// occurrence: Save, Add people and Remove ([delete] false), or Delete,
/// confirmed here with no second dialog. [ruleChanged]: a new repeat only
/// reaches the following ones, so "This event" is off. Null when cancelled.
Future<EventScope?> pickScope(
  BuildContext context, {
  bool delete = false,
  bool ruleChanged = false,
}) => LoomiaDialog.show<EventScope>(
  context,
  (_) => _ScopeDialog(delete: delete, ruleChanged: ruleChanged),
);

class _ScopeDialog extends StatefulWidget {
  const _ScopeDialog({this.delete = false, this.ruleChanged = false});

  final bool delete;
  final bool ruleChanged;

  @override
  State<_ScopeDialog> createState() => _ScopeDialogState();
}

class _ScopeDialogState extends State<_ScopeDialog> {
  late EventScope _scope = widget.ruleChanged
      ? EventScope.following
      : EventScope.one;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return LoomiaDialog(
      title: widget.delete
          ? l10n.eventScopeDeleteTitle
          : l10n.eventScopeChangeTitle,
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(MaterialLocalizations.of(context).cancelButtonLabel),
        ),
        FilledButton(
          style: widget.delete
              ? FilledButton.styleFrom(
                  backgroundColor: scheme.error,
                  foregroundColor: scheme.onError,
                )
              : null,
          onPressed: () => Navigator.pop(context, _scope),
          child: Text(
            widget.delete
                ? l10n.eventDeleteAction
                : MaterialLocalizations.of(context).saveButtonLabel,
          ),
        ),
      ],
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          RadioGroup<EventScope>(
            groupValue: _scope,
            onChanged: (scope) => setState(() => _scope = scope ?? _scope),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                RadioListTile<EventScope>(
                  value: EventScope.one,
                  enabled: !widget.ruleChanged,
                  contentPadding: EdgeInsets.zero,
                  title: Text(l10n.eventScopeThis),
                ),
                RadioListTile<EventScope>(
                  value: EventScope.following,
                  contentPadding: EdgeInsets.zero,
                  title: Text(l10n.eventScopeFollowing),
                ),
              ],
            ),
          ),
          if (widget.ruleChanged)
            Text(
              l10n.eventScopeRuleChanged,
              style: theme.textTheme.bodySmall?.copyWith(
                color: LoomiaColors.of(context).textMuted,
              ),
            ),
        ],
      ),
    );
  }
}

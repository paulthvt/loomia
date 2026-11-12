import 'package:loomia/app/theme/app_colors.dart';
import 'package:loomia/app/theme/app_spacing.dart';
import 'package:loomia/core/ui/loomia_dialog.dart';
import 'package:loomia/l10n/app_localizations.dart';
import 'package:material_ui/material_ui.dart';

/// What a change on an occurrence of a repeating event reaches (#299).
enum EventScope { one, following }

/// Whose wording the scope dialog uses: a repeating event, task (#376) or
/// reminder (#486).
enum ScopeWording { event, task, reminder }

/// "This event" or "This and following events", before a change on an
/// occurrence: Save, Add people and Remove ([delete] false), or Delete,
/// confirmed here with no second dialog. [ruleChanged]: a new repeat only
/// reaches the following ones, so "This event" is off. [wording]: an
/// event's, a task's or a reminder's. [losesReport]: the choices that remove
/// an event with a report, warned about once chosen. Null when cancelled.
Future<EventScope?> pickScope(
  BuildContext context, {
  bool delete = false,
  bool ruleChanged = false,
  ScopeWording wording = ScopeWording.event,
  Set<EventScope> losesReport = const {},
}) => LoomiaDialog.show<EventScope>(
  context,
  (_) => _ScopeDialog(
    delete: delete,
    ruleChanged: ruleChanged,
    wording: wording,
    losesReport: losesReport,
  ),
);

class _ScopeDialog extends StatefulWidget {
  const _ScopeDialog({
    this.delete = false,
    this.ruleChanged = false,
    this.wording = ScopeWording.event,
    this.losesReport = const {},
  });

  final bool delete;
  final bool ruleChanged;
  final ScopeWording wording;
  final Set<EventScope> losesReport;

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
      title: switch ((widget.wording, widget.delete)) {
        (ScopeWording.event, false) => l10n.eventScopeChangeTitle,
        (ScopeWording.event, true) => l10n.eventScopeDeleteTitle,
        (ScopeWording.task, false) => l10n.taskScopeChangeTitle,
        (ScopeWording.task, true) => l10n.taskScopeDeleteTitle,
        (ScopeWording.reminder, false) => l10n.reminderScopeChangeTitle,
        (ScopeWording.reminder, true) => l10n.reminderScopeDeleteTitle,
      },
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
                  title: Text(switch (widget.wording) {
                    ScopeWording.event => l10n.eventScopeThis,
                    ScopeWording.task => l10n.taskScopeThis,
                    ScopeWording.reminder => l10n.reminderScopeThis,
                  }),
                ),
                RadioListTile<EventScope>(
                  value: EventScope.following,
                  contentPadding: EdgeInsets.zero,
                  title: Text(switch (widget.wording) {
                    ScopeWording.event => l10n.eventScopeFollowing,
                    ScopeWording.task => l10n.taskScopeFollowing,
                    ScopeWording.reminder => l10n.reminderScopeFollowing,
                  }),
                ),
              ],
            ),
          ),
          if (widget.ruleChanged)
            Text(
              switch (widget.wording) {
                ScopeWording.event => l10n.eventScopeRuleChanged,
                ScopeWording.task => l10n.taskScopeRuleChanged,
                ScopeWording.reminder => l10n.reminderScopeRuleChanged,
              },
              style: theme.textTheme.bodySmall?.copyWith(
                color: LoomiaColors.of(context).textMuted,
              ),
            ),
          if (widget.losesReport.contains(_scope))
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.sm),
              child: Text(
                l10n.eventScopeReportLost,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: scheme.error,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

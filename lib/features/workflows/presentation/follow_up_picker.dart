import 'package:loomia/app/theme/app_theme.dart';
import 'package:loomia/features/contacts/domain/person.dart';
import 'package:loomia/features/workflows/domain/workflow.dart';
import 'package:loomia/l10n/app_localizations.dart';
import 'package:material_ui/material_ui.dart';

/// A row: [stage], and a dropdown for which workflow people at it start, or
/// null for "Keep their workflow". A [value] not among [workflows] shows as
/// null. Controlled: it shows [value], so a failed save shows the saved one
/// again. A null [onChanged] disables it.
class FollowUpPicker extends StatelessWidget {
  const FollowUpPicker({
    required this.stage,
    required this.workflows,
    required this.value,
    required this.onChanged,
    super.key,
  });

  final Stage stage;
  final List<Workflow> workflows;
  final String? value;
  final ValueChanged<String?>? onChanged;

  /// Long workflow names ellipsize rather than squeeze the stage.
  static const double _maxWidth = 200;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final available = forStage(workflows, stage);
    final current = available.any((w) => w.id == value) ? value : null;
    Widget item(String text) => Text(text, overflow: TextOverflow.ellipsis);
    return ListTile(
      title: Text(l10n.eventWorkflowStage(stage.name)),
      trailing: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: _maxWidth),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<String?>(
            value: current,
            isExpanded: true,
            style: AppTheme.rowDropdown(context),
            items: [
              DropdownMenuItem<String?>(child: item(l10n.eventWorkflowKeep)),
              for (final w in available)
                DropdownMenuItem<String?>(value: w.id, child: item(w.name)),
            ],
            onChanged: onChanged,
          ),
        ),
      ),
    );
  }
}

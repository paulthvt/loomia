import 'package:loomia/app/theme/app_spacing.dart';
import 'package:loomia/features/contacts/domain/person.dart';
import 'package:loomia/features/workflows/domain/workflow.dart';
import 'package:loomia/l10n/app_localizations.dart';
import 'package:material_ui/material_ui.dart';

/// A dropdown for choosing which workflow people at [stage] start, or null
/// for "Keep their workflow". The [value] not among [workflows] shows as null.
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
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final available = forStage(workflows, stage);
    final currentValue = value != null && available.any((w) => w.id == value)
        ? value
        : null;
    return DropdownButtonFormField<String?>(
      key: ValueKey('$stage-$currentValue'),
      isExpanded: true,
      decoration: const InputDecoration(
        contentPadding: EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
      ),
      initialValue: currentValue,
      items: [
        DropdownMenuItem<String?>(
          value: null,
          child: Text(l10n.eventWorkflowKeep),
        ),
        for (final w in available)
          DropdownMenuItem<String?>(value: w.id, child: Text(w.name)),
      ],
      onChanged: onChanged,
    );
  }
}

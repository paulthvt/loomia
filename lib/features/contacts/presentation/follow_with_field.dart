import 'package:loomia/app/theme/app_spacing.dart';
import 'package:loomia/core/ui/labeled_field.dart';
import 'package:loomia/core/ui/pick_day.dart';
import 'package:loomia/core/ui/section_header.dart';
import 'package:loomia/features/contacts/presentation/people_copy.dart';
import 'package:loomia/features/workflows/domain/progress.dart';
import 'package:loomia/features/workflows/domain/workflow.dart';
import 'package:loomia/features/workflows/presentation/workflows_settings.dart';
import 'package:loomia/l10n/app_localizations.dart';
import 'package:material_ui/material_ui.dart';

/// What follows: one of a stage's workflows and its first step's day, or
/// nothing. Controlled — the sheet holds [value].
class FollowWithField extends StatelessWidget {
  const FollowWithField({
    required this.workflows,
    required this.value,
    required this.today,
    required this.onChanged,
    super.key,
  });

  /// One stage's, default first (`forStage`).
  final List<Workflow> workflows;

  /// Null is "Nothing for now".
  final FollowWith? value;
  final DateTime today;
  final ValueChanged<FollowWith?> onChanged;

  // The radio value of "Nothing for now"; ids are uuids, never empty.
  static const _nothing = '';

  Future<void> _pickDay(BuildContext context, FollowWith follow) async {
    final day = await pickDay(
      context,
      initial: follow.firstDue,
      first: today,
      // ponytail: two years out is far enough for a first step; widen if asked.
      last: addDays(today, 730),
    );
    if (day != null) onChanged((workflow: follow.workflow, firstDue: day));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final follow = value;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeader(title: l10n.followWithTitle),
        RadioGroup<String>(
          groupValue: follow?.workflow.id ?? _nothing,
          onChanged: (id) => onChanged(switch (findWorkflow(workflows, id)) {
            final workflow? => (
              workflow: workflow,
              firstDue: firstDueDefault(workflow, today),
            ),
            null => null,
          }),
          child: Column(
            children: [
              for (final workflow in workflows)
                RadioListTile<String>(
                  value: workflow.id,
                  contentPadding: EdgeInsets.zero,
                  title: Text(workflow.name),
                  subtitle: Text(
                    workflow.isDefault
                        ? l10n.followWithSuggestedSteps(
                            workflowSteps(l10n, workflow),
                          )
                        : workflowSteps(l10n, workflow),
                  ),
                ),
              RadioListTile<String>(
                value: _nothing,
                contentPadding: EdgeInsets.zero,
                title: Text(l10n.followWithNothing),
              ),
            ],
          ),
        ),
        if (follow != null) ...[
          const SizedBox(height: AppSpacing.sm),
          LabeledField(
            label:
                follow.workflow.steps.firstOrNull?.label ??
                follow.workflow.name,
            child: Semantics(
              button: true,
              child: InkWell(
                onTap: () => _pickDay(context, follow),
                child: InputDecorator(
                  decoration: const InputDecoration(
                    suffixIcon: Icon(Icons.calendar_today_outlined),
                  ),
                  child: Text(
                    follow.firstDue == today
                        ? l10n.logWhenToday(today)
                        : dayLabel(l10n, follow.firstDue, today),
                  ),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

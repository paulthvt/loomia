import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:loomia/app/router/routes.dart';
import 'package:loomia/app/theme/app_spacing.dart';
import 'package:loomia/app/theme/app_theme.dart';
import 'package:loomia/core/layout/breakpoints.dart';
import 'package:loomia/core/ui/empty_state.dart';
import 'package:loomia/core/ui/form_error.dart';
import 'package:loomia/core/ui/labeled_field.dart';
import 'package:loomia/core/ui/loomia_dialog.dart';
import 'package:loomia/core/ui/section_header.dart';
import 'package:loomia/features/auth/data/auth_repository.dart';
import 'package:loomia/features/contacts/domain/people_failure.dart';
import 'package:loomia/features/contacts/domain/person.dart';
import 'package:loomia/features/contacts/presentation/people_copy.dart';
import 'package:loomia/features/settings/presentation/widgets/settings_group.dart';
import 'package:loomia/features/workflows/domain/event_workflow.dart';
import 'package:loomia/features/workflows/domain/workflow.dart';
import 'package:loomia/features/workflows/presentation/event_workflows_controller.dart';
import 'package:loomia/features/workflows/presentation/workflows_controller.dart';
import 'package:loomia/l10n/app_localizations.dart';
import 'package:material_ui/material_ui.dart';

/// Settings → Workflows, on the signed-in account's workflows.
class WorkflowsSettings extends ConsumerWidget {
  const WorkflowsSettings({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final owner = ref.watch(accountProvider)?.email;
    final workflows = workflowsProvider(owner);
    final state = ref.watch(workflows);
    final list = state.value;
    final eventWorkflows = eventWorkflowsProvider(owner);
    final eventState = ref.watch(eventWorkflows);
    final events = eventState.value;
    if (list == null) {
      return state.hasError
          ? WorkflowsLoadError(onRetry: () => ref.invalidate(workflows))
          : const Center(
              child: Padding(
                padding: EdgeInsets.all(AppSpacing.xl),
                child: CircularProgressIndicator(),
              ),
            );
    }
    return WorkflowsView(
      workflows: list,
      onOpen: (workflow) => openWorkflow(context, workflow.id),
      onNew: () => unawaited(showNewWorkflow(context)),
      eventWorkflows: events ?? const [],
      onOpenEvent: (w) => openEventWorkflow(context, w.id),
      onNewEvent: () => unawaited(showNewEventWorkflow(context)),
    );
  }
}

/// The list, fed its data: one group per stage that has workflows, the
/// default first. Also what the preview shows.
class WorkflowsView extends StatelessWidget {
  const WorkflowsView({
    required this.workflows,
    required this.onOpen,
    required this.onNew,
    required this.eventWorkflows,
    required this.onOpenEvent,
    required this.onNewEvent,
    super.key,
  });

  final List<Workflow> workflows;
  final ValueChanged<Workflow> onOpen;
  final VoidCallback onNew;
  final List<EventWorkflow> eventWorkflows;
  final ValueChanged<EventWorkflow> onOpenEvent;
  final VoidCallback onNewEvent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          l10n.workflowsIntro,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        for (final stage in Stage.values)
          if (forStage(workflows, stage) case final group
              when group.isNotEmpty) ...[
            SectionHeader(title: _stageHeader(l10n, stage)),
            SettingsGroup(
              children: [
                for (final workflow in group)
                  ListTile(
                    title: Text(workflow.name),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      spacing: AppSpacing.sm,
                      children: [
                        Text(_steps(l10n, workflow)),
                        const Icon(Icons.chevron_right_rounded),
                      ],
                    ),
                    onTap: () => onOpen(workflow),
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
          ],
        FilledButton.tonalIcon(
          onPressed: onNew,
          style: AppTheme.tonal(context),
          icon: const Icon(Icons.add_rounded),
          label: Text(l10n.workflowsNew),
        ),
        const SizedBox(height: AppSpacing.xl),
        SectionHeader(title: l10n.workflowsEvents),
        if (eventWorkflows.isNotEmpty)
          SettingsGroup(
            children: [
              for (final workflow in [
                ...eventWorkflows,
              ]..sort((a, b) => a.name.compareTo(b.name)))
                ListTile(
                  title: Text(workflow.name),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    spacing: AppSpacing.sm,
                    children: [
                      Text(l10n.followWithSteps(workflow.steps.length)),
                      const Icon(Icons.chevron_right_rounded),
                    ],
                  ),
                  onTap: () => onOpenEvent(workflow),
                ),
            ],
          ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          l10n.workflowsEventsHint,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        FilledButton.tonalIcon(
          onPressed: onNewEvent,
          style: AppTheme.tonal(context),
          icon: const Icon(Icons.add_rounded),
          label: Text(l10n.eventWorkflowNew),
        ),
      ],
    );
  }

  static String _stageHeader(AppLocalizations l10n, Stage stage) =>
      switch (stage) {
        Stage.prospect => l10n.contactsFilterProspects,
        Stage.customer => l10n.contactsFilterCustomers,
        Stage.team => l10n.contactsFilterTeam,
      };

  static String _steps(AppLocalizations l10n, Workflow workflow) {
    final steps = l10n.followWithSteps(workflow.steps.length);
    return workflow.isDefault ? l10n.workflowsDefaultSteps(steps) : steps;
  }
}

/// The workflows did not load. Existing copy: Next step says the same.
class WorkflowsLoadError extends StatelessWidget {
  const WorkflowsLoadError({required this.onRetry, super.key});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Center(
      child: EmptyState(
        icon: Icons.cloud_off_outlined,
        title: l10n.nextStepLoadFailed,
        body: l10n.contactsLoadErrorBody,
        actionLabel: l10n.contactsRetry,
        onAction: onRetry,
      ),
    );
  }
}

/// In the pane in place of the list on desktop; elsewhere pushed, so back
/// returns to the list.
void openWorkflow(BuildContext context, String id) {
  final location = Routes.settingsWorkflowLocation(id);
  if (context.screenSize.isDesktop) {
    context.go(location);
  } else {
    context.push(location);
  }
}

/// Name and stage. Create writes, then opens the editor on the new workflow.
Future<void> showNewWorkflow(BuildContext context) async {
  final created = await LoomiaDialog.show<Workflow>(
    context,
    (_) => const _NewWorkflowForm(),
  );
  if (created != null && context.mounted) openWorkflow(context, created.id);
}

/// In the pane in place of the list on desktop; elsewhere pushed, so back
/// returns to the list.
void openEventWorkflow(BuildContext context, String id) {
  final location = Routes.settingsEventWorkflowLocation(id);
  if (context.screenSize.isDesktop) {
    context.go(location);
  } else {
    context.push(location);
  }
}

/// Name only. Create writes, then opens the editor on the new event workflow.
Future<void> showNewEventWorkflow(BuildContext context) async {
  final created = await LoomiaDialog.show<EventWorkflow>(
    context,
    (_) => const _NewEventWorkflowForm(),
  );
  if (created != null && context.mounted) {
    openEventWorkflow(context, created.id);
  }
}

class _NewWorkflowForm extends ConsumerStatefulWidget {
  const _NewWorkflowForm();

  @override
  ConsumerState<_NewWorkflowForm> createState() => _NewWorkflowFormState();
}

class _NewWorkflowFormState extends ConsumerState<_NewWorkflowForm> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  Stage _stage = Stage.prospect;
  bool _saving = false;
  PeopleFailure? _failure;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    // A second tap can land before the frame that disables Create.
    if (_saving || !_form.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _failure = null;
    });
    try {
      final created = await editWorkflows(
        ref,
        (workflows) => workflows.create(_stage, _name.text.trim()),
      );
      if (mounted) Navigator.pop(context, created);
    } on PeopleFailure catch (failure) {
      if (mounted) {
        setState(() {
          _saving = false;
          _failure = failure;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final material = MaterialLocalizations.of(context);
    final failure = _failure;

    return Form(
      key: _form,
      child: LoomiaDialog(
        title: l10n.workflowsNew,
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(material.cancelButtonLabel),
          ),
          FilledButton(
            onPressed: _saving ? null : _submit,
            child: _saving
                ? const SizedBox.square(
                    dimension: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(l10n.workflowsCreate),
          ),
        ],
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: AppSpacing.ms,
          children: [
            if (failure != null) FormError(peopleFailureCopy(l10n, failure)),
            LabeledField(
              label: l10n.workflowName,
              child: TextFormField(
                controller: _name,
                autofocus: true,
                textCapitalization: TextCapitalization.sentences,
                validator: (value) => (value ?? '').trim().isEmpty
                    ? l10n.workflowNameRequired
                    : null,
              ),
            ),
            SectionHeader(title: l10n.workflowsNewStage),
            Wrap(
              spacing: AppSpacing.sm,
              children: [
                for (final stage in Stage.values)
                  ChoiceChip(
                    label: Text(stageLabel(l10n, stage)),
                    selected: _stage == stage,
                    onSelected: (_) => setState(() => _stage = stage),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _NewEventWorkflowForm extends ConsumerStatefulWidget {
  const _NewEventWorkflowForm();

  @override
  ConsumerState<_NewEventWorkflowForm> createState() =>
      _NewEventWorkflowFormState();
}

class _NewEventWorkflowFormState extends ConsumerState<_NewEventWorkflowForm> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  bool _saving = false;
  PeopleFailure? _failure;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_saving || !_form.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _failure = null;
    });
    try {
      final created = await editEventWorkflows(
        ref,
        (workflows) => workflows.create(_name.text.trim()),
      );
      if (mounted) Navigator.pop(context, created);
    } on PeopleFailure catch (failure) {
      if (mounted) {
        setState(() {
          _saving = false;
          _failure = failure;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final material = MaterialLocalizations.of(context);
    final failure = _failure;

    return Form(
      key: _form,
      child: LoomiaDialog(
        title: l10n.eventWorkflowNew,
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(material.cancelButtonLabel),
          ),
          FilledButton(
            onPressed: _saving ? null : _submit,
            child: _saving
                ? const SizedBox.square(
                    dimension: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(l10n.workflowsCreate),
          ),
        ],
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: AppSpacing.ms,
          children: [
            if (failure != null) FormError(peopleFailureCopy(l10n, failure)),
            LabeledField(
              label: l10n.workflowName,
              child: TextFormField(
                controller: _name,
                autofocus: true,
                textCapitalization: TextCapitalization.sentences,
                validator: (value) => (value ?? '').trim().isEmpty
                    ? l10n.workflowNameRequired
                    : null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:loomia/app/router/back.dart';
import 'package:loomia/app/router/routes.dart';
import 'package:loomia/app/theme/app_spacing.dart';
import 'package:loomia/core/ui/empty_state.dart';
import 'package:loomia/core/ui/labeled_field.dart';
import 'package:loomia/core/ui/loomia_dialog.dart';
import 'package:loomia/core/ui/section_header.dart';
import 'package:loomia/features/auth/data/auth_repository.dart';
import 'package:loomia/features/contacts/domain/people_failure.dart';
import 'package:loomia/features/contacts/domain/person.dart';
import 'package:loomia/features/contacts/presentation/people_copy.dart';
import 'package:loomia/features/settings/presentation/widgets/settings_group.dart';
import 'package:loomia/features/settings/presentation/widgets/settings_scroll.dart';
import 'package:loomia/features/workflows/domain/event_workflow.dart';
import 'package:loomia/features/workflows/domain/workflow.dart';
import 'package:loomia/features/workflows/presentation/event_step_copy.dart';
import 'package:loomia/features/workflows/presentation/event_step_sheet.dart';
import 'package:loomia/features/workflows/presentation/event_workflows_controller.dart';
import 'package:loomia/features/workflows/presentation/workflows_controller.dart';
import 'package:loomia/features/workflows/presentation/workflows_settings.dart';
import 'package:loomia/l10n/app_localizations.dart';
import 'package:material_ui/material_ui.dart';

/// One event workflow, found in the loaded list (there is no second fetch),
/// wired to saving.
class EventWorkflowEditor extends ConsumerWidget {
  const EventWorkflowEditor({required this.id, super.key});

  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final owner = ref.watch(accountProvider)?.email;
    final eventWorkflows = eventWorkflowsProvider(owner);
    final state = ref.watch(eventWorkflows);
    final list = state.value;
    final workflow = list == null ? null : findEventWorkflow(list, id);

    final workflowsState = ref.watch(workflowsProvider(owner));
    final workflows = workflowsState.value;

    if (workflow == null) {
      if (state.isLoading) {
        return const Center(child: CircularProgressIndicator());
      }
      if (list == null) {
        return WorkflowsLoadError(
          onRetry: () => ref.invalidate(eventWorkflows),
        );
      }
      return Center(
        child: EmptyState(
          icon: Icons.event_rounded,
          title: l10n.workflowMissingTitle,
          body: l10n.workflowMissingBody,
          actionLabel: l10n.workflowBackToList,
          onAction: () => context.go(Routes.settingsWorkflows),
        ),
      );
    }

    // Wait for person workflows to load: the dropdowns need them
    if (workflows == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return SettingsScroll(
      eyebrow: l10n.workflowsEvents,
      title: workflow.name,
      child: EventWorkflowEditorView(
        workflow: workflow,
        workflows: workflows,
        onSave:
            ({required String name, required Map<Stage, String> followUps}) =>
                editEventWorkflows(
                  ref,
                  (repository) => repository.save(
                    workflow.id,
                    name: name,
                    followUps: followUps,
                  ),
                ),
        onAddStep: () => unawaited(showEventStepSheet(context, workflow)),
        onOpenStep: (step) =>
            unawaited(showEventStepSheet(context, workflow, step: step)),
        onDelete: () => _delete(context, ref, owner, workflow),
      ),
    );
  }

  static Future<void> _delete(
    BuildContext context,
    WidgetRef ref,
    String? owner,
    EventWorkflow workflow,
  ) async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await confirmDestructive(
      context,
      title: l10n.workflowDeleteTitle(workflow.name),
      action: l10n.workflowDeleteConfirm,
      body: l10n.eventWorkflowDeleteBody,
    );
    if (!confirmed || !context.mounted) return;
    await editEventWorkflows(
      ref,
      (repository) => repository.delete(workflow.id),
    );
    if (context.mounted) backOr(context, Routes.settingsWorkflows);
  }
}

enum _Control { name, followUps, delete }

/// The editor, fed the saved workflow and callbacks per write; each write
/// callback throws `PeopleFailure`.
class EventWorkflowEditorView extends StatefulWidget {
  const EventWorkflowEditorView({
    required this.workflow,
    required this.workflows,
    required this.onSave,
    required this.onAddStep,
    required this.onOpenStep,
    required this.onDelete,
    super.key,
  });

  final EventWorkflow workflow;
  final List<Workflow> workflows;
  final Future<void> Function({
    required String name,
    required Map<Stage, String> followUps,
  })
  onSave;
  final VoidCallback onAddStep;
  final ValueChanged<EventWorkflowStep> onOpenStep;
  final Future<void> Function() onDelete;

  @override
  State<EventWorkflowEditorView> createState() =>
      _EventWorkflowEditorViewState();
}

class _EventWorkflowEditorViewState extends State<EventWorkflowEditorView> {
  late final _name = TextEditingController(text: widget.workflow.name);
  final _nameFocus = FocusNode();
  final Set<_Control> _busy = {};
  String? _written;

  @override
  void initState() {
    super.initState();
    _nameFocus.addListener(() {
      if (!_nameFocus.hasFocus) unawaited(_saveName());
    });
  }

  @override
  void didUpdateWidget(EventWorkflowEditorView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_nameFocus.hasFocus && widget.workflow.name != _name.text) {
      _name.text = widget.workflow.name;
    }
    if (widget.workflow.name != oldWidget.workflow.name) {
      _written = null;
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _nameFocus.dispose();
    super.dispose();
  }

  Future<bool> _run(_Control control, Future<void> Function() write) async {
    if (_busy.contains(control)) return false;
    final messenger = ScaffoldMessenger.of(context);
    final l10n = AppLocalizations.of(context);
    setState(() => _busy.add(control));
    try {
      await write();
      return true;
    } on PeopleFailure catch (failure) {
      messenger.showSnackBar(
        SnackBar(content: Text(peopleFailureCopy(l10n, failure))),
      );
      return false;
    } finally {
      if (mounted) setState(() => _busy.remove(control));
    }
  }

  Future<void> _saveName() async {
    final saved = widget.workflow.name;
    final name = _name.text.trim();
    if (name.isEmpty || name == saved || name == _written) {
      _name.text = saved;
      return;
    }
    _name.text = name;
    _written = name;
    final ok = await _run(
      _Control.name,
      () => widget.onSave(name: name, followUps: widget.workflow.followUps),
    );
    if (!ok) {
      _written = null;
      if (mounted) _name.text = widget.workflow.name;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final workflow = widget.workflow;
    final steps = workflow.steps;
    final error = theme.colorScheme.error;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LabeledField(
          label: l10n.workflowName,
          child: TextField(
            controller: _name,
            focusNode: _nameFocus,
            readOnly: _busy.contains(_Control.name),
            textCapitalization: TextCapitalization.sentences,
            textInputAction: TextInputAction.done,
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        SectionHeader(
          title: l10n.workflowSteps,
          actionLabel: l10n.workflowAddStep,
          onAction: widget.onAddStep,
        ),
        SettingsGroup(
          children: [
            if (steps.isEmpty)
              ListTile(title: Text(l10n.workflowNoSteps))
            else
              for (final step in steps)
                ListTile(
                  title: Text(step.label),
                  subtitle: Text(stepTiming(l10n, step.days)),
                  onTap: () => widget.onOpenStep(step),
                ),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),
        SectionHeader(title: l10n.eventWorkflowAfter),
        SettingsGroup(
          children: [
            for (final stage in Stage.values) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.md,
                  AppSpacing.md,
                  AppSpacing.md,
                  AppSpacing.xs,
                ),
                child: Text(
                  l10n.eventWorkflowStage(stage.name),
                  style: theme.textTheme.bodyMedium,
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.md,
                  0,
                  AppSpacing.md,
                  AppSpacing.md,
                ),
                child: DropdownButtonFormField<String?>(
                  isExpanded: true,
                  decoration: const InputDecoration(
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: AppSpacing.md,
                      vertical: AppSpacing.sm,
                    ),
                  ),
                  value: () {
                    final id = workflow.followUps[stage];
                    final available = forStage(widget.workflows, stage);
                    return id != null && available.any((w) => w.id == id)
                        ? id
                        : null;
                  }(),
                  items: [
                    DropdownMenuItem<String?>(
                      value: null,
                      child: Text(l10n.eventWorkflowKeep),
                    ),
                    for (final w in forStage(widget.workflows, stage))
                      DropdownMenuItem<String?>(
                        value: w.id,
                        child: Text(w.name),
                      ),
                  ],
                  onChanged: _busy.contains(_Control.followUps)
                      ? null
                      : (id) {
                          final followUps = {...workflow.followUps};
                          if (id == null) {
                            followUps.remove(stage);
                          } else {
                            followUps[stage] = id;
                          }
                          unawaited(
                            _run(
                              _Control.followUps,
                              () => widget.onSave(
                                name: workflow.name,
                                followUps: followUps,
                              ),
                            ),
                          );
                        },
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          l10n.eventWorkflowAfterHint,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        Text(
          l10n.eventWorkflowFooter,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        SettingsGroup(
          children: [
            ListTile(
              leading: const Icon(Icons.delete_outline_rounded),
              title: Text(l10n.workflowDelete),
              textColor: error,
              iconColor: error,
              onTap: _busy.contains(_Control.delete)
                  ? null
                  : () => unawaited(_run(_Control.delete, widget.onDelete)),
            ),
          ],
        ),
      ],
    );
  }
}

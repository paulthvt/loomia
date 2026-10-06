import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:loomia/app/router/routes.dart';
import 'package:loomia/app/theme/app_colors.dart';
import 'package:loomia/app/theme/app_spacing.dart';
import 'package:loomia/core/ui/action_item.dart';
import 'package:loomia/core/ui/pick_day.dart';
import 'package:loomia/core/ui/section_header.dart';
import 'package:loomia/features/auth/data/auth_repository.dart';
import 'package:loomia/features/contacts/domain/person.dart';
import 'package:loomia/features/contacts/presentation/change_stage_sheet.dart';
import 'package:loomia/features/contacts/presentation/change_workflow_sheet.dart';
import 'package:loomia/features/contacts/presentation/contacts_page.dart';
import 'package:loomia/features/contacts/presentation/people_controller.dart';
import 'package:loomia/features/contacts/presentation/people_copy.dart';
import 'package:loomia/features/workflows/domain/progress.dart';
import 'package:loomia/features/workflows/domain/workflow.dart';
import 'package:loomia/features/workflows/presentation/workflows_controller.dart';
import 'package:loomia/l10n/app_localizations.dart';
import 'package:material_ui/material_ui.dart';

/// `NEXT STEP` on a contact: what to do next in their workflow, or what comes
/// after it. Reads the workflows and saves through the book.
class NextStepSection extends ConsumerStatefulWidget {
  const NextStepSection({required this.person, super.key});

  final Person person;

  @override
  ConsumerState<NextStepSection> createState() => _NextStepSectionState();
}

class _NextStepSectionState extends ConsumerState<NextStepSection> {
  /// A write is in flight: its buttons are gone or disabled, so a second tap
  /// can't tick the next step too.
  bool _busy = false;

  Future<void> _run(
    Future<void> Function(PeopleController people) write,
  ) async {
    if (_busy) return;
    setState(() => _busy = true);
    await writePeople(context, ref, write);
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final person = widget.person;
    final provider = workflowsProvider(ref.watch(accountProvider)?.email);
    final workflows = ref.watch(provider);
    final list = workflows.value;
    // Paused needs no workflow; everything else waits for them.
    if (list == null && person.pausedAt == null) {
      return _Waiting(
        failed: workflows.hasError,
        onRetry: () => ref.invalidate(provider),
      );
    }

    final workflow = findWorkflow(list ?? const [], person.place?.workflowId);
    return NextStepCard(
      person: person,
      progress: progressOf(person, workflow),
      onOpen: workflow == null
          ? null
          : () => unawaited(
              context.push(Routes.contactWorkflowLocation(person.id)),
            ),
      today: today(),
      busy: _busy,
      onTick: (step) => unawaited(
        _run((people) => people.completeStep(person, step, today())),
      ),
      onResume: () =>
          unawaited(_run((people) => people.resume(person, today()))),
      onNotNow: () => unawaited(_run((people) => people.pause(person))),
      onFollowWith: () => unawaited(showChangeWorkflow(context, [person])),
      onBecameCustomer: () =>
          unawaited(showChangeStage(context, [person], Stage.customer)),
    );
  }
}

/// The card while the workflows load, or once they failed to.
class _Waiting extends StatelessWidget {
  const _Waiting({required this.failed, required this.onRetry});

  final bool failed;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return _Panel(
      header: l10n.nextStepTitle,
      body: failed ? l10n.nextStepLoadFailed : null,
      actions: [
        if (failed)
          TextButton(onPressed: onRetry, child: Text(l10n.contactsRetry))
        else
          const SizedBox.square(
            dimension: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
      ],
    );
  }
}

/// The card itself, in each of its states. A pure view.
class NextStepCard extends StatelessWidget {
  const NextStepCard({
    required this.person,
    required this.progress,
    required this.today,
    required this.onTick,
    required this.onResume,
    required this.onNotNow,
    required this.onFollowWith,
    required this.onBecameCustomer,
    this.onOpen,
    this.busy = false,
    super.key,
  });

  final Person person;

  /// Null: no workflow.
  final WorkflowProgress? progress;
  final DateTime today;
  final ValueChanged<OnStep> onTick;
  final VoidCallback onResume;

  /// "Not now" on a finished prospect: pauses them.
  final VoidCallback onNotNow;
  final VoidCallback onFollowWith;
  final VoidCallback onBecameCustomer;

  /// Opens the whole workflow; null with none to show.
  final VoidCallback? onOpen;

  /// A write is in flight: no tick, buttons disabled.
  final bool busy;

  VoidCallback? _unlessBusy(VoidCallback action) => busy ? null : action;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final name = firstName(person);
    final followWith = OutlinedButton(
      onPressed: onFollowWith,
      child: Text(l10n.nextStepFollowWith),
    );

    return switch (progress) {
      final OnStep on => _step(l10n, on),
      Done(:final workflow) when person.stage == Stage.prospect => _Panel(
        onOpen: onOpen,
        header: l10n.nextStepDoneTitle(workflow.name),
        title: l10n.nextStepHowDidItEnd(name),
        body: l10n.nextStepAllDoneProspect(workflow.steps.length),
        actions: [
          FilledButton(
            onPressed: _unlessBusy(onBecameCustomer),
            child: Text(l10n.nextStepBecameCustomer),
          ),
          OutlinedButton(
            onPressed: _unlessBusy(onNotNow),
            child: Text(l10n.statusNotNow),
          ),
        ],
      ),
      Done(:final workflow) => _Panel(
        onOpen: onOpen,
        header: l10n.nextStepDoneTitle(workflow.name),
        body: l10n.nextStepAllDoneWith(workflow.steps.length, name),
        actions: [followWith],
      ),
      Paused(:final since) => _Panel(
        onOpen: onOpen,
        header: l10n.nextStepTitle,
        body: l10n.nextStepPausedSince(since.toLocal()),
        actions: [
          OutlinedButton(
            onPressed: _unlessBusy(onResume),
            child: Text(l10n.contactResume),
          ),
        ],
      ),
      null => _Panel(
        header: l10n.nextStepTitle,
        body: l10n.nextStepNothingPlanned,
        actions: [followWith],
      ),
    };
  }

  Widget _step(AppLocalizations l10n, OnStep on) {
    final due = dueLabel(l10n, on.due, today);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeader(
          title: l10n.nextStepTitle,
          actionLabel: l10n.nextStepProgress(
            on.workflow.name,
            on.index,
            on.total,
          ),
        ),
        ActionItem(
          name: person.name,
          title: on.step.label,
          reason: switch (on.step.note) {
            final note? => l10n.nextStepWithNote(due, note),
            null => due,
          },
          onOpen: onOpen,
          onResolve: busy ? null : () => onTick(on),
          resolveLabel: l10n.nextStepMarkDone(on.step.label),
        ),
      ],
    );
  }
}

/// A header, then a card with an optional title, a line, and its buttons.
class _Panel extends StatelessWidget {
  const _Panel({
    required this.header,
    required this.actions,
    this.title,
    this.body,
    this.onOpen,
  });

  final String header;
  final VoidCallback? onOpen;
  final String? title;
  final String? body;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final heading = title;
    final text = body;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeader(title: header),
        Card(
          margin: EdgeInsets.zero,
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onOpen,
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: AppSpacing.sm,
                children: [
                  if (heading != null)
                    Text(heading, style: theme.textTheme.titleMedium),
                  if (text != null)
                    Text(
                      text,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: LoomiaColors.of(context).textMuted,
                      ),
                    ),
                  Wrap(
                    spacing: AppSpacing.sm,
                    runSpacing: AppSpacing.sm,
                    children: actions,
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

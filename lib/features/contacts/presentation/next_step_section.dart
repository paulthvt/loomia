import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:loomia/app/router/routes.dart';
import 'package:loomia/app/theme/app_colors.dart';
import 'package:loomia/app/theme/app_spacing.dart';
import 'package:loomia/core/ui/action_item.dart';
import 'package:loomia/core/ui/pick_day.dart';
import 'package:loomia/core/ui/section_header.dart';
import 'package:loomia/core/ui/slide_swap.dart';
import 'package:loomia/features/auth/data/auth_repository.dart';
import 'package:loomia/features/contacts/domain/people_failure.dart';
import 'package:loomia/features/contacts/domain/person.dart';
import 'package:loomia/features/contacts/presentation/change_stage_sheet.dart';
import 'package:loomia/features/contacts/presentation/change_workflow_sheet.dart';
import 'package:loomia/features/contacts/presentation/contacts_page.dart';
import 'package:loomia/features/contacts/presentation/people_controller.dart';
import 'package:loomia/features/contacts/presentation/people_copy.dart';
import 'package:loomia/features/contacts/presentation/reminder_sheet.dart';
import 'package:loomia/features/workflows/domain/progress.dart';
import 'package:loomia/features/workflows/domain/workflow.dart';
import 'package:loomia/features/workflows/presentation/workflows_controller.dart';
import 'package:loomia/l10n/app_localizations.dart';
import 'package:material_ui/material_ui.dart';

/// `NEXT STEP` on a contact: their reminders (#217), then what to do next in
/// their workflow, or what comes after it. Reads the workflows and saves
/// through the book.
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

  /// Reminders whose tick is in flight.
  final Set<String> _busyReminders = {};

  Future<void> _tickReminder(Reminder reminder) async {
    if (!_busyReminders.add(reminder.id)) return;
    setState(() {});
    await writePeople(
      context,
      ref,
      (people) => people.completeReminder(widget.person, reminder, today()),
    );
    if (mounted) setState(() => _busyReminders.remove(reminder.id));
  }

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
    final waiting = list == null && person.pausedAt == null;
    final workflow = findWorkflow(list ?? const [], person.place?.workflowId);
    return NextStepCard(
      person: person,
      progress: waiting ? null : progressOf(person, workflow),
      waiting: waiting,
      onRetry: waiting && workflows.hasError
          ? () => ref.invalidate(provider)
          : null,
      offline: workflows.error == PeopleFailure.network,
      onOpen: workflow == null
          ? null
          // Relative to wherever the person is open: under Contacts or above
          // the import screen (see Routes.importedContactLocation).
          : () => unawaited(
              context.push(
                '${GoRouterState.of(context).matchedLocation}/'
                '${Routes.contactWorkflowSegment}',
              ),
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
      busyReminders: _busyReminders,
      onTickReminder: (reminder) => unawaited(_tickReminder(reminder)),
      onEditReminder: (reminder) =>
          unawaited(showReminder(context, person, editing: reminder)),
      onAddReminder: () => unawaited(showReminder(context, person)),
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
    this.waiting = false,
    this.onRetry,
    this.offline = false,
    this.busyReminders = const {},
    this.onTickReminder,
    this.onEditReminder,
    this.onAddReminder,
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

  /// The workflows are loading, or failed to when [onRetry] is set: the
  /// card says so, the reminders are there already.
  final bool waiting;
  final VoidCallback? onRetry;

  /// With [onRetry]: the workflows failed because the server is unreachable.
  final bool offline;

  /// Reminders whose tick is in flight.
  final Set<String> busyReminders;

  /// Null: not offered (previews).
  final ValueChanged<Reminder>? onTickReminder;
  final ValueChanged<Reminder>? onEditReminder;
  final VoidCallback? onAddReminder;

  VoidCallback? _unlessBusy(VoidCallback action) => busy ? null : action;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final name = firstName(person);
    final followWith = OutlinedButton(
      onPressed: onFollowWith,
      child: Text(l10n.nextStepFollowWith),
    );

    // The workflow's name and "2 of 4" go on the step's own row: the header
    // sits above reminders too.
    final header = switch (progress) {
      Done(:final workflow) when !waiting => l10n.nextStepDoneTitle(
        workflow.name,
      ),
      _ => l10n.nextStepTitle,
    };
    final retry = onRetry;
    final reminders = person.reminders;
    // Soonest first, the step among the reminders; on a tie, the step first.
    // Reminders are sorted, so those before the step are a prefix.
    final cut = switch (progress) {
      final OnStep on when !waiting => reminders.indexWhere(
        (reminder) => !reminder.dueOn.isBefore(on.due),
      ),
      _ => -1,
    };
    final before = cut == -1 ? reminders.length : cut;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeader(title: header),
        for (final reminder in reminders.take(before)) ...[
          _reminder(l10n, reminder),
          const SizedBox(height: AppSpacing.ms),
        ],
        // A new state (the last step ticked: Done) slides in whole; a new
        // step slides in just its card, in `_step`.
        SlideSwap(
          child: KeyedSubtree(
            key: ValueKey(waiting ? 'waiting' : progress.runtimeType),
            child: waiting
                ? _Panel(
                    body: retry == null
                        ? null
                        : offline
                        ? l10n.offlineInline
                        : l10n.nextStepLoadFailed,
                    actions: [
                      if (retry != null)
                        TextButton(
                          onPressed: retry,
                          child: Text(l10n.contactsRetry),
                        )
                      else
                        const SizedBox.square(
                          dimension: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                    ],
                  )
                : switch (progress) {
                    final OnStep on => _step(l10n, on),
                    Done(:final workflow) when person.stage == Stage.prospect =>
                      _Panel(
                        onOpen: onOpen,
                        title: l10n.nextStepHowDidItEnd(name),
                        body: l10n.nextStepAllDoneProspect(
                          workflow.steps.length,
                        ),
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
                      body: l10n.nextStepAllDoneWith(
                        workflow.steps.length,
                        name,
                      ),
                      actions: [followWith],
                    ),
                    Paused(:final since) => _Panel(
                      onOpen: onOpen,
                      body: l10n.nextStepPausedSince(since.toLocal()),
                      actions: [
                        OutlinedButton(
                          onPressed: _unlessBusy(onResume),
                          child: Text(l10n.contactResume),
                        ),
                      ],
                    ),
                    null => _Panel(
                      // With reminders above, "nothing planned" would be
                      // wrong: only the workflow is missing.
                      body: person.reminders.isEmpty
                          ? l10n.nextStepNothingPlanned
                          : l10n.nextStepNoWorkflow,
                      actions: [followWith],
                    ),
                  },
          ),
        ),
        for (final reminder in reminders.skip(before)) ...[
          const SizedBox(height: AppSpacing.ms),
          _reminder(l10n, reminder),
        ],
        if (onAddReminder case final add?)
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: Padding(
              padding: const EdgeInsets.only(top: AppSpacing.sm),
              child: TextButton.icon(
                onPressed: add,
                icon: const Icon(Icons.add_rounded),
                label: Text(l10n.reminderAdd),
              ),
            ),
          ),
      ],
    );
  }

  /// No date chip: the reason already says "2 days late", as on the step.
  Widget _reminder(AppLocalizations l10n, Reminder reminder) {
    final tick = onTickReminder;
    final edit = onEditReminder;
    return ActionItem(
      key: ValueKey(reminder.id),
      name: person.name,
      icon: Icons.schedule_rounded,
      title: reminder.text,
      reason: dueLabel(l10n, reminder.dueOn, today),
      onOpen: edit == null ? null : () => edit(reminder),
      onResolve: tick == null ? null : () => tick(reminder),
      resolved: busyReminders.contains(reminder.id),
      resolveLabel: l10n.nextStepMarkDone(reminder.text),
    );
  }

  Widget _step(AppLocalizations l10n, OnStep on) {
    final due = dueLabel(l10n, on.due, today);
    final when = switch (on.step.note) {
      final note? => l10n.nextStepWithNote(due, note),
      null => due,
    };
    return SlideSwap(
      child: ActionItem(
        key: ValueKey(on.step.id),
        name: person.name,
        icon: Icons.route_rounded,
        title: on.step.label,
        reason: when,
        detail: l10n.nextStepProgress(on.workflow.name, on.index, on.total),
        onOpen: onOpen,
        onResolve: () => onTick(on),
        resolved: busy,
        resolveLabel: l10n.nextStepMarkDone(on.step.label),
      ),
    );
  }
}

/// A card with an optional title, a line, and its buttons.
class _Panel extends StatelessWidget {
  const _Panel({required this.actions, this.title, this.body, this.onOpen});

  final VoidCallback? onOpen;
  final String? title;
  final String? body;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final heading = title;
    final text = body;

    return Card(
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
    );
  }
}

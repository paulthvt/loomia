import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:loomia/app/router/routes.dart';
import 'package:loomia/app/theme/app_colors.dart';
import 'package:loomia/app/theme/app_spacing.dart';
import 'package:loomia/app/theme/app_theme.dart';
import 'package:loomia/core/ui/action_item.dart';
import 'package:loomia/core/ui/animated_rows.dart';
import 'package:loomia/core/ui/pick_day.dart';
import 'package:loomia/core/ui/section_header.dart';
import 'package:loomia/core/ui/slide_swap.dart';
import 'package:loomia/features/auth/data/auth_repository.dart';
import 'package:loomia/features/calendar/domain/calendar_event.dart';
import 'package:loomia/features/calendar/domain/missed.dart';
import 'package:loomia/features/calendar/presentation/calendar_controller.dart';
import 'package:loomia/features/calendar/presentation/calendar_page.dart';
import 'package:loomia/features/calendar/presentation/event_row.dart';
import 'package:loomia/features/calendar/presentation/plan_sheet.dart';
import 'package:loomia/features/contacts/domain/people_failure.dart';
import 'package:loomia/features/contacts/domain/person.dart';
import 'package:loomia/features/contacts/presentation/change_stage_sheet.dart';
import 'package:loomia/features/contacts/presentation/change_workflow_sheet.dart';
import 'package:loomia/features/contacts/presentation/contacts_page.dart';
import 'package:loomia/features/contacts/presentation/people_controller.dart';
import 'package:loomia/features/contacts/presentation/people_copy.dart';
import 'package:loomia/features/contacts/presentation/reminder_sheet.dart';
import 'package:loomia/features/contacts/presentation/undo_tick.dart';
import 'package:loomia/features/contacts/presentation/whats_next_sheet.dart';
import 'package:loomia/features/workflows/domain/event_workflow.dart';
import 'package:loomia/features/workflows/domain/progress.dart';
import 'package:loomia/features/workflows/domain/workflow.dart';
import 'package:loomia/features/workflows/presentation/event_workflows_controller.dart';
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
    await tickReminder(context, ref, widget.person, reminder);
    if (mounted) setState(() => _busyReminders.remove(reminder.id));
  }

  Future<void> _tickStep(OnStep step) async {
    if (_busy) return;
    setState(() => _busy = true);
    await tickStep(context, ref, widget.person, step);
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _run(
    Future<void> Function(PeopleController people) write,
  ) async {
    if (_busy) return;
    setState(() => _busy = true);
    await writePeople(context, ref, write);
    if (mounted) setState(() => _busy = false);
  }

  /// Plan on an event step: the event, then the book reloads.
  Future<void> _plan(EventWorkflow type) async {
    if (_busy) return;
    setState(() => _busy = true);
    await planEvent(context, widget.person, type);
    if (mounted) setState(() => _busy = false);
  }

  /// Later on an event step: a day from tomorrow, three days out to start.
  Future<void> _later(OnStep step) async {
    final day = await pickLater(context);
    if (day == null || !mounted) return;
    await _run((people) => people.postponeStep(widget.person, step, day));
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
    final owner = ref.watch(accountProvider)?.email;
    final events = ref.watch(eventsProvider(owner)).value ?? const [];
    final types = ref.watch(eventWorkflowsProvider(owner)).value;
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
      onTick: (step) => unawaited(_tickStep(step)),
      events: events,
      // Until the types load, Plan has nothing to plan.
      onPlan: types == null
          ? null
          : (step) {
              if (findEventWorkflow(types, step.step.eventWorkflowId)
                  case final type?) {
                unawaited(_plan(type));
              }
            },
      onLater: (step) => unawaited(_later(step)),
      onOpenEvent: (id) => openEvent(context, id),
      onWhatsNext: workflow == null || list == null
          ? null
          : () => unawaited(showWhatsNext(context, person, workflow, list)),
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
    this.events = const [],
    this.onPlan,
    this.onLater,
    this.onOpenEvent,
    this.onWhatsNext,
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

  /// The calendar, for a planned step's event and a missed one (#315).
  final List<CalendarEvent> events;

  /// Plan and Later on an event step; null disables them.
  final ValueChanged<OnStep>? onPlan;
  final ValueChanged<OnStep>? onLater;

  /// A planned step's row: opens its event.
  final ValueChanged<String>? onOpenEvent;

  /// Done and asked what comes next (`needsNext`, #316): opens the sheet.
  final VoidCallback? onWhatsNext;

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
        AnimatedRows(
          spacing: AppSpacing.ms,
          gap: RowGap.below,
          slideOut: true,
          children: [
            for (final reminder in reminders.take(before))
              _reminder(l10n, reminder),
          ],
        ),
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
                    final OnStep on => _step(context, l10n, on),
                    final Planned planned => _planned(context, l10n, planned),
                    Done(:final workflow) when person.needsNext => _Panel(
                      onOpen: onOpen,
                      title: l10n.nextWhatTitle(name),
                      body: l10n.nextWhatDone(workflow.name),
                      actions: [
                        FilledButton(
                          onPressed: switch (onWhatsNext) {
                            final open? => _unlessBusy(open),
                            null => null,
                          },
                          child: Text(l10n.nextWhatChoose),
                        ),
                      ],
                    ),
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
        AnimatedRows(
          spacing: AppSpacing.ms,
          gap: RowGap.above,
          slideOut: true,
          children: [
            for (final reminder in reminders.skip(before))
              _reminder(l10n, reminder),
          ],
        ),
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

  Widget _step(BuildContext context, AppLocalizations l10n, OnStep on) {
    final due = dueLabel(l10n, on.due, today);
    final missed = on.isEvent ? missedEvent(person, on.step, events) : null;
    final when = switch ((missed, on.step.note)) {
      (final event?, _) => l10n.nextStepMissed(
        event.title,
        event.startsAt.toLocal(),
      ),
      (null, final note?) => l10n.nextStepWithNote(due, note),
      (null, null) => due,
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
        actions: on.isEvent
            ? planButtons(
                context,
                onPlan: busy || onPlan == null ? null : () => onPlan!(on),
                onLater: busy || onLater == null ? null : () => onLater!(on),
              )
            : null,
      ),
    );
  }

  /// Waiting for its event: the event's title and when; opens it.
  Widget _planned(BuildContext context, AppLocalizations l10n, Planned on) {
    final event = events.where((e) => e.id == on.eventId).firstOrNull;
    final open = onOpenEvent;
    return SlideSwap(
      child: ActionItem(
        key: ValueKey('${on.step.id}:${on.eventId}'),
        name: person.name,
        icon: Icons.event_rounded,
        title: event?.title ?? on.step.label,
        reason: event == null
            ? l10n.nextStepPlanned
            : l10n.nextStepPlannedWhen(whenLabel(context, event)),
        detail: l10n.nextStepProgress(on.workflow.name, on.index, on.total),
        onOpen: open == null ? null : () => open(on.eventId),
      ),
    );
  }
}

/// Plan (tonal) and Later on an event step, here and on Today (#315). Null
/// callbacks disable them.
List<Widget> planButtons(
  BuildContext context, {
  required VoidCallback? onPlan,
  required VoidCallback? onLater,
}) {
  final l10n = AppLocalizations.of(context);
  return [
    FilledButton.tonal(
      style: AppTheme.tonal(context),
      onPressed: onPlan,
      child: Text(l10n.nextStepPlan),
    ),
    TextButton(onPressed: onLater, child: Text(l10n.nextStepLater)),
  ];
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

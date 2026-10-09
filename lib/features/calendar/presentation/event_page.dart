import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:loomia/app/router/back.dart';
import 'package:loomia/app/router/routes.dart';
import 'package:loomia/app/theme/app_colors.dart';
import 'package:loomia/app/theme/app_spacing.dart';
import 'package:loomia/app/theme/app_theme.dart';
import 'package:loomia/core/layout/breakpoints.dart';
import 'package:loomia/core/ui/contact_row.dart';
import 'package:loomia/core/ui/empty_state.dart';
import 'package:loomia/core/ui/loomia_dialog.dart';
import 'package:loomia/core/ui/open_external.dart';
import 'package:loomia/core/ui/pick_day.dart';
import 'package:loomia/core/ui/section_header.dart';
import 'package:loomia/features/auth/data/auth_repository.dart';
import 'package:loomia/features/calendar/domain/calendar_event.dart';
import 'package:loomia/features/calendar/presentation/calendar_controller.dart';
import 'package:loomia/features/calendar/presentation/event_form.dart';
import 'package:loomia/features/calendar/presentation/event_row.dart';
import 'package:loomia/features/calendar/presentation/people_picker.dart';
import 'package:loomia/features/calendar/presentation/who_was_there_sheet.dart';
import 'package:loomia/features/contacts/domain/people_failure.dart';
import 'package:loomia/features/contacts/domain/person.dart';
import 'package:loomia/features/contacts/domain/search_key.dart';
import 'package:loomia/features/contacts/presentation/contacts_page.dart';
import 'package:loomia/features/contacts/presentation/people_controller.dart';
import 'package:loomia/features/contacts/presentation/people_copy.dart';
import 'package:loomia/features/workflows/domain/event_workflow.dart';
import 'package:loomia/features/workflows/domain/workflow.dart';
import 'package:loomia/features/workflows/presentation/event_step_copy.dart';
import 'package:loomia/features/workflows/presentation/event_workflows_controller.dart';
import 'package:loomia/features/workflows/presentation/workflows_controller.dart';
import 'package:loomia/l10n/app_localizations.dart';
import 'package:material_ui/material_ui.dart';

/// An invited contact found in the book.
typedef EventPerson = ({Person person, bool came});

/// [event]'s attendees found in [book], by name. Someone deleted from the
/// contacts on another device is left out rather than shown nameless.
List<EventPerson> eventPeople(CalendarEvent event, List<Person> book) {
  final byId = {for (final person in book) person.id: person};
  return [
    for (final attendee in event.attendees)
      if (byId[attendee.personId] case final person?)
        (person: person, came: attendee.came),
  ]..sort(
    (a, b) => searchKey(a.person.name).compareTo(searchKey(b.person.name)),
  );
}

/// One event on mobile and tablet: a screen of its own above the month.
class EventPage extends StatelessWidget {
  const EventPage({required this.id, super.key});

  final String id;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: BackButton(onPressed: () => backOr(context, Routes.calendar)),
      ),
      body: SafeArea(top: false, child: EventPane(id: id)),
    );
  }
}

/// An event found in the loaded calendar (there is no second fetch), wired
/// to editing, deleting and the other apps. Shared by [EventPage] and the
/// desktop pane.
class EventPane extends ConsumerWidget {
  const EventPane({required this.id, super.key});

  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final provider = eventsProvider(ref.watch(accountProvider)?.email);
    final events = ref.watch(provider);
    final list = events.value;
    if (list == null) {
      return events.hasError
          ? Center(
              child: EmptyState(
                icon: Icons.cloud_off_outlined,
                title: l10n.calendarLoadFailed,
                body: l10n.contactsLoadErrorBody,
                actionLabel: l10n.contactsRetry,
                onAction: () => ref.invalidate(provider),
              ),
            )
          : const Center(child: CircularProgressIndicator());
    }
    final event = list.where((event) => event.id == id).firstOrNull;
    if (event == null) {
      return Center(
        child: EmptyState(
          icon: Icons.event_busy_outlined,
          title: l10n.eventNotFound,
          body: l10n.eventNotFoundBody,
        ),
      );
    }
    final book = ref.watch(peopleProvider(ref.watch(accountProvider)?.email));
    final bookPeople = book.value;
    if (bookPeople == null) {
      return book.hasError
          ? Center(
              child: EmptyState(
                icon: Icons.cloud_off_outlined,
                title: l10n.contactsLoadError,
                body: l10n.contactsLoadErrorBody,
                actionLabel: l10n.contactsRetry,
                onAction: () => ref.invalidate(
                  peopleProvider(ref.watch(accountProvider)?.email),
                ),
              ),
            )
          : const Center(child: CircularProgressIndicator());
    }
    final people = eventPeople(event, bookPeople);
    final owner = ref.watch(accountProvider)?.email;
    final eventWorkflows =
        ref.watch(eventWorkflowsProvider(owner)).value ??
        const <EventWorkflow>[];
    final workflows =
        ref.watch(workflowsProvider(owner)).value ?? const <Workflow>[];
    final steps =
        findEventWorkflow(eventWorkflows, event.eventWorkflowId)?.steps ??
        const <EventWorkflowStep>[];
    final followUpNames = followUpNamesOf(event.followUps, workflows);
    return EventView(
      event: event,
      people: people,
      now: DateTime.now(),
      onAddPeople: () => unawaited(_invite(context, ref, event)),
      onRemove: (person) => unawaited(_uninvite(context, ref, event, person)),
      onOpenPerson: (person) => openContact(context, person.id),
      onMarkDone: () =>
          unawaited(showWhoWasThere(context, event: event, people: people)),
      onEdit: () => unawaited(_edit(context, ref, event)),
      onDelete: () => unawaited(_delete(context, ref, event)),
      onOpenPlace: (place) => unawaited(
        openExternal(
          context,
          mapsUri(
            place,
            apple: !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS,
          ),
        ),
      ),
      onJoin: (link) => unawaited(openExternal(context, link)),
      steps: steps,
      onTick: (step, done) => unawaited(_tick(context, ref, event, step, done)),
      followUpNames: followUpNames,
    );
  }

  Future<void> _invite(
    BuildContext context,
    WidgetRef ref,
    CalendarEvent event,
  ) async {
    final owner = ref.read(accountProvider)?.email;
    final messenger = ScaffoldMessenger.of(context);
    final l10n = AppLocalizations.of(context);
    final people = ref.read(peopleProvider(owner)).value ?? const [];
    final events = ref.read(eventsProvider(owner).notifier);
    final picked = await pickPeople(
      context,
      people: people,
      except: {for (final attendee in event.attendees) attendee.personId},
    );
    if (!context.mounted) return;
    if (picked == null || picked.isEmpty) return;
    try {
      await events.invite(event.id, picked);
    } on PeopleFailure catch (failure) {
      messenger.showSnackBar(
        SnackBar(content: Text(peopleFailureCopy(l10n, failure))),
      );
    }
  }

  Future<void> _uninvite(
    BuildContext context,
    WidgetRef ref,
    CalendarEvent event,
    Person person,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final l10n = AppLocalizations.of(context);
    final events = ref.read(
      eventsProvider(ref.read(accountProvider)?.email).notifier,
    );
    try {
      await events.uninvite(event.id, person.id);
    } on PeopleFailure catch (failure) {
      messenger.showSnackBar(
        SnackBar(content: Text(peopleFailureCopy(l10n, failure))),
      );
    }
  }

  Future<void> _tick(
    BuildContext context,
    WidgetRef ref,
    CalendarEvent event,
    EventWorkflowStep step,
    bool done,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final l10n = AppLocalizations.of(context);
    final events = ref.read(
      eventsProvider(ref.read(accountProvider)?.email).notifier,
    );
    try {
      if (done) {
        await events.tick(event.id, step.id, today());
      } else {
        await events.untick(event.id, step.id);
      }
    } on PeopleFailure catch (failure) {
      messenger.showSnackBar(
        SnackBar(content: Text(peopleFailureCopy(l10n, failure))),
      );
    }
  }

  Future<void> _edit(
    BuildContext context,
    WidgetRef ref,
    CalendarEvent event,
  ) async {
    final saved = await showEventForm(context, event: event);
    if (saved != null && context.mounted) {
      ref.read(calendarSelectionProvider.notifier).select(saved.day);
    }
  }

  /// Leaves the event first, so its screen never shows it missing.
  Future<void> _delete(
    BuildContext context,
    WidgetRef ref,
    CalendarEvent event,
  ) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final events = ref.read(
      eventsProvider(ref.read(accountProvider)?.email).notifier,
    );
    final confirmed = await confirmDestructive(
      context,
      title: l10n.eventDeleteTitle(event.title),
      body: l10n.eventDeleteBody,
      action: l10n.eventDeleteAction,
    );
    if (!confirmed || !context.mounted) return;
    if (context.screenSize.isDesktop) {
      context.go(Routes.calendar);
    } else {
      final leaving = ModalRoute.of(context);
      backOr(context, Routes.calendar);
      await leaving?.completed;
    }
    try {
      await events.remove(event.id);
    } on PeopleFailure catch (failure) {
      messenger.showSnackBar(
        SnackBar(content: Text(peopleFailureCopy(l10n, failure))),
      );
    }
  }
}

/// The event as a function of its inputs, for previews and tests.
class EventView extends StatelessWidget {
  const EventView({
    required this.event,
    required this.people,
    required this.now,
    required this.onAddPeople,
    required this.onRemove,
    required this.onOpenPerson,
    required this.onMarkDone,
    required this.onEdit,
    required this.onDelete,
    required this.onOpenPlace,
    required this.onJoin,
    required this.steps,
    required this.onTick,
    required this.followUpNames,
    super.key,
  });

  final CalendarEvent event;
  final List<EventPerson> people;
  final DateTime now;
  final VoidCallback onAddPeople;
  final void Function(Person) onRemove;
  final void Function(Person) onOpenPerson;
  final VoidCallback onMarkDone;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  /// Opens the maps app on the place.
  final void Function(String place) onOpenPlace;
  final void Function(Uri link) onJoin;
  final List<EventWorkflowStep> steps;
  final void Function(EventWorkflowStep step, bool done) onTick;
  final Map<Stage, String> followUpNames;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final place = event.place;
    final link = event.link;
    final notes = event.notes;

    return ListView(
      padding: EdgeInsets.all(
        context.screenSize.isDesktop ? AppSpacing.lg : AppSpacing.md,
      ),
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Text(event.title, style: theme.textTheme.headlineSmall),
            ),
            IconButton(
              onPressed: onEdit,
              tooltip: l10n.eventEdit,
              icon: const Icon(Icons.edit_outlined),
            ),
            IconButton(
              onPressed: onDelete,
              tooltip: l10n.eventDelete,
              icon: const Icon(Icons.delete_outline_rounded),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.ms),
        _Line(icon: Icons.schedule_rounded, text: whenLabel(context, event)),
        if (place != null)
          _Line(
            icon: Icons.place_outlined,
            text: place,
            onTap: () => onOpenPlace(place),
          ),
        if (link != null)
          _Line(
            icon: Icons.videocam_outlined,
            text: shownLink(link),
            singleLine: true,
            trailing: FilledButton.tonal(
              style: AppTheme.tonal(context),
              onPressed: () => onJoin(Uri.parse(link)),
              child: Text(l10n.eventJoin),
            ),
          ),
        if (notes != null)
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.md),
            child: Text(
              notes,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        if (steps.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.lg),
          SectionHeader(title: l10n.eventChecklist),
          for (final step in steps)
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(step.label),
              subtitle: Text(
                l10n.eventStepDue(
                  stepTiming(l10n, step.days),
                  stepDue(event, step),
                ),
              ),
              trailing: IconButton(
                onPressed: () =>
                    onTick(step, !event.stepsDone.containsKey(step.id)),
                isSelected: event.stepsDone.containsKey(step.id),
                tooltip: event.stepsDone.containsKey(step.id)
                    ? l10n.eventStepUntick(step.label)
                    : l10n.eventStepTick(step.label),
                style: AppTheme.resolveRing(context),
                icon: const Icon(Icons.check_rounded),
              ),
            ),
        ],
        if (event.done) ...[
          const SizedBox(height: AppSpacing.lg),
          _DoneBanner(
            text: l10n.eventDoneBanner(event.cameCount, event.attendees.length),
          ),
        ] else if (event.canMarkDone(now)) ...[
          const SizedBox(height: AppSpacing.lg),
          FilledButton(
            onPressed: onMarkDone,
            child: Text(l10n.eventMarkWhoWasThere),
          ),
        ],
        const SizedBox(height: AppSpacing.lg),
        SectionHeader(
          title: l10n.eventPeople,
          actionLabel: event.done ? null : l10n.peoplePickerTitle,
          onAction: event.done ? null : onAddPeople,
        ),
        if (people.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
            child: Text(
              l10n.eventNoPeople,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: LoomiaColors.of(context).textMuted,
              ),
            ),
          )
        else
          for (final (:person, :came) in people)
            ContactRow(
              name: person.name,
              photoPath: person.photoPath,
              subtitle: _status(l10n, person, came),
              onTap: () => onOpenPerson(person),
              trailing: event.done
                  ? null
                  : IconButton(
                      onPressed: () => onRemove(person),
                      tooltip: l10n.eventRemovePerson(person.name),
                      icon: const Icon(Icons.close_rounded),
                    ),
            ),
        if (!event.done && event.eventWorkflowId != null) ...[
          const SizedBox(height: AppSpacing.lg),
          SectionHeader(title: l10n.eventWorkflowAfter),
          for (final stage in Stage.values)
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(l10n.eventWorkflowStage(stage.name)),
              trailing: Text(switch (followUpNames[stage]) {
                final String name => l10n.eventFollowUpStarts(name),
                null => l10n.eventFollowUpKeeps,
              }),
            ),
        ],
      ],
    );
  }

  String _status(AppLocalizations l10n, Person person, bool came) {
    final stage = stageLabel(l10n, person.stage);
    if (!event.done) return l10n.eventPersonInvited(stage);
    return came
        ? l10n.eventPersonWasThere(stage)
        : l10n.eventPersonMissed(stage);
  }
}

/// An icon and a line. With [onTap], the line reads as a link.
class _Line extends StatelessWidget {
  const _Line({
    required this.icon,
    required this.text,
    this.onTap,
    this.trailing,
    this.singleLine = false,
  });

  final IconData icon;
  final String text;
  final VoidCallback? onTap;
  final Widget? trailing;
  final bool singleLine;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    final tap = onTap;
    final row = Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Row(
        spacing: AppSpacing.sm,
        children: [
          Icon(icon, color: muted),
          Expanded(
            child: Text(
              text,
              maxLines: singleLine ? 1 : null,
              overflow: singleLine ? TextOverflow.ellipsis : null,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: tap == null
                    ? muted
                    : LoomiaColors.of(context).primaryText,
              ),
            ),
          ),
          ?trailing,
        ],
      ),
    );
    return tap == null
        ? row
        : Semantics(
            link: true,
            child: InkWell(onTap: tap, child: row),
          );
  }
}

/// "Done · 4 of 5 were there": attendance is history from here.
class _DoneBanner extends StatelessWidget {
  const _DoneBanner({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.ms,
      ),
      decoration: BoxDecoration(
        color: scheme.secondaryContainer,
        borderRadius: BorderRadius.circular(AppRadii.lg),
      ),
      child: Row(
        spacing: AppSpacing.ms,
        children: [
          Icon(Icons.check_rounded, color: scheme.onSecondaryContainer),
          Expanded(
            child: Text(
              text,
              style: Theme.of(context).textTheme.labelLarge
                  ?.copyWith(color: scheme.onSecondaryContainer),
            ),
          ),
        ],
      ),
    );
  }
}

/// The name of each stage's workflow in [followUps]; a stage whose workflow
/// isn't in [workflows] (deleted) is left out, so it reads "keeps".
Map<Stage, String> followUpNamesOf(
  Map<Stage, String> followUps,
  List<Workflow> workflows,
) => {
  for (final MapEntry(key: stage, value: id) in followUps.entries)
    if (findWorkflow(workflows, id) case final workflow?) stage: workflow.name,
};

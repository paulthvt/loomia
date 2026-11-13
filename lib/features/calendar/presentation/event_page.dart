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
import 'package:loomia/core/ui/hero_panel.dart';
import 'package:loomia/core/ui/load_failed.dart';
import 'package:loomia/core/ui/loomia_dialog.dart';
import 'package:loomia/core/ui/open_external.dart';
import 'package:loomia/core/ui/pick_day.dart';
import 'package:loomia/core/ui/scope_dialog.dart';
import 'package:loomia/core/ui/section_header.dart';
import 'package:loomia/core/ui/tick_ring.dart';
import 'package:loomia/features/auth/data/auth_repository.dart';
import 'package:loomia/features/calendar/data/event_repository.dart';
import 'package:loomia/features/calendar/domain/calendar_event.dart';
import 'package:loomia/features/calendar/domain/event_report.dart';
import 'package:loomia/features/calendar/presentation/calendar_controller.dart';
import 'package:loomia/features/calendar/presentation/calendar_page.dart';
import 'package:loomia/features/calendar/presentation/event_form.dart';
import 'package:loomia/features/calendar/presentation/event_row.dart';
import 'package:loomia/features/calendar/presentation/people_picker.dart';
import 'package:loomia/features/calendar/presentation/report_editor.dart';
import 'package:loomia/features/calendar/presentation/report_view.dart';
import 'package:loomia/features/calendar/presentation/who_was_there_sheet.dart';
import 'package:loomia/features/contacts/domain/people_failure.dart';
import 'package:loomia/features/contacts/domain/person.dart';
import 'package:loomia/features/contacts/domain/search_key.dart';
import 'package:loomia/features/contacts/presentation/contacts_page.dart';
import 'package:loomia/features/contacts/presentation/people_controller.dart';
import 'package:loomia/features/contacts/presentation/people_copy.dart';
import 'package:loomia/features/workflows/domain/event_workflow.dart';
import 'package:loomia/features/workflows/presentation/event_step_copy.dart';
import 'package:loomia/features/workflows/presentation/event_workflows_controller.dart';
import 'package:loomia/l10n/app_localizations.dart';
import 'package:material_ui/material_ui.dart';

/// An invited contact found in the book.
typedef EventPerson = ({Person person, Attendee attendee});

/// [event]'s attendees found in [book], by name. Someone deleted from the
/// contacts on another device is left out rather than shown nameless.
List<EventPerson> eventPeople(CalendarEvent event, List<Person> book) {
  final byId = {for (final person in book) person.id: person};
  return [
    for (final attendee in event.attendees)
      if (byId[attendee.personId] case final person?)
        (person: person, attendee: attendee),
  ]..sort(
    (a, b) => searchKey(a.person.name).compareTo(searchKey(b.person.name)),
  );
}

/// The last done event of the type with the person, before the day, that
/// has a report: what was said on the previous call. Null when none.
final previousReportProvider = FutureProvider.autoDispose
    .family<
      CalendarEvent?,
      ({String eventWorkflowId, String personId, DateTime before})
    >(
      (ref, key) => ref
          .watch(eventRepositoryProvider)
          .previousReport(
            eventWorkflowId: key.eventWorkflowId,
            personId: key.personId,
            before: key.before,
          ),
      retry: (error, _) => null,
    );

/// One event on mobile and tablet: a screen of its own above the month.
class EventPage extends StatelessWidget {
  const EventPage({required this.id, super.key});

  final String id;

  @override
  Widget build(BuildContext context) {
    // The hero holds back and runs under the status bar.
    return Scaffold(
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
          ? LoadFailed(
              offline: events.error == PeopleFailure.network,
              title: l10n.calendarLoadFailed,
              onRetry: () => ref.invalidate(provider),
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
          ? LoadFailed(
              offline: book.error == PeopleFailure.network,
              title: l10n.contactsLoadError,
              onRetry: () => ref.invalidate(
                peopleProvider(ref.read(accountProvider)?.email),
              ),
            )
          : const Center(child: CircularProgressIndicator());
    }
    final people = eventPeople(event, bookPeople);
    final owner = ref.watch(accountProvider)?.email;
    final eventWorkflows =
        ref.watch(eventWorkflowsProvider(owner)).value ??
        const <EventWorkflow>[];
    final type = findEventWorkflow(eventWorkflows, event.eventWorkflowId);
    final steps = type?.steps ?? const <EventWorkflowStep>[];
    final report = reportFor(event, type);
    final attendee = event.attendees.singleOrNull;
    final previous = type == null || report.isEmpty || attendee == null
        ? null
        : ref
              .watch(
                previousReportProvider((
                  eventWorkflowId: type.id,
                  personId: attendee.personId,
                  before: event.startsAt,
                )),
              )
              .value;
    return EventView(
      report: report,
      previousReport: previous,
      event: event,
      people: people,
      now: DateTime.now(),
      onAddPeople: () => unawaited(_invite(context, ref, event)),
      onRemove: (person) => unawaited(_uninvite(context, ref, event, person)),
      onGoing: (person) => unawaited(
        _write(context, ref, (events) => events.setGoing(event.id, person.id)),
      ),
      onFollowedUp: (person) => unawaited(
        _write(
          context,
          ref,
          (events) => events.followedUp(event.id, person.id, today()),
        ),
      ),
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
    final following = await _following(context, event);
    if (following == null) return;
    try {
      await events.invite(event.id, picked, today(), following: following);
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
    final following = await _following(context, event);
    if (following == null) return;
    try {
      await events.uninvite(event.id, person.id, following: following);
    } on PeopleFailure catch (failure) {
      messenger.showSnackBar(
        SnackBar(content: Text(peopleFailureCopy(l10n, failure))),
      );
    }
  }

  /// On an occurrence, whether a change on its people reaches the following
  /// ones: false on a single event, null when cancelled.
  Future<bool?> _following(BuildContext context, CalendarEvent event) async {
    if (event.series == null) return false;
    final scope = await pickScope(context);
    if (scope == null || !context.mounted) return null;
    return scope == EventScope.following;
  }

  Future<void> _write(
    BuildContext context,
    WidgetRef ref,
    Future<void> Function(EventsController events) write,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final l10n = AppLocalizations.of(context);
    final events = ref.read(
      eventsProvider(ref.read(accountProvider)?.email).notifier,
    );
    try {
      await write(events);
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
    final bool following;
    if (event.series != null && !event.done) {
      final loaded = ref.read(eventsProvider(ref.read(accountProvider)?.email));
      final scope = await pickScope(
        context,
        delete: true,
        losesReport: {
          if (event.report != null) EventScope.one,
          if (reportsFrom(loaded.value ?? const [], event))
            EventScope.following,
        },
      );
      if (scope == null || !context.mounted) return;
      following = scope == EventScope.following;
    } else {
      final confirmed = await confirmDestructive(
        context,
        title: l10n.eventDeleteTitle(event.title),
        body: event.report == null
            ? l10n.eventDeleteBody
            : l10n.eventDeleteReportBody,
        action: l10n.eventDeleteAction,
      );
      if (!confirmed || !context.mounted) return;
      following = false;
    }
    if (context.screenSize.isDesktop) {
      context.go(Routes.calendar);
    } else {
      final leaving = ModalRoute.of(context);
      backOr(context, Routes.calendar);
      await leaving?.completed;
    }
    try {
      await (following ? events.endSeries(event.id) : events.remove(event.id));
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
    required this.onGoing,
    required this.onFollowedUp,
    required this.onOpenPerson,
    required this.onMarkDone,
    required this.onEdit,
    required this.onDelete,
    required this.onOpenPlace,
    required this.onJoin,
    required this.steps,
    required this.onTick,
    this.report = const [],
    this.previousReport,
    super.key,
  });

  final CalendarEvent event;
  final List<EventPerson> people;
  final DateTime now;
  final VoidCallback onAddPeople;
  final void Function(Person) onRemove;

  /// Someone invited said they are coming.
  final void Function(Person) onGoing;

  /// Someone invited was just followed up: the next follow-up counts from
  /// today.
  final void Function(Person) onFollowedUp;
  final void Function(Person) onOpenPerson;
  final VoidCallback onMarkDone;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  /// Opens the maps app on the place.
  final void Function(String place) onOpenPlace;
  final void Function(Uri link) onJoin;
  final List<EventWorkflowStep> steps;
  final void Function(EventWorkflowStep step, bool done) onTick;

  /// Its fields, from `reportFor`: none outside a one-person type with a
  /// report, and then the notes read as prep notes.
  final List<ReportEntry> report;

  /// The last call's report with the same person, from
  /// [previousReportProvider].
  final CalendarEvent? previousReport;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final place = event.place;
    final link = event.link;
    final notes = event.notes;

    final colors = LoomiaColors.of(context);
    final desktop = context.screenSize.isDesktop;
    final hero = DetailHero(
      band: desktop,
      onBack: desktop ? null : () => backOr(context, Routes.calendar),
      title: event.title,
      editTooltip: l10n.eventEdit,
      onEdit: onEdit,
      deleteTooltip: l10n.eventDelete,
      onDelete: onDelete,
      lines: [
        HeroLine(
          icon: const Icon(Icons.schedule_rounded),
          text: whenLabel(context, event),
        ),
        if (event.series case final series?)
          HeroLine(
            icon: const Icon(Icons.repeat_rounded),
            text: repeatLine(
              l10n,
              everyWeeks: series.everyWeeks,
              firstOn: series.firstOn,
              untilOn: series.untilOn,
            ),
          ),
        if (place != null)
          HeroLine(
            icon: const Icon(Icons.place_rounded),
            text: place,
            onTap: () => onOpenPlace(place),
          ),
        if (link != null)
          HeroLine(
            icon: const Icon(Icons.videocam_rounded),
            text: shownLink(link),
            singleLine: true,
            trailing: FilledButton(
              style: AppTheme.heroPill(context),
              onPressed: () => onJoin(Uri.parse(link)),
              child: Text(l10n.eventJoin),
            ),
          ),
      ],
    );

    return ListView(
      padding: desktop
          ? const EdgeInsets.all(AppSpacing.lg)
          : const EdgeInsets.only(bottom: AppSpacing.lg),
      children: [
        hero,
        const SizedBox(height: AppSpacing.md),
        // Each its own child of the list, which stays lazy: a report
        // scrolled away is let go (its editor keeps what was typed).
        for (final child in <Widget>[
          if (notes != null && report.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            SectionHeader(title: l10n.eventPrepNotes),
          ],
          if (notes != null)
            _Card(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Text(
                  notes,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: theme.colorScheme.onSurface,
                  ),
                ),
              ),
            ),
          if (previousReport case final previous?) ...[
            const SizedBox(height: AppSpacing.md),
            _PreviousReportRow(
              day: previous.day,
              onTap: () => unawaited(
                showReportSheet(
                  context,
                  title: l10n.eventPreviousReport,
                  report: previous.report ?? const [],
                  day: previous.day,
                  onOpenEvent: () => openEvent(context, previous.id),
                ),
              ),
            ),
          ],
          if (report.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.lg),
            ReportEditor(
              key: reportEditorKey(event, report),
              event: event,
              entries: report,
            ),
          ],
          if (steps.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.lg),
            SectionHeader(title: l10n.eventChecklist),
            _Card(
              child: Column(
                children: [
                  for (final (i, step) in steps.indexed) ...[
                    if (i > 0)
                      const Divider(
                        height: 1,
                        indent: AppSpacing.md,
                        endIndent: AppSpacing.md,
                      ),
                    ListTile(
                      title: Text(step.label),
                      subtitle: Text(
                        l10n.eventStepDue(
                          stepTiming(l10n, step.days),
                          stepDue(event, step),
                        ),
                      ),
                      trailing: TickRing(
                        onPressed: () =>
                            onTick(step, !event.stepsDone.containsKey(step.id)),
                        selected: event.stepsDone.containsKey(step.id),
                        tooltip: event.stepsDone.containsKey(step.id)
                            ? l10n.eventStepUntick(step.label)
                            : l10n.eventStepTick(step.label),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
          if (event.done) ...[
            const SizedBox(height: AppSpacing.lg),
            _DoneBanner(
              text: l10n.eventDoneBanner(
                event.cameCount,
                event.attendees.length,
              ),
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
            title: !event.done && event.goingCount < event.attendees.length
                ? l10n.eventPeopleGoing(
                    event.attendees.length,
                    event.goingCount,
                  )
                : l10n.eventPeople,
            actionLabel: event.done ? null : l10n.peoplePickerTitle,
            onAction: event.done ? null : onAddPeople,
          ),
          if (people.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
              child: Text(
                l10n.eventNoPeople,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colors.textMuted,
                ),
              ),
            )
          else
            _Card(
              child: Column(
                children: [
                  for (final (i, (:person, :attendee)) in people.indexed) ...[
                    if (i > 0)
                      const Divider(
                        height: 1,
                        indent: AppSpacing.md,
                        endIndent: AppSpacing.md,
                      ),
                    ContactRow(
                      name: person.name,
                      photoPath: person.photoPath,
                      subtitle: _status(l10n, person, attendee),
                      onTap: () => onOpenPerson(person),
                      trailing: event.done
                          ? null
                          : PopupMenuButton<VoidCallback>(
                              tooltip: l10n.eventPersonMore(person.name),
                              onSelected: (action) => action(),
                              itemBuilder: (context) => [
                                if (!attendee.going) ...[
                                  PopupMenuItem(
                                    value: () => onGoing(person),
                                    child: Text(l10n.eventGoing),
                                  ),
                                  PopupMenuItem(
                                    value: () => onFollowedUp(person),
                                    child: Text(l10n.eventFollowedUp),
                                  ),
                                ],
                                PopupMenuItem(
                                  value: () => onRemove(person),
                                  child: Text(l10n.eventRemoveFromEvent),
                                ),
                              ],
                            ),
                    ),
                  ],
                ],
              ),
            ),
        ])
          Padding(
            padding: EdgeInsets.symmetric(
              horizontal: desktop ? 0 : AppSpacing.md,
            ),
            child: child,
          ),
      ],
    );
  }

  String _status(AppLocalizations l10n, Person person, Attendee attendee) {
    final stage = stageLabel(l10n, person.stage);
    if (event.done) {
      return attendee.came
          ? l10n.eventPersonWasThere(stage)
          : l10n.eventPersonMissed(stage);
    }
    return switch (attendee) {
      Attendee(going: true) => l10n.eventPersonGoing(stage),
      Attendee(:final invitedOn?, :final followedUpOn?) =>
        l10n.eventPersonFollowedUp(stage, invitedOn, followedUpOn),
      Attendee(:final invitedOn?) => l10n.eventPersonInvitedOn(
        stage,
        invitedOn,
      ),
      _ => l10n.eventPersonInvited(stage),
    };
  }
}

/// "Previous report" and its day, opening it.
class _PreviousReportRow extends StatelessWidget {
  const _PreviousReportRow({required this.day, required this.onTap});

  final DateTime day;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = LoomiaColors.of(context);
    return _Card(
      child: ListTile(
        onTap: onTap,
        leading: Icon(Icons.history_rounded, color: colors.primaryText),
        title: Text(l10n.eventPreviousReport),
        subtitle: Text(l10n.reportDay(day)),
        trailing: const Icon(Icons.chevron_right_rounded),
      ),
    );
  }
}

/// One card below the hero: the card's shadow behind a Material that
/// paints its fill, so the rows' ink shows, as EventRow's.
class _Card extends StatelessWidget {
  const _Card({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final card = AppTheme.card(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: card.borderRadius,
        boxShadow: card.boxShadow,
      ),
      child: Material(
        color: card.color,
        shape: RoundedRectangleBorder(borderRadius: card.borderRadius!),
        clipBehavior: Clip.antiAlias,
        child: child,
      ),
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

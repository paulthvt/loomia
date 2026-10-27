import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:loomia/app/router/routes.dart';
import 'package:loomia/app/shell/app_shell.dart';
import 'package:loomia/app/theme/app_spacing.dart';
import 'package:loomia/app/theme/app_theme.dart';
import 'package:loomia/core/business_model/business_model.dart';
import 'package:loomia/core/layout/breakpoints.dart';
import 'package:loomia/core/layout/content_columns.dart';
import 'package:loomia/core/ui/action_item.dart';
import 'package:loomia/core/ui/empty_state.dart';
import 'package:loomia/core/ui/fade_swap.dart';
import 'package:loomia/core/ui/load_failed.dart';
import 'package:loomia/core/ui/loomia_chip.dart';
import 'package:loomia/core/ui/loomia_top_bar.dart';
import 'package:loomia/core/ui/open_external.dart';
import 'package:loomia/core/ui/pick_day.dart';
import 'package:loomia/core/ui/section_header.dart';
import 'package:loomia/core/ui/slide_swap.dart';
import 'package:loomia/features/auth/data/auth_repository.dart';
import 'package:loomia/features/calendar/domain/calendar_event.dart';
import 'package:loomia/features/calendar/presentation/calendar_controller.dart';
import 'package:loomia/features/calendar/presentation/calendar_page.dart';
import 'package:loomia/features/calendar/presentation/event_page.dart';
import 'package:loomia/features/calendar/presentation/plan_sheet.dart';
import 'package:loomia/features/calendar/presentation/who_was_there_sheet.dart';
import 'package:loomia/features/contacts/domain/people_failure.dart';
import 'package:loomia/features/contacts/domain/person.dart';
import 'package:loomia/features/contacts/presentation/contacts_page.dart';
import 'package:loomia/features/contacts/presentation/log_activity_sheet.dart';
import 'package:loomia/features/contacts/presentation/next_step_section.dart';
import 'package:loomia/features/contacts/presentation/people_controller.dart';
import 'package:loomia/features/contacts/presentation/people_copy.dart';
import 'package:loomia/features/contacts/presentation/undo_tick.dart';
import 'package:loomia/features/contacts/presentation/whats_next_sheet.dart';
import 'package:loomia/features/goals/domain/goal_rules.dart';
import 'package:loomia/features/goals/presentation/goal_line.dart';
import 'package:loomia/features/goals/presentation/goals_controller.dart';
import 'package:loomia/features/goals/presentation/ritual_card.dart';
import 'package:loomia/features/goals/presentation/volume_card.dart';
import 'package:loomia/features/notifications/data/push.dart';
import 'package:loomia/features/notifications/domain/notification_settings.dart';
import 'package:loomia/features/notifications/presentation/notification_settings_form.dart';
import 'package:loomia/features/notifications/presentation/notifications_controller.dart';
import 'package:loomia/features/notifications/presentation/nudge_card.dart';
import 'package:loomia/features/tasks/domain/task.dart';
import 'package:loomia/features/tasks/presentation/task_row.dart';
import 'package:loomia/features/tasks/presentation/task_sheet.dart';
import 'package:loomia/features/tasks/presentation/tasks_controller.dart';
import 'package:loomia/features/tasks/presentation/toggle_task.dart';
import 'package:loomia/features/team/domain/check_in.dart';
import 'package:loomia/features/team/presentation/check_in_items.dart';
import 'package:loomia/features/today/domain/due.dart';
import 'package:loomia/features/today/domain/today_events.dart';
import 'package:loomia/features/today/presentation/done_today.dart';
import 'package:loomia/features/today/presentation/today_event_items.dart';
import 'package:loomia/features/today/presentation/today_hero.dart';
import 'package:loomia/features/workflows/domain/event_workflow.dart';
import 'package:loomia/features/workflows/presentation/event_workflows_controller.dart';
import 'package:loomia/features/workflows/presentation/workflows_controller.dart';
import 'package:loomia/l10n/app_localizations.dart';
import 'package:material_ui/material_ui.dart';

/// The home. Everything else in the product is support (design principle #1).
class TodayPage extends ConsumerStatefulWidget {
  const TodayPage({this.openTask, super.key});

  /// A task id from a tapped push (#377): its sheet opens once the tasks
  /// have loaded, if it is still open.
  final String? openTask;

  @override
  ConsumerState<TodayPage> createState() => _TodayPageState();
}

class _TodayPageState extends ConsumerState<TodayPage> {
  /// Rows ([Due.key]) whose tick is in flight: their ring stays filled and
  /// takes no tap, so a second tap can't tick the next step too.
  final Set<String> _busy = {};

  /// The [TodayPage.openTask] already handled, so a rebuild doesn't open it
  /// twice.
  String? _opened;

  /// Opens [TodayPage.openTask]'s sheet when [tasks] holds it, then drops
  /// the parameter from the address.
  void _openFromPush(List<Task>? tasks) {
    final id = widget.openTask;
    // Cleared from the address: the same task's next push opens it again.
    if (id == null) _opened = null;
    if (id == null || id == _opened || tasks == null) return;
    _opened = id;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.go(Routes.today);
      final task = tasks.where((t) => t.id == id && !t.done).firstOrNull;
      if (task != null) {
        unawaited(showTask(context, day: today(), editing: task));
      }
    });
  }

  /// The time picked on the summary card; null shows the default, 19:00.
  TimeOfDay? _nudgeTime;

  late final AppLifecycleListener _lifecycle;

  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(onResume: _onResume);
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  /// Back in the app, maybe on another day: what is due is worked out again
  /// from the device's today, and a stale book reloads, quietly, as on
  /// Contacts.
  void _onResume() {
    setState(() {});
    final owner = ref.read(accountProvider)?.email;
    final people = peopleProvider(owner);
    if (!ref.read(people.notifier).isStaleAt(DateTime.now())) return;
    ref.refresh(people.future).ignore();
    // With the book: a tick from another device takes its row off and
    // counts it, never one without the other.
    ref.invalidate(doneTodayProvider);
  }

  /// A task's ring: done today, with Undo. Not in the history, so not in
  /// [doneTodayProvider]: the hero counts it from the task list.
  Future<void> _tickTask(Task task) async {
    final key = task.key;
    if (!_busy.add(key)) return;
    setState(() {});
    try {
      await toggleTask(context, ref, task);
    } finally {
      if (mounted) setState(() => _busy.remove(key));
    }
  }

  Future<void> _tick(Due due) async {
    final key = due.key;
    if (!_busy.add(key)) return;
    setState(() {});
    final done = ref.read(
      doneTodayProvider((owner: ref.read(accountProvider)?.email, day: today()))
          .notifier,
    );
    final l10n = AppLocalizations.of(context);
    final owner = ref.read(accountProvider)?.email;
    final model =
        ref.read(accountProvider)?.businessModel ?? BusinessModel.other;
    final day = today();
    Person? after;
    try {
      final ticked = await writePeople(context, ref, (people) async {
        switch (due) {
          case DueStep(:final person, :final step):
            after = await people.completeStep(person, step, day);
          case DueReminder(:final person, :final reminder):
            await people.completeReminder(person, reminder, day);
          // Its row has buttons instead of the ring: see _invite.
          case DueFollowUp():
            throw StateError('a follow-up has no ring');
          case DueNext():
            throw StateError('what comes next has no ring');
          case DueLoyalty(:final person, :final renewal):
            after = await people.checkLoyalty(
              person,
              renewal,
              day,
              loyaltyRenewsText(l10n, model, person, renewal),
            );
        }
      });
      // The book dropped the row in this same microtask: the bar moves in
      // the frame the row starts to leave.
      if (!ticked || !mounted) return;
      done.add();
      final (message, undo) = switch (due) {
        DueStep(:final person, :final step) => (
          l10n.tickDoneFor(person.name, step.step.label),
          (PeopleController people) =>
              people.undoStep(person, after!, step, day),
        ),
        DueReminder(:final person, :final reminder) => (
          l10n.tickDoneFor(person.name, reminder.text),
          (PeopleController people) =>
              people.undoReminder(person, reminder, day),
        ),
        DueLoyalty(:final person, :final renewal) => (
          l10n.tickDoneLoyalty(person.name),
          (PeopleController people) =>
              people.undoLoyaltyCheck(person, after!, renewal),
        ),
        DueFollowUp() || DueNext() => throw StateError('not a tick'),
      };
      offerUndo(context, message, (container) async {
        await undo(container.read(peopleProvider(owner).notifier));
        container.invalidate(doneTodayProvider);
      });
    } finally {
      if (mounted) setState(() => _busy.remove(key));
    }
  }

  /// Going, Followed up or Remove on a follow-up row: the row leaves once
  /// the events reload; a failure keeps it and says so.
  Future<void> _invite(
    DueFollowUp due,
    Future<void> Function(EventsController events) write,
  ) async {
    final key = due.key;
    if (!_busy.add(key)) return;
    setState(() {});
    final events = ref.read(
      eventsProvider(ref.read(accountProvider)?.email).notifier,
    );
    final messenger = ScaffoldMessenger.of(context);
    final l10n = AppLocalizations.of(context);
    try {
      await write(events);
    } on PeopleFailure catch (failure) {
      messenger.showSnackBar(
        SnackBar(content: Text(peopleFailureCopy(l10n, failure))),
      );
    } finally {
      if (mounted) setState(() => _busy.remove(key));
    }
  }

  /// Plan on an event step: the event, then the book reloads and the row
  /// leaves.
  Future<void> _planStep(DueStep due, EventWorkflow type) async {
    final key = due.key;
    if (!_busy.add(key)) return;
    setState(() {});
    try {
      await planEvent(context, due.person, type);
    } finally {
      if (mounted) setState(() => _busy.remove(key));
    }
  }

  /// Later on an event step: due on the day picked.
  Future<void> _later(DueStep due) async {
    final day = await pickLater(context);
    if (day == null || !mounted) return;
    final key = due.key;
    if (!_busy.add(key)) return;
    setState(() {});
    try {
      await writePeople(
        context,
        ref,
        (people) => people.postponeStep(due.person, due.step, day),
      );
    } finally {
      if (mounted) setState(() => _busy.remove(key));
    }
  }

  Future<void> _tickStep(DueEventStep due) async {
    final key = stepKey(due);
    if (!_busy.add(key)) return;
    setState(() {});
    final events = ref.read(
      eventsProvider(ref.read(accountProvider)?.email).notifier,
    );
    final messenger = ScaffoldMessenger.of(context);
    final l10n = AppLocalizations.of(context);
    try {
      await events.tick(due.event.id, due.step.id, today());
    } on PeopleFailure catch (failure) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(content: Text(peopleFailureCopy(l10n, failure))),
        );
      return;
    } finally {
      if (mounted) setState(() => _busy.remove(key));
    }
    if (!mounted) return;
    final owner = ref.read(accountProvider)?.email;
    // No history entry, not in the done count: the untick is all there is.
    offerUndo(
      context,
      l10n.tickDone(due.step.label),
      (container) => container
          .read(eventsProvider(owner).notifier)
          .untick(due.event.id, due.step.id),
    );
  }

  /// The people, and this month's goals with them: a failed goals load has
  /// no Try again of its own on Today.
  Future<void> _refresh() {
    final owner = ref.read(accountProvider)?.email;
    ref.invalidate(goalsProvider(owner));
    ref.invalidate(eventsProvider(owner));
    ref.invalidate(tasksProvider(owner));
    ref.invalidate(doneTodayProvider);
    return refreshPeople(context, ref);
  }

  @override
  Widget build(BuildContext context) {
    final account = ref.watch(accountProvider);
    final owner = account?.email;
    final book = peopleProvider(owner);
    final lists = workflowsProvider(owner);
    final people = ref.watch(book);
    final workflows = ref.watch(lists);
    final tasks = ref.watch(tasksProvider(owner));
    _openFromPush(tasks.value);

    final calendarEvents = ref.watch(eventsProvider(owner));
    final eventWorkflows = ref.watch(eventWorkflowsProvider(owner));

    final now = DateTime.now();
    final day = today();
    final events = switch ((calendarEvents.value, eventWorkflows.value)) {
      (final list?, final flows) => todayEvents(list, flows ?? const [], now),
      _ => noTodayEvents,
    };

    return TodayView(
      // `.value` survives a failed refresh, so the rows stay on screen.
      due: switch ((people.value, workflows.value)) {
        (final everyone?, final all?) => AsyncData(
          // A failed events load hides follow-ups, not the list.
          dueToday(
            everyone,
            all,
            today(),
            events: calendarEvents.value ?? const [],
          ),
        ),
        _ when people.hasError => AsyncError(
          people.error!,
          people.stackTrace ?? StackTrace.empty,
        ),
        _ when workflows.hasError => AsyncError(
          workflows.error!,
          workflows.stackTrace ?? StackTrace.empty,
        ),
        _ => const AsyncLoading(),
      },
      // `.value` survives a failed refresh here too.
      tasks: switch (tasks.value) {
        final list? => AsyncData(list),
        _ => tasks,
      },
      now: now,
      // Steps and reminders from the history, tasks from their list.
      done: switch (ref
          .watch(doneTodayProvider((owner: owner, day: day)))
          .value) {
        final ticked? =>
          ticked +
              (tasks.value ?? const <Task>[])
                  .where((task) => task.doneOn == day)
                  .length,
        null => null,
      },
      firstName: account?.firstName ?? '',
      // With a sidebar, Settings is its account block instead.
      accountAction: context.screenSize.usesSideNavigation
          ? IconButton(
              onPressed: _refresh,
              tooltip: AppLocalizations.of(context).contactsRefresh,
              icon: const Icon(Icons.refresh_rounded),
            )
          : const AccountButton(),
      busy: _busy,
      onTick: (due) => unawaited(_tick(due)),
      onGoing: (due) => unawaited(
        _invite(due, (events) => events.setGoing(due.event.id, due.person.id)),
      ),
      onFollowedUp: (due) => unawaited(
        _invite(
          due,
          (events) => events.followedUp(due.event.id, due.person.id, today()),
        ),
      ),
      onPlan: switch (eventWorkflows.value) {
        // Until the types load, there is nothing to plan.
        null => null,
        final types => (due) {
          if (findEventWorkflow(types, due.step.step.eventWorkflowId)
              case final type?) {
            unawaited(_planStep(due, type));
          }
        },
      },
      onLater: (due) => unawaited(_later(due)),
      onNext: (due) => unawaited(
        showWhatsNext(
          context,
          due.person,
          due.workflow,
          workflows.value ?? const [],
        ),
      ),
      onRemoveInvite: (due) => unawaited(
        _invite(due, (events) => events.uninvite(due.event.id, due.person.id)),
      ),
      onOpen: (person) => openContact(context, person.id),
      onTickTask: (task) => unawaited(_tickTask(task)),
      onOpenTask: (task) =>
          unawaited(showTask(context, day: today(), editing: task)),
      onAddTask: () => unawaited(showTask(context, day: today())),
      onRetry: () {
        if (people.hasError) ref.invalidate(book);
        if (workflows.hasError) ref.invalidate(lists);
        if (tasks.hasError) ref.invalidate(tasksProvider(owner));
      },
      onRefresh: _refresh,
      goals: ref.watch(goalsProvider(owner)).value,
      model: account?.businessModel ?? BusinessModel.other,
      onGoals: () => context.go(Routes.goals),
      onRitual: () => context.push(Routes.goalsClose),
      checkIns: checkIns([
        for (final person in people.value ?? const <Person>[])
          if (person.stage == Stage.team) person,
      ], today()),
      onCheckIn: (person) => unawaited(showLogActivity(context, person)),
      events: events,
      onOpenEvent: (event) => openEvent(context, event.id),
      onMarkDone: (event) {
        if (people.value == null) {
          openEvent(context, event.id);
        } else {
          unawaited(
            showWhoWasThere(
              context,
              event: event,
              people: eventPeople(event, people.value!),
            ),
          );
        }
      },
      onTickStep: (due) => unawaited(_tickStep(due)),
      onJoin: (link) => unawaited(openExternal(context, link)),
      nudge: _nudge(owner),
    );
  }

  /// Asked once, on a phone with push: no settings row yet. Either answer
  /// creates one, and the card goes.
  Widget? _nudge(String? owner) {
    if (owner == null || ref.watch(pushAvailableProvider).value != true) {
      return null;
    }
    final settings = ref.watch(notificationSettingsProvider(owner));
    if (settings case AsyncData(value: null)) {
      // ponytail: UTC when the zone can't be read; see the settings screen.
      final zone = ref.watch(deviceTimeZoneProvider).value ?? 'UTC';
      final time = _nudgeTime;
      final offer = time == null
          ? NotificationSettings(timeZone: zone)
          : NotificationSettings(
              timeZone: zone,
              hour: time.hour,
              minute: time.minute,
            );
      return NudgeCard(
        time: formatSummaryTime(context, offer),
        onPickTime: () => unawaited(_pickNudgeTime(offer)),
        onTurnOn: () => unawaited(_answerNudge(owner, offer, turnOn: true)),
        onNotNow: () => unawaited(_answerNudge(owner, offer, turnOn: false)),
      );
    }
    return null;
  }

  /// The card's time, from its picker; dismissed keeps the one shown.
  Future<void> _pickNudgeTime(NotificationSettings offer) async {
    final picked = await pickTime(
      context,
      initial: TimeOfDay(hour: offer.hour, minute: offer.minute),
    );
    if (picked != null && mounted) setState(() => _nudgeTime = picked);
  }

  /// Turn on asks the OS; a refusal saves it off, as Not now does.
  Future<void> _answerNudge(
    String owner,
    NotificationSettings offer, {
    required bool turnOn,
  }) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final controller = ref.read(notificationSettingsProvider(owner).notifier);
    final granted = turnOn && await ref.read(pushProvider).ask();
    try {
      await controller.save(offer.copyWith(enabled: granted));
    } on PeopleFailure catch (failure) {
      messenger.showSnackBar(
        SnackBar(content: Text(peopleFailureCopy(l10n, failure))),
      );
    }
  }
}

/// "Good morning, Pauline" from the device clock: morning before noon,
/// afternoon before 6 pm, evening after. Without a first name, no comma.
String greeting(AppLocalizations l10n, DateTime now, String firstName) {
  final part = now.hour < 12
      ? 'morning'
      : now.hour < 18
      ? 'afternoon'
      : 'evening';
  final name = firstName.trim();
  return name.isEmpty
      ? l10n.todayGreeting(part)
      : l10n.todayGreetingNamed(part, name);
}

/// The screen as a function of its inputs, so it can be previewed and tested
/// without providers. One column on every size.
class TodayView extends StatefulWidget {
  const TodayView({
    required this.due,
    required this.tasks,
    required this.now,
    required this.firstName,
    required this.onTick,
    required this.onOpen,
    required this.onRetry,
    required this.onRefresh,
    this.done,
    this.busy = const {},
    this.onGoing,
    this.onFollowedUp,
    this.onRemoveInvite,
    this.onPlan,
    this.onLater,
    this.onNext,
    this.onTickTask,
    this.onOpenTask,
    this.onAddTask,
    this.accountAction,
    this.goals,
    this.model = BusinessModel.other,
    this.onGoals,
    this.onRitual,
    this.checkIns = const [],
    this.onCheckIn,
    this.events = noTodayEvents,
    this.onOpenEvent,
    this.onMarkDone,
    this.onTickStep,
    this.onJoin,
    this.nudge,
    super.key,
  });

  final AsyncValue<List<Due>> due;
  final AsyncValue<List<Task>> tasks;

  /// Steps, reminders and tasks ticked today; null while unknown or
  /// failed, and then the hero has no bar.
  final int? done;

  /// The device clock: the date, the greeting, and which steps are late.
  final DateTime now;

  /// Empty when the account has none: the greeting goes without.
  final String firstName;

  /// [Due.key]s whose tick is in flight.
  final Set<String> busy;

  final void Function(Due due) onTick;

  /// A follow-up row's buttons.
  final void Function(DueFollowUp due)? onGoing;
  final void Function(DueFollowUp due)? onFollowedUp;
  final void Function(DueFollowUp due)? onRemoveInvite;

  /// An event step's buttons (#315).
  final void Function(DueStep due)? onPlan;
  final void Function(DueStep due)? onLater;

  /// "What's next for Sophie?": opens the sheet (#316).
  final void Function(DueNext due)? onNext;
  final void Function(Person person) onOpen;

  /// Task callbacks.
  final void Function(Task task)? onTickTask;
  final void Function(Task task)? onOpenTask;
  final VoidCallback? onAddTask;

  final VoidCallback onRetry;
  final Future<void> Function() onRefresh;

  /// Top-bar entry to Settings, where there is no sidebar to hold it.
  final Widget? accountAction;

  /// This month's goals; null while loading or failed, and then Today shows
  /// nothing of them.
  final GoalsMonth? goals;

  /// For the goal line's unit.
  final BusinessModel model;

  /// The goal line's tap: opens Goals.
  final VoidCallback? onGoals;

  /// The close-and-plan card's Start: opens /goals/close.
  final VoidCallback? onRitual;

  /// Team members to catch up with: folded under the day on a phone or
  /// tablet, in the side column on desktop.
  final List<CheckIn> checkIns;

  /// A check-in row's button: opens Log something.
  final void Function(Person person)? onCheckIn;

  /// Today's events, events to mark, and steps due.
  final TodayEvents events;

  /// An event's title: opens the event.
  final void Function(CalendarEvent event)? onOpenEvent;

  /// "How did … go?" → Mark who was there.
  final void Function(CalendarEvent event)? onMarkDone;

  /// A step's ring: marks it done.
  final void Function(DueEventStep step)? onTickStep;

  /// Join: opens the link.
  final void Function(Uri link)? onJoin;

  /// The daily summary's offer, below People and Tasks, until it is answered.
  final Widget? nudge;

  @override
  State<TodayView> createState() => _TodayViewState();
}

class _TodayViewState extends State<TodayView> {
  /// Per `docs/design/responsive-design.md`: the priority column's width.
  static const double _column = 624;

  /// "And N more waiting" was tapped. Resets on leaving Today.
  bool _expanded = false;

  /// Show or Hide on Catch up; null follows [_catchUpShown]'s default.
  /// Resets on leaving Today.
  bool? _catchUpOpen;

  /// Catch up unfolded: as last tapped, else only when nothing is due, so
  /// the day's list keeps the screen (#342).
  bool get _catchUpShown =>
      _catchUpOpen ??
      switch (widget.due) {
        AsyncData(:final value) => value.isEmpty,
        _ => false,
      };

  /// The priority rows as last built, by person; a null due is a row on its
  /// way out.
  List<({String id, Due? due})> _slots = const [];

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final desktop = context.screenSize.isDesktop;
    final day = DateTime(widget.now.year, widget.now.month, widget.now.day);
    final goals = widget.goals;
    final ritual = goals == null ? null : pendingRitual(day, goals.plans);
    final goalLine = desktop || goals == null || !hasGoalLine(goals)
        ? null
        : GoalLine(
            month: goals,
            today: day,
            model: widget.model,
            onTap: widget.onGoals ?? () {},
          );
    final ritualCard = [
      if (!desktop && ritual != null) ...[
        SizedBox(height: ritual.drafted ? AppSpacing.sm : AppSpacing.md),
        ritualInvitation(ritual, widget.onRitual ?? () {}),
      ],
    ];
    final goalWidgets = [?goalLine, ...ritualCard];
    // Desktop: the month and the team beside the priority list.
    final side = [
      if (goals != null && hasGoalLine(goals))
        volumeCard(
          context,
          month: goals,
          today: day,
          model: widget.model,
          onTap: widget.onGoals,
        ),
      if (ritual != null) ritualInvitation(ritual, widget.onRitual ?? () {}),
      // One group: its rows keep their own 12px rhythm.
      if (widget.checkIns.isNotEmpty)
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: checkInItems(
            l10n,
            widget.checkIns,
            onOpen: widget.onOpen,
            onCheckIn: widget.onCheckIn ?? (_) {},
          ),
        ),
    ];

    final eventItems = todayEventItems(
      context,
      events: widget.events,
      now: widget.now,
      onOpen: widget.onOpenEvent ?? (_) {},
      onMarkDone: widget.onMarkDone ?? (_) {},
      onTick: widget.onTickStep ?? (_) {},
      onJoin: widget.onJoin ?? (_) {},
      busySteps: widget.busy,
    );
    // As a whole: the last row out takes its header with it, fading, so its
    // check is still seen.
    final eventsBlock = [
      FadeSwap(
        duration: AppMotion.slow,
        child: eventItems.isEmpty
            ? const SizedBox.shrink(key: ValueKey('no-events'))
            : Column(
                key: const ValueKey('events'),
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ...eventItems,
                  SizedBox(height: desktop ? AppSpacing.xl : AppSpacing.lg),
                ],
              ),
      ),
    ];

    // Until they load, or when they fail, no task counts.
    final tasks = switch (widget.tasks) {
      AsyncData(:final value) => todayTasks(value, day),
      _ => const <Task>[],
    };
    final tasksBlock = _tasks(l10n, tasks, day);
    final loading = [
      ...goalWidgets,
      ...eventsBlock,
      const Center(child: CircularProgressIndicator()),
    ];

    final (branch, rows) = switch (widget.due) {
      // Tasks still on their way: no "up to date", no people-only headline.
      AsyncData() when !widget.tasks.hasValue && !widget.tasks.hasError => (
        'loading',
        loading,
      ),
      AsyncData(:final value)
          when value.isEmpty && tasks.isEmpty && (widget.done ?? 0) > 0 =>
        (
          'done',
          [
            ..._allDone(
              l10n,
              widget.done!,
              desktop,
              goalLine,
              ritualCard,
              eventsBlock,
            ),
            ...tasksBlock,
          ],
        ),
      AsyncData(:final value) when value.isEmpty && tasks.isEmpty => (
        'up-to-date',
        [
          ...goalWidgets,
          ...eventsBlock,
          const _UpToDate(),
          SizedBox(height: desktop ? AppSpacing.xl : AppSpacing.lg),
          ...tasksBlock,
        ],
      ),
      AsyncData(:final value) => (
        'due',
        _due(l10n, value, tasks, desktop, goalWidgets, eventsBlock, tasksBlock),
      ),
      AsyncError(:final error) => (
        'error',
        [
          ...goalWidgets,
          ...eventsBlock,
          LoadFailed(
            offline: error == PeopleFailure.network,
            title: l10n.todayLoadFailed,
            onRetry: widget.onRetry,
          ),
        ],
      ),
      _ => ('loading', loading),
    };
    // The last row ticked away: the done state is under it as its list fades,
    // and the row's check finishes drawing on the way out.
    final listed = [
      FadeSwap(
        duration: AppMotion.slow,
        child: Column(
          key: ValueKey(branch),
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: rows,
        ),
      ),
    ];

    final nudge = widget.nudge;
    final content = [
      ...listed,
      FadeSwap(
        duration: AppMotion.quick,
        child: nudge == null
            ? const SizedBox.shrink(key: ValueKey('no-nudge'))
            : Padding(
                key: const ValueKey('nudge'),
                padding: const EdgeInsets.only(top: AppSpacing.lg),
                child: nudge,
              ),
      ),
    ];

    return Scaffold(
      body: SafeArea(
        child: Align(
          alignment: AlignmentDirectional.topStart,
          child: ConstrainedBox(
            // Desktop: ContentColumns caps and centres the two columns.
            constraints: BoxConstraints(
              maxWidth: desktop ? double.infinity : _column,
            ),
            child: RefreshIndicator(
              onRefresh: widget.onRefresh,
              child: ListView(
                // Pull to refresh works on a short list too.
                physics: const AlwaysScrollableScrollPhysics(),
                padding: desktop
                    ? const EdgeInsets.symmetric(
                        horizontal: AppSpacing.xxl,
                        vertical: AppSpacing.xl,
                      )
                    : const EdgeInsets.all(AppSpacing.md),
                children: [
                  ContentColumns.aligned(
                    LoomiaTopBar(
                      eyebrow: l10n.todayDate(widget.now),
                      title: greeting(l10n, widget.now, widget.firstName),
                      large: desktop,
                      action: widget.accountAction,
                      gap: AppSpacing.sm,
                    ),
                  ),
                  if (desktop)
                    ContentColumns(
                      main: content,
                      side: [
                        for (final (index, piece) in side.indexed) ...[
                          if (index > 0) const SizedBox(height: AppSpacing.md),
                          piece,
                        ],
                      ],
                    )
                  else ...[
                    ...content,
                    // Desktop has them in the side column.
                    if (widget.checkIns.isNotEmpty) ...[
                      const SizedBox(height: AppSpacing.lg),
                      ...checkInItems(
                        l10n,
                        widget.checkIns,
                        onOpen: widget.onOpen,
                        onCheckIn: widget.onCheckIn ?? (_) {},
                        collapsed: !_catchUpShown,
                        onToggle: () =>
                            setState(() => _catchUpOpen = !_catchUpShown),
                      ),
                    ],
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// The Tasks header, with Add a task, and today's open tasks under it; a
  /// failed load in their place. Nothing while they load.
  List<Widget> _tasks(AppLocalizations l10n, List<Task> tasks, DateTime day) =>
      switch (widget.tasks) {
        AsyncData() => [
          SectionHeader(
            title: l10n.todaySectionTasks,
            actionLabel: l10n.todayAddTask,
            onAction: widget.onAddTask,
          ),
          for (final (index, task) in tasks.indexed)
            SlideSwap(
              key: ValueKey(task.key),
              padding: EdgeInsets.only(top: index > 0 ? AppSpacing.ms : 0),
              child: ActionItem(
                name: task.title,
                reason: task.note,
                icon: Icons.assignment_outlined,
                tag: repeatIcon(context, task),
                maxLines: 2,
                chip: task.dueOn.isBefore(day)
                    ? DateChip(dueLabel(l10n, task.dueOn, day))
                    : timeChip(context, task),
                onOpen: switch (widget.onOpenTask) {
                  final open? => () => open(task),
                  null => null,
                },
                onResolve: switch (widget.onTickTask) {
                  final tick? => () => tick(task),
                  null => null,
                },
                resolved: widget.busy.contains(task.key),
                resolveLabel: l10n.nextStepMarkDone(task.title),
              ),
            ),
        ],
        AsyncError(:final error) => [
          SectionHeader(title: l10n.todaySectionTasks),
          LoadFailed(
            offline: error == PeopleFailure.network,
            title: l10n.todayTasksLoadFailed,
            onRetry: widget.onRetry,
          ),
        ],
        _ => const [],
      };

  /// Everything on today's list was ticked: the hero stays, full, and the
  /// up-to-date line sits under it (under the goal line on a phone, above the
  /// close-the-month card).
  List<Widget> _allDone(
    AppLocalizations l10n,
    int done,
    bool desktop,
    Widget? goalLine,
    List<Widget> ritualCard,
    List<Widget> eventsBlock,
  ) => [
    TodayHero(
      eyebrow: l10n.todayTitle,
      headline: l10n.todayAllDone,
      progress: (done: done, total: done),
    ),
    ?goalLine,
    Padding(
      padding: desktop
          ? const EdgeInsets.only(top: AppSpacing.sm)
          : const EdgeInsetsDirectional.fromSTEB(
              AppSpacing.xs,
              AppSpacing.xs,
              AppSpacing.xs,
              0,
            ),
      child: Text(
        l10n.todayEmptyBody,
        style: Theme.of(context).textTheme.bodySmall,
      ),
    ),
    ...ritualCard,
    SizedBox(height: desktop ? AppSpacing.xl : AppSpacing.lg),
    ...eventsBlock,
  ];

  List<Widget> _due(
    AppLocalizations l10n,
    List<Due> due,
    List<Task> tasks,
    bool desktop,
    List<Widget> goalWidgets,
    List<Widget> eventsBlock,
    List<Widget> tasksBlock,
  ) {
    final shown = _expanded ? due : due.take(desktop ? 6 : 5).toList();
    final now = widget.now;
    final day = DateTime(now.year, now.month, now.day);
    final done = widget.done;
    // People, not rows: a step and a reminder are one person to message.
    final people = {for (final row in due) row.person.id}.length;
    return [
      TodayHero(
        eyebrow: l10n.todayTitle,
        headline: switch ((people, tasks.length)) {
          (_, 0) => l10n.todayHeadline(people),
          (0, final count) => l10n.todayHeadlineTasks(count),
          (_, final count) => l10n.todayHeadlineBoth(people, count),
        },
        // Rows, not people: each tick moves the bar.
        progress: done == null
            ? null
            : (done: done, total: done + due.length + tasks.length),
      ),
      ...goalWidgets,
      SizedBox(height: desktop ? AppSpacing.xl : AppSpacing.lg),
      ...eventsBlock,
      if (due.isNotEmpty) ...[
        SectionHeader(title: l10n.todaySectionPeople),
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: _slotted(shown, (due) => _row(l10n, due, day)),
        ),
        if (shown.length < due.length) ...[
          const SizedBox(height: AppSpacing.ms),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: TextButton(
              onPressed: () => setState(() => _expanded = true),
              child: Text(l10n.todayShowMore(due.length - shown.length)),
            ),
          ),
        ],
        SizedBox(height: desktop ? AppSpacing.xl : AppSpacing.lg),
      ],
      ...tasksBlock,
    ];
  }

  /// One slot per person, so a ticked row slides out where it was and the
  /// next step slides in over it. A person who left keeps an empty slot at
  /// their place, after whoever was above them, while it closes.
  // ponytail: the empty slots stay until Today is rebuilt from scratch, one
  // per row ticked away during a visit; prune them on a timer if that grows.
  List<Widget> _slotted(List<Due> shown, Widget Function(Due due) row) {
    final next = <({String id, Due? due})>[
      for (final due in shown) (id: due.key, due: due),
    ];
    final live = {for (final slot in next) slot.id};
    for (final (index, slot) in _slots.indexed) {
      if (live.contains(slot.id)) continue;
      var at = 0;
      for (var above = index - 1; above >= 0; above--) {
        final found = next.indexWhere((other) => other.id == _slots[above].id);
        if (found != -1) {
          at = found + 1;
          break;
        }
      }
      next.insert(at, (id: slot.id, due: null));
    }
    _slots = next;

    var gap = false;
    final slots = <Widget>[];
    for (final slot in next) {
      final due = slot.due;
      slots.add(
        SlideSwap(
          key: ValueKey(slot.id),
          // The gap belongs to the row below it, and only once a row is
          // above: when the first row leaves, the next one's gap closes too.
          padding: EdgeInsets.only(top: gap ? AppSpacing.ms : 0),
          child: due == null ? null : row(due),
        ),
      );
      if (due != null) gap = true;
    }
    return slots;
  }

  /// Done with a workflow: the row opens what comes next. No ring, no date:
  /// nothing about it is late.
  Widget _whatsNext(AppLocalizations l10n, DueNext due) {
    final open = widget.onNext;
    return ActionItem(
      key: ValueKey(due.key),
      name: due.person.name,
      photoPath: due.person.photoPath,
      reason: l10n.nextWhatTitle(firstName(due.person)),
      detail: l10n.nextWhatDone(due.workflow.name),
      tag: LoomiaChip(label: stageLabel(l10n, due.person.stage)),
      onOpen: open == null ? null : () => open(due),
    );
  }

  /// Someone not going yet: Going, Followed up, Remove instead of the ring.
  Widget _followUp(AppLocalizations l10n, DueFollowUp due, DateTime day) {
    final busy = widget.busy.contains(due.key);
    void Function()? on(void Function(DueFollowUp)? action) =>
        busy || action == null ? null : () => action(due);
    return ActionItem(
      key: ValueKey(due.key),
      name: due.person.name,
      photoPath: due.person.photoPath,
      reason: dueReason(l10n, widget.model, due),
      tag: LoomiaChip(label: stageLabel(l10n, due.person.stage)),
      chip: due.day.isBefore(day)
          ? DateChip(dueLabel(l10n, due.day, day))
          : null,
      onOpen: () => widget.onOpen(due.person),
      actions: [
        FilledButton.tonal(
          style: AppTheme.tonal(context),
          onPressed: on(widget.onGoing),
          child: Text(l10n.eventGoing),
        ),
        TextButton(
          onPressed: on(widget.onFollowedUp),
          child: Text(l10n.eventFollowedUp),
        ),
        TextButton(
          onPressed: on(widget.onRemoveInvite),
          child: Text(l10n.todayRemoveInvite),
        ),
      ],
    );
  }

  Widget _row(AppLocalizations l10n, Due due, DateTime day) {
    if (due is DueFollowUp) return _followUp(l10n, due, day);
    if (due is DueNext) return _whatsNext(l10n, due);
    // A new step or reminder is a new card: it slides in.
    final reason = dueReason(l10n, widget.model, due);
    final (key, detail) = switch (due) {
      DueStep(:final step, missed: final event?) => (
        step.step.id,
        l10n.nextStepMissed(event.title, event.startsAt.toLocal()),
      ),
      DueStep(:final step) => (
        step.step.id,
        l10n.nextStepProgress(step.workflow.name, step.index, step.total),
      ),
      DueReminder(:final reminder) => (reminder.id, l10n.todayReminderDetail),
      DueFollowUp() => throw StateError('built by _followUp'),
      DueNext() => throw StateError('built by _whatsNext'),
      DueLoyalty() => (due.key, null),
    };
    return ActionItem(
      key: ValueKey(key),
      name: due.person.name,
      photoPath: due.person.photoPath,
      reason: reason,
      detail: detail,
      tag: LoomiaChip(label: stageLabel(l10n, due.person.stage)),
      // The accent chip only when a real date drives it: late. A renewal is
      // never late: it is asked until its day.
      chip: due is! DueLoyalty && due.day.isBefore(day)
          ? DateChip(dueLabel(l10n, due.day, day))
          : null,
      onOpen: () => widget.onOpen(due.person),
      onResolve: () => widget.onTick(due),
      resolved: widget.busy.contains(due.key),
      resolveLabel: l10n.nextStepMarkDone(reason),
      actions: due is DueStep && due.step.isEvent ? _plan(due) : null,
    );
  }

  /// Plan and Later instead of the ring; disabled while busy.
  List<Widget> _plan(DueStep due) {
    final busy = widget.busy.contains(due.key);
    void Function()? on(void Function(DueStep)? action) =>
        busy || action == null ? null : () => action(due);
    return planButtons(
      context,
      onPlan: on(widget.onPlan),
      onLater: on(widget.onLater),
    );
  }
}

class _UpToDate extends StatelessWidget {
  const _UpToDate();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return EmptyState(
      icon: Icons.wb_twilight_rounded,
      title: l10n.todayEmptyTitle,
      body: l10n.todayEmptyBody,
    );
  }
}

/// What [due] asks, in plain words: the row's reason on Today and in the
/// Calendar (#378).
String dueReason(AppLocalizations l10n, BusinessModel model, Due due) =>
    switch (due) {
      DueStep(:final step) => step.step.label,
      DueReminder(:final reminder) => reminder.text,
      DueLoyalty(:final person, :final renewal) => loyaltyRenewsText(
        l10n,
        model,
        person,
        renewal,
      ),
      DueFollowUp(:final person, :final event) => l10n.todayFollowUp(
        firstName(person),
        event.title,
        event.startsAt.toLocal(),
      ),
      DueNext(:final person) => l10n.nextWhatTitle(firstName(person)),
    };

/// "Julie's LRP renews Oct 15": the Today row, and the history entry its
/// tick writes.
String loyaltyRenewsText(
  AppLocalizations l10n,
  BusinessModel model,
  Person person,
  DateTime renewal,
) => l10n.todayLoyaltyRenews(
  firstName(person),
  l10n.loyaltyLabel(model.name),
  renewal,
);

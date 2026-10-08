import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:loomia/app/router/routes.dart';
import 'package:loomia/app/shell/app_shell.dart';
import 'package:loomia/app/theme/app_spacing.dart';
import 'package:loomia/core/business_model/business_model.dart';
import 'package:loomia/core/layout/breakpoints.dart';
import 'package:loomia/core/layout/content_columns.dart';
import 'package:loomia/core/ui/action_item.dart';
import 'package:loomia/core/ui/empty_state.dart';
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
import 'package:loomia/features/calendar/presentation/who_was_there_sheet.dart';
import 'package:loomia/features/contacts/domain/people_failure.dart';
import 'package:loomia/features/contacts/domain/person.dart';
import 'package:loomia/features/contacts/presentation/contacts_page.dart';
import 'package:loomia/features/contacts/presentation/log_activity_sheet.dart';
import 'package:loomia/features/contacts/presentation/people_controller.dart';
import 'package:loomia/features/contacts/presentation/people_copy.dart';
import 'package:loomia/features/goals/domain/goal_rules.dart';
import 'package:loomia/features/goals/presentation/goal_line.dart';
import 'package:loomia/features/goals/presentation/goals_controller.dart';
import 'package:loomia/features/goals/presentation/ritual_card.dart';
import 'package:loomia/features/goals/presentation/volume_card.dart';
import 'package:loomia/features/team/domain/check_in.dart';
import 'package:loomia/features/team/presentation/check_in_items.dart';
import 'package:loomia/features/today/domain/due.dart';
import 'package:loomia/features/today/domain/today_events.dart';
import 'package:loomia/features/today/presentation/today_event_items.dart';
import 'package:loomia/features/today/presentation/today_hero.dart';
import 'package:loomia/features/workflows/presentation/event_workflows_controller.dart';
import 'package:loomia/features/workflows/presentation/workflows_controller.dart';
import 'package:loomia/l10n/app_localizations.dart';
import 'package:material_ui/material_ui.dart';

/// The home. Everything else in the product is support (design principle #1).
class TodayPage extends ConsumerStatefulWidget {
  const TodayPage({super.key});

  @override
  ConsumerState<TodayPage> createState() => _TodayPageState();
}

class _TodayPageState extends ConsumerState<TodayPage> {
  /// Rows ([Due.key]) whose tick is in flight: their ring stays filled and
  /// takes no tap, so a second tap can't tick the next step too.
  final Set<String> _busy = {};

  Future<void> _tick(Due due) async {
    final key = due.key;
    if (!_busy.add(key)) return;
    setState(() {});
    try {
      await writePeople(
        context,
        ref,
        (people) => switch (due) {
          DueStep(:final person, :final step) => people.completeStep(
            person,
            step,
            today(),
          ),
          DueReminder(:final person, :final reminder) =>
            people.completeReminder(person, reminder, today()),
        },
      );
    } finally {
      if (mounted) setState(() => _busy.remove(key));
    }
  }

  Future<void> _tickStep(DueEventStep due) async {
    final events = ref.read(
      eventsProvider(ref.read(accountProvider)?.email).notifier,
    );
    final messenger = ScaffoldMessenger.of(context);
    final l10n = AppLocalizations.of(context);
    try {
      await events.tick(due.event.id, due.step.id, today());
    } on PeopleFailure catch (failure) {
      messenger.showSnackBar(
        SnackBar(content: Text(peopleFailureCopy(l10n, failure))),
      );
    }
  }

  /// The people, and this month's goals with them: a failed goals load has
  /// no Try again of its own on Today.
  Future<void> _refresh() {
    ref.invalidate(goalsProvider(ref.read(accountProvider)?.email));
    ref.invalidate(eventsProvider(ref.read(accountProvider)?.email));
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

    final calendarEvents = ref.watch(eventsProvider(owner));
    final eventWorkflows = ref.watch(eventWorkflowsProvider(owner));

    final now = DateTime.now();
    final events = switch ((calendarEvents.value, eventWorkflows.value)) {
      (final list?, final flows) => todayEvents(list, flows ?? const [], now),
      _ => noTodayEvents,
    };

    return TodayView(
      // `.value` survives a failed refresh, so the rows stay on screen.
      due: switch ((people.value, workflows.value)) {
        (final everyone?, final all?) => AsyncData(
          dueToday(everyone, all, today()),
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
      now: now,
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
      onOpen: (person) => openContact(context, person.id),
      onRetry: () {
        if (people.hasError) ref.invalidate(book);
        if (workflows.hasError) ref.invalidate(lists);
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
    );
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
    required this.now,
    required this.firstName,
    required this.onTick,
    required this.onOpen,
    required this.onRetry,
    required this.onRefresh,
    this.busy = const {},
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
    super.key,
  });

  final AsyncValue<List<Due>> due;

  /// The device clock: the date, the greeting, and which steps are late.
  final DateTime now;

  /// Empty when the account has none: the greeting goes without.
  final String firstName;

  /// [Due.key]s whose tick is in flight.
  final Set<String> busy;

  final void Function(Due due) onTick;
  final void Function(Person person) onOpen;
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

  /// Team members worth a check-in: under the day on a phone, in the side
  /// column on desktop.
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

  @override
  State<TodayView> createState() => _TodayViewState();
}

class _TodayViewState extends State<TodayView> {
  /// Per `docs/design/responsive-design.md`: the priority column's width.
  static const double _column = 624;

  /// "And N more waiting" was tapped. Resets on leaving Today.
  bool _expanded = false;

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
    final goalWidgets = desktop
        ? const <Widget>[]
        : [
            if (goals != null && hasGoalLine(goals))
              GoalLine(
                month: goals,
                today: day,
                model: widget.model,
                onTap: widget.onGoals ?? () {},
              ),
            if (ritual != null) ...[
              const SizedBox(height: AppSpacing.md),
              RitualCard(ritual: ritual, onStart: widget.onRitual ?? () {}),
            ],
          ];
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
      if (ritual != null)
        RitualCard(ritual: ritual, onStart: widget.onRitual ?? () {}),
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
    );
    final eventsBlock = [
      if (eventItems.isNotEmpty) ...[
        ...eventItems,
        SizedBox(height: desktop ? AppSpacing.xl : AppSpacing.lg),
      ],
    ];

    final content = switch (widget.due) {
      AsyncData(:final value) when value.isEmpty => [
        ...goalWidgets,
        ...eventsBlock,
        const _UpToDate(),
      ],
      AsyncData(:final value) => _due(
        l10n,
        value,
        desktop,
        goalWidgets,
        eventsBlock,
      ),
      AsyncError() => [
        ...goalWidgets,
        ...eventsBlock,
        _Failed(onRetry: widget.onRetry),
      ],
      _ => [
        ...goalWidgets,
        ...eventsBlock,
        const Center(child: CircularProgressIndicator()),
      ],
    };

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

  List<Widget> _due(
    AppLocalizations l10n,
    List<Due> due,
    bool desktop,
    List<Widget> goalWidgets,
    List<Widget> eventsBlock,
  ) {
    final shown = _expanded ? due : due.take(desktop ? 6 : 5).toList();
    final now = widget.now;
    final day = DateTime(now.year, now.month, now.day);
    return [
      TodayHero(
        eyebrow: l10n.todayTitle,
        // People, not rows: a step and a reminder are one person to message.
        headline: l10n.todayHeadline(
          {for (final row in due) row.person.id}.length,
        ),
      ),
      ...goalWidgets,
      SizedBox(height: desktop ? AppSpacing.xl : AppSpacing.lg),
      ...eventsBlock,
      SectionHeader(title: l10n.todaySectionPriority),
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

  Widget _row(AppLocalizations l10n, Due due, DateTime day) {
    // A new step or reminder is a new card: it slides in.
    final (key, reason, label) = switch (due) {
      DueStep(:final step) => (
        step.step.id,
        l10n.todayReason(
          step.step.label,
          step.workflow.name,
          step.index,
          step.total,
        ),
        step.step.label,
      ),
      DueReminder(:final reminder) => (
        reminder.id,
        l10n.todayReminderReason(reminder.text),
        reminder.text,
      ),
    };
    return ActionItem(
      key: ValueKey(key),
      name: due.person.name,
      reason: reason,
      // The accent chip only when a real date drives it: late.
      chip: due.day.isBefore(day)
          ? DateChip(dueLabel(l10n, due.day, day))
          : null,
      onOpen: () => widget.onOpen(due.person),
      onResolve: () => widget.onTick(due),
      resolved: widget.busy.contains(due.key),
      resolveLabel: l10n.nextStepMarkDone(label),
    );
  }
}

class _Failed extends StatelessWidget {
  const _Failed({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return EmptyState(
      icon: Icons.cloud_off_outlined,
      title: l10n.todayLoadFailed,
      body: l10n.contactsLoadErrorBody,
      actionLabel: l10n.contactsRetry,
      onAction: onRetry,
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

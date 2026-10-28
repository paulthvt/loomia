import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:loomia/app/router/routes.dart';
import 'package:loomia/app/shell/app_shell.dart';
import 'package:loomia/app/theme/app_colors.dart';
import 'package:loomia/app/theme/app_spacing.dart';
import 'package:loomia/app/theme/app_theme.dart';
import 'package:loomia/core/business_model/business_model.dart';
import 'package:loomia/core/layout/breakpoints.dart';
import 'package:loomia/core/ui/animated_rows.dart';
import 'package:loomia/core/ui/fade_swap.dart';
import 'package:loomia/core/ui/pick_day.dart';
import 'package:loomia/core/ui/section_header.dart';
import 'package:loomia/features/auth/data/auth_repository.dart';
import 'package:loomia/features/calendar/domain/calendar_event.dart';
import 'package:loomia/features/calendar/domain/month_grid.dart';
import 'package:loomia/features/calendar/domain/people_ahead.dart';
import 'package:loomia/features/calendar/presentation/calendar_controller.dart';
import 'package:loomia/features/calendar/presentation/desktop_calendar.dart';
import 'package:loomia/features/calendar/presentation/event_form.dart';
import 'package:loomia/features/calendar/presentation/event_row.dart';
import 'package:loomia/features/calendar/presentation/month_grid.dart';
import 'package:loomia/features/calendar/presentation/people_block.dart';
import 'package:loomia/features/calendar/presentation/week_view.dart';
import 'package:loomia/features/contacts/domain/people_failure.dart';
import 'package:loomia/features/contacts/domain/person.dart';
import 'package:loomia/features/contacts/presentation/contacts_page.dart';
import 'package:loomia/features/contacts/presentation/people_controller.dart';
import 'package:loomia/features/tasks/domain/task.dart';
import 'package:loomia/features/tasks/presentation/task_row.dart';
import 'package:loomia/features/tasks/presentation/task_sheet.dart';
import 'package:loomia/features/tasks/presentation/tasks_controller.dart';
import 'package:loomia/features/tasks/presentation/toggle_task.dart';
import 'package:loomia/features/workflows/presentation/workflows_controller.dart';
import 'package:loomia/l10n/app_localizations.dart';
import 'package:material_ui/material_ui.dart';

/// Opens an event: in the pane beside the month on desktop, pushed above
/// the month elsewhere so back returns to it.
void openEvent(BuildContext context, String id) {
  final location = Routes.eventLocation(id);
  if (context.screenSize.isDesktop) {
    context.go(location);
  } else {
    unawaited(context.push(location));
  }
}

/// Opens a task (#390), as [openEvent] opens an event: in the pane beside the
/// month on desktop, pushed above the current screen elsewhere.
void openTask(BuildContext context, String id) {
  final location = Routes.taskLocation(id);
  if (context.screenSize.isDesktop) {
    context.go(location);
  } else {
    unawaited(context.push(location));
  }
}

/// The Calendar destination. On desktop it also holds [pane]: an open
/// event or task, beside the month or week ([paneOpen]); a day opens in a
/// popover.
class CalendarPage extends ConsumerStatefulWidget {
  const CalendarPage({this.pane, this.paneOpen = false, super.key});

  final Widget? pane;
  final bool paneOpen;

  @override
  ConsumerState<CalendarPage> createState() => _CalendarPageState();
}

class _CalendarPageState extends ConsumerState<CalendarPage> {
  /// How far the title's pickers reach, either side of today.
  static const int _pickYears = 10;

  /// Tasks ([Task.key]) whose write is in flight: their ring takes no tap.
  final Set<String> _busy = {};

  /// A task's ring: an open one is done today, with Undo, and stays on its
  /// day crossed out; a done one opens again, with no snackbar. On desktop
  /// the ring only lives in the day popover, whose barrier would catch the
  /// click on Undo: no Undo there, the ring unticks in one tap.
  Future<void> _toggleTask(Task task) async {
    final key = task.key;
    if (!_busy.add(key)) return;
    setState(() {});
    try {
      await toggleTask(
        context,
        ref,
        task,
        withUndo: !context.screenSize.isDesktop,
      );
    } finally {
      if (mounted) setState(() => _busy.remove(key));
    }
  }

  Future<void> _pickTitle(BuildContext context, WidgetRef ref) async {
    final selection = ref.read(calendarSelectionProvider);
    final selector = ref.read(calendarSelectionProvider.notifier);
    final now = today();
    final first = DateTime(now.year - _pickYears, now.month);
    final last = DateTime(now.year + _pickYears, now.month + 1, 0);
    switch (selection.mode) {
      case CalendarMode.month:
        final month = await pickMonth(
          context,
          initial: selection.month,
          first: first,
          last: last,
        );
        if (month != null) selector.showMonth(month);
      case CalendarMode.week:
        final day = await pickDay(
          context,
          initial: selection.day,
          first: first,
          last: last,
        );
        if (day != null) selector.select(day);
    }
  }

  Future<void> _add(BuildContext context, WidgetRef ref, DateTime day) async {
    final saved = await showEventForm(context, day: day);
    if (saved != null && context.mounted) {
      ref.read(calendarSelectionProvider.notifier).select(saved.day);
    }
  }

  /// Adds or edits a task; the calendar then shows the day it is due.
  Future<void> _task(DateTime day, {Task? editing}) async {
    final saved = await showTask(context, day: day, editing: editing);
    if (saved != null && mounted) {
      ref.read(calendarSelectionProvider.notifier).select(saved.dueOn);
    }
  }

  /// Reloads the events, the book their people come from, and the tasks,
  /// while the month stays on screen. An events failure says so in a
  /// SnackBar; a tasks one only leaves their rows out.
  Future<void> _refresh(BuildContext context, WidgetRef ref) async {
    final owner = ref.read(accountProvider)?.email;
    final messenger = ScaffoldMessenger.of(context);
    final l10n = AppLocalizations.of(context);
    final provider = eventsProvider(owner);
    ref
      ..invalidate(peopleProvider(owner))
      ..invalidate(tasksProvider(owner))
      ..invalidate(provider);
    try {
      await ref.read(provider.future);
    } on PeopleFailure {
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.contactsRefreshFailed)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final owner = ref.watch(accountProvider)?.email;
    final provider = eventsProvider(owner);
    final pane = widget.pane;
    final paneOpen = widget.paneOpen;
    final selector = ref.read(calendarSelectionProvider.notifier);
    final selection = ref.watch(calendarSelectionProvider);
    final desktop = context.screenSize.isDesktop;
    final firstDay = MaterialLocalizations.of(context).firstDayOfWeekIndex;
    final events = ref.watch(provider);
    final people = ref.watch(peopleProvider(owner)).value;
    final workflows = ref.watch(workflowsProvider(owner)).value;
    return CalendarView(
      events: events,
      // While people or workflows load, or failed, nobody shows (#378);
      // events and tasks are unaffected.
      people: switch ((people, workflows)) {
        (final everyone?, final all?) => PeopleAhead(
          people: everyone,
          workflows: all,
          events: events.value ?? const [],
          today: today(),
        ),
        _ => const PeopleAhead.none(),
      },
      model: ref.watch(accountProvider)?.businessModel ?? BusinessModel.other,
      onOpenPerson: (person) => openContact(context, person.id),
      // A failed load leaves the tasks out, the events stay.
      tasks: ref.watch(tasksProvider(owner)).value ?? const [],
      busy: _busy,
      selection: selection,
      today: today(),
      // ponytail: read on build, as Today; the line moves on the next
      // rebuild, not by itself. A minute timer if it ever matters.
      now: DateTime.now(),
      onSelect: (day) {
        selector.select(day);
        // Desktop: an open event gives the pane back to the day.
        if (desktop && paneOpen) context.go(Routes.calendar);
      },
      onShift: (delta) => selector.shift(delta, firstDayOfWeek: firstDay),
      onToday: selector.toToday,
      onMode: selector.setMode,
      onPickTitle: () => unawaited(_pickTitle(context, ref)),
      onOpen: (event) => openEvent(context, event.id),
      onAdd: (day) => unawaited(_add(context, ref, day)),
      onToggleTask: (task) => unawaited(_toggleTask(task)),
      onAddTask: (day) => unawaited(_task(day)),
      onOpenTask: (task) => unawaited(_task(task.dueOn, editing: task)),
      onRetry: () => ref.invalidate(provider),
      onRefresh: () => _refresh(context, ref),
      desktop: desktop,
      pane: paneOpen ? pane : null,
      // With a sidebar, Settings is its account block instead, and there
      // is no pull to refresh on a mouse: a button, as on Today.
      accountAction: context.screenSize.usesSideNavigation
          ? IconButton(
              onPressed: () => unawaited(_refresh(context, ref)),
              tooltip: AppLocalizations.of(context).contactsRefresh,
              icon: const Icon(Icons.refresh_rounded),
            )
          : const AccountButton(),
    );
  }
}

/// The screen as a function of its inputs, for previews and tests. Mobile
/// and tablet: the month and the selected day, or the week strip and the
/// week's days, and an add button. Desktop (#366): the full-width month or
/// the week's hour grid, a day's popover on click, and [pane] (an open
/// event) on the right when there is one.
class CalendarView extends StatelessWidget {
  const CalendarView({
    required this.events,
    required this.selection,
    required this.today,
    required this.onSelect,
    required this.onShift,
    required this.onToday,
    required this.onOpen,
    required this.onAdd,
    required this.onAddTask,
    required this.onRetry,
    required this.tasks,
    required this.onToggleTask,
    required this.onOpenTask,
    this.busy = const {},
    this.onMode,
    this.onPickTitle,
    this.onRefresh,
    this.now,
    this.desktop = false,
    this.pane,
    this.accountAction,
    this.people = const PeopleAhead.none(),
    this.model = BusinessModel.other,
    this.onOpenPerson,
    super.key,
  });

  /// Fixed, like the Contacts list, so a resized window narrows the month.
  static const double _paneWidth = 440;

  final AsyncValue<List<CalendarEvent>> events;

  /// Who is due when (#378): the day's People block, the grid's markers.
  final PeopleAhead people;
  final BusinessModel model;

  /// A person's row in the People block: their page.
  final void Function(Person person)? onOpenPerson;

  /// Every task, open and done; each shows on its due day.
  final List<Task> tasks;

  /// [Task.key]s whose write is in flight.
  final Set<String> busy;
  final CalendarSelection selection;

  /// The device's today, local midnight.
  final DateTime today;

  /// The desktop week's now line. None without it.
  final DateTime? now;

  final ValueChanged<DateTime> onSelect;

  /// −1 for the month (or week) before, 1 for the one after.
  final ValueChanged<int> onShift;
  final VoidCallback onToday;
  final void Function(CalendarEvent event) onOpen;

  /// Adds an event on the given day. On mobile and tablet, the add button
  /// and the day's Add first ask Event or Task; Task opens the task sheet.
  final ValueChanged<DateTime> onAdd;

  /// Opens the task sheet for a new task on the given day.
  final ValueChanged<DateTime> onAddTask;
  final VoidCallback onRetry;

  /// A task's ring: ticks an open one, unticks a done one.
  final void Function(Task task) onToggleTask;
  final void Function(Task task) onOpenTask;

  /// Month or week. None in previews.
  final ValueChanged<CalendarMode>? onMode;

  /// The title's picker: a month, or a day whose week to show.
  final VoidCallback? onPickTitle;

  /// Pull to refresh, on mobile and tablet. None in previews.
  final Future<void> Function()? onRefresh;

  /// The desktop layout: the calendar beside [pane], or alone.
  final bool desktop;
  final Widget? pane;

  /// Top-bar entry to Settings, where there is no sidebar to hold it.
  final Widget? accountAction;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final week = selection.mode == CalendarMode.week;
    final firstDay = MaterialLocalizations.of(context).firstDayOfWeekIndex;
    final days = weekDays(selection.day, firstDay);
    final title = week
        ? weekTitle(l10n, days)
        : l10n.calendarMonth(selection.month);
    final modeSwitch = SegmentedButton<CalendarMode>(
      segments: [
        for (final (mode, label) in [
          (CalendarMode.month, l10n.calendarViewMonth),
          (CalendarMode.week, l10n.calendarViewWeek),
        ])
          ButtonSegment(
            value: mode,
            label: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
          ),
      ],
      selected: {selection.mode},
      onSelectionChanged: (modes) => onMode?.call(modes.single),
    );
    final todayButton = TextButton(
      onPressed: onToday,
      child: Text(l10n.calendarToday),
    );
    final previous = IconButton(
      onPressed: () => onShift(-1),
      tooltip: week ? l10n.calendarPreviousWeek : l10n.calendarPreviousMonth,
      icon: const Icon(Icons.chevron_left_rounded),
    );
    final next = IconButton(
      onPressed: () => onShift(1),
      tooltip: week ? l10n.calendarNextWeek : l10n.calendarNextMonth,
      icon: const Icon(Icons.chevron_right_rounded),
    );
    Widget titleButton(TextStyle? style) => Expanded(
      child: Align(
        alignment: AlignmentDirectional.centerStart,
        child: _TitleButton(
          title: title,
          semantics: week
              ? l10n.calendarChooseWeek(title)
              : l10n.calendarChooseMonth(selection.month),
          style: style,
          onTap: onPickTitle,
        ),
      ),
    );

    if (desktop) {
      return _Latest(
        view: this,
        builder: (context, latest) =>
            _desktop(context, latest, days, firstDay, [
              titleButton(theme.textTheme.headlineSmall),
              modeSwitch,
              const SizedBox(width: AppSpacing.sm),
              todayButton,
              previous,
              next,
              ?accountAction,
            ]),
      );
    }

    final header = Row(
      children: [
        titleButton(theme.textTheme.headlineSmall),
        previous,
        next,
        ?accountAction,
      ],
    );
    final switcher = Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      spacing: AppSpacing.sm,
      children: [
        // Shrinks before Today does, its labels cut with "…" if need be.
        Flexible(child: modeSwitch),
        todayButton,
      ],
    );
    final counts = eventsPerDay(events.value ?? const []);
    final taskCounts = openTasksPerDay(tasks);
    final pager = week
        ? _SwipePager(
            anchor: days.first,
            onShift: onShift,
            builder: (delta) => WeekStrip(
              days: weekDays(
                DateTime(
                  days.first.year,
                  days.first.month,
                  days.first.day + DateTime.daysPerWeek * delta,
                ),
                firstDay,
              ),
              selected: selection.day,
              today: today,
              counts: counts,
              taskCounts: taskCounts,
              people: people,
              onSelect: onSelect,
            ),
          )
        : _SwipePager(
            anchor: selection.month,
            onShift: onShift,
            builder: (delta) => MonthGrid(
              month: DateTime(
                selection.month.year,
                selection.month.month + delta,
              ),
              selected: selection.day,
              today: today,
              counts: counts,
              taskCounts: taskCounts,
              people: people,
              onSelect: onSelect,
            ),
          );

    return Scaffold(
      floatingActionButton: Builder(
        builder: (button) => FloatingActionButton(
          onPressed: () => unawaited(
            chooseAdd(
              button,
              day: selection.day,
              onEvent: onAdd,
              onTask: onAddTask,
            ),
          ),
          tooltip: l10n.calendarAdd,
          child: const Icon(Icons.add_rounded),
        ),
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, box) {
            final top = [
              header,
              const SizedBox(height: AppSpacing.sm),
              switcher,
              const SizedBox(height: AppSpacing.md),
              pager,
            ];
            final below = FadeSwap(
              duration: AppMotion.medium,
              // The month's selected day: another day, another list. The
              // week list holds every day, so picking one doesn't swap it.
              child: KeyedSubtree(
                key: ValueKey(week ? 'week' : selection.day),
                child: week
                    ? WeekList(
                        events: events,
                        tasks: tasks,
                        busy: busy,
                        days: days,
                        selected: selection.day,
                        today: today,
                        onOpen: onOpen,
                        onToggleTask: onToggleTask,
                        onOpenTask: onOpenTask,
                        onRetry: onRetry,
                        people: people,
                        model: model,
                        onOpenPerson: onOpenPerson,
                      )
                    : DaySection(
                        events: events,
                        tasks: tasks,
                        busy: busy,
                        day: selection.day,
                        onOpen: onOpen,
                        onToggleTask: onToggleTask,
                        onOpenTask: onOpenTask,
                        onAdd: onAdd,
                        onAddTask: onAddTask,
                        onRetry: onRetry,
                        people: people,
                        model: model,
                        onOpenPerson: onOpenPerson,
                      ),
              ),
            );
            const sides = EdgeInsets.symmetric(horizontal: AppSpacing.md);
            // The bottom inset keeps the last row clear of the add button.
            const bottom = AppSpacing.xxxl + AppSpacing.lg;
            Widget scrolling(EdgeInsets padding, List<Widget> children) =>
                _refreshable(
                  ListView(
                    // Pull to refresh works on a short list too.
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: padding,
                    children: children,
                  ),
                );
            // On its side the phone has no room to hold the calendar still:
            // everything scrolls, and a curved swipe can still miss.
            if (box.maxHeight < _pinnedMinHeight) {
              return scrolling(
                sides.copyWith(top: AppSpacing.sm, bottom: bottom),
                [...top, const Divider(height: AppSpacing.xl), below],
              );
            }
            // Held still, the month or the strip has no vertical drag to
            // lose a swipe to (#369); only the list below scrolls and pulls.
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: sides.copyWith(top: AppSpacing.sm),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: top,
                  ),
                ),
                const Padding(
                  padding: sides,
                  child: Divider(height: AppSpacing.xl),
                ),
                Expanded(
                  child: scrolling(sides.copyWith(bottom: bottom), [below]),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  /// Below this height (a phone on its side) the calendar scrolls with the
  /// list instead of staying put above it: a six-week month, the header and
  /// the switch take about 420 px. ponytail: a fixed cut, not a measure.
  static const double _pinnedMinHeight = 560;

  /// Desktop (#366): one header row, then the month or the week filling
  /// the window; an open event's pane beside it.
  Widget _desktop(
    BuildContext context,
    ValueNotifier<CalendarView> latest,
    List<DateTime> days,
    int firstDay,
    List<Widget> header,
  ) {
    final l10n = AppLocalizations.of(context);
    final list = events.value ?? const <CalendarEvent>[];
    void openDay(DateTime day, Rect anchor) {
      onSelect(day);
      unawaited(
        showDayPopover(
          context,
          anchor: anchor,
          label: l10n.calendarDayTitle(day),
          builder: (popover) {
            void closing<T>(void Function(T) then, T value) {
              Navigator.pop(popover);
              then(value);
            }

            // The popover is a route of its own: it reads the view's latest
            // build, so a ticked task crosses out in place.
            return ValueListenableBuilder(
              valueListenable: latest,
              builder: (_, view, _) => DaySection(
                events: view.events,
                tasks: view.tasks,
                busy: view.busy,
                day: day,
                onOpen: (event) => closing(view.onOpen, event),
                onToggleTask: view.onToggleTask,
                onOpenTask: (task) => closing(view.onOpenTask, task),
                onAdd: (day) => closing(view.onAdd, day),
                onAddTask: (day) => closing(view.onAddTask, day),
                onRetry: view.onRetry,
                people: view.people,
                model: view.model,
                peopleFoldable: false,
                onOpenPerson: (person) =>
                    closing((Person p) => view.onOpenPerson?.call(p), person),
              ),
            );
          },
        ),
      );
    }

    final side = pane;
    return Scaffold(
      body: SafeArea(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.xl,
                  vertical: AppSpacing.lg,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  spacing: AppSpacing.md,
                  children: [
                    Row(children: header),
                    ?eventsNotLoaded(context, events, onRetry),
                    Expanded(
                      child: selection.mode == CalendarMode.week
                          ? WeekGrid(
                              days: days,
                              events: list,
                              selected: selection.day,
                              today: today,
                              now: now,
                              onOpen: onOpen,
                              tasks: tasks,
                              onOpenTask: onOpenTask,
                              onDay: openDay,
                              people: people,
                            )
                          : DesktopMonth(
                              month: selection.month,
                              days: monthDays(selection.month, firstDay),
                              events: list,
                              selected: selection.day,
                              today: today,
                              onOpen: onOpen,
                              tasks: tasks,
                              onOpenTask: onOpenTask,
                              onDay: openDay,
                              people: people,
                            ),
                    ),
                  ],
                ),
              ),
            ),
            if (side != null)
              Container(
                width: _paneWidth,
                decoration: BoxDecoration(
                  border: Border(
                    left: BorderSide(
                      color: LoomiaColors.of(context).borderSubtle,
                    ),
                  ),
                ),
                child: side,
              ),
          ],
        ),
      ),
    );
  }

  Widget _refreshable(Widget list) {
    final refresh = onRefresh;
    return refresh == null
        ? list
        : RefreshIndicator(onRefresh: refresh, child: list);
  }
}

/// Hands each new [view] to what [builder] opens over it, through `latest`:
/// a day's popover is a route of its own, out of reach of the view's
/// rebuilds.
class _Latest extends StatefulWidget {
  const _Latest({required this.view, required this.builder});

  final CalendarView view;
  final Widget Function(
    BuildContext context,
    ValueNotifier<CalendarView> latest,
  )
  builder;

  @override
  State<_Latest> createState() => _LatestState();
}

class _LatestState extends State<_Latest> {
  late final ValueNotifier<CalendarView> _latest = ValueNotifier(widget.view);

  @override
  void didUpdateWidget(_Latest old) {
    super.didUpdateWidget(old);
    // After the frame: rebuilding the popover, another route, mid-build
    // is not allowed.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _latest.value = widget.view;
    });
  }

  @override
  void dispose() {
    _latest.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.builder(context, _latest);
}

/// The Calendar's title, a button that opens its picker: the month, or the
/// week. One line, cut with "…" if it still doesn't fit.
class _TitleButton extends StatelessWidget {
  const _TitleButton({
    required this.title,
    required this.semantics,
    required this.style,
    required this.onTap,
  });

  final String title;
  final String semantics;
  final TextStyle? style;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: semantics,
    excludeSemantics: true,
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadii.sm),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          spacing: AppSpacing.xs,
          children: [
            Flexible(
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: style,
              ),
            ),
            Icon(
              Icons.expand_more_rounded,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ],
        ),
      ),
    ),
  );
}

/// A horizontal drag that claims the gesture at half the usual slop, so a
/// swipe whose first pixels lean down as much as sideways is the page's,
/// not the vertical scroll's around it, which still needs its full slop.
class _SidewaysDrag extends HorizontalDragGestureRecognizer {
  @override
  bool hasSufficientGlobalDistanceToAccept(
    PointerDeviceKind pointerDeviceKind,
    double? deviceTouchSlop,
  ) =>
      globalDistanceMoved.abs() >
      computeHitSlop(pointerDeviceKind, gestureSettings) / 2;
}

/// A page of the calendar (a month grid, a week strip) at [anchor], which
/// follows the finger: dragged sideways, the neighbouring page comes in
/// beside it, and on release the page turns (past halfway, or flung) or
/// springs back. The arrows and Today slide the new page in from its side
/// too. Reduce motion: they just switch.
class _SwipePager extends StatefulWidget {
  const _SwipePager({
    required this.anchor,
    required this.onShift,
    required this.builder,
  });

  /// What the page shows: the month's 1st, or the week's first day.
  final DateTime anchor;

  /// −1 for the page before, 1 for the one after.
  final ValueChanged<int> onShift;

  /// The page [delta] pages away from [anchor].
  final Widget Function(int delta) builder;

  @override
  State<_SwipePager> createState() => _SwipePagerState();
}

class _SwipePagerState extends State<_SwipePager>
    with SingleTickerProviderStateMixin {
  /// A release faster than this, in px/s, the way the page was dragged,
  /// turns it however short the drag was: a thumb's flick, not only a fling.
  static const double _fling = 100;

  /// Released slower, a drag past this share of the width still turns.
  static const double _past = 1 / 3;

  /// Where [_SwipePager.anchor]'s page sits, in page widths: −1 is off to
  /// the left with the next page fully in, 1 off to the right with the one
  /// before fully in.
  late final _offset = AnimationController.unbounded(vsync: this);
  double _width = 1;

  /// The side a released drag is turning to, until the page lands: −1, 1,
  /// or 0 when nothing is turning.
  double _turning = 0;

  /// [_grab] landed a turn and already moved the offset onto the new page,
  /// so the anchor change it causes must not move it again: the rebuild
  /// may come mid-drag, or (in a test) only after the new release.
  bool _rebased = false;

  @override
  void didUpdateWidget(_SwipePager old) {
    super.didUpdateWidget(old);
    if (widget.anchor == old.anchor) return;
    if (_rebased) {
      _rebased = false;
      return;
    }
    final step = widget.anchor.isAfter(old.anchor) ? 1.0 : -1.0;
    // After a drag the new page is already in place (−1 + 1 = 0); after
    // the arrows or Today it starts on its side and slides in.
    _offset.value = context.reduceMotion
        ? 0
        : (_offset.value + step).clamp(-1.0, 1.0);
    unawaited(_settle(0));
  }

  @override
  void dispose() {
    _offset.dispose();
    super.dispose();
  }

  Future<void> _settle(double target) => _offset.animateTo(
    target,
    duration: context.motion(AppMotion.medium),
    curve: AppMotion.decelerate,
  );

  void _drag(DragUpdateDetails details) {
    final delta = (details.primaryDelta ?? 0) / _width;
    _offset.value = (_offset.value + delta).clamp(-1.0, 1.0);
  }

  /// A new drag stops whatever is moving. A page still turning lands now,
  /// so a quick second swipe turns another page instead of cancelling the
  /// first; the new drag goes on from where the page visibly is.
  void _grab() {
    _offset.stop();
    final turning = _turning;
    _turning = 0;
    if (turning == 0) return;
    // The new page's own offset: the next page sits one width right of
    // the old (−0.8 → 0.2). Left (−1) shows the next page.
    _offset.value -= turning;
    _rebased = true;
    widget.onShift(-turning.toInt());
  }

  Future<void> _release(DragEndDetails details) async {
    final velocity = details.primaryVelocity ?? 0;
    final at = _offset.value;
    // A flick back against the drag cancels it rather than turning the
    // other way.
    final double target =
        velocity.abs() > _fling && (at == 0 || velocity.sign == at.sign)
        ? velocity.sign
        : velocity.abs() > _fling
        ? 0
        : at.abs() > _past
        ? at.sign
        : 0;
    _turning = target;
    // Never completes when a new drag stops it; [_grab] turns it then.
    await _settle(target);
    if (_turning == 0 || !mounted) return;
    _turning = 0;
    widget.onShift(-target.toInt());
  }

  @override
  Widget build(BuildContext context) {
    Widget page(int delta, double at) => FractionalTranslation(
      translation: Offset(at, 0),
      child: widget.builder(delta),
    );
    return RawGestureDetector(
      // The whole page swipes, the gaps between days too: only the days'
      // own squares hit, so a swipe started between two rows or between
      // the weekday names and the first row would be lost (#369).
      behavior: HitTestBehavior.opaque,
      gestures: {
        _SidewaysDrag: GestureRecognizerFactoryWithHandlers<_SidewaysDrag>(
          _SidewaysDrag.new,
          (drag) => drag
            ..onStart = ((_) => _grab())
            ..onUpdate = _drag
            ..onEnd = ((details) => unawaited(_release(details)))
            ..onCancel = () => unawaited(_settle(0)),
        ),
      },
      // A five-week month and a six-week one: the height eases between them.
      child: AnimatedSize(
        duration: context.motion(AppMotion.medium),
        curve: AppMotion.standard,
        alignment: Alignment.topCenter,
        child: LayoutBuilder(
          builder: (context, constraints) {
            _width = constraints.maxWidth;
            return AnimatedBuilder(
              animation: _offset,
              builder: (context, _) {
                final at = _offset.value;
                // Clipped, so the months slide under the page's padding.
                return ClipRect(
                  child: Stack(
                    children: [
                      page(0, at),
                      // Only while moving; it sizes nothing, so a taller
                      // neighbour is cut to this month's height meanwhile.
                      if (at != 0)
                        Positioned(
                          top: 0,
                          left: 0,
                          right: 0,
                          child: ExcludeSemantics(
                            child: at < 0 ? page(1, at + 1) : page(-1, at - 1),
                          ),
                        ),
                    ],
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}

/// The selected day: its heading with Add, then its tasks and its events,
/// or what is wrong with loading the events.
class DaySection extends StatelessWidget {
  const DaySection({
    required this.events,
    required this.day,
    required this.onOpen,
    required this.onAdd,
    required this.onRetry,
    this.tasks = const [],
    this.busy = const {},
    this.onToggleTask,
    this.onOpenTask,
    this.onAddTask,
    this.people = const PeopleAhead.none(),
    this.model = BusinessModel.other,
    this.onOpenPerson,
    this.peopleFoldable = true,
    super.key,
  });

  final AsyncValue<List<CalendarEvent>> events;

  /// Every task; those due on [day] show above its events.
  final List<Task> tasks;

  /// Who is due when: [day]'s people show between its tasks and events.
  final PeopleAhead people;
  final BusinessModel model;
  final void Function(Person person)? onOpenPerson;

  /// False in the desktop popover: the people always show.
  final bool peopleFoldable;

  /// [Task.key]s whose write is in flight.
  final Set<String> busy;
  final DateTime day;
  final void Function(CalendarEvent event) onOpen;
  final void Function(Task task)? onToggleTask;
  final void Function(Task task)? onOpenTask;

  /// Adds an event on the day.
  final ValueChanged<DateTime> onAdd;

  /// Adds a task on the day. With it, Add asks Event or Task first.
  final ValueChanged<DateTime>? onAddTask;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    // `.value` survives a failed refresh, so the rows stay on screen.
    final list = events.value;
    final List<Widget> body;
    if (list == null) {
      body = [?eventsNotLoaded(context, events, onRetry)];
    } else {
      final onDay = <Widget>[
        for (final task in tasksOn(tasks, day))
          TaskRow(
            key: ValueKey('task:${task.id}'),
            task: task,
            busy: busy.contains(task.key),
            onOpen: () => onOpenTask?.call(task),
            onToggle: () => onToggleTask?.call(task),
          ),
        if (people.on(day) case final due when due.isNotEmpty)
          PeopleBlock(
            key: ValueKey(day),
            people: due,
            model: model,
            foldable: peopleFoldable,
            onOpen: (person) => onOpenPerson?.call(person),
          ),
        for (final event in eventsOn(list, day))
          EventRow(
            key: ValueKey('event:${event.id}'),
            event: event,
            onTap: () => onOpen(event),
          ),
      ];
      body = onDay.isEmpty
          ? [
              Text(
                l10n.calendarNothingPlanned,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: LoomiaColors.of(context).textMuted,
                ),
              ),
            ]
          : [
              // A task or event added or deleted grows in or folds out once
              // its sheet has closed; another day is a new list.
              AnimatedRows(
                key: ValueKey(('rows', day)),
                spacing: AppSpacing.ms,
                delay: context.motion(AppMotion.slow),
                children: onDay,
              ),
            ];
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Builder(
          builder: (header) => SectionHeader(
            title: l10n.calendarDayTitle(day),
            actionLabel: l10n.calendarAdd,
            onAction: switch (onAddTask) {
              final onTask? => () => unawaited(
                chooseAdd(header, day: day, onEvent: onAdd, onTask: onTask),
              ),
              null => () => onAdd(day),
            },
          ),
        ),
        const SizedBox(height: AppSpacing.ms),
        ...body,
      ],
    );
  }
}

/// The Calendar's add (the button, a day's Add): a menu at [anchor]'s end
/// that asks Event or Task, then runs [onEvent] or [onTask] for [day].
Future<void> chooseAdd(
  BuildContext anchor, {
  required DateTime day,
  required ValueChanged<DateTime> onEvent,
  required ValueChanged<DateTime> onTask,
}) async {
  final l10n = AppLocalizations.of(anchor);
  final box = anchor.findRenderObject()! as RenderBox;
  final overlay = Overlay.of(anchor).context.findRenderObject()! as RenderBox;
  final rect = box.localToGlobal(Offset.zero, ancestor: overlay) & box.size;
  // From the end of the anchor, so the menu sits over its button and the
  // screen's edge pushes it back in. ponytail: LTR only, both locales are.
  final at = Rect.fromLTWH(rect.right, rect.top, 0, rect.height);
  Widget item(IconData icon, String label) =>
      Row(spacing: AppSpacing.ms, children: [Icon(icon), Text(label)]);
  final choice = await showMenu<ValueChanged<DateTime>>(
    context: anchor,
    position: RelativeRect.fromRect(at, Offset.zero & overlay.size),
    items: [
      PopupMenuItem(
        value: onEvent,
        child: item(Icons.event_outlined, l10n.calendarAddEvent),
      ),
      PopupMenuItem(
        value: onTask,
        child: item(Icons.assignment_outlined, l10n.calendarAddTask),
      ),
    ],
  );
  choice?.call(day);
}

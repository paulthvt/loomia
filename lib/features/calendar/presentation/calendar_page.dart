import 'dart:async';
import 'dart:math' as math;

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
import 'package:loomia/features/calendar/domain/day_timeline.dart';
import 'package:loomia/features/calendar/domain/month_grid.dart';
import 'package:loomia/features/calendar/domain/people_ahead.dart';
import 'package:loomia/features/calendar/domain/week_grid.dart';
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
  /// click on Undo: no Undo there, nor in the phone's day sheet
  /// ([withUndo] false); the ring unticks in one tap.
  Future<void> _toggleTask(Task task, {required bool withUndo}) async {
    final key = task.key;
    if (!_busy.add(key)) return;
    setState(() {});
    try {
      await toggleTask(context, ref, task, withUndo: withUndo);
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
      // 3 days: a day off the page starts it (`select`).
      case CalendarMode.threeDays:
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

  /// Adds a task; the calendar then shows the day it is due. A task is
  /// edited from its page (#390).
  Future<void> _task(DateTime day) async {
    final saved = await showTask(context, day: day);
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
      onToggleTask: (task) => unawaited(_toggleTask(task, withUndo: !desktop)),
      onToggleTaskQuiet: (task) =>
          unawaited(_toggleTask(task, withUndo: false)),
      onAddTask: (day) => unawaited(_task(day)),
      onOpenTask: (task) => openTask(context, task.id),
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
/// and tablet: the month and the selected day, or 3 days or the week on an
/// hour grid whose days open in a sheet, and an add button. Desktop (#366): the full-width month or
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
    this.onToggleTaskQuiet,
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

  /// The desktop week's now line, and which events are over (#451). None
  /// without it.
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

  /// The ring in a day's popover or sheet, whose barrier would catch Undo:
  /// no Undo. [onToggleTask] without it.
  final void Function(Task task)? onToggleTaskQuiet;
  final void Function(Task task) onOpenTask;

  /// Month, 3 days or week. None in previews.
  final ValueChanged<CalendarMode>? onMode;

  /// The title's picker: a month, or a day whose week (or 3 days) to show.
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
    // Desktop has no 3 days: it shows the week holding the selected day.
    final mode = desktop && selection.mode == CalendarMode.threeDays
        ? CalendarMode.week
        : selection.mode;
    final firstDay = MaterialLocalizations.of(context).firstDayOfWeekIndex;
    final days = desktop
        ? weekDays(selection.day, firstDay)
        : shownDays(selection, firstDay);
    final title = mode == CalendarMode.month
        ? l10n.calendarMonth(selection.month)
        : weekTitle(l10n, days);
    final modeSwitch = SegmentedButton<CalendarMode>(
      segments: [
        for (final (mode, label) in [
          (CalendarMode.month, l10n.calendarViewMonth),
          if (!desktop) (CalendarMode.threeDays, l10n.calendarViewThreeDays),
          (CalendarMode.week, l10n.calendarViewWeek),
        ])
          ButtonSegment(
            value: mode,
            label: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
          ),
      ],
      selected: {mode},
      // Three segments on a phone: the tint says which, the tick would
      // squeeze the labels out ("Semaine" in French).
      showSelectedIcon: desktop,
      onSelectionChanged: (modes) => onMode?.call(modes.single),
    );
    // Desktop in 3 days shows a week: its arrows turn weeks.
    void turn(int delta) {
      if (mode != selection.mode) onMode?.call(mode);
      onShift(delta);
    }

    final todayButton = TextButton(
      onPressed: onToday,
      child: Text(l10n.calendarToday),
    );
    final previous = IconButton(
      onPressed: () => turn(-1),
      tooltip: switch (mode) {
        CalendarMode.month => l10n.calendarPreviousMonth,
        CalendarMode.threeDays => l10n.calendarPreviousDays,
        CalendarMode.week => l10n.calendarPreviousWeek,
      },
      icon: const Icon(Icons.chevron_left_rounded),
    );
    final next = IconButton(
      onPressed: () => turn(1),
      tooltip: switch (mode) {
        CalendarMode.month => l10n.calendarNextMonth,
        CalendarMode.threeDays => l10n.calendarNextDays,
        CalendarMode.week => l10n.calendarNextWeek,
      },
      icon: const Icon(Icons.chevron_right_rounded),
    );
    Widget titleButton(TextStyle? style) => Expanded(
      child: Align(
        alignment: AlignmentDirectional.centerStart,
        child: _TitleButton(
          title: title,
          semantics: switch (mode) {
            CalendarMode.month => l10n.calendarChooseMonth(selection.month),
            CalendarMode.threeDays => l10n.calendarChooseDay(title),
            CalendarMode.week => l10n.calendarChooseWeek(title),
          },
          style: style,
          onTap: onPickTitle,
        ),
      ),
    );

    if (desktop) {
      return _Latest(
        view: this,
        builder: (context, latest) =>
            _desktop(context, latest, mode, days, firstDay, [
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
    return _Latest(
      view: this,
      builder: (context, latest) => Scaffold(
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
              // On its side the phone has no room to hold the calendar
              // still: everything scrolls, and a curved swipe can still miss.
              final pinned = box.maxHeight >= _pinnedMinHeight;
              const sides = EdgeInsets.symmetric(horizontal: AppSpacing.md);
              const bottom = _fabClearance;
              Widget scrolling(EdgeInsets padding, List<Widget> children) =>
                  _refreshable(
                    ListView(
                      // Pull to refresh works on a short list too.
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: padding,
                      children: children,
                    ),
                  );
              final top = [
                header,
                const SizedBox(height: AppSpacing.sm),
                switcher,
                const SizedBox(height: AppSpacing.md),
              ];
              if (mode != CalendarMode.month) {
                final grids = _SwipePager(
                  key: ValueKey(mode),
                  anchor: days.first,
                  onShift: onShift,
                  builder: (delta) => _grid(
                    context,
                    latest,
                    mode,
                    firstDay,
                    delta,
                    scrolls: pinned,
                  ),
                );
                final waiting = eventsNotLoaded(context, events, onRetry);
                if (!pinned) {
                  return scrolling(
                    sides.copyWith(top: AppSpacing.sm, bottom: bottom),
                    [...top, ?waiting, grids],
                  );
                }
                // The hours scroll inside the grid, and pull to refresh at
                // its top; a sideways drag is the pager's (#357).
                return Padding(
                  padding: sides.copyWith(top: AppSpacing.sm),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      ...top,
                      ?waiting,
                      Expanded(
                        child: _refreshable(
                          ScrollConfiguration(
                            behavior: ScrollConfiguration.of(context).copyWith(
                              physics: AlwaysScrollableScrollPhysics(
                                parent: ScrollConfiguration.of(context)
                                    .getScrollPhysics(context),
                              ),
                            ),
                            child: grids,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }
              final counts = eventsPerDay(events.value ?? const []);
              final taskCounts = openTasksPerDay(tasks);
              final pager = _SwipePager(
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
              final below = FadeSwap(
                duration: AppMotion.medium,
                // The month's selected day: another day, another list.
                child: KeyedSubtree(
                  key: ValueKey(selection.day),
                  child: DaySection(
                    now: now,
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
                    timeline: true,
                  ),
                ),
              );
              if (!pinned) {
                return scrolling(
                  sides.copyWith(top: AppSpacing.sm, bottom: bottom),
                  [...top, pager, const Divider(height: AppSpacing.xl), below],
                );
              }
              // Held still, the month has no vertical drag to lose a swipe
              // to (#369); only the list below scrolls and pulls.
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: sides.copyWith(top: AppSpacing.sm),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [...top, pager],
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
      ),
    );
  }

  /// The phone's 3 days or week (#448), [delta] pages from the selection's:
  /// an hour grid whose day headers and strip open the day's sheet. Pinned
  /// ([scrolls]), the hours scroll in it; on its side the page scrolls them.
  Widget _grid(
    BuildContext context,
    ValueNotifier<CalendarView> latest,
    CalendarMode mode,
    int firstDay,
    int delta, {
    required bool scrolls,
  }) {
    final three = mode == CalendarMode.threeDays;
    final start = shownDays(selection, firstDay).first;
    final days = three
        ? [
            for (var i = 0; i < 3; i++)
              DateTime(start.year, start.month, start.day + 3 * delta + i),
          ]
        : weekDays(
            DateTime(start.year, start.month, start.day + 7 * delta),
            firstDay,
          );
    final list = events.value ?? const <CalendarEvent>[];
    void openDay(DateTime day) {
      onSelect(day);
      unawaited(showDaySheet(context, latest: latest, day: day));
    }

    return WeekGrid(
      // Opened at its own minute: a new page reads it again.
      key: ValueKey((mode, days.first)),
      days: days,
      events: list,
      // The neighbour sliding in already shows the day it will select.
      selected: delta == 0
          ? selection.day
          : shiftedDay(selection, delta, today, firstDay),
      today: today,
      now: now,
      onOpen: onOpen,
      tasks: tasks,
      onOpenTask: onOpenTask,
      onStripTask: (task) => openDay(task.dueOn),
      onDay: (day, _) => openDay(day),
      onSelect: onSelect,
      people: people,
      compact: true,
      focus: !three,
      gutter: _phoneGutter,
      minHour: _phoneMinHour,
      hourHeight: !scrolls
          ? _sideHour
          : three
          ? _threeDaysHour
          : null,
      scrolls: scrolls,
      scrollToMinute: scrolls ? _opensAt(days, list) : null,
      // Week fits its height; the 3 days' hours scroll past the button.
      bottomInset: scrolls && three ? _fabClearance : 0,
    );
  }

  /// Where a page of the grid opens, as a minute of the day it shows an
  /// hour before: now on a page holding today, else its earliest event's
  /// start; null (the top) when it has neither.
  int? _opensAt(List<DateTime> days, List<CalendarEvent> list) {
    final at = now?.toLocal();
    if (at != null && days.contains(today)) return at.hour * 60 + at.minute;
    final starts = [
      for (final event in list)
        if (days.contains(event.day)) startMinute(event),
    ];
    return starts.isEmpty ? null : starts.reduce(math.min);
  }

  /// Under the last row of a list or of the 3 days' hours: clear of the
  /// add button.
  static const double _fabClearance = AppSpacing.xxxl + AppSpacing.lg;

  /// The phone grid's hour labels ("8 AM") and its least hour height.
  static const double _phoneGutter = 32;
  static const double _phoneMinHour = 28;

  /// 3 days: a fixed hour, the hours scroll (Figma A).
  static const double _threeDaysHour = 52;

  /// A phone on its side: the whole grid scrolls with the page.
  static const double _sideHour = 40;

  /// Below this height (a phone on its side) the calendar scrolls with the
  /// list instead of staying put above it: a six-week month, the header and
  /// the switch take about 420 px. ponytail: a fixed cut, not a measure.
  static const double _pinnedMinHeight = 560;

  /// Desktop (#366): one header row, then the month or the week filling
  /// the window; an open event's pane beside it.
  Widget _desktop(
    BuildContext context,
    ValueNotifier<CalendarView> latest,
    CalendarMode mode,
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
          builder: (popover) => _LatestDay(latest: latest, day: day),
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
                      child: mode == CalendarMode.week
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

/// The phone's day (#448), the desktop popover's counterpart: a modal
/// bottom sheet holding [day] as a timeline, its tasks and people. Dragged
/// down or tapped outside, it closes; what it opens, it closes first.
Future<void> showDaySheet(
  BuildContext context, {
  required ValueNotifier<CalendarView> latest,
  required DateTime day,
}) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  showDragHandle: true,
  useSafeArea: true,
  builder: (_) => SingleChildScrollView(
    padding: const EdgeInsets.fromLTRB(
      AppSpacing.md,
      0,
      AppSpacing.md,
      AppSpacing.lg,
    ),
    child: _LatestDay(latest: latest, day: day, sheet: true),
  ),
);

/// [day]'s [DaySection] in a route of its own (the desktop popover, the
/// phone's sheet), from the view's latest build so a ticked task crosses out
/// in place. What leaves the day closes the route first; the ring, with no
/// Undo, keeps it open.
class _LatestDay extends StatelessWidget {
  const _LatestDay({
    required this.latest,
    required this.day,
    this.sheet = false,
  });

  final ValueNotifier<CalendarView> latest;
  final DateTime day;

  /// The phone's sheet: a timeline, the people folded.
  final bool sheet;

  @override
  Widget build(BuildContext context) {
    void Function(T) closing<T>(void Function(T) then) => (value) {
      Navigator.pop(context);
      then(value);
    };
    return ValueListenableBuilder(
      valueListenable: latest,
      builder: (_, view, _) => DaySection(
        now: view.now,
        events: view.events,
        tasks: view.tasks,
        busy: view.busy,
        day: day,
        onOpen: closing(view.onOpen),
        onToggleTask: view.onToggleTaskQuiet ?? view.onToggleTask,
        onOpenTask: closing(view.onOpenTask),
        onAdd: closing(view.onAdd),
        onAddTask: closing(view.onAddTask),
        onRetry: view.onRetry,
        people: view.people,
        model: view.model,
        peopleFoldable: sheet,
        timeline: sheet,
        onOpenPerson: closing((Person p) => view.onOpenPerson?.call(p)),
      ),
    );
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

/// A page of the calendar (a month grid, an hour grid) at [anchor], which
/// follows the finger: dragged sideways, the neighbouring page comes in
/// beside it, and on release the page turns (past halfway, or flung) or
/// springs back. The arrows and Today slide the new page in from its side
/// too. Reduce motion: they just switch.
class _SwipePager extends StatefulWidget {
  const _SwipePager({
    required this.anchor,
    required this.onShift,
    required this.builder,
    super.key,
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
                      // A page given its height (the phone's grid) gets it
                      // too.
                      if (at != 0)
                        Positioned(
                          top: 0,
                          left: 0,
                          right: 0,
                          bottom: constraints.hasBoundedHeight ? 0 : null,
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
class DaySection extends StatefulWidget {
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
    this.timeline = false,
    this.now,
    super.key,
  });

  /// Events over by it step back (#451).
  final DateTime? now;

  final AsyncValue<List<CalendarEvent>> events;

  /// Every task; those due on [day] show above its events.
  final List<Task> tasks;

  /// Who is due when: [day]'s people show between its tasks and events.
  final PeopleAhead people;
  final BusinessModel model;
  final void Function(Person person)? onOpenPerson;

  /// False in the desktop popover: the people always show.
  final bool peopleFoldable;

  /// True on mobile/tablet: events as a timeline with free time gaps.
  final bool timeline;

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
  State<DaySection> createState() => _DaySectionState();
}

class _DaySectionState extends State<DaySection> {
  final _peopleKey = GlobalKey<PeopleBlockState>();

  List<Widget> _timelineRows(
    BuildContext context,
    List<CalendarEvent> events,
    DateTime day,
  ) {
    final localNow = widget.now?.toLocal();
    final isToday =
        localNow != null &&
        day.year == localNow.year &&
        day.month == localNow.month &&
        day.day == localNow.day;
    final nowMinute = isToday ? localNow.hour * 60 + localNow.minute : null;
    final rows = dayTimeline(events, nowMinute: nowMinute);
    final peopleCount = widget.people.count(day);

    return [
      for (final row in rows)
        switch (row) {
          TimelineEvent(:final event) => EventRow(
            key: ValueKey('event:${event.id}'),
            event: event,
            now: widget.now,
            onTap: () => widget.onOpen(event),
          ),
          TimelineGap(:final start, :final end, :final untilOnly) => _GapRow(
            key: untilOnly
                ? ValueKey('gap:$end:until')
                : ValueKey('gap:$start:$end'),
            start: start,
            end: end,
            untilOnly: untilOnly,
            showPeople: untilOnly && isToday && peopleCount > 0,
            peopleCount: peopleCount,
            onTapPeople: () {
              _peopleKey.currentState?.unfold();
              if (_peopleKey.currentContext != null) {
                Scrollable.ensureVisible(
                  _peopleKey.currentContext!,
                  duration: context.motion(AppMotion.medium),
                );
              }
            },
          ),
          TimelineNow(:final minute) => _NowRow(
            key: const ValueKey('now'),
            minute: minute,
          ),
        },
    ];
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    // `.value` survives a failed refresh, so the rows stay on screen.
    final list = widget.events.value;
    final List<Widget> body;
    if (list == null) {
      body = [?eventsNotLoaded(context, widget.events, widget.onRetry)];
    } else {
      final onDay = <Widget>[
        for (final task in tasksOn(widget.tasks, widget.day))
          TaskRow(
            key: ValueKey('task:${task.id}'),
            task: task,
            busy: widget.busy.contains(task.key),
            onOpen: () => widget.onOpenTask?.call(task),
            onToggle: () => widget.onToggleTask?.call(task),
          ),
        if (widget.people.on(widget.day) case final due when due.isNotEmpty)
          PeopleBlock(
            key: widget.timeline && widget.peopleFoldable
                ? _peopleKey
                : ValueKey(widget.day),
            people: due,
            model: widget.model,
            foldable: widget.peopleFoldable,
            onOpen: (person) => widget.onOpenPerson?.call(person),
          ),
        if (widget.timeline)
          ..._timelineRows(context, eventsOn(list, widget.day), widget.day)
        else
          for (final event in eventsOn(list, widget.day))
            EventRow(
              key: ValueKey('event:${event.id}'),
              event: event,
              now: widget.now,
              onTap: () => widget.onOpen(event),
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
                key: ValueKey(('rows', widget.day)),
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
            title: l10n.calendarDayTitle(widget.day),
            actionLabel: l10n.calendarAdd,
            onAction: switch (widget.onAddTask) {
              final onTask? => () => unawaited(
                chooseAdd(
                  header,
                  day: widget.day,
                  onEvent: widget.onAdd,
                  onTask: onTask,
                ),
              ),
              null => () => widget.onAdd(widget.day),
            },
          ),
        ),
        const SizedBox(height: AppSpacing.ms),
        ...body,
      ],
    );
  }
}

class _GapRow extends StatelessWidget {
  const _GapRow({
    required this.start,
    required this.end,
    required this.untilOnly,
    required this.showPeople,
    required this.peopleCount,
    required this.onTapPeople,
    super.key,
  });

  static const double _minButtonHeight = 48;

  final int start;
  final int end;
  final bool untilOnly;
  final bool showPeople;
  final int peopleCount;
  final VoidCallback onTapPeople;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final colors = LoomiaColors.of(context);
    final duration = end - start;
    final hours = duration ~/ 60;
    final minutes = duration % 60;

    String durationLabel;
    if (minutes == 0) {
      durationLabel = l10n.calendarHours(hours);
    } else {
      durationLabel = l10n.calendarHoursMinutes(
        hours,
        minutes.toString().padLeft(2, '0'),
      );
    }

    String gapText;
    if (untilOnly) {
      final endTime = DateTime(2026, 1, 1, end ~/ 60, end % 60);
      gapText = l10n.calendarFreeUntil(timeLabel(context, endTime));
    } else {
      gapText = l10n.calendarFree(durationLabel);
    }

    return Padding(
      padding: const EdgeInsetsDirectional.only(
        start: EventRow.timeWidth + AppSpacing.ms,
      ),
      child: CustomPaint(
        painter: _DashedBorderPainter(
          color: colors.borderStrong,
          radius: AppRadii.md,
        ),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.ms),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                gapText,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: colors.textMuted,
                ),
              ),
              if (showPeople) ...[
                const SizedBox(height: AppSpacing.xs),
                Semantics(
                  button: true,
                  label: l10n.calendarPeopleToFollowUp(peopleCount),
                  child: InkWell(
                    onTap: onTapPeople,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(
                        minHeight: _minButtonHeight,
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          vertical: AppSpacing.xs,
                        ),
                        child: Text(
                          l10n.calendarPeopleToFollowUp(peopleCount),
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: colors.primaryText,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _DashedBorderPainter extends CustomPainter {
  const _DashedBorderPainter({required this.color, required this.radius});

  static const double _strokeWidth = 1.0;
  static const double _dashWidth = 4.0;
  static const double _dashSpace = 4.0;

  final Color color;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = _strokeWidth;
    final rrect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Radius.circular(radius),
    );

    final path = Path()..addRRect(rrect);
    final pathMetrics = path.computeMetrics();

    for (final metric in pathMetrics) {
      var distance = 0.0;
      while (distance < metric.length) {
        final start = metric.getTangentForOffset(distance)!.position;
        distance += _dashWidth;
        final end = metric.getTangentForOffset(distance)!.position;
        canvas.drawLine(start, end, paint);
        distance += _dashSpace;
      }
    }
  }

  @override
  bool shouldRepaint(_DashedBorderPainter oldDelegate) =>
      color != oldDelegate.color || radius != oldDelegate.radius;
}

class _NowRow extends StatelessWidget {
  const _NowRow({required this.minute, super.key});

  static const double _nowDot = 8;
  static const double _nowLine = 2;

  final int minute;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = LoomiaColors.of(context);
    final time = DateTime(2026, 1, 1, minute ~/ 60, minute % 60);

    return Row(
      children: [
        SizedBox(
          width: EventRow.timeWidth,
          child: Text(
            timeLabel(context, time),
            style: theme.textTheme.labelSmall?.copyWith(
              color: colors.primaryText,
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.ms),
        Expanded(
          child: Row(
            children: [
              Container(
                width: _nowDot,
                height: _nowDot,
                decoration: BoxDecoration(
                  color: colors.primaryText,
                  shape: BoxShape.circle,
                ),
              ),
              Expanded(
                child: Container(height: _nowLine, color: colors.primaryText),
              ),
            ],
          ),
        ),
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

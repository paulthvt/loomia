import 'dart:math' as math;

import 'package:intl/intl.dart';
import 'package:loomia/app/theme/app_colors.dart';
import 'package:loomia/app/theme/app_spacing.dart';
import 'package:loomia/app/theme/app_theme.dart';
import 'package:loomia/app/theme/app_typography.dart';
import 'package:loomia/features/calendar/domain/calendar_event.dart';
import 'package:loomia/features/calendar/domain/people_ahead.dart';
import 'package:loomia/features/calendar/domain/week_grid.dart';
import 'package:loomia/features/calendar/presentation/event_row.dart';
import 'package:loomia/features/calendar/presentation/month_grid.dart';
import 'package:loomia/features/tasks/domain/task.dart';
import 'package:loomia/l10n/app_localizations.dart';
import 'package:material_ui/material_ui.dart';

/// Opens a day's popover, [anchor] being where it hangs from, in global
/// coordinates.
typedef OpenDay = void Function(DateTime day, Rect anchor);

/// [context]'s box, in global coordinates.
Rect _globalRect(BuildContext context) {
  final box = context.findRenderObject()! as RenderBox;
  return box.localToGlobal(Offset.zero) & box.size;
}

/// The height [text] takes in [style] at [width], up to [maxLines], at the
/// device's text scale.
double _textHeight(
  BuildContext context,
  String text,
  TextStyle? style,
  double width, {
  int maxLines = 1,
}) {
  final painter = TextPainter(
    text: TextSpan(text: text, style: style),
    textDirection: Directionality.of(context),
    textScaler: MediaQuery.textScalerOf(context),
    maxLines: maxLines,
    ellipsis: '…',
  )..layout(maxWidth: math.max(width, 0));
  final height = painter.height;
  painter.dispose();
  return height;
}

/// One line of [style] at the device's text scale.
double _lineHeight(BuildContext context, TextStyle style) =>
    MediaQuery.textScalerOf(context).scale(style.fontSize ?? 14) *
    (style.height ?? 1);

/// The desktop month and week's frame: one bordered card.
class _Board extends StatelessWidget {
  const _Board({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colors = LoomiaColors.of(context);
    return Material(
      color: colors.surfaceDefault,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadii.lg),
        side: BorderSide(color: colors.borderSubtle),
      ),
      clipBehavior: Clip.antiAlias,
      child: child,
    );
  }
}

/// Desktop month (Figma "Month B"): the weeks fill the card, ruled, each day
/// listing its tasks, then its events. A day opens its popover; an event
/// or a task opens itself.
class DesktopMonth extends StatelessWidget {
  const DesktopMonth({
    required this.month,
    required this.days,
    required this.events,
    required this.selected,
    required this.today,
    required this.onOpen,
    required this.onDay,
    this.tasks = const [],
    this.onOpenTask,
    this.people = const PeopleAhead.none(),
    super.key,
  });

  /// The 1st of the month shown.
  final DateTime month;

  /// Whole weeks, as `monthDays`.
  final List<DateTime> days;
  final List<CalendarEvent> events;

  /// Every task; each shows on its due day, done ones struck through.
  final List<Task> tasks;

  /// Who is due when (#378): "N people" at the top of a day.
  final PeopleAhead people;
  final DateTime selected;
  final DateTime today;
  final void Function(CalendarEvent event) onOpen;
  final void Function(Task task)? onOpenTask;
  final OpenDay onDay;

  @override
  Widget build(BuildContext context) {
    final colors = LoomiaColors.of(context);
    final weekday = DateFormat.E(Localizations.localeOf(context).toString());
    final byDay = <DateTime, List<CalendarEvent>>{};
    for (final event in byStart(events)) {
      (byDay[event.day] ??= []).add(event);
    }
    const week = DateTime.daysPerWeek;
    return _Board(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Each day says its full date already.
          ExcludeSemantics(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
              child: Row(
                children: [
                  for (final day in days.take(week))
                    Expanded(
                      child: Text(
                        weekday.format(day).toUpperCase(),
                        textAlign: TextAlign.center,
                        style: AppTypography.overline.copyWith(
                          color: colors.textMuted,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          for (var start = 0; start < days.length; start += week)
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final (index, day)
                      in days.sublist(start, start + week).indexed)
                    Expanded(
                      child: _MonthCell(
                        day: day,
                        first: index == 0,
                        inMonth: day.month == month.month,
                        selected: day == selected,
                        today: day == today,
                        events: byDay[day] ?? const [],
                        tasks: tasksOn(tasks, day),
                        people: people.count(day),
                        onOpen: onOpen,
                        onOpenTask: onOpenTask,
                        onDay: onDay,
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// A day of [DesktopMonth]: its number (a filled badge today), then as many
/// of its tasks and events as fit, tasks first, then "+N more". Tinted when selected, sunken when
/// it belongs to the month before or after.
class _MonthCell extends StatelessWidget {
  const _MonthCell({
    required this.day,
    required this.first,
    required this.inMonth,
    required this.selected,
    required this.today,
    required this.events,
    required this.tasks,
    required this.onOpen,
    required this.onOpenTask,
    required this.onDay,
    this.people = 0,
  });

  static const double _badge = 26;
  static const double _gap = 2;

  final DateTime day;

  /// The week's first day: no rule on its start side, the card has one.
  final bool first;
  final bool inMonth;
  final bool selected;
  final bool today;
  final List<CalendarEvent> events;

  /// The day's tasks, open first.
  final List<Task> tasks;

  /// People due that day (#378): the first line, counted in "+N more".
  final int people;
  final void Function(CalendarEvent event) onOpen;
  final void Function(Task task)? onOpenTask;
  final OpenDay onDay;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final colors = LoomiaColors.of(context);
    final l10n = AppLocalizations.of(context);
    final chips = <(double Function(double width), Widget)>[
      if (people > 0)
        (
          (width) => CalendarPeopleLine.heightFor(context, people, width),
          // The day's label says it already.
          ExcludeSemantics(child: CalendarPeopleLine(count: people)),
        ),
      for (final task in tasks)
        (
          (width) => MonthTaskChip.heightFor(context, task, width),
          MonthTaskChip(task: task, onTap: () => onOpenTask?.call(task)),
        ),
      for (final event in events)
        (
          (width) => MonthEventChip.heightFor(context, event, width),
          MonthEventChip(event: event, onTap: () => onOpen(event)),
        ),
    ];
    final rule = BorderSide(color: colors.borderSubtle);
    final more = theme.textTheme.labelSmall?.copyWith(
      color: colors.primaryText,
    );
    final number = today
        ? theme.textTheme.labelMedium?.copyWith(color: scheme.onPrimary)
        : theme.textTheme.bodySmall?.copyWith(
            color: inMonth ? scheme.onSurface : colors.textMuted,
          );

    return Material(
      color: selected
          ? scheme.primaryContainer
          : inMonth
          ? Colors.transparent
          : colors.surfaceSunken,
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: BorderDirectional(
            top: rule,
            start: first ? BorderSide.none : rule,
          ),
        ),
        child: Semantics(
          container: true,
          button: true,
          selected: selected,
          label: daySemantics(
            l10n,
            day,
            events.length,
            tasks.where((task) => !task.done).length,
            people,
          ),
          child: InkWell(
            onTap: () => onDay(day, _globalRect(context)),
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.xs),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                spacing: _gap,
                children: [
                  ExcludeSemantics(
                    child: Center(
                      child: Container(
                        width: _badge,
                        height: _badge,
                        alignment: Alignment.center,
                        decoration: today
                            ? BoxDecoration(
                                color: scheme.primary,
                                shape: BoxShape.circle,
                              )
                            : null,
                        child: Text('${day.day}', style: number),
                      ),
                    ),
                  ),
                  Expanded(
                    child: LayoutBuilder(
                      builder: (context, box) {
                        final heights = [
                          for (final (height, _) in chips)
                            height(box.maxWidth) + _gap,
                        ];
                        final shown = chipsThatFit(
                          heights,
                          _lineHeight(context, more ?? AppTypography.caption),
                          box.maxHeight,
                        );
                        // Measured to fit; the clip only absorbs rounding.
                        return ClipRect(
                          child: OverflowBox(
                            alignment: Alignment.topCenter,
                            maxHeight: double.infinity,
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              spacing: _gap,
                              children: [
                                for (final (_, chip) in chips.take(shown)) chip,
                                if (shown < chips.length)
                                  ExcludeSemantics(
                                    child: Text(
                                      l10n.calendarMoreEvents(
                                        chips.length - shown,
                                      ),
                                      style: more,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// An event inside a desktop month day (Figma `MonthEventChip`): a bar, its
/// start time, its title on up to two lines. Done: greyed.
class MonthEventChip extends StatelessWidget {
  const MonthEventChip({required this.event, required this.onTap, super.key});

  static const double _bar = 2;
  static const double _vertical = 3;
  static const int _titleLines = 2;

  final CalendarEvent event;
  final VoidCallback onTap;

  static TextStyle? _timeStyle(BuildContext context) =>
      Theme.of(context).textTheme.labelSmall;

  static TextStyle? _titleStyle(BuildContext context) =>
      Theme.of(context).textTheme.labelSmall
          ?.copyWith(fontWeight: FontWeight.w700);

  /// The height a chip for [event] takes at [width].
  static double heightFor(
    BuildContext context,
    CalendarEvent event,
    double width,
  ) {
    final text = width - _bar - AppSpacing.sm - AppSpacing.xs;
    return 2 * _vertical +
        _textHeight(
          context,
          timeLabel(context, event.startsAt),
          _timeStyle(context),
          text,
        ) +
        _textHeight(
          context,
          event.title,
          _titleStyle(context),
          text,
          maxLines: _titleLines,
        );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final colors = LoomiaColors.of(context);
    final done = event.done;
    return MergeSemantics(
      child: Semantics(
        button: true,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadii.sm),
          child: Padding(
            padding: const EdgeInsetsDirectional.only(
              top: _vertical,
              bottom: _vertical,
              end: AppSpacing.xs,
            ),
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                spacing: AppSpacing.sm,
                children: [
                  DecoratedBox(
                    decoration: BoxDecoration(
                      color: done ? colors.textMuted : scheme.primary,
                      borderRadius: BorderRadius.circular(AppRadii.pill),
                    ),
                    child: const SizedBox(width: _bar),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          timeLabel(context, event.startsAt),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: _timeStyle(context),
                        ),
                        Text(
                          event.title,
                          maxLines: _titleLines,
                          overflow: TextOverflow.ellipsis,
                          style: _titleStyle(context)?.copyWith(
                            color: done
                                ? scheme.onSurfaceVariant
                                : scheme.onSurface,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// "5 people" at the top of a desktop month day or in the desktop week's
/// strip (#378, Figma "CalendarPeopleLine"): muted, no ring, no bar,
/// quieter than a task or an event. [onTap] opens the day; in a month cell
/// the cell takes the tap.
class CalendarPeopleLine extends StatelessWidget {
  const CalendarPeopleLine({required this.count, this.onTap, super.key});

  static const double _vertical = 3;

  final int count;
  final VoidCallback? onTap;

  static TextStyle? _style(BuildContext context) =>
      Theme.of(context).textTheme.labelSmall
          ?.copyWith(color: LoomiaColors.of(context).textMuted);

  /// The height the line takes at [width].
  static double heightFor(BuildContext context, int count, double width) =>
      2 * _vertical +
      _textHeight(
        context,
        AppLocalizations.of(context).calendarPeopleLine(count),
        _style(context),
        width - 2 * AppSpacing.xs,
      );

  @override
  Widget build(BuildContext context) {
    final line = Padding(
      padding: const EdgeInsets.symmetric(
        vertical: _vertical,
        horizontal: AppSpacing.xs,
      ),
      child: Text(
        AppLocalizations.of(context).calendarPeopleLine(count),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: _style(context),
      ),
    );
    final tap = onTap;
    return tap == null
        ? line
        : InkWell(
            onTap: tap,
            borderRadius: BorderRadius.circular(AppRadii.sm),
            child: line,
          );
  }
}

/// A task inside a desktop month day or the desktop week's strip, sized and
/// set as [MonthEventChip]: a hollow ring (the mobile month's hollow dot),
/// its title on one line. Done: struck through and muted.
class MonthTaskChip extends StatelessWidget {
  const MonthTaskChip({
    required this.task,
    required this.onTap,
    this.showTime = true,
    super.key,
  });

  static const double _ring = 6;
  static const double _stroke = 1.5;
  static const double _vertical = MonthEventChip._vertical;

  final Task task;
  final VoidCallback onTap;

  /// Before the title of a timed task (#377): "14:00 · Call the supplier".
  /// Off on the week's hour grid, where the block's place says it.
  final bool showTime;

  static TextStyle? _titleStyle(BuildContext context) =>
      MonthEventChip._titleStyle(context);

  static String _label(BuildContext context, Task task, bool showTime) =>
      switch (task.dueTime) {
        final time? when showTime =>
          AppLocalizations.of(context).calendarShortEvent(
            timeLabel(context, DateTime(2000, 1, 1, time.hour, time.minute)),
            task.title,
          ),
        _ => task.title,
      };

  /// The height a chip for [task] takes at [width]: one line.
  static double heightFor(BuildContext context, Task task, double width) =>
      2 * _vertical +
      _textHeight(
        context,
        _label(context, task, true),
        _titleStyle(context),
        width - _ring - AppSpacing.sm - AppSpacing.xs,
      );

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final colors = LoomiaColors.of(context);
    final done = task.done;
    return MergeSemantics(
      child: Semantics(
        button: true,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadii.sm),
          child: Padding(
            padding: const EdgeInsetsDirectional.only(
              top: _vertical,
              bottom: _vertical,
              end: AppSpacing.xs,
            ),
            child: Row(
              spacing: AppSpacing.sm,
              children: [
                Container(
                  width: _ring,
                  height: _ring,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: done ? colors.textMuted : scheme.primary,
                      width: _stroke,
                    ),
                  ),
                ),
                Expanded(
                  child: Text(
                    _label(context, task, showTime),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: _titleStyle(context)?.copyWith(
                      color: done ? colors.textMuted : scheme.onSurface,
                      decoration: done ? TextDecoration.lineThrough : null,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Desktop week (Figma "Week B"): the 7 days on an hour grid, events placed
/// at their start and as tall as they last, overlapping ones side by side.
/// The selected column is tinted, today's has a line at [now]. A week with
/// tasks has a strip under the headings: each day's, as in the month.
class WeekGrid extends StatelessWidget {
  const WeekGrid({
    required this.days,
    required this.events,
    required this.selected,
    required this.today,
    required this.onOpen,
    required this.onDay,
    this.tasks = const [],
    this.onOpenTask,
    this.now,
    this.people = const PeopleAhead.none(),
    super.key,
  });

  /// Wider than the Figma's 56: "10:00 AM" in 12-hour locales.
  static const double _gutter = 72;

  /// Below this an hour gets, the grid scrolls instead of shrinking.
  static const double _minHour = 40;

  /// The most of the window the task strip takes; past it, it scrolls.
  static const double _maxStrip = 1 / 3;

  /// The week's 7 days, as `weekDays`.
  final List<DateTime> days;
  final List<CalendarEvent> events;

  /// Every task; each shows on its due day, done ones struck through.
  final List<Task> tasks;
  final void Function(Task task)? onOpenTask;
  final DateTime selected;
  final DateTime today;

  /// Where the now line goes; none without it.
  final DateTime? now;

  /// Who is due when (#378): "N people" in the strip, above the tasks.
  final PeopleAhead people;
  final void Function(CalendarEvent event) onOpen;
  final OpenDay onDay;

  @override
  Widget build(BuildContext context) {
    final colors = LoomiaColors.of(context);
    final week = [
      for (final event in events)
        if (days.contains(event.day)) event,
    ];
    final weekTasks = [for (final day in days) tasksOn(tasks, day)];
    // A timed task goes on the hour grid (#377); the strip keeps the rest.
    final untimed = [
      for (final day in weekTasks) [...day.where((t) => t.dueTime == null)],
    ];
    final timed = [
      for (final day in weekTasks) [...day.where((t) => t.dueTime != null)],
    ];
    final due = [for (final day in days) people.count(day)];
    final range = hourRange(week, [
      for (final day in timed)
        for (final task in day) taskSpan(task.dueTime!),
    ]);
    final hours = range.last - range.first;
    final hourStyle = Theme.of(context).textTheme.labelSmall
        ?.copyWith(color: colors.textMuted);
    return _Board(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
            child: Row(
              children: [
                const SizedBox(width: _gutter),
                for (final (index, day) in days.indexed)
                  Expanded(
                    child: _ColumnHeader(
                      day: day,
                      selected: day == selected,
                      today: day == today,
                      count: eventsOn(week, day).length,
                      open: weekTasks[index].where((t) => !t.done).length,
                      people: due[index],
                      onDay: onDay,
                    ),
                  ),
              ],
            ),
          ),
          if (untimed.any((day) => day.isNotEmpty) || due.any((n) => n > 0))
            ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.sizeOf(context).height * _maxStrip,
              ),
              child: SingleChildScrollView(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(width: _gutter),
                    for (final (index, day) in untimed.indexed)
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.xs,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            spacing: _MonthCell._gap,
                            children: [
                              if (due[index] > 0)
                                Builder(
                                  builder: (line) => CalendarPeopleLine(
                                    count: due[index],
                                    onTap: () =>
                                        onDay(days[index], _globalRect(line)),
                                  ),
                                ),
                              for (final task in day)
                                MonthTaskChip(
                                  task: task,
                                  onTap: () => onOpenTask?.call(task),
                                ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          Expanded(
            child: DecoratedBox(
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: colors.borderSubtle)),
              ),
              child: LayoutBuilder(
                builder: (context, box) {
                  final hour = math.max(_minHour, box.maxHeight / hours);
                  return SingleChildScrollView(
                    child: SizedBox(
                      height: hour * hours,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          SizedBox(
                            width: _gutter,
                            child: ExcludeSemantics(
                              child: Stack(
                                children: [
                                  for (var h = range.first; h < range.last; h++)
                                    PositionedDirectional(
                                      top: (h - range.first) * hour,
                                      end: AppSpacing.sm,
                                      child: Padding(
                                        padding: const EdgeInsets.only(
                                          top: AppSpacing.xs,
                                        ),
                                        child: Text(
                                          timeLabel(
                                            context,
                                            DateTime(2000, 1, 1, h),
                                          ),
                                          style: hourStyle,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                          for (final (index, day) in days.indexed)
                            Expanded(
                              child: _DayColumn(
                                day: day,
                                events: eventsOn(week, day),
                                tasks: timed[index],
                                onOpenTask: onOpenTask,
                                firstHour: range.first,
                                hours: hours,
                                hour: hour,
                                selected: day == selected,
                                now: day == today ? now : null,
                                onOpen: onOpen,
                                onDay: onDay,
                              ),
                            ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A desktop week column's heading: weekday, then the date in a circle,
/// ringed today. Opens the day's popover.
class _ColumnHeader extends StatelessWidget {
  const _ColumnHeader({
    required this.day,
    required this.selected,
    required this.today,
    required this.count,
    required this.open,
    required this.onDay,
    this.people = 0,
  });

  static const double _circle = 36;
  static const double _ring = 1.5;

  final DateTime day;
  final bool selected;
  final bool today;
  final int count;

  /// Open tasks due that day.
  final int open;

  /// People due that day (#378).
  final int people;
  final OpenDay onDay;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final colors = LoomiaColors.of(context);
    final weekday = DateFormat.E(Localizations.localeOf(context).toString());
    return Semantics(
      button: true,
      selected: selected,
      label: daySemantics(
        AppLocalizations.of(context),
        day,
        count,
        open,
        people,
      ),
      excludeSemantics: true,
      child: InkWell(
        onTap: () => onDay(day, _globalRect(context)),
        borderRadius: BorderRadius.circular(AppRadii.md),
        child: Column(
          spacing: AppSpacing.xs,
          children: [
            Text(
              weekday.format(day),
              style: theme.textTheme.labelSmall?.copyWith(
                color: colors.textMuted,
              ),
            ),
            Container(
              width: _circle,
              height: _circle,
              alignment: Alignment.center,
              decoration: today
                  ? BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: scheme.primary, width: _ring),
                    )
                  : null,
              child: Text(
                '${day.day}',
                style: today
                    ? theme.textTheme.labelLarge?.copyWith(
                        color: colors.primaryText,
                      )
                    : theme.textTheme.bodyMedium?.copyWith(
                        color: scheme.onSurface,
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// One day of [WeekGrid]: hour rules, its events placed by time, the now
/// line. Anywhere but an event opens the day's popover, hung from the top.
class _DayColumn extends StatelessWidget {
  const _DayColumn({
    required this.day,
    required this.events,
    required this.tasks,
    required this.onOpenTask,
    required this.firstHour,
    required this.hours,
    required this.hour,
    required this.selected,
    required this.now,
    required this.onOpen,
    required this.onDay,
  });

  /// Between a card and its column's edges, and between lanes.
  static const double _inset = 3;
  static const double _nowLine = 2;
  static const double _nowDot = 8;

  final DateTime day;
  final List<CalendarEvent> events;

  /// The day's timed tasks (#377), each a [taskBlock] at its time.
  final List<Task> tasks;
  final void Function(Task task)? onOpenTask;
  final int firstHour;
  final int hours;

  /// One hour's height.
  final double hour;
  final bool selected;
  final DateTime? now;
  final void Function(CalendarEvent event) onOpen;
  final OpenDay onDay;

  double _y(int minute) => (minute - firstHour * 60) / 60 * hour;

  static Span _span(Object item) => switch (item) {
    final CalendarEvent event => (
      start: startMinute(event),
      end: endMinute(event),
    ),
    final Task task => taskSpan(task.dueTime!),
    _ => (start: 0, end: 0),
  };

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final colors = LoomiaColors.of(context);
    final rule = colors.borderSubtle;
    final at = now;
    final nowMinute = at == null ? null : at.hour * 60 + at.minute;
    final showNow =
        nowMinute != null &&
        nowMinute >= firstHour * 60 &&
        nowMinute <= (firstHour + hours) * 60;
    final minCard = _WeekCard.minHeight(context);
    return Material(
      color: selected ? scheme.primaryContainer : Colors.transparent,
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: BorderDirectional(start: BorderSide(color: rule)),
        ),
        child: InkWell(
          // The day's own button is its heading; this is the same, by mouse.
          excludeFromSemantics: true,
          canRequestFocus: false,
          onTap: () {
            final column = _globalRect(context);
            onDay(day, Rect.fromLTWH(column.left, column.top, column.width, 0));
          },
          child: LayoutBuilder(
            builder: (context, box) {
              final width = box.maxWidth - 2 * _inset;
              return Stack(
                children: [
                  for (var i = 1; i < hours; i++)
                    Positioned(
                      top: i * hour,
                      left: 0,
                      right: 0,
                      height: 1,
                      child: ColoredBox(color: rule),
                    ),
                  for (final item in placeInLanes<Object>([
                    ...events,
                    ...tasks,
                  ], _span))
                    Positioned(
                      top: _y(_span(item.item).start) + 1,
                      height: math.max(
                        _y(_span(item.item).end) -
                            _y(_span(item.item).start) -
                            2,
                        minCard,
                      ),
                      left: _inset + item.lane * width / item.lanes,
                      width: width / item.lanes - (item.lanes > 1 ? 2 : 0),
                      child: switch (item.item) {
                        final Task task => _WeekTask(
                          task: task,
                          onTap: () => onOpenTask?.call(task),
                        ),
                        final event as CalendarEvent => _WeekCard(
                          event: event,
                          onTap: () => onOpen(event),
                        ),
                      },
                    ),
                  if (showNow) ...[
                    Positioned(
                      top: _y(nowMinute) - _nowLine / 2,
                      left: 0,
                      right: 0,
                      height: _nowLine,
                      child: IgnorePointer(
                        child: ColoredBox(color: scheme.primary),
                      ),
                    ),
                    PositionedDirectional(
                      top: _y(nowMinute) - _nowDot / 2,
                      start: 0,
                      width: _nowDot,
                      height: _nowDot,
                      child: IgnorePointer(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: scheme.primary,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

/// A timed task on the desktop week's hour grid (#377): a card like
/// [_WeekCard] around a [MonthTaskChip], its title only.
class _WeekTask extends StatelessWidget {
  const _WeekTask({required this.task, required this.onTap});

  final Task task;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: LoomiaColors.of(context).surfaceDefault,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppRadii.sm),
    ),
    clipBehavior: Clip.antiAlias,
    child: Padding(
      padding: const EdgeInsetsDirectional.only(start: AppSpacing.sm),
      child: Align(
        alignment: AlignmentDirectional.topStart,
        child: MonthTaskChip(task: task, onTap: onTap, showTime: false),
      ),
    ),
  );
}

/// A desktop week card: time and title, a start bar while upcoming; done,
/// outlined and muted. Too short for both lines: "14:00 · Team check-in".
class _WeekCard extends StatelessWidget {
  const _WeekCard({required this.event, required this.onTap});

  static const double _bar = 3;
  static const double _vertical = AppSpacing.xs / 2;

  final CalendarEvent event;
  final VoidCallback onTap;

  static TextStyle _timeStyle(BuildContext context) =>
      (Theme.of(context).textTheme.labelSmall ?? AppTypography.caption)
          .copyWith(fontWeight: FontWeight.w700);

  static TextStyle _titleStyle(BuildContext context) =>
      Theme.of(context).textTheme.labelMedium ?? AppTypography.label;

  /// The one-line card's height.
  static double minHeight(BuildContext context) =>
      2 * _vertical + _lineHeight(context, _timeStyle(context));

  @override
  Widget build(BuildContext context) {
    final colors = LoomiaColors.of(context);
    final scheme = Theme.of(context).colorScheme;
    final done = event.done;
    final ink = done ? colors.textMuted : null;
    final time = timeLabel(context, event.startsAt);
    final timeStyle = _timeStyle(context).copyWith(color: ink);
    final titleStyle = _titleStyle(context).copyWith(color: ink);
    return MergeSemantics(
      child: Semantics(
        button: true,
        child: Material(
          color: colors.surfaceDefault,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadii.sm),
            side: done
                ? BorderSide(color: colors.borderSubtle)
                : BorderSide.none,
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: Container(
              decoration: done
                  ? null
                  : BoxDecoration(
                      border: BorderDirectional(
                        start: BorderSide(color: scheme.primary, width: _bar),
                      ),
                    ),
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.sm,
                vertical: _vertical,
              ),
              child: LayoutBuilder(
                builder: (context, box) {
                  final lines =
                      ((box.maxHeight - _lineHeight(context, timeStyle)) /
                              _lineHeight(context, titleStyle))
                          .floor();
                  if (lines < 1) {
                    return Text(
                      AppLocalizations.of(context)
                          .calendarShortEvent(time, event.title),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: timeStyle,
                    );
                  }
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(time, maxLines: 1, style: timeStyle),
                      Flexible(
                        child: Text(
                          event.title,
                          maxLines: lines,
                          overflow: TextOverflow.ellipsis,
                          style: titleStyle,
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Shows [builder]'s content in a popover hung under [anchor] (above it when
/// there is no room below), kept inside the window: a modal route, so focus
/// moves in, Escape or a click outside closes it, and focus returns.
Future<void> showDayPopover(
  BuildContext context, {
  required Rect anchor,
  required String label,
  required WidgetBuilder builder,
}) => showDialog<void>(
  context: context,
  barrierColor: Colors.transparent,
  barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
  builder: (popover) => CustomSingleChildLayout(
    delegate: _Hung(anchor),
    child: _Popover(label: label, child: builder(popover)),
  ),
);

class _Popover extends StatelessWidget {
  const _Popover({required this.label, required this.child});

  static const double width = 340;

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colors = LoomiaColors.of(context);
    return Semantics(
      scopesRoute: true,
      namesRoute: true,
      explicitChildNodes: true,
      label: label,
      child: Container(
        width: width,
        decoration: BoxDecoration(
          color: colors.surfaceRaised,
          borderRadius: BorderRadius.circular(AppRadii.lg),
          border: Border.all(color: colors.borderSubtle),
          boxShadow: AppElevation.overlay,
        ),
        child: Material(
          type: MaterialType.transparency,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: child,
          ),
        ),
      ),
    );
  }
}

/// Places the popover under [anchor], centred on it, or above it when it
/// doesn't fit below; never closer than a margin to the window's edges.
class _Hung extends SingleChildLayoutDelegate {
  _Hung(this.anchor);

  static const double _gap = AppSpacing.xs;
  static const double _margin = AppSpacing.md;

  final Rect anchor;

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) =>
      BoxConstraints.loose(
        Size(
          constraints.maxWidth - 2 * _margin,
          constraints.maxHeight - 2 * _margin,
        ),
      );

  @override
  Offset getPositionForChild(Size size, Size child) {
    final below = anchor.bottom + _gap;
    final above = anchor.top - _gap - child.height;
    final top = below + child.height <= size.height - _margin
        ? below
        : math.max(above, _margin);
    final left = (anchor.center.dx - child.width / 2)
        .clamp(_margin, math.max(_margin, size.width - _margin - child.width))
        .toDouble();
    return Offset(left, math.min(top, size.height - _margin - child.height));
  }

  @override
  bool shouldRelayout(_Hung old) => old.anchor != anchor;
}

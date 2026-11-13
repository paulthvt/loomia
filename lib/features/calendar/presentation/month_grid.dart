import 'package:intl/intl.dart';
import 'package:loomia/app/theme/app_colors.dart';
import 'package:loomia/app/theme/app_spacing.dart';
import 'package:loomia/features/calendar/domain/month_grid.dart';
import 'package:loomia/features/calendar/domain/people_ahead.dart';
import 'package:loomia/l10n/app_localizations.dart';
import 'package:material_ui/material_ui.dart';

/// A month as whole weeks (spec §3): the locale's first weekday first, the
/// neighbouring months' days dimmed, up to three dots for a day's events and
/// open tasks, a ring on today, the selected day filled. Any day can be tapped, one of a
/// neighbouring month too.
class MonthGrid extends StatelessWidget {
  const MonthGrid({
    required this.month,
    required this.selected,
    required this.today,
    required this.counts,
    required this.onSelect,
    this.taskCounts = const {},
    this.people = const PeopleAhead.none(),
    this.onHero = false,
    super.key,
  });

  /// The 1st of the month shown, local midnight.
  final DateTime month;
  final DateTime selected;
  final DateTime today;

  /// Events per local day; a day without any is absent.
  final Map<DateTime, int> counts;

  /// Open tasks per local day, as `openTasksPerDay`.
  final Map<DateTime, int> taskCounts;

  /// Who is due when: the line under a day.
  final PeopleAhead people;
  final ValueChanged<DateTime> onSelect;

  /// On the hero gradient: white numbers and marks, today ringed and the
  /// selected day filled in white.
  final bool onHero;

  @override
  Widget build(BuildContext context) => _DayRows(
    days: monthDays(
      month,
      MaterialLocalizations.of(context).firstDayOfWeekIndex,
    ),
    inMonth: (day) => day.month == month.month,
    selected: selected,
    today: today,
    counts: counts,
    taskCounts: taskCounts,
    people: people,
    onSelect: onSelect,
    onHero: onHero,
  );
}

/// [days], whole weeks, as rows of [DayCell]s under the weekday names.
class _DayRows extends StatelessWidget {
  const _DayRows({
    required this.days,
    required this.inMonth,
    required this.selected,
    required this.today,
    required this.counts,
    required this.taskCounts,
    required this.people,
    required this.onSelect,
    required this.onHero,
  });

  final List<DateTime> days;
  final bool Function(DateTime day) inMonth;
  final DateTime selected;
  final DateTime today;
  final Map<DateTime, int> counts;
  final Map<DateTime, int> taskCounts;
  final PeopleAhead people;
  final ValueChanged<DateTime> onSelect;
  final bool onHero;

  @override
  Widget build(BuildContext context) {
    final colors = LoomiaColors.of(context);
    final weekday = DateFormat.E(Localizations.localeOf(context).toString());
    final style = Theme.of(context).textTheme.labelSmall
        ?.copyWith(color: onHero ? colors.onHeroQuiet : colors.textMuted);
    const week = DateTime.daysPerWeek;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: AppSpacing.xs,
      children: [
        // Each day says its full date already.
        ExcludeSemantics(
          child: Row(
            children: [
              for (final day in days.take(week))
                Expanded(
                  child: Text(
                    weekday.format(day),
                    textAlign: TextAlign.center,
                    style: style,
                  ),
                ),
            ],
          ),
        ),
        for (var start = 0; start < days.length; start += week)
          Row(
            children: [
              for (final day in days.sublist(start, start + week))
                Expanded(
                  child: DayCell(
                    day: day,
                    inMonth: inMonth(day),
                    selected: day == selected,
                    today: day == today,
                    past: day.isBefore(today),
                    count: counts[day] ?? 0,
                    taskCount: taskCounts[day] ?? 0,
                    people: people.count(day),
                    onTap: () => onSelect(day),
                    onHero: onHero,
                  ),
                ),
            ],
          ),
      ],
    );
  }
}

/// A day of the month grid and the desktop week's column
/// headings: its number in a circle (filled when selected, ringed today),
/// up to three dots: its events', then hollow ones for its open tasks.
class DayCell extends StatelessWidget {
  const DayCell({
    required this.day,
    required this.inMonth,
    required this.selected,
    required this.today,
    required this.past,
    required this.count,
    required this.onTap,
    this.taskCount = 0,
    this.people = 0,
    this.onHero = false,
    super.key,
  });

  static const double _circle = 40;
  static const double _ring = 1.5;
  static const double _dot = 6;
  static const int _maxDots = 3;

  /// The people marker (Figma "PeopleMarker"): 12 × 2, 2 under the dots.
  static const double _marker = 12;
  static const double _markerThickness = 2;

  final DateTime day;
  final bool inMonth;
  final bool selected;
  final bool today;
  final bool past;
  final int count;

  /// Open tasks due that day.
  final int taskCount;

  /// People due that day (#378): a line under the dots, from today on.
  final int people;
  final VoidCallback onTap;

  /// On the hero gradient, as [MonthGrid.onHero].
  final bool onHero;

  /// Neighbouring months' numbers on the hero.
  static const double _outsideOnHero = 0.35;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final colors = LoomiaColors.of(context);
    final ink = onHero
        ? selected
              ? colors.onHeroFill
              : inMonth
              ? colors.onHero
              : colors.onHero.withValues(alpha: _outsideOnHero)
        : selected
        ? scheme.onPrimary
        : today
        ? colors.primaryText
        : inMonth
        ? scheme.onSurface
        : colors.textDisabled;
    final fill = onHero ? colors.onHero : scheme.primary;
    final dot = onHero
        ? colors.onHero
        : past
        ? colors.textMuted
        : scheme.primary;
    final events = count.clamp(0, _maxDots);
    final tasks = taskCount.clamp(0, _maxDots - events);
    final l10n = AppLocalizations.of(context);
    final number = selected || today
        ? theme.textTheme.labelLarge
        : theme.textTheme.bodyLarge;

    return Semantics(
      // Its own node, not merged with the hero around it.
      container: true,
      button: true,
      selected: selected,
      label: daySemantics(l10n, day, count, taskCount, people),
      excludeSemantics: true,
      // The ink only on the number, so hover and splash centre on it; the
      // square is the minimum tap size, and has the number's spacing.
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox.square(
            dimension: kMinInteractiveDimension,
            child: InkWell(
              onTap: onTap,
              customBorder: const CircleBorder(),
              child: Center(
                child: Container(
                  width: _circle,
                  height: _circle,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: selected ? fill : null,
                    border: today && !selected
                        ? Border.all(color: fill, width: _ring)
                        : null,
                  ),
                  child: Text(
                    '${day.day}',
                    style: number?.copyWith(color: ink),
                  ),
                ),
              ),
            ),
          ),
          SizedBox(
            height: _dot,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              spacing: AppSpacing.xs,
              children: [
                for (var i = 0; i < events; i++)
                  Container(
                    width: _dot,
                    height: _dot,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: dot,
                    ),
                  ),
                // Hollow, so a day with only tasks reads apart from one
                // with an event.
                for (var i = 0; i < tasks; i++)
                  Container(
                    width: _dot,
                    height: _dot,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: dot, width: _ring),
                    ),
                  ),
              ],
            ),
          ),
          // People due (#378): one quiet line in the space under the
          // dots, so the cell keeps its height.
          SizedBox(
            height: AppSpacing.xs,
            child: people > 0 && !past
                ? Align(
                    alignment: Alignment.bottomCenter,
                    child: Container(
                      key: const ValueKey('people-marker'),
                      width: _marker,
                      height: _markerThickness,
                      // Round ends: Figma's 1 px radius on a 2 px line.
                      decoration: BoxDecoration(
                        color: onHero ? colors.onHero : colors.textMuted,
                        borderRadius: BorderRadius.circular(AppRadii.pill),
                      ),
                    ),
                  )
                : null,
          ),
        ],
      ),
    );
  }
}

/// What a screen reader says for a day of the Calendar: its date, its
/// events, then its open tasks and the people due, when there are any.
String daySemantics(
  AppLocalizations l10n,
  DateTime day,
  int events,
  int tasks,
  int people,
) => switch ((tasks > 0, people > 0)) {
  (true, true) => l10n.calendarDaySemanticsTasksPeople(
    day,
    events,
    tasks,
    people,
  ),
  (true, false) => l10n.calendarDaySemanticsTasks(day, events, tasks),
  (false, true) => l10n.calendarDaySemanticsPeople(day, events, people),
  (false, false) => l10n.calendarDaySemantics(day, events),
};

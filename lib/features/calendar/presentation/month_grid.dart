import 'package:intl/intl.dart';
import 'package:loomia/app/theme/app_colors.dart';
import 'package:loomia/app/theme/app_spacing.dart';
import 'package:loomia/features/calendar/domain/month_grid.dart';
import 'package:loomia/l10n/app_localizations.dart';
import 'package:material_ui/material_ui.dart';

/// A month as whole weeks (spec §3): the locale's first weekday first, the
/// neighbouring months' days dimmed, up to three dots for a day's events, a
/// ring on today, the selected day filled. Any day can be tapped, one of a
/// neighbouring month too.
class MonthGrid extends StatelessWidget {
  const MonthGrid({
    required this.month,
    required this.selected,
    required this.today,
    required this.counts,
    required this.onSelect,
    super.key,
  });

  /// The 1st of the month shown, local midnight.
  final DateTime month;
  final DateTime selected;
  final DateTime today;

  /// Events per local day; a day without any is absent.
  final Map<DateTime, int> counts;
  final ValueChanged<DateTime> onSelect;

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
    onSelect: onSelect,
  );
}

/// One week of the month grid's day cells under their weekday names: the
/// week view's strip.
class WeekStrip extends StatelessWidget {
  const WeekStrip({
    required this.days,
    required this.selected,
    required this.today,
    required this.counts,
    required this.onSelect,
    super.key,
  });

  /// The week's 7 days, as `weekDays`.
  final List<DateTime> days;
  final DateTime selected;
  final DateTime today;
  final Map<DateTime, int> counts;
  final ValueChanged<DateTime> onSelect;

  @override
  Widget build(BuildContext context) => _DayRows(
    days: days,
    inMonth: (_) => true,
    selected: selected,
    today: today,
    counts: counts,
    onSelect: onSelect,
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
    required this.onSelect,
  });

  final List<DateTime> days;
  final bool Function(DateTime day) inMonth;
  final DateTime selected;
  final DateTime today;
  final Map<DateTime, int> counts;
  final ValueChanged<DateTime> onSelect;

  @override
  Widget build(BuildContext context) {
    final weekday = DateFormat.E(Localizations.localeOf(context).toString());
    final style = Theme.of(context).textTheme.labelSmall
        ?.copyWith(color: LoomiaColors.of(context).textMuted);
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
                    onTap: () => onSelect(day),
                  ),
                ),
            ],
          ),
      ],
    );
  }
}

/// A day of the month grid, the week strip and the desktop week's column
/// headings: its number in a circle (filled when selected, ringed today),
/// up to three dots for its events.
class DayCell extends StatelessWidget {
  const DayCell({
    required this.day,
    required this.inMonth,
    required this.selected,
    required this.today,
    required this.past,
    required this.count,
    required this.onTap,
    super.key,
  });

  static const double _circle = 40;
  static const double _ring = 1.5;
  static const double _dot = 6;
  static const int _maxDots = 3;

  final DateTime day;
  final bool inMonth;
  final bool selected;
  final bool today;
  final bool past;
  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final colors = LoomiaColors.of(context);
    final ink = selected
        ? scheme.onPrimary
        : today
        ? colors.primaryText
        : inMonth
        ? scheme.onSurface
        : colors.textDisabled;
    final number = selected || today
        ? theme.textTheme.labelLarge
        : theme.textTheme.bodyLarge;

    return Semantics(
      button: true,
      selected: selected,
      label: AppLocalizations.of(context).calendarDaySemantics(day, count),
      excludeSemantics: true,
      // The ink only on the number, so hover and splash centre on it; the
      // square is the minimum tap size, and has the number's spacing.
      child: Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.xs),
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
                      color: selected ? scheme.primary : null,
                      border: today && !selected
                          ? Border.all(color: scheme.primary, width: _ring)
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
                  for (var i = 0; i < count.clamp(0, _maxDots); i++)
                    Container(
                      width: _dot,
                      height: _dot,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: past ? colors.textMuted : scheme.primary,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

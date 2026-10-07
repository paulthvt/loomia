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
  Widget build(BuildContext context) {
    final days = monthDays(
      month,
      MaterialLocalizations.of(context).firstDayOfWeekIndex,
    );
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
                  child: _Day(
                    day: day,
                    inMonth: day.month == month.month,
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

class _Day extends StatelessWidget {
  const _Day({
    required this.day,
    required this.inMonth,
    required this.selected,
    required this.today,
    required this.past,
    required this.count,
    required this.onTap,
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
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            spacing: AppSpacing.xs,
            children: [
              Container(
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
                child: Text('${day.day}', style: number?.copyWith(color: ink)),
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
      ),
    );
  }
}

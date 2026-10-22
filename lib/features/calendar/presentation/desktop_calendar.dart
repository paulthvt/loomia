import 'dart:math' as math;

import 'package:intl/intl.dart';
import 'package:loomia/app/theme/app_colors.dart';
import 'package:loomia/app/theme/app_spacing.dart';
import 'package:loomia/app/theme/app_theme.dart';
import 'package:loomia/app/theme/app_typography.dart';
import 'package:loomia/features/calendar/domain/calendar_event.dart';
import 'package:loomia/features/calendar/domain/week_grid.dart';
import 'package:loomia/features/calendar/presentation/event_row.dart';
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
/// listing its events. A day opens its popover; an event opens itself.
class DesktopMonth extends StatelessWidget {
  const DesktopMonth({
    required this.month,
    required this.days,
    required this.events,
    required this.selected,
    required this.today,
    required this.onOpen,
    required this.onDay,
    super.key,
  });

  /// The 1st of the month shown.
  final DateTime month;

  /// Whole weeks, as `monthDays`.
  final List<DateTime> days;
  final List<CalendarEvent> events;
  final DateTime selected;
  final DateTime today;
  final void Function(CalendarEvent event) onOpen;
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
                        onOpen: onOpen,
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
/// of its events as fit, then "+N more". Tinted when selected, sunken when
/// it belongs to the month before or after.
class _MonthCell extends StatelessWidget {
  const _MonthCell({
    required this.day,
    required this.first,
    required this.inMonth,
    required this.selected,
    required this.today,
    required this.events,
    required this.onOpen,
    required this.onDay,
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
  final void Function(CalendarEvent event) onOpen;
  final OpenDay onDay;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final colors = LoomiaColors.of(context);
    final l10n = AppLocalizations.of(context);
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
          label: l10n.calendarDaySemantics(day, events.length),
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
                          for (final event in events)
                            MonthEventChip.heightFor(
                                  context,
                                  event,
                                  box.maxWidth,
                                ) +
                                _gap,
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
                                for (final event in events.take(shown))
                                  MonthEventChip(
                                    event: event,
                                    onTap: () => onOpen(event),
                                  ),
                                if (shown < events.length)
                                  ExcludeSemantics(
                                    child: Text(
                                      l10n.calendarMoreEvents(
                                        events.length - shown,
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

/// Desktop week (Figma "Week B"): the 7 days on an hour grid, events placed
/// at their start and as tall as they last, overlapping ones side by side.
/// The selected column is tinted, today's has a line at [now].
class WeekGrid extends StatelessWidget {
  const WeekGrid({
    required this.days,
    required this.events,
    required this.selected,
    required this.today,
    required this.onOpen,
    required this.onDay,
    this.now,
    super.key,
  });

  /// Wider than the Figma's 56: "10:00 AM" in 12-hour locales.
  static const double _gutter = 72;

  /// Below this an hour gets, the grid scrolls instead of shrinking.
  static const double _minHour = 40;

  /// The week's 7 days, as `weekDays`.
  final List<DateTime> days;
  final List<CalendarEvent> events;
  final DateTime selected;
  final DateTime today;

  /// Where the now line goes; none without it.
  final DateTime? now;
  final void Function(CalendarEvent event) onOpen;
  final OpenDay onDay;

  @override
  Widget build(BuildContext context) {
    final colors = LoomiaColors.of(context);
    final week = [
      for (final event in events)
        if (days.contains(event.day)) event,
    ];
    final range = hourRange(week);
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
                for (final day in days)
                  Expanded(
                    child: _ColumnHeader(
                      day: day,
                      selected: day == selected,
                      today: day == today,
                      count: eventsOn(week, day).length,
                      onDay: onDay,
                    ),
                  ),
              ],
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
                          for (final day in days)
                            Expanded(
                              child: _DayColumn(
                                day: day,
                                events: eventsOn(week, day),
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
    required this.onDay,
  });

  static const double _circle = 36;
  static const double _ring = 1.5;

  final DateTime day;
  final bool selected;
  final bool today;
  final int count;
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
      label: AppLocalizations.of(context).calendarDaySemantics(day, count),
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
  final int firstHour;
  final int hours;

  /// One hour's height.
  final double hour;
  final bool selected;
  final DateTime? now;
  final void Function(CalendarEvent event) onOpen;
  final OpenDay onDay;

  double _y(int minute) => (minute - firstHour * 60) / 60 * hour;

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
                  for (final item in dayLanes(events))
                    Positioned(
                      top: _y(startMinute(item.event)) + 1,
                      height: math.max(
                        _y(endMinute(item.event)) -
                            _y(startMinute(item.event)) -
                            2,
                        minCard,
                      ),
                      left: _inset + item.lane * width / item.lanes,
                      width: width / item.lanes - (item.lanes > 1 ? 2 : 0),
                      child: _WeekCard(
                        event: item.event,
                        onTap: () => onOpen(item.event),
                      ),
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

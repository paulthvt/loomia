import 'dart:math' as math;

import 'package:loomia/features/calendar/domain/calendar_event.dart';
import 'package:loomia/features/calendar/domain/week_grid.dart';

sealed class TimelineRow {}

final class TimelineEvent extends TimelineRow {
  TimelineEvent(this.event);
  final CalendarEvent event;

  @override
  bool operator ==(Object other) =>
      other is TimelineEvent && other.event == event;

  @override
  int get hashCode => event.hashCode;
}

/// Free from [start] to [end], minutes from local midnight. [untilOnly]:
/// today's gap holding now, shown as "Free until {end}".
final class TimelineGap extends TimelineRow {
  TimelineGap(this.start, this.end, this.untilOnly);
  final int start;
  final int end;
  final bool untilOnly;

  @override
  bool operator ==(Object other) =>
      other is TimelineGap &&
      other.start == start &&
      other.end == end &&
      other.untilOnly == untilOnly;

  @override
  int get hashCode => Object.hash(start, end, untilOnly);
}

final class TimelineNow extends TimelineRow {
  TimelineNow(this.minute);
  final int minute;

  @override
  bool operator ==(Object other) =>
      other is TimelineNow && other.minute == minute;

  @override
  int get hashCode => minute.hashCode;
}

const Duration minGap = Duration(hours: 1);

/// [events] (in start order) with the free time of [minGap] or more between
/// their busy runs. With [nowMinute]: every event started before it sits
/// above the now line, the rest below; when now is free, what is left of
/// that gap follows the line as "Free until".
List<TimelineRow> dayTimeline(List<CalendarEvent> events, {int? nowMinute}) {
  if (events.isEmpty) return [];

  final rows = <TimelineRow>[];
  var busyEnd = 0;
  for (final event in events) {
    final start = startMinute(event);
    if (rows.isNotEmpty && start - busyEnd >= minGap.inMinutes) {
      rows.add(TimelineGap(busyEnd, start, false));
    }
    rows.add(TimelineEvent(event));
    busyEnd = math.max(busyEnd, endMinute(event));
  }
  if (nowMinute == null) return rows;

  bool before(TimelineRow row) => switch (row) {
    TimelineEvent(:final event) => startMinute(event) < nowMinute,
    TimelineGap(:final end) => end <= nowMinute,
    TimelineNow() => false,
  };
  // A gap holding now is replaced by its part after now.
  bool holdsNow(TimelineRow row) =>
      row is TimelineGap && row.start <= nowMinute && nowMinute < row.end;

  final above = rows.where(before).toList();
  final below = rows.where((row) => !before(row) && !holdsNow(row)).toList();
  final aboveEnd = above
      .whereType<TimelineEvent>()
      .map((row) => endMinute(row.event))
      .fold(0, math.max);
  final next = below.whereType<TimelineEvent>().firstOrNull;
  final nextStart = next == null ? null : startMinute(next.event);
  return [
    ...above,
    TimelineNow(nowMinute),
    if (aboveEnd <= nowMinute &&
        nextStart != null &&
        nextStart - nowMinute >= minGap.inMinutes)
      TimelineGap(nowMinute, nextStart, true),
    ...below,
  ];
}

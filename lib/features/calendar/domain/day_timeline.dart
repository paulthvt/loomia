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

List<TimelineRow> dayTimeline(List<CalendarEvent> events, {int? nowMinute}) {
  if (events.isEmpty) return [];

  // Step 1: Build events and gaps without considering now
  final rows = <TimelineRow>[];
  var busyEnd = 0;

  for (final event in events) {
    final start = startMinute(event);
    final end = endMinute(event);

    // Check for gap before this event
    if (busyEnd > 0 && start > busyEnd && start - busyEnd >= minGap.inMinutes) {
      rows.add(TimelineGap(busyEnd, start, false));
    }

    // Only add event if it starts at or after busyEnd (skip overlapping events)
    if (start >= busyEnd) {
      rows.add(TimelineEvent(event));
    }

    busyEnd = math.max(busyEnd, end);
  }

  // Step 2: Handle now if provided
  if (nowMinute != null) {
    final withNow = <TimelineRow>[];
    var nowInserted = false;

    for (var i = 0; i < rows.length; i++) {
      final row = rows[i];

      if (row is TimelineEvent) {
        final eventStart = startMinute(row.event);
        final eventEnd = endMinute(row.event);

        // Insert now before this event if: now <= eventStart and not yet inserted
        if (!nowInserted && nowMinute <= eventStart) {
          withNow.add(TimelineNow(nowMinute));
          nowInserted = true;

          // Check if there's a gap between now and this event
          if (eventStart - nowMinute >= minGap.inMinutes) {
            withNow.add(TimelineGap(nowMinute, eventStart, true));
          }
        }

        withNow.add(row);

        // Insert now after this event if now is inside the event
        if (!nowInserted && nowMinute > eventStart && nowMinute <= eventEnd) {
          withNow.add(TimelineNow(nowMinute));
          nowInserted = true;
        }
      } else if (row is TimelineGap) {
        final gap = row;

        // If now falls in this gap
        if (!nowInserted && nowMinute > gap.start && nowMinute < gap.end) {
          withNow.add(TimelineNow(nowMinute));
          nowInserted = true;

          // Add the remaining gap after now if it's big enough
          if (gap.end - nowMinute >= minGap.inMinutes) {
            withNow.add(TimelineGap(nowMinute, gap.end, true));
          }
        } else {
          // Keep gap as-is (whether before or after now)
          withNow.add(gap);
        }
      }
    }

    // If now hasn't been inserted yet, it's after all events
    if (!nowInserted) {
      withNow.add(TimelineNow(nowMinute));
    }

    return withNow;
  }

  return rows;
}

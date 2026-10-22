import 'dart:math' as math;

import 'package:loomia/features/calendar/domain/calendar_event.dart';

/// How long an event without an end lasts on the week's hour grid.
const Duration shownWithoutEnd = Duration(hours: 1);

/// The hours the desktop week shows by default (spec #366).
const int firstShownHour = 8;
const int lastShownHour = 22;

/// Minutes from local midnight of [event]'s day to its start.
int startMinute(CalendarEvent event) {
  final local = event.startsAt.toLocal();
  return local.hour * 60 + local.minute;
}

/// Minutes from local midnight of [event]'s day to its end, or an hour after
/// its start without one; cut at midnight, as it only shows on its start day.
int endMinute(CalendarEvent event) {
  final start = startMinute(event);
  final ends = event.endsAt;
  final length = ends == null
      ? shownWithoutEnd.inMinutes
      : ends.difference(event.startsAt).inMinutes;
  return math.min(start + math.max(length, 0), Duration.minutesPerDay);
}

/// The whole hours the week grid shows: [firstShownHour] to [lastShownHour],
/// stretched so every one of [events] fits.
({int first, int last}) hourRange(Iterable<CalendarEvent> events) {
  var first = firstShownHour;
  var last = lastShownHour;
  for (final event in events) {
    first = math.min(first, startMinute(event) ~/ 60);
    last = math.max(last, (endMinute(event) + 59) ~/ 60);
  }
  return (first: first, last: math.min(last, Duration.hoursPerDay));
}

/// An event's place across its column: [lane] of [lanes] side by side.
typedef Laned = ({CalendarEvent event, int lane, int lanes});

/// One day's [events] side by side where they overlap: each run of events
/// that overlap one another, directly or through a third, splits the column
/// into as many lanes as it needs at once; an event takes the first lane
/// free at its start. One that ends as another starts doesn't overlap it.
List<Laned> dayLanes(List<CalendarEvent> events) {
  final placed = <Laned>[];
  var run = <({CalendarEvent event, int lane})>[];
  var laneEnds = <int>[];
  var runEnd = 0;

  void close() {
    final lanes = laneEnds.length;
    placed.addAll([
      for (final item in run)
        (event: item.event, lane: item.lane, lanes: lanes),
    ]);
    run = [];
    laneEnds = [];
  }

  for (final event in byStart(events)) {
    final start = startMinute(event);
    final end = math.max(endMinute(event), start + 1);
    if (run.isNotEmpty && start >= runEnd) close();
    var lane = laneEnds.indexWhere((laneEnd) => laneEnd <= start);
    if (lane < 0) {
      lane = laneEnds.length;
      laneEnds.add(end);
    } else {
      laneEnds[lane] = end;
    }
    run.add((event: event, lane: lane));
    runEnd = run.length == 1 ? end : math.max(runEnd, end);
  }
  if (run.isNotEmpty) close();
  return placed;
}

/// How many of a day's chips, [heights] in order, fit in [available]: all
/// of them, or as many as leave room for the [more] line under them.
int chipsThatFit(List<double> heights, double more, double available) {
  final total = heights.fold<double>(0, (sum, height) => sum + height);
  if (total <= available) return heights.length;
  var used = more;
  var count = 0;
  for (final height in heights) {
    if (used + height > available) break;
    used += height;
    count++;
  }
  return count;
}

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
/// stretched so every one of [events], and every span in [more] (timed
/// tasks, #377), fits.
({int first, int last}) hourRange(
  Iterable<CalendarEvent> events, [
  Iterable<Span> more = const [],
]) {
  var first = firstShownHour;
  var last = lastShownHour;
  for (final span in [
    for (final event in events)
      (start: startMinute(event), end: endMinute(event)),
    ...more,
  ]) {
    first = math.min(first, span.start ~/ 60);
    last = math.max(last, (span.end + 59) ~/ 60);
  }
  return (first: first, last: math.min(last, Duration.hoursPerDay));
}

/// Minutes from local midnight: where something starts and ends on a day.
typedef Span = ({int start, int end});

/// How long a timed task's block is on the week's hour grid (#377): the
/// shortest that holds a title.
const Duration taskBlock = Duration(minutes: 30);

/// A timed task's place on its day, [taskBlock] long, cut at midnight.
Span taskSpan(({int hour, int minute}) time) {
  final start = time.hour * 60 + time.minute;
  return (
    start: start,
    end: math.min(start + taskBlock.inMinutes, Duration.minutesPerDay),
  );
}

/// An event's place across its column: [lane] of [lanes] side by side.
typedef Laned = ({CalendarEvent event, int lane, int lanes});

/// One day's [events] side by side where they overlap: [placeInLanes].
List<Laned> dayLanes(List<CalendarEvent> events) => [
  for (final item in placeInLanes(
    byStart(events),
    (event) => (start: startMinute(event), end: endMinute(event)),
  ))
    (event: item.item, lane: item.lane, lanes: item.lanes),
];

/// [items] side by side where they overlap: each run of items that overlap
/// one another, directly or through a third, splits the column into as
/// many lanes as it needs at once; an item takes the first lane free at its
/// start. One that ends as another starts doesn't overlap it. Events and
/// timed tasks share it (#377). Equal starts keep [items]' order.
List<({T item, int lane, int lanes})> placeInLanes<T>(
  List<T> items,
  Span Function(T item) span,
) {
  final placed = <({T item, int lane, int lanes})>[];
  var run = <({T item, int lane})>[];
  var laneEnds = <int>[];
  var runEnd = 0;

  void close() {
    final lanes = laneEnds.length;
    placed.addAll([
      for (final entry in run)
        (item: entry.item, lane: entry.lane, lanes: lanes),
    ]);
    run = [];
    laneEnds = [];
  }

  final sorted = [...items]
    ..sort((a, b) => span(a).start.compareTo(span(b).start));
  for (final item in sorted) {
    final start = span(item).start;
    final end = math.max(span(item).end, start + 1);
    if (run.isNotEmpty && start >= runEnd) close();
    var lane = laneEnds.indexWhere((laneEnd) => laneEnd <= start);
    if (lane < 0) {
      lane = laneEnds.length;
      laneEnds.add(end);
    } else {
      laneEnds[lane] = end;
    }
    run.add((item: item, lane: lane));
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

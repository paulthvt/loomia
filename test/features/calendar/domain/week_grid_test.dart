import 'package:flutter_test/flutter_test.dart';
import 'package:loomia/features/calendar/domain/calendar_event.dart';
import 'package:loomia/features/calendar/domain/week_grid.dart';

CalendarEvent _at(String id, int hour, int minute, {int? minutes}) {
  final start = DateTime(2026, 10, 22, hour, minute);
  return CalendarEvent(
    id: id,
    title: id,
    startsAt: start,
    endsAt: minutes == null ? null : start.add(Duration(minutes: minutes)),
  );
}

void main() {
  group('endMinute', () {
    test('an hour without an end, cut at midnight', () {
      expect(endMinute(_at('a', 14, 0)), 15 * 60);
      expect(endMinute(_at('b', 23, 30, minutes: 120)), 24 * 60);
    });
  });

  group('hourRange', () {
    test('8 to 22 by default', () {
      expect(hourRange([_at('a', 12, 30, minutes: 60)]), (first: 8, last: 22));
    });

    test('stretched to whole hours by an early start and a late end', () {
      expect(hourRange([_at('a', 7, 15), _at('b', 21, 30, minutes: 45)]), (
        first: 7,
        last: 23,
      ));
      expect(hourRange([_at('c', 23, 0, minutes: 180)]), (first: 8, last: 24));
    });
  });

  group('dayLanes', () {
    int lanesOf(List<Laned> laned, String id) =>
        laned.firstWhere((item) => item.event.id == id).lanes;
    int laneOf(List<Laned> laned, String id) =>
        laned.firstWhere((item) => item.event.id == id).lane;

    test('events apart, and one ending as the next starts, take the width', () {
      final laned = dayLanes([
        _at('a', 10, 0, minutes: 60),
        _at('b', 11, 0, minutes: 60),
        _at('c', 15, 0),
      ]);
      expect([for (final item in laned) item.lanes], [1, 1, 1]);
    });

    test('overlapping events go side by side, a free lane is reused', () {
      // a 19–21, b 19:30–20, c 20:15–20:45: b's lane is free again for c.
      final laned = dayLanes([
        _at('c', 20, 15, minutes: 30),
        _at('a', 19, 0, minutes: 120),
        _at('b', 19, 30, minutes: 30),
        _at('d', 22, 0),
      ]);
      expect(laneOf(laned, 'a'), 0);
      expect(laneOf(laned, 'b'), 1);
      expect(laneOf(laned, 'c'), 1);
      expect(lanesOf(laned, 'a'), 2);
      expect(lanesOf(laned, 'c'), 2);
      expect(lanesOf(laned, 'd'), 1);
    });

    test('three at once make three lanes', () {
      final laned = dayLanes([
        _at('a', 9, 0, minutes: 90),
        _at('b', 9, 30, minutes: 60),
        _at('c', 10, 0, minutes: 30),
      ]);
      expect([for (final item in laned) item.lane], [0, 1, 2]);
      expect([for (final item in laned) item.lanes], [3, 3, 3]);
    });
  });

  group('chipsThatFit', () {
    test('all of them when they fit, without the more line', () {
      expect(chipsThatFit([20, 20], 16, 40), 2);
    });

    test('otherwise as many as leave room for the more line', () {
      expect(chipsThatFit([20, 20, 20], 16, 59), 2);
      expect(chipsThatFit([20, 20, 20], 16, 55), 1);
      expect(chipsThatFit([20], 16, 10), 0);
    });
  });
}

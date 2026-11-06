import 'package:flutter_test/flutter_test.dart';
import 'package:loomia/features/calendar/domain/calendar_event.dart';
import 'package:loomia/features/calendar/domain/day_timeline.dart';

CalendarEvent _event(int startMin, int? endMin) {
  final start = DateTime(2026, 11, 6).add(Duration(minutes: startMin));
  final end = endMin == null
      ? null
      : DateTime(2026, 11, 6).add(Duration(minutes: endMin));
  return CalendarEvent(
    id: 'event-$startMin',
    title: 'Event at $startMin',
    startsAt: start,
    endsAt: end,
  );
}

void main() {
  group('dayTimeline', () {
    test('no events returns empty list', () {
      expect(dayTimeline([]), <TimelineRow>[]);
    });

    test('three events with gaps between them', () {
      final rows = dayTimeline([
        _event(540, 570), // 9:00–9:30
        _event(840, 900), // 14:00–15:00
        _event(1140, 1260), // 19:00–21:00
      ]);
      expect(rows.length, 5);
      expect(rows[0], isA<TimelineEvent>());
      expect(rows[1], isA<TimelineGap>());
      expect((rows[1] as TimelineGap).start, 570);
      expect((rows[1] as TimelineGap).end, 840);
      expect((rows[1] as TimelineGap).untilOnly, false);
      expect(rows[2], isA<TimelineEvent>());
      expect(rows[3], isA<TimelineGap>());
      expect((rows[3] as TimelineGap).start, 900);
      expect((rows[3] as TimelineGap).end, 1140);
      expect((rows[3] as TimelineGap).untilOnly, false);
      expect(rows[4], isA<TimelineEvent>());
    });

    test('gap under an hour is not shown', () {
      final rows = dayTimeline([
        _event(600, 660), // 10:00–11:00
        _event(690, 720), // 11:30–12:00
      ]);
      expect(rows.length, 2);
      expect(rows[0], isA<TimelineEvent>());
      expect(rows[1], isA<TimelineEvent>());
    });

    test('overlaps merged', () {
      final rows = dayTimeline([
        _event(600, 720), // 10:00–12:00
        _event(660, 780), // 11:00–13:00
        _event(900, 960), // 15:00–16:00
      ]);
      expect(rows.length, 3);
      expect(rows[0], isA<TimelineEvent>());
      expect(rows[1], isA<TimelineGap>());
      expect((rows[1] as TimelineGap).start, 780);
      expect((rows[1] as TimelineGap).end, 900);
      expect(rows[2], isA<TimelineEvent>());
    });

    test('event without end at 10:00, next at 11:30', () {
      final rows = dayTimeline([
        _event(600, null), // 10:00, no end (lasts 1 hour)
        _event(690, 720), // 11:30–12:00
      ]);
      expect(rows.length, 2);
      expect(rows[0], isA<TimelineEvent>());
      expect(rows[1], isA<TimelineEvent>());
    });

    test('Figma D: three events with now at 15:20', () {
      final rows = dayTimeline([
        _event(540, 570), // 9:00–9:30
        _event(840, 900), // 14:00–15:00
        _event(1140, 1260), // 19:00–21:00
      ], nowMinute: 920);
      expect(rows.length, 6);
      expect(rows[0], isA<TimelineEvent>());
      expect(rows[1], isA<TimelineGap>());
      expect((rows[1] as TimelineGap).start, 570);
      expect((rows[1] as TimelineGap).end, 840);
      expect((rows[1] as TimelineGap).untilOnly, false);
      expect(rows[2], isA<TimelineEvent>());
      expect(rows[3], isA<TimelineNow>());
      expect((rows[3] as TimelineNow).minute, 920);
      expect(rows[4], isA<TimelineGap>());
      expect((rows[4] as TimelineGap).start, 920);
      expect((rows[4] as TimelineGap).end, 1140);
      expect((rows[4] as TimelineGap).untilOnly, true);
      expect(rows[5], isA<TimelineEvent>());
    });

    test('now at 12:00 with 9–10 and 15–16', () {
      final rows = dayTimeline([
        _event(540, 600), // 9:00–10:00
        _event(900, 960), // 15:00–16:00
      ], nowMinute: 720);
      expect(rows.length, 4);
      expect(rows[0], isA<TimelineEvent>());
      expect(rows[1], isA<TimelineNow>());
      expect((rows[1] as TimelineNow).minute, 720);
      expect(rows[2], isA<TimelineGap>());
      expect((rows[2] as TimelineGap).start, 720);
      expect((rows[2] as TimelineGap).end, 900);
      expect((rows[2] as TimelineGap).untilOnly, true);
      expect(rows[3], isA<TimelineEvent>());
    });

    test('now 7:00 before the first event at 9:00', () {
      final rows = dayTimeline(
        [_event(540, 600)], // 9:00–10:00
        nowMinute: 420,
      );
      expect(rows.length, 3);
      expect(rows[0], isA<TimelineNow>());
      expect((rows[0] as TimelineNow).minute, 420);
      expect(rows[1], isA<TimelineGap>());
      expect((rows[1] as TimelineGap).start, 420);
      expect((rows[1] as TimelineGap).end, 540);
      expect((rows[1] as TimelineGap).untilOnly, true);
      expect(rows[2], isA<TimelineEvent>());
    });

    test('now 8:30 before the first event at 9:00 (under an hour)', () {
      final rows = dayTimeline(
        [_event(540, 600)], // 9:00–10:00
        nowMinute: 510,
      );
      expect(rows.length, 2);
      expect(rows[0], isA<TimelineNow>());
      expect((rows[0] as TimelineNow).minute, 510);
      expect(rows[1], isA<TimelineEvent>());
    });

    test('now 14:30 inside 14:00–15:00 with 19:00 next', () {
      final rows = dayTimeline([
        _event(840, 900), // 14:00–15:00
        _event(1140, 1260), // 19:00–21:00
      ], nowMinute: 870);
      expect(rows.length, 4);
      expect(rows[0], isA<TimelineEvent>());
      expect((rows[0] as TimelineEvent).event.startsAt.hour, 14);
      expect(rows[1], isA<TimelineNow>());
      expect((rows[1] as TimelineNow).minute, 870);
      expect(rows[2], isA<TimelineGap>());
      expect((rows[2] as TimelineGap).start, 900);
      expect((rows[2] as TimelineGap).end, 1140);
      expect((rows[2] as TimelineGap).untilOnly, false);
      expect(rows[3], isA<TimelineEvent>());
    });

    test('now 19:00 sharp, event at 19:00', () {
      final rows = dayTimeline(
        [_event(1140, 1260)], // 19:00–21:00
        nowMinute: 1140,
      );
      expect(rows.length, 2);
      expect(rows[0], isA<TimelineNow>());
      expect((rows[0] as TimelineNow).minute, 1140);
      expect(rows[1], isA<TimelineEvent>());
    });

    test('now after the last event (22:00)', () {
      final rows = dayTimeline([
        _event(540, 600), // 9:00–10:00
        _event(840, 900), // 14:00–15:00
      ], nowMinute: 1320);
      expect(rows.length, 4);
      expect(rows[0], isA<TimelineEvent>());
      expect(rows[1], isA<TimelineGap>());
      expect(rows[2], isA<TimelineEvent>());
      expect(rows[3], isA<TimelineNow>());
      expect((rows[3] as TimelineNow).minute, 1320);
    });

    test('now exactly at event end (gap start)', () {
      final rows = dayTimeline([
        _event(600, 720), // 10:00–12:00
        _event(840, 900), // 14:00–15:00
      ], nowMinute: 720);
      expect(rows.length, 4);
      expect(rows[0], isA<TimelineEvent>());
      expect(rows[1], isA<TimelineNow>());
      expect((rows[1] as TimelineNow).minute, 720);
      expect(rows[2], isA<TimelineGap>());
      expect((rows[2] as TimelineGap).start, 720);
      expect((rows[2] as TimelineGap).end, 840);
      expect((rows[2] as TimelineGap).untilOnly, true);
      expect(rows[3], isA<TimelineEvent>());
    });
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:loomia/features/calendar/domain/calendar_event.dart';
import 'package:loomia/features/today/domain/today_events.dart';
import 'package:loomia/features/workflows/domain/event_workflow.dart';

final _workshop = EventWorkflow(
  id: 'workshop',
  name: 'Workshop',
  steps: const [
    EventWorkflowStep(id: 'remind', label: 'Remind', days: -1),
    EventWorkflowStep(id: 'thank', label: 'Thank', days: 1),
  ],
);

const _invited = [(personId: 'p1', came: false)];

CalendarEvent _event(
  String id,
  DateTime startsAt, {
  DateTime? endsAt,
  String? link,
  DateTime? doneAt,
  Map<String, DateTime> stepsDone = const {},
  List<Attendee> attendees = _invited,
  String? eventWorkflowId = 'workshop',
}) => CalendarEvent(
  id: id,
  title: id,
  startsAt: startsAt,
  endsAt: endsAt,
  link: link,
  doneAt: doneAt,
  stepsDone: stepsDone,
  attendees: attendees,
  eventWorkflowId: eventWorkflowId,
);

final _morning = DateTime(2026, 10, 8, 9);

void main() {
  test("today's events, earliest first; tomorrow's wait", () {
    final evening = _event('evening', DateTime(2026, 10, 8, 19));
    final lunch = _event('lunch', DateTime(2026, 10, 8, 12));
    final tomorrow = _event('tomorrow', DateTime(2026, 10, 9, 19));

    final shown = todayEvents([evening, tomorrow, lunch], const [], _morning);

    expect(shown.today, [lunch, evening]);
  });

  test('an event that started and is not done is to mark, once', () {
    final started = _event('started', DateTime(2026, 10, 8, 8));
    final yesterday = _event('yesterday', DateTime(2026, 10, 7, 19));
    final done = _event(
      'done',
      DateTime(2026, 10, 7, 10),
      doneAt: DateTime(2026, 10, 7, 12),
    );
    final nobody = _event(
      'nobody',
      DateTime(2026, 10, 7, 9),
      attendees: const [],
    );
    final old = _event('old', DateTime(2026, 9, 23, 19));

    final shown = todayEvents(
      [started, yesterday, done, nobody, old],
      const [],
      _morning,
    );

    expect(shown.toMark, [yesterday, started]);
    expect(shown.today, isEmpty);
  });

  test('steps due today or late, not ticked, within two weeks', () {
    // Due Oct 8 (remind for the 9th) and Oct 7 (thank for the 6th, whose
    // reminder was ticked).
    final friday = _event('friday', DateTime(2026, 10, 9, 19));
    final tuesday = _event(
      'tuesday',
      DateTime(2026, 10, 6, 19),
      doneAt: DateTime(2026, 10, 6, 21),
      stepsDone: {'remind': DateTime(2026, 10, 5)},
    );
    // Thank due Oct 9: tomorrow, not yet. Remind, due Oct 7, is past use on
    // the day itself.
    final today = _event('today', DateTime(2026, 10, 8, 19));
    // Both ticked.
    final ticked = _event(
      'ticked',
      DateTime(2026, 10, 7, 19),
      doneAt: DateTime(2026, 10, 7, 21),
      stepsDone: {
        'remind': DateTime(2026, 10, 6),
        'thank': DateTime(2026, 10, 8),
      },
    );
    // Thank due Sep 21: too old.
    final old = _event('old', DateTime(2026, 9, 20, 19));
    // No checklist.
    final plain = _event(
      'plain',
      DateTime(2026, 10, 7, 19),
      eventWorkflowId: null,
    );

    final steps = todayEvents(
      [friday, tuesday, today, ticked, old, plain],
      [_workshop],
      _morning,
    ).steps;

    expect(
      [
        for (final due in steps)
          '${due.event.id}:${due.step.id}:${due.due.day}',
      ],
      ['tuesday:thank:7', 'friday:remind:8'],
    );
  });

  test(
    'a late prep step shows until the event day, then only on the event',
    () {
      final prep = EventWorkflow(
        id: 'workshop',
        name: 'Workshop',
        steps: const [
          EventWorkflowStep(id: 'order', label: 'Order', days: -3),
          EventWorkflowStep(id: 'setup', label: 'Set up', days: 0),
        ],
      );
      final saturday = _event('saturday', DateTime(2026, 10, 10, 19));
      List<String> due(DateTime now) => [
        for (final step in todayEvents([saturday], [prep], now).steps)
          step.step.id,
      ];

      // Order was due Oct 7: late, still worth doing.
      expect(due(_morning), ['order']);
      // On the day: setting up is due, ordering is past use.
      expect(due(DateTime(2026, 10, 10, 9)), ['setup']);
    },
  );

  test('Join from 15 minutes before until the end', () {
    final online = _event(
      'online',
      DateTime(2026, 10, 8, 19),
      endsAt: DateTime(2026, 10, 8, 20),
      link: 'https://meet.google.com/abc',
    );

    expect(canJoin(online, DateTime(2026, 10, 8, 18, 44)), isFalse);
    expect(canJoin(online, DateTime(2026, 10, 8, 18, 45)), isTrue);
    expect(canJoin(online, DateTime(2026, 10, 8, 19, 59)), isTrue);
    expect(canJoin(online, DateTime(2026, 10, 8, 20)), isFalse);
  });

  test('without an end, Join lasts two hours; without a link, never', () {
    final open = _event(
      'open',
      DateTime(2026, 10, 8, 19),
      link: 'https://x.io',
    );
    final inPerson = _event('inPerson', DateTime(2026, 10, 8, 19));

    expect(canJoin(open, DateTime(2026, 10, 8, 20, 59)), isTrue);
    expect(canJoin(open, DateTime(2026, 10, 8, 21)), isFalse);
    expect(canJoin(inPerson, DateTime(2026, 10, 8, 19)), isFalse);
  });

  test('an online event stays in today during Join, moves to toMark after', () {
    final online = _event(
      'online',
      DateTime(2026, 10, 8, 19),
      endsAt: DateTime(2026, 10, 8, 20, 30),
      link: 'https://meet.google.com/abc',
    );
    final inPerson = _event('inPerson', DateTime(2026, 10, 8, 19));

    // At 19:05, online is in today (Join window), inPerson is to mark.
    final duringJoin = todayEvents(
      [online, inPerson],
      const [],
      DateTime(2026, 10, 8, 19, 5),
    );
    expect(duringJoin.today, [online]);
    expect(duringJoin.toMark, [inPerson]);

    // At 20:30, both are to mark.
    final afterJoin = todayEvents(
      [online, inPerson],
      const [],
      DateTime(2026, 10, 8, 20, 30),
    );
    expect(afterJoin.today, isEmpty);
    expect(afterJoin.toMark, [online, inPerson]);
  });
}

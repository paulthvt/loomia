import 'package:flutter_test/flutter_test.dart';
import 'package:loomia/features/calendar/domain/calendar_event.dart';
import 'package:loomia/features/calendar/domain/missed.dart';
import 'package:loomia/features/contacts/domain/person.dart';
import 'package:loomia/features/workflows/domain/workflow.dart';

const _step = WorkflowStep(
  id: 's1',
  position: 1,
  label: 'Book the unboxing call',
  days: 0,
  eventWorkflowId: 'unboxing',
);

final _julie = Person(
  id: 'p1',
  name: 'Julie',
  stage: Stage.customer,
  stageSince: DateTime.utc(2026, 9),
  place: (workflowId: 'w1', atPosition: 1, lastTick: DateTime(2026, 10, 1)),
);

CalendarEvent _event(
  String id,
  DateTime startsAt, {
  String type = 'unboxing',
  bool came = false,
  bool done = true,
}) => CalendarEvent(
  id: id,
  title: 'Unboxing call $id',
  startsAt: startsAt,
  eventWorkflowId: type,
  doneAt: done ? startsAt : null,
  attendees: [Attendee(personId: 'p1', came: came)],
);

void main() {
  test(
    'the latest done event of the type they missed, since the last tick',
    () {
      expect(
        missedEvent(_julie, _step, [
          _event('old', DateTime(2026, 9, 28, 19)),
          _event('first', DateTime(2026, 10, 3, 19)),
          _event('second', DateTime(2026, 10, 6, 19)),
          _event('open', DateTime(2026, 10, 9, 19), done: false),
        ])?.id,
        'second',
      );
    },
  );

  test('none when they came, for another type, or for a plain step', () {
    expect(
      missedEvent(_julie, _step, [
        _event('came', DateTime(2026, 10, 3, 19), came: true),
        _event('other', DateTime(2026, 10, 4, 19), type: 'workshop'),
      ]),
      isNull,
    );
    expect(
      missedEvent(
        _julie,
        const WorkflowStep(
          id: 's2',
          position: 2,
          label: 'Give access',
          days: 0,
        ),
        [_event('first', DateTime(2026, 10, 3, 19))],
      ),
      isNull,
    );
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:loomia/features/calendar/domain/calendar_event.dart';
import 'package:loomia/features/contacts/domain/person.dart';
import 'package:loomia/features/today/domain/due.dart';
import 'package:loomia/features/workflows/domain/workflow.dart';

import '../../workflows/fake_workflow_repository.dart';

final _workflows = FakeWorkflowRepository.samples();
final _today = DateTime(2026, 9, 29);

/// On Samples step 2 as the server returns them, due on [due].
Person _person(
  String id,
  String name, {
  DateTime? due,
  String? step = 'samples-2',
  DateTime? pausedAt,
  bool follows = true,
  List<Reminder> reminders = const [],
}) => Person(
  id: id,
  name: name,
  stage: Stage.prospect,
  stageSince: DateTime.utc(2026),
  place: follows
      ? (workflowId: 'samples', atPosition: 2, lastTick: DateTime(2026, 9, 20))
      : null,
  currentStepId: follows ? step : null,
  dueOn: due,
  pausedAt: pausedAt,
  reminders: reminders,
);

Reminder _reminder(String id, DateTime due) =>
    (id: id, text: 'Text $id', dueOn: due, createdAt: DateTime.utc(2026));

List<String> _keys(List<Due> due) => [for (final row in due) row.key];

void main() {
  test('due today and late stay; not yet due, paused, done and no workflow '
      'fall out', () {
    final due = dueToday(
      [
        _person('today', 'Today', due: _today),
        _person('late', 'Late', due: DateTime(2026, 9, 27)),
        _person('tomorrow', 'Tomorrow', due: DateTime(2026, 9, 30)),
        _person('paused', 'Paused', pausedAt: DateTime.utc(2026, 9, 1)),
        _person('done', 'Done', step: null),
        _person('none', 'None', follows: false),
      ],
      _workflows,
      _today,
    );

    expect([for (final row in due) row.person.id], ['late', 'today']);
    expect((due.first as DueStep).step.step.label, 'Send the samples');
  });

  test('oldest first, then by name whatever the case', () {
    final due = dueToday(
      [
        _person('c', 'claire', due: DateTime(2026, 9, 28)),
        _person('b', 'Bruno', due: DateTime(2026, 9, 28)),
        _person('a', 'Anna', due: _today),
      ],
      _workflows,
      _today,
    );

    expect(
      [for (final row in due) row.person.name],
      ['Bruno', 'claire', 'Anna'],
    );
  });

  test('reminders due today or late stay, later ones fall out, whatever the '
      'workflow', () {
    final due = dueToday(
      [
        _person(
          'paused',
          'Paused',
          pausedAt: DateTime.utc(2026, 9, 1),
          reminders: [_reminder('r-paused', _today)],
        ),
        _person(
          'none',
          'None',
          follows: false,
          reminders: [
            _reminder('r-late', DateTime(2026, 9, 27)),
            _reminder('r-tomorrow', DateTime(2026, 9, 30)),
          ],
        ),
      ],
      _workflows,
      _today,
    );

    expect(_keys(due), ['r-late', 'r-paused']);
    expect((due.first as DueReminder).reminder.dueOn, DateTime(2026, 9, 27));
  });

  test('one person with a reminder and a step due the same day has two rows, '
      'the reminder first', () {
    final late = DateTime(2026, 9, 27);
    final due = dueToday(
      [
        _person('b', 'Bruno', due: late),
        _person('a', 'Anna', due: late, reminders: [_reminder('r-anna', late)]),
      ],
      _workflows,
      _today,
    );

    expect(_keys(due), ['r-anna', 'a', 'b']);
    expect([for (final row in due) row.person.id], ['a', 'a', 'b']);
  });

  group('invitation follow-ups', () {
    CalendarEvent event(String id, DateTime startsAt, List<Attendee> people) =>
        CalendarEvent(
          id: id,
          title: 'Workshop $id',
          startsAt: startsAt,
          attendees: people,
        );
    Attendee invited(String id, DateTime followUpOn) => Attendee(
      personId: id,
      going: false,
      invitedOn: DateTime(2026, 9, 20),
      followUpOn: followUpOn,
    );

    test('due today or late stay, tomorrow falls out, and the event\'s day '
        'passed takes them away', () {
      final due = dueToday(
        [
          _person('a', 'Anna', follows: false),
          _person('b', 'Bruno', follows: false),
          _person('c', 'Chloé', follows: false),
        ],
        _workflows,
        _today,
        events: [
          event('e1', DateTime(2026, 10, 2, 19), [
            invited('a', _today),
            invited('b', DateTime(2026, 9, 30)),
            invited('gone', _today),
          ]),
          // Today, at 9:00, already started: still its day.
          event('e2', DateTime(2026, 9, 29, 9), [invited('c', _today)]),
          event('e3', DateTime(2026, 9, 28, 19), [invited('b', _today)]),
        ],
      );

      expect(_keys(due), ['e1:a', 'e2:c']);
      expect(due.first, isA<DueFollowUp>());
      expect(due.first.day, _today);
    });

    test('the same day: reminders, then follow-ups, then the step', () {
      final due = dueToday(
        [
          _person(
            'a',
            'Anna',
            due: _today,
            reminders: [_reminder('r-anna', _today)],
          ),
        ],
        _workflows,
        _today,
        events: [
          event('e1', DateTime(2026, 10, 2, 19), [invited('a', _today)]),
        ],
      );

      expect(_keys(due), ['r-anna', 'e1:a', 'a']);
    });
  });

  test('an event step carries the event they missed', () {
    final flow = Workflow(
      id: 'flow',
      stage: Stage.customer,
      name: 'New customer',
      isDefault: true,
      steps: const [
        WorkflowStep(
          id: 'book',
          position: 1,
          label: 'Book the unboxing call',
          days: 0,
          eventWorkflowId: 'unboxing',
        ),
      ],
    );
    final julie = Person(
      id: 'j',
      name: 'Julie',
      stage: Stage.customer,
      stageSince: DateTime.utc(2026),
      place: (
        workflowId: 'flow',
        atPosition: 1,
        lastTick: DateTime(2026, 9, 20),
      ),
      currentStepId: 'book',
      dueOn: DateTime(2026, 9, 20),
    );
    final missed = CalendarEvent(
      id: 'e1',
      title: 'Unboxing call — Julie',
      startsAt: DateTime(2026, 9, 25, 19),
      eventWorkflowId: 'unboxing',
      doneAt: DateTime(2026, 9, 25, 21),
      attendees: const [Attendee(personId: 'j')],
    );

    final due = dueToday([julie], [flow], _today, events: [missed]);

    expect((due.single as DueStep).missed?.id, 'e1');
  });
}

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

  test('done and asked what comes next: one row, on the last tick\'s day', () {
    final sophie = Person(
      id: 's',
      name: 'Sophie',
      stage: Stage.prospect,
      stageSince: DateTime.utc(2026),
      place: (
        workflowId: 'samples',
        atPosition: 1e9,
        lastTick: DateTime(2026, 9, 25),
      ),
      needsNext: true,
    );
    final quiet = Person(
      id: 'q',
      name: 'Quiet',
      stage: Stage.prospect,
      stageSince: DateTime.utc(2026),
      place: (
        workflowId: 'samples',
        atPosition: 1e9,
        lastTick: DateTime(2026, 9, 25),
      ),
    );

    final due = dueToday([sophie, quiet], _workflows, _today);

    expect(_keys(due), ['next:s']);
    expect(due.single.day, DateTime(2026, 9, 25));
    expect((due.single as DueNext).workflow.id, 'samples');
  });

  test('an LRP renewal: from 3 days before, ranked after reminders', () {
    final julie = Person(
      id: 'j',
      name: 'Julie',
      stage: Stage.customer,
      stageSince: DateTime.utc(2026),
      loyaltySince: DateTime(2026, 8, 1),
      loyaltyDay: 1,
      reminders: [_reminder('r-j', DateTime(2026, 9, 28))],
    );

    final due = dueToday([julie], _workflows, _today);

    expect(_keys(due), ['r-j', 'lrp:j']);
    expect((due.last as DueLoyalty).renewal, DateTime(2026, 10));
    expect(due.last.day, DateTime(2026, 9, 28));
  });

  group('dueOn', () {
    final thursday = DateTime(2026, 10, 8);
    final today = DateTime(2026, 10, 6);
    List<Due> on(
      List<Person> people,
      DateTime day, {
      List<CalendarEvent> events = const [],
    }) => dueOn(people, _workflows, day, today, events: events);

    test('a step shows on its day only', () {
      final anna = _person('a', 'Anna', due: thursday);

      expect(_keys(on([anna], thursday)), ['a']);
      expect(on([anna], DateTime(2026, 10, 7)), isEmpty);
      expect(on([anna], DateTime(2026, 10, 9)), isEmpty);
    });

    test('a paused person: the step goes, the reminder stays', () {
      final anna = _person(
        'a',
        'Anna',
        due: thursday,
        pausedAt: DateTime.utc(2026, 10),
        reminders: [_reminder('r', thursday)],
      );

      expect(_keys(on([anna], thursday)), ['r']);
    });

    test('an LRP renewing on the 11th shows on the 8th only, not once '
        'checked', () {
      Person julie({DateTime? checked}) => Person(
        id: 'j',
        name: 'Julie',
        stage: Stage.customer,
        stageSince: DateTime.utc(2026),
        loyaltySince: DateTime(2026, 8, 1),
        loyaltyDay: 11,
        loyaltyCheckedFor: checked,
      );

      final due = on([julie()], thursday);
      expect(_keys(due), ['lrp:j']);
      expect((due.single as DueLoyalty).renewal, DateTime(2026, 10, 11));
      expect(on([julie()], DateTime(2026, 10, 9)), isEmpty);
      expect(on([julie(checked: DateTime(2026, 10, 11))], thursday), isEmpty);
      // Next month's, on its first day.
      expect(_keys(on([julie()], DateTime(2026, 11, 8))), ['lrp:j']);
    });

    test('a follow-up on its day, unless its event is before it', () {
      final anna = _person('a', 'Anna', follows: false);
      CalendarEvent event(String id, DateTime at) => CalendarEvent(
        id: id,
        title: 'Workshop',
        startsAt: at,
        attendees: [
          Attendee(
            personId: 'a',
            going: false,
            invitedOn: DateTime(2026, 10, 5),
            followUpOn: thursday,
          ),
        ],
      );

      expect(
        _keys(
          on(
            [anna],
            thursday,
            events: [event('e1', DateTime(2026, 10, 9, 19))],
          ),
        ),
        ['e1:a'],
      );
      expect(
        on([anna], thursday, events: [event('e2', DateTime(2026, 10, 7, 19))]),
        isEmpty,
      );
    });

    test('never what comes next', () {
      final sophie = Person(
        id: 's',
        name: 'Sophie',
        stage: Stage.prospect,
        stageSince: DateTime.utc(2026),
        place: (workflowId: 'samples', atPosition: 1e9, lastTick: thursday),
        needsNext: true,
      );

      expect(on([sophie], thursday), isEmpty);
    });

    test('a past day is empty; today has no late ones', () {
      final late = _person('l', 'Late', due: DateTime(2026, 10, 5));
      final now = _person('n', 'Now', due: today);

      expect(on([late, now], DateTime(2026, 10, 5)), isEmpty);
      expect(_keys(on([late, now], today)), ['n']);
    });

    test('byPerson: one run per person, by name', () {
      final due = on([
        _person('c', 'Claire', due: thursday),
        _person(
          'a',
          'Anna',
          due: thursday,
          reminders: [_reminder('r', thursday)],
        ),
      ], thursday);

      expect(
        [
          for (final run in byPerson(due)) [for (final item in run) item.key],
        ],
        [
          ['r', 'a'],
          ['c'],
        ],
      );
    });
  });
}

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loomia/core/ui/pick_day.dart';
import 'package:loomia/features/calendar/data/event_repository.dart';
import 'package:loomia/features/calendar/domain/calendar_event.dart';
import 'package:loomia/features/calendar/presentation/calendar_controller.dart';
import 'package:loomia/features/contacts/data/activity_repository.dart';
import 'package:loomia/features/contacts/data/people_repository.dart';
import 'package:loomia/features/contacts/domain/people_failure.dart';
import 'package:loomia/features/contacts/presentation/people_controller.dart';

import '../../contacts/fake_activity_repository.dart';
import '../../contacts/fake_people_repository.dart';
import '../fake_event_repository.dart';

const _owner = 'p@example.com';

ProviderContainer _container(
  FakeEventRepository events, {
  FakePeopleRepository? people,
  FakeActivityRepository? activities,
}) => ProviderContainer.test(
  overrides: [
    eventRepositoryProvider.overrideWithValue(events),
    if (people != null) peopleRepositoryProvider.overrideWithValue(people),
    if (activities != null)
      activityRepositoryProvider.overrideWithValue(activities),
  ],
);

EventDraft _draft(String title, DateTime startsAt) => (
  title: title,
  startsAt: startsAt,
  endsAt: null,
  place: null,
  link: null,
  notes: null,
  eventWorkflowId: null,
);

final _day = DateTime(2026, 10, 10);

There _there(String id) =>
    (personId: id, customer: false, amount: null, text: null);

final _workshop = CalendarEvent(
  id: 'e1',
  title: 'Workshop',
  startsAt: DateTime(2026, 10, 8, 19),
);

void main() {
  test('signed out: no events, and nothing asked', () async {
    final fake = FakeEventRepository([_workshop]);
    final container = _container(fake);

    expect(await container.read(eventsProvider(null).future), isEmpty);
    expect(fake.calls, isEmpty);
  });

  test('add and save keep the list in order, without a reload', () async {
    final fake = FakeEventRepository([_workshop]);
    final container = _container(fake);
    await container.read(eventsProvider(_owner).future);
    final events = container.read(eventsProvider(_owner).notifier);

    final coffee = await events.add(
      _draft('Coffee', DateTime(2026, 10, 8, 10)),
    );
    await events.save('e1', _draft('Workshop', DateTime(2026, 10, 7, 19)));

    expect(
      container.read(eventsProvider(_owner)).value!.map((event) => event.id),
      ['e1', coffee.id],
    );
    expect(fake.calls.where((call) => call == 'list()'), hasLength(1));
  });

  test('remove drops the event', () async {
    final fake = FakeEventRepository([_workshop]);
    final container = _container(fake);
    await container.read(eventsProvider(_owner).future);

    await container.read(eventsProvider(_owner).notifier).remove('e1');

    expect(container.read(eventsProvider(_owner)).value, isEmpty);
    expect(fake.calls, contains('remove(e1)'));
  });

  test('a failed add throws and leaves the list as it was', () async {
    final fake = FakeEventRepository([_workshop]);
    final container = _container(fake);
    await container.read(eventsProvider(_owner).future);
    fake.failWith = PeopleFailure.network;

    await expectLater(
      container
          .read(eventsProvider(_owner).notifier)
          .add(_draft('Coffee', DateTime(2026, 10, 8, 10))),
      throwsA(PeopleFailure.network),
    );
    expect(container.read(eventsProvider(_owner)).value, [_workshop]);
  });

  group('selection', () {
    test('starts on today, in its month', () {
      final container = ProviderContainer.test();
      final now = today();

      expect(container.read(calendarSelectionProvider), (
        mode: CalendarMode.month,
        month: DateTime(now.year, now.month),
        day: now,
      ));
    });

    test('selecting a day of another month shows that month', () {
      final container = ProviderContainer.test();

      container
          .read(calendarSelectionProvider.notifier)
          .select(DateTime(2026, 9, 28));

      expect(container.read(calendarSelectionProvider), (
        mode: CalendarMode.month,
        month: DateTime(2026, 9),
        day: DateTime(2026, 9, 28),
      ));
    });

    test('the mode keeps the day, and selecting keeps the mode', () {
      final container = ProviderContainer.test();
      final selector = container.read(calendarSelectionProvider.notifier)
        ..select(DateTime(2026, 9, 28))
        ..setMode(CalendarMode.week);

      expect(
        container.read(calendarSelectionProvider).day,
        DateTime(2026, 9, 28),
      );

      selector
        ..select(DateTime(2026, 10, 2))
        ..toToday();
      expect(container.read(calendarSelectionProvider).mode, CalendarMode.week);
      expect(container.read(calendarSelectionProvider).day, today());
    });

    test('showing a month selects its 1st, or today in this one', () {
      final container = ProviderContainer.test();
      final selector = container.read(calendarSelectionProvider.notifier)
        ..showMonth(DateTime(2031, 3));
      expect(container.read(calendarSelectionProvider), (
        mode: CalendarMode.month,
        month: DateTime(2031, 3),
        day: DateTime(2031, 3),
      ));

      final now = today();
      selector.showMonth(DateTime(now.year, now.month));
      expect(container.read(calendarSelectionProvider).day, now);
    });

    test('another month selects its 1st; back to this one, today', () {
      final container = ProviderContainer.test();
      final selector = container.read(calendarSelectionProvider.notifier);
      final now = today();

      selector.shift(1);
      expect(
        container.read(calendarSelectionProvider).day,
        DateTime(now.year, now.month + 1),
      );

      selector.shift(-1);
      expect(container.read(calendarSelectionProvider).day, now);
    });

    group('shiftedDay in week view', () {
      // Monday October 19, 2026.
      final now = DateTime(2026, 10, 19);
      CalendarSelection on(DateTime day) => (
        mode: CalendarMode.week,
        month: DateTime(day.year, day.month),
        day: day,
      );

      test('a week later keeps the weekday', () {
        expect(
          shiftedDay(on(DateTime(2026, 10, 21)), 1, now, 1),
          DateTime(2026, 10, 28),
        );
        expect(
          shiftedDay(on(DateTime(2026, 10, 1)), -1, now, 1),
          DateTime(2026, 9, 24),
        );
      });

      test("landing in today's week selects today", () {
        expect(shiftedDay(on(DateTime(2026, 10, 14)), 1, now, 1), now);
        expect(shiftedDay(on(DateTime(2026, 10, 28)), -1, now, 1), now);
        // From Sunday, today's week is October 18 to 24.
        expect(shiftedDay(on(DateTime(2026, 10, 17)), 1, now, 0), now);
        expect(
          shiftedDay(on(DateTime(2026, 10, 18)), -1, now, 0),
          DateTime(2026, 10, 11),
        );
      });

      test('in month view, the 1st or today', () {
        final month = (
          mode: CalendarMode.month,
          month: DateTime(2026, 9),
          day: DateTime(2026, 9, 14),
        );
        expect(shiftedDay(month, 1, now, 1), now);
        expect(shiftedDay(month, -1, now, 1), DateTime(2026, 8));
      });
    });
  });

  test('invite and uninvite reload the event with its people', () async {
    final fake = FakeEventRepository([_workshop]);
    final container = _container(fake);
    await container.read(eventsProvider(_owner).future);
    final events = container.read(eventsProvider(_owner).notifier);

    await events.invite('e1', ['p1', 'p2'], _day);
    expect(container.read(eventsProvider(_owner)).value!.single.attendees, [
      Attendee(personId: 'p1', came: false, invitedOn: _day),
      Attendee(personId: 'p2', came: false, invitedOn: _day),
    ]);

    await events.uninvite('e1', 'p1');
    expect(container.read(eventsProvider(_owner)).value!.single.attendees, [
      Attendee(personId: 'p2', came: false, invitedOn: _day),
    ]);
    expect(fake.calls.where((call) => call == 'list()'), hasLength(3));
  });

  test('on a group type, people start invited; going and following up '
      'move their follow-up day', () async {
    final fake = FakeEventRepository([
      CalendarEvent(
        id: 'e1',
        title: 'Huiles et sommeil',
        startsAt: DateTime(2026, 10, 20, 19),
        eventWorkflowId: 'workshop',
      ),
    ]);
    final container = _container(fake);
    await container.read(eventsProvider(_owner).future);
    final events = container.read(eventsProvider(_owner).notifier);
    Attendee attendee(String id) => container
        .read(eventsProvider(_owner))
        .value!
        .single
        .attendees
        .firstWhere((a) => a.personId == id);

    await events.invite('e1', ['p1', 'p2'], _day);
    expect(attendee('p1').going, isFalse);
    expect(attendee('p1').followUpOn, DateTime(2026, 10, 13));

    await events.followedUp('e1', 'p1', DateTime(2026, 10, 14));
    expect(attendee('p1').followedUpOn, DateTime(2026, 10, 14));
    expect(attendee('p1').followUpOn, DateTime(2026, 10, 17));

    await events.setGoing('e1', 'p2');
    expect(attendee('p2').going, isTrue);
    expect(attendee('p2').followUpOn, isNull);
    expect(
      fake.calls,
      containsAllInOrder(['followedUp(e1:p1)', 'setGoing(e1:p2)']),
    );
  });

  test('a repeating event: its occurrences, the first one back', () async {
    final fake = FakeEventRepository();
    final container = _container(fake);
    await container.read(eventsProvider(_owner).future);
    final events = container.read(eventsProvider(_owner).notifier);

    final first = await events.addRepeating(
      _draft('Team call', DateTime(2026, 10, 13, 19)),
      (everyWeeks: 2, untilOn: DateTime(2026, 11, 10)),
      'Europe/Paris',
    );

    expect(first.startsAt, DateTime(2026, 10, 13, 19));
    expect(
      [
        for (final event in container.read(eventsProvider(_owner)).value!)
          event.day.day,
      ],
      [13, 27, 10],
    );
    expect(fake.calls, contains('addSeries(Team call, 2, Europe/Paris)'));
  });

  test('people on an occurrence: this one, or the following ones', () async {
    final fake = FakeEventRepository();
    final container = _container(fake);
    await container.read(eventsProvider(_owner).future);
    final events = container.read(eventsProvider(_owner).notifier);
    final first = await events.addRepeating(
      _draft('Team call', DateTime(2026, 10, 13, 19)),
      (everyWeeks: 1, untilOn: DateTime(2026, 10, 27)),
      'Europe/Paris',
    );
    final second = container.read(eventsProvider(_owner)).value![1];

    await events.invite(second.id, ['p1'], _day, following: true);
    await events.uninvite(second.id, 'p1', following: true);
    await events.invite(first.id, ['p2'], _day, following: true);
    await events.invite(first.id, ['p3'], _day);

    expect(
      [
        for (final event in container.read(eventsProvider(_owner)).value!)
          event.attendees.map((a) => a.personId).join(),
      ],
      ['p2p3', 'p2', 'p2'],
    );
  });

  test('This and following: in place, or again from a new rule', () async {
    final fake = FakeEventRepository();
    final container = _container(fake);
    await container.read(eventsProvider(_owner).future);
    final events = container.read(eventsProvider(_owner).notifier);
    await events.addRepeating(_draft('Team call', DateTime(2026, 10, 13, 19)), (
      everyWeeks: 1,
      untilOn: DateTime(2026, 11, 10),
    ), 'Europe/Paris');
    final second = container.read(eventsProvider(_owner)).value![1];

    final renamed = await events.saveFollowing(
      second.id,
      _draft('Big call', DateTime(2026, 10, 20, 20)),
      (everyWeeks: 1, untilOn: DateTime(2026, 11, 10)),
    );
    expect(renamed.id, second.id);
    List<String> titles() => [
      for (final event in container.read(eventsProvider(_owner)).value!)
        '${event.day.day}/${event.day.month} ${event.title} '
            '${event.startsAt.hour}',
    ];
    expect(titles(), [
      '13/10 Team call 19',
      '20/10 Big call 20',
      '27/10 Big call 20',
      '3/11 Big call 20',
      '10/11 Big call 20',
    ]);

    final moved = await events.saveFollowing(
      second.id,
      _draft('Big call', DateTime(2026, 10, 20, 20)),
      (everyWeeks: 2, untilOn: DateTime(2026, 11, 10)),
    );
    expect(moved.day, DateTime(2026, 10, 20));
    expect(titles(), [
      '13/10 Team call 19',
      '20/10 Big call 20',
      '3/11 Big call 20',
    ]);
    expect(moved.series?.everyWeeks, 2);
  });

  test('ending a series from an occurrence', () async {
    final fake = FakeEventRepository();
    final container = _container(fake);
    await container.read(eventsProvider(_owner).future);
    final events = container.read(eventsProvider(_owner).notifier);
    await events.addRepeating(_draft('Team call', DateTime(2026, 10, 13, 19)), (
      everyWeeks: 1,
      untilOn: null,
    ), 'Europe/Paris');
    final third = container.read(eventsProvider(_owner)).value![2];

    await events.endSeries(third.id);

    final left = container.read(eventsProvider(_owner)).value!;
    expect(left, hasLength(2));
    expect(left.last.series?.untilOn, DateTime(2026, 10, 26));
  });

  test('a single event made to repeat', () async {
    final fake = FakeEventRepository([_workshop]);
    final container = _container(fake);
    await container.read(eventsProvider(_owner).future);
    final events = container.read(eventsProvider(_owner).notifier);

    final first = await events.repeat(
      'e1',
      _draft('Workshop', _workshop.startsAt),
      (everyWeeks: 4, untilOn: null),
      'Europe/Paris',
    );

    expect(
      fake.calls,
      containsAllInOrder(['update(e1)', 'repeat(e1, 4, Europe/Paris)']),
    );
    expect(first.series?.everyWeeks, 4);
    expect(
      container.read(eventsProvider(_owner)).value!.length,
      greaterThan(10),
    );
  });

  test('marking done reloads the events and the people', () async {
    final fake = FakeEventRepository([_workshop]);
    final people = FakePeopleRepository();
    final container = _container(fake, people: people);
    await container.read(eventsProvider(_owner).future);
    await container.read(peopleProvider(_owner).future);
    final listed = people.calls.where((call) => call == 'list()').length;
    final events = container.read(eventsProvider(_owner).notifier);
    await events.invite('e1', ['p1', 'p2'], _day);

    await events.close('e1', [_there('p1')], const [], DateTime(2026, 10, 9));
    await container.read(peopleProvider(_owner).future);

    final done = container.read(eventsProvider(_owner)).value!.single;
    expect(done.done, isTrue);
    expect(done.attendees, [
      Attendee(personId: 'p1', came: true, invitedOn: _day),
      Attendee(personId: 'p2', came: false, invitedOn: _day),
    ]);
    expect(fake.calls, contains('close(e1:p1|next:)'));
    expect(people.calls.where((call) => call == 'list()').length, listed + 1);
  });

  test('close succeeds even if reload fails', () async {
    final fake = _FailAfterMark([_workshop]);
    final container = _container(fake);
    await container.read(eventsProvider(_owner).future);
    final events = container.read(eventsProvider(_owner).notifier);
    await events.invite('e1', ['p1'], _day);

    await events.close('e1', [_there('p1')], const [], DateTime(2026, 10, 9));

    expect(fake.calls, contains('close(e1:p1|next:)'));
    expect(fake.calls.last, 'list()');
  });

  test('close invalidates and rethrows on failure', () async {
    final fake = FakeEventRepository([_workshop]);
    final container = _container(fake);
    await container.read(eventsProvider(_owner).future);
    final events = container.read(eventsProvider(_owner).notifier);
    fake.failWith = PeopleFailure.unknown;

    await expectLater(
      events.close('e1', const [], const [], DateTime(2026, 10, 9)),
      throwsA(PeopleFailure.unknown),
    );

    expect(fake.calls, contains('close(e1:|next:)'));
    expect(container.read(eventsProvider(_owner)).isLoading, isTrue);
  });

  test('ticking and unticking a step reload the event', () async {
    final fake = FakeEventRepository([_workshop]);
    final container = _container(fake);
    await container.read(eventsProvider(_owner).future);
    final events = container.read(eventsProvider(_owner).notifier);

    await events.tick('e1', 's1', DateTime(2026, 10, 7));
    expect(container.read(eventsProvider(_owner)).value!.single.stepsDone, {
      's1': DateTime(2026, 10, 7),
    });

    await events.untick('e1', 's1');
    expect(
      container.read(eventsProvider(_owner)).value!.single.stepsDone,
      isEmpty,
    );
    expect(fake.calls, containsAll(['tick(e1:s1)', 'untick(e1:s1)']));
  });
}

/// Fails list() once after close.
class _FailAfterMark extends FakeEventRepository {
  _FailAfterMark(super.events);

  var _failNext = false;

  @override
  Future<void> close(
    String eventId,
    List<There> there,
    Iterable<String> inviteNext,
    DateTime today,
  ) async {
    await super.close(eventId, there, inviteNext, today);
    _failNext = true;
  }

  @override
  Future<List<CalendarEvent>> list(DateTime today) async {
    if (_failNext) {
      _failNext = false;
      calls.add('list()');
      throw PeopleFailure.network;
    }
    return super.list(today);
  }
}

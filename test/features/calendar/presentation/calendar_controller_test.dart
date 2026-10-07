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
);

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
        month: DateTime(2026, 9),
        day: DateTime(2026, 9, 28),
      ));
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
  });

  test('invite and uninvite reload the event with its people', () async {
    final fake = FakeEventRepository([_workshop]);
    final container = _container(fake);
    await container.read(eventsProvider(_owner).future);
    final events = container.read(eventsProvider(_owner).notifier);

    await events.invite('e1', ['p1', 'p2']);
    expect(container.read(eventsProvider(_owner)).value!.single.attendees, [
      (personId: 'p1', came: false),
      (personId: 'p2', came: false),
    ]);

    await events.uninvite('e1', 'p1');
    expect(container.read(eventsProvider(_owner)).value!.single.attendees, [
      (personId: 'p2', came: false),
    ]);
    expect(fake.calls.where((call) => call == 'list()'), hasLength(3));
  });

  test('marking done reloads the events and the people', () async {
    final fake = FakeEventRepository([_workshop]);
    final people = FakePeopleRepository();
    final container = _container(fake, people: people);
    await container.read(eventsProvider(_owner).future);
    await container.read(peopleProvider(_owner).future);
    final listed = people.calls.where((call) => call == 'list()').length;
    final events = container.read(eventsProvider(_owner).notifier);
    await events.invite('e1', ['p1', 'p2']);

    await events.markDone('e1', ['p1'], DateTime(2026, 10, 9));
    await container.read(peopleProvider(_owner).future);

    final done = container.read(eventsProvider(_owner)).value!.single;
    expect(done.done, isTrue);
    expect(done.attendees, [
      (personId: 'p1', came: true),
      (personId: 'p2', came: false),
    ]);
    expect(fake.calls, contains('markDone(e1:p1)'));
    expect(people.calls.where((call) => call == 'list()').length, listed + 1);
  });
}

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loomia/features/auth/data/auth_repository.dart';
import 'package:loomia/features/contacts/data/activity_repository.dart';
import 'package:loomia/features/contacts/data/people_repository.dart';
import 'package:loomia/features/contacts/domain/activity.dart';
import 'package:loomia/features/contacts/domain/people_failure.dart';
import 'package:loomia/features/contacts/domain/person.dart';
import 'package:loomia/features/contacts/presentation/history_controller.dart';

import '../../auth/fake_auth_repository.dart';
import '../fake_activity_repository.dart';
import '../fake_people_repository.dart';

Activity _note(String id, int day, {int hour = 12}) => Activity(
  id: id,
  personId: 'p1',
  kind: ActivityKind.note,
  happenedOn: DateTime(2026, 9, day),
  text: 'Note $id',
  createdAt: DateTime.utc(2026, 9, 28, hour),
);

({ProviderContainer container, FakeActivityRepository activities}) _world(
  List<Activity> entries,
) {
  final activities = FakeActivityRepository(entries);
  final auth = FakeAuthRepository()..session = true;
  addTearDown(auth.dispose);
  final container = ProviderContainer.test(
    overrides: [
      activityRepositoryProvider.overrideWithValue(activities),
      // A save reloads the book, which reads the account.
      authRepositoryProvider.overrideWithValue(auth),
      peopleRepositoryProvider.overrideWithValue(FakePeopleRepository()),
    ],
  );
  // autoDispose: keep it alive the way the open page does.
  container.listen(historyProvider('p1'), (_, _) {});
  return (container: container, activities: activities);
}

List<String> _ids(ProviderContainer container) => [
  for (final entry in container.read(historyProvider('p1')).value!) entry.id,
];

void main() {
  test('loads one person, latest day first, then latest made', () async {
    final world = _world([
      _note('old', 3),
      _note('late', 20, hour: 15),
      _note('early', 20, hour: 9),
      Activity(
        id: 'other',
        personId: 'p2',
        kind: ActivityKind.note,
        happenedOn: DateTime(2026, 9, 25),
        text: 'Not Marie',
        createdAt: DateTime.utc(2026, 9, 25),
      ),
    ]);

    await world.container.read(historyProvider('p1').future);

    expect(_ids(world.container), ['late', 'early', 'old']);
    expect(world.activities.calls, ['list(p1)']);
  });

  test('add waits for the server, then places the entry', () async {
    final world = _world([_note('old', 3), _note('new', 25)]);
    await world.container.read(historyProvider('p1').future);

    await world.container.read(historyProvider('p1').notifier).add((
      kind: ActivityKind.call,
      happenedOn: DateTime(2026, 9, 10),
      text: 'Asked about the cream',
      amount: null,
    ));

    expect(_ids(world.container), ['new', 'a-0', 'old']);
    expect(world.activities.calls.last, 'add(p1)');
  });

  test('a failed add rethrows and keeps the list', () async {
    final world = _world([_note('old', 3)]);
    await world.container.read(historyProvider('p1').future);
    world.activities.failWith = PeopleFailure.network;

    await expectLater(
      world.container.read(historyProvider('p1').notifier).add((
        kind: ActivityKind.note,
        happenedOn: DateTime(2026, 9, 10),
        text: 'Lost',
        amount: null,
      )),
      throwsA(PeopleFailure.network),
    );
    expect(_ids(world.container), ['old']);
  });

  test('remove is immediate; a failure puts it back in its place', () async {
    final world = _world([_note('a', 25), _note('b', 20), _note('c', 3)]);
    await world.container.read(historyProvider('p1').future);
    world.activities
      ..failWith = PeopleFailure.network
      ..gate = Completer<void>();
    final b = world.container.read(historyProvider('p1')).value![1];

    final removing = world.container
        .read(historyProvider('p1').notifier)
        .remove(b);
    expect(_ids(world.container), ['a', 'c']);

    world.activities.gate!.complete();
    await expectLater(removing, throwsA(PeopleFailure.network));
    expect(_ids(world.container), ['a', 'b', 'c']);
  });

  test('closed while a save is in flight: nothing throws', () async {
    final activities = FakeActivityRepository();
    final auth = FakeAuthRepository()..session = true;
    addTearDown(auth.dispose);
    final container = ProviderContainer.test(
      overrides: [
        activityRepositoryProvider.overrideWithValue(activities),
        authRepositoryProvider.overrideWithValue(auth),
        peopleRepositoryProvider.overrideWithValue(FakePeopleRepository()),
      ],
    );
    // The only listener, as when the page is the last one open.
    final subscription = container.listen(historyProvider('p1'), (_, _) {});
    await container.read(historyProvider('p1').future);
    activities.gate = Completer<void>();

    final saving = container.read(historyProvider('p1').notifier).add((
      kind: ActivityKind.note,
      happenedOn: DateTime(2026, 9, 28),
      text: 'Saved after the page closed',
      amount: null,
    ));
    subscription.close();
    await Future<void>.delayed(Duration.zero);
    activities.gate!.complete();

    await expectLater(saving, completes);
    expect(activities.store.single.text, 'Saved after the page closed');
  });

  test('a stage entry sorts by the local day it was made', () async {
    final world = _world([
      _note('before', 27),
      Activity(
        id: 'moved',
        personId: 'p1',
        kind: ActivityKind.stage,
        happenedOn: DateTime(2026, 9, 27),
        stage: Stage.customer,
        createdAt: DateTime(2026, 9, 28, 0, 30).toUtc(),
      ),
    ]);

    await world.container.read(historyProvider('p1').future);

    expect(_ids(world.container), ['moved', 'before']);
  });

  test('edit waits for the server, then re-sorts the entry', () async {
    final world = _world([_note('a', 10), _note('b', 12)]);
    await world.container.read(historyProvider('p1').future);

    await world.container.read(historyProvider('p1').notifier).edit(
      world.activities.store.first,
      (
        kind: ActivityKind.note,
        happenedOn: DateTime(2026, 9, 14),
        text: 'Moved',
        amount: null,
      ),
    );

    expect(world.activities.calls.last, 'update(a)');
    expect(_ids(world.container), ['a', 'b']);
    expect(
      world.container.read(historyProvider('p1')).value!.first.text,
      'Moved',
    );
  });

  test('a failed edit rethrows and keeps the list', () async {
    final world = _world([_note('a', 10)]);
    await world.container.read(historyProvider('p1').future);
    world.activities.failWith = PeopleFailure.network;

    await expectLater(
      world.container.read(historyProvider('p1').notifier).edit(
        world.activities.store.first,
        (
          kind: ActivityKind.note,
          happenedOn: DateTime(2026, 9, 10),
          text: 'Changed',
          amount: null,
        ),
      ),
      throwsA(PeopleFailure.network),
    );
    expect(
      world.container.read(historyProvider('p1')).value!.single.text,
      'Note a',
    );
  });
}

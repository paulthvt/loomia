import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loomia/features/contacts/data/activity_repository.dart';
import 'package:loomia/features/contacts/domain/activity.dart';
import 'package:loomia/features/contacts/domain/people_failure.dart';
import 'package:loomia/features/today/presentation/done_today.dart';

import '../contacts/fake_activity_repository.dart';

final _day = DateTime(2026, 10, 12);

Activity _entry(String id, ActivityKind kind, DateTime on) => Activity(
  id: id,
  personId: 'p1',
  kind: kind,
  happenedOn: on,
  text: 'Entry $id',
  createdAt: DateTime.utc(2026, 10, 12, 9),
);

({ProviderContainer container, FakeActivityRepository activities}) _world() {
  final activities = FakeActivityRepository([
    _entry('step', ActivityKind.step, _day),
    _entry('reminder', ActivityKind.reminder, _day),
    // Logged, never on Today's list.
    _entry('call', ActivityKind.call, _day),
    _entry('yesterday', ActivityKind.step, DateTime(2026, 10, 11)),
  ]);
  final container = ProviderContainer.test(
    overrides: [activityRepositoryProvider.overrideWithValue(activities)],
  );
  return (container: container, activities: activities);
}

void main() {
  const owner = 'a@example.com';
  final key = (owner: owner, day: _day);

  test("counts the day's steps and reminders, nothing else", () async {
    final world = _world();
    world.container.listen(doneTodayProvider(key), (_, _) {});

    expect(await world.container.read(doneTodayProvider(key).future), 2);
  });

  test('add counts a tick at once', () async {
    final world = _world();
    world.container.listen(doneTodayProvider(key), (_, _) {});
    await world.container.read(doneTodayProvider(key).future);

    world.container.read(doneTodayProvider(key).notifier).add();

    expect(world.container.read(doneTodayProvider(key)).value, 3);
  });

  test('signed out: none, and nothing asked', () async {
    final world = _world();
    final signedOut = (owner: null, day: _day);
    world.container.listen(doneTodayProvider(signedOut), (_, _) {});

    expect(await world.container.read(doneTodayProvider(signedOut).future), 0);
    expect(world.activities.calls, isEmpty);
  });

  test('a failed count stays unknown, even after a tick', () async {
    final world = _world();
    world.activities.failWith = PeopleFailure.network;
    world.container.listen(doneTodayProvider(key), (_, _) {});
    await expectLater(
      world.container.read(doneTodayProvider(key).future),
      throwsA(PeopleFailure.network),
    );

    world.container.read(doneTodayProvider(key).notifier).add();

    expect(world.container.read(doneTodayProvider(key)).hasError, isTrue);
  });
}

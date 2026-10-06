import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loomia/features/auth/data/auth_repository.dart';
import 'package:loomia/features/auth/domain/account.dart';
import 'package:loomia/features/auth/domain/auth_change.dart';
import 'package:loomia/features/contacts/data/activity_repository.dart';
import 'package:loomia/features/contacts/data/people_repository.dart';
import 'package:loomia/features/contacts/domain/activity.dart';
import 'package:loomia/features/contacts/domain/people_failure.dart';
import 'package:loomia/features/contacts/domain/person.dart';
import 'package:loomia/features/contacts/presentation/history_controller.dart';
import 'package:loomia/features/contacts/presentation/people_controller.dart';
import 'package:loomia/features/workflows/domain/progress.dart';

import '../../auth/fake_auth_repository.dart';
import '../../workflows/fake_workflow_repository.dart';
import '../fake_activity_repository.dart';
import '../fake_people_repository.dart';

Person _person(
  String id,
  String name, {
  Stage stage = Stage.prospect,
  ProspectStatus? status,
}) => Person(
  id: id,
  name: name,
  stage: stage,
  prospectStatus: status,
  stageSince: DateTime.utc(2026, 3, 4),
);

typedef _World = ({
  ProviderContainer container,
  FakePeopleRepository people,
  FakeActivityRepository activities,
  FakeAuthRepository auth,
});

_World _world(List<Person> people) {
  final auth = FakeAuthRepository()
    ..session = true
    ..account = const Account(firstName: 'Pauline', email: 'p@example.com');
  addTearDown(auth.dispose);
  final activities = FakeActivityRepository();
  final repository = FakePeopleRepository(people)..activities = activities;
  final container = ProviderContainer.test(
    overrides: [
      authRepositoryProvider.overrideWithValue(auth),
      peopleRepositoryProvider.overrideWithValue(repository),
      activityRepositoryProvider.overrideWithValue(activities),
    ],
  );
  return (
    container: container,
    people: repository,
    activities: activities,
    auth: auth,
  );
}

/// The signed-in account's book, as the screens read it.
AsyncNotifierProvider<PeopleController, List<Person>> _book(
  ProviderContainer container,
) => peopleProvider(container.read(accountProvider)?.email);

List<String> _names(ProviderContainer container) => [
  for (final person in container.read(_book(container)).value!) person.name,
];

void main() {
  test('loads the book sorted by name, accents and case ignored', () async {
    final world = _world([
      _person('1', 'élodie'),
      _person('2', 'Bruno'),
      _person('3', 'Anne'),
    ]);

    await world.container.read(_book(world.container).future);

    expect(_names(world.container), ['Anne', 'Bruno', 'élodie']);
  });

  test('add keeps the list sorted and returns the new person', () async {
    final world = _world([_person('1', 'Anne'), _person('2', 'Chloé')]);
    await world.container.read(_book(world.container).future);

    final added = await world.container
        .read(_book(world.container).notifier)
        .add((
          name: 'Bruno',
          stage: Stage.customer,
          phone: null,
          email: null,
          instagram: null,
        ), today: DateTime(2026, 9, 28));

    expect(added.name, 'Bruno');
    expect(_names(world.container), ['Anne', 'Bruno', 'Chloé']);
  });

  test('save replaces the person', () async {
    final world = _world([_person('1', 'Anne')]);
    await world.container.read(_book(world.container).future);

    await world.container
        .read(_book(world.container).notifier)
        .save(_person('1', 'Anne Martin'));

    expect(_names(world.container), ['Anne Martin']);
  });

  test('remove drops the person', () async {
    final world = _world([_person('1', 'Anne'), _person('2', 'Bruno')]);
    await world.container.read(_book(world.container).future);

    await world.container.read(_book(world.container).notifier).remove(['1']);

    expect(_names(world.container), ['Bruno']);
  });

  test('remove drops everyone given, in one call', () async {
    final world = _world([
      _person('1', 'Anne'),
      _person('2', 'Bruno'),
      _person('3', 'Chloé'),
    ]);
    await world.container.read(_book(world.container).future);

    await world.container.read(_book(world.container).notifier).remove([
      '1',
      '3',
    ]);

    expect(_names(world.container), ['Bruno']);
    expect(world.people.calls.last, 'delete(1, 3)');
  });

  test('a failed save rethrows and keeps the list', () async {
    final world = _world([_person('1', 'Anne')]);
    await world.container.read(_book(world.container).future);
    world.people.failWith = PeopleFailure.network;

    await expectLater(
      world.container
          .read(_book(world.container).notifier)
          .save(_person('1', 'Changed')),
      throwsA(PeopleFailure.network),
    );
    await expectLater(
      world.container.read(_book(world.container).notifier).remove(['1']),
      throwsA(PeopleFailure.network),
    );

    expect(_names(world.container), ['Anne']);
  });

  test('setStatus shows the change before the save returns', () async {
    final world = _world([_person('1', 'Anne')]);
    await world.container.read(_book(world.container).future);
    world.people.gate = Completer<void>();

    final saving = world.container
        .read(_book(world.container).notifier)
        .setStatus(_person('1', 'Anne'), ProspectStatus.thinking);

    expect(
      world.container.read(_book(world.container)).value!.single.prospectStatus,
      ProspectStatus.thinking,
    );
    world.people.gate!.complete();
    await saving;
    expect(world.people.store['1']!.prospectStatus, ProspectStatus.thinking);
  });

  test('setStatus rolls back on failure and rethrows', () async {
    final world = _world([
      _person('1', 'Anne', status: ProspectStatus.interested),
    ]);
    await world.container.read(_book(world.container).future);
    world.people.failWith = PeopleFailure.network;

    await expectLater(
      world.container
          .read(_book(world.container).notifier)
          .setStatus(_person('1', 'Anne'), ProspectStatus.notNow),
      throwsA(PeopleFailure.network),
    );

    expect(
      world.container.read(_book(world.container)).value!.single.prospectStatus,
      ProspectStatus.interested,
    );
  });

  test('setStatus rolls back only its own change', () async {
    final world = _world([
      _person('1', 'Anne', status: ProspectStatus.interested),
    ]);
    await world.container.read(_book(world.container).future);
    final controller = world.container.read(_book(world.container).notifier);
    final first = Completer<void>();
    final second = Completer<void>();

    world.people
      ..gate = first
      ..failWith = PeopleFailure.network;
    final failing = controller.setStatus(
      _person('1', 'Anne'),
      ProspectStatus.thinking,
    );
    world.people
      ..gate = second
      ..failWith = null;
    final succeeding = controller.setStatus(
      _person('1', 'Anne'),
      ProspectStatus.notNow,
    );

    first.complete();
    await expectLater(failing, throwsA(PeopleFailure.network));
    second.complete();
    await succeeding;

    expect(
      world.container.read(_book(world.container)).value!.single.prospectStatus,
      ProspectStatus.notNow,
    );
  });

  test('switching account reloads and never shows the previous book', () async {
    final world = _world([_person('1', 'Anne')]);
    await world.container.read(_book(world.container).future);

    world.auth
      ..session = false
      ..account = null
      ..emit(AuthChange.signedOut);
    await Future<void>.delayed(Duration.zero);
    await world.container.read(_book(world.container).future);
    expect(world.container.read(_book(world.container)).value, isEmpty);

    world.people.store
      ..clear()
      ..['9'] = _person('9', 'Zoé');
    world.people.gate = Completer<void>();
    world.auth
      ..session = true
      ..account = const Account(firstName: 'Zoé', email: 'z@example.com')
      ..emit(AuthChange.signedIn);
    await Future<void>.delayed(Duration.zero);

    // Loading the new book: the old one is not on screen meanwhile.
    expect(world.container.read(_book(world.container)).hasValue, isFalse);
    world.people.gate!.complete();
    await world.container.read(_book(world.container).future);
    expect(_names(world.container), ['Zoé']);
  });

  test('the next account never inherits the book, even unwatched', () async {
    final world = _world([_person('1', 'Anne')]);
    // Read, not listened: nothing is watching the book when the user signs out,
    // as when they leave Contacts for Settings first.
    await world.container.read(_book(world.container).future);

    world.auth
      ..session = false
      ..account = null
      ..emit(AuthChange.signedOut);
    await Future<void>.delayed(Duration.zero);

    world.people.store.clear();
    world.people.failWith = PeopleFailure.network;
    world.auth
      ..session = true
      ..account = const Account(firstName: 'Zoé', email: 'z@example.com')
      ..emit(AuthChange.signedIn);
    await Future<void>.delayed(Duration.zero);

    final loading = world.container.read(_book(world.container));
    expect(loading.hasValue, isFalse);
    await expectLater(
      world.container.read(_book(world.container).future),
      throwsA(PeopleFailure.network),
    );
    final failed = world.container.read(_book(world.container));
    expect(failed.hasError, isTrue);
    expect(failed.hasValue, isFalse);
  });

  test('is stale a minute after the last load', () async {
    final world = _world([]);
    await world.container.read(_book(world.container).future);
    final controller = world.container.read(_book(world.container).notifier);
    final now = DateTime.now();

    expect(controller.isStaleAt(now), isFalse);
    expect(
      controller.isStaleAt(
        now.add(PeopleController.staleAfter + const Duration(seconds: 1)),
      ),
      isTrue,
    );
  });

  test(
    'moveTo takes what the server returns and reloads the history',
    () async {
      final world = _world([
        _person('p1', 'Marie', status: ProspectStatus.interested),
      ]);
      final book = _book(world.container);
      await world.container.read(book.future);
      world.container.listen(historyProvider('p1'), (_, _) {});
      await world.container.read(historyProvider('p1').future);
      final marie = world.container.read(book).value!.single;

      await world.container.read(book.notifier).moveTo([marie], Stage.customer);

      final moved = world.container.read(book).value!.single;
      expect(moved.stage, Stage.customer);
      expect(moved.prospectStatus, isNull);
      expect(moved.stageSince, DateTime.utc(2026, 9, 28));
      final history = await world.container.read(historyProvider('p1').future);
      expect(history.single.kind, ActivityKind.stage);
      expect(world.activities.calls, ['list(p1)', 'list(p1)']);
    },
  );

  test('moveTo moves everyone given in one call', () async {
    final world = _world([
      _person('p1', 'Marie'),
      _person('p2', 'Nina', stage: Stage.customer),
      _person('p3', 'Olga'),
    ]);
    final book = _book(world.container);
    await world.container.read(book.future);
    final [marie, nina, _] = world.container.read(book).value!;

    await world.container.read(book.notifier).moveTo([marie, nina], Stage.team);

    expect(
      [for (final person in world.container.read(book).value!) person.stage],
      [Stage.team, Stage.team, Stage.prospect],
    );
    expect(world.people.calls.last, 'setStage(p1, p2, team)');
  });

  test('a failed moveTo rethrows and changes nothing', () async {
    final world = _world([_person('p1', 'Marie')]);
    final book = _book(world.container);
    await world.container.read(book.future);
    final marie = world.container.read(book).value!.single;
    world.people.failWith = PeopleFailure.network;

    await expectLater(
      world.container.read(book.notifier).moveTo([marie], Stage.team),
      throwsA(PeopleFailure.network),
    );
    expect(world.container.read(book).value!.single.stage, Stage.prospect);
  });

  final samples = FakeWorkflowRepository.samples().first;
  final customer = FakeWorkflowRepository.samples()[2];
  final day = DateTime(2026, 9, 28);
  WorkflowPlace at(num position, {String workflowId = 'samples'}) =>
      (workflowId: workflowId, atPosition: position, lastTick: day);
  Person onSamples(num position, {DateTime? pausedAt}) => Person(
    id: 'p1',
    name: 'Marie',
    stage: Stage.prospect,
    stageSince: DateTime.utc(2026, 3, 4),
    place: at(position),
    pausedAt: pausedAt,
  );

  test('add starts the given workflow, due its first step today', () async {
    final world = _world([]);
    final book = _book(world.container);
    await world.container.read(book.future);

    final added = await world.container
        .read(book.notifier)
        .add(
          (
            name: 'Bruno',
            stage: Stage.prospect,
            phone: null,
            email: null,
            instagram: null,
          ),
          workflow: samples,
          today: day,
        );

    expect(added.place, at(1));
  });

  test('add with no workflow starts none', () async {
    final world = _world([]);
    final book = _book(world.container);
    await world.container.read(book.future);

    final added = await world.container.read(book.notifier).add((
      name: 'Bruno',
      stage: Stage.prospect,
      phone: null,
      email: null,
      instagram: null,
    ), today: day);

    expect(added.place, isNull);
  });

  test('addAll saves everyone in one call, sorted, on the workflow', () async {
    final world = _world([_person('1', 'Chloé')]);
    final book = _book(world.container);
    await world.container.read(book.future);

    PersonDraft draft(String name) => (
      name: name,
      stage: Stage.prospect,
      phone: null,
      email: null,
      instagram: null,
    );
    final added = await world.container
        .read(book.notifier)
        .addAll([draft('Denis'), draft('Anne')], workflow: samples, today: day);

    expect(world.people.calls.last, 'addAll(Denis, Anne)');
    expect(added.map((person) => person.place), [at(1), at(1)]);
    expect(_names(world.container), ['Anne', 'Chloé', 'Denis']);
  });

  test('moveTo writes the stage and what follows in one call', () async {
    final world = _world([onSamples(3)]);
    final book = _book(world.container);
    await world.container.read(book.future);
    final marie = world.container.read(book).value!.single;

    await world.container
        .read(book.notifier)
        .moveTo(
          [marie],
          Stage.customer,
          follow: (workflow: customer, firstDue: DateTime(2026, 10, 1)),
        );

    final moved = world.container.read(book).value!.single;
    expect(moved.stage, Stage.customer);
    expect(moved.place, (
      workflowId: 'new-customer',
      atPosition: 1,
      lastTick: DateTime(2026, 10, 1),
    ));
    expect(world.people.calls.last, 'setStage(p1, customer)');
  });

  test('moveTo with nothing to follow ends the workflow', () async {
    final world = _world([onSamples(3)]);
    final book = _book(world.container);
    await world.container.read(book.future);
    final marie = world.container.read(book).value!.single;

    await world.container.read(book.notifier).moveTo([marie], Stage.team);

    expect(world.container.read(book).value!.single.place, isNull);
  });

  test('setWorkflow changes the workflow and ends a pause', () async {
    final world = _world([onSamples(3, pausedAt: DateTime.utc(2026, 7, 12))]);
    final book = _book(world.container);
    await world.container.read(book.future);
    final marie = world.container.read(book).value!.single;
    final health = FakeWorkflowRepository.samples()[1];

    await world.container
        .read(book.notifier)
        .setWorkflow([marie], (workflow: health, firstDue: day));

    final changed = world.container.read(book).value!.single;
    expect(changed.place?.workflowId, 'health');
    expect(changed.pausedAt, isNull);
  });

  test('setWorkflow changes everyone given in one call', () async {
    final world = _world([_person('p1', 'Marie'), _person('p2', 'Nina')]);
    final book = _book(world.container);
    await world.container.read(book.future);
    final both = world.container.read(book).value!;

    await world.container.read(book.notifier).setWorkflow(both, (
      workflow: samples,
      firstDue: day,
    ));

    expect([
      for (final person in world.container.read(book).value!) person.place,
    ], everyElement(isNotNull));
    expect(world.people.calls.last, 'setPlace(p1, p2, samples)');
  });

  test('setWorkflow to nothing clears the place', () async {
    final world = _world([onSamples(3)]);
    final book = _book(world.container);
    await world.container.read(book.future);
    final marie = world.container.read(book).value!.single;

    await world.container.read(book.notifier).setWorkflow([marie], null);

    expect(world.container.read(book).value!.single.place, isNull);
    expect(world.people.calls.last, 'setPlace(p1, none)');
  });

  test('completeStep moves to the next step and reloads the history', () async {
    final world = _world([onSamples(2)]);
    final book = _book(world.container);
    await world.container.read(book.future);
    world.container.listen(historyProvider('p1'), (_, _) {});
    await world.container.read(historyProvider('p1').future);
    final marie = world.container.read(book).value!.single;
    final progress = progressOf(marie, samples)! as OnStep;

    await world.container
        .read(book.notifier)
        .completeStep(marie, progress, DateTime(2026, 9, 30));

    final moved = world.container.read(book).value!.single;
    expect(moved.place, (
      workflowId: 'samples',
      atPosition: 3,
      lastTick: DateTime(2026, 9, 30),
    ));
    expect(world.people.calls.last, 'completeStep(p1, samples-2)');
    await world.container.read(historyProvider('p1').future);
    expect(world.activities.calls, ['list(p1)', 'list(p1)']);
  });

  test('a stale tick is refused and changes nothing', () async {
    final world = _world([onSamples(2)]);
    final book = _book(world.container);
    await world.container.read(book.future);
    final marie = world.container.read(book).value!.single;
    final progress = progressOf(marie, samples)! as OnStep;
    // Ticked on another device in the meantime.
    world.people.store['p1'] = onSamples(3);

    await expectLater(
      world.container
          .read(book.notifier)
          .completeStep(marie, progress, DateTime(2026, 9, 30)),
      throwsA(PeopleFailure.unknown),
    );
    expect(world.container.read(book).value!.single.place?.atPosition, 2);
  });

  test('pause marks a prospect Not now; resume counts from today', () async {
    final world = _world([onSamples(2)]);
    final book = _book(world.container);
    await world.container.read(book.future);
    final notifier = world.container.read(book.notifier);

    await notifier.pause(world.container.read(book).value!.single);
    final paused = world.container.read(book).value!.single;
    expect(paused.pausedAt, isNotNull);
    expect(paused.prospectStatus, ProspectStatus.notNow);

    await notifier.resume(paused, DateTime(2026, 10, 5));
    final resumed = world.container.read(book).value!.single;
    expect(resumed.pausedAt, isNull);
    expect(resumed.place?.atPosition, 2);
    expect(resumed.place?.lastTick, DateTime(2026, 10, 5));
  });

  test('pause leaves a customer with no status', () async {
    final world = _world([
      Person(
        id: 'c1',
        name: 'Claire',
        stage: Stage.customer,
        stageSince: DateTime.utc(2026, 3, 4),
        place: at(1, workflowId: 'new-customer'),
      ),
    ]);
    final book = _book(world.container);
    await world.container.read(book.future);

    await world.container
        .read(book.notifier)
        .pause(world.container.read(book).value!.single);

    final paused = world.container.read(book).value!.single;
    expect(paused.pausedAt, isNotNull);
    expect(paused.prospectStatus, isNull);
  });

  test('a failed write rethrows and changes nothing', () async {
    final world = _world([onSamples(2)]);
    final book = _book(world.container);
    await world.container.read(book.future);
    final notifier = world.container.read(book.notifier);
    final marie = world.container.read(book).value!.single;
    final progress = progressOf(marie, samples)! as OnStep;
    world.people.failWith = PeopleFailure.network;

    for (final write in <Future<void> Function()>[
      () => notifier.completeStep(marie, progress, day),
      () => notifier.pause(marie),
      () => notifier.resume(marie, day),
      () => notifier.setWorkflow([marie], null),
      () => notifier.moveTo([marie], Stage.customer),
      () => notifier.add(
        (
          name: 'Bruno',
          stage: Stage.prospect,
          phone: null,
          email: null,
          instagram: null,
        ),
        workflow: samples,
        today: day,
      ),
    ]) {
      await expectLater(write(), throwsA(PeopleFailure.network));
    }
    // Person has no ==: the very same instance is still there.
    expect(world.container.read(book).value!.single, same(marie));
  });

  test('the book rebuilt while a step completes: no throw', () async {
    final world = _world([onSamples(2)]);
    final book = _book(world.container);
    world.container.listen(book, (_, _) {});
    await world.container.read(book.future);
    final marie = world.container.read(book).value!.single;
    final progress = progressOf(marie, samples)! as OnStep;
    world.people.gate = Completer<void>();

    final ticking = world.container
        .read(book.notifier)
        .completeStep(marie, progress, day);
    world.container.invalidate(book);
    world.people.gate!.complete();

    await ticking;
    final reloaded = await world.container.read(book.future);
    expect(reloaded.single.id, 'p1');
  });

  group('last contact', () {
    test('logging reloads the book, so last contact follows', () async {
      final world = _world([_person('p1', 'Marie')]);
      final book = _book(world.container);
      world.container.listen(historyProvider('p1'), (_, _) {});
      await world.container.read(book.future);
      await world.container.read(historyProvider('p1').future);
      world.people.calls.clear();

      await world.container.read(historyProvider('p1').notifier).add((
        kind: ActivityKind.call,
        happenedOn: DateTime(2026, 9, 29),
        text: 'Hi',
        amount: null,
      ));
      final reloaded = await world.container.read(book.future);

      expect(world.people.calls, ['list()']);
      expect(reloaded.single.lastContactOn, DateTime(2026, 9, 29));
    });

    test('deleting the entry reloads it back to nothing', () async {
      final world = _world([_person('p1', 'Marie')]);
      final book = _book(world.container);
      world.container.listen(historyProvider('p1'), (_, _) {});
      await world.container.read(book.future);
      await world.container.read(historyProvider('p1').future);
      final history = world.container.read(historyProvider('p1').notifier);
      await history.add((
        kind: ActivityKind.call,
        happenedOn: DateTime(2026, 9, 29),
        text: 'Hi',
        amount: null,
      ));
      await world.container.read(book.future);

      await history.remove(
        world.container.read(historyProvider('p1')).value!.single,
      );
      final reloaded = await world.container.read(book.future);

      expect(reloaded.single.lastContactOn, isNull);
    });

    test('a sheet closed while saving still reloads the book', () async {
      final world = _world([_person('p1', 'Marie')]);
      final book = _book(world.container);
      // The Log sheet is the history's only listener, as on Team.
      final sheet = world.container.listen(historyProvider('p1'), (_, _) {});
      await world.container.read(book.future);
      await world.container.read(historyProvider('p1').future);
      final gate = world.activities.gate = Completer<void>();

      final saving = world.container.read(historyProvider('p1').notifier).add((
        kind: ActivityKind.call,
        happenedOn: DateTime(2026, 9, 29),
        text: 'Hi',
        amount: null,
      ));
      sheet.close();
      await Future<void>.delayed(Duration.zero);
      gate.complete();
      await saving;
      final reloaded = await world.container.read(book.future);

      expect(reloaded.single.lastContactOn, DateTime(2026, 9, 29));
    });

    test('a stage change is no contact', () async {
      final world = _world([_person('p1', 'Marie')]);
      world.activities.recordStage('p1', Stage.team);

      final book = await world.container.read(_book(world.container).future);

      expect(book.single.lastContactOn, isNull);
    });
  });
}

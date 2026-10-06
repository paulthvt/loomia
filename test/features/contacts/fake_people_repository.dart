import 'dart:async';

import 'package:loomia/features/contacts/data/people_repository.dart';
import 'package:loomia/features/contacts/domain/activity.dart';
import 'package:loomia/features/contacts/domain/people_failure.dart';
import 'package:loomia/features/contacts/domain/person.dart';
import 'package:loomia/features/workflows/domain/workflow.dart';

import '../workflows/fake_workflow_repository.dart';
import '../workflows/server_rule.dart';
import 'fake_activity_repository.dart';

/// An in-memory book that records calls, and fails or stalls on demand.
class FakePeopleRepository implements PeopleRepository {
  FakePeopleRepository([Iterable<Person> people = const []]) {
    for (final person in people) {
      store[person.id] = person;
    }
  }

  final Map<String, Person> store = {};

  /// One entry per call, e.g. `update(p1)`.
  final List<String> calls = <String>[];

  /// Thrown by calls started while set. Use a `PeopleFailure`.
  Object? failWith;

  /// Calls started while set wait on it.
  Completer<void>? gate;

  /// Where [setStage] writes its history entry, as the database does. Unset,
  /// stage changes leave no entry.
  FakeActivityRepository? activities;

  /// What the server's computed fields read. Tests may store people without
  /// them: every person returned gets them from here, as the database would.
  List<Workflow> workflows = FakeWorkflowRepository.samples();

  Person _served(Person person) {
    final served = withServerFields(person, workflows);
    final history = activities;
    if (history == null) return served;
    // As last_contact_on: the latest entry that is not a stage change.
    final days = [
      for (final entry in history.store)
        if (entry.personId == person.id && entry.kind != ActivityKind.stage)
          entry.happenedOn,
    ]..sort();
    return withLastContact(served, days.lastOrNull);
  }

  var _next = 0;

  Future<void> _record(String call) async {
    calls.add(call);
    // Captured now: a later change applies to later calls only.
    final failure = failWith;
    final wait = gate;
    if (wait != null) await wait.future;
    if (failure != null) throw failure;
  }

  @override
  Future<List<Person>> list() async {
    await _record('list()');
    return store.values.map(_served).toList();
  }

  @override
  Future<Person> add(PersonDraft draft, {WorkflowPlace? place}) async {
    await _record('add(${draft.name})');
    final person = Person(
      id: 'new-${_next++}',
      name: draft.name.trim(),
      stage: draft.stage,
      stageSince: DateTime.utc(2026, 9, 28),
      phone: draft.phone,
      email: draft.email,
      instagram: draft.instagram,
      place: place,
    );
    store[person.id] = person;
    return _served(person);
  }

  @override
  Future<List<Person>> addAll(
    List<PersonDraft> drafts, {
    WorkflowPlace? place,
    DateTime? stageSince,
  }) async {
    await _record('addAll(${drafts.map((draft) => draft.name).join(', ')})');
    final added = <Person>[];
    for (final draft in drafts) {
      final person = Person(
        id: 'new-${_next++}',
        name: draft.name.trim(),
        stage: draft.stage,
        stageSince: stageSince ?? DateTime.utc(2026, 9, 28),
        phone: draft.phone,
        email: draft.email,
        place: place,
      );
      store[person.id] = person;
      added.add(_served(person));
    }
    return added;
  }

  @override
  Future<Person> update(Person person, {DateTime? stageSince}) async {
    await _record('update(${person.id})');
    // The real update writes neither the stage nor the workflow fields.
    final stored = store[person.id]!;
    final saved = Person(
      id: person.id,
      name: person.name,
      stage: stored.stage,
      stageSince: stageSince ?? stored.stageSince,
      prospectStatus: stored.stage == Stage.prospect
          ? person.prospectStatus
          : null,
      phone: person.phone,
      email: person.email,
      instagram: person.instagram,
      needs: person.needs,
      products: person.products,
      profession: person.profession,
      address: person.address,
      notes: person.notes,
      why: person.why,
      ownGoal: person.ownGoal,
      timeAvailable: person.timeAvailable,
      wouldLoveTo: person.wouldLoveTo,
      strengths: person.strengths,
      stuckOn: person.stuckOn,
      currentLevel: person.currentLevel,
      targetLevel: person.targetLevel,
      targetLevelBy: person.targetLevelBy,
      monthlyVolumeTarget: person.monthlyVolumeTarget,
      place: stored.place,
      pausedAt: stored.pausedAt,
    );
    store[person.id] = saved;
    // As the trigger: the latest stage entry follows a corrected since.
    if (stageSince != null) activities?.moveLatestStage(person.id, stageSince);
    return _served(saved);
  }

  @override
  Future<void> delete(List<String> ids) async {
    await _record('delete(${ids.join(', ')})');
    ids.forEach(store.remove);
  }

  /// What the database does on a stage change: a new [Person.stageSince], no
  /// status outside prospects, no pause, and an entry in the history.
  @override
  Future<List<Person>> setStage(
    List<String> ids,
    Stage stage, {
    WorkflowPlace? place,
  }) async {
    await _record('setStage(${ids.join(', ')}, ${stage.name})');
    final moved = <Person>[];
    for (final id in ids) {
      final before = store[id];
      if (before == null) continue;
      moved.add(
        _with(
          before,
          stage: stage,
          stageSince: DateTime.utc(2026, 9, 28),
          status: before.prospectStatus,
          place: place,
          pausedAt: null,
        ),
      );
      activities?.recordStage(id, stage);
    }
    return moved;
  }

  @override
  Future<Person> setStageSince(String id, DateTime at) async {
    await _record('setStageSince($id)');
    final moved = _with(
      store[id]!,
      stageSince: at.toUtc(),
      place: store[id]!.place,
      pausedAt: store[id]!.pausedAt,
    );
    activities?.moveLatestStage(id, at);
    return moved;
  }

  @override
  Future<List<Person>> setPlace(List<String> ids, WorkflowPlace? place) async {
    await _record(
      'setPlace(${ids.join(', ')}, ${place?.workflowId ?? 'none'})',
    );
    return [
      for (final id in ids)
        if (store[id] case final before?)
          _with(before, place: place, pausedAt: null),
    ];
  }

  @override
  Future<Person> pause(String id, DateTime at, {required bool notNow}) async {
    await _record('pause($id)');
    final before = store[id]!;
    return _with(
      before,
      status: notNow ? ProspectStatus.notNow : before.prospectStatus,
      place: before.place,
      pausedAt: at,
    );
  }

  @override
  Future<Person> resume(String id, DateTime today) async {
    await _record('resume($id)');
    final before = store[id]!;
    final place = before.place;
    return _with(
      before,
      place: place == null
          ? null
          : (
              workflowId: place.workflowId,
              atPosition: place.atPosition,
              lastTick: today,
            ),
      pausedAt: null,
    );
  }

  @override
  Future<Person> completeStep(
    String personId,
    String stepId,
    DateTime on,
  ) async {
    await _record('completeStep($personId, $stepId)');
    final before = _served(store[personId]!);
    // The database refuses anything but the current step (a stale tick).
    if (before.currentStepId != stepId) throw PeopleFailure.unknown;
    final place = before.place!;
    return _with(
      before,
      place: (
        workflowId: place.workflowId,
        atPosition: positionAfter(
          findWorkflow(workflows, place.workflowId)!,
          stepId,
        ),
        lastTick: on,
      ),
      pausedAt: before.pausedAt,
    );
  }

  /// [before] with the given fields replaced, stored and returned. Stage and
  /// status default to [before]'s; a status never survives outside prospects.
  Person _with(
    Person before, {
    Stage? stage,
    DateTime? stageSince,
    ProspectStatus? status,
    required WorkflowPlace? place,
    required DateTime? pausedAt,
  }) {
    final newStage = stage ?? before.stage;
    final person = Person(
      id: before.id,
      name: before.name,
      stage: newStage,
      stageSince: stageSince ?? before.stageSince,
      prospectStatus: newStage == Stage.prospect
          ? status ?? before.prospectStatus
          : null,
      phone: before.phone,
      email: before.email,
      instagram: before.instagram,
      needs: before.needs,
      products: before.products,
      profession: before.profession,
      address: before.address,
      notes: before.notes,
      why: before.why,
      ownGoal: before.ownGoal,
      timeAvailable: before.timeAvailable,
      wouldLoveTo: before.wouldLoveTo,
      strengths: before.strengths,
      stuckOn: before.stuckOn,
      currentLevel: before.currentLevel,
      targetLevel: before.targetLevel,
      targetLevelBy: before.targetLevelBy,
      monthlyVolumeTarget: before.monthlyVolumeTarget,
      place: place,
      pausedAt: pausedAt,
    );
    store[person.id] = person;
    return _served(person);
  }
}

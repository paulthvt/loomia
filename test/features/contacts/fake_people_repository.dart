import 'dart:async';

import 'package:loomia/features/contacts/data/people_repository.dart';
import 'package:loomia/features/contacts/domain/activity.dart';
import 'package:loomia/features/contacts/domain/people_failure.dart';
import 'package:loomia/features/contacts/domain/person.dart';
import 'package:loomia/features/workflows/domain/progress.dart';
import 'package:loomia/features/workflows/domain/workflow.dart';

import '../workflows/fake_workflow_repository.dart';
import '../workflows/server_rule.dart';
import 'fake_activity_repository.dart';

/// An in-memory book that records calls, and fails or stalls on demand.
class FakePeopleRepository implements PeopleRepository {
  FakePeopleRepository([Iterable<Person> people = const []]) {
    for (final person in people) {
      store[person.id] = person;
      if (person.reminders.isNotEmpty) reminders[person.id] = person.reminders;
    }
  }

  final Map<String, Person> store = {};

  /// Open reminders by person id, as the embedded `reminder(...)` reads them.
  /// Seeded from the people given.
  final Map<String, List<Reminder>> reminders = {};

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

  /// Person id → an open event they attend, as `planned_event_id` would find
  /// it on their event step. Tests set it; the fake never plans.
  final Map<String, String> plannedEvents = {};

  Person _served(Person person) {
    final served = withServerFields(
      person,
      workflows,
      plannedEventId: plannedEvents[person.id],
    ).withReminders(reminders[person.id] ?? const []);
    final history = activities;
    if (history == null) return served;
    // As last_contact_on: the latest entry that is neither a stage change
    // nor an event.
    final days = [
      for (final entry in history.store)
        if (entry.personId == person.id &&
            entry.kind != ActivityKind.stage &&
            entry.kind != ActivityKind.event)
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
        // Inserted now; the stage may be backdated.
        createdAt: DateTime.utc(2026, 9, 28),
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
      createdAt: stored.createdAt,
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
      // As personToRow: an update never writes the photo, nor the LRP.
      photoPath: stored.photoPath,
      loyaltySince: stored.loyaltySince,
      loyaltyDay: stored.loyaltyDay,
      loyaltyCheckedFor: stored.loyaltyCheckedFor,
    );
    store[person.id] = saved;
    // As the trigger: the latest stage entry follows a corrected since.
    if (stageSince != null) activities?.moveLatestStage(person.id, stageSince);
    return _served(saved);
  }

  @override
  Future<Person> setPhoto(String id, String? path) async {
    await _record('setPhoto($id, $path)');
    final before = store[id]!;
    return _with(
      before,
      place: before.place,
      pausedAt: before.pausedAt,
      photoPath: () => path,
    );
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
  Future<List<Person>> setTags(
    List<String> ids,
    Set<String> add,
    Set<String> remove,
  ) async {
    await _record(
      'setTags(${ids.join(', ')}, +${add.join('+')}, -${remove.join('-')})',
    );
    return [
      for (final id in ids)
        if (store[id] case final before?)
          store[id] = before.withTagIds(
            before.tagIds.union(add).difference(remove),
          ),
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
    final raw = store[personId]!;
    final entries = activities?.store.length ?? 0;
    final before = _served(raw);
    // The database refuses anything but the current step (a stale tick).
    if (before.currentStepId != stepId) throw PeopleFailure.unknown;
    final place = before.place!;
    final step = findWorkflow(
      workflows,
      place.workflowId,
    )!.steps.firstWhere((step) => step.id == stepId);
    // As complete_step: the first loyalty step starts their LRP.
    final starts = step.loyaltySetup && before.loyaltySince == null;
    final moved = _with(
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
      loyaltySince: starts ? () => on : null,
    );
    // As complete_step's step entry. The row comes back as PostgREST reads
    // it: last_contact_on from before that entry, in the call's snapshot.
    activities?.store.add(
      Activity(
        id: 'a-step-${_next++}',
        personId: personId,
        kind: ActivityKind.step,
        happenedOn: on,
        text: step.label,
        createdAt: DateTime.utc(2026, 10, 8, 12),
      ),
    );
    if (starts) _addLoyaltyEntry(personId, ActivityKind.loyaltyStart, on);
    _snapshot(moved, raw, entries);
    return withLastContact(moved, before.lastContactOn);
  }

  /// As postpone_step: the current event step only, due on [until].
  @override
  Future<Person> postponeStep(
    String personId,
    String stepId,
    DateTime until,
  ) async {
    await _record('postponeStep($personId:$stepId:${dayColumn(until)})');
    final before = _served(store[personId]!);
    final place = before.place;
    final step = place == null
        ? null
        : findWorkflow(
            workflows,
            place.workflowId,
          )?.steps.where((step) => step.id == stepId).firstOrNull;
    if (before.currentStepId != stepId || step == null || !step.isEvent) {
      throw PeopleFailure.unknown;
    }
    return _with(
      before,
      place: (
        workflowId: place!.workflowId,
        atPosition: place.atPosition,
        lastTick: addDays(until, -step.days),
      ),
      pausedAt: before.pausedAt,
    );
  }

  @override
  Future<Person> setLoyalty(
    String personId,
    DateTime? since,
    DateTime today,
  ) async {
    await _record('setLoyalty($personId)');
    final before = store[personId]!;
    if (before.loyaltySince == since) return _served(before);
    // As set_loyalty: a stop entry, a start entry, or the latest start moved.
    if (since == null) {
      _addLoyaltyEntry(personId, ActivityKind.loyaltyStop, today);
    } else {
      final history = activities?.store;
      final latest = before.loyaltySince == null || history == null
          ? -1
          : history.lastIndexWhere(
              (entry) =>
                  entry.personId == personId &&
                  entry.kind == ActivityKind.loyaltyStart,
            );
      if (latest < 0) {
        _addLoyaltyEntry(personId, ActivityKind.loyaltyStart, since);
      } else {
        final entry = history![latest];
        history[latest] = Activity(
          id: entry.id,
          personId: personId,
          kind: entry.kind,
          happenedOn: since,
          createdAt: entry.createdAt,
        );
      }
    }
    return _served(
      _with(
        before,
        place: before.place,
        pausedAt: before.pausedAt,
        loyaltySince: () => since,
        // As set_loyalty: a start fills the day, a move keeps it, a stop
        // clears it and the check.
        loyaltyDay: () => since == null
            ? null
            : before.loyaltyDay ?? (since.day > 28 ? 28 : since.day),
        loyaltyCheckedFor: () =>
            since == null ? null : before.loyaltyCheckedFor,
      ),
    );
  }

  @override
  Future<Person> setLoyaltyDay(String id, int day) async {
    await _record('setLoyaltyDay($id, $day)');
    final before = store[id]!;
    return _with(
      before,
      place: before.place,
      pausedAt: before.pausedAt,
      loyaltyDay: () => day,
    );
  }

  /// As check_loyalty: a reminder entry, the renewal checked, once.
  @override
  Future<Person> checkLoyalty(
    String personId,
    DateTime renewal,
    DateTime on,
    String text,
  ) async {
    await _record('checkLoyalty($personId:${dayColumn(renewal)})');
    final before = store[personId]!;
    if (before.loyaltySince == null) throw PeopleFailure.unknown;
    if (before.loyaltyCheckedFor == renewal) return _served(before);
    final entries = activities?.store.length ?? 0;
    activities?.store.add(
      Activity(
        id: 'a-reminder-${_next++}',
        personId: personId,
        kind: ActivityKind.reminder,
        happenedOn: on,
        text: text,
        createdAt: DateTime.utc(2026, 10, 8, 12),
      ),
    );
    final checked = _with(
      before,
      place: before.place,
      pausedAt: before.pausedAt,
      loyaltyCheckedFor: () => renewal,
    );
    _snapshot(checked, before, entries);
    return checked;
  }

  void _addLoyaltyEntry(String personId, ActivityKind kind, DateTime on) =>
      activities?.store.add(
        Activity(
          id: 'a-loyalty-${_next++}',
          personId: personId,
          kind: kind,
          happenedOn: on,
          createdAt: DateTime.utc(2026, 10, 8, 12),
        ),
      );

  @override
  Future<Reminder> addReminder(
    String personId,
    String text,
    DateTime dueOn,
  ) async {
    await _record('addReminder($personId)');
    final Reminder reminder = (
      id: 'r-${_next++}',
      text: text.trim(),
      dueOn: dueOn,
      createdAt: DateTime.utc(2026, 10, 8, 12, 0, _next),
    );
    (reminders[personId] ??= []).add(reminder);
    return reminder;
  }

  @override
  Future<Reminder> updateReminder(
    String id,
    String text,
    DateTime dueOn,
  ) async {
    await _record('updateReminder($id)');
    for (final list in reminders.values) {
      final index = list.indexWhere((reminder) => reminder.id == id);
      if (index < 0) continue;
      final Reminder saved = (
        id: id,
        text: text.trim(),
        dueOn: dueOn,
        createdAt: list[index].createdAt,
      );
      list[index] = saved;
      return saved;
    }
    throw PeopleFailure.unknown;
  }

  @override
  Future<void> deleteReminder(String id) async {
    await _record('deleteReminder($id)');
    for (final list in reminders.values) {
      list.removeWhere((reminder) => reminder.id == id);
    }
  }

  /// As `complete_reminder`: the entry, the delete; one already gone is
  /// refused.
  @override
  Future<void> completeReminder(String id, DateTime on) async {
    await _record('completeReminder($id)');
    final MapEntry(key: personId, value: list) = reminders.entries.firstWhere(
      (entry) => entry.value.any((reminder) => reminder.id == id),
      orElse: () => throw PeopleFailure.unknown,
    );
    final reminder = list.firstWhere((reminder) => reminder.id == id);
    list.remove(reminder);
    final history = activities;
    if (history == null) {
      store[personId] = withLastContact(store[personId]!, on);
    } else {
      history.store.add(
        Activity(
          id: 'a-$id',
          personId: personId,
          kind: ActivityKind.reminder,
          happenedOn: on,
          text: reminder.text,
          createdAt: DateTime.utc(2026, 10, 8, 12),
        ),
      );
    }
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
    String? Function()? photoPath,
    DateTime? Function()? loyaltySince,
    int? Function()? loyaltyDay,
    DateTime? Function()? loyaltyCheckedFor,
  }) {
    final newStage = stage ?? before.stage;
    final person = Person(
      id: before.id,
      name: before.name,
      stage: newStage,
      stageSince: stageSince ?? before.stageSince,
      createdAt: before.createdAt,
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
      photoPath: photoPath == null ? before.photoPath : photoPath(),
      loyaltySince: loyaltySince == null ? before.loyaltySince : loyaltySince(),
      loyaltyDay: loyaltyDay == null ? before.loyaltyDay : loyaltyDay(),
      loyaltyCheckedFor: loyaltyCheckedFor == null
          ? before.loyaltyCheckedFor
          : loyaltyCheckedFor(),
      tagIds: before.tagIds,
      // Every write moves updated_at, as the trigger does.
      updatedAt: 'v${_next++}',
    );
    store[person.id] = person;
    return _served(person);
  }

  /// updated_at after a step tick or LRP check → the person before it and
  /// how many entries there were, for the undo.
  final Map<String, (Person, int)> _ticks = {};

  void _snapshot(Person after, Person before, int entries) =>
      _ticks[after.updatedAt!] = (before, entries);

  Person _undoTo(String personId, String updatedAt) {
    final snapshot = _ticks.remove(updatedAt);
    if (snapshot == null || store[personId]?.updatedAt != updatedAt) {
      throw const UndoStale();
    }
    final (before, entries) = snapshot;
    activities?.store.length = entries;
    store[personId] = before;
    return _served(before);
  }

  @override
  Future<Person> undoStep(
    String personId,
    String stepId,
    DateTime on,
    DateTime lastTick,
    String updatedAt,
  ) async {
    await _record('undoStep($personId, $stepId)');
    return _undoTo(personId, updatedAt);
  }

  @override
  Future<Person> undoLoyaltyCheck(
    String personId,
    DateTime renewal,
    DateTime? previous,
    String updatedAt,
  ) async {
    await _record('undoLoyaltyCheck($personId)');
    return _undoTo(personId, updatedAt);
  }

  /// As `undo_reminder`: back with its id, its entry gone.
  @override
  Future<void> undoReminder(
    String personId,
    Reminder reminder,
    DateTime on,
    String updatedAt,
  ) async {
    await _record('undoReminder(${reminder.id})');
    final open = reminders[personId] ??= [];
    if ((store[personId]?.updatedAt ?? '') != updatedAt ||
        open.any((other) => other.id == reminder.id)) {
      throw const UndoStale();
    }
    open.add(reminder);
    activities?.store.removeWhere((entry) => entry.id == 'a-${reminder.id}');
  }
}

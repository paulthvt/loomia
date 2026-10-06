import 'dart:async';

import 'package:loomia/features/contacts/data/activity_repository.dart';
import 'package:loomia/features/contacts/domain/activity.dart';
import 'package:loomia/features/contacts/domain/person.dart';

/// An in-memory history that records calls, and fails or stalls on demand.
class FakeActivityRepository implements ActivityRepository {
  FakeActivityRepository([Iterable<Activity> activities = const []]) {
    store.addAll(activities);
  }

  final List<Activity> store = [];

  /// One entry per call, e.g. `delete(a-0)`.
  final List<String> calls = <String>[];

  /// Thrown by calls started while set. Use a `PeopleFailure`.
  Object? failWith;

  /// Calls started while set wait on it.
  Completer<void>? gate;

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
  Future<List<Activity>> list(String personId) async {
    await _record('list($personId)');
    return store.where((entry) => entry.personId == personId).toList();
  }

  @override
  Future<Activity> add(String personId, ActivityDraft draft) async {
    await _record('add($personId)');
    final text = draft.text.trim();
    final activity = Activity(
      id: 'a-${_next++}',
      personId: personId,
      kind: draft.kind,
      happenedOn: draft.happenedOn,
      text: text.isEmpty ? null : text,
      amount: draft.amount,
      createdAt: DateTime.utc(2026, 9, 28, 12),
    );
    store.add(activity);
    return activity;
  }

  /// Person id to name, for [ordersIn].
  final Map<String, String> names = {};

  @override
  Future<Activity> addOwnOrder(ActivityDraft draft) async {
    await _record('addOwnOrder()');
    final text = draft.text.trim();
    final activity = Activity(
      id: 'a-${_next++}',
      personId: null,
      kind: ActivityKind.order,
      happenedOn: draft.happenedOn,
      text: text.isEmpty ? null : text,
      amount: draft.amount,
      createdAt: DateTime.utc(2026, 9, 28, 12),
    );
    store.add(activity);
    return activity;
  }

  @override
  Future<Activity> update(String id, ActivityDraft draft) async {
    await _record('update($id)');
    final index = store.indexWhere((entry) => entry.id == id);
    final before = store[index];
    final text = draft.text.trim();
    return store[index] = Activity(
      id: before.id,
      personId: before.personId,
      kind: before.kind,
      happenedOn: draft.happenedOn,
      text: text.isEmpty ? null : text,
      amount: draft.amount,
      createdAt: before.createdAt,
    );
  }

  /// What the trigger does when stage_since moves: the latest stage entry
  /// goes to [at], kept after the one before it. Not a call.
  void moveLatestStage(String personId, DateTime at) {
    final stages = [
      for (final (index, entry) in store.indexed)
        if (entry.personId == personId && entry.kind == ActivityKind.stage)
          (index, entry),
    ]..sort((a, b) => b.$2.createdAt.compareTo(a.$2.createdAt));
    if (stages.isEmpty) return;
    final (index, latest) = stages.first;
    final previous = stages.length > 1 ? stages[1].$2.createdAt : null;
    final moved = previous != null && !at.isAfter(previous)
        ? previous.add(const Duration(microseconds: 1))
        : at;
    store[index] = Activity(
      id: latest.id,
      personId: latest.personId,
      kind: latest.kind,
      happenedOn: latest.happenedOn,
      stage: latest.stage,
      createdAt: moved.toUtc(),
    );
  }

  @override
  Future<List<MonthOrder>> ordersIn(DateTime month) async {
    await _record('ordersIn(${month.year}-${month.month})');
    return [
      for (final entry in store.reversed)
        if (entry.kind == ActivityKind.order &&
            entry.happenedOn.year == month.year &&
            entry.happenedOn.month == month.month)
          (order: entry, personName: names[entry.personId]),
    ]..sort((a, b) => b.order.happenedOn.compareTo(a.order.happenedOn));
  }

  @override
  Future<void> delete(String id) async {
    await _record('delete($id)');
    store.removeWhere((entry) => entry.id == id);
  }

  /// What the database trigger writes when a person changes stage. Not a
  /// call: the app never asks for it.
  void recordStage(String personId, Stage stage) => store.add(
    Activity(
      id: 'a-${_next++}',
      personId: personId,
      kind: ActivityKind.stage,
      happenedOn: DateTime(2026, 9, 28),
      stage: stage,
      createdAt: DateTime.utc(2026, 9, 28, 12),
    ),
  );
}

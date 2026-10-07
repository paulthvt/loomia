import 'dart:async';

import 'package:loomia/features/contacts/domain/person.dart';
import 'package:loomia/features/workflows/data/event_workflow_repository.dart';
import 'package:loomia/features/workflows/domain/event_workflow.dart';

/// In-memory event workflows that record calls, and fail or stall on demand.
class FakeEventWorkflowRepository implements EventWorkflowRepository {
  FakeEventWorkflowRepository([Iterable<EventWorkflow> workflows = const []]) {
    store.addAll(workflows);
  }

  var _next = 0;

  final List<EventWorkflow> store = [];

  /// One entry per call, e.g. `create(Training)`.
  final List<String> calls = <String>[];

  /// Thrown by calls started while set. Use a `PeopleFailure`.
  Object? failWith;

  /// Calls started while set wait on it.
  Completer<void>? gate;

  Future<void> _record(String call) async {
    calls.add(call);
    final failure = failWith;
    final wait = gate;
    if (wait != null) await wait.future;
    if (failure != null) throw failure;
  }

  @override
  Future<List<EventWorkflow>> list() async {
    await _record('list()');
    return [...store];
  }

  @override
  Future<EventWorkflow> create(String name) async {
    await _record('create($name)');
    final workflow = EventWorkflow(
      id: 'new-${++_next}',
      name: name,
      steps: const [],
    );
    store.add(workflow);
    return workflow;
  }

  @override
  Future<void> save(
    String id, {
    required String name,
    required Map<Stage, String> followUps,
  }) async {
    await _record('save($id)');
    _change(
      id,
      (workflow) => EventWorkflow(
        id: workflow.id,
        name: name,
        followUps: followUps,
        steps: workflow.steps,
      ),
    );
  }

  @override
  Future<void> delete(String id) async {
    await _record('delete($id)');
    store.removeWhere((workflow) => workflow.id == id);
  }

  @override
  Future<void> addStep(
    String eventWorkflowId, {
    required String label,
    required int days,
    String? note,
  }) async {
    await _record('addStep($eventWorkflowId)');
    _change(
      eventWorkflowId,
      (workflow) => EventWorkflow(
        id: workflow.id,
        name: workflow.name,
        followUps: workflow.followUps,
        steps: [
          ...workflow.steps,
          EventWorkflowStep(
            id: 'step-${++_next}',
            label: label,
            days: days,
            note: note,
          ),
        ],
      ),
    );
  }

  @override
  Future<void> updateStep(
    String stepId, {
    required String label,
    required int days,
    String? note,
  }) async {
    await _record('updateStep($stepId)');
    _changeStep(
      stepId,
      (step) =>
          EventWorkflowStep(id: step.id, label: label, days: days, note: note),
    );
  }

  @override
  Future<void> removeStep(String stepId) async {
    await _record('removeStep($stepId)');
    _changeStep(stepId, (_) => null);
  }

  void _change(
    String id,
    EventWorkflow Function(EventWorkflow workflow) change,
  ) {
    final index = store.indexWhere((workflow) => workflow.id == id);
    if (index >= 0) store[index] = change(store[index]);
  }

  /// A null from [change] removes the step.
  void _changeStep(
    String stepId,
    EventWorkflowStep? Function(EventWorkflowStep step) change,
  ) {
    final index = store.indexWhere(
      (workflow) => workflow.steps.any((step) => step.id == stepId),
    );
    if (index < 0) return;
    final workflow = store[index];
    _change(
      workflow.id,
      (_) => EventWorkflow(
        id: workflow.id,
        name: workflow.name,
        followUps: workflow.followUps,
        steps: [
          for (final step in workflow.steps)
            if (step.id != stepId) step else ?change(step),
        ],
      ),
    );
  }

  /// The seeded Workshop.
  static List<EventWorkflow> samples() => [
    EventWorkflow(
      id: 'workshop',
      name: 'Workshop',
      followUps: const {
        Stage.prospect: 'samples',
        Stage.customer: 'new-customer',
      },
      steps: const [
        EventWorkflowStep(
          id: 'remind',
          label: "Remind everyone it's tomorrow",
          days: -1,
        ),
        EventWorkflowStep(
          id: 'thank',
          label: 'Send a thank-you and the notes',
          days: 1,
        ),
      ],
    ),
  ];
}

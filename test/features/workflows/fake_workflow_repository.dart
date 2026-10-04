import 'dart:async';

import 'package:loomia/features/contacts/domain/people_failure.dart';
import 'package:loomia/features/contacts/domain/person.dart';
import 'package:loomia/features/workflows/data/workflow_repository.dart';
import 'package:loomia/features/workflows/domain/workflow.dart';

/// In-memory workflows that record calls, and fail or stall on demand.
class FakeWorkflowRepository implements WorkflowRepository {
  FakeWorkflowRepository([Iterable<Workflow> workflows = const []]) {
    store.addAll(workflows);
    // Started with workflows: already seeded, as the server would say.
    _seeded = store.isNotEmpty;
  }

  bool _seeded = false;
  var _next = 0;

  final List<Workflow> store = [];

  /// One entry per call, e.g. `seed(en)`.
  final List<String> calls = <String>[];

  /// Thrown by calls started while set. Use a `PeopleFailure`.
  Object? failWith;

  /// Calls started while set wait on it.
  Completer<void>? gate;

  /// Thrown by seed() only.
  Object? seedFailWith;

  /// seed() waits on it.
  Completer<void>? seedGate;

  Future<void> _record(String call) async {
    calls.add(call);
    final failure = failWith;
    final wait = gate;
    if (wait != null) await wait.future;
    if (failure != null) throw failure;
  }

  @override
  Future<List<Workflow>> list() async {
    await _record('list()');
    return [...store];
  }

  /// Like the RPC: seeds once, ever; a no-op afterwards, even with no
  /// workflow left. It does not start people; tests that need a place set it
  /// on the person.
  @override
  Future<void> seed(String lang, DateTime today) async {
    calls.add('seed($lang)');
    final failure = seedFailWith ?? failWith;
    final wait = seedGate ?? gate;
    if (wait != null) await wait.future;
    if (failure != null) throw failure;
    if (_seeded) return;
    _seeded = true;
    store.addAll(samples());
  }

  @override
  Future<Workflow> create(Stage stage, String name) async {
    await _record('create(${stage.name}, $name)');
    final workflow = Workflow(
      id: 'new-${++_next}',
      stage: stage,
      name: name,
      isDefault: false,
      steps: const [],
    );
    store.add(workflow);
    return workflow;
  }

  @override
  Future<void> rename(String id, String name) async {
    await _record('rename($id, $name)');
    _change(id, (workflow) => _copy(workflow, name: name));
  }

  @override
  Future<void> delete(String id) async {
    await _record('delete($id)');
    store.removeWhere((workflow) => workflow.id == id);
  }

  /// Like the RPC: on clears the stage's other default; unknown fails.
  @override
  Future<void> setDefault(String id, bool on) async {
    await _record('setDefault($id, $on)');
    final target = findWorkflow(store, id);
    if (target == null) throw PeopleFailure.unknown;
    for (final (index, workflow) in store.indexed.toList()) {
      if (workflow.id == id) {
        store[index] = _copy(workflow, isDefault: on);
      } else if (on && workflow.stage == target.stage && workflow.isDefault) {
        store[index] = _copy(workflow, isDefault: false);
      }
    }
  }

  @override
  Future<void> addStep(
    String workflowId, {
    required String label,
    required int days,
    String? note,
    required num position,
    bool loyaltySetup = false,
  }) async {
    await _record('addStep($workflowId, $label, $days, $position)');
    _change(
      workflowId,
      (workflow) => _copy(
        workflow,
        steps: [
          ...workflow.steps,
          WorkflowStep(
            id: 'step-${++_next}',
            position: position,
            label: label,
            days: days,
            note: note,
            loyaltySetup: loyaltySetup,
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
    required bool loyaltySetup,
  }) async {
    await _record('updateStep($stepId, $label, $days)');
    _changeStep(
      stepId,
      (step) => WorkflowStep(
        id: step.id,
        position: step.position,
        label: label,
        days: days,
        note: note,
        loyaltySetup: loyaltySetup,
      ),
    );
  }

  @override
  Future<void> moveStep(String stepId, num position) async {
    await _record('moveStep($stepId, $position)');
    _changeStep(
      stepId,
      (step) => WorkflowStep(
        id: step.id,
        position: position,
        label: step.label,
        days: step.days,
        note: step.note,
        loyaltySetup: step.loyaltySetup,
      ),
    );
  }

  @override
  Future<void> removeStep(String stepId) async {
    await _record('removeStep($stepId)');
    _changeStep(stepId, (_) => null);
  }

  void _change(String id, Workflow Function(Workflow workflow) change) {
    final index = store.indexWhere((workflow) => workflow.id == id);
    if (index >= 0) store[index] = change(store[index]);
  }

  /// A null from [change] removes the step.
  void _changeStep(
    String stepId,
    WorkflowStep? Function(WorkflowStep step) change,
  ) {
    final index = store.indexWhere(
      (workflow) => workflow.steps.any((step) => step.id == stepId),
    );
    if (index < 0) return;
    final workflow = store[index];
    store[index] = _copy(
      workflow,
      steps: [
        for (final step in workflow.steps)
          if (step.id != stepId) step else ?change(step),
      ],
    );
  }

  static Workflow _copy(
    Workflow workflow, {
    String? name,
    bool? isDefault,
    List<WorkflowStep>? steps,
  }) => Workflow(
    id: workflow.id,
    stage: workflow.stage,
    name: name ?? workflow.name,
    isDefault: isDefault ?? workflow.isDefault,
    steps: steps ?? workflow.steps,
  );

  /// The English defaults of spec §2.1.
  static List<Workflow> samples() => [
    _workflow('samples', Stage.prospect, 'Samples', isDefault: true, [
      ('Send a first message', 0),
      ('Send the samples', 1),
      ('Samples arrived', 4),
      ('Ask how the samples went', 3),
      ('Follow up', 7),
    ]),
    _workflow('health', Stage.prospect, 'Health professionals', [
      ('Introduce yourself', 0),
      ('Share a product sheet', 2),
      ('Offer a sample kit', 5),
      ('Follow up', 7),
    ]),
    _workflow('new-customer', Stage.customer, 'New customer', isDefault: true, [
      ('Thank them for the order', 0),
      ('Order arrived', 5),
      ('Check in on the products', 14),
      ('Suggest a refill routine', 21),
    ]),
    _workflow('refill', Stage.customer, 'Refill check-in', [
      ('Ask how supplies are going', 25),
      ('Help with the next order', 3),
    ]),
    _workflow(
      'getting-started',
      Stage.team,
      'Getting started',
      isDefault: true,
      [
        ('Welcome call', 0),
        ('Unboxing call', 5),
        ('First training', 3),
        ('First goal together', 7),
        ('Two-week check-in', 14),
      ],
    ),
  ];

  static Workflow _workflow(
    String id,
    Stage stage,
    String name,
    List<(String, int)> steps, {
    bool isDefault = false,
  }) => Workflow(
    id: id,
    stage: stage,
    name: name,
    isDefault: isDefault,
    steps: [
      for (final (index, (label, days)) in steps.indexed)
        WorkflowStep(
          id: '$id-${index + 1}',
          position: index + 1,
          label: label,
          days: days,
        ),
    ],
  );
}

import 'package:loomia/features/contacts/domain/person.dart';

/// One step: [days] after the previous one (after the start, for the first).
class WorkflowStep {
  const WorkflowStep({
    required this.id,
    required this.position,
    required this.label,
    required this.days,
    this.note,
    this.loyaltySetup = false,
  });

  final String id;

  /// Sparse: an inserted step takes the midpoint, so no other one moves.
  final num position;
  final String label;
  final int days;
  final String? note;

  /// Ticking it counts one loyalty setup (an LRP for dōTERRA) for the month.
  final bool loyaltySetup;
}

/// A user's list of steps for one stage. Their own data once seeded.
class Workflow {
  Workflow({
    required this.id,
    required this.stage,
    required this.name,
    required this.isDefault,
    required List<WorkflowStep> steps,
  }) : steps = _sortedSteps(steps);

  final String id;
  final Stage stage;
  final String name;

  /// The one someone new at [stage] starts.
  final bool isDefault;

  /// Sorted by position.
  final List<WorkflowStep> steps;

  static List<WorkflowStep> _sortedSteps(List<WorkflowStep> steps) {
    final sorted = [...steps];
    sorted.sort(
      (a, b) => a.position.toDouble().compareTo(b.position.toDouble()),
    );
    return List.unmodifiable(sorted);
  }
}

/// What Change stage and Change workflow pick; null is "Nothing for now".
typedef FollowWith = ({Workflow workflow, DateTime firstDue});

Workflow? findWorkflow(List<Workflow> workflows, String? id) =>
    workflows.where((workflow) => workflow.id == id).firstOrNull;

Workflow? defaultFor(List<Workflow> workflows, Stage stage) => workflows
    .where((workflow) => workflow.stage == stage && workflow.isDefault)
    .firstOrNull;

/// The choices for [stage]: the default first, then by name.
List<Workflow> forStage(List<Workflow> workflows, Stage stage) =>
    [...workflows.where((workflow) => workflow.stage == stage)]..sort(
      (a, b) => a.isDefault != b.isDefault
          ? (a.isDefault ? -1 : 1)
          : a.name.compareTo(b.name),
    );

/// The position for a step dropped at [index] among [steps] (sorted, the
/// moved step already taken out): the midpoint of its new neighbours, or one
/// past either end. An empty list gives 1.
// ponytail: halving runs out of double precision after ~50 drops into the
// same gap; the unique (workflow_id, position) then refuses the move. Renumber
// the workflow's steps if that ever happens for real.
num positionAt(List<WorkflowStep> steps, int index) {
  if (steps.isEmpty) return 1;
  if (index <= 0) return steps.first.position - 1;
  if (index >= steps.length) return steps.last.position + 1;
  return (steps[index - 1].position + steps[index].position) / 2;
}

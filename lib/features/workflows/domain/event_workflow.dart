import 'package:loomia/features/contacts/domain/person.dart';

/// A step around an event: [days] from its day, signed. −1 is the day
/// before, 0 the day of, 1 the day after.
class EventWorkflowStep {
  const EventWorkflowStep({
    required this.id,
    required this.label,
    required this.days,
    this.note,
  });

  final String id;
  final String label;
  final int days;
  final String? note;
}

/// An event's type: its checklist, and per stage the person workflow that
/// people who were there start. A stage missing from [followUps] keeps
/// their workflow.
class EventWorkflow {
  EventWorkflow({
    required this.id,
    required this.name,
    required List<EventWorkflowStep> steps,
    this.followUps = const {},
  }) : steps = byDays(steps);

  final String id;
  final String name;

  /// Earliest first.
  final List<EventWorkflowStep> steps;

  /// Stage → person workflow id.
  final Map<Stage, String> followUps;
}

/// Chronological: by days, then by label.
List<EventWorkflowStep> byDays(Iterable<EventWorkflowStep> steps) =>
    List.unmodifiable(
      [...steps]..sort((a, b) {
        if (a.days != b.days) return a.days.compareTo(b.days) as int;
        return a.label.compareTo(b.label) as int;
      }),
    );

/// The column of `event_workflow` and `event` holding [stage]'s workflow.
String followUpColumn(Stage stage) => '${stage.name}_workflow_id';

EventWorkflow? findEventWorkflow(List<EventWorkflow> all, String? id) =>
    all.where((workflow) => workflow.id == id).firstOrNull;

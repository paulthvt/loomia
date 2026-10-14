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

/// An event's type: its checklist, and whether it gathers several people.
class EventWorkflow {
  EventWorkflow({
    required this.id,
    required this.name,
    required List<EventWorkflowStep> steps,
    this.isGroup = true,
  }) : steps = byDays(steps);

  final String id;
  final String name;

  /// Earliest first.
  final List<EventWorkflowStep> steps;

  /// Several people per event: people added start invited (#314).
  final bool isGroup;
}

/// Chronological: by days, then by label.
List<EventWorkflowStep> byDays(Iterable<EventWorkflowStep> steps) =>
    List.unmodifiable(
      <EventWorkflowStep>[...steps]..sort((a, b) {
        if (a.days != b.days) return a.days.compareTo(b.days);
        return a.label.compareTo(b.label);
      }),
    );

EventWorkflow? findEventWorkflow(List<EventWorkflow> all, String? id) =>
    all.where((workflow) => workflow.id == id).firstOrNull;

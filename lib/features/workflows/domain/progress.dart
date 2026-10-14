import 'package:loomia/features/contacts/domain/person.dart';
import 'package:loomia/features/workflows/domain/workflow.dart';

/// Where a person stands in their workflow, as the NEXT STEP card shows it.
sealed class WorkflowProgress {
  const WorkflowProgress();
}

final class Paused extends WorkflowProgress {
  const Paused(this.since);

  final DateTime since;
}

final class Done extends WorkflowProgress {
  const Done(this.workflow);

  final Workflow workflow;
}

/// On an event step whose event is planned (#315): it waits for
/// [eventId], and moves on once that is done with them there.
final class Planned extends WorkflowProgress {
  const Planned({
    required this.workflow,
    required this.step,
    required this.index,
    required this.total,
    required this.eventId,
  });

  final Workflow workflow;
  final WorkflowStep step;
  final int index;
  final int total;
  final String eventId;
}

final class OnStep extends WorkflowProgress {
  const OnStep({
    required this.workflow,
    required this.step,
    required this.index,
    required this.total,
    required this.due,
  });

  final Workflow workflow;
  final WorkflowStep step;

  /// 1-based, for "3 of 5".
  final int index;
  final int total;
  final DateTime due;

  /// Planned as an event: Plan and Later instead of the ring.
  bool get isEvent => step.isEvent;
}

/// The server decides the step and its day (`current_step_id`, `due_on`, in
/// supabase/migrations/*_today_due_steps.sql); this only finds that step in
/// [workflow] for its label, note and "3 of 5".
///
/// Null when the person follows no workflow, one missing from the list
/// (deleted elsewhere), or a step the list does not have yet (loaded before
/// an edit), until the next load. Paused wins over everything.
WorkflowProgress? progressOf(Person person, Workflow? workflow) {
  if (person.pausedAt case final since?) return Paused(since);
  final place = person.place;
  if (place == null || workflow == null || workflow.id != place.workflowId) {
    return null;
  }
  final stepId = person.currentStepId;
  if (stepId == null) return Done(workflow);
  final steps = workflow.steps;
  final index = steps.indexWhere((step) => step.id == stepId);
  if (index == -1) return null;
  if (person.plannedEventId case final eventId?) {
    return Planned(
      workflow: workflow,
      step: steps[index],
      index: index + 1,
      total: steps.length,
      eventId: eventId,
    );
  }
  final due = person.dueOn;
  if (due == null) return null;
  return OnStep(
    workflow: workflow,
    step: steps[index],
    index: index + 1,
    total: steps.length,
    due: due,
  );
}

/// Starts [workflow] with its first step due on [firstDue].
WorkflowPlace start(Workflow workflow, {required DateTime firstDue}) {
  final first = workflow.steps.firstOrNull;
  return (
    workflowId: workflow.id,
    atPosition: first?.position ?? 0,
    lastTick: addDays(firstDue, -(first?.days ?? 0)),
  );
}

/// The first step's day when nobody picks one.
DateTime firstDueDefault(Workflow workflow, DateTime today) =>
    addDays(today, workflow.steps.firstOrNull?.days ?? 0);

/// Calendar days, so a clock change never shifts a day.
DateTime addDays(DateTime day, int days) =>
    DateTime(day.year, day.month, day.day + days);

int daysBetween(DateTime from, DateTime to) => DateTime.utc(
  to.year,
  to.month,
  to.day,
).difference(DateTime.utc(from.year, from.month, from.day)).inDays;

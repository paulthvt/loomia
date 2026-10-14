import 'package:loomia/features/calendar/domain/calendar_event.dart';
import 'package:loomia/features/contacts/domain/person.dart';
import 'package:loomia/features/workflows/domain/workflow.dart';

/// The event [person] missed for their event [step]: the latest done event of
/// its type they were invited to and didn't come to, on or after their last
/// tick. Only for the copy ("Book again"); the server decides the due day.
CalendarEvent? missedEvent(
  Person person,
  WorkflowStep step,
  List<CalendarEvent> events,
) {
  final type = step.eventWorkflowId;
  final since = person.place?.lastTick;
  if (type == null || since == null) return null;
  final missed = [
    for (final event in events)
      if (event.done &&
          event.eventWorkflowId == type &&
          !event.day.isBefore(since) &&
          event.attendees.any((a) => a.personId == person.id && !a.came))
        event,
  ];
  return byStart(missed).lastOrNull;
}

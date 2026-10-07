import 'package:loomia/features/calendar/domain/calendar_event.dart';
import 'package:loomia/features/workflows/domain/event_workflow.dart';

/// How far back Today looks for events to mark and steps left undone. Older
/// ones stay on the event's screen.
const int todayEventsDays = 14;

/// Join opens this long before the start.
const Duration joinEarly = Duration(minutes: 15);

/// Without an end time, Join stays this long after the start.
const Duration joinWithoutEnd = Duration(hours: 2);

typedef DueEventStep = ({
  CalendarEvent event,
  EventWorkflowStep step,
  DateTime due,
});

typedef TodayEvents = ({
  List<CalendarEvent> today,
  List<CalendarEvent> toMark,
  List<DueEventStep> steps,
});

const TodayEvents noTodayEvents = (today: [], toMark: [], steps: []);

extension TodayEventsEmpty on TodayEvents {
  bool get isEmpty => today.isEmpty && toMark.isEmpty && steps.isEmpty;
}

/// What Today's Events section shows at [now]: today's events not yet to
/// mark; events started within [todayEventsDays] days that can be marked
/// done; and checklist steps due from [todayEventsDays] days ago through
/// today, not ticked. Each list earliest first.
TodayEvents todayEvents(
  List<CalendarEvent> events,
  List<EventWorkflow> workflows,
  DateTime now,
) {
  final day = DateTime(now.year, now.month, now.day);
  final from = DateTime(day.year, day.month, day.day - todayEventsDays);
  final toMark = byStart(
    events.where(
      (event) => event.canMarkDone(now) && !event.day.isBefore(from),
    ),
  );
  final today = [
    for (final event in eventsOn(events, day))
      if (!toMark.contains(event)) event,
  ];
  final steps =
      <DueEventStep>[
        for (final event in byStart(events))
          if (findEventWorkflow(workflows, event.eventWorkflowId)
              case final workflow?)
            for (final step in workflow.steps)
              if (!event.stepsDone.containsKey(step.id))
                if (stepDue(event, step) case final due
                    when !due.isAfter(day) && !due.isBefore(from))
                  (event: event, step: step, due: due),
      ]..sort((a, b) {
        final byDue = a.due.compareTo(b.due);
        return byDue != 0
            ? byDue
            : a.event.startsAt.compareTo(b.event.startsAt);
      });
  return (today: today, toMark: toMark, steps: steps);
}

bool canJoin(CalendarEvent event, DateTime now) {
  if (event.link == null) return false;
  final opens = event.startsAt.subtract(joinEarly);
  final closes = event.endsAt ?? event.startsAt.add(joinWithoutEnd);
  return !now.isBefore(opens) && now.isBefore(closes);
}

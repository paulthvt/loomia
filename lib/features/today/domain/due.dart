import 'package:loomia/features/calendar/domain/calendar_event.dart';
import 'package:loomia/features/contacts/domain/person.dart';
import 'package:loomia/features/contacts/domain/search_key.dart';
import 'package:loomia/features/workflows/domain/progress.dart';
import 'package:loomia/features/workflows/domain/workflow.dart';

/// Something worth doing with someone today: their workflow step, a
/// reminder they asked for (#217), or following up an invitation (#314).
sealed class Due {
  const Due(this.person);

  final Person person;

  /// The day it is due, local midnight.
  DateTime get day;

  /// Unique on Today: the person's id for their step (one current step
  /// each), the reminder's id for a reminder.
  String get key;
}

final class DueStep extends Due {
  const DueStep(super.person, this.step);

  final OnStep step;

  @override
  DateTime get day => step.due;

  @override
  String get key => person.id;
}

final class DueReminder extends Due {
  const DueReminder(super.person, this.reminder);

  final Reminder reminder;

  @override
  DateTime get day => reminder.dueOn;

  @override
  String get key => reminder.id;
}

/// Someone invited to [event] who hasn't said they're going, due to be
/// followed up.
final class DueFollowUp extends Due {
  const DueFollowUp(super.person, this.event, this.attendee);

  final CalendarEvent event;
  final Attendee attendee;

  @override
  DateTime get day => attendee.followUpOn!;

  @override
  String get key => '${event.id}:${person.id}';
}

/// Steps, reminders and invitation follow-ups due on or before [today],
/// oldest first, then by name; the same day, one person's reminders come
/// first, then their follow-ups, then their step. Paused, done, no workflow
/// and not yet due steps fall out; a pause leaves the rest be. A follow-up
/// stays while its event's day has not passed (as `due_people_count`). The
/// server decides each day (`due_on`, `follow_up_on`); this only compares
/// them with the device's today.
List<Due> dueToday(
  List<Person> people,
  List<Workflow> workflows,
  DateTime today, {
  List<CalendarEvent> events = const [],
}) {
  final byId = {for (final person in people) person.id: person};
  final due = <Due>[
    for (final person in people) ...[
      for (final reminder in person.reminders)
        if (!reminder.dueOn.isAfter(today)) DueReminder(person, reminder),
      if (progressOf(person, findWorkflow(workflows, person.place?.workflowId))
          case final OnStep step when !step.due.isAfter(today))
        DueStep(person, step),
    ],
    for (final event in events)
      if (!event.day.isBefore(today))
        for (final attendee in event.attendees)
          if (attendee.followUpOn case final on? when !on.isAfter(today))
            if (byId[attendee.personId] case final person?)
              DueFollowUp(person, event, attendee),
  ];
  due.sort((a, b) {
    final byDay = a.day.compareTo(b.day);
    if (byDay != 0) return byDay;
    final byName = searchKey(a.person.name).compareTo(searchKey(b.person.name));
    if (byName != 0) return byName;
    final byPerson = a.person.id.compareTo(b.person.id);
    if (byPerson != 0) return byPerson;
    final byKind = _rank(a).compareTo(_rank(b));
    if (byKind != 0) return byKind;
    return switch ((a, b)) {
      (DueReminder(reminder: final x), DueReminder(reminder: final y)) =>
        x.createdAt.compareTo(y.createdAt),
      (DueFollowUp(event: final x), DueFollowUp(event: final y)) =>
        x.startsAt.compareTo(y.startsAt),
      _ => 0,
    };
  });
  return due;
}

int _rank(Due due) => switch (due) {
  DueReminder() => 0,
  DueFollowUp() => 1,
  DueStep() => 2,
};

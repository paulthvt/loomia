import 'package:loomia/features/calendar/domain/calendar_event.dart';
import 'package:loomia/features/calendar/domain/missed.dart';
import 'package:loomia/features/contacts/domain/loyalty_renewal.dart';
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
  const DueStep(super.person, this.step, {this.missed});

  final OnStep step;

  /// On an event step: the event planned for it that they missed, for
  /// "Book again" (#315).
  final CalendarEvent? missed;

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

/// Their LRP renews on [renewal] (#317): from [loyaltyRenewalAhead] days
/// before, never late.
final class DueLoyalty extends Due {
  const DueLoyalty(super.person, this.renewal);

  final DateTime renewal;

  @override
  DateTime get day =>
      DateTime(renewal.year, renewal.month, renewal.day - loyaltyRenewalAhead);

  @override
  String get key => 'lrp:${person.id}';
}

/// Done with [workflow], and asked what comes next (#316): on the day of
/// the last tick, never late.
final class DueNext extends Due {
  const DueNext(super.person, this.workflow);

  final Workflow workflow;

  @override
  DateTime get day => person.place!.lastTick;

  @override
  String get key => 'next:${person.id}';
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
      if (loyaltyRenewal(person, today) case final renewal?)
        DueLoyalty(person, renewal),
      if (progressOf(person, findWorkflow(workflows, person.place?.workflowId))
          case Done(:final workflow) when person.needsNext)
        DueNext(person, workflow),
      if (progressOf(person, findWorkflow(workflows, person.place?.workflowId))
          case final OnStep step when !step.due.isAfter(today))
        DueStep(
          person,
          step,
          missed: step.isEvent ? missedEvent(person, step.step, events) : null,
        ),
    ],
    for (final event in events)
      if (!event.day.isBefore(today))
        for (final attendee in event.attendees)
          if (attendee.followUpOn case final on? when !on.isAfter(today))
            if (byId[attendee.personId] case final person?)
              DueFollowUp(person, event, attendee),
  ];
  due.sort(_compare);
  return due;
}

/// What is due on exactly [day] (#378), for the Calendar to look ahead: the
/// rules of [dueToday], but "on [day]" where it says "on or before", and
/// its LRP check only on the first day Today asks about it. Never
/// [DueNext], a reaction to a tick. Empty before [today]: the late ones
/// live on Today.
List<Due> dueOn(
  List<Person> people,
  List<Workflow> workflows,
  DateTime day,
  DateTime today, {
  List<CalendarEvent> events = const [],
}) {
  if (day.isBefore(today)) return const [];
  final byId = {for (final person in people) person.id: person};
  final due = <Due>[
    for (final person in people) ...[
      for (final reminder in person.reminders)
        if (reminder.dueOn == day) DueReminder(person, reminder),
      if (loyaltyRenewal(person, day) case final renewal?
          when DueLoyalty(person, renewal).day == day)
        DueLoyalty(person, renewal),
      if (progressOf(person, findWorkflow(workflows, person.place?.workflowId))
          case final OnStep step when step.due == day)
        DueStep(person, step),
    ],
    for (final event in events)
      if (!event.day.isBefore(day))
        for (final attendee in event.attendees)
          if (attendee.followUpOn == day)
            if (byId[attendee.personId] case final person?)
              DueFollowUp(person, event, attendee),
  ]..sort(_compare);
  return due;
}

/// [due], sorted as [dueOn], cut into one run per person: a row each.
List<List<Due>> byPerson(List<Due> due) {
  final runs = <List<Due>>[];
  for (final item in due) {
    if (runs.isNotEmpty && runs.last.first.person.id == item.person.id) {
      runs.last.add(item);
    } else {
      runs.add([item]);
    }
  }
  return runs;
}

int _compare(Due a, Due b) {
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
}

int _rank(Due due) => switch (due) {
  DueReminder() => 0,
  DueLoyalty() => 1,
  DueFollowUp() => 2,
  DueNext() => 3,
  DueStep() => 4,
};

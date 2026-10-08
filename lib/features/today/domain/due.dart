import 'package:loomia/features/contacts/domain/person.dart';
import 'package:loomia/features/contacts/domain/search_key.dart';
import 'package:loomia/features/workflows/domain/progress.dart';
import 'package:loomia/features/workflows/domain/workflow.dart';

/// Something worth doing with someone today: their workflow step, or a
/// reminder they asked for (#217).
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

/// Steps and reminders due on or before [today], oldest first, then by name;
/// the same day, one person's reminders come before their step. Paused, done,
/// no workflow and not yet due steps fall out; a pause leaves reminders be.
/// The server decides a step's day (`due_on`); this only compares it with
/// the device's today.
List<Due> dueToday(
  List<Person> people,
  List<Workflow> workflows,
  DateTime today,
) {
  final due = <Due>[
    for (final person in people) ...[
      for (final reminder in person.reminders)
        if (!reminder.dueOn.isAfter(today)) DueReminder(person, reminder),
      if (progressOf(person, findWorkflow(workflows, person.place?.workflowId))
          case final OnStep step when !step.due.isAfter(today))
        DueStep(person, step),
    ],
  ];
  due.sort((a, b) {
    final byDay = a.day.compareTo(b.day);
    if (byDay != 0) return byDay;
    final byName = searchKey(a.person.name).compareTo(searchKey(b.person.name));
    if (byName != 0) return byName;
    final byPerson = a.person.id.compareTo(b.person.id);
    if (byPerson != 0) return byPerson;
    return switch ((a, b)) {
      (DueReminder(reminder: final x), DueReminder(reminder: final y)) =>
        x.createdAt.compareTo(y.createdAt),
      (DueReminder(), _) => -1,
      (_, DueReminder()) => 1,
      _ => 0,
    };
  });
  return due;
}

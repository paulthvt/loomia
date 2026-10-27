import 'package:loomia/features/calendar/domain/calendar_event.dart';
import 'package:loomia/features/contacts/domain/person.dart';
import 'package:loomia/features/today/domain/due.dart';
import 'package:loomia/features/workflows/domain/workflow.dart';

/// Who is due when in the Calendar (#378): what [dueOn] gives for a day,
/// one run per person. Carries its inputs down the Calendar's widgets.
final class PeopleAhead {
  const PeopleAhead({
    required this.people,
    required this.workflows,
    required DateTime this.today,
    this.events = const [],
  });

  /// Nobody: while people or workflows load, or failed to.
  const PeopleAhead.none()
    : people = const [],
      workflows = const [],
      events = const [],
      today = null;

  final List<Person> people;
  final List<Workflow> workflows;
  final List<CalendarEvent> events;

  /// Null for [PeopleAhead.none].
  final DateTime? today;

  /// [day]'s people, one run of Due items each, by name.
  /// ponytail: recomputed over everyone per call (a grid asks ~126 days per
  /// build); memoise per day if a profile ever shows it.
  List<List<Due>> on(DateTime day) => switch (today) {
    final from? => byPerson(
      dueOn(people, workflows, day, from, events: events),
    ),
    null => const [],
  };

  /// How many people are due on [day].
  int count(DateTime day) => on(day).length;
}

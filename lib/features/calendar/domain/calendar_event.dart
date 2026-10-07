import 'package:loomia/features/contacts/domain/person.dart';
import 'package:loomia/features/workflows/domain/event_workflow.dart';

/// Someone invited to an event, and whether they were there once it is
/// marked done.
typedef Attendee = ({String personId, bool came});

/// Something on the calendar: a workshop, a training. [startsAt] and
/// [endsAt] are instants; the calendar reads them in the device's time zone.
class CalendarEvent {
  const CalendarEvent({
    required this.id,
    required this.title,
    required this.startsAt,
    this.endsAt,
    this.place,
    this.link,
    this.notes,
    this.attendees = const [],
    this.doneAt,
    this.eventWorkflowId,
    this.followUps = const {},
    this.stepsDone = const {},
  });

  final String id;
  final String title;
  final DateTime startsAt;

  /// After [startsAt], the same day (the form has no end date).
  final DateTime? endsAt;

  /// Free text: an address, a café's name.
  final String? place;

  /// An http(s) address, for an online event.
  final String? link;
  final String? notes;

  /// Who is invited, in no order: screens sort them by name.
  final List<Attendee> attendees;

  /// When "Mark who was there" was done. From then on attendance is history.
  final DateTime? doneAt;

  /// The event's workflow: its checklist and what the people there start.
  final String? eventWorkflowId;

  /// Stage → person workflow id. A stage not in here keeps their workflow.
  final Map<Stage, String> followUps;

  /// Step id → the day it was ticked.
  final Map<String, DateTime> stepsDone;

  bool get done => doneAt != null;

  /// How many were there. Meaningful once [done].
  int get cameCount => attendees.where((attendee) => attendee.came).length;

  /// "Mark who was there" is offered from the start, until it is done, and
  /// only with someone to mark.
  bool canMarkDone(DateTime now) =>
      !done && attendees.isNotEmpty && !startsAt.isAfter(now);

  /// The local calendar day it starts on, as local midnight.
  DateTime get day {
    final local = startsAt.toLocal();
    return DateTime(local.year, local.month, local.day);
  }
}

/// What the form saves. Text is trimmed and empty text is null by then.
typedef EventDraft = ({
  String title,
  DateTime startsAt,
  DateTime? endsAt,
  String? place,
  String? link,
  String? notes,
  String? eventWorkflowId,
  Map<Stage, String> followUps,
});

/// Earliest first.
List<CalendarEvent> byStart(Iterable<CalendarEvent> events) =>
    [...events]..sort((a, b) => a.startsAt.compareTo(b.startsAt));

/// [events] starting on [day] (local midnight), earliest first.
List<CalendarEvent> eventsOn(List<CalendarEvent> events, DateTime day) =>
    byStart(events.where((event) => event.day == day));

/// How many events start on each local day; days without one are absent.
Map<DateTime, int> eventsPerDay(List<CalendarEvent> events) {
  final counts = <DateTime, int>{};
  for (final event in events) {
    counts.update(event.day, (count) => count + 1, ifAbsent: () => 1);
  }
  return counts;
}

/// [text] as an http(s) link: trimmed, `https://` added when there is no
/// scheme. Null when empty, or when it isn't a web address with a dotted
/// host, which also turns away `javascript:`.
String? normaliseLink(String text) {
  final trimmed = text.trim();
  if (trimmed.isEmpty) return null;
  final link = trimmed.contains('://') ? trimmed : 'https://$trimmed';
  final uri = Uri.tryParse(link);
  if (uri == null ||
      !(uri.isScheme('http') || uri.isScheme('https')) ||
      !uri.host.contains('.')) {
    return null;
  }
  return link;
}

/// [link] as the event screen shows it: without `https://`.
String shownLink(String link) => link.replaceFirst(RegExp('^https?://'), '');

/// Directions to [place] in the maps app: Apple Maps on iOS, Google Maps
/// elsewhere (Android's Maps app opens these links; the web gets the site).
Uri mapsUri(String place, {required bool apple}) => apple
    ? Uri.https('maps.apple.com', '/', {'q': place})
    : Uri.https('www.google.com', '/maps/search/', {
        'api': '1',
        'query': place,
      });

/// When [step] is due for [event]: the event's local day plus its days.
DateTime stepDue(CalendarEvent event, EventWorkflowStep step) {
  final day = event.day;
  return DateTime(day.year, day.month, day.day + step.days);
}

/// "Who was there?"'s summary line: how many were there at a stage, and the
/// workflow they start (null: they keep theirs).
typedef ThereLine = ({Stage stage, int count, String? workflowId});

/// One line per stage present in [stagesThere], in stage order.
List<ThereLine> thereSummary(
  Iterable<Stage> stagesThere,
  Map<Stage, String> followUps,
) {
  final counts = <Stage, int>{};
  for (final stage in stagesThere) {
    counts.update(stage, (count) => count + 1, ifAbsent: () => 1);
  }
  return [
    for (final stage in Stage.values)
      if (counts[stage] case final count?)
        (stage: stage, count: count, workflowId: followUps[stage]),
  ];
}

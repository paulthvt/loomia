import 'package:loomia/features/calendar/data/event_repository.dart';
import 'package:loomia/features/calendar/domain/calendar_event.dart';

import '../workflows/server_rule.dart';

/// In-memory events that record calls and fail on demand.
class FakeEventRepository implements EventRepository {
  FakeEventRepository([Iterable<CalendarEvent> events = const []]) {
    store.addAll(events);
  }

  final List<CalendarEvent> store = [];

  /// Whether an event type gathers several people, as `is_group`: people
  /// invited to an event of that type start not going.
  bool Function(String eventWorkflowId) isGroup = (_) => true;

  /// One entry per call, e.g. `add(Workshop)`.
  final List<String> calls = [];

  /// Thrown by calls started while set. Use a `PeopleFailure`.
  Object? failWith;

  var _next = 0;

  void _record(String call) {
    calls.add(call);
    final failure = failWith;
    if (failure != null) throw failure;
  }

  static CalendarEvent _fromDraft(
    String id,
    EventDraft draft, {
    List<Attendee> attendees = const [],
    DateTime? doneAt,
    Map<String, DateTime> stepsDone = const {},
    EventSeries? series,
  }) => CalendarEvent(
    id: id,
    title: draft.title,
    startsAt: draft.startsAt,
    endsAt: draft.endsAt,
    place: draft.place,
    link: draft.link,
    notes: draft.notes,
    attendees: attendees,
    doneAt: doneAt,
    eventWorkflowId: draft.eventWorkflowId,
    followUps: draft.followUps,
    stepsDone: stepsDone,
    series: series,
  );

  @override
  Future<List<CalendarEvent>> list(DateTime today) async {
    _record('list()');
    return byStart(store);
  }

  @override
  Future<CalendarEvent> add(EventDraft draft) async {
    _record('add(${draft.title})');
    final event = _fromDraft('new${++_next}', draft);
    store.add(event);
    return event;
  }

  @override
  Future<CalendarEvent> update(String id, EventDraft draft) async {
    _record('update($id)');
    final index = store.indexWhere((saved) => saved.id == id);
    final saved = store[index];
    final event = _fromDraft(
      id,
      draft,
      attendees: saved.attendees,
      doneAt: saved.doneAt,
      stepsDone: saved.stepsDone,
      series: saved.series,
    );
    store[index] = event;
    return event;
  }

  @override
  Future<void> remove(String id) async {
    _record('remove($id)');
    store.removeWhere((event) => event.id == id);
  }

  /// As extend_event_series, at once: every [RepeatRule.everyWeeks] weeks
  /// from the first day, up to a year on or the end day, in local time.
  @override
  Future<String> addSeries(
    EventDraft draft,
    RepeatRule rule,
    String zone,
  ) async {
    _record('addSeries(${draft.title}, ${rule.everyWeeks}, $zone)');
    final id = 'series${++_next}';
    final start = draft.startsAt;
    final first = DateTime(start.year, start.month, start.day);
    final series = (
      id: id,
      everyWeeks: rule.everyWeeks,
      firstOn: first,
      untilOn: rule.untilOn,
    );
    final last =
        rule.untilOn ?? DateTime(first.year + 1, first.month, first.day);
    for (var week = 0; ; week += rule.everyWeeks) {
      final day = DateTime(first.year, first.month, first.day + 7 * week);
      if (day.isAfter(last)) break;
      DateTime at(DateTime time) =>
          DateTime(day.year, day.month, day.day, time.hour, time.minute);
      final end = draft.endsAt;
      store.add(
        _fromDraft('$id-$week', (
          title: draft.title,
          startsAt: at(start),
          endsAt: end == null ? null : at(end),
          place: draft.place,
          link: draft.link,
          notes: draft.notes,
          eventWorkflowId: draft.eventWorkflowId,
          followUps: draft.followUps,
        ), series: series),
      );
    }
    return id;
  }

  /// As set_series_attendees: [eventId] and the not done occurrences after.
  @override
  Future<void> setSeriesPeople(
    String eventId, {
    Iterable<String> add = const [],
    Iterable<String> remove = const [],
  }) async {
    _record('setSeriesPeople($eventId:+${add.join(',')}-${remove.join(',')})');
    final from = store.firstWhere((event) => event.id == eventId);
    final seriesId = from.series!.id;
    final gone = remove.toSet();
    for (final event in [...store]) {
      if (event.series?.id != seriesId ||
          event.done ||
          event.startsAt.isBefore(from.startsAt)) {
        continue;
      }
      _with(
        event.id,
        (attendees) => [
          for (final attendee in attendees)
            if (!gone.contains(attendee.personId)) attendee,
          for (final id in add)
            if (!attendees.any((a) => a.personId == id)) Attendee(personId: id),
        ],
      );
    }
  }

  CalendarEvent _with(
    String eventId,
    List<Attendee> Function(List<Attendee>) change, {
    DateTime? doneAt,
    Map<String, DateTime>? stepsDone,
  }) {
    final index = store.indexWhere((event) => event.id == eventId);
    final event = store[index];
    final changed = CalendarEvent(
      id: event.id,
      title: event.title,
      startsAt: event.startsAt,
      endsAt: event.endsAt,
      place: event.place,
      link: event.link,
      notes: event.notes,
      attendees: [
        for (final attendee in change(event.attendees))
          Attendee(
            personId: attendee.personId,
            came: attendee.came,
            going: attendee.going,
            invitedOn: attendee.invitedOn,
            followedUpOn: attendee.followedUpOn,
            followUpOn: followUpOn(
              attendee,
              done: (doneAt ?? event.doneAt) != null,
            ),
          ),
      ],
      doneAt: doneAt ?? event.doneAt,
      eventWorkflowId: event.eventWorkflowId,
      followUps: event.followUps,
      stepsDone: stepsDone ?? event.stepsDone,
      series: event.series,
    );
    store[index] = changed;
    return changed;
  }

  /// As the `event_attendee_going` trigger: not going on a group type.
  @override
  Future<void> invite(
    String eventId,
    Iterable<String> personIds,
    DateTime on,
  ) async {
    _record('invite($eventId:${personIds.join(',')})');
    final type = store
        .firstWhere((event) => event.id == eventId)
        .eventWorkflowId;
    final going = type == null || !isGroup(type);
    _with(
      eventId,
      (attendees) => [
        ...attendees,
        for (final id in personIds)
          Attendee(personId: id, going: going, invitedOn: on),
      ],
    );
  }

  @override
  Future<void> setGoing(String eventId, String personId) async {
    _record('setGoing($eventId:$personId)');
    _change(eventId, personId, (a) => _copy(a, going: true));
  }

  @override
  Future<void> followedUp(String eventId, String personId, DateTime on) async {
    _record('followedUp($eventId:$personId)');
    _change(eventId, personId, (a) => _copy(a, followedUpOn: on));
  }

  void _change(
    String eventId,
    String personId,
    Attendee Function(Attendee) change,
  ) => _with(
    eventId,
    (attendees) => [
      for (final attendee in attendees)
        attendee.personId == personId ? change(attendee) : attendee,
    ],
  );

  static Attendee _copy(
    Attendee attendee, {
    bool? came,
    bool? going,
    DateTime? followedUpOn,
  }) => Attendee(
    personId: attendee.personId,
    came: came ?? attendee.came,
    going: going ?? attendee.going,
    invitedOn: attendee.invitedOn,
    followedUpOn: followedUpOn ?? attendee.followedUpOn,
  );

  @override
  Future<void> uninvite(String eventId, String personId) async {
    _record('uninvite($eventId:$personId)');
    _with(
      eventId,
      (attendees) => [
        for (final attendee in attendees)
          if (attendee.personId != personId) attendee,
      ],
    );
  }

  @override
  Future<void> markDone(
    String eventId,
    Iterable<String> came,
    DateTime today,
  ) async {
    _record('markDone($eventId:${came.join(',')})');
    final there = came.toSet();
    _with(
      eventId,
      (attendees) => [
        for (final attendee in attendees)
          _copy(attendee, came: there.contains(attendee.personId)),
      ],
      doneAt: DateTime.now(),
    );
  }

  @override
  Future<void> tick(String eventId, String stepId, DateTime on) async {
    _record('tick($eventId:$stepId)');
    final index = store.indexWhere((event) => event.id == eventId);
    final event = store[index];
    _with(
      eventId,
      (attendees) => attendees,
      stepsDone: {...event.stepsDone, stepId: on},
    );
  }

  @override
  Future<void> untick(String eventId, String stepId) async {
    _record('untick($eventId:$stepId)');
    final index = store.indexWhere((event) => event.id == eventId);
    final event = store[index];
    _with(
      eventId,
      (attendees) => attendees,
      stepsDone: {
        for (final entry in event.stepsDone.entries)
          if (entry.key != stepId) entry.key: entry.value,
      },
    );
  }
}

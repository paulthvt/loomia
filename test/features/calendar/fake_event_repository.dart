import 'dart:async';

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

  /// A [tick] started while set waits on it.
  Completer<void>? gate;

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
    _generate(series, draft, from: first);
    return id;
  }

  /// Occurrences of [series] from [from] (local midnight, included) up to
  /// a year after its first day or its end day, at [template]'s times.
  void _generate(
    EventSeries series,
    EventDraft template, {
    required DateTime from,
  }) {
    final first = series.firstOn;
    final last =
        series.untilOn ?? DateTime(first.year + 1, first.month, first.day);
    for (var week = 0; ; week += series.everyWeeks) {
      final day = DateTime(first.year, first.month, first.day + 7 * week);
      if (day.isAfter(last)) break;
      if (day.isBefore(from)) continue;
      store.add(
        _fromDraft(
          '${series.id}-${dayKey(day)}',
          _on(template, day),
          series: series,
        ),
      );
    }
  }

  static String dayKey(DateTime day) =>
      '${day.year}${day.month.toString().padLeft(2, '0')}'
      '${day.day.toString().padLeft(2, '0')}';

  /// [draft]'s times on [day].
  static EventDraft _on(EventDraft draft, DateTime day) {
    DateTime at(DateTime time) =>
        DateTime(day.year, day.month, day.day, time.hour, time.minute);
    final end = draft.endsAt;
    return (
      title: draft.title,
      startsAt: at(draft.startsAt),
      endsAt: end == null ? null : at(end),
      place: draft.place,
      link: draft.link,
      notes: draft.notes,
      eventWorkflowId: draft.eventWorkflowId,
    );
  }

  static EventDraft _draftOf(CalendarEvent event) => (
    title: event.title,
    startsAt: event.startsAt,
    endsAt: event.endsAt,
    place: event.place,
    link: event.link,
    notes: event.notes,
    eventWorkflowId: event.eventWorkflowId,
  );

  CalendarEvent _keep(CalendarEvent event, EventDraft draft, EventSeries? s) =>
      _fromDraft(
        event.id,
        draft,
        attendees: event.attendees,
        doneAt: event.doneAt,
        stepsDone: event.stepsDone,
        series: s,
      );

  /// Every event of [seriesId] now says [series] (null: none).
  void _reseries(String seriesId, EventSeries? series) {
    for (final (i, event) in store.indexed) {
      if (event.series?.id == seriesId) {
        store[i] = _keep(event, _draftOf(event), series);
      }
    }
  }

  /// Not done occurrences of [from]'s series from it on.
  bool _following(CalendarEvent event, CalendarEvent from) =>
      event.series?.id == from.series?.id &&
      !event.done &&
      !event.day.isBefore(from.day);

  /// As repeat_event: [eventId] is the first occurrence; its people stay
  /// on it only (the fake keeps no series people).
  @override
  Future<void> repeat(String eventId, RepeatRule rule, String zone) async {
    _record('repeat($eventId, ${rule.everyWeeks}, $zone)');
    final event = store.firstWhere((event) => event.id == eventId);
    final series = (
      id: 'series${++_next}',
      everyWeeks: rule.everyWeeks,
      firstOn: event.day,
      untilOn: rule.untilOn,
    );
    store[store.indexOf(event)] = _keep(event, _draftOf(event), series);
    _generate(
      series,
      _draftOf(event),
      from: DateTime(event.day.year, event.day.month, event.day.day + 1),
    );
  }

  /// As update_event_series: in place, or from the new day on a new rule.
  @override
  Future<String> updateSeries(
    String eventId,
    EventDraft draft,
    RepeatRule rule,
    DateTime today,
  ) async {
    _record('updateSeries($eventId, ${rule.everyWeeks})');
    final from = store.firstWhere((event) => event.id == eventId);
    final old = from.series!;
    final start = draft.startsAt;
    final day = DateTime(start.year, start.month, start.day);
    if (rule.everyWeeks == old.everyWeeks &&
        rule.untilOn == old.untilOn &&
        day == from.day) {
      for (final (i, event) in [...store.indexed]) {
        if (!_following(event, from)) continue;
        store[i] = _keep(
          event,
          event.id == eventId ? draft : _on(draft, event.day),
          old,
        );
      }
      return eventId;
    }
    store.removeWhere((event) => _following(event, from));
    final series = (
      id: old.id,
      everyWeeks: rule.everyWeeks,
      firstOn: day,
      untilOn: rule.untilOn,
    );
    _reseries(old.id, series);
    _generate(series, draft, from: day);
    return '${old.id}-${dayKey(day)}';
  }

  /// As end_event_series.
  @override
  Future<void> endSeries(String eventId) async {
    _record('endSeries($eventId)');
    final from = store.firstWhere((event) => event.id == eventId);
    final old = from.series!;
    store.removeWhere((event) => _following(event, from));
    final until = DateTime(from.day.year, from.day.month, from.day.day - 1);
    _reseries(
      old.id,
      from.day.isAfter(old.firstOn)
          ? (
              id: old.id,
              everyWeeks: old.everyWeeks,
              firstOn: old.firstOn,
              untilOn: until,
            )
          : null,
    );
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

  /// The last [close]'s who was there, as sent.
  List<There>? closedThere;

  /// As close_event, for the event: who came, and done. People's changes
  /// are the server's; [inviteNext] joins the next one of its type.
  @override
  Future<void> close(
    String eventId,
    List<There> there,
    Iterable<String> inviteNext,
    DateTime today,
  ) async {
    _record(
      'close($eventId:${there.map((t) => t.personId).join(',')}'
      '|next:${inviteNext.join(',')})',
    );
    closedThere = there;
    final came = {for (final t in there) t.personId};
    final closed = _with(
      eventId,
      (attendees) => [
        for (final attendee in attendees)
          _copy(attendee, came: came.contains(attendee.personId)),
      ],
      doneAt: DateTime.now(),
    );
    final type = closed.eventWorkflowId;
    final next = type == null || !isGroup(type) || inviteNext.isEmpty
        ? null
        : byStart([
            for (final event in store)
              if (event.eventWorkflowId == type &&
                  !event.done &&
                  event.startsAt.isAfter(closed.startsAt))
                event,
          ]).firstOrNull;
    if (next != null) {
      _with(
        next.id,
        (attendees) => [
          ...attendees,
          for (final id in inviteNext)
            if (!attendees.any((a) => a.personId == id))
              Attendee(personId: id, going: false, invitedOn: today),
        ],
      );
    }
  }

  @override
  Future<void> tick(String eventId, String stepId, DateTime on) async {
    _record('tick($eventId:$stepId)');
    if (gate case final wait?) await wait.future;
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

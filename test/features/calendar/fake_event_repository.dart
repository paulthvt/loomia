import 'package:loomia/features/calendar/data/event_repository.dart';
import 'package:loomia/features/calendar/domain/calendar_event.dart';

/// In-memory events that record calls and fail on demand.
class FakeEventRepository implements EventRepository {
  FakeEventRepository([Iterable<CalendarEvent> events = const []]) {
    store.addAll(events);
  }

  final List<CalendarEvent> store = [];

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
  );

  @override
  Future<List<CalendarEvent>> list() async {
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
    );
    store[index] = event;
    return event;
  }

  @override
  Future<void> remove(String id) async {
    _record('remove($id)');
    store.removeWhere((event) => event.id == id);
  }

  CalendarEvent _with(
    String eventId,
    List<Attendee> Function(List<Attendee>) change, {
    DateTime? doneAt,
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
      attendees: change(event.attendees),
      doneAt: doneAt ?? event.doneAt,
    );
    store[index] = changed;
    return changed;
  }

  @override
  Future<void> invite(String eventId, Iterable<String> personIds) async {
    _record('invite($eventId:${personIds.join(',')})');
    _with(
      eventId,
      (attendees) => [
        ...attendees,
        for (final id in personIds) (personId: id, came: false),
      ],
    );
  }

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
          (
            personId: attendee.personId,
            came: there.contains(attendee.personId),
          ),
      ],
      doneAt: DateTime.now(),
    );
  }
}

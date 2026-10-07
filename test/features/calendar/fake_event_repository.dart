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

  static CalendarEvent _fromDraft(String id, EventDraft draft) => CalendarEvent(
    id: id,
    title: draft.title,
    startsAt: draft.startsAt,
    endsAt: draft.endsAt,
    place: draft.place,
    link: draft.link,
    notes: draft.notes,
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
    final event = _fromDraft(id, draft);
    store[store.indexWhere((saved) => saved.id == id)] = event;
    return event;
  }

  @override
  Future<void> remove(String id) async {
    _record('remove($id)');
    store.removeWhere((event) => event.id == id);
  }
}

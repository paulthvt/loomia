import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loomia/core/ui/pick_day.dart';
import 'package:loomia/features/calendar/data/event_repository.dart';
import 'package:loomia/features/calendar/domain/calendar_event.dart';
import 'package:loomia/features/contacts/domain/people_failure.dart';
import 'package:loomia/features/contacts/presentation/history_controller.dart';
import 'package:loomia/features/contacts/presentation/people_controller.dart';

/// One account's events, `eventsProvider(account?.email)`, earliest first.
/// Keyed by account for the same reason as `peopleProvider`. No automatic
/// retry: a failed load shows its error with Try again.
final eventsProvider =
    AsyncNotifierProvider.family<
      EventsController,
      List<CalendarEvent>,
      String?
    >(EventsController.new, retry: (error, _) => null);

class EventsController extends AsyncNotifier<List<CalendarEvent>> {
  EventsController(this.owner);

  /// The email of the account; null when signed out.
  final String? owner;

  @override
  Future<List<CalendarEvent>> build() async {
    final repository = ref.watch(eventRepositoryProvider);
    if (owner == null) return const [];
    return repository.list();
  }

  /// Saves a new event; the calendar shows it without a reload. Throws
  /// `PeopleFailure`, and then the list stays as it was.
  Future<CalendarEvent> add(EventDraft draft) async {
    final event = await ref.read(eventRepositoryProvider).add(draft);
    _put(event);
    return event;
  }

  /// Saves [id] as [draft]. Throws `PeopleFailure`.
  Future<CalendarEvent> save(String id, EventDraft draft) async {
    final event = await ref.read(eventRepositoryProvider).update(id, draft);
    _put(event);
    return event;
  }

  /// Throws `PeopleFailure`, and then the event stays.
  Future<void> remove(String id) async {
    await ref.read(eventRepositoryProvider).remove(id);
    if (!ref.mounted) return;
    state = AsyncData([
      for (final event in state.value ?? const <CalendarEvent>[])
        if (event.id != id) event,
    ]);
  }

  /// Throws `PeopleFailure`, and then nobody is added.
  Future<void> invite(String eventId, Iterable<String> personIds) async {
    await ref.read(eventRepositoryProvider).invite(eventId, personIds);
    await _reload();
  }

  Future<void> uninvite(String eventId, String personId) async {
    await ref.read(eventRepositoryProvider).uninvite(eventId, personId);
    await _reload();
  }

  /// Marks who was there. Their histories and last contact move with it, so
  /// the book and any open history reload too. Throws `PeopleFailure`.
  Future<void> markDone(
    String eventId,
    Iterable<String> came,
    DateTime today,
  ) async {
    try {
      await ref.read(eventRepositoryProvider).markDone(eventId, came, today);
    } on PeopleFailure {
      ref.invalidateSelf();
      rethrow;
    }
    if (!ref.mounted) return;
    ref
      ..invalidate(peopleProvider(owner))
      ..invalidate(historyProvider);
    await _reload();
  }

  /// The embed is the truth for attendance: read it again.
  Future<void> _reload() async {
    if (!ref.mounted) return;
    ref.invalidateSelf();
    try {
      await future;
    } on PeopleFailure {
      // The change landed; the list shows its own load error.
    }
  }

  void _put(CalendarEvent saved) {
    if (!ref.mounted) return;
    state = AsyncData(
      byStart([
        for (final event in state.value ?? const <CalendarEvent>[])
          if (event.id != saved.id) event,
        saved,
      ]),
    );
  }
}

/// The month the grid shows (its 1st) and the selected day, both local
/// midnights.
typedef CalendarSelection = ({DateTime month, DateTime day});

/// What the Calendar shows. UI state: not per account, and it resets on
/// restart, to today.
final calendarSelectionProvider =
    NotifierProvider<CalendarSelector, CalendarSelection>(CalendarSelector.new);

class CalendarSelector extends Notifier<CalendarSelection> {
  @override
  CalendarSelection build() => _on(today());

  static CalendarSelection _on(DateTime day) =>
      (month: DateTime(day.year, day.month), day: day);

  /// A day of a neighbouring month shows that month.
  void select(DateTime day) => state = _on(day);

  /// The month [delta] months away, with its 1st selected, or today when
  /// it is the current month.
  void shift(int delta) {
    final month = DateTime(state.month.year, state.month.month + delta);
    final now = today();
    select(month.year == now.year && month.month == now.month ? now : month);
  }

  void toToday() => select(today());
}

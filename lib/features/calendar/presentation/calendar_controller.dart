import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loomia/core/ui/pick_day.dart';
import 'package:loomia/features/calendar/data/event_repository.dart';
import 'package:loomia/features/calendar/domain/calendar_event.dart';
import 'package:loomia/features/calendar/domain/month_grid.dart';
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
    return repository.list(today());
  }

  /// Saves a new event; the calendar shows it without a reload. Throws
  /// `PeopleFailure`, and then the list stays as it was.
  Future<CalendarEvent> add(EventDraft draft) async {
    final event = await ref.read(eventRepositoryProvider).add(draft);
    _put(event);
    return event;
  }

  /// Saves a series repeating by [rule] in [zone], then reloads: Postgres
  /// generates the occurrences. Resolves to the first one. Throws
  /// `PeopleFailure`.
  Future<CalendarEvent> addRepeating(
    EventDraft draft,
    RepeatRule rule,
    String zone,
  ) async {
    final id = await ref
        .read(eventRepositoryProvider)
        .addSeries(draft, rule, zone);
    await _reload();
    final first = (state.value ?? const <CalendarEvent>[])
        .where((event) => event.series?.id == id)
        .firstOrNull;
    // The series saved, the reload failed: the list says so.
    return first ?? (throw PeopleFailure.network);
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

  /// Saves the single event [id] as [draft], then makes it the first
  /// occurrence of a series repeating by [rule] in [zone] (#299). Resolves
  /// to it, reloaded. Throws `PeopleFailure`.
  Future<CalendarEvent> repeat(
    String id,
    EventDraft draft,
    RepeatRule rule,
    String zone,
  ) async {
    final repository = ref.read(eventRepositoryProvider);
    await repository.update(id, draft);
    await repository.repeat(id, rule, zone);
    return _reloadTo(id);
  }

  /// "This and following events" on Save (#299): the occurrence [id], the
  /// not done ones after it and their series become [draft] repeating by
  /// [rule]. Resolves to the event in its place, which a new rule or day
  /// generates again. Throws `PeopleFailure`.
  Future<CalendarEvent> saveFollowing(
    String id,
    EventDraft draft,
    RepeatRule rule,
  ) async {
    final now = await ref
        .read(eventRepositoryProvider)
        .updateSeries(id, draft, rule, today());
    return _reloadTo(now);
  }

  /// "This and following events" on Delete (#299): the series ends before
  /// the occurrence [id]. Throws `PeopleFailure`.
  Future<void> endSeries(String id) async {
    await ref.read(eventRepositoryProvider).endSeries(id);
    await _reload();
  }

  Future<CalendarEvent> _reloadTo(String id) async {
    await _reload();
    final event = (state.value ?? const <CalendarEvent>[])
        .where((event) => event.id == id)
        .firstOrNull;
    // Saved, the reload failed: the list says so.
    return event ?? (throw PeopleFailure.network);
  }

  /// Throws `PeopleFailure`, and then nobody is added. [following], on an
  /// occurrence: they join it, the not done ones after it, and the series.
  Future<void> invite(
    String eventId,
    Iterable<String> personIds,
    DateTime on, {
    bool following = false,
  }) async {
    final repository = ref.read(eventRepositoryProvider);
    await (following
        ? repository.setSeriesPeople(eventId, add: personIds)
        : repository.invite(eventId, personIds, on));
    await _reload();
  }

  Future<void> setGoing(String eventId, String personId) async {
    await ref.read(eventRepositoryProvider).setGoing(eventId, personId);
    await _reload();
  }

  Future<void> followedUp(String eventId, String personId, DateTime on) async {
    await ref.read(eventRepositoryProvider).followedUp(eventId, personId, on);
    await _reload();
  }

  /// [following] as for [invite].
  Future<void> uninvite(
    String eventId,
    String personId, {
    bool following = false,
  }) async {
    final repository = ref.read(eventRepositoryProvider);
    await (following
        ? repository.setSeriesPeople(eventId, remove: [personId])
        : repository.uninvite(eventId, personId));
    await _reload();
  }

  /// Marks it done with who was there and what changed for them. Their
  /// stages, workflows and histories move with it, so the book and any open
  /// history reload too. Throws `PeopleFailure`.
  Future<void> close(
    String eventId,
    List<There> there,
    Iterable<String> inviteNext,
    DateTime today,
  ) async {
    try {
      await ref
          .read(eventRepositoryProvider)
          .close(eventId, there, inviteNext, today);
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

  Future<void> tick(String eventId, String stepId, DateTime on) async {
    await ref.read(eventRepositoryProvider).tick(eventId, stepId, on);
    await _reload();
  }

  Future<void> untick(String eventId, String stepId) async {
    await ref.read(eventRepositoryProvider).untick(eventId, stepId);
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

/// The Calendar's two views.
enum CalendarMode { month, week }

/// The view, the month the grid shows (its 1st) and the selected day, both
/// local midnights. In week view, [month] is the selected day's.
typedef CalendarSelection = ({CalendarMode mode, DateTime month, DateTime day});

/// The day [delta] pages away from [from]'s. Month view: that month's 1st,
/// or [today] in the current month. Week view: the same weekday, or
/// [today] in the current week, weeks starting on [firstDayOfWeek] (0 is
/// Sunday). Calendar dates, never 24-hour steps.
DateTime shiftedDay(
  CalendarSelection from,
  int delta,
  DateTime today,
  int firstDayOfWeek,
) {
  switch (from.mode) {
    case CalendarMode.month:
      final month = DateTime(from.month.year, from.month.month + delta);
      return month.year == today.year && month.month == today.month
          ? today
          : month;
    case CalendarMode.week:
      final day = from.day;
      final moved = DateTime(day.year, day.month, day.day + 7 * delta);
      return weekDays(moved, firstDayOfWeek).first ==
              weekDays(today, firstDayOfWeek).first
          ? today
          : moved;
  }
}

/// What the Calendar shows. UI state: not per account, and it resets on
/// restart, to today in month view.
final calendarSelectionProvider =
    NotifierProvider<CalendarSelector, CalendarSelection>(CalendarSelector.new);

class CalendarSelector extends Notifier<CalendarSelection> {
  @override
  CalendarSelection build() => _on(today(), CalendarMode.month);

  static CalendarSelection _on(DateTime day, CalendarMode mode) =>
      (mode: mode, month: DateTime(day.year, day.month), day: day);

  /// A day of a neighbouring month shows that month.
  void select(DateTime day) => state = _on(day, state.mode);

  /// Month or week; the selected day stays.
  void setMode(CalendarMode mode) => state = _on(state.day, mode);

  /// The page [delta] away: see [shiftedDay].
  void shift(int delta, {int firstDayOfWeek = 0}) =>
      select(shiftedDay(state, delta, today(), firstDayOfWeek));

  /// [month] (its 1st) with its 1st selected, or today when it is the
  /// current month.
  void showMonth(DateTime month) {
    final now = today();
    select(month.year == now.year && month.month == now.month ? now : month);
  }

  void toToday() => select(today());
}

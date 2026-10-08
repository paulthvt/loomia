import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loomia/features/calendar/presentation/calendar_controller.dart';
import 'package:loomia/features/contacts/data/people_repository.dart';
import 'package:loomia/features/contacts/domain/person.dart';
import 'package:loomia/features/contacts/domain/search_key.dart';
import 'package:loomia/features/contacts/presentation/history_controller.dart';
import 'package:loomia/features/workflows/domain/progress.dart';
import 'package:loomia/features/workflows/domain/workflow.dart';

/// One account's whole book, loaded once and kept in memory; every contacts
/// screen reads the signed-in one, `peopleProvider(account?.email)`. Sorted by
/// [searchKey] of the name.
///
/// Keyed by account because a rebuild carries the previous value into its
/// loading and error states: the next user must get a new instance, never the
/// last one rebuilt.
///
/// No automatic retry: a failed load shows its error with a Retry button.
// ponytail: a signed-out account's book stays in memory until the app
// restarts; dispose it on sign-out if that ever matters.
final peopleProvider =
    AsyncNotifierProvider.family<PeopleController, List<Person>, String?>(
      PeopleController.new,
      retry: (error, _) => null,
    );

class PeopleController extends AsyncNotifier<List<Person>> {
  PeopleController(this.owner);

  /// The email of the account whose book this is; null when signed out.
  final String? owner;

  /// How old the book may be before returning to the app reloads it. There is
  /// no realtime: this and pull to refresh are how other devices' changes
  /// arrive.
  static const Duration staleAfter = Duration(minutes: 1);

  DateTime? _loadedAt;

  PeopleRepository get _repository => ref.read(peopleRepositoryProvider);

  @override
  Future<List<Person>> build() async {
    final repository = ref.watch(peopleRepositoryProvider);
    if (owner == null) {
      _loadedAt = null;
      return const [];
    }
    final people = await repository.list();
    _loadedAt = DateTime.now();
    return _sorted(people);
  }

  bool isStaleAt(DateTime now) {
    final loadedAt = _loadedAt;
    return loadedAt != null && now.difference(loadedAt) > staleAfter;
  }

  /// Starts [workflow], its first step due counted from [today]. No workflow
  /// (none seeded yet): starts none.
  Future<Person> add(
    PersonDraft draft, {
    Workflow? workflow,
    required DateTime today,
  }) async {
    final person = await _repository.add(
      draft,
      place: workflow == null
          ? null
          : start(workflow, firstDue: firstDueDefault(workflow, today)),
    );
    _change((people) => [...people, person]);
    return person;
  }

  /// The import: everyone in one write, on [workflow] like [add], in their
  /// stage since [stageSince]; null is now.
  Future<List<Person>> addAll(
    List<PersonDraft> drafts, {
    Workflow? workflow,
    required DateTime today,
    DateTime? stageSince,
  }) async {
    final added = await _repository.addAll(
      drafts,
      place: workflow == null
          ? null
          : start(workflow, firstDue: firstDueDefault(workflow, today)),
      stageSince: stageSince,
    );
    _change((people) => [...people, ...added]);
    return added;
  }

  /// [stageSince] corrects the day their stage began; null keeps it.
  Future<void> save(Person person, {DateTime? stageSince}) async {
    _replace(await _repository.update(person, stageSince: stageSince));
    // The database moved the latest stage entry with it.
    if (stageSince != null && ref.mounted) {
      ref.invalidate(historyProvider(person.id));
    }
  }

  /// Moves all of [people] in one write. Waits for the server, which decides
  /// [Person.stageSince] and the status, and writes the history entries that
  /// are then reloaded. [follow] travels in the same update; null is "Nothing
  /// for now". A failure rethrows and changes nothing.
  Future<void> moveTo(
    List<Person> people,
    Stage stage, {
    FollowWith? follow,
  }) async {
    _replaceAll(
      await _repository.setStage(_ids(people), stage, place: _placeFor(follow)),
    );
    if (!ref.mounted) return;
    for (final person in people) {
      ref.invalidate(historyProvider(person.id));
    }
  }

  /// Corrects the day their stage began, to [day] (local midnight). The
  /// database moves the latest stage entry with it, so the history reloads.
  Future<void> setStageSince(Person person, DateTime day) async {
    _replace(await _repository.setStageSince(person.id, day));
    if (ref.mounted) ref.invalidate(historyProvider(person.id));
  }

  /// Change workflow, for all of [people] in one write; null is "Nothing for
  /// now".
  Future<void> setWorkflow(List<Person> people, FollowWith? follow) async {
    _replaceAll(await _repository.setPlace(_ids(people), _placeFor(follow)));
  }

  /// Ticks [progress]'s step on [today]: a history entry, and the next step.
  Future<void> completeStep(
    Person person,
    OnStep progress,
    DateTime today,
  ) async {
    _replace(
      await _repository.completeStep(person.id, progress.step.id, today),
    );
    if (ref.mounted) ref.invalidate(historyProvider(person.id));
  }

  Future<void> addReminder(Person person, String text, DateTime dueOn) async {
    final added = await _repository.addReminder(person.id, text, dueOn);
    _changeReminders(person.id, (reminders) => [...reminders, added]);
  }

  Future<void> editReminder(
    Person person,
    Reminder reminder,
    String text,
    DateTime dueOn,
  ) async {
    final saved = await _repository.updateReminder(reminder.id, text, dueOn);
    _changeReminders(
      person.id,
      (reminders) => [
        for (final other in reminders) other.id == saved.id ? saved : other,
      ],
    );
  }

  Future<void> deleteReminder(Person person, Reminder reminder) async {
    await _repository.deleteReminder(reminder.id);
    _changeReminders(
      person.id,
      (reminders) => [...reminders.where((other) => other.id != reminder.id)],
    );
  }

  /// The history entry and the delete, on the server; the person comes back
  /// as it left them, contact counted.
  Future<void> completeReminder(
    Person person,
    Reminder reminder,
    DateTime today,
  ) async {
    _replace(await _repository.completeReminder(reminder.id, today));
    if (ref.mounted) ref.invalidate(historyProvider(person.id));
  }

  void _changeReminders(
    String id,
    List<Reminder> Function(List<Reminder> reminders) change,
  ) => _change(
    (people) => [
      for (final other in people)
        other.id == id ? other.withReminders(change(other.reminders)) : other,
    ],
  );

  /// Hides the next step; a prospect also becomes Not now.
  Future<void> pause(Person person) async {
    _replace(
      await _repository.pause(
        person.id,
        DateTime.now(),
        notNow: person.stage == Stage.prospect,
      ),
    );
  }

  /// The same step comes back, due counted from [today].
  Future<void> resume(Person person, DateTime today) async {
    _replace(await _repository.resume(person.id, today));
  }

  static WorkflowPlace? _placeFor(FollowWith? follow) =>
      follow == null ? null : start(follow.workflow, firstDue: follow.firstDue);

  /// All of [ids] in one write.
  Future<void> remove(List<String> ids) async {
    await _repository.delete(ids);
    _change((people) => [...people.where((other) => !ids.contains(other.id))]);
    // The database also took them off their events: the calendar's counts
    // are stale until it reads them again.
    if (ref.mounted) ref.invalidate(eventsProvider(owner));
  }

  static List<String> _ids(List<Person> people) => [
    for (final person in people) person.id,
  ];

  /// Shown at once, saved behind. A failure puts the previous status back —
  /// unless a newer tap has replaced this one meanwhile — and rethrows.
  Future<void> setStatus(Person person, ProspectStatus? status) async {
    final before = _find(person.id)?.prospectStatus;
    _setStatusLocally(person.id, status);
    try {
      await _repository.update((_find(person.id) ?? person).withStatus(status));
    } catch (_) {
      if (_find(person.id)?.prospectStatus == status) {
        _setStatusLocally(person.id, before);
      }
      rethrow;
    }
  }

  Person? _find(String id) =>
      state.value?.where((person) => person.id == id).firstOrNull;

  void _replace(Person saved) => _replaceAll([saved]);

  void _replaceAll(List<Person> saved) {
    final byId = {for (final person in saved) person.id: person};
    _change((people) => [for (final other in people) byId[other.id] ?? other]);
  }

  void _setStatusLocally(String id, ProspectStatus? status) => _change(
    (people) => [
      for (final other in people)
        other.id == id ? other.withStatus(status) : other,
    ],
  );

  void _change(List<Person> Function(List<Person> people) change) {
    // Rebuilt or disposed while a save was in flight: the new build has the
    // truth. Checked first: reading state once unmounted throws.
    if (!ref.mounted) return;
    final people = state.value;
    if (people == null) return;
    state = AsyncData(_sorted(change(people)));
  }

  static List<Person> _sorted(Iterable<Person> people) =>
      [...people]
        ..sort((a, b) => searchKey(a.name).compareTo(searchKey(b.name)));
}

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loomia/features/auth/data/auth_repository.dart';
import 'package:loomia/features/contacts/data/activity_repository.dart';
import 'package:loomia/features/contacts/domain/activity.dart';
import 'package:loomia/features/contacts/presentation/people_controller.dart';

/// One person's history, fetched when their page opens and dropped when it
/// closes. Keyed by person id: ids are uuids, so no account ever reads another
/// account's cached history.
///
/// Latest day first, then latest made. No automatic retry: a failed load shows
/// its error with Retry inside the section.
final historyProvider = AsyncNotifierProvider.autoDispose
    .family<HistoryController, List<Activity>, String>(
      HistoryController.new,
      retry: (error, _) => null,
    );

class HistoryController extends AsyncNotifier<List<Activity>> {
  HistoryController(this.personId);

  final String personId;

  ActivityRepository get _repository => ref.read(activityRepositoryProvider);

  @override
  Future<List<Activity>> build() async =>
      _sorted(await ref.watch(activityRepositoryProvider).list(personId));

  /// Waits for the server; a failure rethrows and leaves the list as it was.
  Future<void> add(ActivityDraft draft) async {
    // Alive until the save lands, even if the sheet closes: the book must
    // still reload.
    final alive = ref.keepAlive();
    try {
      final activity = await _repository.add(personId, draft);
      _change((entries) => [...entries, activity]);
      _reloadBook();
    } finally {
      alive.close();
    }
  }

  /// Waits for the server; a failure rethrows and leaves the list as it was.
  Future<void> edit(Activity activity, ActivityDraft draft) async {
    final alive = ref.keepAlive();
    try {
      final edited = await _repository.update(activity.id, draft);
      _change(
        (entries) => [
          for (final entry in entries) entry.id == edited.id ? edited : entry,
        ],
      );
      _reloadBook();
    } finally {
      alive.close();
    }
  }

  /// Gone at once, deleted behind. A failure puts it back and rethrows.
  Future<void> remove(Activity activity) async {
    _change((entries) => [...entries.where((e) => e.id != activity.id)]);
    final alive = ref.keepAlive();
    try {
      await _repository.delete(activity.id);
      _reloadBook();
    } catch (_) {
      _change(
        (entries) => [...entries.where((e) => e.id != activity.id), activity],
      );
      rethrow;
    } finally {
      alive.close();
    }
  }

  /// Last contact is the server's answer: the book re-reads it.
  void _reloadBook() {
    if (!ref.mounted) return;
    ref.invalidate(peopleProvider(ref.read(accountProvider)?.email));
  }

  void _change(List<Activity> Function(List<Activity> entries) change) {
    // Disposed or rebuilt while a save was in flight: the next build has the
    // truth.
    if (!ref.mounted) return;
    final entries = state.value;
    if (entries == null) return;
    state = AsyncData(_sorted(change(entries)));
  }

  static List<Activity> _sorted(Iterable<Activity> entries) =>
      [...entries]..sort((a, b) {
        final byDay = b.day.compareTo(a.day);
        return byDay != 0 ? byDay : b.createdAt.compareTo(a.createdAt);
      });
}

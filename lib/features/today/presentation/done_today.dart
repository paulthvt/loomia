import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loomia/features/contacts/data/activity_repository.dart';

/// Today's ticks so far, for the hero's "X of N done". Keyed by the day, so
/// a resume on the next day reads a new count. Disposed with Today: ticks
/// made elsewhere show once Today is opened again. No automatic retry: an
/// unknown count hides the bar, and pull to refresh asks again.
final doneTodayProvider = AsyncNotifierProvider.autoDispose
    .family<DoneToday, int, ({String? owner, DateTime day})>(
      DoneToday.new,
      retry: (error, _) => null,
    );

class DoneToday extends AsyncNotifier<int> {
  DoneToday(this.key);

  final ({String? owner, DateTime day}) key;

  @override
  Future<int> build() async => key.owner == null
      ? 0
      : ref.watch(activityRepositoryProvider).doneOn(key.day);

  /// A tick on Today went through: counted at once, in the same frame the
  /// row leaves. An unknown count stays unknown.
  void add() {
    if (state case AsyncData(:final value)) state = AsyncData(value + 1);
  }
}

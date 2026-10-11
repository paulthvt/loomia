import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:loomia/features/contacts/domain/people_failure.dart';
import 'package:loomia/features/notifications/data/notifications_repository.dart';
import 'package:loomia/features/notifications/data/push.dart';
import 'package:loomia/features/notifications/domain/notification_settings.dart';

/// One account's daily summary settings, keyed by email like `eventsProvider`;
/// null until the user has answered Today's card or touched Settings. No
/// automatic retry.
final notificationSettingsProvider =
    AsyncNotifierProvider.family<
      NotificationSettingsController,
      NotificationSettings?,
      String?
    >(NotificationSettingsController.new, retry: (error, _) => null);

class NotificationSettingsController
    extends AsyncNotifier<NotificationSettings?> {
  NotificationSettingsController(this.owner);

  final String? owner;

  @override
  Future<NotificationSettings?> build() async {
    final repository = ref.watch(notificationsRepositoryProvider);
    if (owner == null) return null;
    return repository.load();
  }

  /// Shows [next] at once and saves it; an unchanged value saves nothing.
  /// Throws `PeopleFailure`, and then the previous value is back.
  Future<void> save(NotificationSettings next) async {
    final previous = state.value;
    if (next == previous) return;
    state = AsyncData(next);
    try {
      await ref.read(notificationsRepositoryProvider).save(next);
    } on PeopleFailure {
      if (ref.mounted) state = AsyncData(previous);
      rethrow;
    }
  }

  /// The phone's zone, on launch, when it moved: the summary follows the
  /// user. Nothing to do without a row; a failure waits for the next launch.
  Future<void> followDevice(String zone) async {
    try {
      final current = await future;
      if (current == null || current.timeZone == zone) return;
      await save(current.copyWith(timeZone: zone));
    } on PeopleFailure {
      // Logged by guardPeople.
    }
  }
}

/// The device's IANA zone; null when it can't be read.
final deviceTimeZoneProvider = FutureProvider<String?>((ref) async {
  try {
    return (await FlutterTimezone.getLocalTimezone()).identifier;
  } on Object {
    return null;
  }
});

/// Whether push works on this device (Android or iOS with Firebase).
final pushAvailableProvider = FutureProvider<bool>(
  (ref) => ref.watch(pushProvider).available,
);

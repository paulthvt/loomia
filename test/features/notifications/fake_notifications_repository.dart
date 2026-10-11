import 'package:loomia/features/contacts/domain/people_failure.dart';
import 'package:loomia/features/notifications/data/notifications_repository.dart';
import 'package:loomia/features/notifications/domain/notification_settings.dart';

/// In memory; [failure] makes the next calls throw it.
class FakeNotificationsRepository implements NotificationsRepository {
  FakeNotificationsRepository([this.settings]);

  NotificationSettings? settings;
  PeopleFailure? failure;
  final saved = <NotificationSettings>[];

  @override
  Future<NotificationSettings?> load() async {
    if (failure case final failure?) throw failure;
    return settings;
  }

  @override
  Future<void> save(NotificationSettings next) async {
    if (failure case final failure?) throw failure;
    saved.add(next);
    settings = next;
  }
}

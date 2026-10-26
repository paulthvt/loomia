import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loomia/features/notifications/data/notifications_repository.dart';
import 'package:loomia/features/notifications/domain/notification_settings.dart';
import 'package:loomia/features/notifications/presentation/notifications_controller.dart';

import '../fake_notifications_repository.dart';

void main() {
  Future<(FakeNotificationsRepository, NotificationSettingsController)> open(
    NotificationSettings? settings,
  ) async {
    final repository = FakeNotificationsRepository(settings);
    final container = ProviderContainer(
      overrides: [
        notificationsRepositoryProvider.overrideWithValue(repository),
      ],
    );
    addTearDown(container.dispose);
    final provider = notificationSettingsProvider('p@example.com');
    await container.read(provider.future);
    return (repository, container.read(provider.notifier));
  }

  test(
    'ensureFor makes a row with every push off when there is none',
    () async {
      final (repository, controller) = await open(null);

      await controller.ensureFor('Europe/Paris');

      expect(repository.saved, [
        const NotificationSettings(timeZone: 'Europe/Paris'),
      ]);
      expect(repository.settings!.any, isFalse);
    },
  );

  test('ensureFor leaves an existing row alone', () async {
    const existing = NotificationSettings(
      timeZone: 'America/New_York',
      enabled: true,
    );
    final (repository, controller) = await open(existing);

    await controller.ensureFor('Europe/Paris');

    expect(repository.saved, isEmpty);
    expect(repository.settings, existing);
  });
}

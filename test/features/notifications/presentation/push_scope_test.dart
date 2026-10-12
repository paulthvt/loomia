import 'package:flutter_test/flutter_test.dart';
import 'package:loomia/app/router/app_router.dart';
import 'package:loomia/app/router/routes.dart';
import 'package:loomia/features/auth/domain/account.dart';
import 'package:loomia/features/auth/domain/auth_change.dart';
import 'package:loomia/features/notifications/domain/notification_settings.dart';
import 'package:material_ui/material_ui.dart';

import '../../../app/app_harness.dart';
import '../../auth/fake_auth_repository.dart';
import '../fake_notifications_repository.dart';
import '../fake_push.dart';

void main() {
  const phone = Size(390, 844);

  testWidgets('registers once, in the app language, again when it changes', (
    tester,
  ) async {
    final push = FakePush();
    final auth = FakeAuthRepository()
      ..session = true
      ..account = const Account(
        firstName: 'Pauline',
        email: 'p@example.com',
        locale: 'fr',
      );
    await pumpLoomia(tester, size: phone, auth: auth, push: push);
    expect(push.registered, ['fr']);

    auth
      ..account = const Account(
        firstName: 'Pauline',
        email: 'p@example.com',
        locale: 'en',
      )
      ..emit(AuthChange.userUpdated);
    await tester.pumpAndSettle();
    expect(push.registered, ['fr', 'en']);
  });

  testWidgets('a tapped push opens Today', (tester) async {
    final push = FakePush();
    final container = await pumpLoomia(tester, size: phone, push: push);
    container.read(routerProvider).go(Routes.goals);
    await tester.pumpAndSettle();

    push.tap();
    await tester.pumpAndSettle();
    expect(
      container
          .read(routerProvider)
          .routerDelegate
          .currentConfiguration
          .uri
          .path,
      Routes.today,
    );
  });

  testWidgets('the summary follows the phone to another time zone', (
    tester,
  ) async {
    final notifications = FakeNotificationsRepository(
      const NotificationSettings(enabled: true, timeZone: 'America/New_York'),
    );
    await pumpLoomia(tester, size: phone, notifications: notifications);
    expect(notifications.saved.single.timeZone, 'Europe/Paris');
  });

  testWidgets('no settings yet: nothing written', (tester) async {
    final notifications = FakeNotificationsRepository();
    await pumpLoomia(tester, size: phone, notifications: notifications);
    expect(notifications.saved, isEmpty);
  });

  group('summary on, this phone not allowed', () {
    const on = NotificationSettings(enabled: true, timeZone: 'Europe/Paris');

    testWidgets('asks on launch', (tester) async {
      final push = FakePush();
      await pumpLoomia(
        tester,
        size: phone,
        push: push,
        notifications: FakeNotificationsRepository(on),
      );
      expect(push.asked, 1);
    });

    testWidgets('not when allowed, off, or never answered', (tester) async {
      for (final (allowed, settings) in [
        (true, on),
        (false, on.copyWith(enabled: false)),
        (false, null),
      ]) {
        final push = FakePush(isAllowed: allowed);
        await pumpLoomia(
          tester,
          size: phone,
          push: push,
          notifications: FakeNotificationsRepository(settings),
        );
        expect(push.asked, 0, reason: '$allowed $settings');
      }
    });
  });
}

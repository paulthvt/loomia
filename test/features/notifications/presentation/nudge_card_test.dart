import 'package:flutter_test/flutter_test.dart';
import 'package:loomia/features/notifications/domain/notification_settings.dart';
import 'package:material_ui/material_ui.dart';

import '../../../app/app_harness.dart';
import '../fake_notifications_repository.dart';
import '../fake_push.dart';

void main() {
  const phone = Size(390, 844);
  const title = 'Want a nudge at 7:00 PM on weekdays?';

  testWidgets('asked on Today until answered: Turn on', (tester) async {
    final push = FakePush();
    final notifications = FakeNotificationsRepository();
    await pumpLoomia(
      tester,
      size: phone,
      push: push,
      notifications: notifications,
    );
    expect(find.text(title), findsOneWidget);

    await tester.ensureVisible(find.text('Turn on'));
    await tester.tap(find.text('Turn on'));
    await tester.pumpAndSettle();
    expect(push.asked, 1);
    expect(
      notifications.saved.single,
      const NotificationSettings(enabled: true, timeZone: 'Europe/Paris'),
    );
    expect(find.text(title), findsNothing);
  });

  testWidgets('Turn on refused by the phone: saved off', (tester) async {
    final notifications = FakeNotificationsRepository();
    await pumpLoomia(
      tester,
      size: phone,
      push: FakePush(grant: false),
      notifications: notifications,
    );
    await tester.ensureVisible(find.text('Turn on'));
    await tester.tap(find.text('Turn on'));
    await tester.pumpAndSettle();
    expect(notifications.saved.single.enabled, isFalse);
    expect(find.text(title), findsNothing);
  });

  testWidgets('Not now: saved off, never asked', (tester) async {
    final push = FakePush();
    final notifications = FakeNotificationsRepository();
    await pumpLoomia(
      tester,
      size: phone,
      push: push,
      notifications: notifications,
    );
    await tester.ensureVisible(find.text('Not now'));
    await tester.tap(find.text('Not now'));
    await tester.pumpAndSettle();
    expect(push.asked, 0);
    expect(notifications.saved.single.enabled, isFalse);
    expect(find.text(title), findsNothing);
  });

  testWidgets('not shown once answered, nor without push', (tester) async {
    await pumpLoomia(
      tester,
      size: phone,
      push: FakePush(),
      notifications: FakeNotificationsRepository(
        const NotificationSettings(timeZone: 'Europe/Paris'),
      ),
    );
    expect(find.text(title), findsNothing);

    await pumpLoomia(tester, size: phone, push: FakePush(isAvailable: false));
    expect(find.text(title), findsNothing);
  });
}

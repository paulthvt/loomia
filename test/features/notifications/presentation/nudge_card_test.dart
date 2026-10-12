import 'package:flutter_test/flutter_test.dart';
import 'package:loomia/features/notifications/domain/notification_settings.dart';
import 'package:material_ui/material_ui.dart';

import '../../../app/app_harness.dart';
import '../fake_notifications_repository.dart';
import '../fake_push.dart';

void main() {
  const phone = Size(390, 844);
  const title = 'Want a daily nudge?';

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

  testWidgets('the time is chosen on the card, and Turn on saves it', (
    tester,
  ) async {
    final notifications = FakeNotificationsRepository();
    await pumpLoomia(
      tester,
      size: phone,
      push: FakePush(),
      notifications: notifications,
    );
    await tester.ensureVisible(find.text('7:00 PM'));
    await tester.tap(find.text('7:00 PM'));
    await tester.pumpAndSettle();
    // The Material picker, typed rather than dialled.
    await tester.tap(find.byIcon(Icons.keyboard_outlined));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).at(0), '8');
    await tester.enterText(find.byType(TextField).at(1), '30');
    await tester.tap(find.text('AM'));
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    expect(find.text('8:30 AM'), findsOneWidget);

    await tester.ensureVisible(find.text('Turn on'));
    await tester.tap(find.text('Turn on'));
    await tester.pumpAndSettle();
    final saved = notifications.saved.single;
    expect((saved.enabled, saved.hour, saved.minute), (true, 8, 30));
  });

  testWidgets('the picker dismissed keeps 7:00 PM', (tester) async {
    final notifications = FakeNotificationsRepository();
    await pumpLoomia(
      tester,
      size: phone,
      push: FakePush(),
      notifications: notifications,
    );
    await tester.ensureVisible(find.text('7:00 PM'));
    await tester.tap(find.text('7:00 PM'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.text('7:00 PM'), findsOneWidget);
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

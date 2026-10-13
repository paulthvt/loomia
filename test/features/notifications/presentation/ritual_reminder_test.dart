import 'package:flutter_test/flutter_test.dart';
import 'package:loomia/app/router/app_router.dart';
import 'package:loomia/app/router/routes.dart';
import 'package:loomia/features/notifications/domain/notification_settings.dart';
import 'package:material_ui/material_ui.dart';

import '../../../app/app_harness.dart';
import '../fake_notifications_repository.dart';
import '../fake_push.dart';

void main() {
  final reminder = find.textContaining('Remind me when');

  Future<void> open(
    WidgetTester tester, {
    required FakePush push,
    required FakeNotificationsRepository notifications,
  }) async {
    final container = await pumpLoomia(
      tester,
      size: const Size(390, 2400),
      push: push,
      notifications: notifications,
    );
    container.read(routerProvider).go(Routes.goalsPlan);
    await tester.pumpAndSettle();
  }

  testWidgets('no push here (web): not offered', (tester) async {
    await open(
      tester,
      push: FakePush(isAvailable: false),
      notifications: FakeNotificationsRepository(),
    );
    expect(find.text('Save'), findsOneWidget);
    expect(reminder, findsNothing);
  });

  testWidgets('no row yet: on asks, then saves it with the summary off', (
    tester,
  ) async {
    final push = FakePush();
    final notifications = FakeNotificationsRepository();
    await open(tester, push: push, notifications: notifications);
    expect(
      find.text("One note at 7:00 PM when it's time to close it."),
      findsOneWidget,
    );

    await tester.tap(reminder);
    await tester.pumpAndSettle();
    expect(push.asked, 1);
    expect(
      notifications.saved.single,
      const NotificationSettings(ritual: true, timeZone: 'Europe/Paris'),
    );
    expect(
      tester.widget<SwitchListTile>(find.byType(SwitchListTile)).value,
      isTrue,
    );
  });

  testWidgets('refused by the phone: nothing saved, still off', (tester) async {
    final notifications = FakeNotificationsRepository();
    await open(
      tester,
      push: FakePush(grant: false),
      notifications: notifications,
    );

    await tester.tap(reminder);
    await tester.pumpAndSettle();
    expect(notifications.saved, isEmpty);
    expect(
      tester.widget<SwitchListTile>(find.byType(SwitchListTile)).value,
      isFalse,
    );
  });

  testWidgets('on already: off saves off and keeps the summary', (
    tester,
  ) async {
    final push = FakePush(isAllowed: true);
    final notifications = FakeNotificationsRepository(
      const NotificationSettings(
        enabled: true,
        ritual: true,
        hour: 8,
        timeZone: 'Europe/Paris',
      ),
    );
    await open(tester, push: push, notifications: notifications);
    expect(
      find.text("One note at 8:00 AM when it's time to close it."),
      findsOneWidget,
    );

    await tester.tap(reminder);
    await tester.pumpAndSettle();
    expect(push.asked, 0, reason: 'turning off asks nothing');
    expect(
      notifications.saved.single,
      const NotificationSettings(
        enabled: true,
        hour: 8,
        timeZone: 'Europe/Paris',
      ),
    );
  });
}

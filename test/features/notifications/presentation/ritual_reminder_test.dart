import 'package:flutter_test/flutter_test.dart';
import 'package:loomia/app/router/app_router.dart';
import 'package:loomia/app/router/routes.dart';
import 'package:loomia/features/notifications/domain/notification_settings.dart';
import 'package:material_ui/material_ui.dart';

import '../../../app/app_harness.dart';
import '../fake_notifications_repository.dart';
import '../fake_push.dart';

void main() {
  final reminder = find.textContaining('Remind me to review');
  final save = find.widgetWithText(FilledButton, 'Save');

  bool shown(WidgetTester tester) =>
      tester.widget<SwitchListTile>(find.byType(SwitchListTile)).value;

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
    expect(save, findsOneWidget);
    expect(reminder, findsNothing);
  });

  testWidgets('says what it is for, with a bell; on by default', (
    tester,
  ) async {
    await open(
      tester,
      push: FakePush(),
      notifications: FakeNotificationsRepository(),
    );

    expect(
      find.textContaining(
        RegExp(
          r'^At the end of \w+, at 7:00 PM: see how it went and set '
          r'your goals for \w+\.$',
        ),
      ),
      findsOneWidget,
    );
    expect(shown(tester), isTrue);
    expect(find.byIcon(Icons.notifications_active_rounded), findsOneWidget);
  });

  testWidgets('no row yet: Save asks, then saves it with the summary off', (
    tester,
  ) async {
    final push = FakePush();
    final notifications = FakeNotificationsRepository();
    await open(tester, push: push, notifications: notifications);
    expect(push.asked, 0, reason: 'nothing asked before Save');

    await tester.tap(save);
    await tester.pumpAndSettle();
    expect(push.asked, 1);
    expect(
      notifications.saved.single,
      const NotificationSettings(
        ritual: true,
        ritualChosen: true,
        timeZone: 'Europe/Paris',
      ),
    );
  });

  testWidgets('turned off in Settings: off here, and Save keeps it off', (
    tester,
  ) async {
    final push = FakePush();
    final notifications = FakeNotificationsRepository(
      const NotificationSettings(ritualChosen: true, timeZone: 'Europe/Paris'),
    );
    await open(tester, push: push, notifications: notifications);
    expect(shown(tester), isFalse);

    await tester.tap(save);
    await tester.pumpAndSettle();
    expect(push.asked, 0);
    expect(notifications.saved, isEmpty);
  });

  testWidgets('turned off here: Save asks nothing and saves the choice', (
    tester,
  ) async {
    final push = FakePush();
    final notifications = FakeNotificationsRepository();
    await open(tester, push: push, notifications: notifications);

    await tester.tap(reminder);
    await tester.pump();
    expect(shown(tester), isFalse);
    expect(find.byIcon(Icons.notifications_off_outlined), findsOneWidget);
    await tester.tap(save);
    await tester.pumpAndSettle();
    expect(push.asked, 0);
    expect(
      notifications.saved.single,
      const NotificationSettings(ritualChosen: true, timeZone: 'Europe/Paris'),
      reason: 'next month it opens off',
    );
  });

  testWidgets('refused by the phone: nothing saved', (tester) async {
    final notifications = FakeNotificationsRepository();
    await open(
      tester,
      push: FakePush(grant: false),
      notifications: notifications,
    );

    await tester.tap(save);
    await tester.pumpAndSettle();
    expect(notifications.saved, isEmpty);
  });

  testWidgets('on already: off, then Save, saves off and keeps the summary', (
    tester,
  ) async {
    final push = FakePush(isAllowed: true);
    final notifications = FakeNotificationsRepository(
      const NotificationSettings(
        enabled: true,
        ritual: true,
        ritualChosen: true,
        hour: 8,
        timeZone: 'Europe/Paris',
      ),
    );
    await open(tester, push: push, notifications: notifications);
    expect(find.textContaining('at 8:00 AM:'), findsOneWidget);

    await tester.tap(reminder);
    await tester.pump();
    expect(notifications.saved, isEmpty, reason: 'only Save applies it');
    await tester.tap(save);
    await tester.pumpAndSettle();
    expect(push.asked, 0, reason: 'turning off asks nothing');
    expect(
      notifications.saved.single,
      const NotificationSettings(
        enabled: true,
        ritualChosen: true,
        hour: 8,
        timeZone: 'Europe/Paris',
      ),
    );
  });
}

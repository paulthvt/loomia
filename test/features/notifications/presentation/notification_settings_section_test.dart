import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loomia/app/router/app_router.dart';
import 'package:loomia/app/router/routes.dart';
import 'package:loomia/features/contacts/domain/people_failure.dart';
import 'package:loomia/features/notifications/domain/notification_settings.dart';
import 'package:material_ui/material_ui.dart';

import '../../../app/app_harness.dart';
import '../fake_notifications_repository.dart';
import '../fake_push.dart';

void main() {
  const phone = Size(390, 844);
  const on = NotificationSettings(enabled: true, timeZone: 'Europe/Paris');

  Future<void> open(
    WidgetTester tester, {
    FakePush? push,
    FakeNotificationsRepository? notifications,
  }) async {
    final container = await pumpLoomia(
      tester,
      size: phone,
      push: push ?? FakePush(isAllowed: true),
      notifications: notifications,
    );
    container.read(routerProvider).go(Routes.settingsNotifications);
    await tester.pumpAndSettle();
  }

  bool switchedOn(WidgetTester tester) =>
      tester.widget<Switch>(find.byType(Switch)).value;

  FilterChip chip(WidgetTester tester, int day) =>
      tester.widget<FilterChip>(find.byKey(ValueKey('day-$day')));

  testWidgets('nothing saved: off, the defaults, the device zone', (
    tester,
  ) async {
    await open(tester);
    expect(switchedOn(tester), isFalse);
    expect(find.text('7:00 PM'), findsOneWidget);
    expect(find.text('Time zone: Europe/Paris'), findsOneWidget);
    expect(chip(tester, 1).selected, isTrue);
    expect(chip(tester, 6).selected, isFalse);
    expect(chip(tester, 1).onSelected, isNull, reason: 'disabled while off');
    expect(
      find.text('Notifications come to the Android and iOS app.'),
      findsNothing,
    );
  });

  testWidgets('turning it on asks the phone and saves', (tester) async {
    final push = FakePush();
    final notifications = FakeNotificationsRepository();
    await open(tester, push: push, notifications: notifications);

    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();
    expect(push.asked, 1);
    expect(notifications.saved.single, on);
    expect(switchedOn(tester), isTrue);
    expect(
      find.text("Notifications are off for Loomia in your phone's settings."),
      findsNothing,
    );
  });

  testWidgets('refused by the phone: on, with the warning', (tester) async {
    final notifications = FakeNotificationsRepository();
    await open(
      tester,
      push: FakePush(grant: false),
      notifications: notifications,
    );

    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();
    expect(notifications.saved.single.enabled, isTrue);
    expect(
      find.text("Notifications are off for Loomia in your phone's settings."),
      findsOneWidget,
    );
  });

  testWidgets('on but not allowed here: Allow asks the phone', (tester) async {
    final push = FakePush();
    await open(
      tester,
      push: push,
      notifications: FakeNotificationsRepository(on),
    );
    // Launch asked once already (PushScope); the phone said no.
    push
      ..isAllowed = false
      ..asked = 0;
    await tester.pumpAndSettle();
    final container = ProviderScope.containerOf(
      tester.element(find.byType(Switch)),
    );
    container.read(routerProvider).go(Routes.settings);
    await tester.pumpAndSettle();
    container.read(routerProvider).go(Routes.settingsNotifications);
    await tester.pumpAndSettle();
    expect(
      find.text("Notifications are off for Loomia in your phone's settings."),
      findsOneWidget,
    );

    await tester.tap(find.text('Allow notifications'));
    await tester.pumpAndSettle();
    expect(push.asked, 1);
    expect(
      find.text("Notifications are off for Loomia in your phone's settings."),
      findsNothing,
    );
  });

  testWidgets('a day saves at once; the last one stays', (tester) async {
    final notifications = FakeNotificationsRepository(on);
    await open(tester, notifications: notifications);

    await tester.tap(find.byKey(const ValueKey('day-6')));
    await tester.pumpAndSettle();
    expect(notifications.saved.last.days, {1, 2, 3, 4, 5, 6});

    for (final day in [1, 2, 3, 4, 5]) {
      await tester.tap(find.byKey(ValueKey('day-$day')));
      await tester.pumpAndSettle();
    }
    expect(notifications.saved.last.days, {6});
    final saves = notifications.saved.length;
    await tester.tap(find.byKey(const ValueKey('day-6')));
    await tester.pumpAndSettle();
    expect(notifications.saved.length, saves, reason: 'nothing changed');
    expect(chip(tester, 6).selected, isTrue);
  });

  testWidgets('a failed save says so and shows what is saved', (tester) async {
    final notifications = FakeNotificationsRepository(on);
    await open(tester, notifications: notifications);

    notifications.failure = PeopleFailure.network;
    await tester.tap(find.byKey(const ValueKey('day-6')));
    await tester.pumpAndSettle();
    expect(chip(tester, 6).selected, isFalse);
    expect(find.textContaining('Check your connection'), findsOneWidget);
  });

  testWidgets('without push (web): the note, and no prompt', (tester) async {
    final push = FakePush(isAvailable: false);
    final notifications = FakeNotificationsRepository();
    await open(tester, push: push, notifications: notifications);

    expect(
      find.text('Notifications come to the Android and iOS app.'),
      findsOneWidget,
    );
    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();
    expect(push.asked, 0);
    expect(notifications.saved.single.enabled, isTrue);
  });

  testWidgets('the Settings row shows the time, or Off', (tester) async {
    final container = await pumpLoomia(
      tester,
      size: phone,
      notifications: FakeNotificationsRepository(on),
    );
    container.read(routerProvider).go(Routes.settings);
    await tester.pumpAndSettle();
    expect(find.text('7:00 PM'), findsOneWidget);
  });
}

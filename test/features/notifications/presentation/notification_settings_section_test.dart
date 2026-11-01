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
      tester.widget<Switch>(find.byType(Switch).first).value;

  FilterChip chip(WidgetTester tester, int day) =>
      tester.widget<FilterChip>(find.byKey(ValueKey('day-$day')));

  /// The page's own scroll, not the days' row.
  final page = find.byWidgetPredicate(
    (widget) =>
        widget is Scrollable && widget.axisDirection == AxisDirection.down,
  );

  /// The days sit below the switches, off a phone's first screen.
  Future<void> tapDay(WidgetTester tester, int day) async {
    final finder = find.byKey(ValueKey('day-$day'));
    // Built but below the fold: scroll the page, clamped at its end.
    await tester.drag(page.first, const Offset(0, -400));
    await tester.pumpAndSettle();
    await tester.tap(finder);
  }

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

    await tester.tap(find.byType(Switch).first);
    await tester.pumpAndSettle();
    expect(push.asked, 1);
    expect(notifications.saved.single, on);
    expect(switchedOn(tester), isTrue);
    expect(
      find.text("Notifications are off for Loomia in your phone's settings."),
      findsNothing,
    );
  });

  testWidgets('the Sharing switch asks the phone and saves (#423)', (
    tester,
  ) async {
    final push = FakePush();
    final notifications = FakeNotificationsRepository();
    await open(tester, push: push, notifications: notifications);

    await tester.scrollUntilVisible(find.text('Sharing'), 100);
    await tester.tap(find.text('Sharing'));
    await tester.pumpAndSettle();
    expect(push.asked, 1);
    expect(notifications.saved.single.sharing, isTrue);
  });

  testWidgets('refused by the phone: on, with the warning', (tester) async {
    final notifications = FakeNotificationsRepository();
    await open(
      tester,
      push: FakePush(grant: false),
      notifications: notifications,
    );

    await tester.tap(find.byType(Switch).first);
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
      tester.element(find.byType(Switch).first),
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

    await tapDay(tester, 6);
    await tester.pumpAndSettle();
    expect(notifications.saved.last.days, {1, 2, 3, 4, 5, 6});

    for (final day in [1, 2, 3, 4, 5]) {
      await tapDay(tester, day);
      await tester.pumpAndSettle();
    }
    expect(notifications.saved.last.days, {6});
    final saves = notifications.saved.length;
    await tapDay(tester, 6);
    await tester.pumpAndSettle();
    expect(notifications.saved.length, saves, reason: 'nothing changed');
    expect(chip(tester, 6).selected, isTrue);
  });

  testWidgets('a failed save says so and shows what is saved', (tester) async {
    final notifications = FakeNotificationsRepository(on);
    await open(tester, notifications: notifications);

    notifications.failure = PeopleFailure.network;
    await tapDay(tester, 6);
    await tester.pumpAndSettle();
    expect(chip(tester, 6).selected, isFalse);
    // Back to the top, where the form shows its error.
    await tester.drag(page.first, const Offset(0, 1000));
    await tester.pumpAndSettle();
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
    await tester.tap(find.byType(Switch).first);
    await tester.pumpAndSettle();
    expect(push.asked, 0);
    expect(notifications.saved.single.enabled, isTrue);
  });

  testWidgets('the month-end review alone: asks, saves, time and days apply', (
    tester,
  ) async {
    final push = FakePush();
    final notifications = FakeNotificationsRepository();
    await open(tester, push: push, notifications: notifications);

    await tester.tap(find.text('Month-end review'));
    await tester.pumpAndSettle();
    expect(push.asked, 1);
    expect(
      notifications.saved.single,
      const NotificationSettings(ritual: true, timeZone: 'Europe/Paris'),
    );
    expect(switchedOn(tester), isFalse, reason: 'the summary stays off');
    expect(chip(tester, 1).onSelected, isNotNull);
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

  testWidgets('the Settings row shows the time with only the review on', (
    tester,
  ) async {
    final container = await pumpLoomia(
      tester,
      size: phone,
      notifications: FakeNotificationsRepository(
        const NotificationSettings(ritual: true, timeZone: 'Europe/Paris'),
      ),
    );
    container.read(routerProvider).go(Routes.settings);
    await tester.pumpAndSettle();
    expect(find.text('7:00 PM'), findsOneWidget);
    expect(find.text('Off'), findsNothing);
  });

  group('the Tasks switch (#389)', () {
    const tasksOnly = NotificationSettings(timeZone: 'Europe/Paris');

    SwitchListTile tasksTile(WidgetTester tester) => tester
        .widget<SwitchListTile>(find.widgetWithText(SwitchListTile, 'Tasks'));

    testWidgets('on by default; off saves, asks nothing', (tester) async {
      final push = FakePush(isAllowed: true);
      final notifications = FakeNotificationsRepository();
      await open(tester, push: push, notifications: notifications);
      expect(tasksTile(tester).value, isTrue);
      expect(
        find.text('At the time set on a task, when its bell is on.'),
        findsOneWidget,
      );

      await tester.tap(find.text('Tasks'));
      await tester.pumpAndSettle();
      expect(notifications.saved.single.tasks, isFalse);
      expect(push.asked, 0);
      expect(tasksTile(tester).value, isFalse);
    });

    testWidgets('turning it on asks the phone', (tester) async {
      final push = FakePush(isAllowed: true);
      final notifications = FakeNotificationsRepository(
        tasksOnly.copyWith(tasks: false),
      );
      await open(tester, push: push, notifications: notifications);
      push
        ..isAllowed = false
        ..asked = 0;

      await tester.tap(find.text('Tasks'));
      await tester.pumpAndSettle();
      expect(push.asked, 1);
      expect(notifications.saved.single.tasks, isTrue);
    });

    testWidgets('only Tasks on: the time and days stay off', (tester) async {
      await open(tester, notifications: FakeNotificationsRepository(tasksOnly));
      expect(
        tester.widget<ListTile>(find.widgetWithText(ListTile, 'Time')).enabled,
        isFalse,
      );
      expect(chip(tester, 1).onSelected, isNull);
    });

    testWidgets('only Tasks on, refused by the phone: the warning', (
      tester,
    ) async {
      await open(
        tester,
        push: FakePush(grant: false),
        notifications: FakeNotificationsRepository(tasksOnly),
      );
      expect(
        find.text("Notifications are off for Loomia in your phone's settings."),
        findsOneWidget,
      );
    });

    testWidgets('the Settings row says Tasks when only tasks push', (
      tester,
    ) async {
      final container = await pumpLoomia(
        tester,
        size: phone,
        notifications: FakeNotificationsRepository(tasksOnly),
      );
      container.read(routerProvider).go(Routes.settings);
      await tester.pumpAndSettle();
      expect(find.text('Tasks'), findsOneWidget);
      expect(find.text('Off'), findsNothing);
    });

    testWidgets('the Settings row says Sharing when only sharing pushes', (
      tester,
    ) async {
      final container = await pumpLoomia(
        tester,
        size: phone,
        notifications: FakeNotificationsRepository(
          tasksOnly.copyWith(tasks: false, sharing: true),
        ),
      );
      container.read(routerProvider).go(Routes.settings);
      await tester.pumpAndSettle();
      expect(
        find.descendant(
          of: find.widgetWithText(ListTile, 'Notifications'),
          matching: find.text('Sharing'),
        ),
        findsOneWidget,
      );
      expect(find.text('Off'), findsNothing);
    });
  });
}

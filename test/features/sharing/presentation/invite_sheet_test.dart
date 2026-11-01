import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loomia/features/auth/data/auth_repository.dart';
import 'package:loomia/features/auth/domain/account.dart';
import 'package:loomia/features/contacts/domain/people_failure.dart';
import 'package:loomia/features/notifications/data/notifications_repository.dart';
import 'package:loomia/features/notifications/data/push.dart';
import 'package:loomia/features/notifications/domain/notification_settings.dart';
import 'package:loomia/features/notifications/presentation/notifications_controller.dart';
import 'package:loomia/features/sharing/data/sharing_repository.dart';
import 'package:loomia/features/sharing/domain/invite_code.dart';
import 'package:loomia/features/sharing/domain/share_item.dart';
import 'package:loomia/features/sharing/domain/shared_goals.dart';
import 'package:loomia/features/sharing/presentation/contact_sharing_controller.dart';
import 'package:loomia/features/sharing/presentation/invite_sheet.dart';
import 'package:loomia/l10n/app_localizations.dart';
import 'package:material_ui/material_ui.dart';

import '../../notifications/fake_notifications_repository.dart';
import '../../notifications/fake_push.dart';

import '../fake_sharing_repository.dart';

// As the fake records it: the provider asks for the current month.
final thisMonth = '${DateTime.now().year}-${DateTime.now().month}';

void main() {
  late FakeSharingRepository repo;
  late FakePush push;
  late FakeNotificationsRepository notifications;
  late ProviderContainer container;

  setUp(() {
    repo = FakeSharingRepository();
    // The web by default: no push, so no "Tell me" line.
    push = FakePush(isAvailable: false);
    notifications = FakeNotificationsRepository();
    container = ProviderContainer(
      overrides: [
        sharingRepositoryProvider.overrideWithValue(repo),
        pushProvider.overrideWithValue(push),
        notificationsRepositoryProvider.overrideWithValue(notifications),
        accountProvider.overrideWithValue(
          const Account(firstName: 'Marie', email: 'marie@example.com'),
        ),
        deviceTimeZoneProvider.overrideWith((ref) => 'Europe/Paris'),
      ],
    );
  });

  tearDown(() {
    container.dispose();
  });

  Widget wrapped(Widget child) => UncontrolledProviderScope(
    container: container,
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: child),
    ),
  );

  group('showInviteSheet', () {
    testWidgets('creates invite when none exists and shows code', (
      tester,
    ) async {
      repo.openInviteValue = null;
      repo.createInviteValue = Invite(
        code: 'ABCDEFGH',
        expiresAt: DateTime.parse('2026-11-14T00:00:00Z'),
      );

      await tester.pumpWidget(
        wrapped(
          Builder(
            builder: (context) => TextButton(
              onPressed: () =>
                  showInviteSheet(context, personId: 'p1', name: 'Julie'),
              child: const Text('Open'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      expect(repo.calls, ['openInvite(p1)', 'createInvite(p1)']);
      expect(find.text('ABCD-EFGH'), findsOneWidget);
      expect(find.text('app.getloomia.app/#/invite/ABCDEFGH'), findsOneWidget);
    });

    testWidgets('does not create invite when one already exists', (
      tester,
    ) async {
      repo.openInviteValue = Invite(
        code: 'ZYXWVUTS',
        expiresAt: DateTime.parse('2026-11-14T00:00:00Z'),
      );

      await tester.pumpWidget(
        wrapped(
          Builder(
            builder: (context) => TextButton(
              onPressed: () =>
                  showInviteSheet(context, personId: 'p2', name: 'Marc'),
              child: const Text('Open'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      expect(repo.calls, ['openInvite(p2)']);
      expect(find.text('ZYXW-VUTS'), findsOneWidget);
    });

    testWidgets('Copy link puts URL on clipboard and shows snackbar', (
      tester,
    ) async {
      repo.openInviteValue = Invite(
        code: 'ABCDEFGH',
        expiresAt: DateTime.parse('2026-11-14T00:00:00Z'),
      );

      String? clipboardData;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData') {
            clipboardData = call.arguments['text'] as String?;
          }
          return null;
        },
      );

      await tester.pumpWidget(
        wrapped(
          Builder(
            builder: (context) => TextButton(
              onPressed: () =>
                  showInviteSheet(context, personId: 'p3', name: 'Sam'),
              child: const Text('Open'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Copy link'));
      await tester.pump();

      expect(clipboardData, 'https://app.getloomia.app/#/invite/ABCDEFGH');
      expect(find.text('Link copied'), findsOneWidget);
    });

    testWidgets('Cancel invite calls cancelInvite and closes', (tester) async {
      repo.openInviteValue = Invite(
        code: 'TESTCODE',
        expiresAt: DateTime.parse('2026-11-14T00:00:00Z'),
      );

      await tester.pumpWidget(
        wrapped(
          Builder(
            builder: (context) => TextButton(
              onPressed: () =>
                  showInviteSheet(context, personId: 'p4', name: 'Alex'),
              child: const Text('Open'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Cancel invite'));
      await tester.pumpAndSettle();

      expect(repo.calls, ['openInvite(p4)', 'cancelInvite(p4)']);
      expect(find.text('TEST-CODE'), findsNothing); // Sheet closed
    });

    testWidgets('createInvite failure shows error and Try again', (
      tester,
    ) async {
      repo.openInviteValue = null;
      repo.failWith = PeopleFailure.network;

      await tester.pumpWidget(
        wrapped(
          Builder(
            builder: (context) => TextButton(
              onPressed: () =>
                  showInviteSheet(context, personId: 'p5', name: 'Taylor'),
              child: const Text('Open'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      expect(
        find.text("Couldn't save. Check your connection and try again."),
        findsOneWidget,
      );
      expect(find.text('Try again'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);
      expect(repo.calls, ['openInvite(p5)']);

      // Try again - this time succeed
      repo.failWith = null;
      repo.createInviteValue = Invite(
        code: 'RETRYOK',
        expiresAt: DateTime.parse('2026-11-14T00:00:00Z'),
      );

      await tester.tap(find.text('Try again'));
      // Give time for the async operations to complete
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pumpAndSettle();

      // Check that error is gone and code is shown
      expect(
        find.text("Couldn't save. Check your connection and try again."),
        findsNothing,
      );
      expect(find.textContaining('RETRY'), findsOneWidget);
      expect(find.text('Copy link'), findsOneWidget);
      expect(repo.calls, [
        'openInvite(p5)',
        'openInvite(p5)',
        'createInvite(p5)',
      ]);
    });

    testWidgets('cancelInvite failure shows error and re-enables Cancel', (
      tester,
    ) async {
      repo.openInviteValue = Invite(
        code: 'WILLCANCEL',
        expiresAt: DateTime.parse('2026-11-14T00:00:00Z'),
      );

      await tester.pumpWidget(
        wrapped(
          Builder(
            builder: (context) => TextButton(
              onPressed: () =>
                  showInviteSheet(context, personId: 'p6', name: 'Morgan'),
              child: const Text('Open'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      repo.failWith = PeopleFailure.unknown;

      await tester.tap(find.text('Cancel invite'));
      await tester.pumpAndSettle();

      expect(find.text('Something went wrong. Try again.'), findsOneWidget);
      expect(find.text('WILL-CANCEL'), findsOneWidget); // Still showing
      expect(find.text('Cancel invite'), findsOneWidget); // Re-enabled

      // Retry cancel succeeds
      repo.failWith = null;

      await tester.tap(find.text('Cancel invite'));
      await tester.pumpAndSettle();

      expect(repo.calls, [
        'openInvite(p6)',
        'cancelInvite(p6)',
        'cancelInvite(p6)',
      ]);
      expect(find.text('WILL-CANCEL'), findsNothing); // Sheet closed
    });
  });

  group('contactSharingProvider', () {
    test('returns shared goals when they exist', () async {
      repo.sharedGoalsValue = const SharedGoals(
        memberFirstName: 'Julie',
        items: <ShareItem>{},
      );

      final result = await container.read(contactSharingProvider('p1').future);

      expect(result.shared, isNotNull);
      expect(result.shared?.memberFirstName, 'Julie');
      expect(result.invite, isNull);
      expect(repo.calls, contains('sharedGoals(p1, $thisMonth)'));
    });

    test('returns open invite when no shared goals', () async {
      repo.sharedGoalsValue = null;
      repo.openInviteValue = Invite(
        code: 'INVITEME',
        expiresAt: DateTime.parse('2026-11-14T00:00:00Z'),
      );

      final result = await container.read(contactSharingProvider('p2').future);

      expect(result.shared, isNull);
      expect(result.invite, isNotNull);
      expect(result.invite?.code, 'INVITEME');
      expect(repo.calls, ['sharedGoals(p2, $thisMonth)', 'openInvite(p2)']);
    });

    test('returns null invite when no shared goals and no invite', () async {
      repo.sharedGoalsValue = null;
      repo.openInviteValue = null;

      final result = await container.read(contactSharingProvider('p3').future);

      expect(result.shared, isNull);
      expect(result.invite, isNull);
    });
  });

  group('tell me when they accept (#423)', () {
    Future<void> openSheet(WidgetTester tester) async {
      repo.openInviteValue = Invite(
        code: 'ABCDEFGH',
        expiresAt: DateTime.parse('2026-11-14T00:00:00Z'),
      );
      await tester.pumpWidget(
        wrapped(
          Builder(
            builder: (context) => TextButton(
              onPressed: () =>
                  showInviteSheet(context, personId: 'p1', name: 'Julie'),
              child: const Text('Open'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
    }

    const tellMe = 'Tell me when Julie accepts';
    const refused =
        "Notifications are off for Loomia in your phone's settings.";

    testWidgets('offered on a phone while the Sharing push is off', (
      tester,
    ) async {
      push.isAvailable = true;
      await openSheet(tester);
      expect(find.text(tellMe), findsOneWidget);
    });

    testWidgets('not offered without push (web)', (tester) async {
      await openSheet(tester);
      expect(find.text(tellMe), findsNothing);
    });

    testWidgets('not offered once the Sharing push is on', (tester) async {
      push.isAvailable = true;
      notifications.settings = const NotificationSettings(
        timeZone: 'Europe/Paris',
        sharing: true,
      );
      await openSheet(tester);
      expect(find.text(tellMe), findsNothing);
    });

    testWidgets('on, with the bell, until they say otherwise (#439)', (
      tester,
    ) async {
      push.isAvailable = true;
      await openSheet(tester);
      expect(
        tester.widget<SwitchListTile>(find.byType(SwitchListTile)).value,
        isTrue,
      );
      expect(find.byIcon(Icons.notifications_active_rounded), findsOneWidget);
      expect(push.asked, 0, reason: 'nothing asked before Copy link');
      expect(notifications.saved, isEmpty);
    });

    testWidgets('Copy link asks the phone, saves, and the line goes away', (
      tester,
    ) async {
      push.isAvailable = true;
      await openSheet(tester);
      await tester.tap(find.text('Copy link'));
      await tester.pumpAndSettle();
      expect(push.asked, 1);
      expect(notifications.saved.single.sharing, isTrue);
      expect(notifications.saved.single.timeZone, 'Europe/Paris');
      expect(find.text(tellMe), findsNothing);
    });

    testWidgets('switched off first: Copy link asks nothing', (tester) async {
      push.isAvailable = true;
      await openSheet(tester);
      await tester.tap(find.text(tellMe));
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.notifications_off_outlined), findsOneWidget);
      await tester.tap(find.text('Copy link'));
      await tester.pumpAndSettle();
      expect(push.asked, 0);
      expect(notifications.saved, isEmpty);
    });

    testWidgets(
      'refused by the phone: off, nothing saved, and where to fix it',
      (tester) async {
        push
          ..isAvailable = true
          ..grant = false;
        await openSheet(tester);
        await tester.tap(find.text('Copy link'));
        await tester.pumpAndSettle();
        expect(notifications.saved, isEmpty);
        expect(find.text(refused), findsOneWidget);
        expect(
          tester.widget<SwitchListTile>(find.byType(SwitchListTile)).value,
          isFalse,
        );
      },
    );
  });
}

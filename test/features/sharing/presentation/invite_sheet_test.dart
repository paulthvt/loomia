import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loomia/features/contacts/domain/people_failure.dart';
import 'package:loomia/features/sharing/data/sharing_repository.dart';
import 'package:loomia/features/sharing/domain/invite_code.dart';
import 'package:loomia/features/sharing/domain/share_item.dart';
import 'package:loomia/features/sharing/domain/shared_goals.dart';
import 'package:loomia/features/sharing/presentation/contact_sharing_controller.dart';
import 'package:loomia/features/sharing/presentation/invite_sheet.dart';
import 'package:loomia/l10n/app_localizations.dart';
import 'package:material_ui/material_ui.dart';

import '../fake_sharing_repository.dart';

void main() {
  late FakeSharingRepository repo;
  late ProviderContainer container;

  setUp(() {
    repo = FakeSharingRepository();
    container = ProviderContainer(
      overrides: [sharingRepositoryProvider.overrideWithValue(repo)],
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
      expect(find.text('app.getloomia.app/invite/ABCDEFGH'), findsOneWidget);
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

      expect(clipboardData, 'https://app.getloomia.app/invite/ABCDEFGH');
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
      expect(repo.calls, contains('sharedGoals(p1, 2026-10)'));
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
      expect(repo.calls, ['sharedGoals(p2, 2026-10)', 'openInvite(p2)']);
    });

    test('returns null invite when no shared goals and no invite', () async {
      repo.sharedGoalsValue = null;
      repo.openInviteValue = null;

      final result = await container.read(contactSharingProvider('p3').future);

      expect(result.shared, isNull);
      expect(result.invite, isNull);
    });
  });
}

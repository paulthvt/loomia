import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
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

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loomia/app/theme/app_theme.dart';
import 'package:loomia/features/sharing/data/sharing_repository.dart';
import 'package:loomia/features/sharing/domain/invite_failure.dart';
import 'package:loomia/features/sharing/presentation/accept_invite.dart';
import 'package:loomia/l10n/app_localizations.dart';
import 'package:loomia/l10n/localizations_delegates.dart';
import 'package:material_ui/material_ui.dart';

import '../fake_sharing_repository.dart';

Future<void> pumpAcceptInvite(
  WidgetTester tester,
  FakeSharingRepository repository, {
  String? initialCode,
  required VoidCallback onAccepted,
}) {
  return tester.pumpWidget(
    ProviderScope(
      overrides: [sharingRepositoryProvider.overrideWithValue(repository)],
      child: MaterialApp(
        theme: AppTheme.light,
        localizationsDelegates: localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: AcceptInvite(initialCode: initialCode, onAccepted: onAccepted),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('entering code and Continue calls previewInvite', (tester) async {
    final repo = FakeSharingRepository()..previewInviteValue = 'Marie';

    await pumpAcceptInvite(tester, repo, onAccepted: () {});

    final codeField = find.byType(TextField);
    expect(codeField, findsOneWidget);

    await tester.enterText(codeField, 'abcd-efgh');
    await tester.pump();
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    expect(repo.calls, contains('previewInvite(ABCDEFGH)'));
    expect(find.text('Share your goals with Marie?'), findsOneWidget);
  });

  testWidgets('a mentor without a first name: the question goes without', (
    tester,
  ) async {
    final repo = FakeSharingRepository();

    await pumpAcceptInvite(
      tester,
      repo,
      initialCode: 'ABCDEFGH',
      onAccepted: () {},
    );
    await tester.pumpAndSettle();

    expect(find.text('Share your goals?'), findsOneWidget);
  });

  testWidgets('switches default: activity on, progress off, about-me off', (
    tester,
  ) async {
    final repo = FakeSharingRepository()..previewInviteValue = 'Marie';

    await pumpAcceptInvite(tester, repo, onAccepted: () {});
    await tester.enterText(find.byType(TextField), 'ABCDEFGH');
    await tester.pump();
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    final activitySwitch = find.byWidgetPredicate(
      (w) =>
          w is SwitchListTile &&
          w.title is Text &&
          (w.title as Text).data!.contains('targets'),
    );
    final progressSwitch = find.byWidgetPredicate(
      (w) =>
          w is SwitchListTile &&
          w.title is Text &&
          (w.title as Text).data!.contains('month is going'),
    );
    final aboutMeSwitch = find.byWidgetPredicate(
      (w) =>
          w is SwitchListTile &&
          w.title is Text &&
          (w.title as Text).data!.contains('why and your own goal'),
    );

    expect(activitySwitch, findsOneWidget);
    expect(progressSwitch, findsOneWidget);
    expect(aboutMeSwitch, findsOneWidget);

    expect(tester.widget<SwitchListTile>(activitySwitch).value, isTrue);
    expect(tester.widget<SwitchListTile>(progressSwitch).value, isFalse);
    expect(tester.widget<SwitchListTile>(aboutMeSwitch).value, isFalse);
  });

  testWidgets('Accept calls acceptInvite with selected items and onAccepted', (
    tester,
  ) async {
    final repo = FakeSharingRepository()..previewInviteValue = 'Marie';
    var accepted = false;

    await pumpAcceptInvite(tester, repo, onAccepted: () => accepted = true);
    await tester.enterText(find.byType(TextField), 'ABCDEFGH');
    await tester.pump();
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Share'));
    await tester.pump();

    expect(repo.calls.last, 'acceptInvite(ABCDEFGH, 1 items)');
    expect(accepted, isTrue);
  });

  testWidgets('InviteFailure.alreadySharing shows error', (tester) async {
    final repo = FakeSharingRepository()..previewInviteValue = 'Marie';

    await pumpAcceptInvite(tester, repo, onAccepted: () {});
    await tester.enterText(find.byType(TextField), 'ABCDEFGH');
    await tester.pump();

    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    repo.failWith = InviteFailure.alreadySharing;
    await tester.tap(find.text('Share'));
    await tester.pump();

    expect(
      find.text(
        'You already share your goals. Stop that first in Settings → Sharing.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('any other error stops the spinner and says so', (tester) async {
    final repo = FakeSharingRepository()..failWith = Exception('offline');

    await pumpAcceptInvite(tester, repo, onAccepted: () {});
    await tester.enterText(find.byType(TextField), 'ABCDEFGH');
    await tester.pump();
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    expect(find.text('Something went wrong. Try again.'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNotNull,
    );
  });

  testWidgets('any other error on Share stops the spinner and says so', (
    tester,
  ) async {
    final repo = FakeSharingRepository()..previewInviteValue = 'Marie';

    await pumpAcceptInvite(tester, repo, onAccepted: () {});
    await tester.enterText(find.byType(TextField), 'ABCDEFGH');
    await tester.pump();
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    repo.failWith = Exception('offline');
    await tester.tap(find.text('Share'));
    await tester.pumpAndSettle();

    expect(find.text('Something went wrong. Try again.'), findsOneWidget);
    expect(find.text('Share'), findsOneWidget);
  });

  testWidgets('Continue disabled when normaliseCode is null', (tester) async {
    final repo = FakeSharingRepository();

    await pumpAcceptInvite(tester, repo, onAccepted: () {});

    final continueButton = find.widgetWithText(FilledButton, 'Continue');
    expect(tester.widget<FilledButton>(continueButton).onPressed, isNull);

    await tester.enterText(find.byType(TextField), 'abc');
    await tester.pump();
    expect(tester.widget<FilledButton>(continueButton).onPressed, isNull);

    await tester.enterText(find.byType(TextField), 'abcd-efgh');
    await tester.pump();
    expect(tester.widget<FilledButton>(continueButton).onPressed, isNotNull);
  });
}

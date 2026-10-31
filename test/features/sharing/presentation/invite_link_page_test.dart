import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loomia/app/theme/app_theme.dart';
import 'package:loomia/features/auth/data/auth_repository.dart';
import 'package:loomia/features/sharing/data/sharing_repository.dart';
import 'package:loomia/features/sharing/presentation/invite_link_page.dart';
import 'package:loomia/l10n/app_localizations.dart';
import 'package:material_ui/material_ui.dart';

import '../../auth/fake_auth_repository.dart';
import '../fake_sharing_repository.dart';

Future<FakeSharingRepository> _pump(
  WidgetTester tester,
  String code, {
  bool signedIn = false,
}) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  final auth = FakeAuthRepository()..session = signedIn;
  addTearDown(auth.dispose);
  final sharing = FakeSharingRepository()..previewInviteValue = 'Marie';

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authRepositoryProvider.overrideWithValue(auth),
        sharingRepositoryProvider.overrideWithValue(sharing),
      ],
      child: MaterialApp(
        theme: AppTheme.light,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: InviteLinkPage(code: code),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return sharing;
}

void main() {
  testWidgets('signed out shows formatted code', (tester) async {
    await _pump(tester, 'ABCDEFGH');

    expect(find.text('ABCD-EFGH'), findsOneWidget);
    expect(
      find.text('Sign in or create your account, then enter this code.'),
      findsOneWidget,
    );
  });

  testWidgets('signed out, a typed-looking code reads normalised', (
    tester,
  ) async {
    await _pump(tester, 'abcd-efgh');

    expect(find.text('ABCD-EFGH'), findsOneWidget);
  });

  testWidgets('signed out, a code that cannot work says so', (tester) async {
    await _pump(tester, 'AB');

    expect(tester.takeException(), isNull);
    expect(find.text("This code doesn't work. Ask for a new one."), findsOne);
    expect(find.text('AB'), findsNothing);
  });

  testWidgets('signed in, the normalised code is previewed', (tester) async {
    final sharing = await _pump(tester, 'abcd-efgh', signedIn: true);

    expect(sharing.calls, contains('previewInvite(ABCDEFGH)'));
  });
}

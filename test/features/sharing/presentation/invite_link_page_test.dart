import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loomia/features/auth/data/auth_repository.dart';
import 'package:loomia/features/sharing/data/sharing_repository.dart';
import 'package:loomia/features/sharing/presentation/invite_link_page.dart';
import 'package:loomia/l10n/app_localizations.dart';
import 'package:material_ui/material_ui.dart';

import '../../auth/fake_auth_repository.dart';
import '../fake_sharing_repository.dart';

void main() {
  testWidgets('signed out shows formatted code', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final auth = FakeAuthRepository();
    addTearDown(auth.dispose);
    final sharing = FakeSharingRepository();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authRepositoryProvider.overrideWithValue(auth),
          sharingRepositoryProvider.overrideWithValue(sharing),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const InviteLinkPage(code: 'ABCDEFGH'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('ABCD-EFGH'), findsOneWidget);
    expect(
      find.text('Sign in or create your account, then enter this code.'),
      findsOneWidget,
    );
  });
}

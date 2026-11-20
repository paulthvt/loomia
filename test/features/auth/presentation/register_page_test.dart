import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:loomia/app/router/routes.dart';
import 'package:loomia/app/theme/app_theme.dart';
import 'package:loomia/features/auth/data/auth_repository.dart';
import 'package:loomia/features/auth/domain/auth_failure.dart';
import 'package:loomia/features/auth/domain/auth_validation.dart';
import 'package:loomia/features/auth/presentation/register_page.dart';
import 'package:loomia/l10n/app_localizations.dart';
import 'package:loomia/l10n/localizations_delegates.dart';
import 'package:material_ui/material_ui.dart';

import '../fake_auth_repository.dart';

/// A two-route router, so `context.go` works and the test can assert where
/// signup navigated to.
GoRouter _router() => GoRouter(
  routes: [
    GoRoute(path: '/', builder: (context, state) => const RegisterPage()),
    GoRoute(
      path: Routes.checkInbox,
      builder: (context, state) => const SizedBox.shrink(),
    ),
  ],
);

Widget _host(GoRouter router, FakeAuthRepository fake) => ProviderScope(
  overrides: [authRepositoryProvider.overrideWithValue(fake)],
  child: MaterialApp.router(
    locale: const Locale('en'),
    localizationsDelegates: localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    theme: AppTheme.light,
    routerConfig: router,
  ),
);

String _location(GoRouter router) =>
    router.routerDelegate.currentConfiguration.uri.toString();

Future<void> _fill(
  WidgetTester tester, {
  String firstName = 'Pauline',
  String email = 'pauline@example.com',
  String password = 'hunter22',
}) async {
  final fields = find.byType(TextFormField);
  await tester.enterText(fields.at(0), firstName);
  await tester.enterText(fields.at(1), email);
  await tester.enterText(fields.at(2), password);
}

void main() {
  testWidgets('collects first name, email and password', (tester) async {
    await tester.pumpWidget(_host(_router(), FakeAuthRepository()));

    expect(find.text('Create your account'), findsOneWidget);
    expect(find.text('First name'), findsOneWidget);
    expect(find.text('At least $minPasswordLength characters'), findsOneWidget);
    expect(find.text('Create account'), findsOneWidget);
  });

  testWidgets('links the privacy policy, and no terms yet', (tester) async {
    await tester.pumpWidget(_host(_router(), FakeAuthRepository()));

    expect(
      find.textContaining(
        'By creating an account, you accept the',
        findRichText: true,
      ),
      findsOneWidget,
    );
    expect(find.widgetWithText(TextButton, 'privacy policy'), findsOneWidget);
    expect(find.textContaining('terms', findRichText: true), findsNothing);
  });

  testWidgets('a blank first name blocks the request', (tester) async {
    final fake = FakeAuthRepository();
    await tester.pumpWidget(_host(_router(), fake));

    await _fill(tester, firstName: '   ');
    await tester.tap(find.text('Create account'));
    await tester.pumpAndSettle();

    expect(find.text('Enter your first name.'), findsOneWidget);
    expect(fake.calls, isEmpty);
  });

  testWidgets('a short password blocks the request', (tester) async {
    final fake = FakeAuthRepository();
    await tester.pumpWidget(_host(_router(), fake));

    await _fill(tester, password: 'hunter2');
    await tester.tap(find.text('Create account'));
    await tester.pumpAndSettle();

    expect(
      find.text('At least $minPasswordLength characters.'),
      findsOneWidget,
    );
    expect(fake.calls, isEmpty);
  });

  testWidgets('signs up with a normalized email and goes to check-inbox', (
    tester,
  ) async {
    final fake = FakeAuthRepository();
    final router = _router();
    await tester.pumpWidget(_host(router, fake));

    await _fill(tester, email: ' Pauline@Example.com ');
    await tester.tap(find.text('Create account'));
    await tester.pumpAndSettle();

    expect(fake.calls, ['signUp(pauline@example.com, hunter22, Pauline, en)']);
    expect(
      _location(router),
      Routes.checkInboxLocation(
        reason: 'confirm',
        email: 'pauline@example.com',
      ),
    );
  });

  testWidgets('a failure keeps the user on the form', (tester) async {
    final fake = FakeAuthRepository()..failWith = AuthFailure.unknown;
    final router = _router();
    await tester.pumpWidget(_host(router, fake));

    await _fill(tester);
    await tester.tap(find.text('Create account'));
    await tester.pumpAndSettle();

    expect(find.text('Something went wrong. Try again.'), findsOneWidget);
    expect(_location(router), '/');
  });
}

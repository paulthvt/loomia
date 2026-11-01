import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loomia/app/theme/app_theme.dart';
import 'package:loomia/features/auth/data/auth_repository.dart';
import 'package:loomia/features/auth/domain/auth_failure.dart';
import 'package:loomia/features/auth/presentation/welcome_page.dart';
import 'package:loomia/l10n/app_localizations.dart';
import 'package:loomia/l10n/localizations_delegates.dart';
import 'package:material_ui/material_ui.dart';

import '../fake_auth_repository.dart';

Widget _host(
  FakeAuthRepository fake, {
  double textScale = 1,
  bool dark = false,
}) => ProviderScope(
  overrides: [authRepositoryProvider.overrideWithValue(fake)],
  child: MaterialApp(
    locale: const Locale('en'),
    localizationsDelegates: localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    theme: AppTheme.light,
    darkTheme: AppTheme.dark,
    themeMode: dark ? ThemeMode.dark : ThemeMode.light,
    builder: (context, child) => MediaQuery.withClampedTextScaling(
      minScaleFactor: textScale,
      maxScaleFactor: textScale,
      child: child!,
    ),
    home: const WelcomePage(),
  ),
);

Finder _button(String label) => find.ancestor(
  of: find.text(label),
  // OutlinedButton.icon builds a private subclass, so not byType.
  matching: find.byWidgetPredicate((widget) => widget is OutlinedButton),
);

void main() {
  testWidgets('shows the Loomia name and slogan', (tester) async {
    await tester.pumpWidget(_host(FakeAuthRepository()));

    expect(find.bySemanticsLabel('Loomia'), findsOneWidget);
    expect(find.text('Weave your network. Tend every thread.'), findsOneWidget);
  });

  testWidgets('offers the identity paths and the register link', (
    tester,
  ) async {
    await tester.pumpWidget(_host(FakeAuthRepository()));

    expect(find.text('Continue with Google'), findsOneWidget);
    // Google requires its own mark beside the label.
    expect(
      find.image(const AssetImage('assets/images/google_g.png')),
      findsOneWidget,
    );
    // Apple's own mark too, from its design resources.
    expect(
      find.image(const AssetImage('assets/images/apple_logo.png')),
      findsOneWidget,
    );
    expect(find.text('Continue with email'), findsOneWidget);
    // Google, Apple, email, top to bottom: same size, Apple not hidden (4.8).
    final googleY = tester.getCenter(find.text('Continue with Google')).dy;
    final appleY = tester.getCenter(find.text('Continue with Apple')).dy;
    final emailY = tester.getCenter(find.text('Continue with email')).dy;
    expect(googleY < appleY && appleY < emailY, isTrue);
    expect(
      tester.getSize(_button('Continue with Apple')),
      tester.getSize(_button('Continue with Google')),
    );
    expect(find.text('Create an account'), findsOneWidget);
    expect(find.text('Weave your network. Tend every thread.'), findsOneWidget);
  });

  testWidgets('Apple calls the repository once', (tester) async {
    final fake = FakeAuthRepository();
    await tester.pumpWidget(_host(fake));

    await tester.tap(find.text('Continue with Apple'));
    await tester.pumpAndSettle();

    expect(fake.calls, ['signInWithApple()']);
  });

  testWidgets('a failed Apple sign-in shows a form error', (tester) async {
    final fake = FakeAuthRepository()..failWith = AuthFailure.network;
    await tester.pumpWidget(_host(fake));

    await tester.tap(find.text('Continue with Apple'));
    await tester.pumpAndSettle();

    expect(
      find.text('We could not reach Loomia. Check your connection.'),
      findsOneWidget,
    );
  });

  testWidgets('Apple is white with a black outline in light, white in dark', (
    tester,
  ) async {
    for (final dark in [false, true]) {
      await tester.pumpWidget(_host(FakeAuthRepository(), dark: dark));
      // MaterialApp animates a theme change.
      await tester.pumpAndSettle();
      final style = tester
          .widget<ButtonStyleButton>(_button('Continue with Apple'))
          .style!;
      const none = <WidgetState>{};
      expect(style.backgroundColor!.resolve(none), const Color(0xFFFFFFFF));
      expect(style.foregroundColor!.resolve(none), const Color(0xFF000000));
      final side = style.side!.resolve(none)!;
      expect(side.style, dark ? BorderStyle.none : BorderStyle.solid);
      if (!dark) expect(side.color, const Color(0xFF000000));
    }
  });

  testWidgets('the Apple logo sits inside its button, like the Google mark', (
    tester,
  ) async {
    addTearDown(tester.view.reset);
    // Phone, tablet, desktop; then large text on a phone.
    for (final (width, scale) in [
      (360.0, 1.0),
      (800.0, 1.0),
      (1440.0, 1.0),
      (360.0, 2.0),
    ]) {
      tester.view
        ..physicalSize = Size(width, 900)
        ..devicePixelRatio = 1;
      await tester.pumpWidget(_host(FakeAuthRepository(), textScale: scale));
      await tester.pumpAndSettle();

      final button = tester.getRect(_button('Continue with Apple'));
      final logo = tester.getRect(
        find.image(const AssetImage('assets/images/apple_logo.png')),
      );
      final google = tester.getRect(
        find.image(const AssetImage('assets/images/google_g.png')),
      );
      final at = 'width $width, text ×$scale';
      // Clear of the outline by at least 8 on top and bottom.
      expect(logo.top - button.top, greaterThanOrEqualTo(8), reason: at);
      expect(button.bottom - logo.bottom, greaterThanOrEqualTo(8), reason: at);
      expect(logo.height, lessThanOrEqualTo(google.height + 4), reason: at);
      expect(logo.center.dy, moreOrLessEquals(button.center.dy, epsilon: 1));
    }
  });

  testWidgets('Google calls the repository once', (tester) async {
    final fake = FakeAuthRepository();
    await tester.pumpWidget(_host(fake));

    await tester.tap(find.text('Continue with Google'));
    await tester.pumpAndSettle();

    expect(fake.calls, ['signInWithGoogle()']);
  });

  testWidgets('a failed OAuth attempt shows a form error', (tester) async {
    final fake = FakeAuthRepository()..failWith = AuthFailure.network;
    await tester.pumpWidget(_host(fake));

    await tester.tap(find.text('Continue with Google'));
    await tester.pumpAndSettle();

    expect(
      find.text('We could not reach Loomia. Check your connection.'),
      findsOneWidget,
    );
  });

  testWidgets('the footer fits the column at large text sizes', (tester) async {
    await tester.pumpWidget(_host(FakeAuthRepository(), textScale: 2));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });

  testWidgets('two taps in the same frame start one OAuth flow', (
    tester,
  ) async {
    final fake = FakeAuthRepository()..gate = Completer<void>();
    await tester.pumpWidget(_host(fake));

    await tester.tap(find.text('Continue with Google'));
    await tester.tap(find.text('Continue with Google'));
    await tester.pump();

    fake.gate!.complete();
    await tester.pumpAndSettle();

    expect(fake.calls, ['signInWithGoogle()']);
  });
}

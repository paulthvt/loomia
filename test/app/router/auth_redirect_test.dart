import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loomia/app/router/auth_redirect.dart';
import 'package:loomia/app/router/routes.dart';
import 'package:loomia/features/auth/data/auth_repository.dart';
import 'package:loomia/features/auth/domain/auth_change.dart';

import '../../features/auth/fake_auth_repository.dart';

void main() {
  group('signed out', () {
    String? redirect(String location) => authRedirect(
      hasSession: false,
      recoveringPassword: false,
      location: location,
    );

    test('is sent to welcome from a protected route', () {
      expect(redirect(Routes.today), Routes.welcome);
    });

    test('is left alone on every auth route', () {
      for (final path in Routes.authPaths) {
        expect(redirect(path), isNull, reason: path);
      }
    });

    test(
      'cannot reach reset-password without the link having signed them in',
      () {
        expect(redirect(Routes.resetPassword), Routes.welcome);
      },
    );

    test('is left alone on an invite link', () {
      expect(redirect('/invite/ABCDEFGH'), isNull);
    });
  });

  group('signed in', () {
    String? redirect(String location) => authRedirect(
      hasSession: true,
      recoveringPassword: false,
      location: location,
    );

    test('is left alone on a protected route', () {
      expect(redirect(Routes.today), isNull);
    });

    test('is sent to Today from an auth route', () {
      for (final path in Routes.authPaths) {
        expect(redirect(path), Routes.today, reason: path);
      }
    });

    test('is never pushed off reset-password', () {
      expect(redirect(Routes.resetPassword), isNull);
    });
  });

  group('signed in, not onboarded yet', () {
    String? redirect(String location) => authRedirect(
      hasSession: true,
      recoveringPassword: false,
      location: location,
      onboarded: false,
    );

    test('is sent to the first-run screen from anywhere else', () {
      expect(redirect(Routes.today), Routes.start);
      expect(redirect(Routes.contacts), Routes.start);
      expect(redirect(Routes.login), Routes.start);
    });

    test('may go from the first-run screen to the import', () {
      for (final path in Routes.onboardingPaths) {
        expect(redirect(path), isNull, reason: path);
      }
    });

    test('is left alone on an invite link', () {
      expect(redirect('/invite/ABCDEFGH'), isNull);
    });
  });

  group('recovering a password', () {
    String? redirect(String location, {bool hasSession = true}) => authRedirect(
      hasSession: hasSession,
      recoveringPassword: true,
      location: location,
    );

    test('goes to reset-password from anywhere', () {
      expect(redirect(Routes.today), Routes.resetPassword);
      expect(redirect(Routes.welcome), Routes.resetPassword);
    });

    test('recovery wins even when a session is already open', () {
      // Someone opens a recovery link while signed in as another account: the
      // link has replaced the session, so it must not be treated as "already
      // signed in, go to Today".
      expect(redirect(Routes.resetPassword), isNull);
      expect(redirect(Routes.login), Routes.resetPassword);
    });
  });

  group('AuthStatus', () {
    test('starts from the restored session', () {
      final fake = FakeAuthRepository()..session = true;
      final status = AuthStatus(fake);

      expect(status.hasSession, isTrue);
      expect(status.recoveringPassword, isFalse);
      status.dispose();
    });

    test('follows sign-in, recovery and sign-out', () async {
      final fake = FakeAuthRepository();
      final status = AuthStatus(fake);
      var notifications = 0;
      status.addListener(() => notifications++);

      fake.emit(AuthChange.signedIn);
      await Future<void>.delayed(Duration.zero);
      expect(status.hasSession, isTrue);

      fake.emit(AuthChange.passwordRecovery);
      await Future<void>.delayed(Duration.zero);
      expect(status.recoveringPassword, isTrue);
      expect(status.hasSession, isTrue);

      fake.emit(AuthChange.userUpdated);
      await Future<void>.delayed(Duration.zero);
      expect(status.recoveringPassword, isFalse);

      fake.emit(AuthChange.signedOut);
      await Future<void>.delayed(Duration.zero);
      expect(status.hasSession, isFalse);
      expect(status.recoveringPassword, isFalse);

      expect(notifications, 4);
      status.dispose();
    });

    test('is exposed by authStatusProvider', () {
      final fake = FakeAuthRepository()..session = true;
      final container = ProviderContainer(
        overrides: [authRepositoryProvider.overrideWithValue(fake)],
      );
      addTearDown(container.dispose);

      expect(container.read(authStatusProvider).hasSession, isTrue);
    });
  });
}

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loomia/app/router/routes.dart';
import 'package:loomia/features/auth/data/auth_repository.dart';
import 'package:loomia/features/auth/domain/auth_change.dart';

/// The whole guard, as a pure function of five facts — which is why it is
/// testable without a router, a widget tree or a client.
String? authRedirect({
  required bool hasSession,
  required bool recoveringPassword,
  required String location,
  bool onboarded = true,
}) {
  // Recovery outranks everything: the link signs the user in before they choose
  // the new password, so "has a session" must not send them to Today.
  if (recoveringPassword) {
    return location == Routes.resetPassword ? null : Routes.resetPassword;
  }
  if (location == Routes.resetPassword) {
    return hasSession ? null : Routes.welcome;
  }
  // Invite links are accessible in every state except password recovery.
  if (location.startsWith('${Routes.invitePrefix}/')) return null;

  final isAuthRoute = Routes.authPaths.contains(location);
  if (!hasSession) return isAuthRoute ? null : Routes.welcome;
  // A new account starts on the first-run screen, wherever it signed in to.
  if (!onboarded) {
    return Routes.onboardingPaths.contains(location) ? null : Routes.start;
  }
  return isAuthRoute ? Routes.today : null;
}

/// The session state the router needs, as a `Listenable` so
/// `GoRouter.refreshListenable` can re-run the redirect.
class AuthStatus extends ChangeNotifier {
  AuthStatus(this._repository) : _hasSession = _repository.hasSession {
    _subscription = _repository.changes.listen(_apply);
  }

  final AuthRepository _repository;

  bool _hasSession;
  bool _recoveringPassword = false;
  late final StreamSubscription<AuthChange> _subscription;

  bool get hasSession => _hasSession;
  bool get recoveringPassword => _recoveringPassword;

  /// Read live: saving it fires `userUpdated`, which re-runs the redirect.
  bool get onboarded => _repository.account?.onboarded ?? true;

  void _apply(AuthChange change) {
    switch (change) {
      case AuthChange.signedIn:
        _hasSession = true;
      case AuthChange.passwordRecovery:
        _hasSession = true;
        _recoveringPassword = true;
      case AuthChange.userUpdated:
        // The new password has been saved, so recovery is over. Also where
        // [onboarded] changes.
        _recoveringPassword = false;
      case AuthChange.signedOut:
        _hasSession = false;
        _recoveringPassword = false;
      case AuthChange.other:
        return;
    }
    notifyListeners();
  }

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}

final authStatusProvider = Provider<AuthStatus>((ref) {
  final status = AuthStatus(ref.watch(authRepositoryProvider));
  ref.onDispose(status.dispose);
  return status;
});

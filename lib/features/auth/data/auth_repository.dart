import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loomia/core/business_model/business_model.dart';
import 'package:loomia/core/supabase/supabase_config.dart';
import 'package:loomia/core/supabase/supabase_provider.dart';
import 'package:loomia/features/auth/data/auth_failure_mapping.dart';
import 'package:loomia/features/auth/domain/account.dart';
import 'package:loomia/features/auth/domain/auth_change.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Auth's side of the `supabase_flutter` boundary: only `data/` files import it.
///
/// Every method throws [AuthFailure] and nothing else, so screens never see a
/// `supabase_flutter` type. Callers pass an already-normalised email
/// (`normalizeEmail`).
class AuthRepository {
  AuthRepository(this._client);

  final SupabaseClient _client;

  GoTrueClient get _auth => _client.auth;

  /// On web, back to the origin the user is on (localhost, preview or live),
  /// which must be in `additional_redirect_urls`; the custom scheme is for
  /// Android and iOS only.
  String get _redirect => kIsWeb ? Uri.base.origin : SupabaseConfig.redirectUrl;

  bool get hasSession => _auth.currentSession != null;

  /// Null when signed out.
  Account? get account {
    final user = _auth.currentUser;
    if (user == null) return null;
    final metadata = user.userMetadata ?? const <String, dynamic>{};
    return Account(
      firstName: (metadata['first_name'] as String?)?.trim() ?? '',
      email: user.email ?? '',
      locale: metadata['locale'] as String?,
      appearance:
          Appearance.values.asNameMap()[metadata['theme']] ?? Appearance.system,
      onboarded: metadata['onboarded'] == true,
      businessModel: BusinessModel.parse(metadata['business_model']),
      avatarPath: metadata['avatar_path'] as String?,
    );
  }

  /// One shared subscription, so the backfill below runs once per sign-in
  /// however many listeners there are.
  late final Stream<AuthChange> changes = _auth.onAuthStateChange.map((state) {
    final change = switch (state.event) {
      AuthChangeEvent.signedIn => AuthChange.signedIn,
      AuthChangeEvent.signedOut => AuthChange.signedOut,
      AuthChangeEvent.passwordRecovery => AuthChange.passwordRecovery,
      AuthChangeEvent.userUpdated => AuthChange.userUpdated,
      _ => AuthChange.other,
    };
    if (change == AuthChange.signedIn) {
      _backfillFirstName(state.session?.user);
    }
    return change;
  }).asBroadcastStream();

  /// Google and Apple return a name; keep it where the email flow puts it, so
  /// the greeting has one place to read from. Best effort — a failure here must
  /// never block a sign-in.
  void _backfillFirstName(User? user) {
    if (user == null) return;
    final metadata = user.userMetadata ?? const <String, dynamic>{};
    final existing = (metadata['first_name'] as String?)?.trim() ?? '';
    if (existing.isNotEmpty) return;
    final full =
        (metadata['full_name'] as String? ?? metadata['name'] as String? ?? '')
            .trim();
    if (full.isEmpty) return;
    final first = full.split(' ').first;
    _auth.updateUser(UserAttributes(data: {'first_name': first})).ignore();
  }

  Future<void> signIn({required String email, required String password}) =>
      _guard(() => _auth.signInWithPassword(email: email, password: password));

  Future<void> signUp({
    required String email,
    required String password,
    required String firstName,
  }) => _guard(
    () => _auth.signUp(
      email: email,
      password: password,
      data: {'first_name': firstName.trim()},
      emailRedirectTo: _redirect,
    ),
  );

  /// Apple is the other provider the product wants; it needs a paid Apple
  /// Developer account, so it is not wired up yet (issue #22).
  Future<void> signInWithGoogle() => _guard(
    () => _auth.signInWithOAuth(OAuthProvider.google, redirectTo: _redirect),
  );

  Future<void> sendPasswordReset(String email) =>
      _guard(() => _auth.resetPasswordForEmail(email, redirectTo: _redirect));

  Future<void> resendConfirmation(String email) => _guard(
    () => _auth.resend(
      type: OtpType.signup,
      email: email,
      emailRedirectTo: _redirect,
    ),
  );

  Future<void> updatePassword(String password) =>
      _guard(() => _auth.updateUser(UserAttributes(password: password)));

  Future<void> signOut() => _guard(_auth.signOut);

  /// Where sign-up and the provider backfill put it, so the greeting follows.
  Future<void> updateFirstName(String firstName) => _guard(
    () => _auth.updateUser(
      UserAttributes(data: {'first_name': firstName.trim()}),
    ),
  );

  /// A language code, or null to follow the system. Kept on the user so it
  /// follows them to every device.
  Future<void> updateLocale(String? locale) =>
      _guard(() => _auth.updateUser(UserAttributes(data: {'locale': locale})));

  /// Stored as `theme`; removed for [Appearance.system], like a null locale.
  Future<void> updateAppearance(Appearance appearance) => _guard(
    () => _auth.updateUser(
      UserAttributes(
        data: {
          'theme': appearance == Appearance.system ? null : appearance.name,
        },
      ),
    ),
  );

  /// Stored as `business_model`; removed for [BusinessModel.other], like a
  /// system appearance.
  Future<void> updateBusinessModel(BusinessModel model) => _guard(
    () => _auth.updateUser(
      UserAttributes(data: {'business_model': model.stored}),
    ),
  );

  /// Stored as `avatar_path`, removed for null. The file is the caller's
  /// (`swapPhoto`).
  Future<void> updateAvatarPath(String? path) => _guard(
    () => _auth.updateUser(UserAttributes(data: {'avatar_path': path})),
  );

  /// The first-run screen is done with, on every device.
  Future<void> markOnboarded() =>
      _guard(() => _auth.updateUser(UserAttributes(data: {'onboarded': true})));

  /// Deleting needs the secret key, so it happens in the `delete-account` Edge
  /// Function. The session is then dead server-side; sign out locally only —
  /// a server sign-out would fail on a user that no longer exists.
  Future<void> deleteAccount() => _guard(() async {
    await _client.functions.invoke('delete-account');
    await _auth.signOut(scope: SignOutScope.local);
  });

  Future<void> _guard(Future<void> Function() call) async {
    try {
      await call();
    } catch (error) {
      throw authFailureFrom(error);
    }
  }
}

final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => AuthRepository(ref.watch(supabaseClientProvider)),
);

/// The signed-in user, re-read on every auth change (sign-in, sign-out, a
/// saved name, language or appearance).
final accountProvider = Provider<Account?>((ref) {
  final repository = ref.watch(authRepositoryProvider);
  final subscription = repository.changes.listen((_) => ref.invalidateSelf());
  ref.onDispose(subscription.cancel);
  return repository.account;
});

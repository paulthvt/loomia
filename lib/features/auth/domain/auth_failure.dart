/// The auth failures a screen can react to differently. Everything else is
/// [unknown] — a longer enum would be a copy list pretending to be a domain.
///
/// Thrown by `AuthRepository`; no `supabase_flutter` type crosses into
/// `presentation`.
enum AuthFailure {
  invalidCredentials,
  emailNotConfirmed,

  /// The new password is the one already on the account.
  samePassword,

  /// The server rejected the password itself — breached or too easy.
  weakPassword,
  rateLimited,

  /// Turnstile gave no token (#529), or Supabase refused it.
  captcha,
  network,
  unknown,
}

import 'package:logging/logging.dart';
import 'package:loomia/features/auth/domain/auth_failure.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Translates anything thrown by `supabase_flutter` into an [AuthFailure].
///
/// Matches on `code` first — the messages are server copy and change without
/// notice.
AuthFailure authFailureFrom(Object error) {
  if (error is AuthFailure) return error;
  // gotrue throws "retryable" for a 5xx too: the server answered, so it is
  // not the connection (an SMTP failure at sign-up is a 500).
  if (error is AuthRetryableFetchException) {
    return error.statusCode == null ? AuthFailure.network : AuthFailure.unknown;
  }
  if (error is AuthException) {
    if (error.statusCode == '429') return AuthFailure.rateLimited;
    switch (error.code) {
      case 'invalid_credentials':
      case 'invalid_grant':
        return AuthFailure.invalidCredentials;
      case 'email_not_confirmed':
        return AuthFailure.emailNotConfirmed;
      case 'same_password':
        return AuthFailure.samePassword;
      case 'weak_password':
        return AuthFailure.weakPassword;
      case 'over_email_send_rate_limit':
      case 'over_request_rate_limit':
        return AuthFailure.rateLimited;
      case 'captcha_failed':
        return AuthFailure.captcha;
      case 'user_already_exists':
      case 'email_exists':
        // Deliberately not surfaced as its own failure: telling the user the
        // address is taken is an account-enumeration oracle.
        return AuthFailure.unknown;
    }
    return AuthFailure.unknown;
  }
  // A malformed answer is not the connection; any other exception on the way
  // (socket, timeout, the http.ClientException functions.invoke throws) is.
  if (error is FormatException) return AuthFailure.unknown;
  if (error is Exception) return AuthFailure.network;
  return AuthFailure.unknown;
}

/// Runs [call] and turns whatever it throws into an [AuthFailure]. Every
/// `AuthRepository` call goes through it. A bug is logged `SEVERE` (a Sentry
/// event), a refusal `WARNING`, the connection `INFO`.
Future<void> guardAuth(Future<void> Function() call) async {
  try {
    await call();
  } catch (error, stack) {
    final failure = authFailureFrom(error);
    switch (error) {
      // Thrown on purpose: nothing went wrong unexpectedly.
      case AuthFailure():
        break;
      case _ when failure == AuthFailure.network:
        _log.info('offline', error);
      // The server failed (an SMTP error at sign-up is a 500): a Sentry
      // event. The body is server copy and may quote the email, so it stays.
      case final AuthRetryableFetchException e:
        _log.severe('server ${e.statusCode}', null, stack);
      // Wrong passwords, rate limits, "email exists": expected. The message
      // is server copy and may quote the email, so only the code goes.
      case final AuthException e:
        _log.warning('${e.code} ${e.statusCode}');
      default:
        _log.severe('unexpected', error, stack);
    }
    throw failure;
  }
}

final _log = Logger('auth');

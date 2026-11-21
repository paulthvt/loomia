import 'package:loomia/features/auth/domain/auth_failure.dart';
import 'package:loomia/l10n/app_localizations.dart';

/// User-facing copy for a failure. Lives in `presentation` because it is copy,
/// not logic.
///
/// [AuthFailure.invalidCredentials] deliberately does not say which field was
/// wrong and does not reveal whether the account exists.
String authFailureCopy(AppLocalizations l10n, AuthFailure failure) =>
    switch (failure) {
      AuthFailure.invalidCredentials => l10n.authFailureInvalidCredentials,
      AuthFailure.emailNotConfirmed => l10n.authFailureEmailNotConfirmed,
      AuthFailure.samePassword => l10n.authFailureSamePassword,
      AuthFailure.weakPassword => l10n.authFailureWeakPassword,
      AuthFailure.rateLimited => l10n.authFailureRateLimited,
      AuthFailure.captcha => l10n.authFailureCaptcha,
      AuthFailure.network => l10n.authFailureNetwork,
      AuthFailure.unknown => l10n.authFailureUnknown,
    };

import 'dart:async';

import 'package:logging/logging.dart';
import 'package:loomia/features/auth/domain/auth_failure.dart';

/// Turnstile tokens for the email auth calls Supabase checks (#529).
///
/// [solve] runs one invisible Turnstile challenge on this platform
/// (`captcha_solver.dart`). A token is used once and expires after 5 minutes,
/// so one is fetched ahead ([warm]) and replaced past [maxAge]; taking it
/// starts the next. That keeps the 3–5 s challenge off the button tap.
class Captcha {
  Captcha(this._solve, {DateTime Function()? now, this.answerWithin = timeout})
    : _now = now ?? DateTime.now;

  final Future<String> Function() _solve;
  final DateTime Function() _now;
  final Duration answerWithin;

  static const timeout = Duration(seconds: 15);

  /// A minute short of Turnstile's 5, so a token never expires on the way.
  static const maxAge = Duration(minutes: 4);

  Future<String>? _ahead;
  DateTime? _aheadSince;

  /// Starts fetching the next token, if none is on its way.
  void warm() {
    if (_ahead != null) return;
    final ahead = _solveOrFail();
    _ahead = ahead;
    _aheadSince = _now();
    // A failed warm-up is dropped, so the next token() solves afresh.
    ahead.then<void>(
      (_) {},
      onError: (Object _) {
        if (identical(_ahead, ahead)) _ahead = null;
      },
    );
  }

  /// A token for one Supabase call. Throws [AuthFailure.captcha].
  Future<String> token() async {
    var token = _ahead;
    if (token == null || _now().difference(_aheadSince!) > maxAge) {
      token = _solveOrFail();
    }
    _ahead = null;
    try {
      return await token;
    } finally {
      warm();
    }
  }

  /// One retry: Turnstile's own retry is off (`retry: 'never'`), since it
  /// loops forever on a failure.
  Future<String> _solveOrFail() async {
    Object? last;
    for (var attempt = 0; attempt < 2; attempt++) {
      try {
        return await _solve().timeout(answerWithin);
      } catch (error) {
        last = error;
      }
    }
    // A Turnstile error code or a timeout: no personal data.
    _log.warning('captcha failed: $last');
    throw AuthFailure.captcha;
  }
}

final _log = Logger('auth');

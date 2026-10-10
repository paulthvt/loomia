import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:loomia/features/auth/data/auth_failure_mapping.dart';
import 'package:loomia/features/auth/domain/auth_failure.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  test('wrong password maps to invalidCredentials', () {
    const error = AuthApiException(
      'Invalid login credentials',
      code: 'invalid_credentials',
      statusCode: '400',
    );
    expect(authFailureFrom(error), AuthFailure.invalidCredentials);
  });

  test('unconfirmed email maps to emailNotConfirmed', () {
    const error = AuthApiException(
      'Email not confirmed',
      code: 'email_not_confirmed',
      statusCode: '400',
    );
    expect(authFailureFrom(error), AuthFailure.emailNotConfirmed);
  });

  test('a new password equal to the old one maps to samePassword', () {
    const error = AuthApiException(
      'New password should be different from the old password.',
      code: 'same_password',
      statusCode: '422',
    );
    expect(authFailureFrom(error), AuthFailure.samePassword);
  });

  test('a rejected password maps to weakPassword', () {
    const error = AuthApiException(
      'Password is known to be weak and easy to guess',
      code: 'weak_password',
      statusCode: '422',
    );
    expect(authFailureFrom(error), AuthFailure.weakPassword);
  });

  test('email send limit maps to rateLimited', () {
    const error = AuthApiException(
      'rate limit',
      code: 'over_email_send_rate_limit',
      statusCode: '429',
    );
    expect(authFailureFrom(error), AuthFailure.rateLimited);
  });

  test('any 429 maps to rateLimited even without a known code', () {
    const error = AuthApiException('slow down', statusCode: '429');
    expect(authFailureFrom(error), AuthFailure.rateLimited);
  });

  test('a retryable fetch failure maps to network', () {
    expect(
      authFailureFrom(AuthRetryableFetchException(message: 'offline')),
      AuthFailure.network,
    );
  });

  test('a socket failure maps to network', () {
    expect(
      authFailureFrom(const SocketException('no route to host')),
      AuthFailure.network,
    );
  });

  test('any other exception on the way is network', () {
    // functions.invoke throws http.ClientException, not a SocketException.
    expect(authFailureFrom(_Offline()), AuthFailure.network);
  });

  test('a malformed answer is unknown', () {
    expect(authFailureFrom(const FormatException('bad')), AuthFailure.unknown);
  });

  test('anything unrecognised maps to unknown', () {
    expect(authFailureFrom(StateError('boom')), AuthFailure.unknown);
  });

  test('an AuthFailure passes through unchanged', () {
    expect(authFailureFrom(AuthFailure.network), AuthFailure.network);
  });
}

class _Offline implements Exception {}

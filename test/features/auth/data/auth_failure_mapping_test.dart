import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:logging/logging.dart';
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

  group('guardAuth logs', () {
    late List<LogRecord> records;
    late StreamSubscription<LogRecord> subscription;

    setUp(() {
      Logger.root.level = Level.ALL;
      records = [];
      subscription = Logger('auth').onRecord.listen(records.add);
    });
    tearDown(() => subscription.cancel());

    Future<void> guard(Object error, AuthFailure failure) =>
        expectLater(guardAuth(() async => throw error), throwsA(failure));

    test('a lost connection is info only', () async {
      await guard(AuthRetryableFetchException(), AuthFailure.network);
      expect(records.map((r) => r.level), [Level.INFO]);
    });

    test('a refusal is a warning with its code, never severe', () async {
      await guard(
        const AuthApiException(
          'Invalid login credentials',
          code: 'invalid_credentials',
          statusCode: '400',
        ),
        AuthFailure.invalidCredentials,
      );
      final record = records.single;
      expect(record.level, Level.WARNING);
      expect(record.message, 'invalid_credentials 400');
    });

    test('a bug is severe, with its stack', () async {
      await guard(const FormatException('bad'), AuthFailure.unknown);
      final record = records.single;
      expect(record.level, Level.SEVERE);
      expect(record.stackTrace, isNotNull);
    });

    test('an AuthFailure thrown on purpose logs nothing', () async {
      await guard(AuthFailure.rateLimited, AuthFailure.rateLimited);
      expect(records, isEmpty);
    });
  });
}

class _Offline implements Exception {}

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loomia/features/auth/data/auth_repository.dart';
import 'package:loomia/features/auth/data/captcha.dart';
import 'package:loomia/features/auth/domain/auth_change.dart';
import 'package:loomia/features/auth/domain/auth_failure.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../fake_auth_repository.dart';

/// A repository on a local server that records each auth request's captcha
/// token, and answers each with an error (enough: only the request counts).
Future<(AuthRepository, Map<String, Object?>)> _recording() async {
  final tokens = <String, Object?>{};
  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
  addTearDown(server.close);
  server.listen((request) async {
    final body = jsonDecode(await utf8.decodeStream(request)) as Map;
    final security = body['gotrue_meta_security'] as Map?;
    tokens[request.uri.path.split('/').last] = security?['captcha_token'];
    request.response
      ..statusCode = 400
      ..headers.contentType = ContentType.json
      ..write(jsonEncode({'code': 'validation_failed', 'msg': 'stop'}));
    await request.response.close();
  });
  final client = SupabaseClient(
    'http://${server.address.host}:${server.port}',
    'publishable',
    // PKCE needs a storage for its verifier; the request is what counts here.
    authOptions: const AuthClientOptions(authFlowType: AuthFlowType.implicit),
  );
  addTearDown(client.dispose);
  var n = 0;
  return (AuthRepository(client, Captcha(() async => 't${n++}')), tokens);
}

void main() {
  test('every email call sends its own captcha token', () async {
    final (repository, tokens) = await _recording();
    Future<void> attempt(Future<void> call) =>
        call.then((_) {}, onError: (Object _) {});

    await attempt(repository.signIn(email: 'a@example.com', password: 'x'));
    await attempt(
      repository.signUp(
        email: 'a@example.com',
        password: 'x',
        firstName: 'A',
        language: 'en',
      ),
    );
    await attempt(repository.sendPasswordReset('a@example.com'));
    await attempt(repository.resendConfirmation('a@example.com'));

    expect(tokens.keys, containsAll(['token', 'signup', 'recover', 'resend']));
    expect(tokens.values.toSet(), hasLength(4));
    expect(tokens.values, everyElement(startsWith('t')));
  });

  test('no token means no request', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(server.close);
    var requests = 0;
    server.listen((r) {
      requests++;
      r.response.close();
    });
    final client = SupabaseClient('http://127.0.0.1:${server.port}', 'p');
    addTearDown(client.dispose);
    final repository = AuthRepository(
      client,
      Captcha(() async => throw StateError('600010')),
    );

    await expectLater(
      repository.signIn(email: 'a@example.com', password: 'x'),
      throwsA(AuthFailure.captcha),
    );
    expect(requests, 0);
  });

  test('the fake satisfies the whole repository surface', () {
    final AuthRepository repository = FakeAuthRepository();
    expect(repository.hasSession, isFalse);
  });

  test('a fake records calls and throws what it is told to', () async {
    final fake = FakeAuthRepository()
      ..failWith = AuthFailure.invalidCredentials;

    await expectLater(
      fake.signIn(email: 'pauline@example.com', password: 'hunter22'),
      throwsA(AuthFailure.invalidCredentials),
    );
    expect(fake.calls, ['signIn(pauline@example.com, hunter22)']);
  });

  test('a fake can hold a call in flight', () async {
    final fake = FakeAuthRepository()..gate = Completer<void>();
    var done = false;

    final future = fake.signOut().then((_) => done = true);
    await Future<void>.delayed(Duration.zero);
    expect(done, isFalse);

    fake.gate!.complete();
    await future;
    expect(done, isTrue);
  });

  test('changes is a broadcast stream of domain events', () async {
    final fake = FakeAuthRepository();
    final seen = <AuthChange>[];
    fake.changes.listen(seen.add);

    fake.emit(AuthChange.passwordRecovery);
    await Future<void>.delayed(Duration.zero);

    expect(seen, [AuthChange.passwordRecovery]);
    fake.dispose();
  });

  test('authRepositoryProvider can be overridden with a fake', () {
    final fake = FakeAuthRepository();
    final container = ProviderContainer(
      overrides: [authRepositoryProvider.overrideWithValue(fake)],
    );
    addTearDown(container.dispose);

    expect(container.read(authRepositoryProvider), same(fake));
  });

  group('changes on the real client', () {
    late SupabaseClient client;
    late AuthRepository repository;

    setUp(() {
      client = SupabaseClient('http://localhost', 'publishable');
      repository = AuthRepository(client, Captcha(() async => 'unused'));
    });
    tearDown(() => client.dispose());

    // Offline, every failed background refresh lands on onAuthStateChange
    // (#260); a listener without onError would make each one uncaught.
    test('drops a failed token refresh', () async {
      final errors = <Object>[];
      repository.changes.listen((_) {}, onError: errors.add);

      // ignore: invalid_use_of_internal_member, how gotrue reports it.
      client.auth.notifyException(AuthRetryableFetchException());
      await Future<void>.delayed(Duration.zero);

      expect(errors, isEmpty);
    });

    test('lets any other error through', () async {
      final errors = <Object>[];
      repository.changes.listen((_) {}, onError: errors.add);

      // ignore: invalid_use_of_internal_member, how gotrue reports it.
      client.auth.notifyException(const AuthException('boom'));
      await Future<void>.delayed(Duration.zero);

      expect(errors, hasLength(1));
    });
  });
}

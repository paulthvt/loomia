import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loomia/features/auth/data/auth_repository.dart';
import 'package:loomia/features/auth/domain/auth_change.dart';
import 'package:loomia/features/auth/domain/auth_failure.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../fake_auth_repository.dart';

void main() {
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
      repository = AuthRepository(client);
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

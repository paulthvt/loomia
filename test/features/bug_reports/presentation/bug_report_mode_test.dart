import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loomia/features/auth/data/auth_repository.dart';
import 'package:loomia/features/auth/domain/account.dart';
import 'package:loomia/features/auth/domain/auth_change.dart';
import 'package:loomia/features/bug_reports/presentation/bug_report_mode.dart';

import '../../auth/fake_auth_repository.dart';

void main() {
  late FakeAuthRepository auth;
  late ProviderContainer container;

  ProviderContainer containerFor({required bool reporter}) {
    auth = FakeAuthRepository()
      ..session = true
      ..account = Account(
        firstName: 'Pauline',
        email: 'p@example.com',
        bugReporter: reporter,
      );
    final c = ProviderContainer(
      overrides: [authRepositoryProvider.overrideWithValue(auth)],
    );
    addTearDown(c.dispose);
    addTearDown(auth.dispose);
    return c;
  }

  test('starts off and turns on for a reporter', () {
    container = containerFor(reporter: true);
    expect(container.read(bugReportModeProvider), isFalse);
    container.read(bugReportModeProvider.notifier).turnOn();
    expect(container.read(bugReportModeProvider), isTrue);
    container.read(bugReportModeProvider.notifier).turnOff();
    expect(container.read(bugReportModeProvider), isFalse);
  });

  test('stays off for anyone else', () {
    container = containerFor(reporter: false);
    container.read(bugReportModeProvider.notifier).turnOn();
    expect(container.read(bugReportModeProvider), isFalse);
  });

  test('sign-out turns the mode off', () async {
    container = containerFor(reporter: true);
    container.read(bugReportModeProvider.notifier).turnOn();
    auth
      ..account = null
      ..emit(AuthChange.signedOut);
    await Future<void>.delayed(Duration.zero);
    expect(container.read(bugReportModeProvider), isFalse);
  });

  test('a token refresh keeps it on', () async {
    container = containerFor(reporter: true);
    container.read(bugReportModeProvider.notifier).turnOn();
    auth.emit(AuthChange.other);
    await Future<void>.delayed(Duration.zero);
    expect(container.read(bugReportModeProvider), isTrue);
  });
}

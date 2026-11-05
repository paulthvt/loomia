import 'dart:typed_data';

import 'package:feedback/feedback.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loomia/app/router/app_router.dart';
import 'package:loomia/app/router/routes.dart';
import 'package:loomia/features/auth/domain/account.dart';
import 'package:loomia/features/bug_reports/presentation/bug_report_controller.dart';
import 'package:loomia/features/bug_reports/presentation/bug_report_mode.dart';
import 'package:loomia/features/bug_reports/presentation/bug_report_overlay.dart';
import 'package:material_ui/material_ui.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../../app/app_harness.dart';
import '../../auth/fake_auth_repository.dart';
import '../fake_bug_report_repository.dart';

const _size = Size(390, 844);
final _button = find.bySemanticsLabel('Report a bug');
final _target = find.bySemanticsLabel('Turn off bug reports');

void main() {
  setUp(
    () => PackageInfo.setMockInitialValues(
      appName: 'Loomia',
      packageName: 'app.loomia',
      version: '0.4.0',
      buildNumber: '40',
      buildSignature: '',
    ),
  );

  Future<ProviderContainer> pump(
    WidgetTester tester, {
    bool on = true,
    FakeBugReportRepository? bugReports,
  }) async {
    final auth = FakeAuthRepository()
      ..session = true
      ..account = const Account(
        firstName: 'Pauline',
        email: 'p@example.com',
        bugReporter: true,
      );
    final container = await pumpLoomia(
      tester,
      size: _size,
      auth: auth,
      bugReports: bugReports,
    );
    if (on) {
      container.read(bugReportModeProvider.notifier).turnOn();
      await tester.pumpAndSettle();
    }
    return container;
  }

  /// Drags the button so its centre lands on [to].
  Future<void> drag(WidgetTester tester, Offset to) async {
    final gesture = await tester.startGesture(tester.getCenter(_button));
    await gesture.moveTo(to, timeStamp: const Duration(milliseconds: 100));
    await tester.pump();
    await gesture.up();
    await tester.pumpAndSettle();
  }

  testWidgets('no button while the mode is off', (tester) async {
    await pump(tester, on: false);
    expect(_button, findsNothing);
  });

  testWidgets('the button shows on Today, Contacts and Settings', (
    tester,
  ) async {
    final container = await pump(tester);
    expect(_button, findsOneWidget);
    for (final path in [Routes.contacts, Routes.settings]) {
      container.read(routerProvider).go(path);
      await tester.pumpAndSettle();
      expect(_button, findsOneWidget, reason: path);
    }
  });

  testWidgets('starts at the right edge, above the snackbar band', (
    tester,
  ) async {
    await pump(tester);
    final rect = tester.getRect(_button);
    expect(rect.right, closeTo(_size.width - 16, 1));
    expect(rect.bottom, lessThanOrEqualTo(_size.height - bugReportBand));
  });

  testWidgets('tapping it opens the panel and hides the button', (
    tester,
  ) async {
    await pump(tester);
    await tester.tap(_button);
    await tester.pumpAndSettle();
    expect(find.text('What went wrong?'), findsOneWidget);
    expect(_button, findsNothing);
  });

  testWidgets('the ✕ shows only while dragging', (tester) async {
    await pump(tester);
    expect(_target, findsNothing);
    final gesture = await tester.startGesture(tester.getCenter(_button));
    await gesture.moveBy(const Offset(-40, -40));
    await tester.pump();
    expect(_target, findsOneWidget);
    await gesture.up();
    await tester.pumpAndSettle();
    expect(_target, findsNothing);
  });

  testWidgets('dropping it on the ✕ turns the mode off; Undo brings it back', (
    tester,
  ) async {
    final container = await pump(tester);
    final start = tester.getCenter(_button);
    final gesture = await tester.startGesture(start);
    await gesture.moveBy(const Offset(-20, 0));
    await tester.pump();
    await gesture.moveTo(tester.getCenter(_target));
    await tester.pump();
    await gesture.up();
    await tester.pumpAndSettle();

    expect(container.read(bugReportModeProvider), isFalse);
    expect(_button, findsNothing);
    expect(find.text('Bug reports off'), findsOneWidget);

    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();
    expect(container.read(bugReportModeProvider), isTrue);
    expect(tester.getCenter(_button), start);
  });

  testWidgets('a drop away from the target keeps the mode', (tester) async {
    final container = await pump(tester);
    await drag(tester, const Offset(100, 300));
    expect(container.read(bugReportModeProvider), isTrue);
    expect(tester.getCenter(_button), const Offset(100, 300));
  });

  testWidgets('a drop in the bottom band settles just above it', (
    tester,
  ) async {
    await pump(tester);
    await drag(tester, Offset(60, _size.height - 40));
    final rect = tester.getRect(_button);
    expect(rect.bottom, closeTo(_size.height - bugReportBand, 1));
    expect(rect.center.dx, 60);
  });

  group('after sending', () {
    late FakeBugReportRepository repository;

    Future<ProviderContainer> pumpWith(WidgetTester tester) {
      repository = FakeBugReportRepository();
      return pump(tester, bugReports: repository);
    }

    Future<void> send(WidgetTester tester, ProviderContainer container) async {
      await container
          .read(bugReportControllerProvider.notifier)
          .submit(
            UserFeedback(text: 'It froze', screenshot: Uint8List(8)),
            facts: const {},
          );
      await tester.pumpAndSettle();
    }

    testWidgets('a sent report shows its issue number', (tester) async {
      final container = await pumpWith(tester);
      repository.issue = 42;
      await send(tester, container);
      expect(find.text('Sent as #42'), findsOneWidget);
    });

    testWidgets('a failed one offers Retry, reachable past the button', (
      tester,
    ) async {
      WidgetController.hitTestWarningShouldBeFatal = true;
      addTearDown(() => WidgetController.hitTestWarningShouldBeFatal = false);
      final container = await pumpWith(tester);
      repository.failOnce = StateError('offline');
      await send(tester, container);
      expect(find.text("Couldn't send"), findsOneWidget);

      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();
      expect(repository.sent, hasLength(2));
      expect(repository.sent[1].id, repository.sent[0].id);
    });
  });
}

import 'dart:typed_data';

import 'package:feedback/feedback.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:logging/logging.dart';
import 'package:loomia/features/auth/domain/auth_failure.dart';
import 'package:loomia/features/bug_reports/data/bug_report_repository.dart';
import 'package:loomia/features/bug_reports/domain/log_buffer.dart';
import 'package:loomia/features/bug_reports/presentation/bug_report_controller.dart';

import '../fake_bug_report_repository.dart';

final _uuid = RegExp(
  r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
);

void main() {
  late FakeBugReportRepository repository;
  late ProviderContainer container;
  final png = Uint8List.fromList([137, 80, 78, 71]);
  final feedback = UserFeedback(text: 'It froze', screenshot: png);

  setUp(() {
    repository = FakeBugReportRepository();
    final logs = LogBuffer()..add(LogRecord(Level.INFO, '→ /today', 'router'));
    container = ProviderContainer(
      overrides: [
        bugReportRepositoryProvider.overrideWithValue(repository),
        logBufferProvider.overrideWithValue(logs),
      ],
    );
    addTearDown(container.dispose);
  });

  BugReportController controller() =>
      container.read(bugReportControllerProvider.notifier);

  test('submit sends the comment, the PNG, the logs and a fresh id', () async {
    await controller().submit(feedback, facts: const {'route': '/today'});

    final report = repository.sent.single;
    expect(report.comment, 'It froze');
    expect(report.screenshot, png);
    expect(report.facts, {'route': '/today'});
    expect(report.logs.single.message, '→ /today');
    expect(_uuid.hasMatch(report.id), isTrue, reason: report.id);
    expect(container.read(bugReportControllerProvider), const Sent(123));
  });

  test('two reports get two ids', () async {
    await controller().submit(feedback, facts: const {});
    await controller().submit(feedback, facts: const {});
    expect(repository.sent[0].id, isNot(repository.sent[1].id));
  });

  test('a failure keeps the report for a retry', () async {
    repository.failOnce = AuthFailure.network;
    await controller().submit(feedback, facts: const {});
    final state = container.read(bugReportControllerProvider);
    expect(state, isA<Failed>());
    expect((state as Failed).report, same(repository.sent.single));
  });

  test('retry resends the same report id', () async {
    repository.failOnce = AuthFailure.network;
    await controller().submit(feedback, facts: const {});
    await controller().retry();

    expect(repository.sent, hasLength(2));
    expect(repository.sent[1].id, repository.sent[0].id);
    expect(repository.sent[1].screenshot, png);
    expect(container.read(bugReportControllerProvider), const Sent(123));
  });
}

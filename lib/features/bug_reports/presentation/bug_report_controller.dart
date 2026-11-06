import 'dart:math';

import 'package:feedback/feedback.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loomia/features/bug_reports/data/bug_report_repository.dart';
import 'package:loomia/features/bug_reports/domain/bug_report.dart';
import 'package:loomia/features/bug_reports/domain/log_buffer.dart';

sealed class BugReportSendState {
  const BugReportSendState();
}

class Idle extends BugReportSendState {
  const Idle();
}

class Sending extends BugReportSendState {
  const Sending();
}

class Sent extends BugReportSendState {
  const Sent(this.issue);
  final int issue;

  @override
  bool operator ==(Object other) => other is Sent && other.issue == issue;

  @override
  int get hashCode => issue.hashCode;
}

/// The panel closes on Send, so a report that failed is kept here until
/// Retry sends it (with the same id) or the app closes.
class Failed extends BugReportSendState {
  const Failed(this.report);
  final BugReport report;
}

class BugReportController extends Notifier<BugReportSendState> {
  @override
  BugReportSendState build() => const Idle();

  Future<void> submit(
    UserFeedback feedback, {
    required Map<String, Object?> facts,
  }) => _send(
    BugReport(
      id: _uuidV4(),
      // The sheet passes it as an extra; `feedback` has no title of its own.
      title: feedback.extra?['title'] as String? ?? '',
      comment: feedback.text,
      screenshot: feedback.screenshot,
      facts: facts,
      logs: ref.read(logBufferProvider).entries,
    ),
  );

  Future<void> retry() async {
    if (state case Failed(:final report)) await _send(report);
  }

  Future<void> _send(BugReport report) async {
    state = const Sending();
    try {
      state = Sent(await ref.read(bugReportRepositoryProvider).send(report));
    } on Object {
      // guardAuth has already logged it.
      state = Failed(report);
    }
  }
}

final bugReportControllerProvider =
    NotifierProvider<BugReportController, BugReportSendState>(
      BugReportController.new,
    );

final _random = Random.secure();

/// A random (version 4) UUID; the only one the app makes, so no package.
String _uuidV4() {
  final b = List<int>.generate(16, (_) => _random.nextInt(256));
  b[6] = (b[6] & 0x0f) | 0x40;
  b[8] = (b[8] & 0x3f) | 0x80;
  final hex = [for (final x in b) x.toRadixString(16).padLeft(2, '0')].join();
  return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-'
      '${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
}

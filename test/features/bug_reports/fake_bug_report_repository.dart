import 'package:loomia/features/bug_reports/data/bug_report_repository.dart';
import 'package:loomia/features/bug_reports/domain/bug_report.dart';

class FakeBugReportRepository implements BugReportRepository {
  final List<BugReport> sent = [];

  /// Thrown by the next [send] when set, then cleared.
  Object? failOnce;

  int issue = 123;

  @override
  Future<int> send(BugReport report) async {
    sent.add(report);
    if (failOnce case final error?) {
      failOnce = null;
      throw error;
    }
    return issue;
  }
}

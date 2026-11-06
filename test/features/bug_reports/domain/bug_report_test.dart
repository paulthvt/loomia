import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:loomia/features/bug_reports/domain/bug_report.dart';
import 'package:loomia/features/bug_reports/domain/log_buffer.dart';

void main() {
  final entry = LogEntry(
    time: DateTime.utc(2026, 11, 5, 10),
    level: 'INFO',
    logger: 'router',
    message: '→ /today',
  );
  final report = BugReport(
    id: '3f2b8c1e-9a4d-4e6b-8c2f-1a2b3c4d5e6f',
    title: ' Plan button gone ',
    comment: '  The button is gone \n',
    screenshot: Uint8List.fromList([137, 80, 78, 71, 1, 2, 3]),
    facts: const {'appVersion': '0.4.0'},
    logs: [entry],
  );

  test('toJson base64-encodes the screenshot', () {
    final json = report.toJson();
    expect(base64Decode(json['screenshot']! as String), [
      137,
      80,
      78,
      71,
      1,
      2,
      3,
    ]);
  });

  test('toJson trims the comment and keeps id and facts', () {
    final json = report.toJson();
    expect(json['id'], '3f2b8c1e-9a4d-4e6b-8c2f-1a2b3c4d5e6f');
    expect(json['comment'], 'The button is gone');
    expect(json['title'], 'Plan button gone');
    expect(json['facts'], {'appVersion': '0.4.0'});
  });

  test('toJson lists the log entries as their own JSON', () {
    expect(report.toJson()['logs'], [entry.toJson()]);
  });
}

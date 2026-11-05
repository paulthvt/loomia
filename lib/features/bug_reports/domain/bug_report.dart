import 'dart:convert';
import 'dart:typed_data';

import 'package:loomia/features/bug_reports/domain/log_buffer.dart';

/// One report as the `report-bug` Edge Function reads it (#463). [id] is
/// made once when Send is tapped and kept across retries, so a retry
/// overwrites the same screenshot on the NAS.
class BugReport {
  const BugReport({
    required this.id,
    required this.comment,
    required this.screenshot,
    required this.facts,
    required this.logs,
  });

  final String id;
  final String comment;

  /// PNG bytes.
  final Uint8List screenshot;
  final Map<String, Object?> facts;
  final List<LogEntry> logs;

  Map<String, Object?> toJson() => {
    'id': id,
    'comment': comment.trim(),
    'screenshot': base64Encode(screenshot),
    'facts': facts,
    'logs': [for (final entry in logs) entry.toJson()],
  };
}

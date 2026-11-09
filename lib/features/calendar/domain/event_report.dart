import 'package:loomia/features/calendar/domain/calendar_event.dart';
import 'package:loomia/features/workflows/domain/event_workflow.dart';

typedef ReportEntry = ({String label, String text});

/// The report for [event]: its own when present, else the type's template
/// with empty text; `[]` when [type] is null or group.
List<ReportEntry> reportFor(CalendarEvent event, EventWorkflow? type) {
  if (type == null || type.isGroup) return const [];
  if (event.report != null) return event.report!;
  return [for (final label in type.reportFields) (label: label, text: '')];
}

/// Texts trimmed; `null` when every text is empty.
List<ReportEntry>? normaliseReport(List<ReportEntry> entries) {
  final normalised = [
    for (final entry in entries)
      if (entry.text.trim().isNotEmpty)
        (label: entry.label, text: entry.text.trim()),
  ];
  if (normalised.isEmpty) return null;
  return normalised;
}

/// First line of the first non-empty text.
String? reportPreview(List<ReportEntry>? report) {
  if (report == null || report.isEmpty) return null;
  for (final entry in report) {
    if (entry.text.isNotEmpty) {
      return entry.text.split('\n').first;
    }
  }
  return null;
}

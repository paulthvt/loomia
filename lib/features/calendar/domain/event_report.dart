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

/// Texts trimmed; `null` when every text is empty. Blank entries stay, so
/// their fields are still there to fill in when the event opens again.
List<ReportEntry>? normaliseReport(List<ReportEntry> entries) {
  final normalised = [
    for (final entry in entries) (label: entry.label, text: entry.text.trim()),
  ];
  if (normalised.every((entry) => entry.text.isEmpty)) return null;
  return normalised;
}

/// Whether deleting from [from] on, as "This and following events" does,
/// takes a report with it: [from] or a later, not done occurrence of its
/// series in [events] has one.
bool reportsFrom(Iterable<CalendarEvent> events, CalendarEvent from) =>
    from.report != null ||
    events.any(
      (event) =>
          event.series != null &&
          event.series?.id == from.series?.id &&
          !event.done &&
          !event.startsAt.isBefore(from.startsAt) &&
          event.report != null,
    );

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

import 'package:flutter_test/flutter_test.dart';
import 'package:loomia/features/calendar/domain/calendar_event.dart';
import 'package:loomia/features/calendar/domain/event_report.dart';
import 'package:loomia/features/workflows/domain/event_workflow.dart';

void main() {
  group('reportFor', () {
    test('returns template with empty text when report is null', () {
      final workflow = EventWorkflow(
        id: '1',
        name: 'Workshop',
        steps: const [],
        isGroup: false,
        reportFields: const ['Highlights', 'Next steps'],
      );
      final event = CalendarEvent(
        id: 'e1',
        title: 'Test Event',
        startsAt: DateTime(2026, 11, 9),
        report: null,
      );

      final result = reportFor(event, workflow);

      expect(result, [
        (label: 'Highlights', text: ''),
        (label: 'Next steps', text: ''),
      ]);
    });

    test(
      'returns event report frozen after type rename and field addition',
      () {
        final workflow = EventWorkflow(
          id: '1',
          name: 'Workshop',
          steps: const [],
          isGroup: false,
          reportFields: const ['A2', 'B', 'C'],
        );
        final event = CalendarEvent(
          id: 'e1',
          title: 'Test Event',
          startsAt: DateTime(2026, 11, 9),
          report: const [
            (label: 'A', text: 'text A'),
            (label: 'B', text: 'text B'),
          ],
        );

        final result = reportFor(event, workflow);

        expect(result, [
          (label: 'A', text: 'text A'),
          (label: 'B', text: 'text B'),
        ]);
      },
    );

    test('returns empty list for null type', () {
      final event = CalendarEvent(
        id: 'e1',
        title: 'Test Event',
        startsAt: DateTime(2026, 11, 9),
      );

      final result = reportFor(event, null);

      expect(result, const <ReportEntry>[]);
    });

    test('returns empty list for group type with fields', () {
      final workflow = EventWorkflow(
        id: '1',
        name: 'Workshop',
        steps: const [],
        isGroup: true,
        reportFields: const ['A', 'B'],
      );
      final event = CalendarEvent(
        id: 'e1',
        title: 'Test Event',
        startsAt: DateTime(2026, 11, 9),
      );

      final result = reportFor(event, workflow);

      expect(result, const <ReportEntry>[]);
    });
  });

  group('normaliseReport', () {
    test('returns null when all texts are blank', () {
      expect(
        normaliseReport(const [
          (label: 'A', text: ' '),
          (label: 'B', text: ''),
        ]),
        null,
      );
    });

    test('trims texts and returns list', () {
      expect(normaliseReport(const [(label: 'A', text: ' x ')]), const [
        (label: 'A', text: 'x'),
      ]);
    });

    test('returns null for empty list', () {
      expect(normaliseReport(const []), null);
    });

    test('keeps entries with non-empty text only', () {
      expect(
        normaliseReport(const [
          (label: 'A', text: '  '),
          (label: 'B', text: 'content'),
          (label: 'C', text: ''),
        ]),
        const [(label: 'B', text: 'content')],
      );
    });
  });

  group('reportPreview', () {
    test('returns null for null report', () {
      expect(reportPreview(null), null);
    });

    test('returns null for empty report', () {
      expect(reportPreview(const []), null);
    });

    test('returns first line of first non-empty text', () {
      expect(
        reportPreview(const [
          (label: 'A', text: ''),
          (label: 'B', text: 'line1\nline2'),
        ]),
        'line1',
      );
    });

    test('returns single line text as is', () {
      expect(
        reportPreview(const [(label: 'A', text: 'single line')]),
        'single line',
      );
    });

    test('returns null when all texts are empty', () {
      expect(
        reportPreview(const [(label: 'A', text: ''), (label: 'B', text: '')]),
        null,
      );
    });
  });
}

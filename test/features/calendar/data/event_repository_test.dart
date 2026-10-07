import 'package:flutter_test/flutter_test.dart';
import 'package:loomia/features/calendar/data/event_repository.dart';

void main() {
  test('reads a row: instants in UTC, blank text as null', () {
    final event = eventFromRow({
      'id': 'e1',
      'title': 'Workshop',
      'starts_at': '2026-10-08T17:00:00+00:00',
      'ends_at': null,
      'place': '  ',
      'link': 'https://meet.google.com/abc',
      'notes': 'Bring the diffuser',
    });

    expect(event.id, 'e1');
    expect(event.title, 'Workshop');
    expect(event.startsAt, DateTime.utc(2026, 10, 8, 17));
    expect(event.endsAt, isNull);
    expect(event.place, isNull);
    expect(event.link, 'https://meet.google.com/abc');
    expect(event.notes, 'Bring the diffuser');
  });

  test('writes a draft: local times as UTC instants', () {
    final row = draftToEventRow((
      title: 'Workshop',
      startsAt: DateTime(2026, 10, 8, 19),
      endsAt: DateTime(2026, 10, 8, 21),
      place: 'Studio Lumière',
      link: null,
      notes: null,
    ));

    expect(row, {
      'title': 'Workshop',
      'starts_at': DateTime(2026, 10, 8, 19).toUtc().toIso8601String(),
      'ends_at': DateTime(2026, 10, 8, 21).toUtc().toIso8601String(),
      'place': 'Studio Lumière',
      'link': null,
      'notes': null,
    });
  });

  test('reads the attendees and when it was marked done', () {
    final event = eventFromRow({
      'id': 'e1',
      'title': 'Workshop',
      'starts_at': '2026-10-08T17:00:00+00:00',
      'ends_at': null,
      'place': null,
      'link': null,
      'notes': null,
      'done_at': '2026-10-09T08:00:00+00:00',
      'event_attendee': [
        {'person_id': 'p1', 'came': true},
        {'person_id': 'p2', 'came': false},
      ],
    });

    expect(event.doneAt, DateTime.utc(2026, 10, 9, 8));
    expect(event.done, isTrue);
    expect(event.attendees, [
      (personId: 'p1', came: true),
      (personId: 'p2', came: false),
    ]);
    expect(event.cameCount, 1);
  });

  test('a row without the embed has nobody invited', () {
    final event = eventFromRow({
      'id': 'e1',
      'title': 'Workshop',
      'starts_at': '2026-10-08T17:00:00+00:00',
    });

    expect(event.attendees, isEmpty);
    expect(event.done, isFalse);
  });
}

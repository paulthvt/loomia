import 'package:flutter_test/flutter_test.dart';
import 'package:loomia/features/calendar/domain/calendar_event.dart';

CalendarEvent _event(String id, DateTime startsAt) =>
    CalendarEvent(id: id, title: id, startsAt: startsAt);

void main() {
  test('an event just after local midnight is on that local day', () {
    // The previous day in UTC east of Greenwich.
    final late = _event('late', DateTime(2026, 10, 8, 0, 30).toUtc());

    expect(late.day, DateTime(2026, 10, 8));
    expect(eventsOn([late], DateTime(2026, 10, 8)), [late]);
    expect(eventsOn([late], DateTime(2026, 10, 7)), isEmpty);
  });

  test("a day's events, earliest first", () {
    final evening = _event('evening', DateTime(2026, 10, 8, 19));
    final lunch = _event('lunch', DateTime(2026, 10, 8, 12));
    final other = _event('other', DateTime(2026, 10, 9, 9));

    expect(eventsOn([evening, other, lunch], DateTime(2026, 10, 8)), [
      lunch,
      evening,
    ]);
    expect(byStart([evening, other, lunch]), [lunch, evening, other]);
  });

  test('events per local day', () {
    expect(
      eventsPerDay([
        _event('a', DateTime(2026, 10, 8, 10)),
        _event('b', DateTime(2026, 10, 8, 19)),
        _event('c', DateTime(2026, 10, 14, 19)),
      ]),
      {DateTime(2026, 10, 8): 2, DateTime(2026, 10, 14): 1},
    );
  });

  group('normaliseLink', () {
    test('adds https to a bare address', () {
      expect(
        normaliseLink(' meet.google.com/abc '),
        'https://meet.google.com/abc',
      );
    });

    test('keeps an http(s) link', () {
      expect(normaliseLink('https://zoom.us/j/1'), 'https://zoom.us/j/1');
      expect(normaliseLink('http://example.com'), 'http://example.com');
    });

    test('refuses what is not a web address', () {
      expect(normaliseLink(''), isNull);
      expect(normaliseLink('   '), isNull);
      expect(normaliseLink('hello'), isNull);
      expect(normaliseLink('ftp://example.com'), isNull);
      expect(normaliseLink('javascript:alert(1)'), isNull);
    });
  });

  test('a link is shown without its scheme', () {
    expect(shownLink('https://meet.google.com/abc'), 'meet.google.com/abc');
    expect(shownLink('http://example.com'), 'example.com');
  });

  test('directions open Apple Maps on iOS, Google Maps elsewhere', () {
    final apple = mapsUri('Studio Lumière, Lyon', apple: true);
    expect(apple.host, 'maps.apple.com');
    expect(apple.queryParameters, {'q': 'Studio Lumière, Lyon'});

    final google = mapsUri('Studio Lumière, Lyon', apple: false);
    expect(google.host, 'www.google.com');
    expect(google.path, '/maps/search/');
    expect(google.queryParameters, {
      'api': '1',
      'query': 'Studio Lumière, Lyon',
    });
  });

  group('canMarkDone', () {
    final starts = DateTime(2026, 10, 8, 19);
    CalendarEvent event({
      List<Attendee> attendees = const [(personId: 'p1', came: false)],
      DateTime? doneAt,
    }) => CalendarEvent(
      id: 'e1',
      title: 'Workshop',
      startsAt: starts,
      attendees: attendees,
      doneAt: doneAt,
    );

    test('once it has started, with someone invited', () {
      expect(event().canMarkDone(starts), isTrue);
      expect(event().canMarkDone(DateTime(2026, 10, 9)), isTrue);
    });

    test('not before it starts, not with nobody, not twice', () {
      expect(event().canMarkDone(DateTime(2026, 10, 8, 18, 59)), isFalse);
      expect(event(attendees: const []).canMarkDone(starts), isFalse);
      expect(event(doneAt: starts).canMarkDone(starts), isFalse);
    });
  });
}

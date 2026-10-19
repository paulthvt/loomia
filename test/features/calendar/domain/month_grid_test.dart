import 'package:flutter_test/flutter_test.dart';
import 'package:loomia/features/calendar/domain/month_grid.dart';

// firstDayOfWeek as MaterialLocalizations.firstDayOfWeekIndex: 0 is Sunday.
const _sunday = 0;
const _monday = 1;

void main() {
  test('October 2026 from Monday: September 28 to November 1', () {
    final days = monthDays(DateTime(2026, 10), _monday);

    expect(days.length, 35);
    expect(days.first, DateTime(2026, 9, 28));
    expect(days.last, DateTime(2026, 11, 1));
  });

  test('from Sunday, the weeks start a day earlier', () {
    final days = monthDays(DateTime(2026, 10), _sunday);

    expect(days.first, DateTime(2026, 9, 27));
    expect(days.first.weekday, DateTime.sunday);
    expect(days.last, DateTime(2026, 10, 31));
  });

  test('a month that starts on the first weekday fills four weeks', () {
    final days = monthDays(DateTime(2026, 2), _sunday);

    expect(days.length, 28);
    expect(days.first, DateTime(2026, 2));
    expect(days.last, DateTime(2026, 2, 28));
  });

  test('a leap February', () {
    final days = monthDays(DateTime(2028, 2), _monday);

    expect(days.first, DateTime(2028, 1, 31));
    expect(days, contains(DateTime(2028, 2, 29)));
    expect(days.last, DateTime(2028, 3, 5));
  });

  test('every day once, at local midnight, across a DST change', () {
    for (final month in [DateTime(2026, 3), DateTime(2026, 10)]) {
      final days = monthDays(month, _monday);

      expect(days.every((day) => day.hour == 0 && day.minute == 0), isTrue);
      for (var i = 1; i < days.length; i++) {
        final before = days[i - 1];
        expect(days[i], DateTime(before.year, before.month, before.day + 1));
      }
    }
  });

  group('weekDays', () {
    test('the week of a Wednesday, from Monday and from Sunday', () {
      final day = DateTime(2026, 10, 21);

      expect(weekDays(day, _monday), [
        for (var d = 19; d <= 25; d++) DateTime(2026, 10, d),
      ]);
      expect(weekDays(day, _sunday), [
        for (var d = 18; d <= 24; d++) DateTime(2026, 10, d),
      ]);
    });

    test('the first weekday starts its own week', () {
      expect(
        weekDays(DateTime(2026, 10, 19), _monday).first,
        DateTime(2026, 10, 19),
      );
      expect(
        weekDays(DateTime(2026, 10, 18), _sunday).first,
        DateTime(2026, 10, 18),
      );
    });

    test('a week across months and years', () {
      final days = weekDays(DateTime(2026, 12, 31), _monday);

      expect(days.first, DateTime(2026, 12, 28));
      expect(days.last, DateTime(2027, 1, 3));
    });

    test('7 local midnights across a DST change', () {
      final days = weekDays(DateTime(2026, 10, 25), _monday);

      expect(days.toSet().length, 7);
      expect(days.every((day) => day.hour == 0 && day.minute == 0), isTrue);
      expect(days.last, DateTime(2026, 10, 25));
    });
  });
}

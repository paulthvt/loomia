import 'package:flutter_test/flutter_test.dart';
import 'package:loomia/features/notifications/domain/notification_settings.dart';

void main() {
  test('defaults: off, 19:00, Monday to Friday', () {
    const settings = NotificationSettings(timeZone: 'Europe/Paris');
    expect(settings.enabled, isFalse);
    expect(settings.ritual, isFalse);
    expect(settings.any, isFalse);
    expect((settings.hour, settings.minute), (19, 0));
    expect(settings.days, {1, 2, 3, 4, 5});
  });

  test('a row reads back as it was saved', () {
    const settings = NotificationSettings(
      ritual: true,
      hour: 7,
      minute: 5,
      days: {6, 1, 7},
      timeZone: 'America/New_York',
    );
    final row = settings.toRow();
    expect(row['summary_enabled'], isFalse);
    expect(row['ritual_enabled'], isTrue);
    expect(row['summary_time'], '07:05');
    expect(row['summary_days'], [1, 6, 7]);
    expect(
      NotificationSettings.fromRow({...row, 'summary_time': '07:05:00'}),
      settings,
    );
  });

  test('weeks start where the locale says', () {
    expect(weekdayOrder(0), [7, 1, 2, 3, 4, 5, 6], reason: 'Sunday (en)');
    expect(weekdayOrder(1), [1, 2, 3, 4, 5, 6, 7], reason: 'Monday (fr)');
    expect(weekdayOrder(6), [6, 7, 1, 2, 3, 4, 5], reason: 'Saturday');
  });

  test('a day toggles, and the last one stays', () {
    expect(toggleDay({1, 2}, 3), {1, 2, 3});
    expect(toggleDay({1, 2}, 2), {1});
    expect(toggleDay({1}, 1), {1});
  });
}

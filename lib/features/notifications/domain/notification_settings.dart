/// When the daily summary and the month-end push go out, in [timeZone]'s
/// wall clock (`notification_settings`,
/// docs/superpowers/specs/2026-10-11-notifications-design.md and
/// 2026-10-13-month-end-push-design.md).
class NotificationSettings {
  const NotificationSettings({
    required this.timeZone,
    this.enabled = false,
    this.ritual = false,
    this.hour = 19,
    this.minute = 0,
    this.days = weekdays,
  });

  /// Monday to Friday, ISO 8601: 1 = Monday … 7 = Sunday, as
  /// `DateTime.weekday` and Postgres `isodow`.
  static const weekdays = {1, 2, 3, 4, 5};

  /// The daily summary.
  final bool enabled;

  /// The month-end push (#148), at the same time, on the first of [days] in
  /// the close-and-plan window.
  final bool ritual;

  /// Either push is on: time and days matter, and the phone must allow it.
  bool get any => enabled || ritual;
  final int hour;
  final int minute;

  /// ISO weekdays, never empty.
  final Set<int> days;

  /// IANA name, "Europe/Paris".
  final String timeZone;

  NotificationSettings copyWith({
    bool? enabled,
    bool? ritual,
    int? hour,
    int? minute,
    Set<int>? days,
    String? timeZone,
  }) => NotificationSettings(
    enabled: enabled ?? this.enabled,
    ritual: ritual ?? this.ritual,
    hour: hour ?? this.hour,
    minute: minute ?? this.minute,
    days: days ?? this.days,
    timeZone: timeZone ?? this.timeZone,
  );

  /// From a `notification_settings` row; `summary_time` reads "19:00:00".
  factory NotificationSettings.fromRow(Map<String, dynamic> row) {
    final [hour, minute, ...] = (row['summary_time'] as String).split(':');
    return NotificationSettings(
      enabled: row['summary_enabled'] as bool,
      ritual: row['ritual_enabled'] as bool,
      hour: int.parse(hour),
      minute: int.parse(minute),
      days: {for (final day in row['summary_days'] as List) day as int},
      timeZone: row['time_zone'] as String,
    );
  }

  Map<String, dynamic> toRow() => {
    'summary_enabled': enabled,
    'ritual_enabled': ritual,
    'summary_time':
        '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}',
    'summary_days': (days.toList()..sort()),
    'time_zone': timeZone,
  };

  @override
  bool operator ==(Object other) =>
      other is NotificationSettings &&
      other.enabled == enabled &&
      other.ritual == ritual &&
      other.hour == hour &&
      other.minute == minute &&
      other.timeZone == timeZone &&
      other.days.length == days.length &&
      other.days.containsAll(days);

  @override
  int get hashCode => Object.hash(
    enabled,
    ritual,
    hour,
    minute,
    timeZone,
    Object.hashAllUnordered(days),
  );
}

/// The seven ISO weekdays in display order, from
/// `MaterialLocalizations.firstDayOfWeekIndex` (0 = Sunday).
List<int> weekdayOrder(int firstDayOfWeekIndex) {
  final first = firstDayOfWeekIndex == 0 ? 7 : firstDayOfWeekIndex;
  return [for (var i = 0; i < 7; i++) (first - 1 + i) % 7 + 1];
}

/// [days] with [day] switched; the last selected day stays, so the summary
/// always has a day to go out on.
Set<int> toggleDay(Set<int> days, int day) {
  if (!days.contains(day)) return {...days, day};
  if (days.length == 1) return days;
  return {...days}..remove(day);
}

/// The days a month grid shows for [month]: whole weeks, from the one that
/// holds the 1st to the one that holds the last day, each starting on
/// [firstDayOfWeek] (0 is Sunday, as `MaterialLocalizations.firstDayOfWeekIndex`).
/// Local midnights, built from calendar dates rather than by adding 24 hours,
/// so a DST change neither skips nor repeats a day.
List<DateTime> monthDays(DateTime month, int firstDayOfWeek) {
  final first = DateTime(month.year, month.month);
  // DateTime.weekday is 1 (Monday) to 7 (Sunday); % 7 makes Sunday 0.
  final lead = (first.weekday % 7 - firstDayOfWeek) % 7;
  final last = DateTime(month.year, month.month + 1, 0);
  final weeks = ((lead + last.day) / DateTime.daysPerWeek).ceil();
  return [
    for (var i = 0; i < weeks * DateTime.daysPerWeek; i++)
      DateTime(month.year, month.month, 1 - lead + i),
  ];
}

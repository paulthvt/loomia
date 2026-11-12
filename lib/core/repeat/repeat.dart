/// How often a repeating task or reminder comes back (#376, #486).
enum RepeatUnit { day, week, month, year }

/// A repeat: every [every] [unit]s counted from [from], until [until]
/// (null: never). [scheduledOn] is the day the schedule gave this one; its
/// due day differs from it once postponed. All local midnight.
typedef Repeat = ({
  int every,
  RepeatUnit unit,
  DateTime from,
  DateTime? until,
  DateTime scheduledOn,
});

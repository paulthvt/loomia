/// How often a repeating task comes back (#376).
enum RepeatUnit { day, week, month, year }

/// A task's repeat: every [every] [unit]s counted from [from], until [until]
/// (null: never). [scheduledOn] is the day the schedule gave this task;
/// the task's `dueOn` differs from it once postponed. All local midnight.
typedef TaskRepeat = ({
  int every,
  RepeatUnit unit,
  DateTime from,
  DateTime? until,
  DateTime scheduledOn,
});

/// A task with a due date, open or done.
class Task {
  const Task({
    required this.id,
    required this.title,
    required this.note,
    required this.dueOn,
    required this.doneOn,
    required this.createdAt,
    this.repeat,
    this.dueTime,
    this.alert = true,
  });

  final String id;
  final String title;
  final String? note;

  /// Local midnight.
  final DateTime dueOn;

  /// When marked done; null when open. Local midnight.
  final DateTime? doneOn;

  /// Creation timestamp.
  final DateTime createdAt;

  /// Null when it doesn't repeat. A done task keeps the rule it was ticked
  /// with; only an open one comes back.
  final TaskRepeat? repeat;

  /// The time it is due at, a wall clock in the user's settings zone
  /// (#377); null: any time that day. A push goes at that time.
  final TaskTime? dueTime;

  /// The bell (#389): whether [dueTime] pushes. Unused without a time.
  final bool alert;

  bool get done => doneOn != null;

  /// Open and repeating: ticking it makes the next one.
  bool get repeats => repeat != null && !done;

  String get key => 'task:$id';
}

typedef TaskDraft = ({
  String title,
  String? note,
  DateTime dueOn,
  TaskTime? dueTime,
  bool alert,
  TaskRepeat? repeat,
});

/// A wall-clock time of day, 24 h.
typedef TaskTime = ({int hour, int minute});

/// Open tasks due on or before [today]: oldest `dueOn` first; within a day,
/// those without a time ("any time"), then the timed ones by time (#377);
/// then `createdAt`.
List<Task> todayTasks(List<Task> tasks, DateTime today) =>
    tasks.where((t) => !t.done && !_after(t.dueOn, today)).toList()
      ..sort(_byDayThenTime);

/// Every task due on [day], open first, then as [todayTasks].
List<Task> tasksOn(List<Task> tasks, DateTime day) =>
    tasks.where((t) => _sameDay(t.dueOn, day)).toList()..sort((a, b) {
      if (a.done != b.done) return a.done ? 1 : -1;
      return _byDayThenTime(a, b);
    });

int _byDayThenTime(Task a, Task b) {
  final day = a.dueOn.compareTo(b.dueOn);
  if (day != 0) return day;
  final time = _minute(a.dueTime).compareTo(_minute(b.dueTime));
  return time != 0 ? time : a.createdAt.compareTo(b.createdAt);
}

/// No time sorts before 00:00.
int _minute(TaskTime? time) => time == null ? -1 : time.hour * 60 + time.minute;

/// Put off from [now] by [by], up to the next whole minute: the day and time
/// to save (#377). Past midnight, the next day.
({DateTime day, TaskTime time}) postponed(DateTime now, Duration by) {
  final later = now.add(by);
  final whole = DateTime(
    later.year,
    later.month,
    later.day,
    later.hour,
    later.minute,
  );
  final at = whole == later ? whole : whole.add(const Duration(minutes: 1));
  return (
    day: DateTime(at.year, at.month, at.day),
    time: (hour: at.hour, minute: at.minute),
  );
}

/// An open task whose time has passed or is under 15 minutes away: the
/// sheet offers to put it off.
bool alertNear(Task task, DateTime now) {
  final time = task.dueTime;
  if (task.done || time == null) return false;
  final at = DateTime(
    task.dueOn.year,
    task.dueOn.month,
    task.dueOn.day,
    time.hour,
    time.minute,
  );
  return now.isAfter(at.subtract(const Duration(minutes: 15)));
}

/// Open tasks grouped by due day.
Map<DateTime, int> openTasksPerDay(List<Task> tasks) {
  final counts = <DateTime, int>{};
  for (final task in tasks.where((t) => !t.done)) {
    final day = DateTime(task.dueOn.year, task.dueOn.month, task.dueOn.day);
    counts[day] = (counts[day] ?? 0) + 1;
  }
  return counts;
}

bool _sameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

bool _after(DateTime a, DateTime b) =>
    a.year > b.year ||
    (a.year == b.year && a.month > b.month) ||
    (a.year == b.year && a.month == b.month && a.day > b.day);

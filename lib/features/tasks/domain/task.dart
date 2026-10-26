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

  bool get done => doneOn != null;

  /// Open and repeating: ticking it makes the next one.
  bool get repeats => repeat != null && !done;

  String get key => 'task:$id';
}

typedef TaskDraft = ({
  String title,
  String? note,
  DateTime dueOn,
  TaskRepeat? repeat,
});

/// Open tasks due on or before [today], oldest `dueOn` first, then
/// `createdAt`.
List<Task> todayTasks(List<Task> tasks, DateTime today) {
  final result = tasks.where((t) => !t.done && !_after(t.dueOn, today)).toList()
    ..sort((a, b) {
      final cmp = a.dueOn.compareTo(b.dueOn);
      return cmp != 0 ? cmp : a.createdAt.compareTo(b.createdAt);
    });
  return result;
}

/// Every task due on [day], open first, then creation order.
List<Task> tasksOn(List<Task> tasks, DateTime day) {
  final result = tasks.where((t) => _sameDay(t.dueOn, day)).toList()
    ..sort((a, b) {
      if (a.done != b.done) return a.done ? 1 : -1;
      return a.createdAt.compareTo(b.createdAt);
    });
  return result;
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

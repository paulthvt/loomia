import 'package:intl/intl.dart';
import 'package:loomia/app/theme/app_colors.dart';
import 'package:loomia/core/ui/action_item.dart';
import 'package:loomia/features/calendar/presentation/event_row.dart';
import 'package:loomia/features/tasks/domain/task.dart';
import 'package:loomia/l10n/app_localizations.dart';
import 'package:material_ui/material_ui.dart';

/// A task as a row, with Today's look: its ring ticks it; once done it stays,
/// struck through, and the ring unticks it.
class TaskRow extends StatelessWidget {
  const TaskRow({
    required this.task,
    required this.onOpen,
    required this.onToggle,
    this.busy = false,
    super.key,
  });

  final Task task;
  final VoidCallback onOpen;
  final VoidCallback onToggle;

  /// A write is in flight: the ring takes no second tap.
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return ActionItem(
      name: task.title,
      tag: repeatIcon(context, task),
      reason: task.note,
      icon: Icons.assignment_outlined,
      chip: timeChip(context, task),
      onOpen: onOpen,
      onResolve: onToggle,
      resolved: busy,
      done: task.done,
      maxLines: 2,
      resolveLabel: task.done
          ? l10n.eventStepUntick(task.title)
          : l10n.nextStepMarkDone(task.title),
    );
  }
}

/// A timed task's time, in the row's chip (#377): "14:00", in the locale's
/// format. Null without a time.
Widget? timeChip(BuildContext context, Task task) => switch (task.dueTime) {
  final time? => DateChip(
    timeLabel(context, DateTime(2000, 1, 1, time.hour, time.minute)),
  ),
  null => null,
};

/// After the title of an open repeating task: it comes back once ticked.
/// Null for a plain or done one (a done task keeps its rule unseen).
Widget? repeatIcon(BuildContext context, Task task) {
  final repeat = task.repeat;
  if (repeat == null || task.done) return null;
  return Icon(
    Icons.repeat_rounded,
    size: Theme.of(context).textTheme.titleMedium?.fontSize,
    color: LoomiaColors.of(context).textMuted,
    semanticLabel: repeatLine(AppLocalizations.of(context), repeat),
  );
}

/// What [repeat] means in words: "Every month on the 3rd", "Every 2 weeks
/// on Thursday", with ", until Jun 3, 2027" when it ends. Under the form's
/// repeat fields and as the row's repeat icon label.
String repeatLine(AppLocalizations l10n, TaskRepeat repeat) {
  final n = repeat.every;
  final from = repeat.from;
  final line = switch (repeat.unit) {
    RepeatUnit.day => l10n.taskRepeatLineDay(n),
    RepeatUnit.week => l10n.taskRepeatLineWeek(
      n,
      DateFormat.EEEE(l10n.localeName).format(from),
    ),
    RepeatUnit.month => l10n.taskRepeatLineMonth(
      n,
      l10n.taskRepeatDayOfMonth('${from.day}'),
    ),
    RepeatUnit.year => l10n.taskRepeatLineYear(
      n,
      DateFormat.MMMMd(l10n.localeName).format(from),
    ),
  };
  final until = repeat.until;
  return until == null
      ? line
      : l10n.taskRepeatUntil(
          line,
          DateFormat.yMMMd(l10n.localeName).format(until),
        );
}

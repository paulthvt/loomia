import 'package:loomia/core/repeat/repeat_fields.dart';
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
Widget? repeatIcon(BuildContext context, Task task) =>
    task.done ? null : repeatBadge(context, task.repeat);

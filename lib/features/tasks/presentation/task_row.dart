import 'package:loomia/core/ui/action_item.dart';
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
      reason: task.note,
      icon: Icons.assignment_outlined,
      onOpen: onOpen,
      onResolve: onToggle,
      resolved: busy,
      done: task.done,
      resolveLabel: task.done
          ? l10n.eventStepUntick(task.title)
          : l10n.nextStepMarkDone(task.title),
    );
  }
}

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:loomia/app/router/back.dart';
import 'package:loomia/app/router/routes.dart';
import 'package:loomia/app/theme/app_spacing.dart';
import 'package:loomia/core/layout/breakpoints.dart';
import 'package:loomia/core/ui/empty_state.dart';
import 'package:loomia/core/ui/form_error.dart';
import 'package:loomia/core/ui/load_failed.dart';
import 'package:loomia/core/ui/loomia_dialog.dart';
import 'package:loomia/core/ui/pick_day.dart';
import 'package:loomia/core/ui/tick_ring.dart';
import 'package:loomia/features/auth/data/auth_repository.dart';
import 'package:loomia/features/calendar/presentation/calendar_controller.dart';
import 'package:loomia/features/calendar/presentation/event_row.dart'
    show timeLabel;
import 'package:loomia/features/calendar/presentation/scope_dialog.dart';
import 'package:loomia/features/contacts/domain/people_failure.dart';
import 'package:loomia/features/contacts/presentation/people_copy.dart';
import 'package:loomia/features/tasks/domain/task.dart';
import 'package:loomia/features/tasks/presentation/task_row.dart';
import 'package:loomia/features/tasks/presentation/task_sheet.dart';
import 'package:loomia/features/tasks/presentation/tasks_controller.dart';
import 'package:loomia/features/tasks/presentation/toggle_task.dart';
import 'package:loomia/l10n/app_localizations.dart';
import 'package:material_ui/material_ui.dart';

/// One task on mobile and tablet (#390): a screen of its own above the one
/// it was opened from, as an event's.
class TaskPage extends StatelessWidget {
  const TaskPage({required this.id, super.key});

  final String id;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: BackButton(onPressed: () => backOr(context, Routes.calendar)),
      ),
      body: SafeArea(top: false, child: TaskPane(id: id)),
    );
  }
}

/// A task found in the loaded tasks (no second fetch), wired to ticking,
/// postponing, editing and deleting. Shared by [TaskPage] and the Calendar's
/// desktop pane.
class TaskPane extends ConsumerStatefulWidget {
  const TaskPane({required this.id, super.key});

  final String id;

  @override
  ConsumerState<TaskPane> createState() => _TaskPaneState();
}

class _TaskPaneState extends ConsumerState<TaskPane> {
  /// A write in flight: the ring and the postpone buttons take no tap.
  var _busy = false;
  PeopleFailure? _failure;

  TasksController get _tasks =>
      ref.read(tasksProvider(ref.read(accountProvider)?.email).notifier);

  Future<void> _run(Future<void> Function() write) async {
    setState(() {
      _busy = true;
      _failure = null;
    });
    try {
      await write();
    } on PeopleFailure catch (failure) {
      if (mounted) setState(() => _failure = failure);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// In 15 min, In 1 hour, from now. The page stays; a repeating task is put
  /// off alone, its schedule stays.
  Future<void> _postpone(Task task, Duration by) {
    final later = postponed(DateTime.now(), by);
    return _run(
      () => _tasks.save(task.id, (
        title: task.title,
        note: task.note,
        dueOn: later.day,
        dueTime: later.time,
        alert: task.alert,
        repeat: task.repeat,
      )),
    );
  }

  /// The ring: Undo on desktop too, since the pane has no barrier to eat it.
  Future<void> _tick(Task task) async {
    setState(() => _busy = true);
    try {
      await toggleTask(context, ref, task);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// The form over the page; the Calendar then shows the day it is due.
  Future<void> _edit(Task task) async {
    final saved = await showTask(context, day: task.dueOn, editing: task);
    if (saved != null && mounted) {
      ref.read(calendarSelectionProvider.notifier).select(saved.dueOn);
    }
  }

  /// Asks (this or following, for a repeating one), leaves the page, then
  /// deletes, as an event's page does.
  Future<void> _delete(Task task) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final tasks = _tasks;
    bool? following;
    if (task.repeats) {
      final scope = await pickScope(context, delete: true, task: true);
      if (scope == null || !mounted) return;
      following = scope == EventScope.following;
    } else {
      final confirmed = await confirmDestructive(
        context,
        title: l10n.taskDeleteConfirm,
        action: l10n.historyDeleteConfirm,
      );
      if (!confirmed || !mounted) return;
    }
    if (context.screenSize.isDesktop) {
      context.go(Routes.calendar);
    } else {
      final leaving = ModalRoute.of(context);
      backOr(context, Routes.calendar);
      await leaving?.completed;
    }
    try {
      await (following == null
          ? tasks.remove(task.id)
          : tasks.removeRepeating(task, on: today(), following: following));
    } on PeopleFailure catch (failure) {
      messenger.showSnackBar(
        SnackBar(content: Text(peopleFailureCopy(l10n, failure))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final provider = tasksProvider(ref.watch(accountProvider)?.email);
    final tasks = ref.watch(provider);
    final list = tasks.value;
    if (list == null) {
      return tasks.hasError
          ? LoadFailed(
              offline: tasks.error == PeopleFailure.network,
              title: l10n.todayTasksLoadFailed,
              onRetry: () => ref.invalidate(provider),
            )
          : const Center(child: CircularProgressIndicator());
    }
    final task = list.where((task) => task.id == widget.id).firstOrNull;
    if (task == null) {
      return Center(
        child: EmptyState(
          icon: Icons.task_alt_rounded,
          title: l10n.taskNotFound,
          body: l10n.eventNotFoundBody,
        ),
      );
    }
    return TaskView(
      task: task,
      now: DateTime.now(),
      busy: _busy,
      failure: _failure,
      onTick: () => unawaited(_tick(task)),
      onEdit: () => unawaited(_edit(task)),
      onDelete: () => unawaited(_delete(task)),
      onPostpone: (by) => unawaited(_postpone(task, by)),
    );
  }
}

/// The task as a function of its inputs, for previews and tests: the title
/// with Edit and Delete, postpone when its time is near or past, then the
/// ring and the day, the time and its bell, the repeat and the note.
class TaskView extends StatelessWidget {
  const TaskView({
    required this.task,
    required this.now,
    required this.busy,
    required this.onTick,
    required this.onEdit,
    required this.onDelete,
    required this.onPostpone,
    this.failure,
    super.key,
  });

  final Task task;
  final DateTime now;

  /// A write in flight: the ring and postpone take no tap.
  final bool busy;
  final PeopleFailure? failure;
  final VoidCallback onTick;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final void Function(Duration by) onPostpone;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    final failure = this.failure;
    final time = task.dueTime;
    final repeat = task.repeat;
    final note = task.note;

    Widget line(Widget lead, String text, {Widget? trailing}) => Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Row(
        spacing: AppSpacing.sm,
        children: [
          lead,
          Expanded(
            child: Text(
              text,
              style: theme.textTheme.bodyLarge?.copyWith(color: muted),
            ),
          ),
          ?trailing,
        ],
      ),
    );

    return ListView(
      padding: EdgeInsets.all(
        context.screenSize.isDesktop ? AppSpacing.lg : AppSpacing.md,
      ),
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Text(task.title, style: theme.textTheme.headlineSmall),
            ),
            IconButton(
              onPressed: onEdit,
              tooltip: l10n.taskEdit,
              icon: const Icon(Icons.edit_outlined),
            ),
            IconButton(
              onPressed: onDelete,
              tooltip: l10n.taskDelete,
              icon: const Icon(Icons.delete_outline_rounded),
            ),
          ],
        ),
        if (failure != null) ...[
          const SizedBox(height: AppSpacing.sm),
          FormError(peopleFailureCopy(l10n, failure)),
        ],
        if (time != null && !task.done && alertNear(task, now)) ...[
          const SizedBox(height: AppSpacing.ms),
          _Postpone(task: task, now: now, busy: busy, onPostpone: onPostpone),
        ],
        const SizedBox(height: AppSpacing.ms),
        line(
          TickRing(
            selected: task.done,
            tooltip: task.done
                ? l10n.eventStepUntick(task.title)
                : l10n.nextStepMarkDone(task.title),
            onPressed: busy ? null : onTick,
          ),
          DateFormat.MMMMEEEEd(l10n.localeName).format(task.dueOn),
        ),
        if (time != null)
          line(
            Icon(Icons.schedule_rounded, color: muted),
            timeLabel(context, DateTime(2000, 1, 1, time.hour, time.minute)),
            trailing: Icon(
              task.alert
                  ? Icons.notifications_active_rounded
                  : Icons.notifications_off_outlined,
              color: task.alert ? theme.colorScheme.primary : muted,
              semanticLabel: task.alert
                  ? l10n.taskAlertIsOn
                  : l10n.taskAlertIsOff,
            ),
          ),
        if (repeat != null && !task.done)
          line(
            Icon(Icons.repeat_rounded, color: muted),
            repeatLine(l10n, repeat),
          ),
        if (note != null) line(Icon(Icons.notes_rounded, color: muted), note),
      ],
    );
  }
}

/// "It was due at 14:00. Put it off:" with In 15 min and In 1 hour (#377),
/// moved here from the form.
class _Postpone extends StatelessWidget {
  const _Postpone({
    required this.task,
    required this.now,
    required this.busy,
    required this.onPostpone,
  });

  final Task task;
  final DateTime now;
  final bool busy;
  final void Function(Duration by) onPostpone;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final at = task.dueTime!;
    final time = timeLabel(context, DateTime(2000, 1, 1, at.hour, at.minute));
    final due = DateTime(
      task.dueOn.year,
      task.dueOn.month,
      task.dueOn.day,
      at.hour,
      at.minute,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: AppSpacing.sm,
      children: [
        Text(
          now.isBefore(due)
              ? l10n.taskPostponeNear(time)
              : l10n.taskPostponeWas(time),
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        // Two lines when one doesn't hold both (a phone, French).
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: [
            FilledButton.tonal(
              onPressed: busy
                  ? null
                  : () => onPostpone(const Duration(minutes: 15)),
              child: Text(l10n.taskPostpone15),
            ),
            FilledButton.tonal(
              onPressed: busy
                  ? null
                  : () => onPostpone(const Duration(hours: 1)),
              child: Text(l10n.taskPostponeHour),
            ),
          ],
        ),
      ],
    );
  }
}

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:loomia/app/router/back.dart';
import 'package:loomia/app/router/routes.dart';
import 'package:loomia/app/theme/app_colors.dart';
import 'package:loomia/app/theme/app_spacing.dart';
import 'package:loomia/app/theme/app_theme.dart';
import 'package:loomia/core/layout/breakpoints.dart';
import 'package:loomia/core/repeat/repeat_fields.dart';
import 'package:loomia/core/ui/empty_state.dart';
import 'package:loomia/core/ui/form_error.dart';
import 'package:loomia/core/ui/hero_panel.dart';
import 'package:loomia/core/ui/load_failed.dart';
import 'package:loomia/core/ui/loomia_dialog.dart';
import 'package:loomia/core/ui/pick_day.dart';
import 'package:loomia/core/ui/scope_dialog.dart';
import 'package:loomia/features/auth/data/auth_repository.dart';
import 'package:loomia/features/calendar/presentation/calendar_controller.dart';
import 'package:loomia/features/calendar/presentation/event_row.dart'
    show timeLabel;
import 'package:loomia/features/contacts/domain/people_failure.dart';
import 'package:loomia/features/contacts/presentation/people_copy.dart';
import 'package:loomia/features/tasks/domain/task.dart';
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
    // The hero holds back and runs under the status bar.
    return Scaffold(
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
      final scope = await pickScope(
        context,
        delete: true,
        wording: ScopeWording.task,
      );
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

/// The task as a function of its inputs, for previews and tests: a hero
/// with Edit and Delete, the title, the day, the time and its bell, the
/// repeat; below, postpone when its time is near or past, the note and Mark
/// as done.
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
    final failure = this.failure;
    final time = task.dueTime;
    final repeat = task.repeat;
    final note = task.note;

    final colors = LoomiaColors.of(context);
    final desktop = context.screenSize.isDesktop;
    final hero = DetailHero(
      band: desktop,
      onBack: desktop ? null : () => backOr(context, Routes.calendar),
      title: task.title,
      editTooltip: l10n.taskEdit,
      onEdit: onEdit,
      deleteTooltip: l10n.taskDelete,
      onDelete: onDelete,
      lines: [
        HeroLine(
          icon: const Icon(Icons.calendar_today_rounded),
          text: DateFormat.MMMMEEEEd(l10n.localeName).format(task.dueOn),
        ),
        if (time != null)
          HeroLine(
            icon: const Icon(Icons.schedule_rounded),
            text: timeLabel(
              context,
              DateTime(2000, 1, 1, time.hour, time.minute),
            ),
            trailing: task.alert
                ? HeroBadge(
                    icon: Icon(
                      Icons.notifications_rounded,
                      semanticLabel: l10n.taskAlertIsOn,
                    ),
                    // ponytail: no "Bell on" label yet, the ARB is Tasks
                    // 4 and 6's; the icon speaks the bell. Add the label
                    // with its copy.
                  )
                : Icon(
                    Icons.notifications_off_outlined,
                    color: colors.onHeroQuiet,
                    semanticLabel: l10n.taskAlertIsOff,
                  ),
          ),
        if (repeat != null && !task.done)
          HeroLine(
            icon: const Icon(Icons.repeat_rounded),
            text: repeatRuleLine(l10n, repeat),
          ),
      ],
    );

    return ListView(
      padding: desktop
          ? const EdgeInsets.all(AppSpacing.lg)
          : const EdgeInsets.only(bottom: AppSpacing.lg),
      children: [
        hero,
        Padding(
          padding: EdgeInsets.fromLTRB(
            desktop ? 0 : AppSpacing.md,
            AppSpacing.md,
            desktop ? 0 : AppSpacing.md,
            0,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: AppSpacing.md,
            children: [
              if (failure != null) FormError(peopleFailureCopy(l10n, failure)),
              if (time != null && !task.done && alertNear(task, now))
                _Postpone(
                  task: task,
                  now: now,
                  busy: busy,
                  onPostpone: onPostpone,
                ),
              if (note != null)
                Container(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: AppTheme.card(context),
                  child: Text(
                    note,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                ),
              if (task.done)
                FilledButton.tonalIcon(
                  style: AppTheme.tonal(context),
                  onPressed: busy ? null : onTick,
                  icon: const Icon(Icons.undo_rounded),
                  label: Text(l10n.eventStepUntick(task.title)),
                )
              else
                FilledButton.icon(
                  onPressed: busy ? null : onTick,
                  icon: const Icon(Icons.check_rounded),
                  label: Text(l10n.actionMarkAsDone),
                ),
            ],
          ),
        ),
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

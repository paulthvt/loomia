import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:loomia/app/router/routes.dart';
import 'package:loomia/app/theme/app_colors.dart';
import 'package:loomia/app/theme/app_spacing.dart';
import 'package:loomia/core/repeat/repeat_fields.dart';
import 'package:loomia/core/ui/form_error.dart';
import 'package:loomia/core/ui/labeled_field.dart';
import 'package:loomia/core/ui/loomia_dialog.dart';
import 'package:loomia/core/ui/pick_day.dart';
import 'package:loomia/core/ui/scope_dialog.dart';
import 'package:loomia/features/auth/data/auth_repository.dart';
import 'package:loomia/features/contacts/domain/people_failure.dart';
import 'package:loomia/features/contacts/presentation/people_copy.dart';
import 'package:loomia/features/contacts/presentation/reminder_sheet.dart';
import 'package:loomia/features/notifications/data/push.dart';
import 'package:loomia/features/notifications/presentation/notifications_controller.dart';
import 'package:loomia/features/tasks/domain/task.dart';
import 'package:loomia/features/tasks/presentation/tasks_controller.dart';
import 'package:loomia/l10n/app_localizations.dart';
import 'package:material_ui/material_ui.dart';

/// Create or edit a task: a sheet on mobile, a dialog elsewhere. Closes once
/// saved or deleted. Returns the saved task; null when cancelled or deleted.
Future<Task?> showTask(
  BuildContext context, {
  required DateTime day,
  Task? editing,
}) => LoomiaDialog.show<Task>(
  context,
  (_) => _TaskForm(day: day, editing: editing),
);

class _TaskForm extends ConsumerStatefulWidget {
  const _TaskForm({required this.day, this.editing});

  /// The day this task is being created for; ignored when editing.
  final DateTime day;

  /// Null when adding.
  final Task? editing;

  @override
  ConsumerState<_TaskForm> createState() => _TaskFormState();
}

class _TaskFormState extends ConsumerState<_TaskForm> {
  final _form = GlobalKey<FormState>();
  late final _title = TextEditingController(text: widget.editing?.title);
  late final _note = TextEditingController(text: widget.editing?.note);
  late DateTime _day = widget.editing?.dueOn ?? widget.day;
  bool _saving = false;
  PeopleFailure? _failure;

  // A time (#377): its push needs this phone's permission. Null allowed:
  // not asked yet, or no push here (the web).
  late TaskTime? _time = widget.editing?.dueTime;
  bool? _allowed;

  // The bell (#389): whether the time pushes. Kept when the time changes.
  late bool _alert = widget.editing?.alert ?? true;

  @override
  void initState() {
    super.initState();
    if (_time != null) unawaited(_checkAllowed());
  }

  Future<void> _checkAllowed() async {
    final allowed = await ref.read(pushProvider).allowed();
    if (mounted) setState(() => _allowed = allowed);
  }

  Future<void> _pickTime() async {
    final now = DateTime.now();
    final initial = switch (_time) {
      final time? => TimeOfDay(hour: time.hour, minute: time.minute),
      // The next full hour.
      null => TimeOfDay(hour: (now.hour + 1) % 24, minute: 0),
    };
    final picked = await pickTime(context, initial: initial);
    if (picked == null || !mounted) return;
    setState(() {
      // A time added (not changed) starts with the bell on.
      if (_time == null) _alert = true;
      _time = (hour: picked.hour, minute: picked.minute);
    });
    unawaited(_checkAllowed());
  }

  /// The first time on a task: the push needs a zone and the phone's yes.
  Future<void> _armPushes() async {
    final owner = ref.read(accountProvider)?.email;
    final zone = await ref.read(deviceTimeZoneProvider.future) ?? 'UTC';
    await ref
        .read(notificationSettingsProvider(owner).notifier)
        .ensureFor(zone);
  }

  // The repeat fields (#376). A done task keeps its rule unseen: no fields.
  late final Repeat? _old = widget.editing?.repeat;
  late bool _repeatOn = _old != null;
  late final _every = TextEditingController(text: '${_old?.every ?? 1}');
  late RepeatUnit _unit = _old?.unit ?? RepeatUnit.week;
  late DateTime? _until = _old?.until;

  bool get _showsRepeat => !(widget.editing?.done ?? false);

  @override
  void dispose() {
    _title.dispose();
    _note.dispose();
    _every.dispose();
    super.dispose();
  }

  int get _everyValue => int.tryParse(_every.text) ?? 1;

  /// The rule as the fields read, counted from [day].
  Repeat _ruleFrom(DateTime day) => (
    every: _everyValue,
    unit: _unit,
    from: day,
    until: _until,
    scheduledOn: day,
  );

  /// What Save writes as the repeat (spec: Saving an edit). A done task
  /// keeps its rule unseen. Null result: cancelled.
  Future<(Repeat?,)?> _repeatToSave() async {
    final editing = widget.editing;
    if (editing != null && editing.done) return (_old,);
    return repeatToSave(
      context,
      on: _repeatOn,
      old: _old,
      oldDay: editing?.dueOn,
      day: _day,
      ruleFrom: _ruleFrom,
      wording: ScopeWording.task,
    );
  }

  Future<void> _write(
    Future<Task?> Function(TasksController tasks) write,
  ) async {
    final tasks = ref.read(
      tasksProvider(ref.read(accountProvider)?.email).notifier,
    );
    setState(() {
      _saving = true;
      _failure = null;
    });
    try {
      final saved = await write(tasks);
      if (mounted) Navigator.pop(context, saved);
    } on PeopleFailure catch (failure) {
      if (mounted) {
        setState(() {
          _saving = false;
          _failure = failure;
        });
      }
    }
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    final editing = widget.editing;
    final title = _title.text.trim();
    final noteText = _note.text.trim();
    final note = noteText.isEmpty ? null : noteText;
    final repeat = await _repeatToSave();
    if (repeat == null || !mounted) return;
    final draft = (
      title: title,
      note: note,
      dueOn: _day,
      dueTime: _time,
      alert: _alert,
      repeat: repeat.$1,
    );
    // Starts notifying (a time added, or the bell back on): the push needs
    // the settings row and the phone's yes.
    final notifies = _time != null && _alert;
    final notified = editing?.dueTime != null && (editing?.alert ?? false);
    final arms = notifies && !notified;
    await _write((tasks) async {
      if (arms) await _armPushes();
      final saved = await (editing == null
          ? tasks.add(draft)
          : tasks.save(editing.id, draft));
      // The OS prompt, once the task is safe; no answer is a failure.
      if (arms && _allowed != true) await ref.read(pushProvider).ask();
      return saved;
    });
  }

  Widget _repeatFields() => RepeatFields(
    on: _repeatOn,
    onOn: _saving ? null : (on) => setState(() => _repeatOn = on),
    every: _every,
    onEvery: () => setState(() {}),
    unit: _unit,
    onUnit: (unit) => setState(() => _unit = unit),
    until: _until,
    onUntil: (until) => setState(() => _until = until),
    day: _day,
    lineFrom: _old?.from ?? _day,
  );

  /// Add a time, or the time with ✕ and the bell (#377, #389). Under it, the
  /// line saying why it won't push: task pushes off in Settings, else this
  /// phone refusing them.
  Widget _timeField(AppLocalizations l10n) {
    final time = _time;
    final theme = Theme.of(context);
    // Loading, or no settings row yet: on, the column's default.
    final tasksOff =
        ref
            .watch(
              notificationSettingsProvider(ref.watch(accountProvider)?.email),
            )
            .value
            ?.tasks ==
        false;
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: LoomiaColors.of(context).textMuted,
    );
    void openSettings() {
      final router = GoRouter.of(context);
      Navigator.pop(context);
      router.push(Routes.settingsNotifications);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: AppSpacing.xs,
      children: [
        if (time == null)
          ActionChip(
            avatar: const Icon(Icons.schedule_rounded),
            label: Text(l10n.taskAddTime),
            onPressed: _saving ? null : () => unawaited(_pickTime()),
          )
        else
          Row(
            mainAxisSize: MainAxisSize.min,
            spacing: AppSpacing.xs,
            children: [
              InputChip(
                avatar: const Icon(Icons.schedule_rounded),
                label: Text(_formatTime(time)),
                onPressed: _saving ? null : () => unawaited(_pickTime()),
                onDeleted: _saving ? null : () => setState(() => _time = null),
                deleteButtonTooltipMessage: l10n.taskRemoveTime,
              ),
              IconButton(
                isSelected: _alert,
                icon: const Icon(Icons.notifications_off_outlined),
                selectedIcon: const Icon(Icons.notifications_active_rounded),
                tooltip: _alert ? l10n.taskAlertOn : l10n.taskAlertOff,
                onPressed: tasksOff || _saving
                    ? null
                    : () => setState(() => _alert = !_alert),
              ),
            ],
          ),
        if (time != null && tasksOff)
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(l10n.taskAlertsOff, style: muted),
              TextButton(
                onPressed: openSettings,
                child: Text(l10n.taskAlertsTurnOn),
              ),
            ],
          )
        else if (time != null && _allowed == false)
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(l10n.taskNotificationsOff, style: muted),
              TextButton(
                onPressed: openSettings,
                child: Text(l10n.taskNotificationsSettings),
              ),
            ],
          ),
      ],
    );
  }

  /// "It was due at 14:00", or "Due at 14:00" when it's near, then In 15 min
  /// and In 1 hour.
  String _formatTime(TaskTime time) =>
      MaterialLocalizations.of(context).formatTimeOfDay(
        TimeOfDay(hour: time.hour, minute: time.minute),
        alwaysUse24HourFormat: MediaQuery.alwaysUse24HourFormatOf(context),
      );

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final material = MaterialLocalizations.of(context);
    final editing = widget.editing;
    final failure = _failure;

    return Form(
      key: _form,
      child: LoomiaDialog(
        title: editing == null ? l10n.taskNewTitle : l10n.taskEditTitle,
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(material.cancelButtonLabel),
          ),
          FilledButton(
            onPressed: _saving ? null : () => unawaited(_save()),
            child: _saving
                ? const SizedBox.square(
                    dimension: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(material.saveButtonLabel),
          ),
        ],
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: AppSpacing.ms,
          children: [
            if (failure != null) FormError(peopleFailureCopy(l10n, failure)),
            LabeledField(
              label: l10n.taskTitle,
              child: TextFormField(
                controller: _title,
                autofocus: editing == null,
                textCapitalization: TextCapitalization.sentences,
                validator: (value) => (value ?? '').trim().isEmpty
                    ? l10n.taskTitleRequired
                    : null,
              ),
            ),
            ReminderDayField(
              label: l10n.logWhen,
              value: _day,
              onChanged: (day) => setState(() {
                _day = day;
                // An end before the task's day ends nothing: drop it.
                if (_until case final until? when until.isBefore(day)) {
                  _until = null;
                }
              }),
            ),
            _timeField(l10n),
            if (_showsRepeat) _repeatFields(),
            LabeledField(
              label: l10n.taskNote,
              child: TextFormField(
                controller: _note,
                minLines: 2,
                maxLines: 6,
                textCapitalization: TextCapitalization.sentences,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

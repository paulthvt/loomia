import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:loomia/app/theme/app_colors.dart';
import 'package:loomia/app/theme/app_spacing.dart';
import 'package:loomia/core/ui/form_error.dart';
import 'package:loomia/core/ui/labeled_field.dart';
import 'package:loomia/core/ui/loomia_dialog.dart';
import 'package:loomia/core/ui/pick_day.dart';
import 'package:loomia/features/auth/data/auth_repository.dart';
import 'package:loomia/features/calendar/presentation/scope_dialog.dart';
import 'package:loomia/features/contacts/domain/people_failure.dart';
import 'package:loomia/features/contacts/presentation/people_copy.dart';
import 'package:loomia/features/contacts/presentation/reminder_sheet.dart';
import 'package:loomia/features/tasks/domain/task.dart';
import 'package:loomia/features/tasks/presentation/task_row.dart';
import 'package:loomia/features/tasks/presentation/tasks_controller.dart';
import 'package:loomia/features/workflows/domain/progress.dart';
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

  // The repeat fields (#376). A done task keeps its rule unseen: no fields.
  late final TaskRepeat? _old = widget.editing?.repeat;
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
  TaskRepeat _ruleFrom(DateTime day) => (
    every: _everyValue,
    unit: _unit,
    from: day,
    until: _until,
    scheduledOn: day,
  );

  /// What Save writes as the repeat, after the scope dialog when the day of
  /// a repeating task moved (spec: Saving an edit). Null result: cancelled.
  Future<(TaskRepeat?,)?> _repeatToSave() async {
    final editing = widget.editing;
    if (editing != null && editing.done) return (_old,);
    if (!_repeatOn) return (null,);
    final old = _old;
    if (editing == null || old == null) return (_ruleFrom(_day),);
    final ruleChanged =
        old.every != _everyValue || old.unit != _unit || old.until != _until;
    final dayChanged = _day != editing.dueOn;
    if (!dayChanged) return (ruleChanged ? _ruleFrom(_day) : old,);
    final scope = await pickScope(
      context,
      ruleChanged: ruleChanged,
      task: true,
    );
    if (scope == null) return null;
    // This task: postponed, the schedule stays.
    return (scope == EventScope.one ? old : _ruleFrom(_day),);
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
    final draft = (title: title, note: note, dueOn: _day, repeat: repeat.$1);
    await _write(
      (tasks) =>
          editing == null ? tasks.add(draft) : tasks.save(editing.id, draft),
    );
  }

  Future<void> _delete() async {
    final editing = widget.editing;
    if (editing == null) return;
    final l10n = AppLocalizations.of(context);
    if (editing.repeats) {
      final scope = await pickScope(context, delete: true, task: true);
      if (scope == null) return;
      await _write((tasks) async {
        await tasks.removeRepeating(
          editing,
          on: today(),
          following: scope == EventScope.following,
        );
        return null;
      });
      return;
    }
    final confirmed = await confirmDestructive(
      context,
      title: l10n.taskDeleteConfirm,
      action: l10n.historyDeleteConfirm,
    );
    if (confirmed) {
      await _write((tasks) async {
        await tasks.remove(editing.id);
        return null;
      });
    }
  }

  List<Widget> _repeatFields(AppLocalizations l10n) {
    final count = _everyValue;
    return [
      // The app's one switch style, as in the log sheet.
      SwitchListTile(
        value: _repeatOn,
        title: Text(l10n.taskRepeat),
        contentPadding: EdgeInsets.zero,
        onChanged: _saving ? null : (on) => setState(() => _repeatOn = on),
      ),
      if (_repeatOn) ...[
        LabeledField(
          label: l10n.taskRepeatsEvery,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: AppSpacing.sm,
            children: [
              Expanded(
                child: TextFormField(
                  controller: _every,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  onChanged: (_) => setState(() {}),
                  validator: (value) => switch (int.tryParse(value ?? '')) {
                    final n? when n >= 1 && n <= 99 => null,
                    _ => l10n.taskRepeatEveryInvalid,
                  },
                ),
              ),
              Expanded(
                flex: 2,
                child: DropdownButtonFormField<RepeatUnit>(
                  initialValue: _unit,
                  // The menu lists the units as words, the field reads them
                  // after the number: "3 months".
                  items: [
                    for (final unit in RepeatUnit.values)
                      DropdownMenuItem(
                        value: unit,
                        child: Text(_unitLabel(l10n, unit, 1)),
                      ),
                  ],
                  selectedItemBuilder: (context) => [
                    for (final unit in RepeatUnit.values)
                      Text(_unitLabel(l10n, unit, count)),
                  ],
                  onChanged: (unit) => setState(() => _unit = unit ?? _unit),
                ),
              ),
            ],
          ),
        ),
        Text(
          repeatLine(l10n, _ruleFrom(_old?.from ?? _day)),
          style: Theme.of(context).textTheme.bodyMedium
              ?.copyWith(color: LoomiaColors.of(context).textMuted),
        ),
        LabeledField(
          label: l10n.taskRepeatEnds,
          child: RadioGroup<bool>(
            groupValue: _until != null,
            onChanged: (ends) async {
              if (ends ?? false) {
                await _pickUntil();
              } else {
                setState(() => _until = null);
              }
            },
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                RadioListTile<bool>(
                  value: false,
                  contentPadding: EdgeInsets.zero,
                  title: Text(l10n.taskRepeatNever),
                ),
                RadioListTile<bool>(
                  value: true,
                  contentPadding: EdgeInsets.zero,
                  title: Row(
                    spacing: AppSpacing.sm,
                    children: [
                      Text(l10n.taskRepeatOn),
                      Flexible(
                        child: OutlinedButton(
                          onPressed: _until == null
                              ? null
                              : () => unawaited(_pickUntil()),
                          child: Text(switch (_until) {
                            final until? => DateFormat.yMMMd(
                              l10n.localeName,
                            ).format(until),
                            null => l10n.taskRepeatPickDay,
                          }, overflow: TextOverflow.ellipsis),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    ];
  }

  String _unitLabel(AppLocalizations l10n, RepeatUnit unit, int count) =>
      switch (unit) {
        RepeatUnit.day => l10n.taskRepeatUnitDay(count),
        RepeatUnit.week => l10n.taskRepeatUnitWeek(count),
        RepeatUnit.month => l10n.taskRepeatUnitMonth(count),
        RepeatUnit.year => l10n.taskRepeatUnitYear(count),
      };

  /// Ends On: picks a day not before the task's. Cancelled leaves it as is.
  Future<void> _pickUntil() async {
    final day = await pickDay(
      context,
      initial: _until ?? addDays(_day, 30),
      first: _day,
      last: addDays(_day, 365 * 10),
    );
    if (day != null && mounted) setState(() => _until = day);
  }

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
          if (editing != null)
            TextButton(
              onPressed: _saving ? null : () => unawaited(_delete()),
              child: Text(l10n.historyDeleteConfirm),
            ),
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
            if (_showsRepeat) ..._repeatFields(l10n),
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

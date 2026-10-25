import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loomia/app/theme/app_spacing.dart';
import 'package:loomia/core/ui/form_error.dart';
import 'package:loomia/core/ui/labeled_field.dart';
import 'package:loomia/core/ui/loomia_dialog.dart';
import 'package:loomia/features/auth/data/auth_repository.dart';
import 'package:loomia/features/contacts/domain/people_failure.dart';
import 'package:loomia/features/contacts/presentation/people_copy.dart';
import 'package:loomia/features/contacts/presentation/reminder_sheet.dart';
import 'package:loomia/features/tasks/domain/task.dart';
import 'package:loomia/features/tasks/presentation/tasks_controller.dart';
import 'package:loomia/l10n/app_localizations.dart';
import 'package:material_ui/material_ui.dart';

/// Create or edit a task: a sheet on mobile, a dialog elsewhere. Closes once
/// saved or deleted.
Future<void> showTask(
  BuildContext context, {
  required DateTime day,
  Task? editing,
}) => LoomiaDialog.show<void>(
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

  @override
  void dispose() {
    _title.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _write(
    Future<void> Function(TasksController tasks) write,
  ) async {
    final tasks = ref.read(
      tasksProvider(ref.read(accountProvider)?.email).notifier,
    );
    setState(() {
      _saving = true;
      _failure = null;
    });
    try {
      await write(tasks);
      if (mounted) Navigator.pop(context);
    } on PeopleFailure catch (failure) {
      if (mounted) {
        setState(() {
          _saving = false;
          _failure = failure;
        });
      }
    }
  }

  void _save() {
    if (!_form.currentState!.validate()) return;
    final editing = widget.editing;
    final title = _title.text.trim();
    final noteText = _note.text.trim();
    final note = noteText.isEmpty ? null : noteText;
    _write(
      (tasks) => editing == null
          ? tasks.add((title: title, note: note, dueOn: _day))
          : tasks.save(editing.id, (title: title, note: note, dueOn: _day)),
    );
  }

  Future<void> _delete() async {
    final editing = widget.editing;
    if (editing == null) return;
    final l10n = AppLocalizations.of(context);
    final confirmed = await confirmDestructive(
      context,
      title: l10n.taskDeleteConfirm,
      action: l10n.historyDeleteConfirm,
    );
    if (confirmed) {
      await _write((tasks) => tasks.remove(editing.id));
    }
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
            onPressed: _saving ? null : _save,
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
              onChanged: (day) => setState(() => _day = day),
            ),
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

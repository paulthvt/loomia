import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:loomia/app/theme/app_colors.dart';
import 'package:loomia/app/theme/app_spacing.dart';
import 'package:loomia/core/repeat/repeat.dart';
import 'package:loomia/core/repeat/repeat_fields.dart';
import 'package:loomia/core/ui/form_error.dart';
import 'package:loomia/core/ui/labeled_field.dart';
import 'package:loomia/core/ui/loomia_dialog.dart';
import 'package:loomia/core/ui/pick_day.dart';
import 'package:loomia/core/ui/scope_dialog.dart';
import 'package:loomia/features/auth/data/auth_repository.dart';
import 'package:loomia/features/contacts/domain/people_failure.dart';
import 'package:loomia/features/contacts/domain/person.dart';
import 'package:loomia/features/contacts/presentation/people_controller.dart';
import 'package:loomia/features/contacts/presentation/people_copy.dart';
import 'package:loomia/features/workflows/domain/progress.dart';
import 'package:loomia/l10n/app_localizations.dart';
import 'package:material_ui/material_ui.dart';

/// Remind me about [person], or edit [editing]: a sheet on mobile, a dialog
/// elsewhere (#217). Closes once saved or deleted.
Future<void> showReminder(
  BuildContext context,
  Person person, {
  Reminder? editing,
}) => LoomiaDialog.show<void>(
  context,
  (_) => _ReminderForm(person: person, editing: editing),
);

class _ReminderForm extends ConsumerStatefulWidget {
  const _ReminderForm({required this.person, this.editing});

  final Person person;

  /// Null when adding.
  final Reminder? editing;

  @override
  ConsumerState<_ReminderForm> createState() => _ReminderFormState();
}

class _ReminderFormState extends ConsumerState<_ReminderForm> {
  final _form = GlobalKey<FormState>();
  late final _text = TextEditingController(text: widget.editing?.text);
  late DateTime _day = widget.editing?.dueOn ?? addDays(today(), 1);
  bool _saving = false;
  PeopleFailure? _failure;

  // The repeat fields (#486), as on a task.
  late final Repeat? _old = widget.editing?.repeat;
  late bool _repeatOn = _old != null;
  late final _every = TextEditingController(text: '${_old?.every ?? 1}');
  late RepeatUnit _unit = _old?.unit ?? RepeatUnit.week;
  late DateTime? _until = _old?.until;

  @override
  void dispose() {
    _text.dispose();
    _every.dispose();
    super.dispose();
  }

  /// The rule as the fields read, counted from [day].
  Repeat _ruleFrom(DateTime day) => (
    every: int.tryParse(_every.text) ?? 1,
    unit: _unit,
    from: day,
    until: _until,
    scheduledOn: day,
  );

  Future<void> _write(
    Future<void> Function(PeopleController people) write,
  ) async {
    final people = ref.read(
      peopleProvider(ref.read(accountProvider)?.email).notifier,
    );
    setState(() {
      _saving = true;
      _failure = null;
    });
    try {
      await write(people);
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

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    final editing = widget.editing;
    final text = _text.text;
    final repeat = await repeatToSave(
      context,
      on: _repeatOn,
      old: _old,
      oldDay: editing?.dueOn,
      day: _day,
      ruleFrom: _ruleFrom,
      wording: ScopeWording.reminder,
    );
    if (repeat == null || !mounted) return;
    await _write(
      (people) => editing == null
          ? people.addReminder(widget.person, text, _day, repeat: repeat.$1)
          : people.editReminder(
              widget.person,
              editing,
              text,
              _day,
              repeat: repeat.$1,
            ),
    );
  }

  /// A repeating one asks first: This reminder skips to its next day, This
  /// and following deletes it; the dialog's Delete confirms. A plain one
  /// goes at once.
  Future<void> _delete(Reminder editing) async {
    final person = widget.person;
    if (editing.repeat == null) {
      return _write((people) => people.deleteReminder(person, editing));
    }
    final scope = await pickScope(
      context,
      delete: true,
      wording: ScopeWording.reminder,
    );
    if (scope == null || !mounted) return;
    await _write(
      (people) => scope == EventScope.one
          ? people.skipReminder(person, editing, today())
          : people.deleteReminder(person, editing),
    );
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
        title: editing == null ? l10n.reminderNewTitle : l10n.reminderEditTitle,
        actions: [
          if (editing != null)
            TextButton(
              onPressed: _saving ? null : () => unawaited(_delete(editing)),
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
              label: l10n.reminderWhat,
              child: TextFormField(
                controller: _text,
                autofocus: editing == null,
                minLines: 1,
                maxLines: 4,
                textCapitalization: TextCapitalization.sentences,
                validator: (value) => (value ?? '').trim().isEmpty
                    ? l10n.reminderWhatRequired
                    : null,
              ),
            ),
            ReminderDayField(
              label: l10n.logWhen,
              value: _day,
              onChanged: (day) => setState(() {
                _day = day;
                // An end before the reminder's day ends nothing: drop it.
                if (_until case final until? when until.isBefore(day)) {
                  _until = null;
                }
              }),
            ),
            RepeatFields(
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
            ),
          ],
        ),
      ),
    );
  }
}

/// When a reminder is due: Today (#486) · Tomorrow · In 3 days · In a week ·
/// In 2 weeks · Pick a day, and the day itself written under them. Used by the reminder
/// sheet and by Remind me in Log something.
class ReminderDayField extends StatelessWidget {
  const ReminderDayField({
    required this.label,
    required this.value,
    required this.onChanged,
    super.key,
  });

  final String label;

  /// Local midnight.
  final DateTime value;
  final ValueChanged<DateTime> onChanged;

  static const List<int> _presets = [0, 1, 3, 7, 14];

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final now = today();
    final preset = _presets
        .where((days) => addDays(now, days) == value)
        .firstOrNull;

    return LabeledField(
      label: label,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: AppSpacing.sm,
        children: [
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              for (final days in _presets)
                ChoiceChip(
                  label: Text(switch (days) {
                    0 => l10n.reminderToday,
                    1 => l10n.reminderTomorrow,
                    7 || 14 => l10n.reminderInWeeks(days ~/ 7),
                    _ => l10n.reminderInDays(days),
                  }),
                  selected: preset == days,
                  onSelected: (_) => onChanged(addDays(now, days)),
                ),
              ChoiceChip(
                label: Text(l10n.reminderPickDay),
                selected: preset == null,
                onSelected: (_) async {
                  final day = await pickDay(
                    context,
                    initial: value.isBefore(now) ? now : value,
                    first: now,
                    last: addDays(now, 365 * 2),
                  );
                  if (day != null) onChanged(day);
                },
              ),
            ],
          ),
          Text(
            (value.year == now.year
                    ? DateFormat.MMMMEEEEd(l10n.localeName)
                    : DateFormat.yMMMMEEEEd(l10n.localeName))
                .format(value),
            style: Theme.of(context).textTheme.bodyMedium
                ?.copyWith(color: LoomiaColors.of(context).textMuted),
          ),
        ],
      ),
    );
  }
}

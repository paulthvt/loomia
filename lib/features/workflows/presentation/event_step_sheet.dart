import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loomia/app/theme/app_spacing.dart';
import 'package:loomia/core/ui/form_error.dart';
import 'package:loomia/core/ui/labeled_field.dart';
import 'package:loomia/core/ui/loomia_dialog.dart';
import 'package:loomia/features/contacts/domain/people_failure.dart';
import 'package:loomia/features/contacts/presentation/people_copy.dart';
import 'package:loomia/features/workflows/domain/event_workflow.dart';
import 'package:loomia/features/workflows/presentation/event_workflows_controller.dart';
import 'package:loomia/l10n/app_localizations.dart';
import 'package:material_ui/material_ui.dart';

enum _When { before, onTheDay, after }

/// Edits [step] of [workflow], or adds one when [step] is null. The sheet
/// reads its own `ref`, so it does not depend on the editor under it staying
/// mounted.
Future<void> showEventStepSheet(
  BuildContext context,
  EventWorkflow workflow, {
  EventWorkflowStep? step,
}) => LoomiaDialog.show<void>(
  context,
  (_) => Consumer(
    builder: (context, ref, _) => _EventStepForm(
      workflow: workflow,
      step: step,
      onSave: (label, days, note) => editEventWorkflows(
        ref,
        (repository) => step == null
            ? repository.addStep(
                workflow.id,
                label: label,
                days: days,
                note: note,
              )
            : repository.updateStep(
                step.id,
                label: label,
                days: days,
                note: note,
              ),
      ),
      onRemove: step == null
          ? null
          : () => editEventWorkflows(
              ref,
              (repository) => repository.removeStep(step.id),
            ),
    ),
  ),
);

class _EventStepForm extends StatefulWidget {
  const _EventStepForm({
    required this.workflow,
    required this.onSave,
    this.step,
    this.onRemove,
  });

  final EventWorkflow workflow;
  final EventWorkflowStep? step;
  final Future<void> Function(String label, int days, String? note) onSave;
  final Future<void> Function()? onRemove;

  @override
  State<_EventStepForm> createState() => _EventStepFormState();
}

class _EventStepFormState extends State<_EventStepForm> {
  final _form = GlobalKey<FormState>();
  late final _label = TextEditingController(text: widget.step?.label);
  late _When _when = widget.step == null
      ? _When.before
      : widget.step!.days < 0
      ? _When.before
      : widget.step!.days == 0
      ? _When.onTheDay
      : _When.after;
  late final _days = TextEditingController(
    text: widget.step == null
        ? '1'
        : widget.step!.days == 0
        ? '1'
        : '${widget.step!.days.abs()}',
  );
  late final _note = TextEditingController(text: widget.step?.note);
  bool _saving = false;
  PeopleFailure? _failure;

  @override
  void dispose() {
    _label.dispose();
    _days.dispose();
    _note.dispose();
    super.dispose();
  }

  static int? _parseDays(String text) {
    final days = int.tryParse(text);
    return days != null && days >= 1 && days <= 365 ? days : null;
  }

  Future<void> _run(Future<void> Function() write) async {
    if (_saving) return;
    setState(() {
      _saving = true;
      _failure = null;
    });
    try {
      await write();
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
    if (_saving || !_form.currentState!.validate()) return;
    final note = _note.text.trim();
    final n = _when == _When.onTheDay ? 0 : int.parse(_days.text);
    final days = _when == _When.before
        ? -n
        : _when == _When.onTheDay
        ? 0
        : n;
    unawaited(
      _run(
        () =>
            widget.onSave(_label.text.trim(), days, note.isEmpty ? null : note),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final material = MaterialLocalizations.of(context);
    final failure = _failure;
    final remove = widget.onRemove;

    return Form(
      key: _form,
      child: LoomiaDialog(
        title: widget.step == null ? l10n.stepNew : widget.step!.label,
        actions: [
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
        footer: remove == null
            ? null
            : TextButton(
                onPressed: _saving ? null : () => unawaited(_run(remove)),
                child: Text(l10n.stepRemove),
              ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: AppSpacing.ms,
          children: [
            if (failure != null) FormError(peopleFailureCopy(l10n, failure)),
            LabeledField(
              label: l10n.stepLabel,
              child: TextFormField(
                controller: _label,
                autofocus: widget.step == null,
                textCapitalization: TextCapitalization.sentences,
                validator: (value) => (value ?? '').trim().isEmpty
                    ? l10n.stepLabelRequired
                    : null,
              ),
            ),
            LabeledField(
              label: l10n.eventStepWhen,
              child: Wrap(
                spacing: AppSpacing.sm,
                children: [
                  ChoiceChip(
                    label: Text(l10n.eventStepWhenBefore),
                    selected: _when == _When.before,
                    onSelected: (_) => setState(() => _when = _When.before),
                  ),
                  ChoiceChip(
                    label: Text(l10n.eventStepOnTheDay),
                    selected: _when == _When.onTheDay,
                    onSelected: (_) => setState(() => _when = _When.onTheDay),
                  ),
                  ChoiceChip(
                    label: Text(l10n.eventStepWhenAfter),
                    selected: _when == _When.after,
                    onSelected: (_) => setState(() => _when = _When.after),
                  ),
                ],
              ),
            ),
            if (_when != _When.onTheDay)
              LabeledField(
                label: l10n.eventStepDays,
                child: TextFormField(
                  controller: _days,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  validator: (value) => _parseDays(value ?? '') == null
                      ? l10n.eventStepDaysInvalid
                      : null,
                ),
              ),
            LabeledField(
              label: l10n.stepNote,
              child: TextFormField(
                controller: _note,
                minLines: 2,
                maxLines: 5,
                textCapitalization: TextCapitalization.sentences,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

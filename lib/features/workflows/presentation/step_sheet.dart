import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loomia/app/theme/app_spacing.dart';
import 'package:loomia/core/ui/form_error.dart';
import 'package:loomia/core/ui/labeled_field.dart';
import 'package:loomia/core/ui/loomia_dialog.dart';
import 'package:loomia/features/contacts/domain/people_failure.dart';
import 'package:loomia/features/contacts/presentation/people_copy.dart';
import 'package:loomia/features/workflows/domain/workflow.dart';
import 'package:loomia/features/workflows/presentation/workflows_controller.dart';
import 'package:loomia/l10n/app_localizations.dart';
import 'package:material_ui/material_ui.dart';

/// What the step sheet saves: a trimmed label, 0 to 365 days, and a trimmed
/// note or null.
typedef StepDraft = ({String label, int days, String? note});

/// Edits the step at [index] of [workflow], or adds one at the end when
/// [index] is null. The sheet reads its own `ref`, so it does not depend on
/// the editor under it staying mounted.
Future<void> showStepSheet(
  BuildContext context,
  Workflow workflow, {
  int? index,
}) {
  final step = index == null ? null : workflow.steps[index];
  return LoomiaDialog.show<void>(
    context,
    (_) => Consumer(
      builder: (context, ref, _) => StepForm(
        number: (index ?? workflow.steps.length) + 1,
        step: step,
        onSave: (draft) => editWorkflows(
          ref,
          (repository) => step == null
              ? repository.addStep(
                  workflow.id,
                  label: draft.label,
                  days: draft.days,
                  note: draft.note,
                  position: positionAt(workflow.steps, workflow.steps.length),
                )
              : repository.updateStep(
                  step.id,
                  label: draft.label,
                  days: draft.days,
                  note: draft.note,
                  loyaltySetup: step.loyaltySetup,
                ),
        ),
        onRemove: step == null
            ? null
            : () => editWorkflows(
                ref,
                (repository) => repository.removeStep(step.id),
              ),
      ),
    ),
  );
}

/// One step's form, fed its callbacks, which throw `PeopleFailure`. Pops
/// itself once one succeeds; keeps what was typed when one fails. Also what
/// the preview shows.
class StepForm extends StatefulWidget {
  const StepForm({
    required this.number,
    required this.onSave,
    this.step,
    this.onRemove,
    super.key,
  });

  /// From 1. Step 1 counts from the start, the others from the one before.
  final int number;

  /// The step edited; null adds one.
  final WorkflowStep? step;
  final Future<void> Function(StepDraft draft) onSave;

  /// Editing only.
  final Future<void> Function()? onRemove;

  @override
  State<StepForm> createState() => _StepFormState();
}

class _StepFormState extends State<StepForm> {
  final _form = GlobalKey<FormState>();
  late final _label = TextEditingController(text: widget.step?.label);
  // A new step 1 is usually done on the day; a later one the day after.
  late final _days = TextEditingController(
    text: '${widget.step?.days ?? (widget.number == 1 ? 0 : 1)}',
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
    return days != null && days >= 0 && days <= 365 ? days : null;
  }

  Future<void> _run(Future<void> Function() write) async {
    // A second tap can land before the frame that disables the buttons.
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
    unawaited(
      _run(
        () => widget.onSave((
          label: _label.text.trim(),
          days: int.parse(_days.text),
          note: note.isEmpty ? null : note,
        )),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final material = MaterialLocalizations.of(context);
    final failure = _failure;
    final remove = widget.onRemove;
    final first = widget.number == 1;
    final days = _parseDays(_days.text);

    return Form(
      key: _form,
      child: LoomiaDialog(
        title: widget.step == null
            ? l10n.stepNew
            : l10n.stepTitle(widget.number),
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
              label: first
                  ? l10n.stepDaysAfterStart
                  : l10n.stepDaysAfterPrevious,
              child: TextFormField(
                controller: _days,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                // The hint follows what is typed.
                onChanged: (_) => setState(() {}),
                validator: (value) => _parseDays(value ?? '') == null
                    ? l10n.stepDaysInvalid
                    : null,
                decoration: InputDecoration(
                  helperText: days == null
                      ? null
                      : first
                      ? l10n.stepDueAfterStart(days)
                      : l10n.stepDueAfterPrevious(days, widget.number - 1),
                  helperMaxLines: 2,
                ),
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

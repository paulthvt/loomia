import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loomia/app/theme/app_spacing.dart';
import 'package:loomia/core/ui/form_error.dart';
import 'package:loomia/core/ui/loomia_dialog.dart';
import 'package:loomia/core/ui/pick_day.dart';
import 'package:loomia/features/auth/data/auth_repository.dart';
import 'package:loomia/features/contacts/domain/people_failure.dart';
import 'package:loomia/features/contacts/domain/person.dart';
import 'package:loomia/features/contacts/presentation/people_controller.dart';
import 'package:loomia/features/contacts/presentation/people_copy.dart';
import 'package:loomia/features/workflows/domain/progress.dart';
import 'package:loomia/features/workflows/domain/workflow.dart';
import 'package:loomia/l10n/app_localizations.dart';
import 'package:material_ui/material_ui.dart';

/// "What's next for Sophie?" once [workflow] is done (#316): for a customer
/// without an LRP, whether they started one; then the workflows offered
/// next, or nothing. [all] resolves the offers, in `forStage` order.
Future<void> showWhatsNext(
  BuildContext context,
  Person person,
  Workflow workflow,
  List<Workflow> all,
) => LoomiaDialog.show<void>(
  context,
  (_) => _WhatsNext(
    person: person,
    workflow: workflow,
    options: [
      for (final other in forStage(all, workflow.stage))
        if (workflow.next.contains(other.id)) other,
    ],
  ),
);

class _WhatsNext extends ConsumerStatefulWidget {
  const _WhatsNext({
    required this.person,
    required this.workflow,
    required this.options,
  });

  final Person person;
  final Workflow workflow;
  final List<Workflow> options;

  @override
  ConsumerState<_WhatsNext> createState() => _WhatsNextState();
}

class _WhatsNextState extends ConsumerState<_WhatsNext> {
  static const _nothing = '';

  late String _picked = widget.options.firstOrNull?.id ?? _nothing;

  /// Null until answered, when asked at all.
  bool? _loyalty;
  bool _saving = false;
  PeopleFailure? _failure;

  bool get _asksLoyalty =>
      widget.person.stage == Stage.customer &&
      widget.person.loyaltySince == null;

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _failure = null;
    });
    final people = ref.read(
      peopleProvider(ref.read(accountProvider)?.email).notifier,
    );
    final day = today();
    try {
      if (_loyalty ?? false) {
        await people.setLoyalty(widget.person, day, day);
      }
      // With the LRP started and nothing to offer, nothing is left to ask.
      if (widget.options.isNotEmpty || !(_loyalty ?? false)) {
        final next = findWorkflow(widget.options, _picked);
        await people.setWorkflow(
          [widget.person],
          next == null
              ? null
              : (workflow: next, firstDue: firstDueDefault(next, day)),
        );
      }
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

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final name = firstName(widget.person);
    final failure = _failure;
    final ready = !_saving && (!_asksLoyalty || _loyalty != null);
    return LoomiaDialog(
      title: l10n.nextWhatTitle(name),
      body: l10n.nextWhatDone(widget.workflow.name),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(MaterialLocalizations.of(context).cancelButtonLabel),
        ),
        FilledButton(
          onPressed: ready ? _save : null,
          child: _saving
              ? const SizedBox.square(
                  dimension: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(l10n.nextWhatSave),
        ),
      ],
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: AppSpacing.sm,
        children: [
          if (failure != null) FormError(peopleFailureCopy(l10n, failure)),
          if (_asksLoyalty) ...[
            Text(
              l10n.nextLoyaltyQuestion(name),
              style: Theme.of(context).textTheme.titleSmall,
            ),
            SegmentedButton<bool>(
              emptySelectionAllowed: true,
              segments: [
                ButtonSegment(value: true, label: Text(l10n.nextLoyaltyYes)),
                ButtonSegment(
                  value: false,
                  label: Text(l10n.nextLoyaltyNotYet),
                ),
              ],
              selected: {?_loyalty},
              onSelectionChanged: _saving
                  ? null
                  : (picked) => setState(() => _loyalty = picked.firstOrNull),
            ),
          ],
          if (widget.options.isNotEmpty)
            RadioGroup<String>(
              groupValue: _picked,
              onChanged: (id) => setState(() => _picked = id ?? _nothing),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final option in widget.options)
                    RadioListTile<String>(
                      value: option.id,
                      contentPadding: EdgeInsets.zero,
                      title: Text(option.name),
                    ),
                  RadioListTile<String>(
                    value: _nothing,
                    contentPadding: EdgeInsets.zero,
                    title: Text(l10n.nextWhatNothing),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loomia/core/business_model/business_model.dart';
import 'package:loomia/core/ui/form_error.dart';
import 'package:loomia/core/ui/labeled_field.dart';
import 'package:loomia/core/ui/loomia_dialog.dart';
import 'package:loomia/core/ui/pick_day.dart';
import 'package:loomia/features/auth/data/auth_repository.dart';
import 'package:loomia/features/contacts/domain/people_failure.dart';
import 'package:loomia/features/contacts/domain/person.dart';
import 'package:loomia/features/contacts/presentation/people_controller.dart';
import 'package:loomia/features/contacts/presentation/people_copy.dart';
import 'package:loomia/l10n/app_localizations.dart';
import 'package:material_ui/material_ui.dart';

/// [person]'s LRP (#255): the day it started, today by default, or stopped.
/// A sheet on mobile, a dialog elsewhere. Closes once saved.
Future<void> showLoyalty(BuildContext context, Person person) =>
    LoomiaDialog.show<void>(context, (_) => LoyaltyForm(person: person));

class LoyaltyForm extends ConsumerStatefulWidget {
  const LoyaltyForm({required this.person, super.key});

  final Person person;

  @override
  ConsumerState<LoyaltyForm> createState() => _LoyaltyFormState();
}

class _LoyaltyFormState extends ConsumerState<LoyaltyForm> {
  late DateTime _day = widget.person.loyaltySince ?? today();
  bool _saving = false;
  PeopleFailure? _failure;

  Future<void> _pickDay() async {
    final day = await pickDay(
      context,
      initial: _day,
      first: DateTime(2000),
      last: today(),
    );
    if (day != null && mounted) setState(() => _day = day);
  }

  /// [since] null stops it.
  Future<void> _write(DateTime? since) async {
    final people = ref.read(
      peopleProvider(ref.read(accountProvider)?.email).notifier,
    );
    setState(() {
      _saving = true;
      _failure = null;
    });
    try {
      await people.setLoyalty(widget.person, since, today());
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
    final material = MaterialLocalizations.of(context);
    final model =
        ref.watch(accountProvider)?.businessModel ?? BusinessModel.other;
    final failure = _failure;
    final now = today();

    return LoomiaDialog(
      title: l10n.loyaltyLabel(model.name),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(material.cancelButtonLabel),
        ),
        FilledButton(
          onPressed: _saving ? null : () => _write(_day),
          child: _saving
              ? const SizedBox.square(
                  dimension: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(material.saveButtonLabel),
        ),
      ],
      footer: widget.person.loyaltySince == null
          ? null
          : TextButton(
              onPressed: _saving ? null : () => _write(null),
              child: Text(l10n.loyaltySheetStop(model.name)),
            ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (failure != null) FormError(peopleFailureCopy(l10n, failure)),
          LabeledField(
            label: l10n.loyaltySheetQuestion,
            child: InkWell(
              onTap: _saving ? null : _pickDay,
              child: InputDecorator(
                decoration: const InputDecoration(
                  suffixIcon: Icon(Icons.calendar_today_outlined),
                ),
                child: Text(
                  _day == now
                      ? l10n.logWhenToday(_day)
                      : dayLabel(l10n, _day, now),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

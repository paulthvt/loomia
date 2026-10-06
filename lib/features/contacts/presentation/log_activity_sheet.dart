import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loomia/app/theme/app_spacing.dart';
import 'package:loomia/core/business_model/business_model.dart';
import 'package:loomia/core/ui/form_error.dart';
import 'package:loomia/core/ui/labeled_field.dart';
import 'package:loomia/core/ui/loomia_dialog.dart';
import 'package:loomia/core/ui/pick_day.dart';
import 'package:loomia/features/auth/data/auth_repository.dart';
import 'package:loomia/features/contacts/data/activity_repository.dart';
import 'package:loomia/features/contacts/domain/activity.dart';
import 'package:loomia/features/contacts/domain/people_failure.dart';
import 'package:loomia/features/contacts/domain/person.dart';
import 'package:loomia/features/contacts/presentation/history_controller.dart';
import 'package:loomia/features/contacts/presentation/people_controller.dart';
import 'package:loomia/features/contacts/presentation/people_copy.dart';
import 'package:loomia/l10n/app_localizations.dart';
import 'package:material_ui/material_ui.dart';

/// Log something with [person]: a sheet on mobile, a dialog elsewhere. Closes
/// once the entry is saved.
Future<void> showLogActivity(BuildContext context, Person person) =>
    LoomiaDialog.show<void>(context, (_) => _LogActivityForm(person: person));

/// The user's own order, from Goals: Order only, with an amount. [onSaved]
/// runs once it is saved, before the sheet closes.
Future<void> showLogOwnOrder(
  BuildContext context, {
  required VoidCallback onSaved,
}) =>
    LoomiaDialog.show<void>(context, (_) => _LogActivityForm(onSaved: onSaved));

/// Edit [activity] in [person]'s history: the same form, the kind fixed. A
/// stage entry asks only for its day, which is [Person.stageSince]. Resolves
/// true when Delete is tapped; the history confirms and deletes.
Future<bool?> showEditActivity(
  BuildContext context,
  Person person,
  Activity activity,
) => LoomiaDialog.show<bool>(
  context,
  (_) => _LogActivityForm(person: person, editing: activity),
);

class _LogActivityForm extends ConsumerStatefulWidget {
  const _LogActivityForm({this.person, this.onSaved, this.editing});

  /// Null: the user's own order.
  final Person? person;

  /// Own order only: after the save, before the sheet closes.
  final VoidCallback? onSaved;

  /// Null when adding.
  final Activity? editing;

  @override
  ConsumerState<_LogActivityForm> createState() => _LogActivityFormState();
}

class _LogActivityFormState extends ConsumerState<_LogActivityForm> {
  final _form = GlobalKey<FormState>();
  late final Activity? _editing = widget.editing;
  late final _text = TextEditingController(text: _editing?.text);
  // Plain digits and a dot, as the edit form writes a volume: parseAmount
  // reads them back in every language.
  late final _amount = TextEditingController(
    text: switch (_editing?.amount) {
      final double amount when amount % 1 == 0 => amount.toInt().toString(),
      final double amount => amount.toString(),
      null => '',
    },
  );
  late ActivityKind _kind =
      _editing?.kind ??
      (widget.person == null ? ActivityKind.order : ActivityKind.note);
  late DateTime _day = _editing?.day ?? today();
  bool _saving = false;
  PeopleFailure? _failure;

  @override
  void dispose() {
    _text.dispose();
    _amount.dispose();
    super.dispose();
  }

  bool get _stage => _editing?.kind == ActivityKind.stage;

  Future<void> _pickDay() async {
    final now = today();
    final day = await pickDay(
      context,
      initial: _day,
      first: _stage ? _previousStageDay() : null,
      // A day saved on a device ahead of this one stays reachable.
      last: _day.isAfter(now) ? _day : now,
    );
    if (day != null && mounted) setState(() => _day = day);
  }

  /// A stage entry can't go before the stage before it (the database keeps
  /// it after that one anyway).
  DateTime? _previousStageDay() {
    final entries = ref.read(historyProvider(widget.person!.id)).value;
    final stages = [
      for (final entry in entries ?? const <Activity>[])
        if (entry.kind == ActivityKind.stage) entry,
    ];
    final index = stages.indexWhere((entry) => entry.id == _editing!.id);
    if (index < 0 || index + 1 >= stages.length) return null;
    return stages[index + 1].day;
  }

  Future<void> _submit() async {
    // A stage entry has only its day: nothing to validate.
    if (!_stage && !_form.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _failure = null;
    });
    try {
      final ActivityDraft draft = (
        kind: _kind,
        happenedOn: _day,
        text: _text.text.trim(),
        // Typed under Order, then another kind picked: not this entry's.
        amount: _kind == ActivityKind.order
            ? parseAmount(_amount.text, AppLocalizations.of(context).localeName)
            : null,
      );
      final person = widget.person;
      final editing = _editing;
      if (person == null) {
        await ref.read(activityRepositoryProvider).addOwnOrder(draft);
        widget.onSaved?.call();
      } else if (editing == null) {
        await ref.read(historyProvider(person.id).notifier).add(draft);
      } else if (_stage) {
        // The same day keeps its time, and its place among that day's.
        if (_day != editing.day) {
          await ref
              .read(peopleProvider(ref.read(accountProvider)?.email).notifier)
              .setStageSince(person, _day);
        }
      } else {
        await ref
            .read(historyProvider(person.id).notifier)
            .edit(editing, draft);
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
    // Keeps the history alive while the sheet is open, whatever is under it.
    final person = widget.person;
    if (person != null) ref.watch(historyProvider(person.id));
    final l10n = AppLocalizations.of(context);
    final material = MaterialLocalizations.of(context);
    final failure = _failure;
    final currentDay = today();
    final order = _kind == ActivityKind.order;
    final unit = l10n.orderUnit(
      (ref.watch(accountProvider)?.businessModel ?? BusinessModel.other).name,
    );

    return Form(
      key: _form,
      child: LoomiaDialog(
        title: _editing != null
            ? l10n.editActivityTitle
            : person == null
            ? l10n.logOwnOrderTitle
            : l10n.logTitle(firstName(person)),
        actions: [
          if (_editing != null && !_stage)
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(l10n.historyDeleteConfirm),
            ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(material.cancelButtonLabel),
          ),
          FilledButton(
            onPressed: _saving ? null : _submit,
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
            if (person != null && _editing == null)
              Wrap(
                spacing: AppSpacing.sm,
                children: [
                  for (final kind in ActivityKind.values)
                    if (kind.byUser)
                      ChoiceChip(
                        label: Text(kindLabel(l10n, kind)!),
                        selected: _kind == kind,
                        onSelected: (_) => setState(() => _kind = kind),
                      ),
                ],
              ),
            LabeledField(
              label: l10n.logWhen,
              child: InkWell(
                onTap: _pickDay,
                child: InputDecorator(
                  decoration: const InputDecoration(
                    suffixIcon: Icon(Icons.calendar_today_outlined),
                  ),
                  child: Text(
                    _day == currentDay
                        ? l10n.logWhenToday(_day)
                        : dayLabel(l10n, _day, currentDay),
                  ),
                ),
              ),
            ),
            if (order)
              LabeledField(
                label: l10n.logAmount,
                // The unit is drawn excluded from semantics (see below), so
                // a screen reader hears it here.
                child: Semantics(
                  hint: unit,
                  child: TextFormField(
                    controller: _amount,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    // An icon, not suffixText, kept out of semantics: a suffix
                    // that has semantics trips a Flutter assertion in
                    // LabeledField's MergeSemantics when the form rebuilds.
                    decoration: InputDecoration(
                      suffixIcon: unit.isEmpty
                          ? null
                          : Padding(
                              padding: const EdgeInsetsDirectional.only(
                                end: AppSpacing.md,
                              ),
                              child: ExcludeSemantics(child: Text(unit)),
                            ),
                      suffixIconConstraints: const BoxConstraints(),
                    ),
                    validator: (value) {
                      final typed = (value ?? '').trim();
                      if (typed.isEmpty) {
                        return person == null
                            ? l10n.logOwnOrderAmountRequired
                            : null;
                      }
                      return parseAmount(typed, l10n.localeName) != null
                          ? null
                          : l10n.logAmountInvalid;
                    },
                  ),
                ),
              ),
            if (!_stage)
              LabeledField(
                // Keeps its state, focus included, when Amount appears above.
                key: const ValueKey('text'),
                label: order ? l10n.logNote : l10n.logWhat,
                child: TextFormField(
                  controller: _text,
                  autofocus: _editing == null,
                  minLines: 2,
                  maxLines: 5,
                  textCapitalization: TextCapitalization.sentences,
                  validator: (value) {
                    if ((value ?? '').trim().isNotEmpty) return null;
                    if (!order) return l10n.logWhatRequired;
                    return _amount.text.trim().isEmpty
                        ? l10n.logOrderRequired
                        : null;
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}

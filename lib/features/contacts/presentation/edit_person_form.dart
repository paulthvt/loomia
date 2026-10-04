import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loomia/app/theme/app_spacing.dart';
import 'package:loomia/core/business_model/business_model.dart';
import 'package:loomia/core/ui/form_error.dart';
import 'package:loomia/core/ui/labeled_field.dart';
import 'package:loomia/core/ui/loomia_dialog.dart';
import 'package:loomia/core/ui/pick_day.dart';
import 'package:loomia/core/ui/section_header.dart';
import 'package:loomia/features/auth/data/auth_repository.dart';
import 'package:loomia/features/contacts/domain/activity.dart' show parseAmount;
import 'package:loomia/features/contacts/domain/people_failure.dart';
import 'package:loomia/features/contacts/domain/person.dart';
import 'package:loomia/features/contacts/presentation/people_controller.dart';
import 'package:loomia/features/contacts/presentation/people_copy.dart';
import 'package:loomia/l10n/app_localizations.dart';
import 'package:material_ui/material_ui.dart';

/// Which fields the form asks for: all of them from ⋯, or one section's from
/// its own Edit, so a single fact is not lost in the whole form.
enum EditPart {
  everything,

  /// WHAT THEY ARE AIMING FOR: a team member's own profile.
  aims,

  /// WHAT YOU KNOW: every fact but the name and the profile.
  facts,
}

/// Edit details: every field but the stage (it moves through ⋯ in #56) and the
/// status (edited on the detail screen), or only those of [part]. A scrolling
/// sheet on mobile, a dialog elsewhere. Fields not asked for are kept.
Future<void> showEditPerson(
  BuildContext context,
  Person person, [
  EditPart part = EditPart.everything,
]) => LoomiaDialog.show<void>(context, (_) => _EditPersonForm(person, part));

// In the detail page's order.
enum _Field {
  name,
  why,
  ownGoal,
  timeAvailable,
  wouldLoveTo,
  strengths,
  stuckOn,
  needs,
  products,
  profession,
  phone,
  email,
  instagram,
  address,
  notes,
}

/// A team member's own profile: only asked while they are on the team.
const _teamFields = {
  _Field.why,
  _Field.ownGoal,
  _Field.timeAvailable,
  _Field.wouldLoveTo,
  _Field.strengths,
  _Field.stuckOn,
};

/// WHAT YOU KNOW: the rest but the name.
final _facts = _Field.values.where(
  (field) => field != _Field.name && !_teamFields.contains(field),
);

/// Sentences in their words, not a single value.
const _multiline = {_Field.address, _Field.notes, ..._teamFields};

class _EditPersonForm extends ConsumerStatefulWidget {
  const _EditPersonForm(this.person, this.part);

  final Person person;
  final EditPart part;

  @override
  ConsumerState<_EditPersonForm> createState() => _EditPersonFormState();
}

class _EditPersonFormState extends ConsumerState<_EditPersonForm> {
  final _form = GlobalKey<FormState>();
  late final Map<_Field, TextEditingController> _controllers = {
    for (final field in _Field.values)
      field: TextEditingController(text: _initial(field)),
  };
  bool _saving = false;
  PeopleFailure? _failure;

  // A team member's rank and volume: picked or typed, kept as they are when
  // this form does not ask for them.
  late String? _levelNow = widget.person.currentLevel;
  late String? _aimingFor = widget.person.targetLevel;
  late DateTime? _by = widget.person.targetLevelBy;
  // Plain digits and a dot: parseAmount reads them back in every language
  // (French reads a dot as the decimal too). No context here, so dispose can
  // create it safely.
  late final _volume = TextEditingController(
    text: switch (widget.person.monthlyVolumeTarget) {
      final double volume when volume % 1 == 0 => volume.toInt().toString(),
      final double volume => volume.toString(),
      null => '',
    },
  );

  Future<void> _pickBy() async {
    final now = today();
    final thisMonth = DateTime(now.year, now.month);
    final initial = _by ?? thisMonth;
    final by = await pickMonth(
      context,
      initial: initial,
      // A saved month in the past stays reachable.
      first: initial.isBefore(thisMonth) ? initial : thisMonth,
      last: DateTime(thisMonth.year + 10, thisMonth.month),
    );
    if (by != null && mounted) setState(() => _by = by);
  }

  String? _initial(_Field field) {
    final p = widget.person;
    return switch (field) {
      _Field.name => p.name,
      _Field.phone => p.phone,
      _Field.email => p.email,
      _Field.instagram => p.instagram,
      _Field.needs => p.needs,
      _Field.products => p.products,
      _Field.profession => p.profession,
      _Field.address => p.address,
      _Field.notes => p.notes,
      _Field.why => p.why,
      _Field.ownGoal => p.ownGoal,
      _Field.timeAvailable => p.timeAvailable,
      _Field.wouldLoveTo => p.wouldLoveTo,
      _Field.strengths => p.strengths,
      _Field.stuckOn => p.stuckOn,
    };
  }

  bool _asks(_Field field) => switch (widget.part) {
    EditPart.everything =>
      widget.person.stage == Stage.team || !_teamFields.contains(field),
    EditPart.aims => _teamFields.contains(field),
    EditPart.facts => _facts.contains(field),
  };

  /// Blank is absent.
  String? _text(_Field field) {
    final text = _controllers[field]!.text.trim();
    return text.isEmpty ? null : text;
  }

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    _volume.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    final p = widget.person;
    final volume = _asks(_Field.why)
        ? parseAmount(_volume.text, AppLocalizations.of(context).localeName)
        : p.monthlyVolumeTarget;
    setState(() {
      _saving = true;
      _failure = null;
    });
    try {
      await ref
          .read(peopleProvider(ref.read(accountProvider)?.email).notifier)
          .save(
            Person(
              id: p.id,
              name: _text(_Field.name)!,
              stage: p.stage,
              prospectStatus: p.prospectStatus,
              stageSince: p.stageSince,
              phone: _text(_Field.phone),
              email: _text(_Field.email),
              instagram: _text(_Field.instagram),
              needs: _text(_Field.needs),
              products: _text(_Field.products),
              profession: _text(_Field.profession),
              address: _text(_Field.address),
              notes: _text(_Field.notes),
              why: _text(_Field.why),
              currentLevel: _levelNow,
              targetLevel: _aimingFor,
              // The database refuses a month with nothing to aim for.
              targetLevelBy: _aimingFor == null ? null : _by,
              monthlyVolumeTarget: volume,
              ownGoal: _text(_Field.ownGoal),
              timeAvailable: _text(_Field.timeAvailable),
              wouldLoveTo: _text(_Field.wouldLoveTo),
              strengths: _text(_Field.strengths),
              stuckOn: _text(_Field.stuckOn),
            ),
          );
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
    final failure = _failure;
    final model =
        ref.watch(accountProvider)?.businessModel ?? BusinessModel.other;
    final labels = {
      _Field.name: l10n.addPersonName,
      _Field.phone: l10n.factPhone,
      _Field.email: l10n.factEmail,
      _Field.instagram: l10n.factInstagram,
      _Field.needs: l10n.factNeeds,
      _Field.products: l10n.factProducts,
      _Field.profession: l10n.factProfession,
      _Field.address: l10n.factAddress,
      _Field.notes: l10n.factNotes,
      _Field.why: l10n.factWhy,
      _Field.ownGoal: l10n.factOwnGoal,
      _Field.timeAvailable: l10n.factTimeAvailable,
      _Field.wouldLoveTo: l10n.factWouldLoveTo,
      _Field.strengths: l10n.factStrengths,
      _Field.stuckOn: l10n.factStuckOn,
    };

    Widget input(_Field field) => LabeledField(
      key: ValueKey(field),
      label: labels[field]!,
      child: TextFormField(
        controller: _controllers[field],
        textCapitalization: field == _Field.name
            ? TextCapitalization.words
            : TextCapitalization.sentences,
        keyboardType: switch (field) {
          _Field.phone => TextInputType.phone,
          _Field.email => TextInputType.emailAddress,
          _ when _multiline.contains(field) => TextInputType.multiline,
          _ => TextInputType.text,
        },
        maxLines: _multiline.contains(field) ? null : 1,
        validator: field == _Field.name
            ? (value) => (value ?? '').trim().isEmpty
                  ? l10n.addPersonNameRequired
                  : null
            : null,
      ),
    );

    // dōTERRA picks from its ranks; Other types its own words. A stored
    // label the list lacks (a renamed rank) stays a choice.
    Widget level(
      String label,
      String? value,
      List<String> choices,
      ValueChanged<String?> onChanged,
    ) => LabeledField(
      // A new key when the choices change, so the dropdown restarts from
      // [value] instead of keeping one it no longer offers.
      key: ValueKey((label, choices.length)),
      label: label,
      child: model.levels.isEmpty
          ? TextFormField(
              initialValue: value,
              textCapitalization: TextCapitalization.words,
              onChanged: (typed) =>
                  onChanged(typed.trim().isEmpty ? null : typed.trim()),
            )
          : DropdownButtonFormField<String?>(
              initialValue: value,
              // Defaults to titleMedium; the text fields around it are
              // bodyLarge.
              style: Theme.of(context).textTheme.bodyLarge,
              items: [
                DropdownMenuItem(child: Text(l10n.editLevelNone)),
                for (final name in [
                  ...choices,
                  if (value != null && !choices.contains(value)) value,
                ])
                  DropdownMenuItem(value: name, child: Text(name)),
              ],
              onChanged: onChanged,
            ),
    );

    // Nobody aims for a rank they already hold: only the ranks above the
    // current one, or all of them when it is unknown.
    List<String> above(String? rank) {
      final index = model.levels.indexOf(rank ?? '');
      return model.levels.sublist(index + 1);
    }

    final rankAndVolume = [
      level(
        l10n.factLevelNow(model.name),
        _levelNow,
        model.levels,
        (value) => setState(() {
          _levelNow = value;
          if (_aimingFor != null &&
              model.levels.contains(_aimingFor) &&
              !above(value).contains(_aimingFor)) {
            _aimingFor = null;
          }
        }),
      ),
      level(
        l10n.factAimingFor,
        _aimingFor,
        above(_levelNow),
        (value) => setState(() => _aimingFor = value),
      ),
      if (_aimingFor != null)
        LabeledField(
          key: const ValueKey('by'),
          label: l10n.editBy,
          child: InkWell(
            onTap: _pickBy,
            child: InputDecorator(
              decoration: const InputDecoration(
                suffixIcon: Icon(Icons.calendar_today_outlined),
              ),
              child: Text(switch (_by) {
                final DateTime by => material.formatMonthYear(by),
                null => '',
              }),
            ),
          ),
        ),
      LabeledField(
        key: const ValueKey('volume'),
        label: l10n.editEachMonth(model.name),
        child: TextFormField(
          controller: _volume,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          validator: (value) {
            final typed = (value ?? '').trim();
            return typed.isEmpty || parseAmount(typed, l10n.localeName) != null
                ? null
                : l10n.logAmountInvalid;
          },
        ),
      ),
    ];

    return Form(
      key: _form,
      child: LoomiaDialog(
        title: switch (widget.part) {
          EditPart.everything => l10n.editPersonTitle,
          EditPart.aims => l10n.contactSectionAimingFor,
          EditPart.facts => l10n.contactSectionWhatYouKnow,
        },
        actions: [
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
          children: [
            if (failure != null) ...[
              FormError(peopleFailureCopy(l10n, failure)),
              const SizedBox(height: AppSpacing.ms),
            ],
            // The whole form is grouped as the page is; a section's own
            // needs no header, the title says it.
            for (final (index, (header, fields)) in [
              (null, [_Field.name]),
              (l10n.contactSectionAimingFor, _teamFields),
              (l10n.contactSectionWhatYouKnow, _facts),
            ].where((section) => section.$2.any(_asks)).indexed) ...[
              if (index > 0) const SizedBox(height: AppSpacing.lg),
              if (header != null && widget.part == EditPart.everything)
                SectionHeader(title: header),
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                spacing: AppSpacing.ms,
                children: [
                  for (final field in fields.where(_asks)) ...[
                    input(field),
                    if (field == _Field.why) ...rankAndVolume,
                  ],
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

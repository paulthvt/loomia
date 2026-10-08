import 'package:loomia/app/theme/app_spacing.dart';
import 'package:loomia/features/contacts/domain/person.dart';
import 'package:loomia/l10n/app_localizations.dart';
import 'package:material_ui/material_ui.dart';

/// Everyone · Prospects · Customers · Team, one picked. Null is everyone.
class StageFilter extends StatelessWidget {
  const StageFilter({required this.value, required this.onChanged, super.key});

  final Stage? value;
  final ValueChanged<Stage?> onChanged;

  /// Whether [person] passes the filter set to [stage].
  static bool shows(Stage? stage, Person person) =>
      stage == null || person.stage == stage;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Wrap(
      spacing: AppSpacing.sm,
      children: [
        for (final (stage, label) in [
          (null, l10n.contactsFilterEveryone),
          (Stage.prospect, l10n.contactsFilterProspects),
          (Stage.customer, l10n.contactsFilterCustomers),
          (Stage.team, l10n.contactsFilterTeam),
        ])
          ChoiceChip(
            label: Text(label),
            selected: value == stage,
            onSelected: (_) => onChanged(stage),
          ),
      ],
    );
  }
}

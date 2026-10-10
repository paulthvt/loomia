import 'package:loomia/app/theme/app_spacing.dart';
import 'package:loomia/features/contacts/domain/person.dart';
import 'package:loomia/l10n/app_localizations.dart';
import 'package:material_ui/material_ui.dart';

/// Everyone · Prospects · Customers · Team, one picked. Null is everyone.
/// Then, with a [loyaltyLabel], an LRP chip on or off, within the stage
/// (#255).
class StageFilter extends StatelessWidget {
  const StageFilter({
    required this.value,
    required this.onChanged,
    this.loyaltyLabel,
    this.loyalty = false,
    this.onLoyaltyChanged,
    super.key,
  });

  final Stage? value;
  final ValueChanged<Stage?> onChanged;

  /// "LRP" or "Loyalty orders"; null hides the chip.
  final String? loyaltyLabel;
  final bool loyalty;
  final ValueChanged<bool>? onLoyaltyChanged;

  /// Whether [person] passes the filter set to [stage], and to people with
  /// an LRP when [loyalty].
  static bool shows(Stage? stage, Person person, {bool loyalty = false}) =>
      (stage == null || person.stage == stage) &&
      (!loyalty || person.loyaltySince != null);

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
        if (loyaltyLabel case final label?)
          FilterChip(
            label: Text(label),
            selected: loyalty,
            onSelected: onLoyaltyChanged,
          ),
      ],
    );
  }
}

import 'package:loomia/app/theme/app_spacing.dart';
import 'package:loomia/core/layout/breakpoints.dart';
import 'package:loomia/core/ui/tag_chip.dart';
import 'package:loomia/features/contacts/domain/person.dart';
import 'package:loomia/features/contacts/domain/tag.dart';
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

  /// Whether [person] passes the filter set to [stage], to people with an
  /// LRP when [loyalty], and to people with every one of [tags].
  static bool shows(
    Stage? stage,
    Person person, {
    bool loyalty = false,
    Set<String> tags = const {},
  }) =>
      (stage == null || person.stage == stage) &&
      (!loyalty || person.loyaltySince != null) &&
      person.tagIds.containsAll(tags);

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

/// The tag chips under the stage chips (#332), one per tag in [tags]' order,
/// each on or off. Several on: people with all of them. A phone scrolls them
/// sideways on one line; wider screens wrap them.
class TagFilter extends StatelessWidget {
  const TagFilter({
    required this.tags,
    required this.selected,
    required this.onChanged,
    super.key,
  });

  final List<Tag> tags;
  final Set<String> selected;
  final ValueChanged<Set<String>> onChanged;

  @override
  Widget build(BuildContext context) {
    final chips = [
      for (final tag in tags)
        TagChip(
          label: tag.name,
          color: tag.color,
          selected: selected.contains(tag.id),
          onTap: () => onChanged(
            selected.contains(tag.id)
                ? selected.difference({tag.id})
                : {...selected, tag.id},
          ),
        ),
    ];
    if (!context.screenSize.isMobile) {
      return Wrap(spacing: AppSpacing.sm, children: chips);
    }
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(spacing: AppSpacing.sm, children: chips),
    );
  }
}

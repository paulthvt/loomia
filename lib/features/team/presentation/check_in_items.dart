import 'package:loomia/app/theme/app_spacing.dart';
import 'package:loomia/core/ui/action_item.dart';
import 'package:loomia/core/ui/section_header.dart';
import 'package:loomia/features/contacts/domain/person.dart';
import 'package:loomia/features/contacts/presentation/people_copy.dart';
import 'package:loomia/features/team/domain/check_in.dart';
import 'package:loomia/l10n/app_localizations.dart';
import 'package:material_ui/material_ui.dart';

/// `WORTH A CHECK-IN`: its header and one row per member who might need
/// you. Team shows it; Today's desktop side column too. Nothing when [due]
/// is empty.
List<Widget> checkInItems(
  AppLocalizations l10n,
  List<CheckIn> due, {
  required void Function(Person person) onOpen,
  required void Function(Person person) onCheckIn,
}) => [
  if (due.isNotEmpty) ...[
    SectionHeader(title: l10n.teamSectionCheckIn),
    for (final (index, checkIn) in due.indexed) ...[
      if (index > 0) const SizedBox(height: AppSpacing.ms),
      ActionItem(
        name: checkIn.person.name,
        reason: checkInReason(l10n, checkIn),
        chip: DateChip(switch (checkIn.reason) {
          CheckInReason.isNew => l10n.teamChipNew,
          CheckInReason.quiet => l10n.teamChipQuiet(checkIn.days ~/ 7),
        }),
        onOpen: () => onOpen(checkIn.person),
        onResolve: () => onCheckIn(checkIn.person),
        resolveLabel: l10n.logTitle(firstName(checkIn.person)),
      ),
    ],
  ],
];

/// Why [checkIn]'s member is worth a check-in, in plain words.
String checkInReason(AppLocalizations l10n, CheckIn checkIn) {
  final (:person, :reason, :since, :days) = checkIn;
  return switch (reason) {
    CheckInReason.isNew when days <= 0 => l10n.teamReasonNewToday,
    CheckInReason.isNew when days < 7 => l10n.teamReasonNewDays(days),
    CheckInReason.isNew => l10n.teamReasonNewWeeks(days ~/ 7),
    CheckInReason.quiet when person.lastContactOn == null =>
      l10n.teamReasonQuietNothing(since),
    CheckInReason.quiet => l10n.teamReasonQuiet(since),
  };
}

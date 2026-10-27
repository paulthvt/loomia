import 'package:loomia/app/theme/app_colors.dart';
import 'package:loomia/app/theme/app_spacing.dart';
import 'package:loomia/app/theme/app_theme.dart';
import 'package:loomia/core/ui/action_item.dart';
import 'package:loomia/core/ui/loomia_avatar.dart';
import 'package:loomia/core/ui/section_header.dart';
import 'package:loomia/features/contacts/domain/person.dart';
import 'package:loomia/features/contacts/presentation/people_copy.dart';
import 'package:loomia/features/team/domain/check_in.dart';
import 'package:loomia/l10n/app_localizations.dart';
import 'package:material_ui/material_ui.dart';

/// `CATCH UP`: its header and one row per member who might need you.
/// Nothing when [due] is empty. With [onToggle] (Today's single column) the
/// header says Show or Hide and, [collapsed], one summary line stands in for
/// the rows; without it (the desktop side column) the rows always show.
List<Widget> checkInItems(
  AppLocalizations l10n,
  List<CheckIn> due, {
  required void Function(Person person) onOpen,
  required void Function(Person person) onCheckIn,
  bool collapsed = false,
  VoidCallback? onToggle,
}) => [
  if (due.isNotEmpty) ...[
    SectionHeader(
      title: l10n.teamSectionCheckIn,
      actionLabel: onToggle == null
          ? null
          : collapsed
          ? l10n.todayCatchUpShow
          : l10n.todayCatchUpHide,
      onAction: onToggle,
    ),
    FoldBody(
      folded: collapsed && onToggle != null,
      summary: PeopleSummary(
        names: [for (final checkIn in due) checkIn.person.name],
        label: l10n.todayCatchUpSummary(due.length),
        onTap: onToggle ?? () {},
      ),
      rows: [
        for (final checkIn in due)
          ActionItem(
            name: checkIn.person.name,
            photoPath: checkIn.person.photoPath,
            reason: checkInReason(l10n, checkIn),
            chip: DateChip(switch (checkIn.reason) {
              CheckInReason.isNew => l10n.teamChipNew,
              CheckInReason.quiet => l10n.teamChipQuiet(
                checkIn.days ~/ quietAfterDays,
              ),
            }),
            onOpen: () => onOpen(checkIn.person),
            onResolve: () => onCheckIn(checkIn.person),
            resolveLabel: l10n.logTitle(firstName(checkIn.person)),
          ),
      ],
    ),
  ],
];

/// A folded section's body (Catch up, the Calendar's People block): the
/// summary line, or the rows. The height eases between the two, so what's
/// below follows instead of jumping (240ms).
class FoldBody extends StatelessWidget {
  const FoldBody({
    required this.folded,
    required this.summary,
    required this.rows,
    super.key,
  });

  final bool folded;
  final Widget summary;
  final List<Widget> rows;

  @override
  Widget build(BuildContext context) => AnimatedSize(
    duration: context.motion(AppMotion.medium),
    curve: AppMotion.standard,
    alignment: Alignment.topCenter,
    child: folded
        ? summary
        : Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: AppSpacing.ms,
            children: rows,
          ),
  );
}

/// The folded section: their faces and how many. One button for a screen
/// reader, so the count is not read twice. Also the Calendar's folded
/// People block (#378).
class PeopleSummary extends StatelessWidget {
  const PeopleSummary({
    required this.names,
    required this.label,
    required this.onTap,
    super.key,
  });

  final List<String> names;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: label,
    excludeSemantics: true,
    child: Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        // As on the rows it stands for.
        hoverColor: LoomiaColors.of(context).surfaceSunken,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(
            spacing: AppSpacing.ms,
            children: [
              LoomiaAvatarGroup(names: names),
              Expanded(
                child: Text(
                  label,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

/// Why [checkIn]'s member is worth catching up with, in plain words.
String checkInReason(AppLocalizations l10n, CheckIn checkIn) {
  final (:person, :reason, :since, :days) = checkIn;
  return switch (reason) {
    CheckInReason.isNew when days <= 0 => l10n.teamReasonNewToday,
    CheckInReason.isNew when days < 7 => l10n.teamReasonNewDays(days),
    CheckInReason.isNew => l10n.teamReasonNewWeeks(days ~/ 7),
    CheckInReason.quiet when person.lastContactOn != null =>
      l10n.teamReasonQuiet(since),
    // Never logged, counted from the day they were added: the import.
    CheckInReason.quiet when since.isAfter(joinedOn(person)) =>
      l10n.teamReasonQuietAdded(since),
    CheckInReason.quiet => l10n.teamReasonQuietNothing(since),
  };
}

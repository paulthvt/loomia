import 'package:loomia/app/theme/app_colors.dart';
import 'package:loomia/app/theme/app_spacing.dart';
import 'package:loomia/app/theme/app_theme.dart';
import 'package:loomia/core/ui/action_item.dart';
import 'package:loomia/core/ui/loomia_avatar.dart';
import 'package:loomia/core/ui/section_header.dart';
import 'package:loomia/features/contacts/domain/person.dart';
import 'package:loomia/features/team/domain/check_in.dart';
import 'package:loomia/l10n/app_localizations.dart';
import 'package:material_ui/material_ui.dart';

/// `CATCH UP`: its header and one row per member who might need you.
/// Nothing when [due] is empty. With [onToggle] (Today's single column) the
/// header says Show or Hide and, [collapsed], one summary line stands in for
/// the rows; without it (the desktop side column) the rows always show.
///
/// [onNotNow] puts people off for a month (#481): a row's Not now, a swipe on
/// a row where there is [onToggle] (a phone or tablet), or the summary's Not
/// now for all of them. It answers whether the write went through, so a
/// swiped row comes back when it did not.
List<Widget> checkInItems(
  AppLocalizations l10n,
  List<CheckIn> due, {
  required void Function(Person person) onOpen,
  required void Function(Person person) onCheckIn,
  required Future<bool> Function(List<Person> people) onNotNow,
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
        trailing: TextButton(
          onPressed: () => onNotNow([for (final c in due) c.person]),
          child: Text(l10n.todayCatchUpNotNow),
        ),
      ),
      rows: [
        for (final checkIn in due)
          _swipeable(
            checkIn.person,
            enabled: onToggle != null,
            onNotNow: onNotNow,
            label: l10n.todayCatchUpNotNow,
            child: Builder(
              builder: (context) => ActionItem(
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
                actions: [
                  FilledButton.tonal(
                    style: AppTheme.tonal(context),
                    onPressed: () => onCheckIn(checkIn.person),
                    child: Text(l10n.contactLogSomething),
                  ),
                  TextButton(
                    onPressed: () => onNotNow([checkIn.person]),
                    child: Text(l10n.todayCatchUpNotNow),
                  ),
                ],
              ),
            ),
          ),
      ],
    ),
  ],
];

/// A swipe either way says Not now; the row slides back if it failed.
Widget _swipeable(
  Person person, {
  required bool enabled,
  required Future<bool> Function(List<Person> people) onNotNow,
  required String label,
  required Widget child,
}) => !enabled
    ? child
    : Dismissible(
        key: ValueKey('catch-up-${person.id}'),
        confirmDismiss: (_) => onNotNow([person]),
        background: _SwipeBackground(label, Alignment.centerLeft),
        secondaryBackground: _SwipeBackground(label, Alignment.centerRight),
        child: child,
      );

/// What a swiped row uncovers: Not now, on the side it leaves from.
class _SwipeBackground extends StatelessWidget {
  const _SwipeBackground(this.label, this.alignment);

  final String label;
  final Alignment alignment;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: LoomiaColors.of(context).surfaceSunken,
      borderRadius: BorderRadius.circular(AppRadii.lg),
    ),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      child: Align(
        alignment: alignment,
        child: Text(label, style: Theme.of(context).textTheme.labelLarge),
      ),
    ),
  );
}

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
    this.trailing,
    super.key,
  });

  final List<String> names;
  final String label;
  final VoidCallback onTap;

  /// A button at the line's end, outside its tap: Catch up's Not now.
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final line = Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
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
    );
    return Container(
      decoration: AppTheme.card(context),
      clipBehavior: Clip.antiAlias,
      child: trailing == null
          ? line
          : Row(
              children: [
                Expanded(child: line),
                Padding(
                  padding: const EdgeInsets.only(right: AppSpacing.sm),
                  child: trailing,
                ),
              ],
            ),
    );
  }
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

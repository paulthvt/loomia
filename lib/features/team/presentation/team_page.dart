import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loomia/app/shell/app_shell.dart';
import 'package:loomia/app/theme/app_colors.dart';
import 'package:loomia/app/theme/app_spacing.dart';
import 'package:loomia/app/theme/app_typography.dart';
import 'package:loomia/core/layout/breakpoints.dart';
import 'package:loomia/core/layout/content_columns.dart';
import 'package:loomia/core/ui/contact_row.dart';
import 'package:loomia/core/ui/empty_state.dart';
import 'package:loomia/core/ui/loomia_avatar.dart';
import 'package:loomia/core/ui/loomia_chip.dart';
import 'package:loomia/core/ui/loomia_top_bar.dart';
import 'package:loomia/core/ui/pick_day.dart';
import 'package:loomia/core/ui/section_header.dart';
import 'package:loomia/features/auth/data/auth_repository.dart';
import 'package:loomia/features/contacts/domain/person.dart';
import 'package:loomia/features/contacts/presentation/contacts_page.dart';
import 'package:loomia/features/contacts/presentation/log_activity_sheet.dart';
import 'package:loomia/features/contacts/presentation/people_controller.dart';
import 'package:loomia/features/contacts/presentation/people_copy.dart';
import 'package:loomia/features/team/domain/check_in.dart';
import 'package:loomia/features/team/presentation/check_in_items.dart';
import 'package:loomia/features/workflows/domain/progress.dart';
import 'package:loomia/l10n/app_localizations.dart';
import 'package:material_ui/material_ui.dart';

/// "Team · joined 3 weeks ago": days for a week, weeks up to 8, then the
/// month. Counted on the device's calendar, so a UTC [since] is read locally.
String joinedLabel(AppLocalizations l10n, DateTime since, DateTime today) {
  final local = since.toLocal();
  return switch (daysBetween(local, today)) {
    <= 0 => l10n.teamJoinedToday,
    1 => l10n.teamJoinedYesterday,
    < 7 && final days => l10n.teamJoinedDaysAgo(days),
    <= 56 && final days => l10n.teamJoinedWeeksAgo(days ~/ 7),
    _ => l10n.teamJoinedIn(local),
  };
}

/// "Team · talked yesterday" once something is logged since they joined;
/// until then, when they joined.
String rosterLabel(AppLocalizations l10n, Person person, DateTime today) {
  final last = person.lastContactOn;
  if (last == null || !talkedSinceJoining(person)) {
    return joinedLabel(l10n, person.stageSince, today);
  }
  return switch (daysBetween(last, today)) {
    <= 0 => l10n.teamTalkedToday,
    1 => l10n.teamTalkedYesterday,
    < 7 && final days => l10n.teamTalkedDaysAgo(days),
    <= 56 && final days => l10n.teamTalkedWeeksAgo(days ~/ 7),
    _ => l10n.teamTalkedIn(last),
  };
}

/// The team, read from the book the Contacts tab already holds.
class TeamPage extends ConsumerWidget {
  const TeamPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final book = peopleProvider(ref.watch(accountProvider)?.email);
    return TeamView(
      people: ref.watch(book),
      today: today(),
      // With a sidebar, Settings is its account block instead.
      accountAction: context.screenSize.usesSideNavigation
          ? IconButton(
              onPressed: () => refreshPeople(context, ref),
              tooltip: AppLocalizations.of(context).contactsRefresh,
              icon: const Icon(Icons.refresh_rounded),
            )
          : const AccountButton(),
      onOpen: (person) => openContact(context, person.id),
      onRetry: () => ref.invalidate(book),
      // Saving reloads the book, so they leave the check-ins.
      onCheckIn: (person) => unawaited(showLogActivity(context, person)),
      onRefresh: () => refreshPeople(context, ref),
    );
  }
}

/// Who on the team might need the user, never who is performing
/// (`docs/design/screens.md` §4). The screen as a function of its inputs, so
/// it can be previewed and tested without providers. One column on every size.
class TeamView extends StatelessWidget {
  const TeamView({
    required this.people,
    required this.today,
    required this.onOpen,
    required this.onRetry,
    required this.onCheckIn,
    required this.onRefresh,
    this.accountAction,
    super.key,
  });

  /// The whole book; the team is everyone at [Stage.team], in its order.
  final AsyncValue<List<Person>> people;

  /// Local midnight: how long ago each member joined or last talked.
  final DateTime today;

  final void Function(Person person) onOpen;
  final VoidCallback onRetry;

  /// The circle on a check-in: log something with them.
  final void Function(Person person) onCheckIn;
  final Future<void> Function() onRefresh;

  /// Top-bar entry to Settings, where there is no sidebar to hold it.
  final Widget? accountAction;

  /// Per `docs/design/responsive-design.md`: the same column as Today.
  static const double _column = 624;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final desktop = context.screenSize.isDesktop;

    return Scaffold(
      body: SafeArea(
        child: Align(
          alignment: AlignmentDirectional.topStart,
          child: ConstrainedBox(
            // Desktop: ContentColumns caps and centres the two columns.
            constraints: BoxConstraints(
              maxWidth: desktop ? double.infinity : _column,
            ),
            child: RefreshIndicator(
              onRefresh: onRefresh,
              child: ListView(
                // Pull to refresh works on a short list too.
                physics: const AlwaysScrollableScrollPhysics(),
                padding: desktop
                    ? const EdgeInsets.symmetric(
                        horizontal: AppSpacing.xxl,
                        vertical: AppSpacing.xl,
                      )
                    : const EdgeInsets.all(AppSpacing.md),
                children: [
                  ContentColumns.aligned(
                    LoomiaTopBar(
                      title: l10n.teamTitle,
                      large: desktop,
                      action: accountAction,
                    ),
                  ),
                  ...switch (people) {
                    // `.value` survives a failed refresh, so the rows stay.
                    AsyncValue(value: final book?) => _layout(
                      l10n,
                      desktop,
                      _team(l10n, [
                        for (final person in book)
                          if (person.stage == Stage.team) person,
                      ]),
                    ),
                    AsyncError() => [
                      EmptyState(
                        icon: Icons.cloud_off_outlined,
                        title: l10n.teamLoadFailed,
                        body: l10n.contactsLoadErrorBody,
                        actionLabel: l10n.contactsRetry,
                        onAction: onRetry,
                      ),
                    ],
                    _ => const [Center(child: CircularProgressIndicator())],
                  },
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Mobile: summary, check-ins, roster. Desktop: the roster, with the
  /// summary and check-ins beside it.
  List<Widget> _layout(
    AppLocalizations l10n,
    bool desktop,
    ({List<Widget> summary, List<Widget> checks, List<Widget> roster})? parts,
  ) {
    if (parts == null) {
      return [
        EmptyState(
          icon: Icons.diversity_3_outlined,
          title: l10n.teamEmptyTitle,
          body: l10n.teamEmptyBody,
        ),
      ];
    }
    final (:summary, :checks, :roster) = parts;
    if (desktop) {
      return [
        ContentColumns(
          main: roster,
          side: [
            ...summary,
            if (checks.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.lg),
              ...checks,
            ],
          ],
        ),
      ];
    }
    return [
      ...summary,
      if (checks.isNotEmpty) ...[
        const SizedBox(height: AppSpacing.lg),
        ...checks,
      ],
      const SizedBox(height: AppSpacing.lg),
      ...roster,
    ];
  }

  /// The team's three parts, or null when there is nobody on it.
  ({List<Widget> summary, List<Widget> checks, List<Widget> roster})? _team(
    AppLocalizations l10n,
    List<Person> team,
  ) {
    if (team.isEmpty) return null;
    final due = checkIns(team, today);
    return (
      summary: [_Summary(team: team, checkIns: due.length)],
      checks: checkInItems(l10n, due, onOpen: onOpen, onCheckIn: onCheckIn),
      roster: [
        SectionHeader(
          title: l10n.teamSectionEveryone,
          actionLabel: '${team.length}',
        ),
        for (final person in team)
          ContactRow(
            name: person.name,
            subtitle: rosterLabel(l10n, person, today),
            trailing: LoomiaChip(label: stageLabel(l10n, person.stage)),
            onTap: () => onOpen(person),
          ),
      ],
    );
  }
}

/// How many, who, and the rule said out loud. No totals, no scores.
class _Summary extends StatelessWidget {
  const _Summary({required this.team, required this.checkIns});

  final List<Person> team;

  /// How many are worth a check-in: the paragraph says it first.
  final int checkIns;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = LoomiaColors.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    l10n.teamCount(team.length),
                    style: AppTypography.title.copyWith(
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                // The heading already says how many, in the user's language.
                ExcludeSemantics(
                  child: LoomiaAvatarGroup(
                    names: [for (final p in team) p.name],
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.ms),
            Text(
              // Two whole sentences, so no translation is split.
              '${l10n.teamCheckInSummary(checkIns)} ${l10n.teamNotMeasured}',
              style: Theme.of(context).textTheme.bodyMedium
                  ?.copyWith(color: colors.textMuted),
            ),
          ],
        ),
      ),
    );
  }
}

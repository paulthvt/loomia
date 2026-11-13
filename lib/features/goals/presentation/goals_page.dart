import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:loomia/app/router/routes.dart';
import 'package:loomia/app/shell/app_shell.dart';
import 'package:loomia/app/theme/app_colors.dart';
import 'package:loomia/app/theme/app_spacing.dart';
import 'package:loomia/app/theme/app_typography.dart';
import 'package:loomia/core/business_model/business_model.dart';
import 'package:loomia/core/layout/breakpoints.dart';
import 'package:loomia/core/layout/content_columns.dart';
import 'package:loomia/core/ui/empty_state.dart';
import 'package:loomia/core/ui/hero_panel.dart';
import 'package:loomia/core/ui/load_failed.dart';
import 'package:loomia/core/ui/loomia_top_bar.dart';
import 'package:loomia/core/ui/pick_day.dart';
import 'package:loomia/core/ui/section_header.dart';
import 'package:loomia/core/ui/stat_tile.dart';
import 'package:loomia/features/auth/data/auth_repository.dart';
import 'package:loomia/features/contacts/domain/people_failure.dart';
import 'package:loomia/features/goals/domain/goal_rules.dart';
import 'package:loomia/features/goals/domain/month_plan.dart';
import 'package:loomia/features/goals/presentation/goals_controller.dart';
import 'package:loomia/features/goals/presentation/orders_sheet.dart';
import 'package:loomia/features/goals/presentation/ritual_card.dart';
import 'package:loomia/features/goals/presentation/volume_card.dart';
import 'package:loomia/l10n/app_localizations.dart';
import 'package:material_ui/material_ui.dart';

/// The month's own goals: what the user aimed for and what their book did.
/// Never compared with anyone (design principle #5).
class GoalsPage extends ConsumerWidget {
  const GoalsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final account = ref.watch(accountProvider);
    final provider = goalsProvider(account?.email);
    return GoalsView(
      month: ref.watch(provider),
      today: today(),
      model: account?.businessModel ?? BusinessModel.other,
      onPlan: () => context.push(Routes.goalsPlan),
      onRetry: () => ref.invalidate(provider),
      onRefresh: () => ref.refresh(provider.future),
      onRitual: () => context.push(Routes.goalsClose),
      onOrders: () =>
          unawaited(showOrders(context, DateTime(today().year, today().month))),
      // With a sidebar, Settings is its account block instead.
      accountAction: context.screenSize.usesSideNavigation
          ? null
          : const AccountButton(),
    );
  }
}

/// The screen as a function of its inputs, for tests and previews. One
/// 624px column on every size, like Today.
class GoalsView extends StatelessWidget {
  const GoalsView({
    required this.month,
    required this.today,
    required this.model,
    required this.onPlan,
    required this.onRetry,
    required this.onRefresh,
    required this.onOrders,
    required this.onRitual,
    this.accountAction,
    super.key,
  });

  final AsyncValue<GoalsMonth> month;

  /// The device's day: days left, pace.
  final DateTime today;
  final BusinessModel model;
  final VoidCallback onPlan;
  final VoidCallback onRetry;
  final Future<void> Function() onRefresh;

  /// Opens the month's orders: the volume card's tap.
  final VoidCallback onOrders;

  /// Opens /goals/close.
  final VoidCallback onRitual;
  final Widget? accountAction;

  /// Per `docs/design/responsive-design.md`, as on Today.
  static const double _column = 624;

  /// The hero card beside the title on desktop, as on Today.
  static const double _heroCardWidth = 440;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final desktop = context.screenSize.isDesktop;
    final daysLeft = DateTime(today.year, today.month + 1, 0).day - today.day;
    final ritual = switch (month) {
      AsyncData(:final value) => pendingRitual(today, value.plans),
      _ => null,
    };
    // Planning this month alone is the empty state's job.
    final showRitual =
        ritual != null && (ritual.closes || month.value?.month != ritual.plan);

    final plan = month.value?.plan;
    final heroCard = switch (month) {
      AsyncData(:final value) when plan != null => HeroCard(
        child: OwnVolumeHero(
          month: value,
          today: today,
          model: model,
          // Desktop lists the orders beside the card already.
          onTap: desktop ? null : onOrders,
          onPlan: plan.closed ? null : onPlan,
        ),
      ),
      _ => null,
    };
    final topBar = Semantics(
      container: true,
      child: LoomiaTopBar(
        eyebrow: l10n.goalsDaysLeft(daysLeft, today),
        title: l10n.goalsTitle,
        large: desktop,
        action: accountAction,
        gap: 0,
        onHero: true,
      ),
    );
    final content = <Widget>[
      // Desktop's dashboard has it in the side column.
      if (showRitual && !(desktop && plan != null)) ...[
        ritualInvitation(ritual, onRitual),
        const SizedBox(height: AppSpacing.md),
      ],
      ...switch (month) {
        AsyncData(:final value) when value.plan == null => [
          EmptyState(
            icon: Icons.flag_outlined,
            title: l10n.goalsEmptyTitle,
            body: l10n.goalsEmptyBody(value.month),
            actionLabel: l10n.goalsPlanMonth(value.month),
            onAction: onPlan,
          ),
        ],
        AsyncData(:final value) => switch (_dashboard(context, value)) {
          (:final main, :final past) when desktop => [
            ContentColumns(
              main: main,
              side: [
                if (showRitual) ...[
                  ritualInvitation(ritual, onRitual),
                  const SizedBox(height: AppSpacing.lg),
                ],
                SectionHeader(title: l10n.ordersTitle(value.month)),
                OrdersList(month: value.month),
                ...past,
              ],
            ),
          ],
          (:final main, :final past) => [...main, ...past],
        },
        AsyncError(:final error) => [
          LoadFailed(
            offline: error == PeopleFailure.network,
            title: l10n.goalsLoadFailed,
            onRetry: onRetry,
          ),
        ],
        _ => const [Center(child: CircularProgressIndicator())],
      },
    ];
    final bottom = MediaQuery.paddingOf(context).bottom;

    final list = desktop
        ? ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.xxl,
              vertical: AppSpacing.xl,
            ).add(EdgeInsets.only(bottom: bottom)),
            children: [
              HeroPanel(
                shape: HeroShape.band,
                padding: const EdgeInsets.all(AppSpacing.xl),
                children: [
                  Row(
                    children: [
                      Expanded(child: topBar),
                      if (heroCard != null) ...[
                        const SizedBox(width: AppSpacing.lg),
                        SizedBox(width: _heroCardWidth, child: heroCard),
                      ],
                    ],
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              ...content,
            ],
          )
        : ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            // The list runs under the floating bar, padded by its room.
            padding: EdgeInsets.only(bottom: AppSpacing.md + bottom),
            children: [
              // From the screen's top edge, under the status bar.
              HeroPanel(gap: AppSpacing.md, children: [topBar, ?heroCard]),
              const SizedBox(height: AppSpacing.lg),
              for (final piece in content)
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                  ),
                  child: piece,
                ),
            ],
          );

    return Scaffold(
      body: SafeArea(
        // A phone's hero paints under the status bar and pads itself.
        top: desktop,
        bottom: false,
        child: Align(
          alignment: AlignmentDirectional.topStart,
          child: ConstrainedBox(
            // Desktop: ContentColumns caps and centres the two columns.
            constraints: BoxConstraints(
              maxWidth: desktop ? double.infinity : _column,
            ),
            child: RefreshIndicator(
              onRefresh: onRefresh,
              edgeOffset: desktop ? 0 : MediaQuery.paddingOf(context).top,
              child: list,
            ),
          ),
        ),
      ),
    );
  }

  /// The month against its plan, and the closed months, apart: desktop
  /// puts the closed months in the side column.
  ({List<Widget> main, List<Widget> past}) _dashboard(
    BuildContext context,
    GoalsMonth month,
  ) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final colors = LoomiaColors.of(context);
    final number = NumberFormat.decimalPattern(l10n.localeName);
    final plan = month.plan!;
    final done = month.progress;

    Widget count(String label, int value, int? aimed) => StatTile(
      label: label,
      value: '$value',
      note: aimed == null ? null : l10n.goalAimedFor(aimed),
    );
    Widget pair(Widget start, Widget end) => IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(child: start),
          const SizedBox(width: AppSpacing.ms),
          Expanded(child: end),
        ],
      ),
    );
    Widget note(String line, String below) => Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(line, style: theme.textTheme.titleMedium),
            const SizedBox(height: AppSpacing.xs),
            Text(
              below,
              style: AppTypography.caption.copyWith(color: colors.textMuted),
            ),
          ],
        ),
      ),
    );

    final loyaltyNote = [
      if (plan.loyaltyTarget case final aimed?) l10n.goalLoyaltyOf(aimed),
      if (month.forecast > 0) l10n.goalMoreLikely(month.forecast),
    ].join(' · ');
    final declared = [
      if (plan.levelTarget case final level?) l10n.goalAimingFor(level),
      if (plan.teamVolumeTarget case final volume?)
        l10n.goalTeamVolume(model.name, number.format(volume)),
    ].join(' · ');
    final past = [
      for (final closed in month.plans)
        if (closed.closed && closed.month != month.month) closed,
    ];

    final main = <Widget>[
      pair(
        count(l10n.goalNewProspects, done.prospects, plan.prospectsTarget),
        count(l10n.goalNewCustomers, done.customers, plan.customersTarget),
      ),
      const SizedBox(height: AppSpacing.ms),
      pair(
        count(
          l10n.goalNewTeamMembers,
          done.teamMembers,
          plan.teamMembersTarget,
        ),
        StatTile(
          label: l10n.goalLoyalty(model.name),
          value: '${done.loyalty}',
          note: loyaltyNote.isEmpty ? null : loyaltyNote,
        ),
      ),
      if (declared.isNotEmpty) ...[
        const SizedBox(height: AppSpacing.md),
        note(declared, l10n.goalDeclaredNote),
      ],
    ];
    final pastWidgets = <Widget>[
      if (past.isNotEmpty) ...[
        const SizedBox(height: AppSpacing.md),
        SectionHeader(title: l10n.goalPastMonths),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: AppSpacing.ms,
              children: [
                for (final closed in past)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.goalPastMonth(closed.month),
                        style: AppTypography.caption.copyWith(
                          color: colors.textMuted,
                        ),
                      ),
                      Text(
                        _pastLine(l10n, number, closed),
                        style: theme.textTheme.bodyLarge,
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ],
    ];
    return (main: main, past: pastWidgets);
  }

  /// "2 410 of 2 500 PV · Elite reached": the month's own volume against
  /// its target, then the level typed at close.
  String _pastLine(
    AppLocalizations l10n,
    NumberFormat number,
    MonthPlan closed,
  ) {
    final actual = number.format(closed.actual?.ownVolume ?? 0);
    final target = closed.ownVolumeTarget;
    return [
      target == null
          ? l10n.goalPastVolumeAlone(model.name, actual)
          : l10n.goalPastVolume(model.name, actual, number.format(target)),
      if (closed.levelActual case final level?)
        level == closed.levelTarget ? l10n.goalLevelReached(level) : level,
    ].join(' · ');
  }
}

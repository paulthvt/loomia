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
import 'package:loomia/core/ui/empty_state.dart';
import 'package:loomia/core/ui/goal_card.dart';
import 'package:loomia/core/ui/loomia_top_bar.dart';
import 'package:loomia/core/ui/pick_day.dart';
import 'package:loomia/core/ui/section_header.dart';
import 'package:loomia/core/ui/stat_tile.dart';
import 'package:loomia/features/auth/data/auth_repository.dart';
import 'package:loomia/features/contacts/presentation/log_activity_sheet.dart';
import 'package:loomia/features/goals/domain/goal_rules.dart';
import 'package:loomia/features/goals/domain/month_plan.dart';
import 'package:loomia/features/goals/presentation/goals_controller.dart';
import 'package:loomia/features/goals/presentation/orders_sheet.dart';
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
      onLogOrder: () {
        final container = ProviderScope.containerOf(context, listen: false);
        unawaited(
          showLogOwnOrder(context, onSaved: () => refreshOrders(container)),
        );
      },
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
    required this.onLogOrder,
    required this.onOrders,
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

  /// Opens Your own order.
  final VoidCallback onLogOrder;

  /// Opens the month's orders: the volume card's tap.
  final VoidCallback onOrders;
  final Widget? accountAction;

  /// Per `docs/design/responsive-design.md`, as on Today.
  static const double _column = 624;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final desktop = context.screenSize.isDesktop;
    final daysLeft = DateTime(today.year, today.month + 1, 0).day - today.day;

    return Scaffold(
      body: SafeArea(
        child: Align(
          alignment: AlignmentDirectional.topStart,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: _column),
            child: RefreshIndicator(
              onRefresh: onRefresh,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: desktop
                    ? const EdgeInsets.symmetric(
                        horizontal: AppSpacing.xxl,
                        vertical: AppSpacing.xl,
                      )
                    : const EdgeInsets.all(AppSpacing.md),
                children: [
                  LoomiaTopBar(
                    eyebrow: l10n.goalsDaysLeft(daysLeft, today),
                    title: l10n.goalsTitle,
                    large: desktop,
                    action: accountAction,
                    gap: AppSpacing.sm,
                  ),
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
                    AsyncData(:final value) => _dashboard(context, value),
                    AsyncError() => [
                      EmptyState(
                        icon: Icons.cloud_off_outlined,
                        title: l10n.goalsLoadFailed,
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

  List<Widget> _dashboard(BuildContext context, GoalsMonth month) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final colors = LoomiaColors.of(context);
    final number = NumberFormat.decimalPattern(l10n.localeName);
    final plan = month.plan!;
    final done = month.progress;
    final daysLeft = DateTime(today.year, today.month + 1, 0).day - today.day;
    final target = plan.ownVolumeTarget;
    final hasTarget = target != null && target > 0;
    final pacing = pace(hasTarget ? target : null, done.ownVolume, today);

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
            Text(line, style: theme.textTheme.bodyLarge),
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

    return [
      GoalCard(
        title: l10n.goalOwnVolume,
        value: number.format(done.ownVolume),
        suffix: hasTarget
            ? l10n.goalVolumeOf(model.name, number.format(target))
            : l10n.goalVolumeAlone(model.name),
        progress: hasTarget ? done.ownVolume / target : null,
        pace: switch (pacing) {
          null => null,
          (onPace: true, projected: _) => l10n.goalOnPace,
          _ => l10n.goalBehindPace,
        },
        behindPace: pacing?.onPace == false,
        leading: hasTarget
            ? l10n.goalPercentPlanned((done.ownVolume / target * 100).round())
            : null,
        timeLeft: hasTarget ? l10n.goalDaysLeft(daysLeft) : null,
        onTap: onOrders,
      ),
      const SizedBox(height: AppSpacing.md),
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
      if (pacing != null) ...[
        const SizedBox(height: AppSpacing.md),
        note(
          l10n.goalPaceProjection(
            model.name,
            number.format(pacing.projected.round()),
          ),
          l10n.goalPaceNote,
        ),
      ],
      const SizedBox(height: AppSpacing.md),
      FilledButton.tonalIcon(
        onPressed: onLogOrder,
        icon: const Icon(Icons.add_rounded),
        label: Text(l10n.goalLogOwnOrder),
      ),
      const SizedBox(height: AppSpacing.sm),
      Align(
        alignment: AlignmentDirectional.centerStart,
        child: TextButton(onPressed: onPlan, child: Text(l10n.goalChangePlan)),
      ),
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

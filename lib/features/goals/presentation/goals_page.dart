import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:loomia/app/router/routes.dart';
import 'package:loomia/app/shell/app_shell.dart';
import 'package:loomia/app/theme/app_spacing.dart';
import 'package:loomia/core/business_model/business_model.dart';
import 'package:loomia/core/layout/breakpoints.dart';
import 'package:loomia/core/ui/empty_state.dart';
import 'package:loomia/core/ui/loomia_top_bar.dart';
import 'package:loomia/core/ui/pick_day.dart';
import 'package:loomia/features/auth/data/auth_repository.dart';
import 'package:loomia/features/goals/presentation/goals_controller.dart';
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

  /// Task 4.
  List<Widget> _dashboard(BuildContext context, GoalsMonth month) => const [];
}

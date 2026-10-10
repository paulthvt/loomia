import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loomia/app/router/back.dart';
import 'package:loomia/app/router/routes.dart';
import 'package:loomia/core/business_model/business_model.dart';
import 'package:loomia/core/ui/empty_state.dart';
import 'package:loomia/core/ui/load_failed.dart';
import 'package:loomia/core/ui/pick_day.dart';
import 'package:loomia/features/auth/data/auth_repository.dart';
import 'package:loomia/features/contacts/domain/people_failure.dart';
import 'package:loomia/features/goals/data/goals_repository.dart';
import 'package:loomia/features/goals/domain/month_plan.dart';
import 'package:loomia/features/goals/presentation/close_form.dart';
import 'package:loomia/features/goals/presentation/goals_controller.dart';
import 'package:loomia/features/goals/presentation/plan_page.dart';
import 'package:loomia/l10n/app_localizations.dart';
import 'package:material_ui/material_ui.dart';

/// The month-end ritual, full screen: step 1 closes the month (when it was
/// planned and isn't closed yet), step 2 plans the next. The step is local
/// state: closing can't be undone, so back on step 2 leaves.
class ClosePage extends ConsumerStatefulWidget {
  const ClosePage({this.day, this.onDone, super.key});

  /// Today unless a test pins it.
  final DateTime? day;

  /// After the plan is saved, or from "Back to Goals". Defaults to going back
  /// to Goals.
  final VoidCallback? onDone;

  @override
  ConsumerState<ClosePage> createState() => _ClosePageState();
}

class _ClosePageState extends ConsumerState<ClosePage> {
  late final DateTime _day = widget.day ?? today();

  /// What step 1 closed this visit; null before.
  MonthPlan? _closed;

  void _done() => (widget.onDone ?? () => backOr(context, Routes.goals))();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final account = ref.watch(accountProvider);
    final model = account?.businessModel ?? BusinessModel.other;
    final provider = closingProvider((email: account?.email, day: _day));
    final closing = ref.watch(provider);
    final container = ProviderScope.containerOf(context, listen: false);

    return Scaffold(
      appBar: AppBar(
        leading: BackButton(onPressed: () => backOr(context, Routes.goals)),
      ),
      body: SafeArea(
        child: switch (closing) {
          AsyncValue(value: null, hasValue: true) => EmptyState(
            icon: Icons.flag_outlined,
            title: l10n.closeNothing,
            body: l10n.closeNothingBody,
            actionLabel: l10n.closeBackToGoals,
            onAction: _done,
          ),
          AsyncValue(value: final value?)
              when value.ritual.closes && _closed == null =>
            CloseForm(
              closing: value,
              model: model,
              onClose: ({teamVolume, level}) async {
                final closed = await container
                    .read(goalsRepositoryProvider)
                    .close(
                      value.ritual.close,
                      teamVolume: teamVolume,
                      level: level,
                    );
                container.invalidate(goalsProvider);
                if (mounted) setState(() => _closed = closed);
              },
            ),
          AsyncValue(value: final value?) => PlanForm(
            step: value.ritual.closes ? 2 : null,
            month: (
              month: value.ritual.plan,
              plan: value.plans
                  .where((plan) => plan.month == value.ritual.plan)
                  .firstOrNull,
              // Planning reads no progress.
              progress: const Progress(
                ownVolume: 0,
                prospects: 0,
                customers: 0,
                teamMembers: 0,
                loyalty: 0,
              ),
              forecast: value.forecast,
              // The month just closed counts toward the suggestions.
              plans: [
                for (final plan in value.plans)
                  if (plan.month != _closed?.month) plan,
                ?_closed,
              ],
            ),
            model: model,
            // savePlan reloads Goals. This page's own load dies with it:
            // reloading it now would show "Nothing to close" on the way out.
            onSave: (plan) => savePlan(container, plan),
            onSaved: _done,
          ),
          AsyncError(:final error) => LoadFailed(
            offline: error == PeopleFailure.network,
            title: l10n.goalsLoadFailed,
            onRetry: () => ref.invalidate(provider),
          ),
          _ => const Center(child: CircularProgressIndicator()),
        },
      ),
    );
  }
}

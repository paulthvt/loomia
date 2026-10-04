import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loomia/app/theme/app_colors.dart';
import 'package:loomia/core/business_model/business_model.dart';
import 'package:loomia/core/ui/activity_item.dart';
import 'package:loomia/core/ui/loomia_dialog.dart';
import 'package:loomia/core/ui/pick_day.dart';
import 'package:loomia/features/auth/data/auth_repository.dart';
import 'package:loomia/features/contacts/data/activity_repository.dart';
import 'package:loomia/features/contacts/domain/activity.dart';
import 'package:loomia/features/contacts/domain/people_failure.dart';
import 'package:loomia/features/contacts/presentation/history_controller.dart';
import 'package:loomia/features/contacts/presentation/people_controller.dart';
import 'package:loomia/features/contacts/presentation/people_copy.dart';
import 'package:loomia/features/goals/presentation/goals_controller.dart';
import 'package:loomia/l10n/app_localizations.dart';
import 'package:material_ui/material_ui.dart';

/// [month]'s orders, contacts' and own, each deletable: a sheet on mobile, a
/// dialog elsewhere.
Future<void> showOrders(BuildContext context, DateTime month) =>
    LoomiaDialog.show<void>(context, (_) => _Orders(month));

class _Orders extends ConsumerWidget {
  const _Orders(this.month);

  final DateTime month;

  Future<void> _delete(
    BuildContext context,
    WidgetRef ref,
    MonthOrder entry,
  ) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final container = ProviderScope.containerOf(context, listen: false);
    final confirmed = await confirmDestructive(
      context,
      title: l10n.historyDeleteTitle,
      action: l10n.historyDeleteConfirm,
    );
    if (!confirmed) return;
    try {
      await container.read(activityRepositoryProvider).delete(entry.order.id);
    } on PeopleFailure catch (failure) {
      messenger.showSnackBar(
        SnackBar(content: Text(peopleFailureCopy(l10n, failure))),
      );
      return;
    }
    refreshOrders(container);
    // The same entry was in that person's history, and their last contact
    // may move.
    if (entry.order.personId case final personId?) {
      container.invalidate(historyProvider(personId));
    }
    container.invalidate(
      peopleProvider(container.read(accountProvider)?.email),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final material = MaterialLocalizations.of(context);
    final colors = LoomiaColors.of(context);
    final model =
        ref.watch(accountProvider)?.businessModel ?? BusinessModel.other;
    final orders = ref.watch(ordersProvider(month));
    final day = today();
    Widget muted(String text) => Text(
      text,
      style: Theme.of(context).textTheme.bodyMedium
          ?.copyWith(color: colors.textMuted),
    );

    return LoomiaDialog(
      title: l10n.ordersTitle(month),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(material.closeButtonLabel),
        ),
      ],
      child: switch (orders) {
        AsyncValue(value: final entries?) when entries.isEmpty => muted(
          l10n.ordersEmpty,
        ),
        AsyncValue(value: final entries?) => Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final (index, entry) in entries.indexed)
              Row(
                children: [
                  Expanded(
                    child: ActivityItem(
                      title: activityTitle(l10n, entry.order, model),
                      meta: l10n.historyMeta(
                        dayLabel(l10n, entry.order.day, day),
                        entry.personName ?? l10n.ordersOwn,
                      ),
                      showRailLine: index < entries.length - 1,
                    ),
                  ),
                  IconButton(
                    tooltip: l10n.ordersRemove,
                    onPressed: () => _delete(context, ref, entry),
                    icon: const Icon(Icons.delete_outline),
                  ),
                ],
              ),
          ],
        ),
        AsyncError() => Row(
          children: [
            Expanded(child: muted(l10n.ordersLoadFailed)),
            TextButton(
              onPressed: () => ref.invalidate(ordersProvider(month)),
              child: Text(l10n.contactsRetry),
            ),
          ],
        ),
        _ => const Center(child: CircularProgressIndicator()),
      },
    );
  }
}

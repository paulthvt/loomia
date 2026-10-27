import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loomia/app/theme/app_colors.dart';
import 'package:loomia/app/theme/app_spacing.dart';
import 'package:loomia/app/theme/app_theme.dart';
import 'package:loomia/core/business_model/business_model.dart';
import 'package:loomia/core/ui/activity_item.dart';
import 'package:loomia/core/ui/animated_rows.dart';
import 'package:loomia/core/ui/fade_swap.dart';
import 'package:loomia/core/ui/loomia_dialog.dart';
import 'package:loomia/core/ui/section_header.dart';
import 'package:loomia/features/auth/data/auth_repository.dart';
import 'package:loomia/features/contacts/domain/activity.dart';
import 'package:loomia/features/contacts/domain/people_failure.dart';
import 'package:loomia/features/contacts/domain/person.dart';
import 'package:loomia/features/contacts/presentation/history_controller.dart';
import 'package:loomia/features/contacts/presentation/log_activity_sheet.dart';
import 'package:loomia/features/contacts/presentation/people_copy.dart';
import 'package:loomia/l10n/app_localizations.dart';
import 'package:material_ui/material_ui.dart';

/// `HISTORY`: the latest entries, the rest a tap away. It loads on its own,
/// so a failure here leaves the rest of the page working.
class HistorySection extends ConsumerStatefulWidget {
  const HistorySection({required this.person, required this.onAdd, super.key});

  final Person person;
  final VoidCallback onAdd;

  @override
  ConsumerState<HistorySection> createState() => _HistorySectionState();
}

class _HistorySectionState extends ConsumerState<HistorySection> {
  static const _preview = 3;
  bool _expanded = false;

  Future<void> _delete(Activity activity) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final notifier = ref.read(historyProvider(widget.person.id).notifier);
    final confirmed = await confirmDestructive(
      context,
      title: l10n.historyDeleteTitle,
      action: l10n.historyDeleteConfirm,
    );
    if (!confirmed) return;
    try {
      await notifier.remove(activity);
    } on PeopleFailure catch (failure) {
      // The controller has already put it back.
      messenger.showSnackBar(
        SnackBar(content: Text(peopleFailureCopy(l10n, failure))),
      );
    }
  }

  Future<void> _edit(Activity activity) async {
    final delete = await showEditActivity(context, widget.person, activity);
    if (delete == true && mounted) await _delete(activity);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final colors = LoomiaColors.of(context);
    final provider = historyProvider(widget.person.id);
    final history = ref.watch(provider);
    final entries = history.value;
    final shown = _expanded ? entries : entries?.take(_preview).toList();
    // Only the current stage's entry is its "since"; older ones stay.
    final latestStage = entries
        ?.where((entry) => entry.kind == ActivityKind.stage)
        .firstOrNull;
    final today = DateTime.now();
    final model =
        ref.watch(accountProvider)?.businessModel ?? BusinessModel.other;

    Widget muted(String text) => Text(
      text,
      style: theme.textTheme.bodyMedium?.copyWith(color: colors.textMuted),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeader(
          title: l10n.historyTitle,
          actionLabel: l10n.historyAdd,
          onAction: widget.onAdd,
        ),
        // Loading, failed, empty or the list: one fades into the next.
        FadeSwap(
          duration: AppMotion.quick,
          child: KeyedSubtree(
            key: ValueKey(switch (entries) {
              null when history.hasError && !history.isLoading => 'error',
              null => 'loading',
              [] => 'empty',
              _ => 'list',
            }),
            child: _body(
              context,
              history,
              entries,
              shown,
              latestStage,
              today,
              model,
              muted,
            ),
          ),
        ),
      ],
    );
  }

  Widget _body(
    BuildContext context,
    AsyncValue<List<Activity>> history,
    List<Activity>? entries,
    List<Activity>? shown,
    Activity? latestStage,
    DateTime today,
    BusinessModel model,
    Widget Function(String text) muted,
  ) {
    final l10n = AppLocalizations.of(context);
    final provider = historyProvider(widget.person.id);
    if (entries == null) {
      // A retry keeps the error while it loads: the spinner wins.
      return history.hasError && !history.isLoading
          ? Row(
              children: [
                Expanded(
                  child: muted(
                    history.error == PeopleFailure.network
                        ? l10n.offlineInline
                        : l10n.historyLoadError,
                  ),
                ),
                TextButton(
                  onPressed: () => ref.invalidate(provider),
                  child: Text(l10n.contactsRetry),
                ),
              ],
            )
          : const Padding(
              padding: EdgeInsets.all(AppSpacing.md),
              child: Center(child: CircularProgressIndicator()),
            );
    }
    if (entries.isEmpty) return muted(l10n.historyEmpty);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // After the sheet or dialog that changed it has closed, so the
        // entry is seen arriving or leaving. Keyed by See all: the rest
        // appear at once, as a new list.
        AnimatedRows(
          key: ValueKey(_expanded),
          delay: context.motion(AppMotion.slow),
          children: [
            for (final (index, activity) in shown!.indexed)
              _Entry(
                key: ValueKey(activity.id),
                activity: activity,
                today: today,
                model: model,
                last: index == shown.length - 1,
                // A loyalty entry follows the person's LRP: changed from
                // the LRP line, never here.
                onTap:
                    activity.kind.isLoyalty ||
                        (activity.kind == ActivityKind.stage &&
                            activity != latestStage)
                    ? null
                    : () => _edit(activity),
                onDelete:
                    activity.kind == ActivityKind.stage ||
                        activity.kind.isLoyalty
                    ? null
                    : () => _delete(activity),
              ),
          ],
        ),
        if (!_expanded && entries.length > _preview)
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: TextButton(
              onPressed: () => setState(() => _expanded = true),
              child: Text(l10n.historySeeAll(entries.length)),
            ),
          ),
      ],
    );
  }
}

/// One entry. Tap edits it. Long-press, right-click, or the screen reader's
/// Delete action removes it; stage entries can't be removed, and only the
/// latest opens; loyalty entries do neither.
class _Entry extends StatelessWidget {
  const _Entry({
    required this.activity,
    required this.today,
    required this.model,
    required this.last,
    required this.onTap,
    required this.onDelete,
    super.key,
  });

  final Activity activity;
  final DateTime today;
  final BusinessModel model;
  final bool last;
  final VoidCallback? onTap;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final item = ActivityItem(
      title: activityTitle(l10n, activity, model),
      meta: activityMeta(l10n, activity, today),
      showRailLine: !last,
    );
    final onDelete = this.onDelete;
    final onTap = this.onTap;
    if (onDelete == null && onTap == null) return item;
    return Semantics(
      container: true,
      onTap: onTap,
      // "Double tap to edit", not a bare "double tap to activate".
      onTapHint: onTap == null ? null : l10n.editActivityTitle,
      customSemanticsActions: onDelete == null
          ? null
          : {CustomSemanticsAction(label: l10n.historyDeleteConfirm): onDelete},
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        // The Semantics above speaks for it.
        excludeFromSemantics: true,
        onTap: onTap,
        onLongPress: onDelete,
        onSecondaryTap: onDelete,
        child: item,
      ),
    );
  }
}

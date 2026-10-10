import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:loomia/app/router/back.dart';
import 'package:loomia/app/router/routes.dart';
import 'package:loomia/app/theme/app_colors.dart';
import 'package:loomia/app/theme/app_spacing.dart';
import 'package:loomia/app/theme/app_typography.dart';
import 'package:loomia/core/layout/breakpoints.dart';
import 'package:loomia/core/ui/empty_state.dart';
import 'package:loomia/core/ui/load_failed.dart';
import 'package:loomia/core/ui/loomia_top_bar.dart';
import 'package:loomia/core/ui/pick_day.dart';
import 'package:loomia/features/auth/data/auth_repository.dart';
import 'package:loomia/features/contacts/domain/people_failure.dart';
import 'package:loomia/features/contacts/domain/person.dart';
import 'package:loomia/features/contacts/presentation/contacts_page.dart';
import 'package:loomia/features/contacts/presentation/people_controller.dart';
import 'package:loomia/features/contacts/presentation/people_copy.dart';
import 'package:loomia/features/workflows/domain/progress.dart';
import 'package:loomia/features/workflows/domain/workflow.dart';
import 'package:loomia/features/workflows/presentation/workflows_controller.dart';
import 'package:loomia/l10n/app_localizations.dart';
import 'package:material_ui/material_ui.dart';

/// A person's whole workflow, top to bottom: the steps before the current one
/// greyed, the current one ticked from here as from the card. Greyed means
/// "before", not "done": the history keeps no step ids to tell.
class WorkflowTimelinePage extends ConsumerStatefulWidget {
  const WorkflowTimelinePage({required this.id, super.key});

  final String id;

  @override
  ConsumerState<WorkflowTimelinePage> createState() =>
      _WorkflowTimelinePageState();
}

class _WorkflowTimelinePageState extends ConsumerState<WorkflowTimelinePage> {
  /// A write is in flight, as on the card.
  bool _busy = false;

  Future<void> _run(
    Future<void> Function(PeopleController people) write,
  ) async {
    if (_busy) return;
    setState(() => _busy = true);
    await writePeople(context, ref, write);
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final owner = ref.watch(accountProvider)?.email;
    final book = peopleProvider(owner);
    final people = ref.watch(book);
    final workflows = workflowsProvider(owner);
    final list = ref.watch(workflows);

    final l10n = AppLocalizations.of(context);
    final Widget body;
    if (people.value case final loaded?) {
      final person = loaded.where((p) => p.id == widget.id).firstOrNull;
      final workflow = findWorkflow(
        list.value ?? const [],
        person?.place?.workflowId,
      );
      body = switch ((person, workflow)) {
        (final person?, final workflow?) => _timeline(person, workflow),
        (null, _) => _Gone(
          title: l10n.contactMissingTitle,
          body: l10n.contactMissingBody,
          action: l10n.contactBackToContacts,
          onAction: () => context.go(Routes.contacts),
        ),
        _ when list.isLoading => const Center(
          child: CircularProgressIndicator(),
        ),
        _ when list.hasError => LoadFailed(
          offline: list.error == PeopleFailure.network,
          title: l10n.nextStepLoadFailed,
          onRetry: () => ref.invalidate(workflows),
        ),
        // Taken off the workflow, or it was deleted, elsewhere.
        (final person?, _) => _Gone(
          title: l10n.nextStepNothingPlanned,
          body: l10n.workflowTimelineGoneBody(firstName(person)),
          action: l10n.workflowTimelineBackTo(firstName(person)),
          onAction: () => backOr(context, Routes.contactLocation(widget.id)),
        ),
      };
    } else {
      body = people.hasError
          ? LoadFailed(
              offline: people.error == PeopleFailure.network,
              title: l10n.contactsLoadError,
              onRetry: () => ref.invalidate(book),
            )
          : const Center(child: CircularProgressIndicator());
    }

    return Scaffold(
      appBar: AppBar(
        leading: BackButton(
          onPressed: () => backOr(context, Routes.contactLocation(widget.id)),
        ),
      ),
      body: SafeArea(top: false, child: body),
    );
  }

  Widget _timeline(Person person, Workflow workflow) {
    final l10n = AppLocalizations.of(context);
    final steps = workflow.steps;
    final progress = progressOf(person, workflow);
    // Done: every step is behind.
    final current = switch (person.currentStepId) {
      final id? => steps.indexWhere((step) => step.id == id),
      null => steps.length,
    };
    final paused = person.pausedAt;
    final now = today();

    final desktop = context.screenSize.isDesktop;
    // ponytail: 600 matches SettingsScroll; one token if a third page wants it.
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 600),
        child: ListView(
          padding: EdgeInsets.all(desktop ? AppSpacing.xl : AppSpacing.md),
          children: [
            LoomiaTopBar(
              large: desktop,
              eyebrow: current < steps.length
                  ? l10n.workflowTimelineStep(
                      person.name,
                      current + 1,
                      steps.length,
                    )
                  : l10n.workflowTimelineDone(person.name),
              title: workflow.name,
            ),
            for (final (index, step) in steps.indexed)
              TimelineStep(
                title: step.label,
                meta: switch ((index == current, paused, progress)) {
                  (true, final since?, _) => l10n.nextStepPausedSince(
                    since.toLocal(),
                  ),
                  (true, _, final OnStep on) => _dueWithNote(l10n, on, now),
                  _ => l10n.workflowTimelineDaysLater(step.days),
                },
                first: index == 0,
                last: index == steps.length - 1,
                dimmed: index < current,
                current: index == current,
                action: switch ((index == current, paused, progress)) {
                  (false, _, _) => null,
                  (true, _?, _) => TextButton(
                    onPressed: _busy
                        ? null
                        : () => unawaited(
                            _run((people) => people.resume(person, today())),
                          ),
                    child: Text(l10n.contactResume),
                  ),
                  (true, _, final OnStep on) => IconButton(
                    onPressed: _busy
                        ? null
                        : () => unawaited(
                            _run(
                              (people) =>
                                  people.completeStep(person, on, today()),
                            ),
                          ),
                    tooltip: l10n.nextStepMarkDone(step.label),
                    icon: const Icon(Icons.check_rounded),
                  ),
                  _ => null,
                },
              ),
          ],
        ),
      ),
    );
  }

  static String _dueWithNote(AppLocalizations l10n, OnStep on, DateTime now) {
    final due = dueLabel(l10n, on.due, now);
    return switch (on.step.note) {
      final note? => l10n.nextStepWithNote(due, note),
      null => due,
    };
  }
}

/// One step on the rail. Every row has the same insets, so the rail stays
/// straight through the current one's wash.
class TimelineStep extends StatelessWidget {
  const TimelineStep({
    required this.title,
    required this.meta,
    required this.first,
    required this.last,
    this.dimmed = false,
    this.current = false,
    this.action,
    super.key,
  });

  final String title;
  final String meta;
  final bool first;
  final bool last;

  /// Before the current step: greyed.
  final bool dimmed;

  /// On the selected-row wash, its dot in primary.
  final bool current;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = LoomiaColors.of(context);
    final button = action;
    Widget line({double? height, bool visible = true}) => Container(
      width: 2,
      height: height,
      color: visible ? colors.borderSubtle : null,
    );

    return Container(
      decoration: current
          ? BoxDecoration(
              color: colors.primaryMuted,
              borderRadius: BorderRadius.circular(AppRadii.lg),
            )
          : null,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.ms),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              width: AppSpacing.md,
              child: Column(
                children: [
                  line(height: AppSpacing.ms + AppSpacing.xs, visible: !first),
                  Container(
                    width: AppSpacing.sm,
                    height: AppSpacing.sm,
                    decoration: BoxDecoration(
                      color: current
                          ? colors.primaryText
                          : dimmed
                          ? colors.borderSubtle
                          : colors.borderStrong,
                      shape: BoxShape.circle,
                    ),
                  ),
                  Expanded(child: line(visible: !last)),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.ms),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.ms),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: dimmed
                            ? colors.textDisabled
                            : theme.colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      meta,
                      style: AppTypography.caption.copyWith(
                        color: dimmed ? colors.textDisabled : colors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (button != null) Center(child: button),
          ],
        ),
      ),
    );
  }
}

class _Gone extends StatelessWidget {
  const _Gone({
    required this.title,
    required this.body,
    required this.action,
    required this.onAction,
  });

  final String title;
  final String body;
  final String action;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) => Center(
    child: SingleChildScrollView(
      child: EmptyState(
        icon: Icons.route_outlined,
        title: title,
        body: body,
        actionLabel: action,
        onAction: onAction,
      ),
    ),
  );
}

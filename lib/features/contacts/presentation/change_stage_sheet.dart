import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loomia/app/theme/app_spacing.dart';
import 'package:loomia/core/ui/form_error.dart';
import 'package:loomia/core/ui/loomia_dialog.dart';
import 'package:loomia/core/ui/pick_day.dart';
import 'package:loomia/features/auth/data/auth_repository.dart';
import 'package:loomia/features/calendar/presentation/plan_sheet.dart';
import 'package:loomia/features/contacts/domain/activity.dart';
import 'package:loomia/features/contacts/domain/people_failure.dart';
import 'package:loomia/features/contacts/domain/person.dart';
import 'package:loomia/features/contacts/presentation/follow_with_field.dart';
import 'package:loomia/features/contacts/presentation/history_controller.dart';
import 'package:loomia/features/contacts/presentation/people_controller.dart';
import 'package:loomia/features/contacts/presentation/people_copy.dart';
import 'package:loomia/features/workflows/domain/event_workflow.dart';
import 'package:loomia/features/workflows/domain/progress.dart';
import 'package:loomia/features/workflows/domain/workflow.dart';
import 'package:loomia/features/workflows/presentation/event_workflows_controller.dart';
import 'package:loomia/features/workflows/presentation/workflows_controller.dart';
import 'package:loomia/l10n/app_localizations.dart';
import 'package:material_ui/material_ui.dart';

/// Moves [people] to [stage] once confirmed, in one write: a sheet on mobile,
/// a dialog elsewhere. Closes once the move is saved, and completes with
/// whether it was. None of them may be in [stage] already.
/// Plan it now (#413) opens the event form once the sheet has closed.
Future<bool> showChangeStage(
  BuildContext context,
  List<Person> people,
  Stage stage,
) async {
  EventWorkflow? plan;
  final moved =
      await LoomiaDialog.show<bool>(
        context,
        (_) => _ChangeStage(
          people: people,
          stage: stage,
          onPlan: (type) => plan = type,
        ),
      ) ??
      false;
  if (plan case final type? when moved && context.mounted) {
    await planEvent(context, people.single, type);
  }
  return moved;
}

class _ChangeStage extends ConsumerStatefulWidget {
  const _ChangeStage({
    required this.people,
    required this.stage,
    required this.onPlan,
  });

  final List<Person> people;
  final Stage stage;

  /// The event to plan once closed.
  final ValueChanged<EventWorkflow> onPlan;

  @override
  ConsumerState<_ChangeStage> createState() => _ChangeStageState();
}

class _ChangeStageState extends ConsumerState<_ChangeStage> {
  /// What the user picked; null until they pick, so the default can arrive
  /// with the workflows. The record tells "picked nothing" from "not yet".
  ({FollowWith? follow})? _picked;
  bool _saving = false;
  PeopleFailure? _failure;

  /// Plan the first step's event once moved, when it is one (#413).
  bool _plan = true;

  /// One prospect becoming a customer: their registration order (#318).
  final _amount = TextEditingController();
  final _form = GlobalKey<FormState>();

  bool get _registers =>
      widget.stage == Stage.customer &&
      widget.people.length == 1 &&
      widget.people.single.stage == Stage.prospect;

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  double? get _registration =>
      parseAmount(_amount.text, AppLocalizations.of(context).localeName);

  FollowWith? _follow(List<Workflow> workflows, DateTime today) {
    if (_picked case (:final follow)) return follow;
    final suggested = defaultFor(workflows, widget.stage);
    return suggested == null
        ? null
        : (workflow: suggested, firstDue: firstDueDefault(suggested, today));
  }

  Future<void> _move(FollowWith? picked, EventWorkflow? type) async {
    if (!(_form.currentState?.validate() ?? true)) return;
    final amount = _registers ? _registration : null;
    final text = AppLocalizations.of(context).thereRegistrationOrder;
    final plan = _plan ? type : null;
    // Due today, so a form closed unsaved leaves it on Today.
    final follow = plan == null || picked == null
        ? picked
        : (workflow: picked.workflow, firstDue: today());
    setState(() {
      _saving = true;
      _failure = null;
    });
    try {
      await ref
          .read(peopleProvider(ref.read(accountProvider)?.email).notifier)
          .moveTo(widget.people, widget.stage, follow: follow);
      // ponytail: the move then the order, two writes; a failed order says
      // so, and the stage stays moved. One RPC if that ever loses one.
      if (amount != null) {
        await ref.read(historyProvider(widget.people.single.id).notifier).add((
          kind: ActivityKind.order,
          happenedOn: today(),
          text: text,
          amount: amount,
        ));
      }
      if (plan != null) widget.onPlan(plan);
      if (mounted) Navigator.pop(context, true);
    } on PeopleFailure catch (failure) {
      if (mounted) {
        setState(() {
          _saving = false;
          _failure = failure;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final failure = _failure;
    final owner = ref.watch(accountProvider)?.email;
    final workflowsAsync = ref.watch(workflowsProvider(owner));
    final workflows = workflowsAsync.value ?? const [];
    final now = today();
    final follow = _follow(workflows, now);
    final people = widget.people;
    // ponytail: one person plans; several share a reminder, since an event
    // per person would need the group choice for each.
    final type = people.length == 1
        ? FollowWithField.planType(
            ref.watch(eventWorkflowsProvider(owner)).value ?? const [],
            follow,
          )
        : null;
    final ending = [
      for (final person in people)
        if (findWorkflow(workflows, person.place?.workflowId)
            case final workflow?
            when progressOf(person, workflow) is OnStep ||
                progressOf(person, workflow) is Planned)
          workflow,
    ];
    // The database clears a prospect's status when they leave prospects.
    final clearsStatus =
        widget.stage != Stage.prospect &&
        people.any((person) => person.prospectStatus != null);
    final body = clearsStatus
        ? l10n.changeStageBodyCleared
        : l10n.changeStageBody;

    return LoomiaDialog(
      title: switch (people) {
        [final person] => movedTitle(l10n, firstName(person), widget.stage),
        _ => movedManyTitle(l10n, people.length, widget.stage),
      },
      body: switch (ending) {
        [] => body,
        [final workflow] when people.length == 1 =>
          '$body ${l10n.changeStageWorkflowEnds(workflow.name)}',
        _ => '$body ${l10n.changeStageWorkflowsEnd}',
      },
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(MaterialLocalizations.of(context).cancelButtonLabel),
        ),
        FilledButton(
          onPressed: _saving || !workflowsAsync.hasValue
              ? null
              : () => _move(follow, type),
          child: _saving
              ? const SizedBox.square(
                  dimension: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(moveToLabel(l10n, widget.stage)),
        ),
      ],
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: AppSpacing.ms,
        children: [
          if (failure != null) FormError(peopleFailureCopy(l10n, failure)),
          FollowWithField(
            workflows: forStage(workflows, widget.stage),
            value: follow,
            today: now,
            onChanged: (next) => setState(() => _picked = (follow: next)),
            plan: type == null ? null : _plan,
            onPlanChanged: (plan) => setState(() => _plan = plan),
          ),
          if (_registers)
            Form(
              key: _form,
              child: TextFormField(
                controller: _amount,
                enabled: !_saving,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: InputDecoration(
                  labelText: l10n.thereRegistrationOrder,
                  helperText: l10n.changeStageRegistrationHint,
                ),
                validator: (value) =>
                    (value ?? '').trim().isEmpty || _registration != null
                    ? null
                    : l10n.logAmountInvalid,
              ),
            ),
        ],
      ),
    );
  }
}

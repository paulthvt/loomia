import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loomia/app/theme/app_colors.dart';
import 'package:loomia/app/theme/app_spacing.dart';
import 'package:loomia/core/business_model/business_model.dart';
import 'package:loomia/core/ui/form_error.dart';
import 'package:loomia/core/ui/loomia_dialog.dart';
import 'package:loomia/core/ui/pick_day.dart';
import 'package:loomia/features/auth/data/auth_repository.dart';
import 'package:loomia/features/calendar/domain/calendar_event.dart';
import 'package:loomia/features/calendar/presentation/calendar_controller.dart';
import 'package:loomia/features/calendar/presentation/event_page.dart';
import 'package:loomia/features/contacts/domain/activity.dart';
import 'package:loomia/features/contacts/domain/people_failure.dart';
import 'package:loomia/features/contacts/domain/person.dart';
import 'package:loomia/features/contacts/presentation/people_copy.dart';
import 'package:loomia/features/workflows/domain/event_workflow.dart';
import 'package:loomia/features/workflows/domain/progress.dart';
import 'package:loomia/features/workflows/domain/workflow.dart';
import 'package:loomia/features/workflows/presentation/event_workflows_controller.dart';
import 'package:loomia/features/workflows/presentation/workflows_controller.dart';
import 'package:loomia/l10n/app_localizations.dart';
import 'package:material_ui/material_ui.dart';

/// "Who was there?" (#318): everyone invited, ticked. For each person there,
/// what changed: a prospect who became a customer, with their registration
/// order; someone else's order. Who missed a group event can be invited to
/// the next one of its type. Done marks it all in one write.
Future<void> showWhoWasThere(
  BuildContext context, {
  required CalendarEvent event,
  required List<EventPerson> people,
}) => LoomiaDialog.show<void>(
  context,
  (_) => _WhoWasThere(event: event, people: people),
);

/// The next open event of [event]'s type, after it: where someone who
/// missed it can go instead. Null for a plain event.
CalendarEvent? nextOfType(List<CalendarEvent> events, CalendarEvent event) {
  final type = event.eventWorkflowId;
  if (type == null) return null;
  return byStart([
    for (final other in events)
      if (other.id != event.id &&
          other.eventWorkflowId == type &&
          !other.done &&
          other.startsAt.isAfter(event.startsAt))
        other,
  ]).firstOrNull;
}

class _WhoWasThere extends ConsumerStatefulWidget {
  const _WhoWasThere({required this.event, required this.people});

  final CalendarEvent event;
  final List<EventPerson> people;

  @override
  ConsumerState<_WhoWasThere> createState() => _WhoWasThereState();
}

class _WhoWasThereState extends ConsumerState<_WhoWasThere> {
  final _form = GlobalKey<FormState>();
  late final Set<String> _there = {
    for (final (:person, attendee: _) in widget.people) person.id,
  };

  /// Prospects there who became customers.
  final Set<String> _customers = {};

  /// Who missed it and stays out of the next one; everyone else is invited.
  final Set<String> _notNext = {};
  late final Map<String, TextEditingController> _amounts = {
    for (final (:person, attendee: _) in widget.people)
      person.id: TextEditingController(),
  };
  bool _saving = false;
  PeopleFailure? _failure;

  @override
  void dispose() {
    for (final controller in _amounts.values) {
      controller.dispose();
    }
    super.dispose();
  }

  double? _amount(String personId) => parseAmount(
    _amounts[personId]!.text,
    AppLocalizations.of(context).localeName,
  );

  Future<void> _submit(CalendarEvent? next) async {
    if (!_form.currentState!.validate()) return;
    final l10n = AppLocalizations.of(context);
    final there = <There>[
      for (final (:person, attendee: _) in widget.people)
        if (_there.contains(person.id))
          (
            personId: person.id,
            customer: _customers.contains(person.id),
            amount: _amount(person.id),
            text: _customers.contains(person.id)
                ? l10n.thereRegistrationOrder
                : null,
          ),
    ];
    final inviteNext = next == null
        ? const <String>[]
        : [
            for (final (:person, attendee: _) in widget.people)
              if (!_there.contains(person.id) && !_notNext.contains(person.id))
                person.id,
          ];
    setState(() {
      _saving = true;
      _failure = null;
    });
    try {
      await ref
          .read(eventsProvider(ref.read(accountProvider)?.email).notifier)
          .close(widget.event.id, there, inviteNext, today());
      if (mounted) Navigator.pop(context);
    } on PeopleFailure catch (failure) {
      if (mounted) {
        setState(() {
          _saving = false;
          _failure = failure;
        });
      }
    }
  }

  /// "Continues New customer → Give VIP access" when this event is their
  /// current event step; "Finishes Workshop invite" when it is the last.
  String? _continues(AppLocalizations l10n, Person person, List<Workflow> all) {
    final type = widget.event.eventWorkflowId;
    if (type == null) return null;
    final workflow = findWorkflow(all, person.place?.workflowId);
    final (step, index) = switch (progressOf(person, workflow)) {
      OnStep(:final step, :final index) => (step, index),
      Planned(:final step, :final index) => (step, index),
      _ => (null, 0),
    };
    if (workflow == null || step == null || step.eventWorkflowId != type) {
      return null;
    }
    return index < workflow.steps.length
        ? l10n.thereContinues(workflow.name, workflow.steps[index].label)
        : l10n.thereFinishes(workflow.name);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final failure = _failure;
    final owner = ref.watch(accountProvider)?.email;
    final workflows = ref.watch(workflowsProvider(owner)).value ?? const [];
    final types = ref.watch(eventWorkflowsProvider(owner)).value ?? const [];
    final isGroup =
        findEventWorkflow(types, widget.event.eventWorkflowId)?.isGroup ??
        false;
    final next = isGroup
        ? nextOfType(
            ref.watch(eventsProvider(owner)).value ?? const [],
            widget.event,
          )
        : null;
    final unit = l10n.orderUnit(
      (ref.watch(accountProvider)?.businessModel ?? BusinessModel.other).name,
    );
    final starts = defaultFor(workflows, Stage.customer);
    final muted = Theme.of(context).textTheme.bodySmall
        ?.copyWith(color: LoomiaColors.of(context).textMuted);

    Widget amount(String personId, String label) => Padding(
      padding: const EdgeInsetsDirectional.only(start: AppSpacing.xl),
      child: TextFormField(
        controller: _amounts[personId],
        enabled: !_saving,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: InputDecoration(
          labelText: label,
          suffixText: unit.isEmpty ? null : unit,
        ),
        validator: (value) =>
            (value ?? '').trim().isEmpty || _amount(personId) != null
            ? null
            : l10n.logAmountInvalid,
      ),
    );

    Widget line(String text) => Padding(
      padding: const EdgeInsetsDirectional.only(start: AppSpacing.xl),
      child: Text(text, style: muted),
    );

    return Form(
      key: _form,
      child: LoomiaDialog(
        title: l10n.eventWhoWasThere,
        body: l10n.eventWhoWasThereBody,
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(MaterialLocalizations.of(context).cancelButtonLabel),
          ),
          FilledButton(
            onPressed: _saving ? null : () => _submit(next),
            child: _saving
                ? const SizedBox.square(
                    dimension: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(l10n.eventMarkDone(_there.length)),
          ),
        ],
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: AppSpacing.xs,
          children: [
            if (failure != null) FormError(peopleFailureCopy(l10n, failure)),
            for (final (:person, attendee: _) in widget.people) ...[
              CheckboxListTile(
                value: _there.contains(person.id),
                onChanged: _saving
                    ? null
                    : (ticked) => setState(() {
                        if (ticked ?? false) {
                          _there.add(person.id);
                        } else {
                          _there.remove(person.id);
                        }
                      }),
                title: Text(person.name),
                subtitle: Text(stageLabel(l10n, person.stage)),
                controlAffinity: ListTileControlAffinity.leading,
                contentPadding: EdgeInsets.zero,
              ),
              if (_there.contains(person.id)) ...[
                if (_continues(l10n, person, workflows) case final text?
                    when !_customers.contains(person.id))
                  line(text),
                if (person.stage == Stage.prospect) ...[
                  Padding(
                    padding: const EdgeInsetsDirectional.only(
                      start: AppSpacing.xl,
                    ),
                    child: SwitchListTile(
                      value: _customers.contains(person.id),
                      title: Text(l10n.thereBecameCustomer),
                      contentPadding: EdgeInsets.zero,
                      onChanged: _saving
                          ? null
                          : (on) => setState(() {
                              if (on) {
                                _customers.add(person.id);
                              } else {
                                _customers.remove(person.id);
                              }
                            }),
                    ),
                  ),
                  if (_customers.contains(person.id)) ...[
                    amount(person.id, l10n.thereRegistrationOrder),
                    if (starts != null) line(l10n.thereStarts(starts.name)),
                  ],
                ] else
                  amount(person.id, l10n.thereOrder),
              ] else if (next != null)
                Padding(
                  padding: const EdgeInsetsDirectional.only(
                    start: AppSpacing.xl,
                  ),
                  child: SwitchListTile(
                    value: !_notNext.contains(person.id),
                    title: Text(
                      l10n.thereInviteNext(next.title, next.startsAt.toLocal()),
                    ),
                    contentPadding: EdgeInsets.zero,
                    onChanged: _saving
                        ? null
                        : (on) => setState(() {
                            if (on) {
                              _notNext.remove(person.id);
                            } else {
                              _notNext.add(person.id);
                            }
                          }),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

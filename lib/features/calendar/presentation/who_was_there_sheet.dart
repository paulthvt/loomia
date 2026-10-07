import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loomia/app/theme/app_colors.dart';
import 'package:loomia/app/theme/app_spacing.dart';
import 'package:loomia/app/theme/app_typography.dart';
import 'package:loomia/core/ui/form_error.dart';
import 'package:loomia/core/ui/loomia_dialog.dart';
import 'package:loomia/core/ui/pick_day.dart';
import 'package:loomia/features/auth/data/auth_repository.dart';
import 'package:loomia/features/calendar/domain/calendar_event.dart';
import 'package:loomia/features/calendar/presentation/calendar_controller.dart';
import 'package:loomia/features/calendar/presentation/event_page.dart';
import 'package:loomia/features/contacts/domain/people_failure.dart';
import 'package:loomia/features/contacts/domain/person.dart';
import 'package:loomia/features/contacts/presentation/people_copy.dart';
import 'package:loomia/l10n/app_localizations.dart';
import 'package:material_ui/material_ui.dart';

/// "Who was there?": everyone invited, ticked; Done marks the event done
/// with whoever is still ticked (spec §3, Event 4).
Future<void> showWhoWasThere(
  BuildContext context, {
  required CalendarEvent event,
  required List<EventPerson> people,
  required Map<Stage, String> followUpNames,
}) => LoomiaDialog.show<void>(
  context,
  (_) =>
      _WhoWasThere(event: event, people: people, followUpNames: followUpNames),
);

class _WhoWasThere extends ConsumerStatefulWidget {
  const _WhoWasThere({
    required this.event,
    required this.people,
    required this.followUpNames,
  });

  final CalendarEvent event;
  final List<EventPerson> people;
  final Map<Stage, String> followUpNames;

  @override
  ConsumerState<_WhoWasThere> createState() => _WhoWasThereState();
}

class _WhoWasThereState extends ConsumerState<_WhoWasThere> {
  late final Set<String> _there = {
    for (final (:person, came: _) in widget.people) person.id,
  };
  bool _saving = false;
  PeopleFailure? _failure;

  List<ThereLine> get _lines => thereSummary([
    for (final (:person, came: _) in widget.people)
      if (_there.contains(person.id)) person.stage,
  ], widget.event.followUps);

  Future<void> _submit() async {
    setState(() {
      _saving = true;
      _failure = null;
    });
    try {
      await ref
          .read(eventsProvider(ref.read(accountProvider)?.email).notifier)
          .markDone(widget.event.id, _there, today());
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

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final failure = _failure;
    return LoomiaDialog(
      title: l10n.eventWhoWasThere,
      body: l10n.eventWhoWasThereBody,
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(MaterialLocalizations.of(context).cancelButtonLabel),
        ),
        FilledButton(
          onPressed: _saving ? null : _submit,
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
          for (final (:person, came: _) in widget.people)
            CheckboxListTile(
              value: _there.contains(person.id),
              onChanged: (ticked) => setState(() {
                if (ticked ?? false) {
                  _there.add(person.id);
                } else {
                  _there.remove(person.id);
                }
              }),
              title: Text(person.name),
              subtitle: Text(stageLabel(l10n, person.stage)),
              controlAffinity: ListTileControlAffinity.leading,
            ),
          if (widget.event.eventWorkflowId != null && _lines.isNotEmpty)
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: LoomiaColors.of(context).surfaceSunken,
                borderRadius: BorderRadius.circular(AppRadii.md),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: AppSpacing.xs,
                children: [
                  Text(
                    l10n.eventWhatHappensNext.toUpperCase(),
                    style: AppTypography.overline.copyWith(
                      color: LoomiaColors.of(context).textMuted,
                    ),
                  ),
                  for (final line in _lines)
                    Text(switch (widget.followUpNames[line.stage]) {
                      final String name => l10n.eventThereStarts(
                        line.count,
                        line.stage.name,
                        name,
                      ),
                      null => l10n.eventThereKeeps(line.count, line.stage.name),
                    }),
                  if (_lines.any(
                    (line) => widget.followUpNames.containsKey(line.stage),
                  ))
                    Text(
                      l10n.eventThereReplaces,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

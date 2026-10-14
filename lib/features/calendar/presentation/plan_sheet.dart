import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loomia/core/ui/loomia_dialog.dart';
import 'package:loomia/core/ui/pick_day.dart';
import 'package:loomia/features/auth/data/auth_repository.dart';
import 'package:loomia/features/calendar/domain/calendar_event.dart';
import 'package:loomia/features/calendar/presentation/calendar_controller.dart';
import 'package:loomia/features/calendar/presentation/event_form.dart';
import 'package:loomia/features/contacts/domain/people_failure.dart';
import 'package:loomia/features/contacts/domain/person.dart';
import 'package:loomia/features/contacts/presentation/people_controller.dart';
import 'package:loomia/features/contacts/presentation/people_copy.dart';
import 'package:loomia/features/workflows/domain/event_workflow.dart';
import 'package:loomia/features/workflows/domain/progress.dart';
import 'package:loomia/l10n/app_localizations.dart';
import 'package:material_ui/material_ui.dart';

/// The proposed day for a new event planned from a step.
// ponytail: a week out for every type; a delay per event type if one needs
// another.
const int planInDays = 7;

/// Later on an event step: a day from tomorrow to a year out, three days out
/// to start. Null when dismissed.
Future<DateTime?> pickLater(BuildContext context) => pickDay(
  context,
  initial: addDays(today(), 3),
  first: addDays(today(), 1),
  last: addDays(today(), 365),
);

/// Plan on an event step (#315): an event of [type] with [person] in it.
/// One person per event: the event form, prefilled, a week out. Several: an
/// upcoming event of that type or a new one, and they join it invited.
/// True once they are in the event; people reload, since the server decides
/// that their step now waits.
Future<bool> planEvent(
  BuildContext context,
  Person person,
  EventWorkflow type,
) async {
  final container = ProviderScope.containerOf(context);
  final owner = container.read(accountProvider)?.email;
  final events = container.read(eventsProvider(owner).notifier);
  final messenger = ScaffoldMessenger.of(context);
  final l10n = AppLocalizations.of(context);

  Future<String?> create() async => (await showEventForm(
    context,
    type: type,
    title: l10n.planEventTitle(type.name, firstName(person)),
    day: addDays(today(), planInDays),
  ))?.id;

  String? eventId;
  if (type.isGroup) {
    final now = DateTime.now();
    final upcoming = byStart([
      for (final event
          in container.read(eventsProvider(owner)).value ??
              const <CalendarEvent>[])
        if (event.eventWorkflowId == type.id &&
            !event.done &&
            event.startsAt.isAfter(now) &&
            !event.attendees.any((a) => a.personId == person.id))
          event,
    ]);
    final picked = await LoomiaDialog.show<_Pick>(
      context,
      (_) => _GroupPlan(person: person, type: type, upcoming: upcoming),
    );
    if (picked == null || !context.mounted) return false;
    eventId = switch (picked) {
      _Existing(:final id) => id,
      _New() => await create(),
    };
  } else {
    eventId = await create();
  }
  if (eventId == null) return false;

  // ponytail: two writes, the event then the person; a failed second one
  // leaves the event without them, said here. One RPC if that ever bites.
  try {
    await events.invite(eventId, [person.id], today());
  } on PeopleFailure catch (failure) {
    messenger.showSnackBar(
      SnackBar(content: Text(peopleFailureCopy(l10n, failure))),
    );
    return false;
  }
  container.invalidate(peopleProvider(owner));
  return true;
}

sealed class _Pick {
  const _Pick();
}

final class _Existing extends _Pick {
  const _Existing(this.id);

  final String id;
}

final class _New extends _Pick {
  const _New();
}

/// Several people per event: an upcoming one of [type], or a new one.
class _GroupPlan extends StatefulWidget {
  const _GroupPlan({
    required this.person,
    required this.type,
    required this.upcoming,
  });

  final Person person;
  final EventWorkflow type;

  /// Earliest first, without the person.
  final List<CalendarEvent> upcoming;

  @override
  State<_GroupPlan> createState() => _GroupPlanState();
}

class _GroupPlanState extends State<_GroupPlan> {
  static const _newValue = '';

  late String _picked = widget.upcoming.firstOrNull?.id ?? _newValue;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final name = firstName(widget.person);
    return LoomiaDialog(
      title: l10n.planGroupTitle(name, widget.type.name),
      body: l10n.planGroupBody(name),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(MaterialLocalizations.of(context).cancelButtonLabel),
        ),
        FilledButton(
          onPressed: () => Navigator.pop<_Pick>(
            context,
            _picked == _newValue ? const _New() : _Existing(_picked),
          ),
          child: Text(l10n.planInvite),
        ),
      ],
      child: RadioGroup<String>(
        groupValue: _picked,
        onChanged: (id) => setState(() => _picked = id ?? _newValue),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final event in widget.upcoming)
              RadioListTile<String>(
                value: event.id,
                contentPadding: EdgeInsets.zero,
                title: Text(
                  l10n.planEventOption(
                    event.title,
                    event.startsAt.toLocal(),
                    l10n.eventInvitedCount(event.attendees.length),
                  ),
                ),
              ),
            RadioListTile<String>(
              value: _newValue,
              contentPadding: EdgeInsets.zero,
              title: Text(l10n.planGroupNew(widget.type.name)),
            ),
          ],
        ),
      ),
    );
  }
}

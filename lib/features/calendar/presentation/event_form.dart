import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:loomia/app/theme/app_colors.dart';
import 'package:loomia/app/theme/app_spacing.dart';
import 'package:loomia/core/ui/form_error.dart';
import 'package:loomia/core/ui/labeled_field.dart';
import 'package:loomia/core/ui/loomia_dialog.dart';
import 'package:loomia/core/ui/pick_day.dart';
import 'package:loomia/features/auth/data/auth_repository.dart';
import 'package:loomia/features/calendar/domain/calendar_event.dart';
import 'package:loomia/features/calendar/presentation/calendar_controller.dart';
import 'package:loomia/features/calendar/presentation/event_row.dart';
import 'package:loomia/features/calendar/presentation/scope_dialog.dart';
import 'package:loomia/features/contacts/domain/people_failure.dart';
import 'package:loomia/features/contacts/presentation/people_copy.dart';
import 'package:loomia/features/notifications/presentation/notifications_controller.dart';
import 'package:loomia/features/workflows/domain/event_workflow.dart';
import 'package:loomia/features/workflows/presentation/event_workflows_controller.dart';
import 'package:loomia/l10n/app_localizations.dart';
import 'package:material_ui/material_ui.dart';

/// A new event on [day], or [event] to change: a sheet on mobile, a dialog
/// elsewhere. Resolves to the saved event, or null when dismissed.
/// A new event on [day], or [event] to edit. A new one can start with its
/// [type] chosen and a [title] (Plan on an event step, #315).
Future<CalendarEvent?> showEventForm(
  BuildContext context, {
  CalendarEvent? event,
  DateTime? day,
  EventWorkflow? type,
  String? title,
}) => LoomiaDialog.show<CalendarEvent>(
  context,
  (_) => _EventForm(event: event, day: day, type: type, title: title),
);

/// A new event starts in the evening, when most workshops are.
const _defaultStart = TimeOfDay(hour: 19, minute: 0);

class _EventForm extends ConsumerStatefulWidget {
  const _EventForm({this.event, this.day, this.type, this.title});

  final CalendarEvent? event;
  final DateTime? day;
  final EventWorkflow? type;
  final String? title;

  @override
  ConsumerState<_EventForm> createState() => _EventFormState();
}

class _EventFormState extends ConsumerState<_EventForm> {
  final _form = GlobalKey<FormState>();
  late final _title = TextEditingController(text: widget.event?.title);
  late final _place = TextEditingController(text: widget.event?.place);
  late final _link = TextEditingController(text: widget.event?.link);
  late final _notes = TextEditingController(text: widget.event?.notes);
  late DateTime _day;
  late TimeOfDay _start;
  TimeOfDay? _end;
  bool _endBeforeStart = false;
  bool _saving = false;
  PeopleFailure? _failure;
  String? _eventWorkflowId;
  String? _typeName;

  /// Every 1, 2 or 4 weeks; null doesn't repeat. Not on a done event.
  int? _repeatWeeks;

  /// The last day it can take place; null is forever.
  DateTime? _until;
  bool _untilBeforeStart = false;

  @override
  void initState() {
    super.initState();
    final event = widget.event;
    if (event == null) {
      _day = widget.day ?? today();
      _start = _defaultStart;
      if (widget.type case final type?) {
        _typeName = type.name;
        _eventWorkflowId = type.id;
        _title.text = widget.title ?? type.name;
      }
      return;
    }
    final starts = event.startsAt.toLocal();
    _day = DateTime(starts.year, starts.month, starts.day);
    _start = TimeOfDay.fromDateTime(starts);
    final ends = event.endsAt;
    _end = ends == null ? null : TimeOfDay.fromDateTime(ends.toLocal());
    _eventWorkflowId = event.eventWorkflowId;
    if (event.series case final series?) {
      _repeatWeeks = series.everyWeeks;
      _until = series.untilOn;
    }
  }

  @override
  void dispose() {
    _title.dispose();
    _place.dispose();
    _link.dispose();
    _notes.dispose();
    super.dispose();
  }

  // ponytail: the end is a time on the start's day, so nothing runs past
  // midnight; add an end date if someone needs it.
  DateTime _at(TimeOfDay time) =>
      DateTime(_day.year, _day.month, _day.day, time.hour, time.minute);

  Future<void> _pickDay() async {
    final day = await pickDay(
      context,
      initial: _day,
      first: DateTime(_day.year - 5),
      last: DateTime(_day.year + 5),
    );
    if (day != null && mounted) setState(() => _day = day);
  }

  Future<void> _pickStart() async {
    final time = await pickTime(context, initial: _start);
    if (time == null || !mounted) return;
    setState(() {
      _start = time;
      _endBeforeStart = false;
    });
  }

  Future<void> _pickEnd() async {
    final time = await pickTime(
      context,
      initial:
          _end ??
          TimeOfDay(
            hour: (_start.hour + 1) % TimeOfDay.hoursPerDay,
            minute: _start.minute,
          ),
    );
    if (time == null || !mounted) return;
    setState(() {
      _end = time;
      _endBeforeStart = false;
    });
  }

  void _clearEnd() => setState(() {
    _end = null;
    _endBeforeStart = false;
  });

  Future<void> _pickUntil() async {
    final day = await pickDay(
      context,
      initial: _until ?? DateTime(_day.year, _day.month + 1, _day.day),
      first: _day,
      last: DateTime(_day.year + 5),
    );
    if (day != null && mounted) {
      setState(() {
        _until = day;
        _untilBeforeStart = false;
      });
    }
  }

  List<EventWorkflow>? get _eventWorkflows =>
      ref.read(eventWorkflowsProvider(ref.read(accountProvider)?.email)).value;

  void _choose(EventWorkflow workflow) {
    final currentTitle = _title.text.trim();
    final previous =
        _typeName ??
        findEventWorkflow(_eventWorkflows ?? const [], _eventWorkflowId)?.name;
    if (currentTitle.isEmpty || currentTitle == previous) {
      _title.text = workflow.name;
    }
    _typeName = workflow.name;
    _eventWorkflowId = workflow.id;
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    final startsAt = _at(_start);
    final end = _end;
    final endsAt = end == null ? null : _at(end);
    if (endsAt != null && !endsAt.isAfter(startsAt)) {
      setState(() => _endBeforeStart = true);
      return;
    }
    final repeatWeeks = _repeatWeeks;
    final until = _until;
    if (repeatWeeks != null && until != null && until.isBefore(_day)) {
      setState(() => _untilBeforeStart = true);
      return;
    }
    String? text(TextEditingController controller) {
      final value = controller.text.trim();
      return value.isEmpty ? null : value;
    }

    // Deleted since the form opened, or since the event was saved: dropped,
    // once the lists say so.
    final owner = ref.read(accountProvider)?.email;
    final eventWorkflows = _eventWorkflows;
    final eventWorkflowId = eventWorkflows == null
        ? _eventWorkflowId
        : findEventWorkflow(eventWorkflows, _eventWorkflowId)?.id;

    final EventDraft draft = (
      title: _title.text.trim(),
      startsAt: startsAt,
      endsAt: endsAt,
      place: text(_place),
      link: normaliseLink(_link.text),
      notes: text(_notes),
      eventWorkflowId: eventWorkflowId,
    );
    final event = widget.event;
    final series = event?.series;
    EventScope? scope;
    if (event != null && series != null && !event.done) {
      // An occurrence: a new rule or day only reaches the following ones.
      scope = await pickScope(
        context,
        ruleChanged:
            repeatWeeks != series.everyWeeks ||
            until != series.untilOn ||
            _day != event.day,
      );
      if (scope == null || !mounted) return;
    }
    setState(() {
      _saving = true;
      _failure = null;
    });
    try {
      final events = ref.read(eventsProvider(owner).notifier);
      final CalendarEvent saved;
      if (event != null && scope != null) {
        saved = scope == EventScope.one
            ? await events.save(event.id, draft)
            : await events.saveFollowing(event.id, draft, (
                everyWeeks: repeatWeeks!,
                untilOn: until,
              ));
      } else if (event != null && (event.done || repeatWeeks == null)) {
        saved = await events.save(event.id, draft);
      } else if (repeatWeeks != null) {
        // Null when the device can't say: guessing UTC would move every
        // start.
        final zone =
            await ref.read(deviceTimeZoneProvider.future) ??
            (throw PeopleFailure.unknown);
        final RepeatRule rule = (everyWeeks: repeatWeeks, untilOn: until);
        saved = event == null
            ? await events.addRepeating(draft, rule, zone)
            : await events.repeat(event.id, draft, rule, zone);
      } else {
        saved = await events.add(draft);
      }
      if (mounted) Navigator.pop(context, saved);
    } on PeopleFailure catch (failure) {
      if (mounted) {
        setState(() {
          _saving = false;
          _failure = failure;
        });
      }
    }
  }

  /// Repeat and, once it repeats, Ends: chips with the line they make under
  /// them, like Remind me's When.
  List<Widget> _repeat(AppLocalizations l10n) {
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodyMedium?.copyWith(
      color: LoomiaColors.of(context).textMuted,
    );
    final weeks = _repeatWeeks;
    final until = _until;
    return [
      LabeledField(
        label: l10n.eventRepeat,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: AppSpacing.sm,
          children: [
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                // ponytail: an occurrence stops repeating by Delete, This
                // and following; "Doesn't repeat" here would need a split.
                if (widget.event?.series == null)
                  ChoiceChip(
                    label: Text(l10n.eventRepeatNever),
                    selected: weeks == null,
                    onSelected: (_) => setState(() => _repeatWeeks = null),
                  ),
                for (final every in repeatWeeks)
                  ChoiceChip(
                    label: Text(l10n.eventRepeatEvery(every)),
                    selected: weeks == every,
                    onSelected: (_) => setState(() => _repeatWeeks = every),
                  ),
              ],
            ),
            if (weeks != null)
              Text(
                repeatLine(l10n, everyWeeks: weeks, firstOn: _day),
                style: muted,
              ),
          ],
        ),
      ),
      if (weeks != null)
        LabeledField(
          label: l10n.eventRepeatEnds,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: AppSpacing.sm,
            children: [
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: [
                  ChoiceChip(
                    label: Text(l10n.eventRepeatEndsNever),
                    selected: until == null,
                    onSelected: (_) => setState(() {
                      _until = null;
                      _untilBeforeStart = false;
                    }),
                  ),
                  ChoiceChip(
                    label: Text(l10n.eventRepeatEndsOn),
                    selected: until != null,
                    onSelected: (_) => unawaited(_pickUntil()),
                  ),
                ],
              ),
              if (until != null)
                Text(
                  DateFormat.yMMMMEEEEd(l10n.localeName).format(until),
                  style: muted,
                ),
              if (_untilBeforeStart)
                Text(
                  l10n.eventRepeatEndsBeforeStart,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.error,
                  ),
                ),
            ],
          ),
        ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final material = MaterialLocalizations.of(context);
    final h24 = MediaQuery.alwaysUse24HourFormatOf(context);
    String time(TimeOfDay value) =>
        material.formatTimeOfDay(value, alwaysUse24HourFormat: h24);
    final failure = _failure;
    final end = _end;
    final owner = ref.watch(accountProvider)?.email;
    final eventWorkflows =
        ref.watch(eventWorkflowsProvider(owner)).value ?? const [];

    return Form(
      key: _form,
      child: LoomiaDialog(
        title: widget.event == null ? l10n.calendarNewEvent : l10n.eventEdit,
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(material.cancelButtonLabel),
          ),
          FilledButton(
            onPressed: _saving ? null : _submit,
            child: _saving
                ? const SizedBox.square(
                    dimension: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(material.saveButtonLabel),
          ),
        ],
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: AppSpacing.ms,
          children: [
            if (failure != null) FormError(peopleFailureCopy(l10n, failure)),
            if (eventWorkflows.isNotEmpty)
              LabeledField(
                label: l10n.eventType,
                child: Wrap(
                  spacing: AppSpacing.sm,
                  children: [
                    // Plain events (#300): no checklist, nothing after.
                    ChoiceChip(
                      label: Text(l10n.eventTypeNone),
                      selected: _eventWorkflowId == null,
                      onSelected: (_) =>
                          setState(() => _eventWorkflowId = null),
                    ),
                    for (final w in eventWorkflows)
                      ChoiceChip(
                        label: Text(w.name),
                        selected: w.id == _eventWorkflowId,
                        onSelected: (_) => setState(() => _choose(w)),
                      ),
                  ],
                ),
              ),
            LabeledField(
              label: l10n.eventTitle,
              child: TextFormField(
                controller: _title,
                autofocus: widget.event == null,
                textCapitalization: TextCapitalization.sentences,
                textInputAction: TextInputAction.next,
                validator: (value) => (value ?? '').trim().isEmpty
                    ? l10n.eventTitleRequired
                    : null,
              ),
            ),
            LabeledField(
              label: l10n.eventDate,
              child: _Picker(
                text: material.formatMediumDate(_day),
                icon: Icons.calendar_today_outlined,
                onTap: _pickDay,
              ),
            ),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: AppSpacing.sm,
              children: [
                Expanded(
                  child: LabeledField(
                    label: l10n.eventStarts,
                    child: _Picker(
                      text: time(_start),
                      icon: Icons.schedule_rounded,
                      onTap: _pickStart,
                    ),
                  ),
                ),
                Expanded(
                  child: LabeledField(
                    label: l10n.eventEnds,
                    child: _Picker(
                      text: end == null ? l10n.eventEndsNone : time(end),
                      icon: Icons.schedule_rounded,
                      onTap: _pickEnd,
                      onClear: end == null ? null : _clearEnd,
                      error: _endBeforeStart ? l10n.eventEndsBeforeStart : null,
                    ),
                  ),
                ),
              ],
            ),
            if (!(widget.event?.done ?? false)) ..._repeat(l10n),
            LabeledField(
              label: l10n.eventPlace,
              child: TextFormField(
                controller: _place,
                textCapitalization: TextCapitalization.words,
                textInputAction: TextInputAction.next,
              ),
            ),
            LabeledField(
              label: l10n.eventLink,
              child: TextFormField(
                controller: _link,
                keyboardType: TextInputType.url,
                autocorrect: false,
                textInputAction: TextInputAction.next,
                decoration: InputDecoration(hintText: l10n.eventLinkHint),
                validator: (value) {
                  final text = (value ?? '').trim();
                  return text.isNotEmpty && normaliseLink(text) == null
                      ? l10n.eventLinkInvalid
                      : null;
                },
              ),
            ),
            LabeledField(
              label: l10n.eventNotes,
              child: TextFormField(
                controller: _notes,
                minLines: 2,
                maxLines: 5,
                textCapitalization: TextCapitalization.sentences,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A field that opens a picker, as Log something's day does. [onClear]
/// empties an optional one.
class _Picker extends StatelessWidget {
  const _Picker({
    required this.text,
    required this.icon,
    required this.onTap,
    this.onClear,
    this.error,
  });

  final String text;
  final IconData icon;
  final VoidCallback onTap;
  final VoidCallback? onClear;
  final String? error;

  @override
  Widget build(BuildContext context) {
    final clear = onClear;
    return InkWell(
      onTap: onTap,
      child: InputDecorator(
        decoration: InputDecoration(
          errorText: error,
          errorMaxLines: 2,
          suffixIcon: clear == null
              ? Icon(icon)
              : IconButton(
                  onPressed: clear,
                  tooltip: MaterialLocalizations.of(context).clearButtonTooltip,
                  icon: const Icon(Icons.close_rounded),
                ),
        ),
        child: Text(text),
      ),
    );
  }
}

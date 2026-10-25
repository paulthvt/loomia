import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:loomia/app/theme/app_colors.dart';
import 'package:loomia/app/theme/app_spacing.dart';
import 'package:loomia/app/theme/app_theme.dart';
import 'package:loomia/core/ui/load_failed.dart';
import 'package:loomia/features/calendar/domain/calendar_event.dart';
import 'package:loomia/features/calendar/presentation/event_row.dart';
import 'package:loomia/features/contacts/domain/people_failure.dart';
import 'package:loomia/features/tasks/domain/task.dart';
import 'package:loomia/features/tasks/presentation/task_row.dart';
import 'package:loomia/l10n/app_localizations.dart';
import 'package:material_ui/material_ui.dart';

/// The week view's title: both ends with their month, in the locale's
/// order ("Oct 19 – Oct 25"), with the year when the week crosses one.
/// `intl` has no range format, and dropping the repeated month by hand gets
/// the order wrong in some locales.
String weekTitle(AppLocalizations l10n, List<DateTime> week) {
  final first = week.first;
  final last = week.last;
  final format = first.year == last.year
      ? DateFormat.MMMd(l10n.localeName)
      : DateFormat.yMMMd(l10n.localeName);
  return l10n.calendarWeek(format.format(first), format.format(last));
}

/// What stands in for the events while they are not loaded: the failure
/// with Try again, or a spinner. Null once there is a list, which a failed
/// refresh keeps.
Widget? eventsNotLoaded(
  BuildContext context,
  AsyncValue<List<CalendarEvent>> events,
  VoidCallback onRetry,
) {
  if (events.value != null) return null;
  if (events.hasError) {
    return LoadFailed(
      offline: events.error == PeopleFailure.network,
      title: AppLocalizations.of(context).calendarLoadFailed,
      onRetry: onRetry,
    );
  }
  return const Center(child: CircularProgressIndicator());
}

/// Mobile and tablet week view, under the strip: each day's heading, then
/// its tasks then its events, or "Nothing planned". Selecting another day of the same week
/// scrolls its heading into view.
class WeekList extends StatefulWidget {
  const WeekList({
    required this.events,
    required this.days,
    required this.selected,
    required this.today,
    required this.onOpen,
    required this.onRetry,
    required this.tasks,
    required this.onToggleTask,
    required this.onOpenTask,
    this.busy = const {},
    super.key,
  });

  final AsyncValue<List<CalendarEvent>> events;
  final List<Task> tasks;

  /// The week's 7 days, as `weekDays`.
  final List<DateTime> days;
  final DateTime selected;
  final DateTime today;
  final void Function(CalendarEvent event) onOpen;
  final VoidCallback onRetry;
  final void Function(Task task) onToggleTask;
  final void Function(Task task) onOpenTask;

  /// [Task.key]s whose write is in flight.
  final Set<String> busy;

  @override
  State<WeekList> createState() => _WeekListState();
}

class _WeekListState extends State<WeekList> {
  final _headings = <DateTime, GlobalKey>{};

  @override
  void didUpdateWidget(WeekList old) {
    super.didUpdateWidget(old);
    // A new week starts at its top; a day of this one comes into view.
    if (widget.days.first != old.days.first ||
        widget.selected == old.selected) {
      return;
    }
    final heading = _headings[widget.selected]?.currentContext;
    if (heading == null) return;
    unawaited(
      Scrollable.ensureVisible(
        heading,
        duration: context.motion(AppMotion.medium),
        curve: AppMotion.standard,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final waiting = eventsNotLoaded(context, widget.events, widget.onRetry);
    if (waiting != null) return waiting;
    final l10n = AppLocalizations.of(context);
    final muted = Theme.of(context).textTheme.bodyMedium
        ?.copyWith(color: LoomiaColors.of(context).textMuted);
    final list = widget.events.value ?? const <CalendarEvent>[];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: AppSpacing.md,
      children: [
        for (final day in widget.days)
          Column(
            key: _headings.putIfAbsent(day, GlobalKey.new),
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: AppSpacing.sm,
            children: [
              _WeekDayHeading(
                day: day,
                selected: day == widget.selected,
                today: day == widget.today,
              ),
              ...switch ((tasksOn(widget.tasks, day), eventsOn(list, day))) {
                ([], []) => [Text(l10n.calendarNothingPlanned, style: muted)],
                (final tasks, final events) => [
                  for (final task in tasks)
                    TaskRow(
                      task: task,
                      busy: widget.busy.contains(task.key),
                      onOpen: () => widget.onOpenTask(task),
                      onToggle: () => widget.onToggleTask(task),
                    ),
                  for (final event in events)
                    EventRow(event: event, onTap: () => widget.onOpen(event)),
                ],
              },
            ],
          ),
      ],
    );
  }
}

/// "Mon 19": the selected day's in primary; today's with a ringed "Today".
class _WeekDayHeading extends StatelessWidget {
  const _WeekDayHeading({
    required this.day,
    required this.selected,
    required this.today,
  });

  static const double _ring = 1.5;

  final DateTime day;
  final bool selected;
  final bool today;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final colors = LoomiaColors.of(context);
    final locale = Localizations.localeOf(context).toString();
    // No intl skeleton gives the weekday and day without the month.
    final label = '${DateFormat.E(locale).format(day)} ${day.day}';
    return Semantics(
      header: true,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
        child: Row(
          spacing: AppSpacing.sm,
          children: [
            Text(
              label,
              style: theme.textTheme.labelLarge?.copyWith(
                color: selected ? colors.primaryText : null,
              ),
            ),
            if (today)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(AppRadii.pill),
                  border: Border.all(color: scheme.primary, width: _ring),
                ),
                child: Text(
                  AppLocalizations.of(context).calendarToday,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: colors.primaryText,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

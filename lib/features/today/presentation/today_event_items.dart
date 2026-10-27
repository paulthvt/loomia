import 'package:loomia/app/theme/app_colors.dart';
import 'package:loomia/app/theme/app_spacing.dart';
import 'package:loomia/app/theme/app_theme.dart';
import 'package:loomia/core/ui/animated_rows.dart';
import 'package:loomia/core/ui/section_header.dart';
import 'package:loomia/core/ui/tick_ring.dart';
import 'package:loomia/features/calendar/domain/calendar_event.dart';
import 'package:loomia/features/calendar/presentation/event_row.dart';
import 'package:loomia/features/today/domain/today_events.dart';
import 'package:loomia/l10n/app_localizations.dart';
import 'package:material_ui/material_ui.dart';

/// Today's EVENTS: today's events (Join near an online one's start), events
/// to mark who was there, then the checklist steps due. Nothing when there's
/// nothing to show.
List<Widget> todayEventItems(
  BuildContext context, {
  required TodayEvents events,
  required DateTime now,
  required void Function(CalendarEvent event) onOpen,
  required void Function(CalendarEvent event) onMarkDone,
  required void Function(DueEventStep step) onTick,
  required void Function(Uri link) onJoin,
  Set<String> busySteps = const {},
}) {
  if (events.isEmpty) return const [];
  final l10n = AppLocalizations.of(context);
  final rows = <Widget>[
    for (final event in events.today)
      EventRow(
        key: ValueKey('event:${event.id}'),
        event: event,
        onTap: () => onOpen(event),
        trailing: canJoin(event, now)
            ? FilledButton.tonal(
                style: AppTheme.tonal(context),
                onPressed: () => onJoin(Uri.parse(event.link!)),
                child: Text(l10n.eventJoin),
              )
            : null,
      ),
    for (final event in events.toMark)
      _Card(
        key: ValueKey('mark:${event.id}'),
        onTap: () => onOpen(event),
        title: l10n.todayHowDidItGo(event.title),
        subtitle: l10n.todayEventDay(event.startsAt),
        below: Align(
          alignment: AlignmentDirectional.centerStart,
          child: FilledButton.tonal(
            style: AppTheme.tonal(context),
            onPressed: () => onMarkDone(event),
            child: Text(l10n.eventMarkWhoWasThere),
          ),
        ),
      ),
    for (final due in events.steps)
      _Card(
        key: ValueKey(stepKey(due)),
        onTap: () => onOpen(due.event),
        title: due.step.label,
        subtitle: l10n.todayStepFor(due.event.title, due.event.startsAt),
        trailing: TickRing(
          onPressed: busySteps.contains(stepKey(due))
              ? null
              : () => onTick(due),
          selected: busySteps.contains(stepKey(due)),
          tooltip: l10n.eventStepTick(due.step.label),
        ),
      ),
  ];
  return [
    SectionHeader(title: l10n.todaySectionEvents),
    AnimatedRows(spacing: AppSpacing.ms, slideOut: true, children: rows),
  ];
}

/// A checklist step's busy key on Today: its event and its step.
String stepKey(DueEventStep due) => '${due.event.id}:${due.step.id}';

/// A card like EventRow's, for a line of text and an action.
class _Card extends StatelessWidget {
  const _Card({
    required this.onTap,
    required this.title,
    required this.subtitle,
    this.trailing,
    this.below,
    super.key,
  });

  final VoidCallback onTap;
  final String title;
  final String subtitle;
  final Widget? trailing;
  final Widget? below;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = LoomiaColors.of(context);
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppRadii.lg),
      side: BorderSide(color: colors.borderSubtle),
    );
    return Material(
      color: colors.surfaceDefault,
      shape: shape,
      child: InkWell(
        onTap: onTap,
        customBorder: shape,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: AppSpacing.ms,
            children: [
              Row(
                spacing: AppSpacing.ms,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      spacing: AppSpacing.xs,
                      children: [
                        Text(title, style: theme.textTheme.titleMedium),
                        Text(
                          subtitle,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  ?trailing,
                ],
              ),
              ?below,
            ],
          ),
        ),
      ),
    );
  }
}

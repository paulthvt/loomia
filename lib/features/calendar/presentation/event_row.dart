import 'package:loomia/app/theme/app_colors.dart';
import 'package:loomia/app/theme/app_spacing.dart';
import 'package:loomia/features/calendar/domain/calendar_event.dart';
import 'package:loomia/l10n/app_localizations.dart';
import 'package:material_ui/material_ui.dart';

/// [at] as a local time of day, in the device's 12- or 24-hour format.
String timeLabel(BuildContext context, DateTime at) =>
    MaterialLocalizations.of(context).formatTimeOfDay(
      TimeOfDay.fromDateTime(at.toLocal()),
      alwaysUse24HourFormat: MediaQuery.alwaysUse24HourFormatOf(context),
    );

/// "Thursday, October 8 · 7:00 PM – 9:00 PM".
String whenLabel(BuildContext context, CalendarEvent event) {
  final start = timeLabel(context, event.startsAt);
  final ends = event.endsAt;
  return AppLocalizations.of(context).eventWhen(
    event.day,
    ends == null ? start : '$start – ${timeLabel(context, ends)}',
  );
}

/// One event on the Calendar: its times, a bar, its title and where.
class EventRow extends StatelessWidget {
  const EventRow({
    required this.event,
    required this.onTap,
    this.trailing,
    super.key,
  });

  static const double _timeWidth = 64;
  static const double _bar = 3;

  final CalendarEvent event;
  final VoidCallback onTap;

  /// Today's Join.
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final colors = LoomiaColors.of(context);
    final ends = event.endsAt;
    final l10n = AppLocalizations.of(context);
    final where = event.place ?? (event.link == null ? null : l10n.eventOnline);
    final count = event.attendees.isEmpty
        ? null
        : event.done
        ? (where == null
              ? l10n.eventThereCountAlone(event.cameCount)
              : l10n.eventThereCount(event.cameCount))
        : l10n.eventInvitedCount(event.attendees.length);
    final line = where != null && count != null
        ? l10n.eventRowLine(where, count)
        : where ?? count;
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
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: AppSpacing.ms,
              children: [
                SizedBox(
                  width: _timeWidth,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        timeLabel(context, event.startsAt),
                        style: theme.textTheme.labelLarge,
                      ),
                      if (ends != null)
                        Text(
                          timeLabel(context, ends),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colors.textMuted,
                          ),
                        ),
                    ],
                  ),
                ),
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: scheme.primary,
                    borderRadius: BorderRadius.circular(AppRadii.pill),
                  ),
                  child: const SizedBox(width: _bar),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    spacing: AppSpacing.xs,
                    children: [
                      Text(event.title, style: theme.textTheme.titleMedium),
                      if (line != null)
                        Text(
                          line,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                    ],
                  ),
                ),
                ?trailing,
              ],
            ),
          ),
        ),
      ),
    );
  }
}

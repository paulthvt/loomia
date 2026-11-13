import 'package:intl/intl.dart';
import 'package:loomia/app/theme/app_colors.dart';
import 'package:loomia/app/theme/app_spacing.dart';
import 'package:loomia/app/theme/app_theme.dart';
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

/// "Every week on Tuesday", "Every 2 weeks on Tuesday · until December 15":
/// the event page's line and the line under New event's Repeat.
String repeatLine(
  AppLocalizations l10n, {
  required int everyWeeks,
  required DateTime firstOn,
  DateTime? untilOn,
}) {
  final line = l10n.eventRepeatLine(
    everyWeeks,
    DateFormat.EEEE(l10n.localeName).format(firstOn),
  );
  if (untilOn == null) return line;
  final day = untilOn.year == firstOn.year
      ? DateFormat.MMMMd(l10n.localeName)
      : DateFormat.yMMMMd(l10n.localeName);
  return l10n.eventRepeatUntil(line, day.format(untilOn));
}

/// One event on the Calendar: its times, a bar, its title and where.
class EventRow extends StatelessWidget {
  const EventRow({
    required this.event,
    required this.onTap,
    this.trailing,
    this.now,
    super.key,
  });

  static const double timeWidth = 64;
  static const double _bar = 3;

  final CalendarEvent event;
  final VoidCallback onTap;

  /// Today's Join.
  final Widget? trailing;

  /// Once the event is over by it, the row steps back (#451): no fill, a
  /// neutral bar, muted ink. Never over without it.
  final DateTime? now;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final colors = LoomiaColors.of(context);
    final over = switch (now) {
      final at? => event.isOver(at),
      null => false,
    };
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
    // A card; over, an outline with no fill or shadow.
    final card = AppTheme.card(context);
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppRadii.card),
      side: over ? BorderSide(color: colors.borderSubtle) : BorderSide.none,
    );

    // Over: the ink one step down, so the times and title stay readable.
    final ink = over ? scheme.onSurfaceVariant : scheme.onSurface;
    final quiet = over ? colors.textMuted : scheme.onSurfaceVariant;

    final row = Material(
      color: over ? Colors.transparent : card.color,
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
                  width: timeWidth,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        timeLabel(context, event.startsAt),
                        style: theme.textTheme.labelLarge?.copyWith(color: ink),
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
                    color: over ? colors.borderStrong : scheme.primary,
                    borderRadius: BorderRadius.circular(AppRadii.pill),
                  ),
                  child: const SizedBox(width: _bar),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    spacing: AppSpacing.xs,
                    children: [
                      Text(
                        event.title,
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: ink,
                        ),
                      ),
                      if (line != null)
                        Text(
                          line,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: quiet,
                          ),
                        ),
                    ],
                  ),
                ),
                if (trailing case final t?) Center(child: t),
              ],
            ),
          ),
        ),
      ),
    );
    // The card's shadow behind the Material, which paints its fill.
    return over
        ? row
        : DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: card.borderRadius,
              boxShadow: card.boxShadow,
            ),
            child: row,
          );
  }
}

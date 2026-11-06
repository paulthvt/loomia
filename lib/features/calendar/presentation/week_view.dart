import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:loomia/core/ui/load_failed.dart';
import 'package:loomia/features/calendar/domain/calendar_event.dart';
import 'package:loomia/features/contacts/domain/people_failure.dart';
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

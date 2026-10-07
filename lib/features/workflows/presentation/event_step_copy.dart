import 'package:loomia/l10n/app_localizations.dart';

/// When an event step comes due, from its signed [days]: "3 days before",
/// "On the day", "1 day after".
String stepTiming(AppLocalizations l10n, int days) => days < 0
    ? l10n.eventStepBefore(-days)
    : days == 0
    ? l10n.eventStepOnTheDay
    : l10n.eventStepAfter(days);

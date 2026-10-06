import 'package:loomia/core/business_model/business_model.dart';
import 'package:loomia/features/contacts/domain/activity.dart';
import 'package:loomia/features/contacts/domain/people_failure.dart';
import 'package:loomia/features/contacts/domain/person.dart';
import 'package:loomia/features/workflows/domain/progress.dart';
import 'package:loomia/l10n/app_localizations.dart';

/// User-facing words for the contacts domain. Copy, so it lives in
/// presentation.
String stageLabel(AppLocalizations l10n, Stage stage) => switch (stage) {
  Stage.prospect => l10n.stageProspect,
  Stage.customer => l10n.stageCustomer,
  Stage.team => l10n.stageTeam,
};

String statusLabel(AppLocalizations l10n, ProspectStatus status) =>
    switch (status) {
      ProspectStatus.interested => l10n.statusInterested,
      ProspectStatus.thinking => l10n.statusThinking,
      ProspectStatus.notNow => l10n.statusNotNow,
      ProspectStatus.noReply => l10n.statusNoReply,
    };

String peopleFailureCopy(AppLocalizations l10n, PeopleFailure failure) =>
    switch (failure) {
      PeopleFailure.network => l10n.peopleFailureNetwork,
      PeopleFailure.unknown => l10n.peopleFailureUnknown,
    };

/// The second line of a person's row: paused, else what they do, else what
/// they need.
String? contactSubtitle(AppLocalizations l10n, Person person) =>
    switch (person.pausedAt?.toLocal()) {
      final since? when person.prospectStatus == ProspectStatus.notNow =>
        l10n.contactPausedNotNow(since),
      final since? => l10n.contactPaused(since),
      null => person.profession ?? person.needs,
    };

/// When a step is due, counted in calendar days from [today].
String dueLabel(AppLocalizations l10n, DateTime due, DateTime today) =>
    switch (daysBetween(today, due)) {
      < 0 && final late => l10n.nextStepLate(-late),
      0 => l10n.nextStepDueToday,
      1 => l10n.nextStepDueTomorrow,
      <= 6 && final days => l10n.nextStepDueInDays(days),
      _ => l10n.nextStepDueOn(due),
    };

/// The first word of a name, for titles that speak about the person.
String firstName(Person person) =>
    person.name.trim().split(RegExp(r'\s+')).first;

String moveToLabel(AppLocalizations l10n, Stage stage) => switch (stage) {
  Stage.prospect => l10n.contactMoveToProspects,
  Stage.customer => l10n.contactMoveToCustomers,
  Stage.team => l10n.contactMoveToTeam,
};

/// The Change stage title: "Sarah is now a customer".
String movedTitle(AppLocalizations l10n, String name, Stage stage) =>
    switch (stage) {
      Stage.prospect => l10n.changeStageToProspect(name),
      Stage.customer => l10n.changeStageToCustomer(name),
      Stage.team => l10n.changeStageToTeam(name),
    };

/// The same, for [count] people: "These 3 are now customers".
String movedManyTitle(AppLocalizations l10n, int count, Stage stage) =>
    switch (stage) {
      Stage.prospect => l10n.changeStageManyToProspect(count),
      Stage.customer => l10n.changeStageManyToCustomer(count),
      Stage.team => l10n.changeStageManyToTeam(count),
    };

/// Null for stage entries, which the user never picks.
String? kindLabel(AppLocalizations l10n, ActivityKind kind) => switch (kind) {
  ActivityKind.note => l10n.activityKindNote,
  ActivityKind.call => l10n.activityKindCall,
  ActivityKind.message => l10n.activityKindMessage,
  ActivityKind.order => l10n.activityKindOrder,
  ActivityKind.meeting => l10n.activityKindMeeting,
  ActivityKind.stage => null,
  ActivityKind.step => l10n.activityKindStep,
};

/// What the user wrote; for a stage entry, what changed; for an order with an
/// amount, "Order · 100 PV". A person is never created with a stage entry, so
/// one to prospects is always a way back.
String activityTitle(
  AppLocalizations l10n,
  Activity activity,
  BusinessModel model,
) {
  final amount = activity.amount;
  if (amount != null) return l10n.historyOrder(model.name, amount);
  return switch (activity.stage) {
    null => activity.text!,
    Stage.prospect => l10n.historyBackToProspects,
    Stage.customer => l10n.historyBecameCustomer,
    Stage.team => l10n.historyJoinedTeam,
  };
}

/// "13 October" this year, "13 October 2024" before.
String dayLabel(AppLocalizations l10n, DateTime day, DateTime today) =>
    day.year == today.year
    ? l10n.historyDay(day)
    : l10n.historyDayWithYear(day);

/// "13 October · Call"; a stage entry has the day alone. An order with an
/// amount already says Order in its title: the day, then its note if any.
String activityMeta(AppLocalizations l10n, Activity activity, DateTime today) {
  final day = dayLabel(l10n, activity.day, today);
  if (activity.amount != null) {
    final note = activity.text;
    return note == null ? day : l10n.historyOrderMeta(day, note);
  }
  final kind = kindLabel(l10n, activity.kind);
  return kind == null ? day : l10n.historyMeta(day, kind);
}

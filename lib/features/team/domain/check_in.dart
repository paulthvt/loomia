import 'package:loomia/features/contacts/domain/person.dart';
import 'package:loomia/features/contacts/domain/search_key.dart';
import 'package:loomia/features/workflows/domain/progress.dart';

/// Why someone on the team is worth catching up with. Never a score: a
/// reason.
enum CheckInReason { isNew, quiet }

typedef CheckIn = ({
  Person person,
  CheckInReason reason,

  /// The day the reason counts from.
  DateTime since,

  /// Days from [since] to today.
  int days,
});

/// The day they joined the team, on the device's calendar.
DateTime joinedOn(Person person) {
  final local = person.stageSince.toLocal();
  return DateTime(local.year, local.month, local.day);
}

/// Something is logged with them on or after the day they joined.
bool talkedSinceJoining(Person person) {
  final last = person.lastContactOn;
  return last != null && !last.isBefore(joinedOn(person));
}

/// New for this many days after joining.
const newForDays = 30;

/// Nobody added to Loomia more recently than this shows: the app has had no
/// time to see them yet (#342).
const graceDays = 30;

/// Quiet from this many days without contact.
const quietAfterDays = 30;

/// The day they were added to Loomia, on the device's calendar.
DateTime addedOn(Person person) {
  final local = person.createdAt.toLocal();
  return DateTime(local.year, local.month, local.day);
}

/// They reached their stage after being added: the app saw them join. An
/// insert sets both from the same instant; a backdated import is earlier.
bool joinedInLoomia(Person person) =>
    person.stageSince.isAfter(person.createdAt);

/// Who on [team] could use a catch-up on [today] (local midnight): moved to
/// the team in Loomia and not talked to yet, or quiet for a month, once they
/// have been in Loomia for a month. One row each, oldest first.
List<CheckIn> checkIns(List<Person> team, DateTime today) {
  final rows = <CheckIn>[];
  for (final person in team) {
    final joined = joinedOn(person);
    final sinceJoining = daysBetween(joined, today);
    if (sinceJoining < newForDays &&
        joinedInLoomia(person) &&
        !talkedSinceJoining(person)) {
      rows.add((
        person: person,
        reason: CheckInReason.isNew,
        since: joined,
        days: sinceJoining,
      ));
      continue;
    }
    final added = addedOn(person);
    if (daysBetween(added, today) < graceDays) continue;
    // Never logged: from when the app could have, not a joining day years
    // back.
    final last =
        person.lastContactOn ?? (added.isAfter(joined) ? added : joined);
    final quiet = daysBetween(last, today);
    if (quiet >= quietAfterDays) {
      rows.add((
        person: person,
        reason: CheckInReason.quiet,
        since: last,
        days: quiet,
      ));
    }
  }
  return rows..sort((a, b) {
    final bySince = a.since.compareTo(b.since);
    return bySince != 0
        ? bySince
        : searchKey(a.person.name).compareTo(searchKey(b.person.name));
  });
}

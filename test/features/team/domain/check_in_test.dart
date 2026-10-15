import 'package:flutter_test/flutter_test.dart';
import 'package:loomia/features/contacts/domain/person.dart';
import 'package:loomia/features/team/domain/check_in.dart';
import 'package:loomia/features/workflows/domain/progress.dart';

final _today = DateTime(2026, 10, 8);

DateTime _ago(int days) => addDays(_today, -days);

/// On the team since [joined]; added to Loomia on [added], a year ago unless
/// told. An [added] before [joined] means they reached Team inside Loomia
/// only when [movedHere].
Person _member(
  String name,
  DateTime joined, {
  DateTime? talked,
  DateTime? added,
  bool movedHere = false,
}) => Person(
  id: name,
  name: name,
  stage: Stage.team,
  // A stage change lands later than the insert: the time of day says so.
  stageSince: movedHere ? joined.add(const Duration(hours: 12)) : joined,
  createdAt: added ?? _ago(365),
  lastContactOn: talked,
);

void main() {
  group('new', () {
    test('moved to Team inside Loomia, nothing logged since', () {
      final [row] = checkIns([
        _member('Ana', _ago(1), added: _ago(3), movedHere: true),
      ], _today);

      expect(
        (row.reason, row.since, row.days),
        (CheckInReason.isNew, _ago(1), 1),
      );
    });

    test('moved and added the same day still counts', () {
      final [row] = checkIns([
        _member('Ana', _today, added: _today, movedHere: true),
      ], _today);

      expect(row.reason, CheckInReason.isNew);
    });

    test('a contact before joining does not count', () {
      final [row] = checkIns([
        _member('Ana', _ago(10), talked: _ago(20), movedHere: true),
      ], _today);

      expect(row.reason, CheckInReason.isNew);
    });

    test('added straight onto Team: not new, and in the grace month', () {
      expect(
        checkIns([_member('Ana', _today, added: _today)], _today),
        isEmpty,
      );
    });

    test('not new at 30 days: quiet from the joining day instead', () {
      final [row] = checkIns([
        _member('Ana', _ago(30), movedHere: true),
      ], _today);

      expect((row.reason, row.days), (CheckInReason.quiet, 30));
    });
  });

  group('grace month after an import', () {
    test('imported since today: hidden for 29 days, quiet on day 30', () {
      expect(
        checkIns([_member('A', _ago(0), added: _ago(0))], _today),
        isEmpty,
      );
      expect(
        checkIns([_member('A', _ago(29), added: _ago(29))], _today),
        isEmpty,
      );
      final [row] = checkIns([_member('A', _ago(30), added: _ago(30))], _today);
      expect((row.reason, row.days), (CheckInReason.quiet, 30));
    });

    test('imported backdated: counted from the day added', () {
      final joined = DateTime(2019, 3, 4);

      expect(
        checkIns([_member('A', joined, added: _ago(29))], _today),
        isEmpty,
      );
      final [row] = checkIns([_member('A', joined, added: _ago(30))], _today);
      expect(
        (row.reason, row.since, row.days),
        (CheckInReason.quiet, _ago(30), 30),
      );
    });

    test('a log older than the add, inside the grace month: hidden', () {
      expect(
        checkIns([
          _member('A', _ago(400), talked: _ago(90), added: _ago(10)),
        ], _today),
        isEmpty,
      );
    });
  });

  group('quiet', () {
    test('from 30 days without contact, not 29', () {
      expect(
        checkIns([_member('A', _ago(400), talked: _ago(29))], _today),
        isEmpty,
      );
      final [row] = checkIns([
        _member('A', _ago(400), talked: _ago(30)),
      ], _today);
      expect(
        (row.reason, row.days, row.since),
        (CheckInReason.quiet, 30, _ago(30)),
      );
    });

    test('the added day counts in the local calendar', () {
      final lateEvening = DateTime(2026, 9, 7, 23, 30).toUtc();

      expect(addedOn(_member('A', _ago(400), added: lateEvening)), _ago(31));
    });
  });

  test('neither: talked since joining, lately', () {
    expect(
      checkIns([_member('A', _ago(400), talked: _today)], _today),
      isEmpty,
    );
  });

  test('the joining day is the local calendar day', () {
    final lateEvening = DateTime(2026, 9, 29, 23, 30).toUtc();

    expect(joinedOn(_member('A', lateEvening)), DateTime(2026, 9, 29));
    // Just past midnight in Paris is still yesterday in UTC.
    final earlyMorning = DateTime(2026, 9, 30, 0, 30).toUtc();
    expect(joinedOn(_member('A', earlyMorning)), DateTime(2026, 9, 30));
    expect(
      talkedSinceJoining(
        _member('A', lateEvening, talked: DateTime(2026, 9, 29)),
      ),
      isTrue,
    );
  });

  test('oldest first, then by name', () {
    final rows = checkIns([
      _member('Zoé', _ago(5), movedHere: true),
      _member('Émile', _ago(5), movedHere: true),
      _member('Bruno', _ago(400), talked: _ago(60)),
    ], _today);

    expect(
      [for (final row in rows) row.person.name],
      ['Bruno', 'Émile', 'Zoé'],
    );
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:loomia/core/ui/action_item.dart';
import 'package:loomia/core/ui/section_header.dart';
import 'package:loomia/features/contacts/domain/person.dart';
import 'package:loomia/features/team/domain/check_in.dart';
import 'package:loomia/features/team/presentation/check_in_items.dart';
import 'package:loomia/l10n/app_localizations_en.dart';

final _l10n = AppLocalizationsEn();
final _today = DateTime(2026, 10, 8);

String _reason({DateTime? talked, required DateTime joined, DateTime? added}) {
  final [row] = checkIns([
    Person(
      id: 'a',
      name: 'Camille',
      stage: Stage.team,
      stageSince: joined,
      createdAt: added ?? DateTime(2025),
      lastContactOn: talked,
    ),
  ], _today);
  return checkInReason(_l10n, row);
}

String _chip(int days) {
  final [header, row] = checkInItems(
    _l10n,
    [
      (
        person: Person(
          id: 'a',
          name: 'A',
          stage: Stage.team,
          stageSince: DateTime(2025),
        ),
        reason: CheckInReason.quiet,
        since: DateTime(2025),
        days: days,
      ),
    ],
    onOpen: (_) {},
    onCheckIn: (_) {},
  );
  expect(header, isA<SectionHeader>());
  return ((row as ActionItem).chip! as DateChip).label;
}

void main() {
  setUpAll(() => initializeDateFormatting('en'));

  test('quiet reasons: talked, never since joining, never since added', () {
    expect(
      _reason(joined: DateTime(2025), talked: DateTime(2026, 7, 12)),
      'You last talked on July 12',
    );
    expect(
      _reason(joined: DateTime(2026, 8, 3), added: DateTime(2026, 8, 1)),
      'Nothing is logged since they joined on August 3',
    );
    expect(
      _reason(joined: DateTime(2019, 3, 4), added: DateTime(2026, 9, 3)),
      'Nothing is logged since you added them on September 3',
    );
  });

  test('the chip counts whole months', () {
    expect(_chip(30), 'Quiet a month');
    expect(_chip(59), 'Quiet a month');
    expect(_chip(60), 'Quiet 2 months');
  });
}

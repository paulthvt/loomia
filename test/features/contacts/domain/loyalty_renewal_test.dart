import 'package:flutter_test/flutter_test.dart';
import 'package:loomia/features/contacts/domain/loyalty_renewal.dart';
import 'package:loomia/features/contacts/domain/person.dart';

/// The cases of supabase/tests/loyalty_renewal_test.sql.
Person _on(int? day, {DateTime? checked, bool lrp = true}) => Person(
  id: 'p1',
  name: 'Julie',
  stage: Stage.customer,
  stageSince: DateTime.utc(2026),
  loyaltySince: lrp ? DateTime(2026, 9, 15) : null,
  loyaltyDay: day,
  loyaltyCheckedFor: checked,
);

void main() {
  test('4 days before: not yet; 3 days before to the day: due; after: next '
      'month, not yet', () {
    final julie = _on(15);
    expect(loyaltyRenewal(julie, DateTime(2026, 10, 11)), isNull);
    expect(
      loyaltyRenewal(julie, DateTime(2026, 10, 12)),
      DateTime(2026, 10, 15),
    );
    expect(
      loyaltyRenewal(julie, DateTime(2026, 10, 15)),
      DateTime(2026, 10, 15),
    );
    expect(loyaltyRenewal(julie, DateTime(2026, 10, 16)), isNull);
  });

  test('the 28th in February; next month it comes back', () {
    expect(
      loyaltyRenewal(_on(28), DateTime(2027, 2, 25)),
      DateTime(2027, 2, 28),
    );
    expect(
      loyaltyRenewal(_on(15), DateTime(2026, 11, 14)),
      DateTime(2026, 11, 15),
    );
  });

  test('across a year: a renewal early in January is asked in December', () {
    expect(
      loyaltyRenewal(_on(2), DateTime(2026, 12, 30)),
      DateTime(2027, 1, 2),
    );
  });

  test('checked, or no LRP: nothing to ask', () {
    expect(
      loyaltyRenewal(
        _on(15, checked: DateTime(2026, 10, 15)),
        DateTime(2026, 10, 14),
      ),
      isNull,
    );
    expect(loyaltyRenewal(_on(15, lrp: false), DateTime(2026, 10, 15)), isNull);
    expect(loyaltyRenewal(_on(null), DateTime(2026, 10, 15)), isNull);
  });
}

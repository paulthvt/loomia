import 'package:loomia/features/contacts/domain/person.dart';

/// Days before a renewal that Today asks to check in about it.
const int loyaltyRenewalAhead = 3;

/// The Dart copy of `loyalty_renewal_on` (#317): the LRP renewal to check in
/// about on [today], local midnight. This month's, or next month's once this
/// month's has passed; due from [loyaltyRenewalAhead] days before until the
/// day, unless already checked. Null otherwise.
/// supabase/tests/loyalty_renewal_test.sql pins the same cases.
DateTime? loyaltyRenewal(Person person, DateTime today) {
  final day = person.loyaltyDay;
  if (person.loyaltySince == null || day == null) return null;
  final renewal = today.day <= day
      ? DateTime(today.year, today.month, day)
      : DateTime(today.year, today.month + 1, day);
  final from = DateTime(
    renewal.year,
    renewal.month,
    renewal.day - loyaltyRenewalAhead,
  );
  if (today.isBefore(from) || person.loyaltyCheckedFor == renewal) return null;
  return renewal;
}

import 'dart:typed_data';

import 'package:loomia/features/contacts/domain/person.dart';
import 'package:loomia/features/contacts/domain/search_key.dart';

/// Someone in the phone's address book, as the import sees them: only what
/// Add someone would take, and the thumbnail of their photo (#240).
typedef PhoneContact = ({
  String name,
  String? phone,
  String? email,
  Uint8List? photo,
});

/// Whether [contact] looks like someone already in [people]: the same phone
/// number, or else the same name. Flagged for the user to decide, never
/// merged.
bool alreadyIn(PhoneContact contact, Iterable<Person> people) {
  final phone = _number(contact.phone);
  final name = searchKey(contact.name);
  return people.any(
    (person) => phone != null
        ? phone == _number(person.phone)
        : name == searchKey(person.name),
  );
}

/// The last nine digits: "+33 6 12 34 56 78" and "06 12 34 56 78" are the same
/// line. Null when there are too few digits to tell.
// ponytail: nine digits fits French and most European numbers; parse with the
// country code if a shorter national format ever collides.
String? _number(String? phone) {
  final digits = (phone ?? '').replaceAll(RegExp(r'\D'), '');
  return digits.length < 9 ? null : digits.substring(digits.length - 9);
}

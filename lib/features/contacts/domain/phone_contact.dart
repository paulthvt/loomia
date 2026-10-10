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

/// Someone in [people] on [contact]'s phone line: the same person, so they
/// are not imported twice. Null when the number is unknown or too short to
/// tell.
Person? samePhone(PhoneContact contact, Iterable<Person> people) {
  final phone = _number(contact.phone);
  if (phone == null) return null;
  return people.where((person) => _number(person.phone) == phone).firstOrNull;
}

/// Without a number to tell, whether someone in [people] has [contact]'s
/// name: maybe them, maybe a namesake, so it is flagged and the user decides.
bool sameName(PhoneContact contact, Iterable<Person> people) {
  if (_number(contact.phone) != null) return false;
  final name = searchKey(contact.name);
  return people.any((person) => searchKey(person.name) == name);
}

/// The last nine digits: "+33 6 12 34 56 78" and "06 12 34 56 78" are the same
/// line. Null when there are too few digits to tell.
// ponytail: nine digits fits French and most European numbers; parse with the
// country code if a shorter national format ever collides.
String? _number(String? phone) {
  final digits = (phone ?? '').replaceAll(RegExp(r'\D'), '');
  return digits.length < 9 ? null : digits.substring(digits.length - 9);
}

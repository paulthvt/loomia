import 'package:flutter_test/flutter_test.dart';
import 'package:loomia/features/contacts/domain/person.dart';
import 'package:loomia/features/contacts/domain/phone_contact.dart';

Person _person(String name, {String? phone}) => Person(
  id: name,
  name: name,
  stage: Stage.prospect,
  stageSince: DateTime.utc(2026, 3, 4),
  phone: phone,
);

void main() {
  final people = [
    _person('Marie Dupont', phone: '06 12 34 56 78'),
    _person('Hélène Martin'),
  ];

  test('the same line, written another way, is that person', () {
    expect(
      samePhone((
        name: 'Maman',
        phone: '+33 6 12 34 56 78',
        email: null,
        photo: null,
      ), people)?.name,
      'Marie Dupont',
    );
  });

  test('another number is someone else, even with the same name', () {
    const contact = (
      name: 'Marie Dupont',
      phone: '06 99 88 77 66',
      email: null,
      photo: null,
    );
    expect(samePhone(contact, people), isNull);
    expect(sameName(contact, people), isFalse);
  });

  test('without a number, the name flags, accents and case ignored', () {
    const helene = (
      name: 'helene MARTIN',
      phone: null,
      email: null,
      photo: null,
    );
    expect(samePhone(helene, people), isNull);
    expect(sameName(helene, people), isTrue);
    expect(
      sameName((name: 'Anne', phone: null, email: null, photo: null), people),
      isFalse,
    );
  });

  test('a number too short to tell falls back to the name', () {
    const contact = (
      name: 'Hélène Martin',
      phone: '3615',
      email: null,
      photo: null,
    );
    expect(samePhone(contact, people), isNull);
    expect(sameName(contact, people), isTrue);
  });
}

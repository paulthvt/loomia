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

  test('the same line, written another way, is already in', () {
    expect(
      alreadyIn((
        name: 'Maman',
        phone: '+33 6 12 34 56 78',
        email: null,
        photo: null,
      ), people),
      isTrue,
    );
  });

  test('another number is someone else, even with the same name', () {
    expect(
      alreadyIn((
        name: 'Marie Dupont',
        phone: '06 99 88 77 66',
        email: null,
        photo: null,
      ), people),
      isFalse,
    );
  });

  test('without a number, the name decides, accents and case ignored', () {
    expect(
      alreadyIn((
        name: 'helene MARTIN',
        phone: null,
        email: null,
        photo: null,
      ), people),
      isTrue,
    );
    expect(
      alreadyIn((name: 'Anne', phone: null, email: null, photo: null), people),
      isFalse,
    );
  });

  test('a number too short to tell falls back to the name', () {
    expect(
      alreadyIn((
        name: 'Hélène Martin',
        phone: '3615',
        email: null,
        photo: null,
      ), people),
      isTrue,
    );
  });
}

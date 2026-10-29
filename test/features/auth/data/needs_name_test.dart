import 'package:flutter_test/flutter_test.dart';
import 'package:loomia/features/auth/data/auth_repository.dart';

void main() {
  test('a name is needed only when neither the user nor the provider gave '
      'one', () {
    expect(needsNameFrom({}), isTrue);
    expect(needsNameFrom({'first_name': ' '}), isTrue);
    expect(needsNameFrom({'full_name': '  '}), isTrue);
    expect(needsNameFrom({'first_name': 'Pauline'}), isFalse);
    // Google's name, before the backfill copies it to first_name.
    expect(needsNameFrom({'full_name': 'Pauline Martin'}), isFalse);
    expect(needsNameFrom({'name': 'Pauline'}), isFalse);
  });
}

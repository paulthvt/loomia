import 'package:flutter_test/flutter_test.dart';
import 'package:loomia/features/auth/data/auth_repository.dart';

void main() {
  test('only a literal true in app_metadata makes a bug reporter', () {
    expect(bugReporterFrom({'bug_reporter': true}), isTrue);
    expect(bugReporterFrom({'bug_reporter': 'true'}), isFalse);
    expect(bugReporterFrom({}), isFalse);
    expect(bugReporterFrom(null), isFalse);
  });
}

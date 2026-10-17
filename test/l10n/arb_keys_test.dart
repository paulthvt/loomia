import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Keys in an ARB file, ignoring `@@locale` and the `@key` metadata entries.
Set<String> _keys(File file) =>
    (jsonDecode(file.readAsStringSync()) as Map<String, dynamic>).keys
        .where((key) => !key.startsWith('@'))
        .toSet();

void main() {
  // A language may legitimately lag: gen-l10n falls back to English for a key a
  // translation has not reached yet. A key that exists ONLY in a translation is
  // a different thing — a rename that went wrong, or a stale file.
  test('every translated key exists in English', () {
    final directory = Directory('lib/l10n');
    final english = _keys(File('${directory.path}/app_en.arb'));

    for (final file in directory.listSync().whereType<File>()) {
      final name = file.uri.pathSegments.last;
      if (!name.endsWith('.arb') || name == 'app_en.arb') continue;

      expect(
        _keys(file).difference(english),
        isEmpty,
        reason:
            '$name has keys English does not: check the Weblate pull request',
      );
    }
  });
}

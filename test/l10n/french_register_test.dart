import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Loomia is an assistant, so French says *tu*. French is machine-translated,
/// and a translator left to its default picks *vous*: this is what turns a sync
/// pull request in the wrong register red.
///
/// Imperatives (« Consultez » vs « Consulte ») have no marker word, so they
/// are the reviewer's job.
void main() {
  final vous = RegExp(r'\b(vous|votre|vos)\b', caseSensitive: false);

  test('French never addresses the user as vous', () {
    final arb = jsonDecode(
      File('lib/l10n/app_fr.arb').readAsStringSync(),
    ) as Map<String, dynamic>;
    final offending = {
      for (final MapEntry(:key, :value) in arb.entries)
        if (!key.startsWith('@') && value is String && vous.hasMatch(value))
          key: value,
    };

    expect(offending, isEmpty, reason: 'use tu, ton, ta, tes');
  });

  test('French uses the typographic apostrophe', () {
    final arb = jsonDecode(
      File('lib/l10n/app_fr.arb').readAsStringSync(),
    ) as Map<String, dynamic>;
    final offending = {
      for (final MapEntry(:key, :value) in arb.entries)
        if (!key.startsWith('@') && value is String && value.contains("'"))
          key: value,
    };

    expect(offending, isEmpty, reason: "use ’, not '");
  });
}

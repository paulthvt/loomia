import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The auth emails in supabase/templates/ carry their own English and French
/// (Weblate only handles the ARB files), each as `{{ if $fr }}…{{ else }}…`.
/// Checked here so a missing language, a lost link or a *vous* fails the PR.
void main() {
  final config = File('supabase/config.toml').readAsStringSync();
  final branches = RegExp(
    r'\{\{ if \$fr \}\}(.*?)\{\{ else \}\}(.*?)\{\{ end \}\}',
    dotAll: true,
  );
  final vous = RegExp(r'\b(vous|votre|vos)\b', caseSensitive: false);

  /// Each `[auth.email.template.x]` / `[auth.email.notification.x]` table:
  /// its subject and its HTML file.
  final emails = {
    for (final m in RegExp(
      r'^\[auth\.email\.(?:template|notification)\.(\w+)\]\n((?:[^\[\n].*\n?)*)',
      multiLine: true,
    ).allMatches(config))
      m[1]!: m[2]!,
  };

  /// A TOML string or bare value; a subject's `\"` read back as `"`.
  String field(String table, String key) => RegExp(
    '^$key = "?(.*?)"?\$',
    multiLine: true,
  ).firstMatch(table)![1]!.replaceAll(r'\"', '"');

  test('the three emails the app sends have templates', () {
    expect(emails.keys, containsAll(['confirmation', 'recovery']));
    expect(emails.keys, contains('password_changed'));
    expect(field(emails['password_changed']!, 'enabled'), 'true');
  });

  for (final MapEntry(key: name, value: table) in emails.entries) {
    group(name, () {
      final subject = field(table, 'subject');
      final html = File(field(table, 'content_path').replaceFirst('./', ''))
          .readAsStringSync();

      test('subject and body pick the language the same way', () {
        for (final text in [subject, html]) {
          expect(
            text,
            contains(
              r'{{ $fr := eq (or .Data.locale .Data.email_locale "en") "fr" }}',
            ),
          );
          expect(branches.hasMatch(text), isTrue);
        }
      });

      test('every French text has an English one, and says tu', () {
        for (final m in branches.allMatches(subject + html)) {
          final (fr, en) = (m[1]!.trim(), m[2]!.trim());
          expect(en, isNotEmpty);
          expect(fr, isNotEmpty);
          expect(vous.hasMatch(fr), isFalse, reason: fr);
        }
      });

      if (name != 'password_changed') {
        test('has the confirmation link', () {
          expect(html, contains('{{ .ConfirmationURL }}'));
        });
      }
    });
  }
}

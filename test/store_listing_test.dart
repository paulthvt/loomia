import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The App Store listing in ios/fastlane/metadata/ (deliver's layout), sent by
/// the Store listing workflow. Checked here so a field Apple would refuse, or
/// copy that breaks the product's rules, fails the PR instead of the upload.
void main() {
  const root = 'ios/fastlane/metadata';
  const languages = ['en-US', 'fr-FR'];
  const limits = {
    'name': 30,
    'subtitle': 30,
    'promotional_text': 170,
    'keywords': 100,
    'description': 4000,
  };
  const urls = ['support_url', 'marketing_url', 'privacy_url'];

  // deliver trims each file, so trimmed text is what Apple counts.
  String read(String path) => File('$root/$path').readAsStringSync().trim();

  test("every field exists in every language and fits Apple's limit", () {
    for (final lang in languages) {
      for (final MapEntry(key: field, value: max) in limits.entries) {
        final text = read('$lang/$field.txt');
        expect(text, isNotEmpty, reason: '$lang/$field');
        expect(
          text.length,
          lessThanOrEqualTo(max),
          reason: '$lang/$field: ${text.length} > $max',
        );
      }
      for (final field in urls) {
        expect(File('$root/$lang/$field.txt').existsSync(), isTrue);
      }
    }
  });

  test('keywords are comma-separated with no spaces after commas', () {
    for (final lang in languages) {
      expect(read('$lang/keywords.txt'), isNot(contains(', ')), reason: lang);
    }
  });

  test('URLs are on getloomia.app, French ones under /fr', () {
    const paths = {
      'support_url': '/support',
      'marketing_url': '',
      'privacy_url': '/privacy',
    };
    for (final MapEntry(key: field, value: path) in paths.entries) {
      expect(read('en-US/$field.txt'), 'https://getloomia.app$path');
      expect(read('fr-FR/$field.txt'), 'https://getloomia.app/fr$path');
    }
  });

  test('French uses tu', () {
    final words = RegExp(r'\b(vous|votre|vos)\b', caseSensitive: false);
    for (final field in limits.keys) {
      expect(words.hasMatch(read('fr-FR/$field.txt')), isFalse, reason: field);
    }
  });

  test('nothing reads as MLM, in the listing or the screenshot data', () {
    final words = RegExp(
      r'recruit|recrut|downline|upline|\bPV\b|\bOV\b|elite|essential oil|'
      r'huiles? essentielle|lavender|lavande|peppermint|menthe poivrée',
      caseSensitive: false,
    );
    final texts = {
      for (final lang in languages)
        for (final field in limits.keys)
          '$lang/$field': read('$lang/$field.txt'),
      'review notes': read('review_information/notes.txt'),
      'screenshots': File('test/store_screenshots_test.dart')
          .readAsStringSync()
          .replaceAll(RegExp(r'RegExp\([\s\S]*?\);'), ''),
    };
    for (final MapEntry(key: name, value: text) in texts.entries) {
      expect(words.firstMatch(text)?.group(0), isNull, reason: name);
    }
  });

  test('categories and review details are set', () {
    expect(read('primary_category.txt'), 'BUSINESS');
    expect(read('secondary_category.txt'), 'PRODUCTIVITY');
    expect(read('copyright.txt'), '2026 Paul Thevenot');
    expect(read('review_information/first_name.txt'), 'Paul');
    expect(read('review_information/last_name.txt'), 'Thevenot');
    expect(read('review_information/email_address.txt'), 'hello@getloomia.app');
    expect(read('review_information/notes.txt'), isNotEmpty);
    // The demo account's email and password, and the phone, are secrets.
    expect(
      File('$root/review_information/demo_user.txt').existsSync(),
      isFalse,
    );
    expect(
      File('$root/review_information/demo_password.txt').existsSync(),
      isFalse,
    );
  });

  test('the age rating answers every question with none or false', () {
    final answers = jsonDecode(
      File('ios/fastlane/rating_config.json').readAsStringSync(),
    ) as Map<String, Object?>;
    expect(answers, isNotEmpty);
    for (final MapEntry(key: question, value: answer) in answers.entries) {
      expect(answer, anyOf('NONE', false), reason: question);
    }
  });
}

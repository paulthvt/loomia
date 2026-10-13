import 'package:flutter_test/flutter_test.dart';

import '../../tool/release_notes.dart';

void main() {
  test('changes keeps user-facing sections and drops the links', () {
    const body = '''
## [0.1.1](https://github.com/x/y/compare/v0.1.0...v0.1.1) (2026-09-30)


### ✨ Features

* **auth:** sign in and register ([#23](https://github.com/x/y/issues/23)) ([cd6afee](https://github.com/x/y/commit/cd6afee))
* **shell:** app shell with a sidebar ([#33](https://github.com/x/y/issues/33)) ([876b620](https://github.com/x/y/commit/876b620)), closes [#29](https://github.com/x/y/issues/29)


### 🐛 Bug Fixes

* **contacts:** delete once the page is off screen ([#75](https://github.com/x/y/issues/75)) ([409b8d5](https://github.com/x/y/commit/409b8d5))


### ✅ Tests

* golden tests for every widget preview ([#42](https://github.com/x/y/issues/42)) ([905afa9](https://github.com/x/y/commit/905afa9))
''';
    expect(changes(body), [
      '**auth:** sign in and register',
      '**shell:** app shell with a sidebar',
      '**contacts:** delete once the page is off screen',
    ]);
  });

  test('changes reads a yeet body', () {
    const body = '''
## [2026.10.1](https://github.com/x/y/compare/2026.10.0...2026.10.1) (2026-10-14)

### ⚠ BREAKING CHANGES

- **db:** drop the team table ([abc1234](https://github.com/x/y/commit/abc1234))

### ✨ Features

- **calendar:** repeat weekly (#305) ([30a9c53](https://github.com/x/y/commit/30a9c53))

### ⚡ Performance

- faster Today ([1a2b3c4](https://github.com/x/y/commit/1a2b3c4))

### 🔧 Miscellaneous

- **deps:** pin ([5d6e7f8](https://github.com/x/y/commit/5d6e7f8))
''';
    expect(changes(body), [
      '**calendar:** repeat weekly (#305)',
      'faster Today',
    ]);
  });

  test('changes is empty when nothing is user-facing', () {
    expect(changes('### 🔧 Miscellaneous\n\n* **deps:** pin\n'), isEmpty);
  });

  group('check', () {
    const languages = ['en-US', 'fr-FR'];

    test('accepts one text per language', () {
      expect(
        check(languages, {'en-US': '• New', 'fr-FR': '• Nouveau'}),
        isEmpty,
      );
    });

    test('flags missing, extra, empty and too long', () {
      expect(check(languages, {'en-US': ' ', 'de-DE': 'Neu'}), [
        'de-DE: not requested',
        'en-US: empty',
        'fr-FR: missing from the reply',
      ]);
      expect(check(['en-US'], {'en-US': 'a' * 501}), [
        'en-US: 501 characters, over 500',
      ]);
      expect(check(languages, ['nope']), [
        'reply is not a JSON object: [nope]',
      ]);
    });
  });
}

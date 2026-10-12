import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../../tool/push_strings.dart';

void main() {
  const count = {
    'placeholders': {
      'count': {'type': 'int'},
    },
  };

  test('a plural splits into one and other, per language', () {
    final strings = pushStrings({
      'en': {
        'pushSummaryBody':
            '{count, plural, =1{One person} other{{count} people}}',
        '@pushSummaryBody': count,
        'todayTitle': 'Today',
      },
      'fr': {
        'pushSummaryBody':
            '{count, plural, =1{Une personne} other{{count} personnes}}',
      },
    });
    expect(strings, {
      'push_summary_body_one_en': ['One person'],
      'push_summary_body_one_fr': ['Une personne'],
      'push_summary_body_other_en': [1, ' people'],
      'push_summary_body_other_fr': [1, ' personnes'],
    });
  });

  test('plain text gets no plural suffix', () {
    expect(
      pushStrings({
        'en': {'pushHello': 'Hello'},
      }),
      {
        'push_hello_en': ['Hello'],
      },
    );
  });

  test('an unsupported plural case stops the run', () {
    expect(
      () => pushStrings({
        'en': {
          'pushX': '{count, plural, =0{None} other{{count}}}',
          '@pushX': count,
        },
      }),
      throwsFormatException,
    );
  });

  test('Android escapes and positions', () {
    final xml = toAndroidXml({
      'k': ["C'est \"5 %\" & <ok> ", 1],
    });
    expect(
      xml,
      contains(
        r'''<string name="k">C\'est \"5 %%\" &amp; &lt;ok> %1$s</string>''',
      ),
    );
  });

  // Release builds shrink resources; these are only looked up by name (#282).
  test('Android keeps them through release shrinking', () {
    expect(
      File('android/app/src/main/res/raw/push_keep.xml').readAsStringSync(),
      contains('tools:keep="@string/push_*"'),
    );
  });

  test('iOS escapes and positions', () {
    final strings = toIosStrings({
      'k': ['a "b" \\ 5 % ', 1],
    });
    expect(strings, contains(r'"k" = "a \"b\" \\ 5 %% %1$@";'));
  });

  test(
    'the committed files are current: run dart run tool/push_strings.dart',
    () {
      final strings = pushStrings(readArbs());
      expect(File(androidPath).readAsStringSync(), toAndroidXml(strings));
      expect(File(iosPath).readAsStringSync(), toIosStrings(strings));
    },
  );
}

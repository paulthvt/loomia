import 'package:flutter_test/flutter_test.dart';

import '../../tool/translate.dart';

void main() {
  const english = {'a': 'Hello', 'b': 'Bye', 'c': 'New'};

  group('stale', () {
    test('sends missing keys and keys whose English changed', () {
      expect(
        stale(
          english,
          {'a': 'Salut', 'b': 'Ciao'},
          {'a': 'Hello', 'b': 'Bye!'},
        ),
        ['b', 'c'],
      );
    });

    test('adopts a translation with no recorded source', () {
      expect(
        stale(english, {'a': 'Salut', 'b': 'Ciao', 'c': 'Neuf'}, {}),
        isEmpty,
      );
    });
  });

  test('merge keeps English order, prefers new text, drops removed keys', () {
    final (:arb, :sources) = merge(
      'fr',
      english,
      {'c': 'Neuf', 'a': 'Salut', 'gone': 'Parti'},
      {'b': 'Au revoir'},
    );
    expect(arb.keys, ['@@locale', 'a', 'b', 'c']);
    expect(arb['b'], 'Au revoir');
    expect(sources, english);
  });

  test('strings accepts flat and {text} replies, rejects anything else', () {
    expect(
      strings({
        'a': 'Salut',
        'b': {'text': 'Ciao'},
      }),
      {'a': 'Salut', 'b': 'Ciao'},
    );
    expect(strings({'a': 1}), isNull);
    expect(strings(['a']), isNull);
  });

  group('check', () {
    final englishArb = <String, dynamic>{
      'n': '{count, plural, =1{One person} other{{count} people}}',
      '@n': {
        'placeholders': {'count': <String, dynamic>{}},
      },
      'm': 'Hi {name}',
      '@m': {
        'placeholders': {'name': <String, dynamic>{}},
      },
    };

    test('accepts a faithful reply', () {
      expect(
        check(
          englishArb,
          ['n', 'm'],
          {
            'n': '{count, plural, =1{Une personne} other{{count} personnes}}',
            'm': 'Salut {name}',
          },
        ),
        isEmpty,
      );
    });

    test('flags a lost or renamed placeholder, a missing and an extra key', () {
      final errors = check(
        englishArb,
        ['n', 'm'],
        {'m': 'Salut {nom}', 'x': 'extra'},
      );
      expect(errors, hasLength(3));
    });
  });
}

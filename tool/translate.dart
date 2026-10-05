// Translates every lib/l10n/app_xx.arb from app_en.arb with Gemini.
//
//   GEMINI_API_KEY=... dart run tool/translate.dart
//
// Free-tier Gemini key, see tool/gemini.dart.
//
// Only keys that need work are sent: missing in the target, or whose English
// changed since they were translated. lib/l10n/translation_sources.json records
// the English each translation was made from; that is how a change is noticed,
// and why a hand edit to a translated ARB survives the next run.
import 'dart:convert';
import 'dart:io';

import 'gemini.dart';

const _dir = 'lib/l10n';
const _sourcesPath = '$_dir/translation_sources.json';

// ponytail: fixed batch size; lower it if a long language hits max_tokens.
const _batch = 80;

const _system = '''
You translate the UI strings of Loomia, a productivity app for people who run a
business on relationships: contacts, follow-ups, customers, goals.

Rules:
- Informal register everywhere the language distinguishes. French uses tu, ton,
  ta, tes and informal imperatives ("Consulte", not "Consultez"); never vous,
  votre, vos.
- Calm, plain, warm. Never salesy, never pressure, no "recruit" language.
- Keep every {placeholder} exactly as written, and keep ICU plural/select syntax
  intact: translate only the text inside the branches, keep the keywords and
  the =0/=1/one/other selectors. Add the target language's plural categories if
  it needs them.
- Keep punctuation conventions of the target language (e.g. French non-breaking
  space rules may be approximated with a normal space).
- Each string comes with a description of where it appears. Use it.

Reply with a single flat JSON object mapping every key you were given to its
translated text as a plain string, e.g. {"key": "translation"}, not
{"key": {"text": "translation"}}. No other text.''';

Future<void> main() async {
  final key = Platform.environment['GEMINI_API_KEY'];
  if (key == null || key.isEmpty) fail('GEMINI_API_KEY is not set');

  final englishArb = _readJson('$_dir/app_en.arb');
  final english = messages(englishArb);
  final sourcesFile = File(_sourcesPath);
  final allSources = sourcesFile.existsSync()
      ? _readJson(_sourcesPath).map(
          (locale, value) =>
              MapEntry(locale, Map<String, String>.from(value as Map)),
        )
      : <String, Map<String, String>>{};

  final files =
      Directory(_dir)
          .listSync()
          .whereType<File>()
          .where((f) => RegExp(r'app_\w+\.arb$').hasMatch(f.path))
          .where((f) => !f.path.endsWith('app_en.arb'))
          .toList()
        ..sort((a, b) => a.path.compareTo(b.path));

  final client = HttpClient();
  final nextSources = <String, Map<String, String>>{};
  for (final file in files) {
    final arb = _readJson(file.path);
    final locale = arb['@@locale'] as String;
    final target = messages(arb);
    final sources = allSources[locale] ?? {};
    final todo = stale(english, target, sources);
    stdout.writeln('$locale: ${todo.length} to translate');

    final translated = <String, String>{};
    for (var i = 0; i < todo.length; i += _batch) {
      final keys = todo.sublist(i, (i + _batch).clamp(0, todo.length));
      final reply = await _translate(client, key, locale, englishArb, keys);
      final errors = check(englishArb, keys, reply);
      if (errors.isNotEmpty) fail('$locale:\n  ${errors.join('\n  ')}');
      translated.addAll(reply);
    }

    final merged = merge(locale, english, target, translated);
    file.writeAsStringSync(_encode(merged.arb));
    nextSources[locale] = merged.sources;
  }
  client.close();
  sourcesFile.writeAsStringSync(_encode(nextSources));
}

/// The translatable messages of an ARB file: no `@@locale`, no `@key` metadata.
Map<String, String> messages(Map<String, dynamic> arb) => {
  for (final MapEntry(:key, :value) in arb.entries)
    if (!key.startsWith('@')) key: value as String,
};

/// Keys to send, in English order: missing in [target], or translated from an
/// English that has since changed. A key present in [target] with no recorded
/// source is adopted as-is — it was written by hand or predates the sidecar.
List<String> stale(
  Map<String, String> english,
  Map<String, String> target,
  Map<String, String> sources,
) => [
  for (final MapEntry(:key, :value) in english.entries)
    if (!target.containsKey(key) ||
        (sources.containsKey(key) && sources[key] != value))
      key,
];

/// The new target ARB and its sources, in English order. Keys English no longer
/// has are dropped from both.
({Map<String, Object> arb, Map<String, String> sources}) merge(
  String locale,
  Map<String, String> english,
  Map<String, String> target,
  Map<String, String> translated,
) {
  final arb = <String, Object>{'@@locale': locale};
  final sources = <String, String>{};
  for (final MapEntry(:key, :value) in english.entries) {
    final text = translated[key] ?? target[key];
    if (text == null) continue;
    arb[key] = text;
    sources[key] = value;
  }
  return (arb: arb, sources: sources);
}

/// Problems with a reply for [keys]: a key missing, an extra key, or a declared
/// placeholder of the English message that appears or disappears.
List<String> check(
  Map<String, dynamic> englishArb,
  List<String> keys,
  Map<String, String> reply,
) {
  final errors = <String>[
    for (final key in reply.keys)
      if (!keys.contains(key)) '$key: not requested',
  ];
  for (final key in keys) {
    final text = reply[key];
    if (text == null) {
      errors.add('$key: missing from the reply');
      continue;
    }
    final meta = englishArb['@$key'] as Map<String, dynamic>?;
    final names = (meta?['placeholders'] as Map<String, dynamic>?)?.keys ?? [];
    for (final name in names) {
      final used = RegExp('\\{${RegExp.escape(name)}[,}]');
      if (used.hasMatch(englishArb[key] as String) != used.hasMatch(text)) {
        errors.add('$key: placeholder {$name} not preserved in "$text"');
      }
    }
  }
  return errors;
}

Future<Map<String, String>> _translate(
  HttpClient client,
  String apiKey,
  String locale,
  Map<String, dynamic> englishArb,
  List<String> keys,
) async {
  final input = {
    for (final key in keys)
      key: {
        'text': englishArb[key],
        if (englishArb['@$key'] case final Map<String, dynamic> meta) ...meta,
      },
  };
  final reply = await askGemini(
    client,
    apiKey,
    system: _system,
    prompt:
        'Translate from English into the locale "$locale".\n\n'
        '${const JsonEncoder.withIndent('  ').convert(input)}',
    what: locale,
  );
  final result = strings(reply);
  if (result == null) {
    fail('$locale: reply is not a JSON object of strings:\n$reply');
  }
  return result;
}

/// [reply] as key → translation. Lighter models echo the input shape and
/// answer `{"key": {"text": "..."}}`, so that is unwrapped too. Null if neither.
Map<String, String>? strings(Object? reply) {
  if (reply is! Map) return null;
  final result = <String, String>{};
  for (final MapEntry(:key, :value) in reply.entries) {
    final text = switch (value) {
      String() => value,
      {'text': final String text} => text,
      _ => null,
    };
    if (key is! String || text == null) return null;
    result[key] = text;
  }
  return result;
}

Map<String, dynamic> _readJson(String path) =>
    jsonDecode(File(path).readAsStringSync()) as Map<String, dynamic>;

String _encode(Object json) =>
    '${const JsonEncoder.withIndent('  ').convert(json)}\n';

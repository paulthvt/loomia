// The store "What's new" text of one release, in every app language, with
// Gemini.
//
//   gh release view 2026.10.1 --json body -q .body > body.md
//   GEMINI_API_KEY=... dart run tool/release_notes.dart body.md release-notes.json
//
// Writes {"en-US": "...", "fr-FR": "..."}, each at most 500 characters: Play's
// limit, the App Store allows more, so one text fits every store. Only the
// Features, Bug Fixes and Performance entries are sent; a release with none
// writes no file. One call per release, on the free-tier key of
// tool/gemini.dart.
import 'dart:convert';
import 'dart:io';

import 'gemini.dart';

const _max = 500;

// App locale → store language code, the same on Play and the App Store. A new
// app language stops the run until it has a line here.
const _store = {'en': 'en-US', 'fr': 'fr-FR'};

// .yeet.yaml changelog sections a user can notice.
const _shown = {'Features', 'Bug Fixes', 'Performance'};

const _system =
    '''
You write the "What's new" notes the app stores show for Loomia, a productivity
app for people who run a business on relationships: contacts, follow-ups,
customers, goals.

You get the changes of one release as developer commit subjects. Write for the
people using the app:
- Only what they would notice. Skip anything internal: tests, tooling,
  refactoring, dependencies, databases, configuration.
- Inviting, like a friend telling you what got better: warm, confident,
  concrete. Talk to the reader ("you"). Lead with what it gives them, not the
  feature's name: "Know who to reach out to the moment you open the app", not
  "Today view suggests contacts".
- Never pushy: no hype words (amazing, powerful, revolutionary), no exclamation
  marks, no emoji. No "recruit" language; never present the app as a sales or
  MLM tool.
- Start with one short sentence that sums up the release. Then one short line
  per change, each starting with "• ", most useful first. Merge related
  changes; leave out plumbing a user takes for granted. No heading, no version
  number, no issue numbers.
- Informal register wherever the language distinguishes: French uses tu, ton,
  ta, tes and informal imperatives; never vous, votre, vos.
- Every language says the same thing, written natively, not word for word.
- At most $_max characters per language, spaces and line breaks included. Drop
  the least useful changes to fit.

Reply with a single JSON object mapping each requested language code to its
notes. No other text.''';

Future<void> main(List<String> args) async {
  if (args.length != 2) fail('usage: release_notes.dart <body.md> <out.json>');
  final key = Platform.environment['GEMINI_API_KEY'];
  if (key == null || key.isEmpty) fail('GEMINI_API_KEY is not set');

  final lines = changes(File(args[0]).readAsStringSync());
  if (lines.isEmpty) {
    stdout.writeln('Nothing a user would notice, no release notes.');
    return;
  }

  final languages = [
    for (final file in Directory('lib/l10n').listSync())
      if (RegExp(r'app_(\w+)\.arb$').firstMatch(file.path) case final match?)
        _store[match[1]] ?? fail('${match[1]}: no store language code'),
  ]..sort();

  final client = HttpClient();
  final reply = await askGemini(
    client,
    key,
    system: _system,
    prompt:
        'Languages: ${languages.join(', ')}\n\n'
        'Changes:\n${lines.map((line) => '- $line').join('\n')}',
    what: 'release notes',
  );
  client.close();

  final errors = check(languages, reply);
  if (errors.isNotEmpty) fail(errors.join('\n'));
  final notes = reply! as Map<String, dynamic>;
  File(args[1]).writeAsStringSync(
    const JsonEncoder.withIndent('  ')
        .convert({for (final language in languages) language: notes[language]}),
  );
  stdout.writeln(notes.values.join('\n\n'));
}

/// The user-facing entries of a release body (yeet, or release-please before
/// 2026.10), without their issue and commit links.
List<String> changes(String body) {
  final links = RegExp(r',? ?(closes )?\(?\[[^\]]*\]\([^)]*\)\)?');
  final lines = <String>[];
  var shown = false;
  for (final line in LineSplitter.split(body)) {
    if (line.startsWith('### ')) {
      shown = _shown.any(line.endsWith);
    } else if (shown && (line.startsWith('* ') || line.startsWith('- '))) {
      lines.add(line.substring(2).replaceAll(links, '').trim());
    }
  }
  return lines;
}

/// Problems with a reply for [languages]: not an object, a language missing or
/// extra, or notes that are empty or over [_max] characters.
List<String> check(List<String> languages, Object? reply) {
  if (reply is! Map) return ['reply is not a JSON object: $reply'];
  return [
    for (final language in reply.keys)
      if (!languages.contains(language)) '$language: not requested',
    for (final language in languages)
      switch (reply[language]) {
        final String text when text.trim().isEmpty => '$language: empty',
        final String text when text.length > _max =>
          '$language: ${text.length} characters, over $_max',
        String() => null,
        _ => '$language: missing from the reply',
      },
  ].nonNulls.toList();
}

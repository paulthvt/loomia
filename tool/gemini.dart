// The one Gemini call tool/release_notes.dart makes.
//
// The key is a free-tier Google AI Studio key: no billing, rate-limited, and
// Google may use the requests to improve its products. Fine here, the input is
// public UI copy and commit subjects only.
import 'dart:convert';
import 'dart:io';

// Free-tier models (ai.google.dev/gemini-api/docs/pricing), tried in turn: a
// 503 is one model out of capacity, and each has its own quota. The first one
// is used whenever it answers. List them with
//   curl -H "x-goog-api-key: $GEMINI_API_KEY" https://generativelanguage.googleapis.com/v1beta/models
const _models = [
  'gemini-3.8-flash',
  'gemini-3.7-flash',
  'gemini-3.5-flash-lite',
];

// Waits before each retry of an overloaded (503), failing (500) or
// rate-limited (429) call, on the next model. The free tier does all three; a
// minute covers the per-minute limit, not the daily one.
const _retries = [
  Duration(seconds: 10),
  Duration(seconds: 30),
  Duration(minutes: 1),
];

/// The JSON Gemini replies with to [prompt] under [system]. Exits on any
/// failure that survives the retries — quota, error status, cut-off or
/// non-JSON reply — naming [what].
Future<Object?> askGemini(
  HttpClient client,
  String apiKey, {
  required String system,
  required String prompt,
  required String what,
}) async {
  late HttpClientResponse response;
  late String body;
  for (final (attempt, wait) in [..._retries, null].indexed) {
    final model = _models[attempt % _models.length];
    final request = await client.postUrl(
      Uri.parse(
        'https://generativelanguage.googleapis.com/v1beta/models/$model:generateContent',
      ),
    );
    request.headers
      ..set('x-goog-api-key', apiKey)
      ..contentType = ContentType.json;
    request.write(
      jsonEncode({
        'systemInstruction': {
          'parts': [
            {'text': system},
          ],
        },
        'contents': [
          {
            'role': 'user',
            'parts': [
              {'text': prompt},
            ],
          },
        ],
        'generationConfig': {'responseMimeType': 'application/json'},
      }),
    );
    response = await request.close();
    body = await response.transform(utf8.decoder).join();
    if (wait == null || !const {429, 500, 503}.contains(response.statusCode)) {
      break;
    }
    stderr.writeln(
      '$what: Gemini ${response.statusCode}, retrying in ${wait.inSeconds}s',
    );
    await Future<void>.delayed(wait);
  }
  if (response.statusCode == 429) {
    fail(
      'Gemini free-tier quota or rate limit reached (429). Wait and re-run the '
      'workflow.\n$body',
    );
  }
  if (response.statusCode != 200) {
    fail('Gemini API ${response.statusCode}: $body');
  }
  final reply = jsonDecode(body) as Map<String, dynamic>;
  final candidates = reply['candidates'] as List<dynamic>? ?? [];
  if (candidates.isEmpty) fail('$what: no candidate returned: $body');
  final candidate = candidates.first as Map<String, dynamic>;
  final finish = candidate['finishReason'];
  if (finish != 'STOP') fail('$what: stopped with $finish');
  final content = candidate['content'] as Map<String, dynamic>;
  final text = (content['parts'] as List<dynamic>)
      .cast<Map<String, dynamic>>()
      .map((part) => part['text'] as String? ?? '')
      .join();
  try {
    return jsonDecode(text);
  } on FormatException {
    fail('$what: reply is not JSON:\n$text');
  }
}

Never fail(String message) {
  stderr.writeln(message);
  exit(1);
}

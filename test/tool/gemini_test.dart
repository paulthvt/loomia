import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../../tool/gemini.dart';

void main() {
  test(
    'a dropped connection is retried on the next model',
    () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final models = <String>[];
      server.listen((request) async {
        models.add(request.uri.pathSegments.last);
        await utf8.decoder.bind(request).join();
        if (models.length == 1) {
          // What Google did on 2026-11-14: drop the call without a reply.
          (await request.response.detachSocket()).destroy();
          return;
        }
        request.response
          ..headers.contentType = ContentType.json
          ..write(
            jsonEncode({
              'candidates': [
                {
                  'finishReason': 'STOP',
                  'content': {
                    'parts': [
                      {'text': '{"en-US": "New"}'},
                    ],
                  },
                },
              ],
            }),
          );
        await request.response.close();
      });
      // Plain HTTP to the local server in place of TLS to Google.
      final client = HttpClient()
        ..connectionFactory = (uri, proxyHost, proxyPort) =>
            Socket.startConnect(InternetAddress.loopbackIPv4, server.port);

      final reply = await askGemini(
        client,
        'key',
        system: 'system',
        prompt: 'prompt',
        what: 'test',
      );

      expect(reply, {'en-US': 'New'});
      expect(models, [
        'gemini-3.8-flash:generateContent',
        'gemini-3.7-flash:generateContent',
      ]);
      client.close(force: true);
      await server.close(force: true);
    },
    // The first retry waits 10 seconds.
    timeout: const Timeout(Duration(seconds: 30)),
  );
}

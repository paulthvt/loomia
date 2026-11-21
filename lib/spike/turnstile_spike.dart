// THROWAWAY SPIKE (#529): not for main. Checks that invisible Turnstile hands
// a token back through webview_flutter on a real iPhone and Android phone.
// Run: flutter run -t lib/spike/turnstile_spike.dart -d <device>
import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:webview_flutter/webview_flutter.dart';

void main() => runApp(const MaterialApp(home: _Spike()));

/// Cloudflare's test site keys: work on any domain.
const _keys = {
  // The real Loomia widget (invisible): proves Cloudflare accepts the
  // getloomia.app origin that loadHtmlString gives the page.
  'Real Loomia key': '0x4AAAAAAGLbJD8LJpK6Xhx9',
  'Invisible, always passes': '1x00000000000000000000BB',
  'Forces an interactive challenge': '3x00000000000000000000FF',
  'Always fails': '2x00000000000000000000AB',
};

String _page(String siteKey) =>
    '''
<!doctype html><html><head>
<meta name="viewport" content="width=device-width,initial-scale=1">
<script>
window.onerror = function (m) { console.log('js error: ' + m); };
function failed() { console.log('api.js failed to load'); }
</script>
<script src="https://challenges.cloudflare.com/turnstile/v0/api.js?onload=go&render=explicit" async onerror="failed()"></script>
<script>
function go() {
  console.log('api.js loaded');
  turnstile.render('#c', {
    sitekey: '$siteKey',
    callback: function (t) { Turnstile.postMessage('token:' + t); },
    'error-callback': function (e) { Turnstile.postMessage('error:' + e); },
    'timeout-callback': function () { Turnstile.postMessage('error:timeout'); },
    'unsupported-callback': function () { Turnstile.postMessage('error:unsupported'); },
  });
}
</script></head><body><div id="c"></div></body></html>''';

class _Spike extends StatefulWidget {
  const _Spike();
  @override
  State<_Spike> createState() => _SpikeState();
}

class _SpikeState extends State<_Spike> {
  final _log = <String>[];
  WebViewController? _controller;
  Stopwatch? _clock;
  Timer? _deadline;

  void _run(String label, String key) {
    _deadline?.cancel();
    _clock = Stopwatch()..start();
    _deadline = Timer(const Duration(seconds: 20), () {
      _add('$label: NO ANSWER after 20 s');
    });
    final controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..addJavaScriptChannel(
        'Turnstile',
        onMessageReceived: (m) {
          _deadline?.cancel();
          final text = m.message.length > 40
              ? '${m.message.substring(0, 40)}…'
              : m.message;
          _add('$label: $text (${_clock!.elapsedMilliseconds} ms)');
        },
      )
      ..setOnConsoleMessage((m) => _add('console: ${m.message}'))
      ..setNavigationDelegate(
        NavigationDelegate(
          onWebResourceError: (e) =>
              _add('load error: ${e.errorCode} ${e.description} ${e.url}'),
          onPageFinished: (u) => _add('page finished: $u'),
        ),
      )
      ..loadHtmlString(_page(key), baseUrl: 'https://getloomia.app');
    setState(() => _controller = controller);
    _add('$label: started');
  }

  @override
  void initState() {
    super.initState();
    // Starts the invisible key on launch, so a run without taps reports too.
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _run(_keys.keys.first, _keys.values.first),
    );
  }

  void _add(String line) {
    debugPrint('SPIKE $line');
    setState(() => _log.insert(0, line));
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Turnstile spike')),
    body: Column(
      children: [
        for (final MapEntry(key: label, value: key) in _keys.entries)
          ListTile(title: Text(label), onTap: () => _run(label, key)),
        // The web view must be in the tree to run; an interactive challenge
        // shows here.
        SizedBox(
          height: 80,
          child: _controller == null
              ? null
              : WebViewWidget(controller: _controller!),
        ),
        Expanded(
          child: ListView(children: [for (final l in _log) Text(l)]),
        ),
      ],
    ),
  );
}

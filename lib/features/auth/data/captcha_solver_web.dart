import 'dart:async';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:loomia/features/auth/data/captcha_page.dart';
import 'package:material_ui/material_ui.dart';
import 'package:web/web.dart' as web;

/// The web: the page is already a browser, so Turnstile's script goes into
/// the app's own document and renders one invisible widget into a detached
/// corner `div` per challenge.
Future<String> solveTurnstile() async {
  final turnstile = await _script();
  final host = web.document.createElement('div') as web.HTMLElement
    ..style.setProperty('position', 'fixed')
    ..style.setProperty('left', '-10000px');
  web.document.body!.append(host);
  final answer = Completer<String>();
  final options = JSObject()
    ..['sitekey'] = turnstileSiteKey.toJS
    ..['retry'] = 'never'.toJS
    // Invisible mode only takes 'auto' or 'never'; Captcha replaces old tokens.
    ..['refresh-expired'] = 'never'.toJS
    ..['callback'] = ((JSString t) {
      if (!answer.isCompleted) answer.complete(t.toDart);
    }).toJS
    ..['error-callback'] = ((JSAny? code) {
      if (!answer.isCompleted) answer.completeError(StateError('error:$code'));
      return true.toJS;
    }).toJS
    ..['timeout-callback'] = (() {
      if (!answer.isCompleted) answer.completeError(StateError('timeout'));
    }).toJS
    ..['unsupported-callback'] = (() {
      if (!answer.isCompleted) answer.completeError(StateError('unsupported'));
    }).toJS;
  final id = turnstile.render(host, options);
  try {
    return await answer.future;
  } finally {
    turnstile.remove(id);
    host.remove();
  }
}

/// Nothing to mount on the web.
Widget turnstileView() => const SizedBox.shrink();

Future<_Turnstile>? _loading;

Future<_Turnstile> _script() => _loading ??= () {
  final loaded = Completer<_Turnstile>();
  final script = web.document.createElement('script') as web.HTMLScriptElement
    ..src =
        'https://challenges.cloudflare.com/turnstile/v0/api.js?render=explicit'
    ..async = true;
  script
    ..onload = ((web.Event _) => loaded.complete(_turnstile!)).toJS
    ..onerror = ((web.Event _) {
      _loading = null; // the next challenge tries again
      loaded.completeError(StateError('script'));
    }).toJS;
  web.document.head!.append(script);
  return loaded.future;
}();

@JS('turnstile')
external _Turnstile? get _turnstile;

extension type _Turnstile(JSObject _) implements JSObject {
  external JSString render(web.HTMLElement element, JSObject options);
  external void remove(JSString id);
}

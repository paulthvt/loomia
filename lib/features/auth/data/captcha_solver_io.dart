import 'dart:async';

import 'package:loomia/features/auth/data/captcha_page.dart';
import 'package:material_ui/material_ui.dart';
import 'package:webview_flutter/webview_flutter.dart';

/// Android and iOS: one invisible challenge in a web view loaded under
/// [turnstileOrigin]. The view must be on screen to run (`turnstileView`,
/// mounted by `CaptchaHost`).
Future<String> solveTurnstile() {
  final view = _view;
  if (view == null) return Future.error(StateError('no web view'));
  return view.solve();
}

/// The web view, for `CaptchaHost`; nothing where none can exist.
Widget turnstileView() {
  final view = _view;
  return view == null
      ? const SizedBox.shrink()
      : WebViewWidget(controller: view.controller);
}

// Null in tests, where no web view platform is registered.
final _TurnstileWebView? _view = WebViewPlatform.instance == null
    ? null
    : _TurnstileWebView();

class _TurnstileWebView {
  _TurnstileWebView() {
    controller
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..addJavaScriptChannel('Captcha', onMessageReceived: _onMessage);
  }

  final controller = WebViewController();
  Completer<String>? _answer;

  Future<String> solve() {
    final previous = _answer;
    if (previous != null && !previous.isCompleted) {
      previous.completeError(StateError('superseded'));
    }
    final answer = _answer = Completer<String>();
    controller.loadHtmlString(captchaPage, baseUrl: turnstileOrigin);
    return answer.future;
  }

  void _onMessage(JavaScriptMessage message) {
    final answer = _answer;
    if (answer == null || answer.isCompleted) return;
    final text = message.message;
    if (text.startsWith('token:')) {
      answer.complete(text.substring('token:'.length));
    } else {
      answer.completeError(StateError(text));
    }
  }
}

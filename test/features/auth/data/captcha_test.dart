import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:loomia/features/auth/data/captcha.dart';
import 'package:loomia/features/auth/domain/auth_failure.dart';

void main() {
  var clock = DateTime(2026, 11, 21, 10);

  /// Answers each solve with the next of [answers]: a token, an error, or
  /// null for "never answers".
  ({Captcha captcha, List<int> solves}) captchaWith(
    List<Object?> answers, {
    Duration timeout = Captcha.timeout,
  }) {
    final solves = <int>[];
    var i = 0;
    final captcha = Captcha(
      () {
        solves.add(i);
        final answer = answers[i++];
        if (answer == null) return Completer<String>().future;
        if (answer is String) return Future.value(answer);
        return Future.error(answer);
      },
      now: () => clock,
      answerWithin: timeout,
    );
    return (captcha: captcha, solves: solves);
  }

  test('a token is used once; the next one is fetched behind it', () async {
    final (:captcha, :solves) = captchaWith(['a', 'b', 'c']);
    captcha.warm();
    expect(await captcha.token(), 'a');
    expect(await captcha.token(), 'b');
    // Two tokens and the one warmed behind them: none fetched on demand.
    expect(solves, hasLength(3));
  });

  test('a warmed token older than 4 minutes is replaced', () async {
    final (:captcha, solves: _) = captchaWith(['old', 'fresh', 'next']);
    captcha.warm();
    await Future<void>.delayed(Duration.zero);
    clock = clock.add(const Duration(minutes: 4, seconds: 1));
    expect(await captcha.token(), 'fresh');
  });

  test('an error is retried once, then is a captcha failure', () async {
    final retried = captchaWith([StateError('600010'), 'ok']).captcha;
    expect(await retried.token(), 'ok');

    final failing = captchaWith([StateError('x'), StateError('y'), 'z']);
    await expectLater(failing.captcha.token(), throwsA(AuthFailure.captcha));
  });

  test('no answer in time counts as an error', () async {
    final (:captcha, solves: _) = captchaWith([
      null,
      null,
      'later',
    ], timeout: const Duration(milliseconds: 10));
    await expectLater(captcha.token(), throwsA(AuthFailure.captcha));
  });

  test('Turnstile gets 15 s to answer', () {
    expect(Captcha.timeout, const Duration(seconds: 15));
  });

  test('a failed warm-up does not poison the next token', () async {
    final (:captcha, solves: _) = captchaWith([
      StateError('a'),
      StateError('b'),
      'ok',
    ]);
    captcha.warm();
    await Future<void>.delayed(Duration.zero);
    expect(await captcha.token(), 'ok');
  });
}

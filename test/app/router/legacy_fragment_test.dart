import 'package:flutter_test/flutter_test.dart';
import 'package:loomia/app/router/legacy_fragment.dart';

String? target(String url) => legacyFragmentTarget(Uri.parse(url));

void main() {
  test('an old # link lands on its path (#440)', () {
    expect(
      target('https://app.getloomia.app/#/invite/ABCDEFGH'),
      '/invite/ABCDEFGH',
    );
    expect(target('https://app.getloomia.app/#/'), '/');
    expect(
      target('https://app.getloomia.app/#/contacts/p1?tab=history'),
      '/contacts/p1?tab=history',
    );
  });

  test('anything else is left alone', () {
    expect(target('https://app.getloomia.app/?code=abc'), isNull);
    expect(
      target('https://app.getloomia.app/#access_token=x&type=recovery'),
      isNull,
    );
    expect(target('https://app.getloomia.app/#error=access_denied'), isNull);
    expect(target('https://app.getloomia.app/invite/AB'), isNull);
    expect(target('https://app.getloomia.app/'), isNull);
  });
}

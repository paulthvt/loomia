import 'package:flutter_test/flutter_test.dart';
import 'package:loomia/core/ui/open_external.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  test('site pages are English, French under /fr', () {
    for (final page in ['/privacy', '/support']) {
      expect(
        siteUri(const Locale('en'), page),
        Uri.parse('https://getloomia.app$page'),
      );
      expect(
        siteUri(const Locale('fr'), page),
        Uri.parse('https://getloomia.app/fr$page'),
      );
      // The site has no other language.
      expect(
        siteUri(const Locale('de'), page),
        Uri.parse('https://getloomia.app$page'),
      );
    }
  });
}

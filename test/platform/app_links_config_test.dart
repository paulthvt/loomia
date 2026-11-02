import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

// Only /invite/ on app.getloomia.app opens the app (#440); the files it is
// checked against are in web/.well-known/.
void main() {
  test('Android: a verified App Link for /invite/ only', () {
    final manifest = File('android/app/src/main/AndroidManifest.xml')
        .readAsStringSync();
    expect(manifest, contains('android:autoVerify="true"'));
    expect(manifest, contains('android:host="app.getloomia.app"'));
    expect(manifest, contains('android:pathPrefix="/invite/"'));
  });

  test('iOS: the associated domain', () {
    expect(
      File('ios/Runner/Runner.entitlements').readAsStringSync(),
      contains('<string>applinks:app.getloomia.app</string>'),
    );
  });
}

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

// The files Android and iOS read from app.getloomia.app before an invite
// link opens the app (#440).
void main() {
  test('assetlinks.json lets app.loomia open the links, signed by Play', () {
    final statements = jsonDecode(
      File('web/.well-known/assetlinks.json').readAsStringSync(),
    ) as List;
    final target = (statements.single as Map)['target'] as Map;
    expect((statements.single as Map)['relation'], [
      'delegate_permission/common.handle_all_urls',
    ]);
    expect(target['namespace'], 'android_app');
    expect(target['package_name'], 'app.loomia');
    expect(target['sha256_cert_fingerprints'], [
      // Play app signing key.
      'E3:B6:39:FC:A3:7E:09:E3:4F:82:44:22:A4:15:75:B0:91:E4:63:88:C8:FA:87:A1:6F:F2:BB:09:61:B2:6D:07',
      // Upload key: sideloaded builds.
      '13:40:11:27:F6:6D:08:DA:E8:91:C7:62:AE:32:11:9F:80:F8:25:57:86:9D:4C:CF:31:D0:CD:BD:F4:A6:BA:1D',
    ]);
  });

  test('apple-app-site-association: only /invite/ opens the app', () {
    final aasa = jsonDecode(
      File('web/.well-known/apple-app-site-association').readAsStringSync(),
    ) as Map;
    final detail = ((aasa['applinks'] as Map)['details'] as List).single as Map;
    expect(detail['appIDs'], ['378X654D2A.app.loomia']);
    expect(detail['components'], [
      {'/': '/invite/*'},
    ]);
  });

  test('the association is served as JSON, which iOS requires', () {
    expect(
      File('web/_headers').readAsStringSync(),
      contains(
        '/.well-known/apple-app-site-association\n'
        '  Content-Type: application/json',
      ),
    );
  });
}
